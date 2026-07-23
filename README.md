# MetalPOC

**Jarvis-Style Transparent Metal HUD for macOS**

A proof-of-concept transparent heads-up display rendered entirely in Apple Metal on macOS. A central animated energy orb is surrounded by ten dynamic widgets — system KPIs, LLM telemetry, world clocks, scrolling log stream, task list, compass, schedule countdowns, status ticker, spectrum analyzer, and vitals ring — updating at 60 fps over a frosted-glass blurred backdrop.

This forms the rendering and shader pipeline architecture powering [Jarvis](https://github.com/KofTwentyTwo/Jarvis). The HUD floats over your desktop on every Space with click-through enabled, featuring a status item menu to switch between Full, Compact, and Hidden modes.

---

## Technical Highlights

- **All-Metal Graphics**: Five specialized shader pipelines (orb, ornament, widget, vitals, spectrum) plus a two-pass post-process RGB-split glitch pipeline.
- **CoreText to MTLTexture**: Text rasterization with sub-pixel marquee scrolling for live status streaming.
- **Per-Widget Chamfered Backdrops**: Individual `NSVisualEffectView` layers clipped to chamfered shapes with dark glass tint overlays.
- **Bundled Typography**: Share Tech Mono (body) and Orbitron (display) bundled under SIL Open Font License.
- **Centralized Parameterization**: All layout, palette, animation rates, and shader constants centralized in `Sources/Theme.swift`.
- **Mode Switching**: Full HUD (⌘1), Compact orb-only (⌘2), and Hidden (⌘3) modes via menu-bar item.

---

## System Requirements

- **Operating System**: macOS 13.0 or newer (macOS 15+ recommended)
- **Graphics & Hardware**: Apple Silicon GPU (M-series required)
- **Developer Tools**: Xcode 15+ with Metal toolchain & `xcodegen` (`brew install xcodegen`)

---

## Build & Installation

```bash
# Clone repository
git clone https://github.com/KofTwentyTwo/MetalPOC.git
cd MetalPOC

# Generate Xcode project bundle
xcodegen generate

# Build release application bundle
xcodebuild -project MetalPOC.xcodeproj -scheme MetalPOC -configuration Release build

# Launch HUD application
open build/Release/MetalPOC.app
```

---

## Architecture Overview

- **Window Host**: Borderless transparent `NSWindow` set to `.floating` window level, multi-Space enabled (`canJoinAllSpaces`, `stationary`), with `ignoresMouseEvents = true` for click-through behavior.
- **Glass Backdrops**: One `NSVisualEffectView` per widget, frame-clipped to chamfered geometry via `CAShapeLayer.mask` with `.hudWindow` blur and `.vibrantDark` appearance.
- **Renderer Loop**: `MTKViewDelegate` per-frame render pipeline encoding scene elements into `MTLCommandBuffer` command streams.
- **Shader Pipelines**:
  - `OrnamentPipeline`: Corner framing brackets.
  - `OrbPipeline`: Procedural energy core with counter-rotating rings and radial halo.
  - `WidgetPipeline`: Textured quads with chamfered borders, scanlines, hex grid, and LED indicators.
  - `VitalsPipeline`: Radial progress ring gauges.
  - `SpectrumPipeline`: 32-channel audio spectrum visualization.
  - `GlitchPipeline`: Post-process RGB-split shader firing on randomized intervals.

---

## Project Structure

```
Sources/
├── App/                      NSApplication host, window setup, and status item
├── Render/                   Renderer, Metal pipelines, FrameContext, HUDElement protocol
├── Elements/
│   ├── OrbElement.swift
│   ├── OrnamentElement.swift
│   └── Widgets/              The 10 dynamic widget implementations
├── Shaders/                  Metal shader files (orb, ornament, widget, vitals, spectrum, glitch)
├── Text/                     TextRasterizer (CoreText to MTLTexture converter)
├── Resources/Fonts/          Bundled Share Tech Mono and Orbitron fonts
└── Theme.swift               Centralized theme constants and layout parameters
```

---

## Tech Stack & Dependencies

- **Language**: Swift 5.9 / Swift 6.0
- **Frameworks**: AppKit, Metal, MetalKit, CoreText, CoreGraphics
- **Project Generator**: XcodeGen (`project.yml`)

---

## License & Credits

- **License**: MIT License. See [LICENSE](LICENSE) for details.
- **Bundled Fonts**: [Share Tech Mono](https://fonts.google.com/specimen/Share+Tech+Mono) by Carrois Apostrophe and [Orbitron](https://fonts.google.com/specimen/Orbitron) by Matt McInerney (OFL).
