import Metal
import simd

final class VitalsRingWidget: HUDElement {
    /// Must match `OrbElement.radius` so the vital rings sit just outside the orb.
    var orbRadius: Float = 0.18

    private struct Uniforms {
        var resolution: SIMD2<Float>
        var time: Float
        var radius: Float
        var battery: Float
        var cpuTemp: Float
        var fanRpm: Float
        var _pad0: Float = 0
    }

    private var battery: Float = 0.78
    private var cpuTemp: Float = 0.42
    private var fanRpm: Float = 0.35

    private var timeSinceTick: Float = 0
    private let tickInterval: Float = 0.25

    func update(context: FrameContext) {
        timeSinceTick += context.deltaTime
        if timeSinceTick >= tickInterval {
            timeSinceTick = 0
            battery = max(0.05, battery - 0.0008 + Float.random(in: -0.0002...0.0002))
            cpuTemp = max(0.05, min(0.95, cpuTemp + Float.random(in: -0.04...0.04)))
            fanRpm = max(0.05, min(0.95, 0.7 * fanRpm + 0.3 * cpuTemp + Float.random(in: -0.03...0.03)))
        }
    }

    func encode(into encoder: MTLRenderCommandEncoder, context: FrameContext) {
        var uniforms = Uniforms(
            resolution: context.resolution,
            time: context.time,
            radius: orbRadius,
            battery: battery,
            cpuTemp: cpuTemp,
            fanRpm: fanRpm
        )
        encoder.setRenderPipelineState(context.pipelines.vitals)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    }
}
