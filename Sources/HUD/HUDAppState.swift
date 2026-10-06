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

    func requestCapture() {
        captureFocusTrigger += 1
    }

    /// Returns true if it consumed the escape (i.e. was mid-edit).
    @discardableResult
    func cancelEditingIfNeeded() -> Bool {
        guard editingID != nil else { return false }
        editingID = nil
        return true
    }
}
