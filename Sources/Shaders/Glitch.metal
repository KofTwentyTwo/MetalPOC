#include <metal_stdlib>
#include "Common.h"
using namespace metal;

// Post-process pass: sample the HUD composite texture with per-channel UV offsets.
// When glitchAmount > 0, R, G, B channels are sampled at slightly different x positions.

struct GlitchUniforms {
    float glitchAmount;   // 0 = no effect, 1 = full aberration
    float time;
    float2 _pad;
};

struct GlitchVertexOut {
    float4 position [[position]];
    float2 uv;
};

// Full-screen triangle (3 vertices cover the entire NDC space).
vertex GlitchVertexOut glitch_vertex(uint vid [[vertex_id]]) {
    float2 corners[3] = {
        float2(-1.0, -1.0),
        float2( 3.0, -1.0),
        float2(-1.0,  3.0)
    };
    float2 p = corners[vid];
    GlitchVertexOut out;
    out.position = float4(p, 0.0, 1.0);
    // Convert NDC [-1,1] to UV [0,1] (flip y because Metal UV is y-down).
    out.uv = float2((p.x + 1.0) * 0.5, 1.0 - (p.y + 1.0) * 0.5);
    return out;
}

fragment float4 glitch_fragment(GlitchVertexOut in [[stage_in]],
                                constant GlitchUniforms &u [[buffer(0)]],
                                texture2d<float> scene [[texture(0)]]) {
    constexpr sampler s(coord::normalized, filter::linear, address::clamp_to_edge);

    if (u.glitchAmount <= 0.0) {
        return scene.sample(s, in.uv);
    }

    float shift = u.glitchAmount * 0.006;
    float r = scene.sample(s, float2(in.uv.x + shift, in.uv.y)).r;
    float g = scene.sample(s, in.uv).g;
    float b = scene.sample(s, float2(in.uv.x - shift, in.uv.y)).b;
    float a = scene.sample(s, in.uv).a;
    return float4(r, g, b, a);
}
