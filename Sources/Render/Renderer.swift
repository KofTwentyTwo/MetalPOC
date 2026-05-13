import MetalKit
import simd

final class Renderer: NSObject, MTKViewDelegate {
    var scene: [HUDElement] = []

    private let device: MTLDevice
    private let queue: MTLCommandQueue
    private let startTime: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
    private var lastFrameTime: CFAbsoluteTime

    init?(view: MTKView) {
        guard let device = view.device,
              let queue = device.makeCommandQueue() else {
            return nil
        }
        self.device = device
        self.queue = queue
        self.lastFrameTime = CFAbsoluteTimeGetCurrent()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        let now = CFAbsoluteTimeGetCurrent()
        let deltaTime = Float(now - lastFrameTime)
        lastFrameTime = now

        let context = FrameContext(
            time: Float(now - startTime),
            deltaTime: deltaTime,
            resolution: SIMD2<Float>(Float(view.drawableSize.width), Float(view.drawableSize.height)),
            scaleFactor: Float(view.window?.backingScaleFactor ?? 1.0),
            device: device
        )

        for element in scene {
            element.update(context: context)
        }

        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor,
              let command = queue.makeCommandBuffer(),
              let encoder = command.makeRenderCommandEncoder(descriptor: descriptor) else {
            return
        }

        for element in scene {
            element.encode(into: encoder, context: context)
        }

        encoder.endEncoding()
        command.present(drawable)
        command.commit()
    }
}
