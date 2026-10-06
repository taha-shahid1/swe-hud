import SwiftUI

struct SessionsView: View {
    let store: SessionStore
    let appState: HUDAppState
    var onJumped: () -> Void

    @State private var selectedID: String?
    @FocusState private var gridFocused: Bool
    @State private var gridHeight: CGFloat = 0

    private let columns = [
        GridItem(.flexible(), spacing: Theme.Spacing.sm),
        GridItem(.flexible(), spacing: Theme.Spacing.sm),
    ]
    private static let columnCount = 2
    /// Panel max height minus header, detail strip and padding.
    private static let maxGridHeight = PanelController.maxHeight - 220

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            if store.sorted.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        let (live, detached) = sections
                        if !live.isEmpty {
                            sectionHeader("Attached", icon: "eye")
                            grid(live)
                        }
                        if !detached.isEmpty {
                            sectionHeader("Detached", icon: "eye.slash")
                                .padding(.top, live.isEmpty ? 0 : Theme.Spacing.xs)
                            grid(detached)
                        }
                    }
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { gridHeight = $0 }
                }
                // Exact + capped, same as the thread list (see LeftPanelView).
                .frame(height: min(gridHeight, Self.maxGridHeight))
                .scrollIndicators(.never)
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black, location: 0.03),
                            .init(color: .black, location: 0.96),
                            .init(color: .clear, location: 1),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .focusable()
                .focusEffectDisabled()
                .focused($gridFocused)
                .onAppear {
                    if selectedID == nil { selectedID = store.sorted.first?.id }
                    gridFocused = true
                }
                .onKeyPress(.leftArrow) { move(.left); return .handled }
                .onKeyPress(.rightArrow) { move(.right); return .handled }
                .onKeyPress(.upArrow) { move(.up); return .handled }
                .onKeyPress(.downArrow) { move(.down); return .handled }
                .onKeyPress(.return) { jumpToSelected(); return .handled }

                if let selected = store.sorted.first(where: { $0.id == selectedID }) {
                    DetailStrip(session: selected, onJump: jumpToSelected)
                }
            }
        }
        .onChange(of: appState.sessionsFocusTrigger) { _, _ in
            if selectedID == nil { selectedID = store.sorted.first?.id }
            gridFocused = true
        }
    }

    /// Visible sessions, then detached ones in their own section below.
    private var sections: (live: [SessionItem], detached: [SessionItem]) {
        let all = store.sorted
        return (all.filter { $0.state != .detached }, all.filter { $0.state == .detached })
    }

    /// Grid rows across both sections, so ↑/↓ crosses between them by column.
    private var rows: [[SessionItem]] {
        let (live, detached) = sections
        return Self.chunked(live) + Self.chunked(detached)
    }

    private static func chunked(_ items: [SessionItem]) -> [[SessionItem]] {
        stride(from: 0, to: items.count, by: columnCount).map {
            Array(items[$0..<min($0 + columnCount, items.count)])
        }
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 9.5, weight: .semibold))
            Text(title)
                .font(.system(size: 10.5, weight: .semibold))
        }
        .foregroundStyle(.tertiary)
    }

    private func grid(_ items: [SessionItem]) -> some View {
        LazyVGrid(columns: columns, spacing: Theme.Spacing.sm) {
            ForEach(items) { session in
                SessionTileView(session: session, isSelected: selectedID == session.id, isActive: gridFocused)
                    .onTapGesture {
                        selectedID = session.id
                        gridFocused = true
                    }
            }
        }
    }

    private enum Direction { case left, right, up, down }

    private func move(_ direction: Direction) {
        let rows = rows
        guard !rows.isEmpty else { return }
        guard let r = rows.firstIndex(where: { $0.contains { $0.id == selectedID } }),
              let c = rows[r].firstIndex(where: { $0.id == selectedID })
        else {
            selectedID = rows[0][0].id
            return
        }
        switch direction {
        case .left:
            // Off the grid's left edge: back to the thread list.
            if c == 0 { appState.focusThreads() } else { selectedID = rows[r][c - 1].id }
        case .right:
            if c + 1 < rows[r].count { selectedID = rows[r][c + 1].id }
            else if r + 1 < rows.count { selectedID = rows[r + 1][0].id }
        case .up, .down:
            let nr = min(max(r + (direction == .up ? -1 : 1), 0), rows.count - 1)
            selectedID = rows[nr][min(c, rows[nr].count - 1)].id
        }
    }

    private func jumpToSelected() {
        guard let session = store.sorted.first(where: { $0.id == selectedID }) else { return }
        store.jump(to: session)
        onJumped()
    }

    private var emptyState: some View {
        VStack(alignment: .center, spacing: Theme.Spacing.sm) {
            Image(systemName: "bolt.slash")
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(.tertiary)
            Text("Nothing running")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xl)
    }
}

/// The distilled note for whichever tile is selected — this is where the
/// "what happened / what's blocked / next step" text actually lives, one
/// tap or arrow-key away from the grid, never buried further than that.
private struct DetailStrip: View {
    let session: SessionItem
    var onJump: () -> Void

    @State private var noteHeight: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.xs) {
                Text(session.project)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                if let branch = session.branch {
                    Text(branch)
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
                Spacer(minLength: Theme.Spacing.sm)
                if let notedAt = session.notedAt {
                    Text(Self.relativeTime(notedAt))
                        .font(.system(size: 10.5))
                        .foregroundStyle(.tertiary)
                }
            }

            // Capped + internally scrollable rather than line-limited: a
            // hard line cap silently hides the rest of the note with no
            // way to read it. This way nothing is ever lost, and the
            // detail strip can't push the panel past its fixed height.
            ScrollView {
                Text(session.note ?? "No recap yet. Run /recap in the session.")
                    .font(.system(size: 12))
                    .foregroundStyle(session.note == nil ? .tertiary : .secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { noteHeight = $0 }
            }
            .frame(maxWidth: .infinity)
            .scrollIndicators(.never)
            // Exact + capped (see LeftPanelView) so it can't collapse.
            .frame(height: min(noteHeight, 72))

            Button(action: onJump) {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 9, weight: .semibold))
                    Text(session.state == .detached ? "open in Terminal" : "jump in")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(Theme.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(Theme.Spacing.sm + 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
    }

    private static func relativeTime(_ date: Date) -> String {
        let seconds = Date().timeIntervalSince(date)
        if seconds < 60 { return "just now" }
        let minutes = Int(seconds / 60)
        if minutes < 60 { return "\(minutes)m ago" }
        return "\(minutes / 60)h ago"
    }
}
