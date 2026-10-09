import SwiftUI

struct RightPanelView: View {
    let store: SessionStore
    let threadStore: ThreadStore
    let appState: HUDAppState
    var onJumped: () -> Void

    private var sessionCount: Int {
        threadStore.threads.filter { $0.status != .done }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.xs + 2) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("Sessions")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                if sessionCount > 0 {
                    Text("\(sessionCount)")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.primary.opacity(0.08)))
                }
            }

            SessionsView(store: store, appState: appState, onJumped: onJumped)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, Theme.Spacing.lg)
        .padding(.bottom, Theme.Spacing.lg)
        // LazyVGrid's .flexible() columns need a concrete width to
        // distribute space across. Nothing else in this chain pins one
        // down top-down (ScrollView -> LazyVGrid alone doesn't guarantee
        // that propagates), so without this the grid falls back to some
        // oversized default and spreads the two columns far apart — the
        // exact "huge gap between tiles" bug. Anchoring it explicitly
        // here removes the ambiguity outright.
        .frame(width: PanelController.rightPanelWidth)
        .glassBackdrop()
        .ignoresSafeArea()
    }
}
