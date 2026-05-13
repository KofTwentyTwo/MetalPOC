import Metal
import simd

final class OrbElement: HUDElement {
    /// Orb radius in normalized vertical-axis units. Spec §7 wants the orb to read as the visual hero.
    var radius: Float = 0.18

    private struct Uniforms {
        var resolution: SIMD2<Float>
        var time: Float
        var radius: Float
    }

    func update(context: FrameContext) {}

    func encode(into encoder: MTLRenderCommandEncoder, context: FrameContext) {
        var uniforms = Uniforms(resolution: context.resolution, time: context.time, radius: radius)
        encoder.setRenderPipelineState(context.pipelines.orb)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    }
}
