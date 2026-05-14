import Metal
import simd

final class ForceGraphWidget: FramedHUDWidget {
    var origin: SIMD2<Float> = Theme.Layout.forceGraph.origin
    var size:   SIMD2<Float> = Theme.Layout.forceGraph.size
    var revealDelay: Float = Theme.Reveal.forceGraph
    private var revealStart: Float = -1

    // Mirror of Metal GraphUniforms — must match kGraphMaxNodes=16, kGraphMaxEdges=24
    private struct Uniforms {
        var resolution: SIMD2<Float>
        var origin:     SIMD2<Float>
        var size:       SIMD2<Float>
        var nodeCount:  Int32
        var edgeCount:  Int32
        var time:       Float
        var _pad:       Float = 0
        // 16 nodes × 16 bytes each (float4)
        var nodes: (
            SIMD4<Float>, SIMD4<Float>, SIMD4<Float>, SIMD4<Float>,
            SIMD4<Float>, SIMD4<Float>, SIMD4<Float>, SIMD4<Float>,
            SIMD4<Float>, SIMD4<Float>, SIMD4<Float>, SIMD4<Float>,
            SIMD4<Float>, SIMD4<Float>, SIMD4<Float>, SIMD4<Float>
        )
        // 24 edges × 16 bytes each (int4)
        var edges: (
            SIMD4<Int32>, SIMD4<Int32>, SIMD4<Int32>, SIMD4<Int32>,
            SIMD4<Int32>, SIMD4<Int32>, SIMD4<Int32>, SIMD4<Int32>,
            SIMD4<Int32>, SIMD4<Int32>, SIMD4<Int32>, SIMD4<Int32>,
            SIMD4<Int32>, SIMD4<Int32>, SIMD4<Int32>, SIMD4<Int32>,
            SIMD4<Int32>, SIMD4<Int32>, SIMD4<Int32>, SIMD4<Int32>,
            SIMD4<Int32>, SIMD4<Int32>, SIMD4<Int32>, SIMD4<Int32>
        )
    }

    private struct Node {
        var pos: SIMD2<Float>
        var vel: SIMD2<Float>
        var status: Float
        var phase:  Float
    }

    private var nodes: [Node]
    private var edges: [(Int32, Int32)]
    private var timeSinceStatusFlip: Float = 0

    init() {
        var rng = SystemRandomNumberGenerator()
        nodes = (0..<10).map { _ in
            Node(
                pos: SIMD2(Float.random(in: 0.2...0.8, using: &rng),
                           Float.random(in: 0.2...0.8, using: &rng)),
                vel: SIMD2(0, 0),
                status: 0,
                phase: Float.random(in: 0...(2 * .pi), using: &rng)
            )
        }
        var edgeSet = Set<UInt64>()
        var edgesList: [(Int32, Int32)] = []
        while edgesList.count < 15 {
            let a = Int.random(in: 0..<10, using: &rng)
            var b = Int.random(in: 0..<10, using: &rng)
            while b == a { b = Int.random(in: 0..<10, using: &rng) }
            let key = UInt64(min(a, b)) | (UInt64(max(a, b)) << 32)
            if edgeSet.insert(key).inserted {
                edgesList.append((Int32(a), Int32(b)))
            }
        }
        edges = edgesList
    }

    func update(context: FrameContext) {
        if revealStart < 0 { revealStart = context.time + revealDelay }
        if context.time < revealStart { return }

        let dt: Float = min(context.deltaTime, 0.033)
        let repulsion:  Float = 0.0015
        let springRest: Float = 0.20
        let springK:    Float = 1.8
        let damping:    Float = 0.92
        let centerPull: Float = 0.6

        var newVels = nodes.map { $0.vel }

        // Repulsion between all pairs
        for i in 0..<nodes.count {
            for j in (i+1)..<nodes.count {
                let delta = nodes[i].pos - nodes[j].pos
                let d2 = max(dot(delta, delta), 1e-4)
                let force = (repulsion / d2) * normalize(delta)
                newVels[i] += force
                newVels[j] -= force
            }
        }

        // Edge spring forces
        for e in edges {
            let i = Int(e.0); let j = Int(e.1)
            let delta = nodes[j].pos - nodes[i].pos
            let dist = max(length(delta), 1e-4)
            let dir = delta / dist
            let stretch = dist - springRest
            let force = dir * (springK * stretch * dt)
            newVels[i] += force
            newVels[j] -= force
        }

        // Center pull toward (0.5, 0.5)
        for i in 0..<nodes.count {
            let toCenter = SIMD2<Float>(0.5, 0.5) - nodes[i].pos
            newVels[i] += toCenter * (centerPull * dt)
        }

        // Integrate + damp + clamp
        for i in 0..<nodes.count {
            nodes[i].vel = newVels[i] * damping
            nodes[i].pos += nodes[i].vel * dt
            nodes[i].pos = clamp(nodes[i].pos, min: SIMD2(0.1, 0.1), max: SIMD2(0.9, 0.9))
        }

        // Occasionally flip a node status
        timeSinceStatusFlip += context.deltaTime
        if timeSinceStatusFlip > 3.0 {
            timeSinceStatusFlip = 0
            let idx = Int.random(in: 0..<nodes.count)
            let roll = Float.random(in: 0...1)
            nodes[idx].status = roll < 0.70 ? 0 : (roll < 0.92 ? 1 : 2)
        }
    }

    func encode(into encoder: MTLRenderCommandEncoder, context: FrameContext) {
        guard context.time >= revealStart, revealStart >= 0 else { return }

        // Pad to 16 nodes
        let padNode = Node(pos: SIMD2(0,0), vel: SIMD2(0,0), status: 0, phase: 0)
        let n16 = (nodes + Array(repeating: padNode, count: max(0, 16 - nodes.count))).prefix(16)
            .map { SIMD4<Float>($0.pos.x, $0.pos.y, $0.status, $0.phase) }

        // Pad to 24 edges
        let padEdge: (Int32, Int32) = (0, 0)
        let e24 = (edges + Array(repeating: padEdge, count: max(0, 24 - edges.count))).prefix(24)
            .map { SIMD4<Int32>($0.0, $0.1, 0, 0) }

        var u = Uniforms(
            resolution: context.resolution,
            origin: origin,
            size: size,
            nodeCount: Int32(nodes.count),
            edgeCount: Int32(edges.count),
            time: context.time,
            nodes: (n16[0],  n16[1],  n16[2],  n16[3],
                    n16[4],  n16[5],  n16[6],  n16[7],
                    n16[8],  n16[9],  n16[10], n16[11],
                    n16[12], n16[13], n16[14], n16[15]),
            edges: (e24[0],  e24[1],  e24[2],  e24[3],
                    e24[4],  e24[5],  e24[6],  e24[7],
                    e24[8],  e24[9],  e24[10], e24[11],
                    e24[12], e24[13], e24[14], e24[15],
                    e24[16], e24[17], e24[18], e24[19],
                    e24[20], e24[21], e24[22], e24[23])
        )
        encoder.setRenderPipelineState(context.pipelines.graph)
        encoder.setVertexBytes(&u, length: MemoryLayout<Uniforms>.stride, index: 0)
        encoder.setFragmentBytes(&u, length: MemoryLayout<Uniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
    }
}
