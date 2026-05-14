import Metal
import AppKit
import Foundation
import simd

final class LogStreamWidget: HUDElement {
    var origin: SIMD2<Float> = SIMD2(0.050, 0.290)
    var size:   SIMD2<Float> = SIMD2(0.260, 0.470)

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

    private struct Line {
        let level: String      // INFO / WARN / ERROR
        let timestamp: String
        let body: String
    }

    private let messagePool: [String] = [
        "Renderer encoded 11 elements",
        "Texture pool size: 240 KB",
        "Drawable acquired in 0.4 ms",
        "MTKView reported drawableSize change",
        "Frame budget: 16.6 ms",
        "Pipeline cache hit: widget",
        "CoreText raster cost: 0.2 ms",
        "Detected backing scale 2.0",
        "Floating window joined all spaces",
        "Ornament SDF AA factor recomputed",
        "Orb radius set to 0.18",
        "Status item menu opened",
        "Mock KPI tick complete",
        "Mock LLM telemetry: tok/s drifted",
        "Compass heading wrapped at 360°",
        "Spectrum buffer cycled",
        "Schedule countdown crossed boundary",
        "Status ticker advanced to slot 7",
        "Vitals: battery -0.03%",
        "Task list shuffled active task",
    ]

    private var lines: [Line] = []
    private let maxLines = 22

    private var timeSinceLine: Float = 0
    private var nextDelay: Float = 0.4
    private var lastChangeTime: Float = -999
    private var textTexture: MTLTexture?
    private var textDirty = false

    func update(context: FrameContext) {
        timeSinceLine += context.deltaTime
        if timeSinceLine >= nextDelay {
            timeSinceLine = 0
            nextDelay = Float.random(in: 0.30...1.10)
            appendLine()
            textDirty = true
        }
        if textDirty {
            rebuildText(context: context)
            lastChangeTime = context.time
            textDirty = false
        }
    }

    private func appendLine() {
        let now = Date()
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm:ss.SSS"
        let level: String
        let r = Float.random(in: 0...1)
        if r < 0.05 { level = "ERROR" }
        else if r < 0.20 { level = "WARN" }
        else { level = "INFO" }
        let body = messagePool.randomElement() ?? "..."
        let line = Line(level: level, timestamp: fmt.string(from: now), body: body)
        lines.insert(line, at: 0)
        if lines.count > maxLines { lines.removeLast(lines.count - maxLines) }
    }

    private func rebuildText(context: FrameContext) {
        let widthPts  = CGFloat(size.x) * CGFloat(context.resolution.x) / CGFloat(context.scaleFactor)
        let heightPts = CGFloat(size.y) * CGFloat(context.resolution.y) / CGFloat(context.scaleFactor)

        let font = NSFont(name: "ShareTechMono-Regular", size: 11) ?? NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 2

        let attributed = NSMutableAttributedString()
        let header: [NSAttributedString.Key: Any] = [
            .font: NSFont(name: "Orbitron-Bold", size: 13) ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .bold),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraph
        ]
        attributed.append(NSAttributedString(string: "[ LOG STREAM ]\n", attributes: header))

        for line in lines {
            let color: NSColor
            switch line.level {
            case "ERROR": color = NSColor(red: 1.0, green: 0.5, blue: 0.5, alpha: 1.0)
            case "WARN":  color = NSColor(red: 1.0, green: 0.85, blue: 0.4, alpha: 1.0)
            default:      color = NSColor.white
            }
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font, .foregroundColor: color, .paragraphStyle: paragraph
            ]
            let levelTag = "[\(line.level)]".padding(toLength: 7, withPad: " ", startingAt: 0)
            let composed = "\(line.timestamp) \(levelTag) \(line.body)\n"
            attributed.append(NSAttributedString(string: composed, attributes: attrs))
        }

        let microID = String(format: "0x%04X", abs(ObjectIdentifier(self).hashValue) & 0xFFFF)
        let microAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont(name: "ShareTechMono-Regular", size: 9) ?? NSFont.monospacedSystemFont(ofSize: 9, weight: .regular),
            .foregroundColor: NSColor(red: 0.20, green: 0.85, blue: 1.0, alpha: 0.40),
            .paragraphStyle: { let p = NSMutableParagraphStyle(); p.alignment = .right; return p }()
        ]
        attributed.append(NSAttributedString(string: "\n\(microID)", attributes: microAttrs))

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
            tint: SIMD4<Float>(1, 1, 1, 1),
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
