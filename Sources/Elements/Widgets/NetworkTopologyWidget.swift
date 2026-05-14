import Metal
import simd

final class NetworkTopologyWidget: FramedHUDWidget {
    var origin: SIMD2<Float> = Theme.Layout.networkTopology.origin
    var size:   SIMD2<Float> = Theme.Layout.networkTopology.size
    var revealDelay: Float = Theme.Reveal.networkTopology
    private var revealStart: Float = -1

    // Mirror of Metal TopologyUniforms — kTopoMaxNodes=12, kTopoMaxEdges=16
    private struct Uniforms {
        var resolution: SIMD2<Float>
        var origin:     SIMD2<Float>
        var size:       SIMD2<Float>
        var nodeCount:  Int32
        var edgeCount:  Int32
        var time:       Float
        var pulseSpeed: Float
        // 12 nodes × 16 bytes each (float4)
        var nodes: (
            SIMD4<Float>, SIMD4<Float>, SIMD4<Float>, SIMD4<Float>,
            SIMD4<Float>, SIMD4<Float>, SIMD4<Float>, SIMD4<Float>,
            SIMD4<Float>, SIMD4<Float>, SIMD4<Float>, SIMD4<Float>
        )
        // 16 edges × 16 bytes each (int4)
        var edges: (
            SIMD4<Int32>, SIMD4<Int32>, SIMD4<Int32>, SIMD4<Int32>,
            SIMD4<Int32>, SIMD4<Int32>, SIMD4<Int32>, SIMD4<Int32>,
            SIMD4<Int32>, SIMD4<Int32>, SIMD4<Int32>, SIMD4<Int32>,
            SIMD4<Int32>, SIMD4<Int32>, SIMD4<Int32>, SIMD4<Int32>
        )
    }

    // Hub-and-spoke: center hub + 7 satellites
    private let nodePositions: [SIMD2<Float>] = [
        SIMD2(0.50, 0.50),   // 0: hub
        SIMD2(0.20, 0.30),   // 1
        SIMD2(0.50, 0.20),   // 2
        SIMD2(0.80, 0.30),   // 3
        SIMD2(0.85, 0.65),   // 4
        SIMD2(0.65, 0.85),   // 5
        SIMD2(0.35, 0.85),   // 6
        SIMD2(0.15, 0.65),   // 7
    ]
    private let edgesList: [(Int32, Int32)] = [
        (0, 1), (0, 2), (0, 3), (0, 4), (0, 5), (0, 6), (0, 7),  // hub spokes
        (1, 2), (3, 4), (5, 6), (7, 1)                              // ring connections
    ]
    private var statuses: [Float]
    private var timeSinceFlip: Float = 0

    init() {
        statuses = Array(repeating: 0, count: 8)
    }

    func update(context: FrameContext) {
        if revealStart < 0 { revealStart = context.time + revealDelay }
        if context.time < revealStart { return }
        timeSinceFlip += context.deltaTime
        if timeSinceFlip > 4.0 {
            timeSinceFlip = 0
            let idx = Int.random(in: 0..<statuses.count)
            let roll = Float.random(in: 0...1)
            statuses[idx] = roll < 0.75 ? 0 : (roll < 0.95 ? 1 : 2)
        }
    }

    func encode(into encoder: MTLRenderCommandEncoder, context: FrameContext) {
        guard context.time >= revealStart, revealStart >= 0 else { return }

        let nodeCount = nodePositions.count  // 8
        // Pad to 12
        var n12: [SIMD4<Float>] = nodePositions.enumerated().map { (i, pos) in
            SIMD4<Float>(pos.x, pos.y, i < statuses.count ? statuses[i] : 0, 0)
        }
        while n12.count < 12 { n12.append(SIMD4<Float>(0, 0, 0, 0)) }

        let edgeCount = edgesList.count  // 11
        // Pad to 16
        var e16: [SIMD4<Int32>] = edgesList.map { SIMD4<Int32>($0.0, $0.1, 0, 0) }
        while e16.count < 16 { e16.append(SIMD4<Int32>(0, 0, 0, 0)) }

        var u = Uniforms(
            resolution: context.resolution,
            origin: origin,
            size: size,
            nodeCount: Int32(nodeCount),
            edgeCount: Int32(edgeCount),
            time: context.time,
            pulseSpeed: Theme.Tick.topologyFlowSpeedPerSec,
            nodes: (n12[0],  n12[1],  n12[2],  n12[3],
                    n12[4],  n12[5],  n12[6],  n12[7],
                    n12[8],  n12[9],  n12[10], n12[11]),
            edges: (e16[0],  e16[1],  e16[2],  e16[3],
                    e16[4],  e16[5],  e16[6],  e16[7],
                    e16[8],  e16[9],  e16[10], e16[11],
                    e16[12], e16[13], e16[14], e16[15])
        )
        encoder.setRenderPipelineState(context.pipelines.topology)
        encoder.setVertexBytes(&u, length: MemoryLayout<Uniforms>.stride, index: 0)
        encoder.setFragmentBytes(&u, length: MemoryLayout<Uniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
    }
}
