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
    float time;             // elapsed time in seconds (for animation)
    float flashAge;         // seconds since last content change (for reactive flash)
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

    // Soft cyan glow around text glyphs — adds a halo where glyphs exist.
    float3 glowContrib = sampled.a * 0.35 * kBrightCyan;
    float glowAlpha    = sampled.a * 0.35;

    // Composite text + glow.
    float3 totalTextColor = textColor + glowContrib;
    float  totalTextAlpha = clamp(textAlpha + glowAlpha, 0.0, 1.0);

    // -------------------------------------------------------------------------
    // Aspect-correct frame border using SDF in widget-local space.
    // -------------------------------------------------------------------------
    float aspect = u.resolution.x / u.resolution.y;
    float2 px = (in.uv - 0.5) * float2(u.size.x * aspect, u.size.y);
    float2 half_ = float2(u.size.x * aspect, u.size.y) * 0.5;

    float dBox = sdBox(px, half_);

    // Chamfer TL and BR corners at 45°. notchSize = 10% of the smaller half.
    // Text content stays clear of the chamfered region via inset padding in the
    // TextRasterizer (~10% of the widget's smaller dimension).
    float notchSize = min(half_.x, half_.y) * 0.10;

    // Top-left chamfer: the corner where px.x ~ -half_.x AND px.y ~ +half_.y
    // Cut plane: a diagonal line whose normal points into (1, -1) direction
    // passes through the corner point (-half_.x + notch, half_.y - notch).
    float tlPlane = -(px.x + half_.x - notchSize) + (px.y - half_.y + notchSize);

    // Bottom-right chamfer: mirror of TL (flip both axes).
    float brPlane = (px.x - half_.x + notchSize) - (px.y + half_.y - notchSize);

    // Apply chamfer: max() extends the SDF outward at the cut corners,
    // effectively slicing them off.
    float dShaped = max(dBox, max(tlPlane, brPlane));

    float dBorder = abs(dShaped + 0.0008) - 0.0010;

    float aa = 2.0 / u.resolution.y;
    float frameMask = max(aaEdge(dBorder, aa),
                          softGlow(dBorder, 0.004) * 0.4);
    // Reactive flash: very subtle brightness boost when content changes (dialed down from
    // earlier values that were WAY too bright — at 0.6/1.5 the whole HUD strobed).
    float flashBoost = exp(-u.flashAge * 6.0) * 0.08;
    float flashedFrameMask = frameMask * (1.0 + flashBoost * 0.25);
    float3 frameColor = kBrightCyan * flashedFrameMask;
    float  frameAlpha = flashedFrameMask * u.frameAlpha;

    // -------------------------------------------------------------------------
    // Animated scanline drift — thin cyan band scrolling down the widget.
    // in.uv.y: 0 = bottom, 1 = top (Metal NDC y increases upward after vertex).
    // We want the band to appear inside the widget so clip to interior.
    // -------------------------------------------------------------------------
    float interiorMask = 1.0 - step(0.0, dShaped);   // 1 inside, 0 outside
    float bandY = fract(u.time * 0.08);
    float dist  = abs(in.uv.y - bandY);
    float scanIntensity = exp(-pow(dist / 0.012, 2.0)) * 0.18 * interiorMask;
    float3 scanColor = kBrightCyan * scanIntensity;
    float  scanAlpha = scanIntensity;

    // -------------------------------------------------------------------------
    // Hex grid background pattern (very subtle).
    // Uses axial coords to identify which hex cell a fragment is in.
    // -------------------------------------------------------------------------
    float3 color = totalTextColor + frameColor + scanColor;
    float  alpha = clamp(max(totalTextAlpha, max(frameAlpha, scanAlpha)), 0.0, 1.0);

    // Hex grid pattern on top of the NSVisualEffectView blur — now genuinely visible.
    if (interiorMask > 0.5) {
        float2 hexUV = in.uv * float2(u.size.x * u.resolution.x, u.size.y * u.resolution.y);
        hexUV /= 28.0;
        float2 h = hexUV;
        h.x *= 1.1547005;
        h.y += fmod(floor(h.x), 2.0) * 0.5;
        float2 hf = fract(h) - 0.5;
        float hexDist = max(abs(hf.x), max(abs(hf.y) + abs(hf.x) * 0.5, abs(hf.y) * 1.1547));
        float hexEdge = smoothstep(0.45, 0.49, hexDist) - smoothstep(0.49, 0.50, hexDist);
        float hexMask = hexEdge * 0.14;  // visible against the NSVisualEffectView blur
        color += kCyan * hexMask;
        alpha = max(alpha, hexMask);
    }

    // -------------------------------------------------------------------------
    // Pulsing LED at top-left corner of widget body (no divider line — the divider
    // was being read as a false "top of the box" with title text appearing above it).
    // -------------------------------------------------------------------------
    if (interiorMask > 0.5) {
        // LED sits inside the chamfered shape, offset enough from the TL corner to
        // clear the 10% notch on all widget aspect ratios.
        float2 ledPos = float2(0.08, 0.85);
        float ledRadius = 0.012;
        float widgetAspect = (u.size.x * u.resolution.x) / (u.size.y * u.resolution.y);
        float2 ledDelta = (in.uv - ledPos) * float2(widgetAspect, 1.0);
        float ledD = length(ledDelta);
        float pulse = 0.4 + 0.6 * (0.5 + 0.5 * sin(u.time * 2.0));
        float ledMask = smoothstep(ledRadius, ledRadius * 0.5, ledD) * pulse;
        color += kBrightCyan * ledMask;
        alpha = max(alpha, ledMask);
        float ledHalo = exp(-ledD / (ledRadius * 1.5)) * pulse * 0.4;
        color += kBrightCyan * ledHalo;
        alpha = max(alpha, ledHalo);
    }

    return premul(color, alpha);
}
