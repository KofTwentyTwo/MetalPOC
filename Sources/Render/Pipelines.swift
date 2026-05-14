import Metal

final class Pipelines {
    let ornament: MTLRenderPipelineState
    let orb: MTLRenderPipelineState
    let widget: MTLRenderPipelineState
    let vitals: MTLRenderPipelineState
    let spectrum: MTLRenderPipelineState
    let glitch: MTLRenderPipelineState

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

        self.vitals = try Pipelines.makePipeline(
            device: device, library: library, colorPixelFormat: colorPixelFormat,
            vertexFunctionName: "vitals_vertex", fragmentFunctionName: "vitals_fragment",
            label: "VitalsPipeline")

        self.spectrum = try Pipelines.makePipeline(
            device: device, library: library, colorPixelFormat: colorPixelFormat,
            vertexFunctionName: "spectrum_vertex", fragmentFunctionName: "spectrum_fragment",
            label: "SpectrumPipeline")

        // Glitch post-process: draws to the drawable using .bgra8Unorm since it
        // samples from the intermediate texture (not blended over transparency).
        let glitchDesc = MTLRenderPipelineDescriptor()
        glitchDesc.label = "GlitchPipeline"
        glitchDesc.vertexFunction = library.makeFunction(name: "glitch_vertex")
        glitchDesc.fragmentFunction = library.makeFunction(name: "glitch_fragment")
        glitchDesc.colorAttachments[0].pixelFormat = colorPixelFormat
        glitchDesc.colorAttachments[0].isBlendingEnabled = false
        self.glitch = try device.makeRenderPipelineState(descriptor: glitchDesc)
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
