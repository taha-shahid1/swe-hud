import SwiftUI

struct LeftPanelView: View {
    let store: ThreadStore
    let appState: HUDAppState

    @FocusState private var listFocused: Bool
    @State private var listHeight: CGFloat = 0
    /// Mouse reordering. A plain DragGesture, not system drag-and-drop: that
    /// needs a pasteboard type macOS only registers for bundled apps.
    @State private var draggingID: UUID?
    @State private var dragOffset: CGFloat = 0
    @State private var dropTargetID: UUID?
    /// "Clear done" is two clicks: the first arms it for a few seconds.
    @State private var confirmClearDone = false
    @State private var rowFrames: [UUID: CGRect] = [:]
    /// Drag auto-scroll: the pointer is tracked in the (non-scrolling) viewport,
    /// so the dragged row can be kept under it while content scrolls beneath.
    @State private var scrollPosition = ScrollPosition(edge: .top)
    @State private var scroll = ScrollMetrics()
    @State private var dragStartOffset: CGFloat = 0
    @State private var dragTranslation: CGFloat = 0
    @State private var pointerY: CGFloat = 0
    @State private var autoScrollTimer: Timer?
    /// Panel max height minus header, capture field and padding.
    private static let maxListHeight = PanelController.maxHeight - 120

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            header

            CaptureField(appState: appState) { text in
                    let (key, title) = Self.parse(text)
                    withAnimation(Theme.listSpring) {
                        let created = store.add(key: key, title: title)
                        appState.selectedID = created.id
                    }
                    listFocused = true
                }

                if store.sorted.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: Theme.Spacing.xs + 2) {
                            ForEach(store.sorted) { thread in
                                ThreadRowView(
                                    thread: thread,
                                    isSelected: appState.selectedID == thread.id,
                                    isEditing: appState.editingID == thread.id,
                                    isActive: listFocused || appState.editingID == thread.id,
                                    onCommitNextStep: { text in
                                        withAnimation(Theme.listSpring) {
                                            store.setNextStep(thread.id, text: text)
                                        }
                                        appState.editingID = nil
                                    }
                                )
                                .transition(.scale(scale: 0.96).combined(with: .opacity))
                                .onGeometryChange(for: CGRect.self) {
                                    $0.frame(in: .named(Self.listSpace))
                                } action: { rowFrames[thread.id] = $0 }
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                                        .strokeBorder(Color.primary.opacity(dropTargetID == thread.id ? 0.3 : 0), lineWidth: 1.5)
                                )
                                .scaleEffect(draggingID == thread.id ? 1.02 : 1)
                                .shadow(color: .black.opacity(draggingID == thread.id ? 0.18 : 0), radius: 8, y: 3)
                                .offset(y: draggingID == thread.id ? dragOffset : 0)
                                .zIndex(draggingID == thread.id ? 1 : 0)
                                .onTapGesture {
                                    appState.selectedID = thread.id
                                    listFocused = true
                                }
                                .gesture(reorderGesture(for: thread))
                                .contextMenu {
                                    Button("Delete", role: .destructive) { delete(thread.id) }
                                }
                            }
                        }
                        .coordinateSpace(name: Self.listSpace)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { listHeight = $0 }
                    }
                    // Exactly as tall as the rows (capped), so the panel hugs
                    // its content: NSHostingView resizes the window to match.
                    // Must be exact, not maxHeight — a flexible height lets
                    // the window shrink but never grow back.
                    .frame(height: min(listHeight, Self.maxListHeight))
                    .coordinateSpace(name: Self.viewportSpace)
                    .scrollPosition($scrollPosition)
                    .onScrollGeometryChange(for: ScrollMetrics.self) { geo in
                        ScrollMetrics(
                            offset: geo.contentOffset.y,
                            maxOffset: max(0, geo.contentSize.height - geo.containerSize.height),
                            height: geo.containerSize.height
                        )
                    } action: { _, new in
                        scroll = new
                        if draggingID != nil { updateDrag() }
                    }
                    .onDisappear { stopAutoScroll() }
                    .scrollIndicators(.never)
                    .scrollEdgeFade()
                    // A plain ScrollView instead of List: List's native
                    // NSTableView selection paints a system-blue highlight
                    // that no SwiftUI modifier can suppress, which clashed
                    // badly with the grayscale-except-accent design. This
                    // trades List's free keyboard nav for full control over
                    // the selection look, so nav is reimplemented below.
                    .focusable()
                    .focusEffectDisabled()
                    .focused($listFocused)
                    .onAppear {
                        if appState.selectedID == nil {
                            appState.selectedID = store.sorted.first?.id
                        }
                        listFocused = true
                    }
                    .onKeyPress(.upArrow, phases: [.down, .repeat]) { press in
                        arrow(press, delta: -1)
                    }
                    .onKeyPress(.downArrow, phases: [.down, .repeat]) { press in
                        arrow(press, delta: 1)
                    }
                    .onKeyPress(.return) {
                        guard appState.editingID == nil, let id = appState.selectedID else {
                            return .ignored
                        }
                        appState.editingID = id
                        return .handled
                    }
                    .onKeyPress(.tab) {
                        guard appState.editingID == nil,
                              let id = appState.selectedID,
                              let current = store.threads.first(where: { $0.id == id })?.status
                        else { return .ignored }
                        withAnimation(Theme.listSpring) {
                            store.setStatus(id, status: current.next)
                        }
                        return .handled
                    }
                    .onKeyPress(.rightArrow) {
                        guard appState.editingID == nil else { return .ignored }
                        appState.focusSessions()
                        return .handled
                    }
                    .onKeyPress("n") {
                        guard appState.editingID == nil else { return .ignored }
                        appState.requestCapture()
                        return .handled
                    }
                    .onKeyPress(characters: .decimalDigits) { press in
                        guard appState.editingID == nil else { return .ignored }
                        return appState.jumpToSession(numbered: press.characters) ? .handled : .ignored
                    }
                    .onKeyPress(.delete) {
                        guard appState.editingID == nil, let id = appState.selectedID else {
                            return .ignored
                        }
                        delete(id)
                        return .handled
                    }
                }
        }
        .onChange(of: appState.threadsFocusTrigger) { _, _ in
            // No list yet: land in the capture field instead.
            if store.sorted.isEmpty { appState.requestCapture() } else { listFocused = true }
        }
        .padding(Theme.Spacing.lg)
        .frame(width: PanelController.leftPanelWidth)
        .glassBackdrop()
        .ignoresSafeArea()
    }

    private var header: some View {
        HStack(spacing: Theme.Spacing.xs + 2) {
            Image(systemName: "tray.full.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("Threads")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
            if !store.sorted.isEmpty {
                Text("\(store.sorted.count)")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.primary.opacity(0.08)))
            }
            let doneCount = store.threads.filter { $0.status == .done }.count
            if doneCount > 0 {
                Spacer(minLength: Theme.Spacing.sm)
                Button(confirmClearDone ? "Clear \(doneCount) done?" : "Clear done") {
                    if confirmClearDone {
                        clearDone()
                    } else {
                        confirmClearDone = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { confirmClearDone = false }
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: confirmClearDone ? .semibold : .regular))
                .foregroundStyle(confirmClearDone ? .primary : .tertiary)
            }
        }
    }

    /// Selects the neighbor first so focus doesn't fall off the list.
    private func delete(_ id: UUID) {
        let items = store.sorted
        if appState.selectedID == id, let idx = items.firstIndex(where: { $0.id == id }) {
            let neighbor = items.indices.contains(idx + 1) ? items[idx + 1] : (idx > 0 ? items[idx - 1] : nil)
            appState.selectedID = neighbor?.id
        }
        withAnimation(Theme.listSpring) { store.remove(id) }
    }

    private func clearDone() {
        confirmClearDone = false
        if let id = appState.selectedID, store.threads.first(where: { $0.id == id })?.status == .done {
            appState.selectedID = store.sorted.first { $0.status != .done }?.id
        }
        withAnimation(Theme.listSpring) { store.removeDone() }
    }

    private static let listSpace = "threadList"
    private static let viewportSpace = "threadViewport"
    /// Pointer within this distance of the list's top/bottom edge scrolls it.
    private static let edgeZone: CGFloat = 32
    /// Points per frame at full speed (pointer at or past the edge).
    private static let maxScrollStep: CGFloat = 10

    /// Drag a row; on release it takes the slot of the row under the pointer
    /// (same status group only, like ⌥↑/⌥↓).
    private func reorderGesture(for thread: ThreadItem) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named(Self.viewportSpace))
            .onChanged { value in
                if draggingID == nil {
                    draggingID = thread.id
                    appState.selectedID = thread.id
                    listFocused = true
                    dragStartOffset = scroll.offset
                    startAutoScroll()
                }
                dragTranslation = value.translation.height
                pointerY = value.location.y
                updateDrag()
            }
            .onEnded { _ in
                stopAutoScroll()
                let targetID = target(at: pointerY + scroll.offset, for: thread)
                withAnimation(Theme.listSpring) {
                    if let targetID { store.move(thread.id, to: targetID) }
                    draggingID = nil
                    dragOffset = 0
                }
                dropTargetID = nil
            }
    }

    private func updateDrag() {
        guard let id = draggingID, let thread = store.threads.first(where: { $0.id == id }) else { return }
        // Pointer motion plus however far the content has scrolled since the drag began.
        dragOffset = dragTranslation + (scroll.offset - dragStartOffset)
        dropTargetID = target(at: pointerY + scroll.offset, for: thread)
    }

    private func startAutoScroll() {
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { _ in autoScrollStep() }
        // .common so it keeps firing while the mouse is held down.
        RunLoop.main.add(timer, forMode: .common)
        autoScrollTimer = timer
    }

    private func stopAutoScroll() {
        autoScrollTimer?.invalidate()
        autoScrollTimer = nil
    }

    /// Faster the deeper the pointer is in the edge zone; capped once past the edge.
    private func autoScrollStep() {
        let depth: CGFloat
        if pointerY < Self.edgeZone {
            depth = pointerY - Self.edgeZone
        } else if pointerY > scroll.height - Self.edgeZone {
            depth = pointerY - (scroll.height - Self.edgeZone)
        } else {
            return
        }
        let step = max(-1, min(1, depth / Self.edgeZone)) * Self.maxScrollStep
        let next = min(max(scroll.offset + step, 0), scroll.maxOffset)
        if next != scroll.offset { scrollPosition.scrollTo(y: next) }
    }

    private func target(at y: CGFloat, for thread: ThreadItem) -> UUID? {
        store.sorted.first { other in
            other.id != thread.id && other.status == thread.status
                && (rowFrames[other.id].map { $0.minY...$0.maxY ~= y } ?? false)
        }?.id
    }

    /// ↑/↓ moves the selection; ⌥↑/⌥↓ moves the selected thread itself.
    private func arrow(_ press: KeyPress, delta: Int) -> KeyPress.Result {
        guard appState.editingID == nil else { return .ignored }
        if press.modifiers.contains(.option) {
            guard let id = appState.selectedID else { return .ignored }
            withAnimation(Theme.listSpring) { store.move(id, by: delta) }
        } else {
            moveSelection(by: delta)
        }
        return .handled
    }

    private func moveSelection(by delta: Int) {
        let items = store.sorted
        guard !items.isEmpty else { return }
        guard let currentID = appState.selectedID,
              let idx = items.firstIndex(where: { $0.id == currentID })
        else {
            appState.selectedID = delta > 0 ? items.first?.id : items.last?.id
            return
        }
        let newIndex = min(max(idx + delta, 0), items.count - 1)
        appState.selectedID = items[newIndex].id
    }

    private var emptyState: some View {
        VStack(alignment: .center, spacing: Theme.Spacing.sm) {
            Image(systemName: "tray")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(.tertiary)
            Text("Nothing in flight")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            Text("Type above to capture a thread")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xl)
    }

    /// "ENG-482 fix the thing" -> key "ENG-482", title "fix the thing".
    /// No recognizable key prefix -> whole text is the title.
    private static func parse(_ text: String) -> (key: String, title: String) {
        if let match = text.range(of: #"^[A-Z][A-Z0-9]+-\d+\s+"#, options: .regularExpression) {
            let key = text[..<match.upperBound].trimmingCharacters(in: .whitespaces)
            let title = String(text[match.upperBound...])
            return (key, title)
        }
        return ("", text)
    }
}

private struct ScrollMetrics: Equatable {
    var offset: CGFloat = 0
    var maxOffset: CGFloat = 0
    var height: CGFloat = 0
}
