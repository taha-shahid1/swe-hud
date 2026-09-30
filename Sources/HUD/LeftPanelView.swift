import SwiftUI

struct LeftPanelView: View {
    let store: ThreadStore
    let appState: HUDAppState

    @FocusState private var listFocused: Bool

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
                        LazyVStack(spacing: Theme.Spacing.xs + 2) {
                            ForEach(store.sorted) { thread in
                                ThreadRowView(
                                    thread: thread,
                                    isSelected: appState.selectedID == thread.id,
                                    isEditing: appState.editingID == thread.id,
                                    onCommitNextStep: { text in
                                        withAnimation(Theme.listSpring) {
                                            store.setNextStep(thread.id, text: text)
                                        }
                                        appState.editingID = nil
                                    }
                                )
                                .transition(.scale(scale: 0.96).combined(with: .opacity))
                                .onTapGesture {
                                    appState.selectedID = thread.id
                                    listFocused = true
                                }
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                    // Rows fade out at the scroll edges instead of clipping
                    // hard mid-row — the reactbits AnimatedList top-gradient
                    // trick, done as a true content mask.
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .black, location: 0.025),
                                .init(color: .black, location: 0.96),
                                .init(color: .clear, location: 1),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
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
                    .onKeyPress(.upArrow) {
                        guard appState.editingID == nil else { return .ignored }
                        moveSelection(by: -1)
                        return .handled
                    }
                    .onKeyPress(.downArrow) {
                        guard appState.editingID == nil else { return .ignored }
                        moveSelection(by: 1)
                        return .handled
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
                }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, Theme.Spacing.lg)
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
        }
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
            Text("⌥N to capture a thread")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.Spacing.xl * 2)
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
