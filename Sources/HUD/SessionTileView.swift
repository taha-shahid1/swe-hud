import SwiftUI

struct SessionTileView: View {
    let session: SessionItem
    let isSelected: Bool
    /// 1–9: the digit key that jumps here.
    var number: Int?
    /// Whether this panel has keyboard focus; the selection dims when it doesn't.
    var isActive = true

    @State private var hovering = false

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            glyph
                .frame(height: 30)

            Text(session.name ?? session.project)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)

            if let branch = session.branch {
                Text(branch)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Text(session.attachID != nil && session.state == .detached ? "background" : session.state.label)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.sm + 2)
        .padding(.horizontal, Theme.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                .fill(Color.primary.opacity(isSelected ? (isActive ? 0.1 : 0.05) : (hovering ? 0.05 : 0)))
        )
        .overlay(alignment: .topLeading) {
            if let number {
                Text("\(number)")
                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .padding(Theme.Spacing.sm)
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }

    @ViewBuilder
    private var glyph: some View {
        switch session.state {
        case .needsYou:
            NeedsYouGlyph()
        case .working:
            Image(systemName: "bolt.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
        case .idle:
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
        case .detached:
            Image(systemName: "eye.slash")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}

/// Same radial-glow + radar-pulse language as StatusDot's needs-you state,
/// scaled up for a tile glyph. The one accent color, the one animation.
private struct NeedsYouGlyph: View {
    @State private var pulsing = false
    private let size: CGFloat = 12

    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.accent.opacity(0.5))
                .frame(width: size, height: size)
                .scaleEffect(pulsing ? 2.2 : 1)
                .opacity(pulsing ? 0 : 0.7)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Theme.accent.opacity(0.95), Theme.accent],
                        center: UnitPoint(x: 0.35, y: 0.3),
                        startRadius: 0,
                        endRadius: size * 0.9
                    )
                )
                .frame(width: size, height: size)
                .shadow(color: Theme.accent.opacity(0.7), radius: 4)
        }
        .frame(width: 26, height: 26)
        .onAppear {
            withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) {
                pulsing = true
            }
        }
    }
}
