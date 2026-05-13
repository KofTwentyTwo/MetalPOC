#include <metal_stdlib>
#include "Common.h"
using namespace metal;

constant constexpr int kSpectrumBarCount = 32;

struct SpectrumUniforms {
    float2 resolution;
    float time;
    float radius;
    float bars[kSpectrumBarCount];   // 0..1 per bar
};

struct SpectrumVertexOut {
    float4 position [[position]];
    float2 ndc;
};

vertex SpectrumVertexOut spectrum_vertex(uint vid [[vertex_id]]) {
    float2 corners[3] = {
        float2(-1.0, -1.0),
        float2( 3.0, -1.0),
        float2(-1.0,  3.0)
    };
    float2 p = corners[vid];
    SpectrumVertexOut out;
    out.position = float4(p, 0.0, 1.0);
    out.ndc = p;
    return out;
}

fragment float4 spectrum_fragment(SpectrumVertexOut in [[stage_in]],
                                  constant SpectrumUniforms &u [[buffer(0)]]) {
    float aspect = u.resolution.x / u.resolution.y;
    float2 p = in.ndc;
    p.x *= aspect;
    float r = length(p);

    float innerR = u.radius * 1.92;
    float maxBarLength = u.radius * 0.85;
    if (r < innerR || r > innerR + maxBarLength) return float4(0.0);

    // Map angle to bar index. We sweep across the upper hemisphere only (π .. 2π → bar 0..32).
    float a = atan2(p.y, p.x);
    if (a < 0) a += 2.0 * M_PI_F;
    if (a < M_PI_F) return float4(0.0);
    float band = (a - M_PI_F) / M_PI_F;        // 0..1
    int idx = int(band * float(kSpectrumBarCount));
    if (idx >= kSpectrumBarCount) idx = kSpectrumBarCount - 1;
    float barFracLocal = band * float(kSpectrumBarCount) - float(idx);

    // A thin "slot" around each bar centerline.
    float slotHalf = 0.45;
    if (barFracLocal < (0.5 - slotHalf) || barFracLocal > (0.5 + slotHalf)) return float4(0.0);

    float barHeight = u.bars[idx] * maxBarLength;
    float radial = r - innerR;
    if (radial > barHeight) return float4(0.0);

    // Color: cyan ramping to bright at the top.
    float gradient = radial / max(barHeight, 0.0001);
    float3 col = mix(kCyan, kBrightCyan, gradient);
    float core = 1.0;
    float halo = softGlow(0.0, 0.004) * 0.3;
    return premul(col * (core + halo), 0.8);
}
