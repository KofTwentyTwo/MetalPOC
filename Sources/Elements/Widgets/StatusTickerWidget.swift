import Metal
import AppKit
import CoreText
import CoreGraphics
import simd

final class StatusTickerWidget: FramedHUDWidget {
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
    var revealDelay: Float = 0
    private var revealStart: Float = -1

    // Scroll state in points (continuous, sub-pixel). When > widget_width + cachedLineWidth,
    // the message has fully scrolled off the left and we switch to the next.
    private var scrollPositionPts: Float = 0
    private let scrollSpeedPtsPerSec: Float = 140   // tunable; 140pt/s ≈ smooth ticker pace

    private var textTexture: MTLTexture?
    private var cachedLineWidthPts: CGFloat = 0
    private let colorSpace = CGColorSpaceCreateDeviceRGB()

    func update(context: FrameContext) {
        if revealStart < 0 { revealStart = context.time + revealDelay }
        if context.time < revealStart { return }

        scrollPositionPts += scrollSpeedPtsPerSec * context.deltaTime

        // Widget width in points
        let widthPts = CGFloat(size.x) * CGFloat(context.resolution.x) / CGFloat(context.scaleFactor)
        // Switch message when fully scrolled past the left edge
        if CGFloat(scrollPositionPts) > widthPts + cachedLineWidthPts + 40 {
            scrollPositionPts = 0
            currentIndex = (currentIndex + 1) % messages.count
        }

        // Rebuild texture EVERY frame so the sub-pixel scroll position renders smoothly.
        rebuildText(context: context)
    }

    private func rebuildText(context: FrameContext) {
        let widthPts  = CGFloat(size.x) * CGFloat(context.resolution.x) / CGFloat(context.scaleFactor)
        let heightPts = CGFloat(size.y) * CGFloat(context.resolution.y) / CGFloat(context.scaleFactor)
        let scale = CGFloat(context.scaleFactor)

        let pixelWidth  = max(Int((widthPts  * scale).rounded(.up)), 1)
        let pixelHeight = max(Int((heightPts * scale).rounded(.up)), 1)
        let bytesPerRow = pixelWidth * 4

        guard let ctx = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue
                       | CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else { return }

        ctx.scaleBy(x: scale, y: scale)
        ctx.setShouldAntialias(true)
        ctx.setShouldSmoothFonts(true)

        // Build attributed string for the single-line ticker text.
        let font = NSFont(name: "ShareTechMono-Regular", size: 12)
            ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]
        let attributed = NSAttributedString(
            string: "▶  " + messages[currentIndex],
            attributes: attrs
        )

        // Measure the line so we know the actual rendered width for scroll completion check.
        let line = CTLineCreateWithAttributedString(attributed)
        let typoBounds = CTLineGetTypographicBounds(line, nil, nil, nil)
        cachedLineWidthPts = CGFloat(typoBounds)

        // Flip Y so text draws top-down. CoreText baseline goes through the origin point.
        ctx.translateBy(x: 0, y: heightPts)
        ctx.scaleBy(x: 1, y: -1)
        ctx.textMatrix = .identity

        // Sub-pixel-precise text origin: starts off the right edge, scrolls left over time.
        // y = baseline below top (font ascent ~10pt at 12pt size; center within widget height).
        let xPos = widthPts - CGFloat(scrollPositionPts)
        let yPos = heightPts * 0.5 - 4
        ctx.textPosition = CGPoint(x: xPos, y: yPos)
        CTLineDraw(line, ctx)

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: pixelWidth,
            height: pixelHeight,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead]
        descriptor.storageMode = .shared
        guard let tex = context.device.makeTexture(descriptor: descriptor),
              let data = ctx.data else { return }
        tex.replace(
            region: MTLRegionMake2D(0, 0, pixelWidth, pixelHeight),
            mipmapLevel: 0,
            withBytes: data,
            bytesPerRow: bytesPerRow
        )
        textTexture = tex
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
