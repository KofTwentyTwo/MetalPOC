import Cocoa

final class StatusItemController {
    /// Set by the AppDelegate once the HUD controller exists. Stays nil through Task 2.
    var onToggle: (() -> Void)?

    private let statusItem: NSStatusItem

    init() {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        configureButton()
        configureMenu()
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        if let image = NSImage(systemSymbolName: "scope", accessibilityDescription: "Metal HUD") {
            image.isTemplate = true
            button.image = image
        } else {
            button.title = "HUD"
        }
    }

    private func configureMenu() {
        let menu = NSMenu()

        let toggleItem = NSMenuItem(title: "Toggle HUD", action: #selector(toggle), keyEquivalent: "h")
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit MetalPOC", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.target = NSApp
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func toggle() {
        onToggle?()
    }
}
