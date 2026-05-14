import Metal
import AppKit
import simd

final class ScheduleStripWidget: FramedHUDWidget {
    var origin: SIMD2<Float> = Theme.Layout.scheduleStrip.origin
    var size:   SIMD2<Float> = Theme.Layout.scheduleStrip.size

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

    private struct Event {
        var label: String
        var remaining: Float    // seconds
        var flashing: Float     // 0 if not flashing, >0 countdown of flash effect
    }

    private var events: [Event] = [
        Event(label: "STANDUP",    remaining: 90,  flashing: 0),
        Event(label: "DEPLOY OK",  remaining: 220, flashing: 0),
        Event(label: "BRIEF",      remaining: 460, flashing: 0),
    ]

    var revealDelay: Float = 0
    private var revealStart: Float = -1

    private var timeSinceRebuild: Float = 0
    private let rebuildInterval: Float = Theme.Tick.scheduleRedrawSec
    private var lastChangeTime: Float = -999
    private var textTexture: MTLTexture?

    func update(context: FrameContext) {
        if revealStart < 0 { revealStart = context.time + revealDelay }
        if context.time < revealStart { return }
        for i in events.indices {
            events[i].remaining -= context.deltaTime
            if events[i].remaining <= 0 && events[i].flashing == 0 {
                events[i].flashing = Theme.Tick.scheduleFlashDurSec
            }
            if events[i].flashing > 0 {
                events[i].flashing -= context.deltaTime
                if events[i].flashing <= 0 {
                    // Reset to a new future time.
                    events[i].remaining = Float.random(in: Theme.Tick.scheduleResetMinSec...Theme.Tick.scheduleResetMaxSec)
                    events[i].flashing = 0
                }
            }
        }
        timeSinceRebuild += context.deltaTime
        if timeSinceRebuild >= rebuildInterval {
            timeSinceRebuild = 0
            rebuildText(context: context)
            lastChangeTime = context.time
        }
    }

    private func format(_ remaining: Float) -> String {
        if remaining <= 0 { return "  NOW " }
        let total = Int(remaining)
        let m = total / 60
        let s = total % 60
        return String(format: "%02d:%02d", m, s)
    }

    private func rebuildText(context: FrameContext) {
        let widthPts  = CGFloat(size.x) * CGFloat(context.resolution.x) / CGFloat(context.scaleFactor)
        let heightPts = CGFloat(size.y) * CGFloat(context.resolution.y) / CGFloat(context.scaleFactor)

        // Sized to fill the widget body height after inset (~60pt usable on the
        // 76pt strip — 36pt font reads as the dominant content).
        let font = Theme.Font.body(size: Theme.Font.scheduleStripSize)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributed = NSMutableAttributedString()

        for (i, ev) in events.enumerated() {
            let pulsing = ev.flashing > 0
            let color: NSColor = pulsing
                ? Theme.Palette.textScheduleFlash
                : Theme.Palette.textWhite
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font, .foregroundColor: color, .paragraphStyle: paragraph
            ]
            let sep = (i == events.count - 1) ? "" : "     "
            let line = "\(format(ev.remaining)) ● \(ev.label)\(sep)"
            attributed.append(NSAttributedString(string: line, attributes: attrs))
        }

        let microID = String(format: "0x%04X", abs(ObjectIdentifier(self).hashValue) & 0xFFFF)
        let microAttrs: [NSAttributedString.Key: Any] = [
            .font: Theme.Font.body(size: Theme.Font.scheduleStripMicroSize),
            .foregroundColor: Theme.Palette.textMicroReadout,
            .paragraphStyle: { let p = NSMutableParagraphStyle(); p.alignment = .right; return p }()
        ]
        attributed.append(NSAttributedString(string: " \(microID)", attributes: microAttrs))

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
