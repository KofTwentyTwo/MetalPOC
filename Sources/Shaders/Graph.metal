#include <metal_stdlib>
#include "Common.h"
using namespace metal;

constant constexpr int kGraphMaxNodes = 16;
constant constexpr int kGraphMaxEdges = 24;

struct GraphUniforms {
    float2 resolution;
    float2 origin;
    float2 size;
    int    nodeCount;
    int    edgeCount;
    float  time;
    float  _pad;
    float4 nodes[kGraphMaxNodes];   // xy = position in widget-local [0..1], z = status (0=ok,1=warn,2=err), w = pulse phase
    int4   edges[kGraphMaxEdges];   // x = fromIdx, y = toIdx, z/w unused
};

struct GraphVertexOut {
    float4 position [[position]];
    float2 uv01;
};

vertex GraphVertexOut graph_vertex(uint vid [[vertex_id]],
                                   constant GraphUniforms &u [[buffer(0)]]) {
    float2 corners[6] = {
        float2(0,0), float2(1,0), float2(0,1),
        float2(0,1), float2(1,0), float2(1,1)
    };
    float2 unit = corners[vid];
    float2 q = u.origin + unit * u.size;
    float2 ndc = q * 2.0 - 1.0;
    GraphVertexOut out;
    out.position = float4(ndc, 0.0, 1.0);
    out.uv01 = unit;
    return out;
}

// SDF for a line segment from a to b
static float sdSegmentGraph(float2 p, float2 a, float2 b) {
    float2 pa = p - a;
    float2 ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-5), 0.0, 1.0);
    return length(pa - ba * h);
}

fragment float4 graph_fragment(GraphVertexOut in [[stage_in]],
                               constant GraphUniforms &u [[buffer(0)]]) {
    float widgetAspect = (u.size.x * u.resolution.x) / (u.size.y * u.resolution.y);
    float2 p = in.uv01;
    p.x *= widgetAspect;

    float3 color = float3(0.0);
    float alpha = 0.0;

    // Edges
    for (int e = 0; e < u.edgeCount && e < kGraphMaxEdges; ++e) {
        int fromIdx = u.edges[e].x;
        int toIdx   = u.edges[e].y;
        if (fromIdx >= u.nodeCount || toIdx >= u.nodeCount) continue;
        float2 a = u.nodes[fromIdx].xy;
        float2 b = u.nodes[toIdx].xy;
        a.x *= widgetAspect;
        b.x *= widgetAspect;
        float d = sdSegmentGraph(p, a, b);
        float edgeMask = smoothstep(0.005, 0.001, d);
        color += kCyan * edgeMask * 0.6;
        alpha = max(alpha, edgeMask * 0.6);
    }

    // Nodes
    for (int n = 0; n < u.nodeCount && n < kGraphMaxNodes; ++n) {
        float2 c = u.nodes[n].xy;
        c.x *= widgetAspect;
        float d = length(p - c);
        float status = u.nodes[n].z;
        float phase = u.nodes[n].w;
        float pulse = 0.7 + 0.3 * sin(u.time * 3.0 + phase);
        float coreMask = smoothstep(0.012, 0.006, d);
        float haloMask = exp(-d / 0.020) * 0.4 * pulse;
        float3 nodeColor;
        if (status < 0.5) nodeColor = kBrightCyan;
        else if (status < 1.5) nodeColor = float3(1.0, 0.85, 0.4);
        else nodeColor = float3(1.0, 0.5, 0.5);
        color += nodeColor * (coreMask + haloMask);
        alpha = max(alpha, coreMask + haloMask * 0.6);
    }

    return premul(color, clamp(alpha, 0.0, 1.0));
}
