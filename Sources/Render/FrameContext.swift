import Metal
import simd

struct FrameContext {
    let time: Float
    let deltaTime: Float
    let resolution: SIMD2<Float>
    let scaleFactor: Float
    let device: MTLDevice
    let pipelines: Pipelines
}
