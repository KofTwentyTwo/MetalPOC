import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: StatusItemController?
    private var hudController: HUDWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let hud = HUDWindowController()
        hudController = hud
        hud.showWindow(nil)

        let status = StatusItemController()
        status.onToggle = { [weak hud] in hud?.cycleMode() }
        statusItem = status
    }
}
