import SwiftUI

struct RightPanelView: View {
    let store: SessionStore

    private var sessionCount: Int {
        store.sorted.count
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

            SessionsView(store: store)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, Theme.Spacing.lg)
        .padding(.bottom, Theme.Spacing.lg)
        .glassBackdrop()
        .ignoresSafeArea()
    }
}
