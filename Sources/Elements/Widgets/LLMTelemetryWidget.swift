import Metal
import AppKit
import simd

final class LLMTelemetryWidget: HUDElement {
    var origin: SIMD2<Float> = SIMD2(0.760, 0.770)
    var size:   SIMD2<Float> = SIMD2(0.190, 0.120)

    private struct Uniforms {
        var resolution: SIMD2<Float>
        var origin: SIMD2<Float>
        var size: SIMD2<Float>
        var tint: SIMD4<Float>
        var frameAlpha: Float
        var textAlpha: Float
        var time: Float
        var _pad1: Float = 0
    }

    private var tokensPerSec: Float = 42
    private var contextUsed: Float = 6800     // tokens
    private let contextMax: Float = 128_000
    private var cumulativeCost: Float = 0.0072
    private var latencyMs: Float = 340
    private let models = ["claude-opus-4-7", "claude-sonnet-4-6", "claude-haiku-4-5"]
    private var modelIndex = 0
    private var timeSinceModelSwap: Float = 0
    private var timeSinceUpdate: Float = 0
    private let updateInterval: Float = 0.5  // 2 Hz

    private var textTexture: MTLTexture?
    private var textDirty = true

    func update(context: FrameContext) {
        timeSinceUpdate += context.deltaTime
        timeSinceModelSwap += context.deltaTime
        if timeSinceUpdate >= updateInterval {
            timeSinceUpdate = 0
            advanceMockData(deltaTime: updateInterval)
            textDirty = true
        }
        if timeSinceModelSwap >= 30 {
            timeSinceModelSwap = 0
            modelIndex = (modelIndex + 1) % models.count
            textDirty = true
        }
        if textDirty {
            rebuildText(context: context)
            textDirty = false
        }
    }

    private func advanceMockData(deltaTime: Float) {
        tokensPerSec = max(2, min(120, tokensPerSec + Float.random(in: -18...18)))
        contextUsed = min(contextMax, contextUsed + Float.random(in: -200...600))
        if contextUsed >= contextMax * 0.95 { contextUsed = 4000 }  // periodic reset
        cumulativeCost += Float.random(in: 0.0001...0.0009)
        latencyMs = max(80, min(1200, latencyMs + Float.random(in: -60...60)))
    }

    private func barGauge(_ fraction: Float, segments: Int = 10) -> String {
        let f = max(0, min(segments, Int(fraction * Float(segments))))
        return String(repeating: "▰", count: f) + String(repeating: "▱", count: segments - f)
    }

    private func rebuildText(context: FrameContext) {
        let widthPts  = CGFloat(size.x) * CGFloat(context.resolution.x) / CGFloat(context.scaleFactor)
        let heightPts = CGFloat(size.y) * CGFloat(context.resolution.y) / CGFloat(context.scaleFactor)

        let bodyFont  = NSFont(name: "ShareTechMono-Regular", size: 12) ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
        let titleFont = NSFont(name: "Orbitron-Bold", size: 13) ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .bold)
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: titleFont, .foregroundColor: NSColor.white
        ]
        let bodyAttrs: [NSAttributedString.Key: Any] = [
            .font: bodyFont, .foregroundColor: NSColor.white
        ]

        let ctxPct = (contextUsed / contextMax) * 100
        let body = """
        TOK/S    \(String(format: "%5.1f", tokensPerSec))
        CTX      \(barGauge(contextUsed / contextMax)) \(String(format: "%.1f", ctxPct))%
        COST     $\(String(format: "%.4f", cumulativeCost))
        LATENCY  \(String(format: "%.0f", latencyMs)) ms
        MODEL    \(models[modelIndex])
        """

        let attributed = NSMutableAttributedString()
        attributed.append(NSAttributedString(string: "[ LLM TELEMETRY ]\n", attributes: titleAttrs))
        attributed.append(NSAttributedString(string: body, attributes: bodyAttrs))
        textTexture = context.textRasterizer.rasterize(
            attributed,
            maxSize: CGSize(width: widthPts, height: heightPts),
            scale: CGFloat(context.scaleFactor)
        )
    }

    func encode(into encoder: MTLRenderCommandEncoder, context: FrameContext) {
        guard let texture = textTexture else { return }
        var uniforms = Uniforms(
            resolution: context.resolution,
            origin: origin,
            size: size,
            tint: SIMD4<Float>(0.20, 0.85, 1.0, 1.0),
            frameAlpha: 0.8,
            textAlpha: 1.0,
            time: context.time
        )
        encoder.setRenderPipelineState(context.pipelines.widget)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
    }
}
