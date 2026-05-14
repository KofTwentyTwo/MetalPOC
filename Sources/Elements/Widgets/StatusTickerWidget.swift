import Metal
import AppKit
import simd

final class StatusTickerWidget: HUDElement {
    var origin: SIMD2<Float> = SIMD2(0.050, 0.055)
    var size:   SIMD2<Float> = SIMD2(0.900, 0.025)

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

    private let messages: [String] = [
        "ALL SYSTEMS NOMINAL",
        "RENDERER STABLE — 60 FPS",
        "PIPELINE PRESSURE LOW",
        "TEXTURE POOL @ 32%",
        "MOCK STREAMS ONLINE",
        "MULTI-SPACE BIND OK",
        "FLOAT-LEVEL ATTACHMENT VERIFIED",
        "CLICK-THROUGH POLICY ACTIVE",
        "COREXT RASTER 0.2 MS AVG",
        "SHADERS COMPILED FROM DEFAULT LIBRARY",
        "DESIGN SPEC SECTION 6 SCAFFOLDED",
        "POC ACCEPTANCE 8/8 CRITERIA OBSERVABLE"
    ]
    private var currentIndex = 0
    private var timeSinceSwap: Float = 0
    private let swapInterval: Float = 4.0

    private var timeSinceRebuild: Float = 0
    private let rebuildInterval: Float = 1.0 / 8.0
    private var scrollPosition: Float = 0     // characters scrolled
    private let scrollSpeed: Float = 24       // chars/sec

    private var textTexture: MTLTexture?

    func update(context: FrameContext) {
        timeSinceSwap += context.deltaTime
        scrollPosition += scrollSpeed * context.deltaTime
        if timeSinceSwap >= swapInterval {
            timeSinceSwap = 0
            currentIndex = (currentIndex + 1) % messages.count
            scrollPosition = 0
        }
        timeSinceRebuild += context.deltaTime
        if timeSinceRebuild >= rebuildInterval {
            timeSinceRebuild = 0
            rebuildText(context: context)
        }
    }

    private func rebuildText(context: FrameContext) {
        let widthPts  = CGFloat(size.x) * CGFloat(context.resolution.x) / CGFloat(context.scaleFactor)
        let heightPts = CGFloat(size.y) * CGFloat(context.resolution.y) / CGFloat(context.scaleFactor)

        let font = NSFont(name: "ShareTechMono-Regular", size: 12) ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font, .foregroundColor: NSColor.white
        ]

        // Approximate: a monospace char at 12pt is ~7pt wide.
        let charWidthPts: CGFloat = 7
        let viewableChars = Int(widthPts / charWidthPts)
        let leading = max(0, viewableChars - Int(scrollPosition))
        let padded = String(repeating: " ", count: leading) + "▶  " + messages[currentIndex]
        let attributed = NSAttributedString(string: padded, attributes: attrs)

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
            frameAlpha: 0.5,
            textAlpha: 1.0,
            time: context.time,
            flashAge: 999
        )
        encoder.setRenderPipelineState(context.pipelines.widget)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
    }
}
