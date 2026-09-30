import SwiftUI

struct SessionsView: View {
    let store: SessionStore

    @State private var selectedID: String?
    @FocusState private var gridFocused: Bool

    private let columns = [
        GridItem(.flexible(), spacing: Theme.Spacing.sm),
        GridItem(.flexible(), spacing: Theme.Spacing.sm),
    ]
    private static let columnCount = 2

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
                }
                .scrollIndicators(.hidden)
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
        // TODO: AppleScript terminal-jump / VS Code companion extension —
        // real Phase 3 infra, not wired up yet. This is the placeholder
        // hook point once that lands.
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
        .padding(.top, Theme.Spacing.xl * 2)
    }
}

/// The distilled note for whichever tile is selected — this is where the
/// "what happened / what's blocked / next step" text actually lives, one
/// tap or arrow-key away from the grid, never buried further than that.
private struct DetailStrip: View {
    let session: SessionItem
    var onJump: () -> Void

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
                Text(session.note ?? "No notes yet.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity)
            .scrollIndicators(.hidden)
            .frame(maxHeight: 72)

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
