import Foundation
import Observation

/// Shared UI state bridging AppKit-level input (global hotkeys, the Esc
/// monitor) and the SwiftUI panel content.
@Observable
final class HUDAppState {
    var selectedID: UUID?
    var editingID: UUID?
    var captureFocusTrigger: Int = 0
    var isCaptureFocused: Bool = false
    var threadsFocusTrigger: Int = 0
    var sessionsFocusTrigger: Int = 0
    /// Set by PanelController: the panels are separate windows, so moving
    /// focus across means making the other window key first.
    @ObservationIgnored var focusThreads: () -> Void = {}
    @ObservationIgnored var focusSessions: () -> Void = {}
    /// Jump to the session tile at this index (display order). Set by PanelController.
    @ObservationIgnored var jumpToSessionAt: (Int) -> Void = { _ in }

    func requestCapture() {
        captureFocusTrigger += 1
    }

    /// "1"–"9" in either panel jumps to that numbered tile. False if `key` isn't one.
    func jumpToSession(numbered key: String) -> Bool {
        guard let n = Int(key), (1...9).contains(n) else { return false }
        jumpToSessionAt(n - 1)
        return true
    }

    /// Returns true if it consumed the escape (i.e. was mid-edit).
    @discardableResult
    func cancelEditingIfNeeded() -> Bool {
        guard editingID != nil else { return false }
        editingID = nil
        return true
    }
}
