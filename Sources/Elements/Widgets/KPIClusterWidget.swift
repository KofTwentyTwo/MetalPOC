import Metal
import AppKit
import simd

final class KPIClusterWidget: FramedHUDWidget {
    // Screen-normalized [0..1] origin and size (bottom-left origin).
    var origin: SIMD2<Float> = Theme.Layout.kpiCluster.origin
    var size:   SIMD2<Float> = Theme.Layout.kpiCluster.size

    private struct Uniforms {
        var resolution: SIMD2<Float>
        var origin: SIMD2<Float>
        var size: SIMD2<Float>
        var tint: SIMD4<Float>
        var frameAlpha: Float
        var textAlpha: Float
        var time: Float
        var flashAge: Float = 999
    }

    private struct KPI {
        var label: String
        var value: Float    // 0..100
        var unit: String
        var history: [Float] = []
    }

    private var kpis: [KPI] = [
        KPI(label: "CPU", value: 32, unit: "%"),
        KPI(label: "GPU", value: 21, unit: "%"),
        KPI(label: "MEM", value: 58, unit: "%"),
        KPI(label: "NET", value: 12, unit: "MB/s"),
    ]
    var revealDelay: Float = 0
    private var revealStart: Float = -1

    private var timeSinceUpdate: Float = 0
    private let updateInterval: Float = Theme.Tick.kpiUpdateSec
    private var lastChangeTime: Float = -999

    private var textTexture: MTLTexture?
    private var textDirty = true

    func update(context: FrameContext) {
        if revealStart < 0 { revealStart = context.time + revealDelay }
        if context.time < revealStart { return }
        timeSinceUpdate += context.deltaTime
        if timeSinceUpdate >= updateInterval {
            timeSinceUpdate = 0
            advanceMockData()
            textDirty = true
        }
        if textDirty {
            rebuildText(context: context)
            lastChangeTime = context.time
            textDirty = false
        }
    }

    private func advanceMockData() {
        for i in kpis.indices {
            let drift = Float.random(in: -3.5...3.5)
            kpis[i].value = min(99, max(1, kpis[i].value + drift))
            kpis[i].history.append(kpis[i].value)
            if kpis[i].history.count > 20 { kpis[i].history.removeFirst() }
        }
    }

    private func barGauge(_ value: Float, max: Float, segments: Int = 10) -> String {
        let filled = Int((value / max) * Float(segments))
        let f = Swift.max(0, Swift.min(segments, filled))
        return String(repeating: "▰", count: f) + String(repeating: "▱", count: segments - f)
    }

    private func rebuildText(context: FrameContext) {
        let widthPts  = CGFloat(size.x) * CGFloat(context.resolution.x) / CGFloat(context.scaleFactor)
        let heightPts = CGFloat(size.y) * CGFloat(context.resolution.y) / CGFloat(context.scaleFactor)

        let bodyFont = Theme.Font.body(size: Theme.Font.widgetBodySize)
        let titleFont = Theme.Font.title(size: Theme.Font.widgetTitleSize)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 2

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: Theme.Palette.textWhite,
            .paragraphStyle: paragraph
        ]
        let bodyAttrs: [NSAttributedString.Key: Any] = [
            .font: bodyFont,
            .foregroundColor: Theme.Palette.textWhite,
            .paragraphStyle: paragraph
        ]
        let lines = kpis.map { kpi -> String in
            let bar = barGauge(kpi.value, max: 100)
            return String(format: "%@  %@  %5.1f%@", kpi.label, bar, kpi.value, kpi.unit)
        }
        let microID = String(format: "0x%04X", abs(ObjectIdentifier(self).hashValue) & 0xFFFF)
        let microAttrs: [NSAttributedString.Key: Any] = [
            .font: Theme.Font.body(size: Theme.Font.microReadoutSize),
            .foregroundColor: Theme.Palette.textMicroReadout,
            .paragraphStyle: { let p = NSMutableParagraphStyle(); p.alignment = .right; return p }()
        ]
        let attributed = NSMutableAttributedString()
        attributed.append(NSAttributedString(string: "[ SYS KPI ]\n", attributes: titleAttrs))
        attributed.append(NSAttributedString(string: lines.joined(separator: "\n"), attributes: bodyAttrs))
        attributed.append(NSAttributedString(string: "\n\(microID)", attributes: microAttrs))

        let kpisCopy = kpis  // capture for closure
        textTexture = context.textRasterizer.rasterize(
            attributed,
            maxSize: CGSize(width: widthPts, height: heightPts),
            scale: CGFloat(context.scaleFactor)
        ) { ctx, size in
            // Draw sparklines for each KPI row on the right side.
            let titleHeight: CGFloat = 20  // approx space for title line
            let lineHeight: CGFloat = 16   // approx per-row height
            let sparkW: CGFloat = 56       // width of sparkline area
            let sparkH: CGFloat = 9        // height of sparkline
            let sparkX: CGFloat = size.width - sparkW - 4  // right-aligned with small margin
            ctx.setStrokeColor(NSColor(red: CGFloat(Theme.Palette.cyanTint.x), green: CGFloat(Theme.Palette.cyanTint.y), blue: CGFloat(Theme.Palette.cyanTint.z), alpha: 0.65).cgColor)
            ctx.setLineWidth(0.75)
            ctx.setLineJoin(.round)
            for (i, kpi) in kpisCopy.enumerated() where kpi.history.count >= 2 {
                let rowY = titleHeight + CGFloat(i) * lineHeight + 3
                let pts = kpi.history.enumerated().map { (idx, val) -> CGPoint in
                    let x = sparkX + (CGFloat(idx) / CGFloat(max(kpi.history.count - 1, 1))) * sparkW
                    let norm = CGFloat(min(max(val / 100.0, 0.0), 1.0))
                    // CGContext y-down: rowY is top of row, sparkH down from there
                    let y = rowY + (1.0 - norm) * sparkH
                    return CGPoint(x: x, y: y)
                }
                ctx.beginPath()
                ctx.move(to: pts[0])
                for p in pts.dropFirst() { ctx.addLine(to: p) }
                ctx.strokePath()
            }
        }
    }

    func encode(into encoder: MTLRenderCommandEncoder, context: FrameContext) {
        guard let texture = textTexture else { return }
        var uniforms = Uniforms(
            resolution: context.resolution,
            origin: origin,
            size: size,
            tint: Theme.Palette.cyanTint,
            frameAlpha: 0.8,
            textAlpha: 1.0,
            time: context.time,
            flashAge: context.time - lastChangeTime
        )
        encoder.setRenderPipelineState(context.pipelines.widget)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
    }
}
