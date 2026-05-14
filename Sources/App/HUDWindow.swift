import Cocoa

final class HUDWindow: NSWindow {
    /// Container that holds NSVisualEffectView backdrops and the HUDView on top.
    /// Exposed so HUDWindowController can populate it after widgets are constructed.
    let containerView: NSView

    init() {
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let frame = screen.frame

        let container = NSView(frame: NSRect(origin: .zero, size: frame.size))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.clear.cgColor
        container.autoresizingMask = [.width, .height]
        self.containerView = container

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
        contentView = container
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
