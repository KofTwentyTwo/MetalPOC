import Cocoa

final class HUDWindowController: NSWindowController {
    private let hudWindow: HUDWindow
    private let hudView: HUDView

    init() {
        let screenFrame = (NSScreen.main ?? NSScreen.screens.first!).frame
        self.hudView = HUDView(frame: NSRect(origin: .zero, size: screenFrame.size))
        self.hudWindow = HUDWindow(contentView: hudView)
        super.init(window: hudWindow)

        hudView.renderer.scene = [
            OrnamentElement(),
            OrbElement(),
            KPIClusterWidget()
        ]
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
