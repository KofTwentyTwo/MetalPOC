import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: StatusItemController?
    private var hudController: HUDWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let hud = HUDWindowController()
        hudController = hud
        hud.showWindow(nil)

        let status = StatusItemController()
        status.onFull    = { [weak hud] in hud?.setFull() }
        status.onCompact = { [weak hud] in hud?.setCompact() }
        status.onHidden  = { [weak hud] in hud?.setHidden() }
        statusItem = status
    }
}
