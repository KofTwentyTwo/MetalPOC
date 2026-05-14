#include <metal_stdlib>
#include "Common.h"
using namespace metal;

constant constexpr int kTopoMaxNodes = 12;
constant constexpr int kTopoMaxEdges = 16;

struct TopologyUniforms {
    float2 resolution;
    float2 origin;
    float2 size;
    int    nodeCount;
    int    edgeCount;
    float  time;
    float  pulseSpeed;
    float4 nodes[kTopoMaxNodes];   // xy = pos, z = status, w = unused
    int4   edges[kTopoMaxEdges];   // x = from, y = to, z/w unused
};

struct TopoVertexOut {
    float4 position [[position]];
    float2 uv01;
};

vertex TopoVertexOut topology_vertex(uint vid [[vertex_id]],
                                     constant TopologyUniforms &u [[buffer(0)]]) {
    float2 corners[6] = {
        float2(0,0), float2(1,0), float2(0,1),
        float2(0,1), float2(1,0), float2(1,1)
    };
    float2 unit = corners[vid];
    float2 q = u.origin + unit * u.size;
    float2 ndc = q * 2.0 - 1.0;
    TopoVertexOut out;
    out.position = float4(ndc, 0.0, 1.0);
    out.uv01 = unit;
    return out;
}

static float sdSegmentTopo(float2 p, float2 a, float2 b) {
    float2 pa = p - a;
    float2 ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-5), 0.0, 1.0);
    return length(pa - ba * h);
}

fragment float4 topology_fragment(TopoVertexOut in [[stage_in]],
                                  constant TopologyUniforms &u [[buffer(0)]]) {
    float widgetAspect = (u.size.x * u.resolution.x) / (u.size.y * u.resolution.y);
    float2 p = in.uv01;
    p.x *= widgetAspect;

    float3 color = float3(0.0);
    float alpha = 0.0;

    // Edges with animated flow pulses
    for (int e = 0; e < u.edgeCount && e < kTopoMaxEdges; ++e) {
        int fromIdx = u.edges[e].x;
        int toIdx   = u.edges[e].y;
        if (fromIdx >= u.nodeCount || toIdx >= u.nodeCount) continue;
        float2 a = u.nodes[fromIdx].xy;
        float2 b = u.nodes[toIdx].xy;
        a.x *= widgetAspect;
        b.x *= widgetAspect;
        float d = sdSegmentTopo(p, a, b);
        float edgeMask = smoothstep(0.004, 0.001, d);
        color += kCyan * edgeMask * 0.45;
        alpha = max(alpha, edgeMask * 0.45);

        // Pulse traveling along edge
        float2 ba = b - a;
        float bLen = max(length(ba), 1e-4);
        float t = dot(p - a, ba) / (bLen * bLen);
        if (t >= 0.0 && t <= 1.0) {
            float phase = float(e) * 0.21;
            float pulsePos = fract(u.time * u.pulseSpeed + phase);
            float dist = abs(t - pulsePos);
            dist = min(dist, abs(t - pulsePos - 1.0));
            dist = min(dist, abs(t - pulsePos + 1.0));
            float pulseAlongEdge = exp(-pow(dist / 0.05, 2.0)) * 0.85;
            float perpDist = sdSegmentTopo(p, a, b);
            float perpMask = smoothstep(0.010, 0.0, perpDist);
            float pulseBrightness = pulseAlongEdge * perpMask;
            color += kBrightCyan * pulseBrightness;
            alpha = max(alpha, pulseBrightness);
        }
    }

    // Nodes
    for (int n = 0; n < u.nodeCount && n < kTopoMaxNodes; ++n) {
        float2 c = u.nodes[n].xy;
        c.x *= widgetAspect;
        float d = length(p - c);
        float status = u.nodes[n].z;
        float3 nodeColor;
        if (status < 0.5) nodeColor = kBrightCyan;
        else if (status < 1.5) nodeColor = float3(1.0, 0.85, 0.4);
        else nodeColor = float3(1.0, 0.5, 0.5);
        float coreMask = smoothstep(0.016, 0.008, d);
        float haloMask = exp(-d / 0.025) * 0.5;
        color += nodeColor * (coreMask + haloMask);
        alpha = max(alpha, coreMask + haloMask * 0.6);
    }

    return premul(color, clamp(alpha, 0.0, 1.0));
}
