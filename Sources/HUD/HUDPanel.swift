import AppKit

/// A borderless, non-activating panel.
///
/// `.nonactivatingPanel` is the trick behind Spotlight/Alfred/Raycast-style
/// overlays: the panel can become key (so it receives keyboard input, like
/// Esc) without activating this app or moving focus away from whatever app
/// was frontmost.
final class HUDPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        // Each chip draws its own SwiftUI shadow now that there's no
        // panel-wide background — leave the window's own shadow off so it
        // can't ghost a big rectangle behind the transparent gaps.
        hasShadow = false
        isMovable = false
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        animationBehavior = .none
    }
}
