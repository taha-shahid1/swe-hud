import SwiftUI

/// Placeholder until Phase 3 wires up Claude Code sessions.
struct RightPanelView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.xs + 2) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("Sessions")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
            }

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
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, Theme.Spacing.lg)
        .glassBackdrop()
        .ignoresSafeArea()
    }
}
