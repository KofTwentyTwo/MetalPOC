import Metal
import AppKit
import simd

final class TaskListWidget: FramedHUDWidget {
    var origin: SIMD2<Float> = SIMD2(0.690, 0.290)
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

    private struct Task {
        var title: String
        var status: String          // PENDING / ACTIVE / BLOCKED / DONE
        var progress: Float         // 0..1 — only meaningful when ACTIVE
    }

    private var tasks: [Task] = [
        Task(title: "Wire renderer pipeline state",  status: "DONE",    progress: 1.0),
        Task(title: "Compose orb shader",            status: "DONE",    progress: 1.0),
        Task(title: "Implement widget pipeline",     status: "DONE",    progress: 1.0),
        Task(title: "Build log widget",              status: "ACTIVE",  progress: 0.62),
        Task(title: "Wire schedule countdown",       status: "PENDING", progress: 0.0),
        Task(title: "Spectrum bars FFT mock",        status: "PENDING", progress: 0.0),
        Task(title: "Status ticker scrolling logic", status: "BLOCKED", progress: 0.0),
        Task(title: "Visual acceptance test pass",   status: "PENDING", progress: 0.0),
    ]

    var revealDelay: Float = 0
    private var revealStart: Float = -1

    private var timeSinceFlip: Float = 0
    private let flipInterval: Float = 8.0
    private var lastChangeTime: Float = -999
    private var textTexture: MTLTexture?
    private var textDirty = true

    func update(context: FrameContext) {
        if revealStart < 0 { revealStart = context.time + revealDelay }
        if context.time < revealStart { return }
        timeSinceFlip += context.deltaTime
        if timeSinceFlip >= flipInterval {
            timeSinceFlip = 0
            shuffleStatus()
            textDirty = true
        }
        // Progress animates continuously on the active task.
        if let activeIdx = tasks.firstIndex(where: { $0.status == "ACTIVE" }) {
            tasks[activeIdx].progress = min(1.0, tasks[activeIdx].progress + context.deltaTime * 0.04)
            if tasks[activeIdx].progress >= 1.0 {
                tasks[activeIdx].status = "DONE"
                if let nextIdx = tasks.firstIndex(where: { $0.status == "PENDING" }) {
                    tasks[nextIdx].status = "ACTIVE"
                    tasks[nextIdx].progress = 0
                }
                textDirty = true
            }
            // Always redraw progress at 4 Hz to keep the percentage feeling alive.
            if Int(context.time * 4) != lastRenderedSecondTick {
                lastRenderedSecondTick = Int(context.time * 4)
                textDirty = true
            }
        }
        if textDirty {
            rebuildText(context: context)
            lastChangeTime = context.time
            textDirty = false
        }
    }

    private var lastRenderedSecondTick: Int = -1

    private func shuffleStatus() {
        // 50% chance: revive a DONE task back to PENDING
        if Bool.random() {
            if let doneIdx = tasks.indices.filter({ tasks[$0].status == "DONE" }).randomElement() {
                tasks[doneIdx].status = "PENDING"
                tasks[doneIdx].progress = 0
            }
        }
        // Existing logic (PENDING↔BLOCKED swap)
        guard let pending = tasks.indices.filter({ tasks[$0].status == "PENDING" }).randomElement(),
              let blocked = tasks.indices.filter({ tasks[$0].status == "BLOCKED" }).randomElement() else { return }
        if Bool.random() {
            tasks[blocked].status = "PENDING"
            tasks[pending].status = "BLOCKED"
        }
    }

    private func rebuildText(context: FrameContext) {
        let widthPts  = CGFloat(size.x) * CGFloat(context.resolution.x) / CGFloat(context.scaleFactor)
        let heightPts = CGFloat(size.y) * CGFloat(context.resolution.y) / CGFloat(context.scaleFactor)

        let font = NSFont(name: "ShareTechMono-Regular", size: 11) ?? NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3

        let attributed = NSMutableAttributedString()
        let header: [NSAttributedString.Key: Any] = [
            .font: NSFont(name: "Orbitron-Bold", size: 13) ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .bold),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraph
        ]
        attributed.append(NSAttributedString(string: "[ OPEN TASKS ]\n", attributes: header))

        for task in tasks {
            let color: NSColor
            switch task.status {
            case "DONE":    color = NSColor(white: 0.55, alpha: 1.0)
            case "ACTIVE":  color = NSColor(red: 0.6, green: 1.0, blue: 0.8, alpha: 1.0)
            case "BLOCKED": color = NSColor(red: 1.0, green: 0.55, blue: 0.55, alpha: 1.0)
            default:        color = NSColor.white
            }
            let dot: String
            switch task.status {
            case "DONE":    dot = "●"
            case "ACTIVE":  dot = "◉"
            case "BLOCKED": dot = "◍"
            default:        dot = "○"
            }
            let tag = "[\(task.status)]".padding(toLength: 9, withPad: " ", startingAt: 0)
            let progressLabel = task.status == "ACTIVE" ? String(format: " %3d%%", Int(task.progress * 100)) : ""
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font, .foregroundColor: color, .paragraphStyle: paragraph
            ]
            let line = "\(dot) \(tag)\(progressLabel)  \(task.title)\n"
            attributed.append(NSAttributedString(string: line, attributes: attrs))
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
