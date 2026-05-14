import MetalKit
import simd

final class Renderer: NSObject, MTKViewDelegate {
    var scene: [HUDElement] = []

    private let device: MTLDevice
    private let queue: MTLCommandQueue
    private let pipelines: Pipelines
    private let textRasterizer: TextRasterizer
    private let startTime: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
    private var lastFrameTime: CFAbsoluteTime

    // Glitch post-process state
    private var intermediateTexture: MTLTexture?
    private var intermediateSize: CGSize = .zero
    // Glitch fires every ~12s for a brief burst (fade over ~0.15s).
    private let glitchPeriod: Float = 12.0

    init?(view: MTKView) {
        guard let device = view.device,
              let queue = device.makeCommandQueue(),
              let library = device.makeDefaultLibrary() else {
            return nil
        }
        do {
            self.pipelines = try Pipelines(
                device: device,
                library: library,
                colorPixelFormat: view.colorPixelFormat
            )
        } catch {
            print("Failed to build pipelines: \(error)")
            return nil
        }
        self.device = device
        self.queue = queue
        self.textRasterizer = TextRasterizer(device: device)
        self.lastFrameTime = CFAbsoluteTimeGetCurrent()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        intermediateTexture = nil  // invalidate so it gets rebuilt
    }

    private func ensureIntermediateTexture(size: CGSize, pixelFormat: MTLPixelFormat) {
        if intermediateTexture != nil && intermediateSize == size { return }
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: Int(size.width),
            height: Int(size.height),
            mipmapped: false
        )
        desc.usage = [.renderTarget, .shaderRead]
        desc.storageMode = .private
        intermediateTexture = device.makeTexture(descriptor: desc)
        intermediateSize = size
    }

    func draw(in view: MTKView) {
        let now = CFAbsoluteTimeGetCurrent()
        let deltaTime = Float(now - lastFrameTime)
        lastFrameTime = now
        let elapsed = Float(now - startTime)

        let context = FrameContext(
            time: elapsed,
            deltaTime: deltaTime,
            resolution: SIMD2<Float>(Float(view.drawableSize.width), Float(view.drawableSize.height)),
            scaleFactor: Float(view.window?.backingScaleFactor ?? 1.0),
            device: device,
            pipelines: pipelines,
            textRasterizer: textRasterizer
        )

        for element in scene {
            element.update(context: context)
        }

        guard let drawable = view.currentDrawable,
              let drawableDescriptor = view.currentRenderPassDescriptor,
              let command = queue.makeCommandBuffer() else {
            return
        }

        // Compute glitch amount: once per glitchPeriod, a 1-frame pulse.
        // glitchPhase ∈ [0,1) — when near 0 we fire the effect.
        let glitchPhase = elapsed.truncatingRemainder(dividingBy: glitchPeriod) / glitchPeriod
        // Fire window: 0..0.012 within each period (~150ms window at 12s period).
        let glitchAmount: Float = glitchPhase < 0.012 ? (1.0 - glitchPhase / 0.012) : 0.0

        if glitchAmount > 0.01 {
            // Two-pass: render scene to intermediate, then apply glitch to drawable.
            ensureIntermediateTexture(size: view.drawableSize, pixelFormat: view.colorPixelFormat)
            guard let intermediate = intermediateTexture else {
                // Fallback: single pass, no glitch
                guard let encoder = command.makeRenderCommandEncoder(descriptor: drawableDescriptor) else { return }
                for element in scene { element.encode(into: encoder, context: context) }
                encoder.endEncoding()
                command.present(drawable)
                command.commit()
                return
            }

            // Pass 1: render scene to intermediate texture (clear to transparent black).
            let offscreenDesc = MTLRenderPassDescriptor()
            offscreenDesc.colorAttachments[0].texture = intermediate
            offscreenDesc.colorAttachments[0].loadAction = .clear
            offscreenDesc.colorAttachments[0].storeAction = .store
            offscreenDesc.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)

            guard let pass1 = command.makeRenderCommandEncoder(descriptor: offscreenDesc) else { return }
            for element in scene { element.encode(into: pass1, context: context) }
            pass1.endEncoding()

            // Pass 2: apply glitch to drawable.
            guard let pass2 = command.makeRenderCommandEncoder(descriptor: drawableDescriptor) else { return }
            struct GlitchUniforms { var glitchAmount: Float; var time: Float; var _pad: SIMD2<Float> = .zero }
            var gu = GlitchUniforms(glitchAmount: glitchAmount, time: elapsed)
            pass2.setRenderPipelineState(pipelines.glitch)
            pass2.setFragmentBytes(&gu, length: MemoryLayout<GlitchUniforms>.stride, index: 0)
            pass2.setFragmentTexture(intermediate, index: 0)
            pass2.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            pass2.endEncoding()
        } else {
            // No glitch — render directly to the drawable (normal path).
            guard let encoder = command.makeRenderCommandEncoder(descriptor: drawableDescriptor) else { return }
            for element in scene { element.encode(into: encoder, context: context) }
            encoder.endEncoding()
        }

        command.present(drawable)
        command.commit()
    }
}
