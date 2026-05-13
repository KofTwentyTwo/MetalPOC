import MetalKit

final class HUDView: MTKView {
    let renderer: Renderer

    init(frame: NSRect) {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not available on this system")
        }

        let dummy = MTKView(frame: frame, device: device)
        guard let renderer = Renderer(view: dummy) else {
            fatalError("Failed to create Renderer")
        }
        self.renderer = renderer

        super.init(frame: frame, device: device)
        configureForTransparency()
        delegate = renderer
    }

    required init(coder: NSCoder) {
        fatalError("HUDView does not support init(coder:)")
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
