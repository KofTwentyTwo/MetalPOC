import Cocoa

final class HUDWindow: NSWindow {
    init(contentView: NSView) {
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let frame = screen.frame

        super.init(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        self.contentView = contentView
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
