#include <metal_stdlib>
#include "Common.h"
using namespace metal;

struct WidgetUniforms {
    float2 resolution;     // drawable pixels
    float2 origin;          // widget origin in screen-normalized [0..1]
    float2 size;            // widget size in screen-normalized [0..1]
    float4 tint;            // RGBA tint multiplied with sampled texture
    float frameAlpha;       // 0..1 — how visible the bordering frame is
    float textAlpha;        // 0..1 — how visible the sampled texture is
    float _pad0;
    float _pad1;
};

struct WidgetVertexOut {
    float4 position [[position]];
    float2 uv;       // [0,1] within the widget quad
    float2 uv01;     // [0,1] across the drawable
};

vertex WidgetVertexOut widget_vertex(uint vid [[vertex_id]],
                                     constant WidgetUniforms &u [[buffer(0)]]) {
    // Unit-quad corners (two triangles, six vertices).
    float2 corners[6] = {
        float2(0, 0), float2(1, 0), float2(0, 1),
        float2(0, 1), float2(1, 0), float2(1, 1)
    };
    float2 unit = corners[vid];
    float2 q = u.origin + unit * u.size;             // [0..1] screen coords
    float2 ndc = q * 2.0 - 1.0;                       // clip space
    WidgetVertexOut out;
    out.position = float4(ndc, 0.0, 1.0);
    out.uv = unit;
    out.uv01 = q;
    return out;
}

fragment float4 widget_fragment(WidgetVertexOut in [[stage_in]],
                                constant WidgetUniforms &u [[buffer(0)]],
                                texture2d<float> textTexture [[texture(0)]]) {
    constexpr sampler s(coord::normalized, filter::linear,
                        address::clamp_to_edge);

    // Sampled text (premultiplied alpha). Tint multiplies through.
    float4 sampled = textTexture.sample(s, in.uv);
    float3 textColor = sampled.rgb * u.tint.rgb;
    float textAlpha = sampled.a * u.tint.a * u.textAlpha;

    // Aspect-correct frame border using SDF in widget-local pixel space.
    float aspect = u.resolution.x / u.resolution.y;
    float2 px = (in.uv - 0.5) * float2(u.size.x * aspect, u.size.y);
    float2 half_ = float2(u.size.x * aspect, u.size.y) * 0.5;
    float dOuter = sdBox(px, half_);
    float dBorder = abs(dOuter + 0.0008) - 0.0010;

    float aa = 2.0 / u.resolution.y;
    float frameMask = max(aaEdge(dBorder, aa),
                          softGlow(dBorder, 0.004) * 0.4);
    float3 frameColor = kBrightCyan * frameMask;
    float frameAlpha = frameMask * u.frameAlpha;

    float3 color = textColor + frameColor;
    float alpha = max(textAlpha, frameAlpha);
    return premul(color, alpha);
}
