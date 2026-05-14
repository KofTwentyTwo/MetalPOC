import Metal
import AppKit
import simd

final class CompassWidget: HUDElement {
    var origin: SIMD2<Float> = SIMD2(0.050, 0.170)
    var size:   SIMD2<Float> = SIMD2(0.220, 0.100)

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

    private var headingDeg: Float = 27   // bearing in degrees, 0..360
    private var driftRate: Float = 3     // deg/sec average rotation
    private var timeSinceUpdate: Float = 0
    private let updateInterval: Float = 0.25  // 4 Hz redraw

    private var textTexture: MTLTexture?
    private var textDirty = true

    func update(context: FrameContext) {
        let drift = driftRate * context.deltaTime + Float.random(in: -0.3...0.3)
        headingDeg = (headingDeg + drift).truncatingRemainder(dividingBy: 360)
        if headingDeg < 0 { headingDeg += 360 }
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

    private func cardinal(for heading: Float) -> String {
        let dirs = ["N","NE","E","SE","S","SW","W","NW"]
        let idx = Int(round(heading / 45.0)) % 8
        return dirs[idx]
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
        // Build a "tape" of bearings centered on the current heading: show 9 segments,
        // each 10° apart, with the center highlighted.
        let centerHeading = Int(headingDeg.rounded())
        var tape = ""
        for offset in stride(from: -40, through: 40, by: 10) {
            var deg = centerHeading + offset
            if deg < 0 { deg += 360 }
            deg %= 360
            let mark = (offset == 0) ? "▼" : "·"
            tape += "\(mark)\(String(format: "%03d", deg)) "
        }
        let bodyText = "\(String(format: "%05.1f° %@", headingDeg, cardinal(for: headingDeg)))\n\(tape.trimmingCharacters(in: .whitespaces))"
        let attributed = NSMutableAttributedString()
        attributed.append(NSAttributedString(string: "[ HEADING ]\n", attributes: titleAttrs))
        attributed.append(NSAttributedString(string: bodyText, attributes: bodyAttrs))

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
