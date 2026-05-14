import Metal
import AppKit
import simd

final class ScheduleStripWidget: HUDElement {
    var origin: SIMD2<Float> = SIMD2(0.300, 0.090)
    var size:   SIMD2<Float> = SIMD2(0.400, 0.045)

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

    private var timeSinceRebuild: Float = 0
    private let rebuildInterval: Float = 0.5  // 2 Hz redraw
    private var lastChangeTime: Float = -999
    private var textTexture: MTLTexture?

    func update(context: FrameContext) {
        for i in events.indices {
            events[i].remaining -= context.deltaTime
            if events[i].remaining <= 0 && events[i].flashing == 0 {
                events[i].flashing = 2.0
            }
            if events[i].flashing > 0 {
                events[i].flashing -= context.deltaTime
                if events[i].flashing <= 0 {
                    // Reset to a new future time.
                    events[i].remaining = Float.random(in: 120...600)
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

        let font = NSFont(name: "ShareTechMono-Regular", size: 13) ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .medium)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributed = NSMutableAttributedString()

        for (i, ev) in events.enumerated() {
            let pulsing = ev.flashing > 0
            let color: NSColor = pulsing
                ? NSColor(red: 1.0, green: 0.9, blue: 0.4, alpha: 1.0)
                : NSColor.white
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font, .foregroundColor: color, .paragraphStyle: paragraph
            ]
            let sep = (i == events.count - 1) ? "" : "     "
            let line = "\(format(ev.remaining)) ● \(ev.label)\(sep)"
            attributed.append(NSAttributedString(string: line, attributes: attrs))
        }

        let microID = String(format: "0x%04X", abs(ObjectIdentifier(self).hashValue) & 0xFFFF)
        let microAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont(name: "ShareTechMono-Regular", size: 8) ?? NSFont.monospacedSystemFont(ofSize: 8, weight: .regular),
            .foregroundColor: NSColor(red: 0.20, green: 0.85, blue: 1.0, alpha: 0.40),
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
