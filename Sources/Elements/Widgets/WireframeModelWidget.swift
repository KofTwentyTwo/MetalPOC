import Metal
import simd

final class WireframeModelWidget: FramedHUDWidget {
    var origin: SIMD2<Float> = Theme.Layout.wireframeModel.origin
    var size:   SIMD2<Float> = Theme.Layout.wireframeModel.size
    var revealDelay: Float = Theme.Reveal.wireframeModel
    private var revealStart: Float = -1

    // Mirror of Metal ModelUniforms
    private struct Uniforms {
        var resolution:       SIMD2<Float>
        var origin:           SIMD2<Float>
        var size:             SIMD2<Float>
        var time:             Float
        var rotationDegPerSec: Float
    }

    func update(context: FrameContext) {
        if revealStart < 0 { revealStart = context.time + revealDelay }
    }

    func encode(into encoder: MTLRenderCommandEncoder, context: FrameContext) {
        guard context.time >= revealStart, revealStart >= 0 else { return }
        var u = Uniforms(
            resolution: context.resolution,
            origin: origin,
            size: size,
            time: context.time,
            rotationDegPerSec: Theme.Tick.modelRotationDegPerSec
        )
        encoder.setRenderPipelineState(context.pipelines.model)
        encoder.setVertexBytes(&u, length: MemoryLayout<Uniforms>.stride, index: 0)
        encoder.setFragmentBytes(&u, length: MemoryLayout<Uniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
    }
}
