import Metal
import AppKit
import simd

final class CompassWidget: FramedHUDWidget {
    var origin: SIMD2<Float> = Theme.Layout.compass.origin
    var size:   SIMD2<Float> = Theme.Layout.compass.size

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

    private var headingDeg: Float = 27   // bearing in degrees, 0..360
    private var driftRate: Float = Theme.Tick.compassDriftDegPerSec
    var revealDelay: Float = 0
    private var revealStart: Float = -1

    private var timeSinceUpdate: Float = 0
    private let updateInterval: Float = Theme.Tick.compassRedrawSec
    private var lastChangeTime: Float = -999

    private var textTexture: MTLTexture?
    private var textDirty = true

    func update(context: FrameContext) {
        if revealStart < 0 { revealStart = context.time + revealDelay }
        if context.time < revealStart { return }
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
            lastChangeTime = context.time
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

        let bodyFont  = Theme.Font.body(size: Theme.Font.compassBodySize)
        let titleFont = Theme.Font.title(size: Theme.Font.widgetTitleSize)
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: titleFont, .foregroundColor: Theme.Palette.textWhite
        ]
        let bodyAttrs: [NSAttributedString.Key: Any] = [
            .font: bodyFont, .foregroundColor: Theme.Palette.textWhite
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
        let microID = String(format: "0x%04X", abs(ObjectIdentifier(self).hashValue) & 0xFFFF)
        let microAttrs: [NSAttributedString.Key: Any] = [
            .font: Theme.Font.body(size: Theme.Font.microReadoutSize),
            .foregroundColor: Theme.Palette.textMicroReadout,
            .paragraphStyle: { let p = NSMutableParagraphStyle(); p.alignment = .right; return p }()
        ]
        let attributed = NSMutableAttributedString()
        attributed.append(NSAttributedString(string: "[ HEADING ]\n", attributes: titleAttrs))
        attributed.append(NSAttributedString(string: bodyText, attributes: bodyAttrs))
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
