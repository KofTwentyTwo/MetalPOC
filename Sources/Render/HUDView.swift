import MetalKit

final class HUDView: MTKView {
    init(frame: NSRect) {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not available on this system")
        }
        super.init(frame: frame, device: device)
        configureForTransparency()
    }

    required init(coder: NSCoder) {
        super.init(coder: coder)
        configureForTransparency()
    }

    private func configureForTransparency() {
        wantsLayer = true
        layer?.isOpaque = false
        layer?.backgroundColor = NSColor.clear.cgColor

        colorPixelFormat = .bgra8Unorm
        framebufferOnly = false
        clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)

        preferredFramesPerSecond = 60
        enableSetNeedsDisplay = false
        isPaused = false
    }
}
