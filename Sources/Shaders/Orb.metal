#include <metal_stdlib>
#include "Common.h"
using namespace metal;

struct OrbUniforms {
    float2 resolution;
    float time;
    float radius;       // orb radius in normalized vertical units
};

struct OrbVertexOut {
    float4 position [[position]];
    float2 ndc;   // [-1, 1]
};

vertex OrbVertexOut orb_vertex(uint vid [[vertex_id]]) {
    float2 corners[3] = {
        float2(-1.0, -1.0),
        float2( 3.0, -1.0),
        float2(-1.0,  3.0)
    };
    float2 p = corners[vid];
    OrbVertexOut out;
    out.position = float4(p, 0.0, 1.0);
    out.ndc = p;
    return out;
}

// Simple 2D hash + value noise — cheap, perlin-flavored.
static float hash21(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}
static float vnoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float a = hash21(i);
    float b = hash21(i + float2(1, 0));
    float c = hash21(i + float2(0, 1));
    float d = hash21(i + float2(1, 1));
    float2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}
static float fbm(float2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 4; ++i) { v += a * vnoise(p); p *= 2.0; a *= 0.5; }
    return v;
}

fragment float4 orb_fragment(OrbVertexOut in [[stage_in]],
                             constant OrbUniforms &u [[buffer(0)]]) {
    float aspect = u.resolution.x / u.resolution.y;
    float aa = 2.0 / u.resolution.y;
    float2 p = in.ndc;
    p.x *= aspect;
    // Center the orb on screen.
    p.y -= 0.0;

    float r = length(p);
    if (r > u.radius * 3.0) {
        // Cheap early-out for fragments far outside the orb's influence radius.
        return float4(0.0);
    }

    float3 color = float3(0.0);
    float alpha = 0.0;

    // Energy core — smooth disc with internal swirling noise.
    float coreEdge = r - u.radius;
    float coreFill = aaEdge(coreEdge, aa);
    float swirl = fbm(p * 6.0 + float2(u.time * 0.3, u.time * 0.2));
    float3 coreColor = mix(kCyan, kBrightCyan, swirl);
    float coreIntensity = coreFill * (0.45 + 0.35 * swirl);
    color += coreColor * coreIntensity;
    alpha = max(alpha, coreIntensity);

    // Inner halo / outer halo.
    float halo = softGlow(coreEdge, u.radius * 0.30) * 0.5;
    color += kBrightCyan * halo;
    alpha = max(alpha, halo * 0.7);

    // Two rotating thin rings.
    float ring1 = sdRing(p, u.radius * 1.20, 0.0015);
    float ring2 = sdRing(p, u.radius * 1.35, 0.0010);
    float ring1Strength = max(aaEdge(ring1, aa), softGlow(ring1, 0.006) * 0.5);
    float ring2Strength = max(aaEdge(ring2, aa), softGlow(ring2, 0.005) * 0.4);
    color += kBrightCyan * ring1Strength;
    color += kCyan * ring2Strength;
    alpha = max(alpha, max(ring1Strength, ring2Strength));

    // Pulsing outer halo on a slow sin wave.
    float pulse = 0.5 + 0.5 * sin(u.time * 0.8);
    float outer = softGlow(coreEdge, u.radius * (0.6 + 0.2 * pulse)) * 0.18 * pulse;
    color += kCyan * outer;
    alpha = max(alpha, outer);

    color = min(color, float3(1.0));
    alpha = clamp(alpha, 0.0, 1.0);
    return premul(color, alpha);
}
