import Metal
import AppKit
import Foundation
import simd

final class LocalNetworkWidget: FramedHUDWidget {
    var origin: SIMD2<Float> = Theme.Layout.localNetwork.origin
    var size:   SIMD2<Float> = Theme.Layout.localNetwork.size

    var revealDelay: Float = Theme.Reveal.localNetwork
    private var revealStart: Float = -1

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

    private var textTexture: MTLTexture?
    private var timeSinceRebuild: Float = 0
    private var textDirty = true

    func update(context: FrameContext) {
        if revealStart < 0 { revealStart = context.time + revealDelay }
        if context.time < revealStart { return }
        timeSinceRebuild += context.deltaTime
        if timeSinceRebuild >= Theme.LocalNetwork.refreshSec {
            timeSinceRebuild = 0
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

        let titleFont = Theme.Font.title(size: Theme.Font.widgetTitleSize)
        let bodyFont  = Theme.Font.body(size: Theme.Font.widgetBodySize)
        let microFont = Theme.Font.body(size: Theme.Font.microReadoutSize)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 2

        let attributed = NSMutableAttributedString()

        // Title
        attributed.append(NSAttributedString(string: "[ LOCAL NETWORK ]\n", attributes: [
            .font: titleFont,
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraph
        ]))

        // Mac location — place name
        let placeName = LocationProvider.shared.placeName
        attributed.append(NSAttributedString(string: "HERE     \(placeName)\n", attributes: [
            .font: bodyFont,
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraph
        ]))

        // Coordinates (or awaiting-permission note)
        let coordsLine: String
        if let loc = LocationProvider.shared.currentLocation {
            coordsLine = String(format: "%.2f°, %.2f°", loc.coordinate.latitude, loc.coordinate.longitude)
        } else {
            coordsLine = "(awaiting permission)"
        }
        attributed.append(NSAttributedString(string: "         \(coordsLine)\n", attributes: [
            .font: microFont,
            .foregroundColor: Theme.Palette.textMicroReadout,
            .paragraphStyle: paragraph
        ]))

        // Phone presence
        let phoneHere = Theme.LocalNetwork.myPhoneNamePatterns.contains { pattern in
            NetworkScanner.shared.hasDevice(matching: pattern)
        }
        let phoneLabel = phoneHere ? "● HERE" : "○ AWAY"
        let phoneColor: NSColor = phoneHere
            ? NSColor(red: 0.60, green: 1.0, blue: 0.8, alpha: 1.0)
            : NSColor(red: 1.0, green: 0.55, blue: 0.55, alpha: 1.0)
        attributed.append(NSAttributedString(string: "PHONE    \(phoneLabel)\n", attributes: [
            .font: bodyFont,
            .foregroundColor: phoneColor,
            .paragraphStyle: paragraph
        ]))

        // Device count header
        let devices = NetworkScanner.shared.currentDevices()
        let totalCount = devices.count
        attributed.append(NSAttributedString(string: "DEVICES  \(totalCount) on LAN\n", attributes: [
            .font: bodyFont,
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraph
        ]))

        // Individual device names (capped)
        let shown = devices.prefix(Theme.LocalNetwork.maxDevicesShown)
        for device in shown {
            let truncated = device.name.count > 28
                ? String(device.name.prefix(28)) + "…"
                : device.name
            attributed.append(NSAttributedString(string: "  \(truncated)\n", attributes: [
                .font: bodyFont,
                .foregroundColor: NSColor(white: 0.75, alpha: 1.0),
                .paragraphStyle: paragraph
            ]))
        }
        if totalCount > Theme.LocalNetwork.maxDevicesShown {
            let extra = totalCount - Theme.LocalNetwork.maxDevicesShown
            attributed.append(NSAttributedString(string: "  + \(extra) more\n", attributes: [
                .font: bodyFont,
                .foregroundColor: Theme.Palette.textMicroReadout,
                .paragraphStyle: paragraph
            ]))
        }

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
            tint: SIMD4(1, 1, 1, 1),
            frameAlpha: 0.8,
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
