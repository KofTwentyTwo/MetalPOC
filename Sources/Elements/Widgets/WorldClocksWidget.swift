import Metal
import AppKit
import Foundation
import simd

final class WorldClocksWidget: FramedHUDWidget {
    var origin: SIMD2<Float> = SIMD2(0.330, 0.895)
    var size:   SIMD2<Float> = SIMD2(0.340, 0.040)

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

    private struct Clock {
        let label: String
        let timeZoneID: String
    }
    private let clocks: [Clock] = [
        .init(label: "NYC", timeZoneID: "America/New_York"),
        .init(label: "LON", timeZoneID: "Europe/London"),
        .init(label: "TYO", timeZoneID: "Asia/Tokyo"),
        .init(label: "SYD", timeZoneID: "Australia/Sydney"),
    ]

    var revealDelay: Float = 0
    private var revealStart: Float = -1

    private var timeSinceUpdate: Float = 0
    private let updateInterval: Float = 1.0
    private var lastChangeTime: Float = -999
    private var textTexture: MTLTexture?
    private var textDirty = true

    func update(context: FrameContext) {
        if revealStart < 0 { revealStart = context.time + revealDelay }
        if context.time < revealStart { return }
        timeSinceUpdate += context.deltaTime
        if timeSinceUpdate >= updateInterval {
            timeSinceUpdate = 0
            textDirty = true
        }
        if textDirty {
            rebuildText(context: context)
            lastChangeTime = context.time
            textDirty = false
        }
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

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let now = Date()
        let parts = clocks.map { c -> String in
            formatter.timeZone = TimeZone(identifier: c.timeZoneID) ?? .current
            return "\(c.label) \(formatter.string(from: now))"
        }
        let microID = String(format: "0x%04X", abs(ObjectIdentifier(self).hashValue) & 0xFFFF)
        let microAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont(name: "ShareTechMono-Regular", size: 9) ?? NSFont.monospacedSystemFont(ofSize: 9, weight: .regular),
            .foregroundColor: NSColor(red: 0.20, green: 0.85, blue: 1.0, alpha: 0.40),
            .paragraphStyle: { let p = NSMutableParagraphStyle(); p.alignment = .right; return p }()
        ]
        let attributed = NSMutableAttributedString()
        attributed.append(NSAttributedString(string: "[ WORLD CLOCKS ]\n", attributes: titleAttrs))
        attributed.append(NSAttributedString(string: parts.joined(separator: "   "), attributes: bodyAttrs))
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
            tint: SIMD4<Float>(0.20, 0.85, 1.0, 1.0),
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
