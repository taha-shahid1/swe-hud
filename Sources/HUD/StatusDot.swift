import SwiftUI

/// Every status but "needs you" stays grayscale — shape carries the
/// meaning, not color. "Needs you" gets the one accent color, plus the
/// only animation in the whole app: a quiet radar pulse. Nothing else
/// moves unless it needs you.
struct StatusDot: View {
    let status: ThreadStatus

    @State private var pulsing = false

    private let size: CGFloat = 7

    var body: some View {
        switch status {
        case .needsYou:
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.5))
                    .frame(width: size, height: size)
                    .scaleEffect(pulsing ? 2.4 : 1)
                    .opacity(pulsing ? 0 : 0.7)
                // A glowing orb instead of a flat fill: radial gradient
                // from a bright hot core out to the accent color, plus a
                // soft halo shadow — the one spot of color in the app
                // gets to feel like it actually needs you.
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
                    .shadow(color: Theme.accent.opacity(0.7), radius: 3)
            }
            .frame(width: 16, height: 16)
            .onAppear {
                withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) {
                    pulsing = true
                }
            }
        case .working:
            Circle()
                .fill(Color.secondary)
                .frame(width: size, height: size)
                .frame(width: 16, height: 16)
        case .waitingOnSomeone:
            Circle()
                .strokeBorder(Color.secondary, lineWidth: 1.2)
                .frame(width: size, height: size)
                .frame(width: 16, height: 16)
        case .done:
            Image(systemName: "checkmark")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.tertiary)
                .frame(width: 16, height: 16)
        }
    }
}
