import Metal
import simd

/// Per-frame argument bundle handed to every `HUDElement` during `update` and `encode`.
struct FrameContext {
    let time: Float            // seconds since renderer start
    let deltaTime: Float       // seconds since last frame
    let resolution: SIMD2<Float>   // drawable size in pixels
    let scaleFactor: Float          // backing scale (1 on non-Retina, 2 on Retina)
    let device: MTLDevice
}
