#pragma once

// Wrapped in __METAL_VERSION__ so clang's indexer (which sees this as a C/C++ header)
// stays quiet. The Metal compiler defines __METAL_VERSION__ and gets the full content.
#ifdef __METAL_VERSION__

#include <metal_stdlib>
using namespace metal;

// Premultiplied-alpha output for "over" compositing.
inline float4 premul(float3 color, float alpha) {
    return float4(color * alpha, alpha);
}

// Antialiased step from outside (d > 0) to inside (d < 0) of an SDF.
inline float aaEdge(float d, float aa) {
    return 1.0 - smoothstep(-aa, aa, d);
}

// Soft exponential falloff for halos / glow.
inline float softGlow(float d, float radius) {
    return exp(-max(d, 0.0) / radius);
}

// SDF: axis-aligned box centered at origin, half-extents b.
inline float sdBox(float2 p, float2 b) {
    float2 d = abs(p) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

// SDF: ring at radius r with width w.
inline float sdRing(float2 p, float r, float w) {
    return abs(length(p) - r) - w;
}

// Standard Jarvis palette.
constant float3 kCyan       = float3(0.20, 0.85, 1.00);
constant float3 kBrightCyan = float3(0.55, 0.95, 1.00);

#endif // __METAL_VERSION__
