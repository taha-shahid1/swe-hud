import SwiftUI

struct SessionsView: View {
    let store: SessionStore
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
                    LazyVGrid(columns: columns, spacing: Theme.Spacing.sm) {
                        ForEach(store.sorted) { session in
                            SessionTileView(session: session, isSelected: selectedID == session.id)
                                .onTapGesture {
                                    selectedID = session.id
                                    gridFocused = true
                                }
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
                .onKeyPress(.leftArrow) { move(-1); return .handled }
                .onKeyPress(.rightArrow) { move(1); return .handled }
                .onKeyPress(.upArrow) { move(-Self.columnCount); return .handled }
                .onKeyPress(.downArrow) { move(Self.columnCount); return .handled }
                .onKeyPress(.return) { jumpToSelected(); return .handled }

                if let selected = store.sorted.first(where: { $0.id == selectedID }) {
                    DetailStrip(session: selected, onJump: jumpToSelected)
                }
            }
        }
    }

    private func move(_ delta: Int) {
        let items = store.sorted
        guard !items.isEmpty else { return }
        guard let id = selectedID, let idx = items.firstIndex(where: { $0.id == id }) else {
            selectedID = items.first?.id
            return
        }
        let newIndex = min(max(idx + delta, 0), items.count - 1)
        selectedID = items[newIndex].id
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
                    Text("jump in")
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
