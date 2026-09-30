import SwiftUI

extension View {
    /// The one shared blur surface for a panel. Every row/field sits on
    /// top of this as a plain tinted shape rather than carrying its own
    /// independent live blur — both because that's how Apple's own
    /// grouped-widget surfaces (e.g. Notification Center) actually work,
    /// and because many small `.behindWindow`-blended views inside a
    /// scrolling list is a reliability risk, not just a style choice.
    func glassBackdrop(cornerRadius: CGFloat = Theme.corner + 4) -> some View {
        background(
            VisualEffectView(material: .menu)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        )
        .shadow(color: .black.opacity(0.2), radius: 14, y: 4)
    }
}
