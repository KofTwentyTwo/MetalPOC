import Cocoa

final class HUDWindowController: NSWindowController {
    private let hudWindow: HUDWindow

    init() {
        // Temporary tinted placeholder content for Task 3. Replaced by HUDView in Task 4.
        let placeholder = NSView()
        placeholder.wantsLayer = true
        placeholder.layer?.backgroundColor = NSColor.clear.cgColor

        self.hudWindow = HUDWindow(contentView: placeholder)
        super.init(window: hudWindow)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func showWindow(_ sender: Any?) {
        hudWindow.orderFrontRegardless()
    }

    func toggleVisibility() {
        if hudWindow.isVisible {
            hudWindow.orderOut(nil)
        } else {
            hudWindow.orderFrontRegardless()
        }
    }
}
