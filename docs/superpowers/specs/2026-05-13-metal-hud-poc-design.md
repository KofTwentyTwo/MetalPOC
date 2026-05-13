# Metal HUD POC — Design

**Status:** Draft, awaiting user review.
**Date:** 2026-05-13
**Author:** Claude (with james.maes)

## 1. Overview

A macOS proof-of-concept that renders a **transparent, always-on-top, Jarvis/Ironman-style heads-up display** directly in Apple Metal. The POC validates that Metal is the right foundation for the eventual product — a busy, visually dense, interactive HUD with a central animated "talking orb" surrounded by many live-data widgets.

The eventual product is an interactive HUD with real data sources (system metrics, LLM telemetry, agent state, task systems, voice/agent IO). This POC is the **rendering and architecture spine** that product will be built on. It does not include real data, real voice, real agent integration, or interactivity in v0.

### What this POC proves

1. A transparent, borderless, always-on-top Metal-rendered window works on modern macOS, follows you across Spaces, and composites cleanly over arbitrary desktop content.
2. A unified Metal rendering pipeline can deliver the Jarvis aesthetic for many widgets at once — cyan glow, scanlines, frames, animated orb — at 60fps.
3. Text-heavy widgets (logs, KPIs, lists, countdowns) work in Metal via CoreText rasterization, and update dynamically without jank.
4. A widget abstraction lets us add new widget types as a single new file each, with no changes to the renderer.

### What this POC explicitly does *not* prove

- Real data integrations (all data is mocked but **dynamic** — numbers tick, logs scroll, countdowns count).
- Click/keyboard interactivity (the orb is non-interactive in v0; the architecture leaves room for selective click-through but doesn't implement it).
- Voice in/out, LLM integration, agent state.
- Multi-monitor handling (main screen only).
- Configuration UI, persistence, hotkeys.
- Tests (POC; manual visual validation is the gate).

## 2. Non-goals

- Not a finished product. Code quality is "POC-grade clean," not "production-grade hardened."
- Not a screensaver. Screensavers run *instead of* your desktop; this HUD runs *on top of* it.
- Not a SwiftUI app. Every rendered pixel goes through Metal.
- Not multi-window. One transparent window covering the main screen.

## 3. Architecture

### 3.1 Process & window

- **Single process**, launched from Xcode or by double-clicking the built `.app`.
- `LSUIElement: true` — no Dock icon, no app menu bar.
- A **status-bar item** (SF Symbol `scope`) is the only system-level affordance. Its menu has **Toggle HUD** and **Quit**. This is the only way to dismiss/exit the HUD in v0.
- One **borderless transparent `NSWindow`** sized to the main screen's frame.
  - `level = .floating` (above normal app windows, below the system menu bar — keeps Cmd-Tab and menu bar usable while the HUD is up).
  - `collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]` — the HUD follows you across Spaces and survives over fullscreen apps.
  - `ignoresMouseEvents = true` permanently — orb is non-interactive, every click passes through to whatever is underneath.
  - `isOpaque = false`, `backgroundColor = .clear`, `hasShadow = false`.
- One **`MTKView`** as the window's content view: `colorPixelFormat = .bgra8Unorm`, `clearColor` with alpha 0, `framebufferOnly = false`, layer-backed with `layer.isOpaque = false`. Premultiplied-alpha "over" blending in every render pipeline so the HUD composites cleanly with whatever the window server presents behind the window.

### 3.2 Layout (main screen)

```
+--------------------------------------------------------------------+
| [System KPI]               [World Clocks]        [LLM Telemetry]   |
|                                                                    |
|  [Log Stream]                                       [Task List]    |
|  > [INFO]   ...                                      PENDING  ●    |
|  > [WARN]   ...                  ╭───────╮            ACTIVE  ●    |
|  > [ERROR]  ...               ──╯  ORB  ╰──         BLOCKED  ●    |
|  > [INFO]   ...                  ╰───────╯            DONE    ●    |
|  > ...                     vitals ring + spectrum                  |
|  > ...                                                             |
|                                                                    |
|  [Compass]              [Schedule strip]                           |
|   N E S W                10:00●  13:30●  15:00●                    |
| << status ticker scrolling right-to-left >>                        |
+--------------------------------------------------------------------+
```

Layout is **fixed/hard-coded** for v0 — widget frames are computed in screen-relative ratios so the HUD adapts to display size, but no layout engine, no dynamic placement.

### 3.3 Render loop

A flat, ordered scene of **elements**. No tree, no transforms, no z-buffer — draw order is just array order.

```swift
protocol HUDElement: AnyObject {
    func update(context: FrameContext)
    func encode(into encoder: MTLRenderCommandEncoder, context: FrameContext)
}

struct FrameContext {
    let time: Float            // seconds since launch
    let deltaTime: Float
    let resolution: SIMD2<Float>   // drawable pixels
    let scaleFactor: Float          // backing scale factor
    let device: MTLDevice
    let textRasterizer: TextRasterizer
    let pipelines: Pipelines
}
```

`Renderer` owns `var scene: [HUDElement]` in draw order: ornaments → orb → widgets. Each frame:

1. Build `FrameContext`.
2. For each element: `update(context:)` (advance animations, tick mock data, mark text dirty if changed).
3. Acquire `currentDrawable` + render-pass descriptor (load=clear-alpha-0, store=store).
4. One render pass: for each element, `encode(into:context:)`.
5. Present drawable.

Single-pass renderer. Glow effects happen inside each element's fragment shader, not as a post-process bloom. This keeps the POC simple; bloom is an explicit upgrade later.

### 3.4 Pipelines

Three `MTLRenderPipelineState`s, all sharing premultiplied-alpha blending:

| Pipeline | Geometry | Fragment role | Used by |
|---|---|---|---|
| `OrbPipeline` | fullscreen quad | Procedural orb shader — concentric rings, swirl, energy core | OrbElement |
| `OrnamentPipeline` | fullscreen quad | SDF-based ambient chrome — corner brackets, faint outer ring, scanlines | OrnamentElement |
| `WidgetPipeline` | per-instance unit quad with `(origin, size)` transform | Samples widget's text texture, draws frame border, applies tint/glow | Every widget element |

### 3.5 Coordinate spaces

- **Screen coordinates**: macOS conventional points, origin bottom-left. Widget frames live here.
- **Drawable pixels**: `view.drawableSize` — used by shaders.
- **Normalized [0..1]²**: convenient for SDF math and corner-bracket placement.

Conversion is explicit at the encode boundary. Each widget's frame (in points) is converted to a normalized rect for the shader.

## 4. Text rasterization

The single most consequential subsystem after the renderer.

### Approach

Each text-bearing widget owns one or more `MTLTexture` instances containing rasterized text. When the widget's text content changes, the widget asks `TextRasterizer` to re-rasterize into a fresh texture (or back into the same texture if dimensions match).

```swift
final class TextRasterizer {
    init(device: MTLDevice)
    func rasterize(
        _ string: NSAttributedString,
        maxSize: CGSize,                  // bounds for layout
        scale: CGFloat                    // backing scale (Retina)
    ) -> MTLTexture
}
```

Implementation:
1. Create a `CGContext` backed by an `MTLBuffer` (or by `CFData`) at the appropriate pixel format (BGRA8, premultiplied alpha).
2. Run CoreText layout (`CTFramesetter` for multi-line, `CTLine` for single-line).
3. Draw glyphs into the `CGContext`.
4. Copy bytes into a new `MTLTexture`. (Or use `CGContext.makeImage()` → `MTKTextureLoader` → texture, depending on perf — pick the simpler path first, measure.)

### Re-rasterization rules

- **On content change**: log gets a new line, KPI value changes, schedule countdown crosses a second boundary → re-rasterize.
- **Not per-frame**: a scrolling log animates by translating its texture's *vertical offset* inside the widget shader, not by re-rasterizing every frame.
- **Texture pooling**: a small free-list per `(width, height, scale)` keyed bucket so widgets don't allocate fresh `MTLTexture`s every update. POC can skip this if perf is fine; revisit on measurement.

### Fonts

One bundled monospace font (TBD — `Menlo` system default or a bundled custom `.otf`/`.ttf` like "Share Tech Mono" or "Orbitron"). Cyan tint applied in the widget fragment shader, not baked into glyphs.

## 5. Mock data — owned by the widget

For the POC, **each widget owns its own state machine**. No central data hub, no `DataSource` protocol layer, no Combine pipelines. Inside `update(context:)`:

```swift
func update(context: FrameContext) {
    advanceMockData(deltaTime: context.deltaTime)   // tick noise, advance counters
    if textNeedsRebuild {
        textTexture = context.textRasterizer.rasterize(currentString, ...)
        textNeedsRebuild = false
    }
    advanceVisualAnimation(time: context.time)      // glow pulses, scroll offsets
}
```

This keeps the POC small. When real data sources arrive, refactoring a widget to subscribe to an external `AsyncStream<Snapshot>` is a localized change.

## 6. Widget catalog (10 widgets)

Each widget is a single file under `Sources/Elements/Widgets/`. All share the `WidgetPipeline`; each varies in its update rule, layout, and any extra shader inputs (tint, frame style).

| # | Widget | Position | Mock behavior |
|---|---|---|---|
| 1 | `KPIClusterWidget` | top-left | CPU, GPU, MEM, NET each random-walk inside plausible ranges; update 2Hz; numeric readout + a thin progress bar each |
| 2 | `LLMTelemetryWidget` | top-right | tok/s with bursty noise; ctx fills toward max then resets; cost monotonically increases; latency noise; model name rotates every 30s |
| 3 | `WorldClocksWidget` | top-center | NYC / London / Tokyo / Sydney; ticks every second |
| 4 | `LogStreamWidget` | left, tall | Pulls lines from a pool of mock log strings, 1–3 new lines/sec, with `[INFO]/[WARN]/[ERROR]` levels and timestamps; lines smooth-scroll upward |
| 5 | `TaskListWidget` | right, tall | 8 mock tasks with status (`PENDING/ACTIVE/BLOCKED/DONE`); one "active" task has a progress bar that animates; statuses flip occasionally |
| 6 | `VitalsRingWidget` | around orb (radial overlay) | Battery, CPU temp, fan RPM as arc segments; battery slowly decreases, temp drifts, fan ramps with CPU |
| 7 | `SpectrumBarsWidget` | around orb (radial overlay) | 32 "audio" bars dancing with perlin-noise-like motion at 30Hz visual update |
| 8 | `CompassWidget` | bottom-left | Heading rotates slowly + small noise; cardinal letters drawn in shader |
| 9 | `ScheduleStripWidget` | bottom-center | 3 fixed mock events; countdowns recompute per frame; one event "fires" at intervals (status flashes) |
| 10 | `StatusTickerWidget` | bottom edge | One-line ticker scrolling right-to-left; ~12 mock status messages cycling, new message every 4s |

The text-bearing widgets (1, 2, 3, 4, 5, 8, 9, 10) each manage their own text texture(s). The purely-visual widgets (6, 7) draw in shader only — no text.

## 7. The orb

A fullscreen-quad shader procedurally renders the orb at the screen center.

Visual recipe:
- A central energy core: smooth distance-falloff sphere, cyan-to-bright-cyan gradient.
- 2–3 concentric thin rings rotating slowly at different rates.
- A swirling noise field inside the core boundary (3D noise sampled in 2D + time, gives organic motion).
- A subtle outer halo that pulses on a slow sin wave.
- Pure procedural — no inputs from data, mouse, or audio in v0. Just `time` and `resolution`.

Owned by `OrbElement` (single instance). Lives in `Sources/Elements/OrbElement.swift`, shader in `Sources/Shaders/Orb.metal`.

## 8. Ambient ornaments

A single `OrnamentElement` drawing the persistent HUD chrome that isn't part of any widget:

- Four corner brackets.
- A faint outer scanline pattern (subtle, low-alpha).
- A faint full-screen reticle ring (optional — feels Jarvis-y when very faint).

Drawn first in the scene so widgets/orb overlay correctly.

## 9. File layout

```
MetalPOC/
├── project.yml                      (xcodegen project spec)
├── .gitignore
├── docs/
│   └── superpowers/
│       └── specs/
│           └── 2026-05-13-metal-hud-poc-design.md   (this file)
└── Sources/
    ├── Info.plist
    ├── App/
    │   ├── main.swift
    │   ├── AppDelegate.swift
    │   ├── StatusItemController.swift
    │   ├── HUDWindow.swift
    │   └── HUDWindowController.swift
    ├── Render/
    │   ├── HUDView.swift             (MTKView subclass, transparency config)
    │   ├── Renderer.swift            (MTKViewDelegate, scene encoding)
    │   ├── FrameContext.swift
    │   ├── HUDElement.swift          (protocol)
    │   └── Pipelines.swift           (Orb/Ornament/Widget pipeline factories)
    ├── Text/
    │   └── TextRasterizer.swift      (CoreText → MTLTexture)
    ├── Elements/
    │   ├── OrbElement.swift
    │   ├── OrnamentElement.swift
    │   └── Widgets/
    │       ├── KPIClusterWidget.swift
    │       ├── LLMTelemetryWidget.swift
    │       ├── WorldClocksWidget.swift
    │       ├── LogStreamWidget.swift
    │       ├── TaskListWidget.swift
    │       ├── VitalsRingWidget.swift
    │       ├── SpectrumBarsWidget.swift
    │       ├── CompassWidget.swift
    │       ├── ScheduleStripWidget.swift
    │       └── StatusTickerWidget.swift
    └── Shaders/
        ├── Common.metal              (SDF helpers, blend helpers, palette)
        ├── Orb.metal
        ├── Ornament.metal
        └── Widget.metal              (textured quad + frame + glow)
```

The early scaffolding already written (`Sources/main.swift`, `Sources/AppDelegate.swift`, etc. at the flat level) will be **reorganized** into this structure during implementation — or scrapped and regenerated, whichever the implementation plan prefers. The scaffolding's `Shaders.metal` currently mixes orb + ornament + widget concerns; that gets split into the three shader files above.

## 10. Build & run

- **Tooling**: `xcodegen` (already installed), Xcode 26.5 (already installed).
- **Generate**: `xcodegen generate` produces `MetalPOC.xcodeproj` (gitignored — `project.yml` is the source of truth).
- **Build & run**: open the generated project in Xcode, ⌘R. The HUD appears over the desktop on the main display. Click the `scope` icon in the menu bar → Quit to exit.
- **Target**: macOS 13.0+. Apple Silicon assumed (Intel may work but isn't validated).
- **No code signing** for POC (`CODE_SIGNING_ALLOWED = NO`, `CODE_SIGN_IDENTITY = "-"`). Local dev only.

## 11. Performance targets & acceptance criteria

### Targets
- **60fps sustained** with all 10 widgets active on Apple Silicon.
- **< 5ms GPU time per frame** at the target framerate (well within 16.6ms budget — leaves headroom).
- **< 5% CPU** on an M-series Mac while running.

### Acceptance criteria (the gate for "POC done")
1. The HUD launches and renders the full layout on the main display.
2. The orb animates continuously and looks like an "alive" energy core.
3. All 10 widgets render with their Jarvis-style frames and content.
4. **Every numeric and text element in the widgets is dynamically updating** (no static placeholders). Logs scroll, KPIs tick, countdowns count, ticker scrolls, spectrum bars dance.
5. The HUD stays on top across Spaces and over fullscreen apps.
6. Clicking anywhere on screen passes through to the underlying app — no clicks captured.
7. Menu-bar `Quit` exits cleanly. `Toggle HUD` hides/shows.
8. 60fps sustained for at least 60 seconds of continuous run, by visual inspection (no perceptible stutter) and confirmed by Xcode's Metal frame-time HUD (View → Show Performance HUD in the running app, or Instruments Metal trace).

## 12. Open questions & deferred items

### Open (will be decided during implementation)
- Exact bundled font choice (Menlo vs. Share Tech Mono vs. Orbitron vs. something else).
- Whether to ship texture pooling in v0 or defer until perf measurement says we need it.

### Explicitly deferred (out of scope for this POC; tracked here for product roadmap)
- Real data sources (Combine/AsyncStream subscriptions to actual system metrics, LLM APIs, calendar, task systems).
- Voice in/out and agent state visualization.
- Selective click-through (mouse capture on widget hit-regions while passing other clicks through).
- Multi-monitor and per-display HUD configurations.
- Configuration UI, persistence, hotkeys, custom widget arrangements.
- Bloom/post-process effects (separate render pass).
- Accessibility (VoiceOver is a complicated story for Metal-rendered text).
- Dark/light desktop adaptation (HUD currently assumes "looks good on a dark-ish desktop").
- Unit/snapshot tests.
