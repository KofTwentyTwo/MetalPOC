import Metal
import AppKit
import Foundation
import simd

final class WorldClocksWidget: HUDElement {
    var origin: SIMD2<Float> = SIMD2(0.380, 0.880)
    var size:   SIMD2<Float> = SIMD2(0.240, 0.080)

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

    private var timeSinceUpdate: Float = 0
    private let updateInterval: Float = 1.0
    private var textTexture: MTLTexture?
    private var textDirty = true

    func update(context: FrameContext) {
        timeSinceUpdate += context.deltaTime
        if timeSinceUpdate >= updateInterval {
            timeSinceUpdate = 0
            textDirty = true
        }
        if textDirty {
            rebuildText(context: context)
            textDirty = false
        }
    }

    private func rebuildText(context: FrameContext) {
        let widthPts  = CGFloat(size.x) * CGFloat(context.resolution.x) / CGFloat(context.scaleFactor)
        let heightPts = CGFloat(size.y) * CGFloat(context.resolution.y) / CGFloat(context.scaleFactor)

        let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font, .foregroundColor: NSColor.white
        ]

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let now = Date()
        let parts = clocks.map { c -> String in
            formatter.timeZone = TimeZone(identifier: c.timeZoneID) ?? .current
            return "\(c.label) \(formatter.string(from: now))"
        }
        let text = "[ WORLD CLOCKS ]\n" + parts.joined(separator: "   ")
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
