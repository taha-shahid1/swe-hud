import Carbon.HIToolbox
import AppKit

/// Registers a single global hotkey via the Carbon Event Manager.
///
/// Carbon hotkeys work system-wide without an Accessibility permission
/// prompt, unlike an `NSEvent` global monitor — that's why this app uses
/// them instead for the panel-toggle shortcut.
final class HotKeyManager {
    typealias Handler = () -> Void

    private static var nextID: UInt32 = 1

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let handler: Handler
    private let hotKeyID: EventHotKeyID

    init?(keyCode: UInt32, modifiers: UInt32, handler: @escaping Handler) {
        self.handler = handler
        self.hotKeyID = EventHotKeyID(signature: OSType(0x4855_4431), id: Self.nextID) // 'HUD1', 'HUD2', ...
        Self.nextID += 1

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, eventRef, userData in
                guard let userData, let eventRef else { return OSStatus(eventNotHandledErr) }
                var hkID = EventHotKeyID()
                let err = GetEventParameter(
                    eventRef,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hkID
                )
                guard err == noErr else { return err }
                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                guard hkID.id == manager.hotKeyID.id else {
                    // Not ours: let the event continue to other installed
                    // handlers. Returning `noErr` here would mark it as
                    // handled and stop the chain, starving every other
                    // registered hotkey.
                    return OSStatus(eventNotHandledErr)
                }
                manager.handler()
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &eventHandler
        )
        guard installStatus == noErr else { return nil }

        let registerStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard registerStatus == noErr else {
            if let eventHandler { RemoveEventHandler(eventHandler) }
            return nil
        }
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }
}
