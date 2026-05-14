import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: StatusItemController?
    private var hudController: HUDWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Start real-data services before creating the HUD so data flows immediately.
        NetworkScanner.shared.start()
        LocationProvider.shared.start()

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
