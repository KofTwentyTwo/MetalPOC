#include <metal_stdlib>
#include "Common.h"
using namespace metal;

struct OrnamentUniforms {
    float2 resolution;
    float time;
};

struct OrnamentVertexOut {
    float4 position [[position]];
    float2 uv01;  // [0, 1] across the drawable
};

vertex OrnamentVertexOut ornament_vertex(uint vid [[vertex_id]]) {
    // Fullscreen triangle (oversized; the GPU clips it to the viewport).
    float2 corners[3] = {
        float2(-1.0, -1.0),
        float2( 3.0, -1.0),
        float2(-1.0,  3.0)
    };
    float2 p = corners[vid];
    OrnamentVertexOut out;
    out.position = float4(p, 0.0, 1.0);
    out.uv01 = p * 0.5 + 0.5;
    return out;
}

fragment float4 ornament_fragment(OrnamentVertexOut in [[stage_in]],
                                  constant OrnamentUniforms &u [[buffer(0)]]) {
    float aspect = u.resolution.x / u.resolution.y;
    float aa = 2.0 / u.resolution.y;
    float2 q = in.uv01;

    // Four corner brackets — each is one horizontal + one vertical short segment.
    const float margin = 0.018;
    const float legLen = 0.035;            // in y units
    const float thick  = 0.0010;           // in y units

    float2 corners[4] = {
        float2(margin, margin),
        float2(1.0 - margin, margin),
        float2(margin, 1.0 - margin),
        float2(1.0 - margin, 1.0 - margin)
    };
    float2 dirs[4] = {
        float2( 1.0,  1.0),
        float2(-1.0,  1.0),
        float2( 1.0, -1.0),
        float2(-1.0, -1.0)
    };

    float bracket = 1e9;
    for (int i = 0; i < 4; ++i) {
        float2 c = corners[i];
        float2 d = dirs[i];
        // Horizontal leg: extends along x from the corner.
        float2 hMid = c + float2(d.x * (legLen / aspect) * 0.5, 0.0);
        float hd = sdBox(q - hMid, float2((legLen / aspect) * 0.5, thick));
        // Vertical leg: extends along y from the corner.
        float2 vMid = c + float2(0.0, d.y * legLen * 0.5);
        float vd = sdBox(q - vMid, float2(thick / aspect, legLen * 0.5));
        bracket = min(bracket, min(hd, vd));
    }

    float core = aaEdge(bracket, aa);
    float halo = softGlow(bracket, 0.004) * 0.4;
    float strength = max(core, halo);

    return premul(kBrightCyan * strength, strength);
}
