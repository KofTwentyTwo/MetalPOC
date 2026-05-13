#include <metal_stdlib>
#include "Common.h"
using namespace metal;

struct VitalsUniforms {
    float2 resolution;
    float time;
    float radius;       // orb radius — vital rings sit just outside this
    float battery;      // 0..1
    float cpuTemp;      // 0..1
    float fanRpm;       // 0..1
    float _pad0;
};

struct VitalsVertexOut {
    float4 position [[position]];
    float2 ndc;
};

vertex VitalsVertexOut vitals_vertex(uint vid [[vertex_id]]) {
    float2 corners[3] = {
        float2(-1.0, -1.0),
        float2( 3.0, -1.0),
        float2(-1.0,  3.0)
    };
    float2 p = corners[vid];
    VitalsVertexOut out;
    out.position = float4(p, 0.0, 1.0);
    out.ndc = p;
    return out;
}

// Returns a mask 1 within the angular range [startAngle, startAngle + sweep], 0 outside.
static float arcMask(float2 p, float startAngle, float sweep) {
    float a = atan2(p.y, p.x);
    if (a < 0) a += 2.0 * M_PI_F;
    float delta = fmod(a - startAngle + 4.0 * M_PI_F, 2.0 * M_PI_F);
    return step(delta, sweep);
}

fragment float4 vitals_fragment(VitalsVertexOut in [[stage_in]],
                                constant VitalsUniforms &u [[buffer(0)]]) {
    float aspect = u.resolution.x / u.resolution.y;
    float aa = 2.0 / u.resolution.y;
    float2 p = in.ndc;
    p.x *= aspect;

    float r = length(p);
    if (r < u.radius * 1.45 || r > u.radius * 1.85) {
        return float4(0.0);
    }

    float3 color = float3(0.0);
    float alpha = 0.0;

    struct Arc {
        float radius;
        float thickness;
        float startAngle;
        float maxSweep;
        float fill;       // 0..1
        float3 color;
    };

    Arc arcs[3] = {
        { u.radius * 1.55, 0.0035, 1.30, 1.40, u.battery, kBrightCyan },
        { u.radius * 1.65, 0.0030, 3.10, 1.30, u.cpuTemp, kCyan       },
        { u.radius * 1.75, 0.0028, 5.00, 1.10, u.fanRpm,  kBrightCyan },
    };

    for (int i = 0; i < 3; ++i) {
        Arc a = arcs[i];
        float ringD = sdRing(p, a.radius, a.thickness);
        float ringStrength = aaEdge(ringD, aa);
        // Dim background ring (track).
        color += a.color * ringStrength * 0.10;
        alpha = max(alpha, ringStrength * 0.15);
        // Bright fill portion.
        float mask = arcMask(p, a.startAngle, a.maxSweep * a.fill);
        float fillStrength = ringStrength * mask;
        color += a.color * fillStrength * 0.9;
        alpha = max(alpha, fillStrength);
        // Halo on the leading edge.
        float halo = softGlow(ringD, 0.005) * 0.4 * mask;
        color += a.color * halo;
        alpha = max(alpha, halo);
    }

    color = min(color, float3(1.0));
    alpha = clamp(alpha, 0.0, 1.0);
    return premul(color, alpha);
}
