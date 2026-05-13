import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = StatusItemController()
        // statusItem!.onToggle = { … } wired up when HUDWindowController exists (Task 3)
    }
}
