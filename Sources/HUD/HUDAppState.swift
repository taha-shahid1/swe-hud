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
