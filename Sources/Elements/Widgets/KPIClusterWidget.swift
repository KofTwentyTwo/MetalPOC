import Metal
import AppKit
import simd

final class KPIClusterWidget: HUDElement {
    // Screen-normalized [0..1] origin and size (bottom-left origin).
    var origin: SIMD2<Float> = SIMD2(0.030, 0.870)
    var size:   SIMD2<Float> = SIMD2(0.180, 0.110)

    private struct Uniforms {
        var resolution: SIMD2<Float>
        var origin: SIMD2<Float>
        var size: SIMD2<Float>
        var tint: SIMD4<Float>
        var frameAlpha: Float
        var textAlpha: Float
        var _pad0: Float = 0
        var _pad1: Float = 0
    }

    private struct KPI {
        var label: String
        var value: Float    // 0..100
        var unit: String
    }

    private var kpis: [KPI] = [
        KPI(label: "CPU", value: 32, unit: "%"),
        KPI(label: "GPU", value: 21, unit: "%"),
        KPI(label: "MEM", value: 58, unit: "%"),
        KPI(label: "NET", value: 12, unit: "MB/s"),
    ]
    private var timeSinceUpdate: Float = 0
    private let updateInterval: Float = 0.5  // 2 Hz

    private var textTexture: MTLTexture?
    private var textDirty = true

    func update(context: FrameContext) {
        timeSinceUpdate += context.deltaTime
        if timeSinceUpdate >= updateInterval {
            timeSinceUpdate = 0
            advanceMockData()
            textDirty = true
        }
        if textDirty {
            rebuildText(context: context)
            textDirty = false
        }
    }

    private func advanceMockData() {
        for i in kpis.indices {
            let drift = Float.random(in: -3.5...3.5)
            kpis[i].value = min(99, max(1, kpis[i].value + drift))
        }
    }

    private func rebuildText(context: FrameContext) {
        let widthPts  = CGFloat(size.x) * CGFloat(context.resolution.x) / CGFloat(context.scaleFactor)
        let heightPts = CGFloat(size.y) * CGFloat(context.resolution.y) / CGFloat(context.scaleFactor)

        let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 2

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraph
        ]
        let lines = kpis.map { String(format: "%@   %5.1f%@", $0.label, $0.value, $0.unit) }
        let text = "[ SYS KPI ]\n" + lines.joined(separator: "\n")
        let attributed = NSAttributedString(string: text, attributes: attributes)

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
            textAlpha: 1.0
        )
        encoder.setRenderPipelineState(context.pipelines.widget)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
    }
}
