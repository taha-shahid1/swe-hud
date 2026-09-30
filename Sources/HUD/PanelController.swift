import AppKit
import SwiftUI

/// Owns the left and right overlay panels and toggles them together.
final class PanelController {
    static let leftPanelWidth: CGFloat = 300
    /// Wider than the left panel — a 2-column tile grid needs more
    /// breathing room per tile than a single-column row list does.
    static let rightPanelWidth: CGFloat = 340
    /// Gap from the top of the screen.
    static let topMargin: CGFloat = 12
    /// Gap from the left/right screen edges — floating, not edge-to-edge.
    static let horizontalMargin: CGFloat = 16
    /// Hard cap on panel height. A screen-spanning panel reads as a wall
    /// regardless of corner radius or inset — capping the height and
    /// anchoring near the top is what actually makes it a compact card.
    static let maxHeight: CGFloat = 640

    private let leftPanel: HUDPanel
    private let rightPanel: HUDPanel
    private let threadStore = ThreadStore()
    private let sessionStore = SessionStore()
    private let appState = HUDAppState()
    private(set) var isVisible = false
    private var keyMonitor: Any?

    private static let escapeKeyCode: UInt16 = 53

    init() {
        let (initialLeft, initialRight) = Self.targetFrames()
        leftPanel = HUDPanel(contentRect: initialLeft)
        rightPanel = HUDPanel(contentRect: initialRight)

        leftPanel.contentView = NSHostingView(
            rootView: LeftPanelView(store: threadStore, appState: appState)
        )
        rightPanel.contentView = NSHostingView(rootView: RightPanelView(store: sessionStore))

        // SwiftUI's `.onExitCommand` needs the view to be part of macOS's
        // focus system, which a raw AppKit-hosted NSPanel never establishes.
        // A local key monitor is the reliable way to catch Esc here. It also
        // has to know about inline editing, since Esc there should cancel
        // the edit rather than close the whole panel.
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isVisible else { return event }
            if event.keyCode == Self.escapeKeyCode {
                if self.appState.cancelEditingIfNeeded() {
                    return nil
                }
                self.hide()
                return nil
            }
            return event
        }
    }

    deinit {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
    }

    func toggle() {
        isVisible ? hide() : show()
    }

    /// Opens the panel (if needed) and jumps straight into the capture
    /// field so the dedicated hotkey goes from idea to typed text with
    /// no intermediate click.
    func showQuickCapture() {
        if !isVisible { show() }
        appState.requestCapture()
    }

    // Appear/disappear as a plain fade, no slide. Movement catches the eye
    // far more than a fade does, and this panel is meant to be glanceable,
    // not performative, every time it opens.
    func show() {
        let (finalLeft, finalRight) = Self.targetFrames()
        leftPanel.setFrame(finalLeft, display: false)
        rightPanel.setFrame(finalRight, display: false)
        leftPanel.alphaValue = 0
        rightPanel.alphaValue = 0

        rightPanel.orderFrontRegardless()
        leftPanel.orderFrontRegardless()
        leftPanel.makeKey()
        isVisible = true

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            leftPanel.animator().alphaValue = 1
            rightPanel.animator().alphaValue = 1
        }
    }

    func hide() {
        isVisible = false
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.1
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            leftPanel.animator().alphaValue = 0
            rightPanel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.leftPanel.orderOut(nil)
            self?.rightPanel.orderOut(nil)
        })
    }

    /// The panels' resting frames on whichever screen the pointer is on, so
    /// the overlay always shows up where you're actually looking.
    private static func targetFrames() -> (left: NSRect, right: NSRect) {
        let frame = activeScreenFrame()
        let height = min(maxHeight, frame.height - topMargin * 2)
        let y = frame.maxY - topMargin - height
        let left = NSRect(
            x: frame.minX + horizontalMargin, y: y, width: leftPanelWidth, height: height
        )
        let right = NSRect(
            x: frame.maxX - rightPanelWidth - horizontalMargin, y: y, width: rightPanelWidth, height: height
        )
        return (left, right)
    }

    private static func activeScreenFrame() -> NSRect {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) ?? NSScreen.main
        return screen?.frame ?? .zero
    }
}
