import Metal

protocol HUDElement: AnyObject {
    func update(context: FrameContext)
    func encode(into encoder: MTLRenderCommandEncoder, context: FrameContext)
}
