import Metal

final class Pipelines {
    let ornament: MTLRenderPipelineState
    let orb: MTLRenderPipelineState
    let widget: MTLRenderPipelineState

    init(device: MTLDevice, library: MTLLibrary, colorPixelFormat: MTLPixelFormat) throws {
        self.ornament = try Pipelines.makePipeline(
            device: device, library: library, colorPixelFormat: colorPixelFormat,
            vertexFunctionName: "ornament_vertex", fragmentFunctionName: "ornament_fragment",
            label: "OrnamentPipeline")

        self.orb = try Pipelines.makePipeline(
            device: device, library: library, colorPixelFormat: colorPixelFormat,
            vertexFunctionName: "orb_vertex", fragmentFunctionName: "orb_fragment",
            label: "OrbPipeline")

        self.widget = try Pipelines.makePipeline(
            device: device, library: library, colorPixelFormat: colorPixelFormat,
            vertexFunctionName: "widget_vertex", fragmentFunctionName: "widget_fragment",
            label: "WidgetPipeline")
    }

    static func makePipeline(
        device: MTLDevice,
        library: MTLLibrary,
        colorPixelFormat: MTLPixelFormat,
        vertexFunctionName: String,
        fragmentFunctionName: String,
        label: String
    ) throws -> MTLRenderPipelineState {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.label = label
        descriptor.vertexFunction = library.makeFunction(name: vertexFunctionName)
        descriptor.fragmentFunction = library.makeFunction(name: fragmentFunctionName)

        let attachment = descriptor.colorAttachments[0]!
        attachment.pixelFormat = colorPixelFormat
        attachment.isBlendingEnabled = true
        attachment.rgbBlendOperation = .add
        attachment.alphaBlendOperation = .add
        attachment.sourceRGBBlendFactor = .one
        attachment.sourceAlphaBlendFactor = .one
        attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
        attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha

        return try device.makeRenderPipelineState(descriptor: descriptor)
    }
}
