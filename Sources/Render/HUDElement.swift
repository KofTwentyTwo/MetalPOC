import Metal
import simd

protocol HUDElement: AnyObject {
    func update(context: FrameContext)
    func encode(into encoder: MTLRenderCommandEncoder, context: FrameContext)
}

/// A `HUDElement` that has a rectangular frame in screen-normalized [0..1] coords.
/// Used by `HUDWindowController` to create per-widget `NSVisualEffectView` backdrops.
/// Orb / ornament / vitals / spectrum elements (purely procedural) do NOT conform.
protocol FramedHUDWidget: HUDElement {
    var origin: SIMD2<Float> { get }
    var size: SIMD2<Float> { get }
}
