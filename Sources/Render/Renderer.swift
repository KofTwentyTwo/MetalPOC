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
    // Glitch fires at a random interval averaging ~10 minutes (range 8–12 min).
    // Brief burst — fades over ~0.15s.
    private var nextGlitchAt: Float = .random(in: 480...720)  // 8–12 min from launch
    private var lastGlitchFiredAt: Float = -1
    private let glitchBurstDuration: Float = 0.15

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

        // Compute glitch amount: fires once per scheduled interval, fading over
        // `glitchBurstDuration`. After firing, schedule the next at a fresh random time.
        let glitchAmount: Float
        if elapsed >= nextGlitchAt {
            if lastGlitchFiredAt < 0 {
                // First moment we cross the threshold — record fire time.
                lastGlitchFiredAt = elapsed
            }
            let burstAge = elapsed - lastGlitchFiredAt
            if burstAge < glitchBurstDuration {
                glitchAmount = 1.0 - (burstAge / glitchBurstDuration)
            } else {
                // Burst finished — schedule next glitch 8–12 min from now and arm.
                nextGlitchAt = elapsed + .random(in: 480...720)
                lastGlitchFiredAt = -1
                glitchAmount = 0
            }
        } else {
            glitchAmount = 0
        }

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
