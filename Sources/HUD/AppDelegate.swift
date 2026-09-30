import AppKit
import Carbon.HIToolbox
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panelController: PanelController!
    private var toggleHotKey: HotKeyManager?
    private var captureHotKey: HotKeyManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        panelController = PanelController()
        setUpStatusItem()
        setUpHotKeys()
        registerLoginItemIfNeeded()
    }

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(
            systemSymbolName: "rectangle.split.2x1", accessibilityDescription: "HUD"
        )

        let menu = NSMenu()
        let toggleItem = NSMenuItem(
            title: "Toggle HUD", action: #selector(togglePanels), keyEquivalent: "h"
        )
        toggleItem.keyEquivalentModifierMask = [.control, .option]
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit HUD", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func setUpHotKeys() {
        // Not ⌥Space: Raycast (and many launchers) already own that combo,
        // and Carbon hotkeys are first-come-first-served system-wide.
        toggleHotKey = HotKeyManager(
            keyCode: UInt32(kVK_ANSI_H),
            modifiers: UInt32(controlKey | optionKey)
        ) { [weak self] in
            self?.panelController.toggle()
        }

        captureHotKey = HotKeyManager(
            keyCode: UInt32(kVK_ANSI_N),
            modifiers: UInt32(optionKey)
        ) { [weak self] in
            self?.panelController.showQuickCapture()
        }
    }

    private func registerLoginItemIfNeeded() {
        do {
            if SMAppService.mainApp.status == .notRegistered {
                try SMAppService.mainApp.register()
            }
        } catch {
            // Non-fatal: common in dev runs that aren't a signed, installed .app bundle.
        }
    }

    @objc private func togglePanels() {
        panelController.toggle()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
