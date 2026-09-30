import SwiftUI

/// Centralized design tokens. One corner radius, one accent color, one
/// spacing scale — reused everywhere so nothing drifts.
enum Theme {
    static let corner: CGFloat = 16

    /// Reserved exclusively for "needs you" — every other status stays
    /// grayscale so the accent always means the same thing.
    static let accent = Color(red: 1.0, green: 0.42, blue: 0.24)

    static let listSpring = Animation.spring(response: 0.32, dampingFraction: 0.82)

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
    }
}
