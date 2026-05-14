import Metal
import simd

final class SpectrumBarsWidget: HUDElement {
    var orbRadius: Float = Theme.Orb.radius
    static let barCount = Theme.Tick.spectrumBarCount

    private struct Uniforms {
        var resolution: SIMD2<Float>
        var time: Float
        var radius: Float
        // 32 floats — matches the Metal shader's `float bars[32]`. SIMD-aligned via tuple.
        var bars: (Float, Float, Float, Float, Float, Float, Float, Float,
                   Float, Float, Float, Float, Float, Float, Float, Float,
                   Float, Float, Float, Float, Float, Float, Float, Float,
                   Float, Float, Float, Float, Float, Float, Float, Float)
    }

    // Current bar amplitudes (0..1) — animated.
    private var bars: [Float] = (0..<SpectrumBarsWidget.barCount).map { _ in Float.random(in: 0.1...0.6) }
    private var phases: [Float] = (0..<SpectrumBarsWidget.barCount).map { _ in Float.random(in: 0...Float.pi * 2) }
    private var freqs:  [Float] = (0..<SpectrumBarsWidget.barCount).map { _ in Float.random(in: 0.7...2.4) }

    private var timeSinceTick: Float = 0
    private let tickInterval: Float = Theme.Tick.spectrumUpdateSec

    func update(context: FrameContext) {
        timeSinceTick += context.deltaTime
        if timeSinceTick >= tickInterval {
            timeSinceTick = 0
            let t = context.time
            for i in 0..<SpectrumBarsWidget.barCount {
                // Envelope shape favors central frequencies.
                let bell = sin(Float(i + 1) * Float.pi / Float(SpectrumBarsWidget.barCount + 1))
                let oscillation = (sin(t * freqs[i] + phases[i]) * 0.5 + 0.5)
                let noise = Float.random(in: -0.05...0.05)
                bars[i] = max(0.05, min(1.0, 0.25 + bell * (0.55 * oscillation + 0.2) + noise))
            }
        }
    }

    func encode(into encoder: MTLRenderCommandEncoder, context: FrameContext) {
        // Build the Uniforms struct with the bars tuple.
        var uniforms = Uniforms(
            resolution: context.resolution,
            time: context.time,
            radius: orbRadius,
            bars: (bars[0],  bars[1],  bars[2],  bars[3],  bars[4],  bars[5],  bars[6],  bars[7],
                   bars[8],  bars[9],  bars[10], bars[11], bars[12], bars[13], bars[14], bars[15],
                   bars[16], bars[17], bars[18], bars[19], bars[20], bars[21], bars[22], bars[23],
                   bars[24], bars[25], bars[26], bars[27], bars[28], bars[29], bars[30], bars[31])
        )
        encoder.setRenderPipelineState(context.pipelines.spectrum)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    }
}
