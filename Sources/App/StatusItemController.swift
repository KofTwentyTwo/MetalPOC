import Cocoa

final class StatusItemController {
    var onFull:    (() -> Void)?
    var onCompact: (() -> Void)?
    var onHidden:  (() -> Void)?

    /// Legacy single-toggle callback — kept for compatibility; cycles through modes.
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

        let fullItem = NSMenuItem(title: "Full HUD", action: #selector(triggerFull), keyEquivalent: "1")
        fullItem.target = self
        menu.addItem(fullItem)

        let compactItem = NSMenuItem(title: "Compact (orb only)", action: #selector(triggerCompact), keyEquivalent: "2")
        compactItem.target = self
        menu.addItem(compactItem)

        let hideItem = NSMenuItem(title: "Hide HUD", action: #selector(triggerHidden), keyEquivalent: "3")
        hideItem.target = self
        menu.addItem(hideItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit MetalPOC", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.target = NSApp
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func triggerFull()    { onFull?() }
    @objc private func triggerCompact() { onCompact?() }
    @objc private func triggerHidden()  { onHidden?() }
}
