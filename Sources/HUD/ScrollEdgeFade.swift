import SwiftUI

extension View {
    /// Fades a scroll edge only while more content lies past it, so the first
    /// and last items at rest are never dimmed.
    func scrollEdgeFade(length: CGFloat = 16) -> some View {
        modifier(ScrollEdgeFade(length: length))
    }
}

private struct ScrollEdgeFade: ViewModifier {
    let length: CGFloat
    @State private var moreAbove = false
    @State private var moreBelow = false

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: [Bool].self) { geo in
                [
                    geo.contentOffset.y > 1,
                    geo.contentOffset.y + geo.containerSize.height < geo.contentSize.height - 1,
                ]
            } action: { _, edges in
                moreAbove = edges[0]
                moreBelow = edges[1]
            }
            .mask(
                VStack(spacing: 0) {
                    LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                        .frame(height: moreAbove ? length : 0)
                    Color.black
                    LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: moreBelow ? length : 0)
                }
            )
    }
}
