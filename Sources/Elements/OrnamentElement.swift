import Metal
import simd

final class OrnamentElement: HUDElement {
    private struct Uniforms {
        var resolution: SIMD2<Float>
        var time: Float
        var _pad: Float = 0
    }

    func update(context: FrameContext) {}

    func encode(into encoder: MTLRenderCommandEncoder, context: FrameContext) {
        var uniforms = Uniforms(resolution: context.resolution, time: context.time)
        encoder.setRenderPipelineState(context.pipelines.ornament)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    }
}
