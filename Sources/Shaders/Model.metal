#include <metal_stdlib>
#include "Common.h"
using namespace metal;

// Icosahedron — 12 vertices (normalized so max edge ~= 1)
constant float3 kIcoVerts[12] = {
    float3( 0.0,      1.0,     0.5257),
    float3( 0.0,      1.0,    -0.5257),
    float3( 0.0,     -1.0,     0.5257),
    float3( 0.0,     -1.0,    -0.5257),
    float3( 0.5257,   0.0,     1.0),
    float3(-0.5257,   0.0,     1.0),
    float3( 0.5257,   0.0,    -1.0),
    float3(-0.5257,   0.0,    -1.0),
    float3( 1.0,      0.5257,  0.0),
    float3( 1.0,     -0.5257,  0.0),
    float3(-1.0,      0.5257,  0.0),
    float3(-1.0,     -0.5257,  0.0)
};

// 30 edges as pairs of vertex indices
constant int2 kIcoEdges[30] = {
    int2(0,1),  int2(0,4),  int2(0,5),  int2(0,8),  int2(0,10),
    int2(1,6),  int2(1,7),  int2(1,8),  int2(1,10), int2(2,3),
    int2(2,4),  int2(2,5),  int2(2,9),  int2(2,11), int2(3,6),
    int2(3,7),  int2(3,9),  int2(3,11), int2(4,5),  int2(4,8),
    int2(4,9),  int2(5,10), int2(5,11), int2(6,7),  int2(6,8),
    int2(6,9),  int2(7,10), int2(7,11), int2(8,9),  int2(10,11)
};

struct ModelUniforms {
    float2 resolution;
    float2 origin;
    float2 size;
    float  time;
    float  rotationDegPerSec;
};

struct ModelVertexOut {
    float4 position [[position]];
    float2 uv01;
};

vertex ModelVertexOut model_vertex(uint vid [[vertex_id]],
                                   constant ModelUniforms &u [[buffer(0)]]) {
    float2 corners[6] = {
        float2(0,0), float2(1,0), float2(0,1),
        float2(0,1), float2(1,0), float2(1,1)
    };
    float2 unit = corners[vid];
    float2 q = u.origin + unit * u.size;
    float2 ndc = q * 2.0 - 1.0;
    ModelVertexOut out;
    out.position = float4(ndc, 0.0, 1.0);
    out.uv01 = unit;
    return out;
}

// Project a 3D vertex to widget-local 2D [0..1] after Y-axis rotation + X tilt
static float2 projectVertex(float3 v, float angle) {
    float cy = cos(angle), sy = sin(angle);
    // Y-axis rotation
    float3 r = float3(cy * v.x + sy * v.z, v.y, -sy * v.x + cy * v.z);
    // Slight X-axis tilt for visual depth
    float cx = cos(0.4), sx = sin(0.4);
    r = float3(r.x, cx * r.y - sx * r.z, sx * r.y + cx * r.z);
    // Orthographic projection, centered, scaled to fit widget
    return float2(0.5 + r.x * 0.35, 0.5 + r.y * 0.35);
}

static float sdSegmentModel(float2 p, float2 a, float2 b) {
    float2 pa = p - a;
    float2 ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-5), 0.0, 1.0);
    return length(pa - ba * h);
}

fragment float4 model_fragment(ModelVertexOut in [[stage_in]],
                               constant ModelUniforms &u [[buffer(0)]]) {
    float widgetAspect = (u.size.x * u.resolution.x) / (u.size.y * u.resolution.y);
    float2 p = in.uv01;
    p.x *= widgetAspect;

    float angle = u.time * (u.rotationDegPerSec * M_PI_F / 180.0);

    float3 color = float3(0.0);
    float alpha = 0.0;

    for (int e = 0; e < 30; ++e) {
        float3 va = kIcoVerts[kIcoEdges[e].x];
        float3 vb = kIcoVerts[kIcoEdges[e].y];
        float2 a = projectVertex(va, angle);
        float2 b = projectVertex(vb, angle);
        a.x *= widgetAspect;
        b.x *= widgetAspect;
        float d = sdSegmentModel(p, a, b);
        float edgeMask = smoothstep(0.004, 0.001, d);
        // Depth fade: back-facing edges dimmer
        float cy = cos(angle), sy = sin(angle);
        float zA = -sy * va.x + cy * va.z;
        float zB = -sy * vb.x + cy * vb.z;
        float avgZ = (zA + zB) * 0.5;
        float depthFade = 0.4 + 0.6 * clamp((avgZ + 1.0) * 0.5, 0.0, 1.0);
        color += kBrightCyan * edgeMask * depthFade;
        alpha = max(alpha, edgeMask * depthFade);
    }

    // Subtle center glow at widget center
    float2 centerProj = float2(0.5 * widgetAspect, 0.5);
    float dc = length(p - centerProj);
    float centerGlow = exp(-dc / 0.05) * 0.25;
    color += kCyan * centerGlow;
    alpha = max(alpha, centerGlow);

    return premul(color, clamp(alpha, 0.0, 1.0));
}
