import AppKit
import Carbon.HIToolbox
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panelController: PanelController!
    private var toggleHotKey: HotKeyManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        panelController = PanelController()
        setUpStatusItem()
        setUpHotKeys()
        registerLoginItemIfNeeded()
        // Dev affordance: `HUD --show` opens the panels at launch, for
        // eyeballing UI changes without the hotkey. `--snapshot <dir>` also
        // renders them to PNGs (no Screen Recording permission needed).
        let args = CommandLine.arguments
        if args.contains("--show") { panelController.show() }
        if let i = args.firstIndex(of: "--snapshot"), i + 1 < args.count {
            panelController.show(takeFocus: false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.panelController.snapshot(to: URL(fileURLWithPath: args[i + 1]))
                NSApp.terminate(nil)
            }
        }
    }

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(
            systemSymbolName: "rectangle.split.2x1", accessibilityDescription: "HUD"
        )

        let menu = NSMenu()
        let toggleItem = NSMenuItem(
            title: "Toggle HUD", action: #selector(togglePanels), keyEquivalent: "\t"
        )
        toggleItem.keyEquivalentModifierMask = [.option]
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit HUD", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func setUpHotKeys() {
        // ⌥Tab: unbound by macOS and common apps. Avoids ⌥Space (Claude
        // desktop, launchers), ⌘⇧Space (1Password), ⌥-letters (dead keys
        // like ⌥N for ñ) and ⌃-letters (tmux/shell). Carbon hotkeys steal
        // the combo from every app, so it has to be one nothing uses.
        // Capture is N inside the panel, not a second global hotkey.
        toggleHotKey = HotKeyManager(
            keyCode: UInt32(kVK_Tab),
            modifiers: UInt32(optionKey)
        ) { [weak self] in
            self?.panelController.toggle()
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
