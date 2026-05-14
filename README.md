# MetalPOC

A proof-of-concept **Jarvis-style transparent heads-up display** rendered entirely in **Apple Metal** on macOS. A central animated orb is surrounded by ten dynamic widgets — system KPIs, LLM telemetry, world clocks, a scrolling log stream, task list, compass, schedule countdowns, status ticker, spectrum analyzer, vitals ring — all updating with live mock data at 60 fps over a frosted-glass blurred backdrop.

This is the rendering and architecture spine for an eventual interactive HUD product. The HUD floats over your desktop on every Space, click-through, with a menu-bar item to switch between full / compact (orb-only in the lower-right corner) / hidden modes.

## Highlights

- **All-Metal rendering** — five shader pipelines (orb / ornament / widget / vitals / spectrum) plus a two-pass glitch post-process
- **CoreText → MTLTexture** text rasterization with sub-pixel scrolling for the marquee
- **`NSVisualEffectView` per-widget backdrops** clipped to chamfered shapes, with an additional dark tint sublayer so widgets read as dark glass regardless of desktop content
- **Bundled fonts** — Share Tech Mono (body) + Orbitron (titles)
- **All tunables centralized** in `Sources/Theme.swift` — palette, layout, font sizes, update intervals, glitch interval, backdrop tint
- **Frosted-glass corner-chamfered widget frames** with header LED, hex-grid texture, scanline drift, inline bar gauges, sparklines, micro-readouts, reactive frame flash
- **Three visibility states** — Full HUD (⌘1), Compact orb-only (⌘2), Hidden (⌘3) — controllable via menu-bar status item

## Screenshots

> Add screenshots to `docs/screenshots/` and link them here.

## Requirements

- macOS 13.0 or newer (developed on macOS 15+)
- Xcode 15+ with Metal toolchain
- Apple Silicon recommended (tested on M-series)
- [xcodegen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Build & Run

```bash
git clone https://github.com/KofTwentyTwo/MetalPOC.git
cd MetalPOC
xcodegen generate
xcodebuild -project MetalPOC.xcodeproj -scheme MetalPOC -configuration Debug build
open build/Debug/MetalPOC.app
```

The HUD appears on the main display and registers a `scope` icon in the macOS menu bar. Switch modes from the menu (Full HUD ⌘1, Compact ⌘2, Hide HUD ⌘3, Quit ⌘Q).

## Architecture

- **Window**: borderless transparent `NSWindow` at `.floating` level, multi-Space (`canJoinAllSpaces`, `stationary`), permanent `ignoresMouseEvents = true` for click-through.
- **Backdrops**: one `NSVisualEffectView` per widget, frame-clipped to the widget's chamfered shape via `CAShapeLayer.mask`, with a `.hudWindow` blur + `.vibrantDark` appearance + a translucent dark sublayer for Jarvis tint.
- **Renderer**: `MTKView` covers the window, a `Renderer` (MTKViewDelegate) drives the per-frame loop. Scene is a flat ordered array of `HUDElement`. Element protocol exposes `update(context:)` and `encode(into:context:)`.
- **Pipelines**: ornament (corner brackets), orb (procedural energy core with rotating rings + halo), widget (textured quad + chamfered frame + scanline + hex grid + LED + flash), vitals (radial gauges), spectrum (32 dancing bars), glitch (post-process RGB-split, fires randomly every 8–12 min).
- **Text**: `TextRasterizer` (CoreText → `MTLTexture`, BGRA8 premultiplied, with chamfer-aware inset). The `StatusTickerWidget` bypasses the shared rasterizer for sub-pixel `CTLineDraw` rendering each frame.
- **Mock data**: each widget owns its own state machine. No external integrations.

## Customization

Everything tunable lives in **`Sources/Theme.swift`**:

| Section | What you can change |
|---|---|
| `Theme.Palette` | All colors (cyan tints, log/task/schedule text colors, micro-readout tint) |
| `Theme.Layout` | Per-widget `origin` and `size` (screen-normalized [0..1], bottom-left origin) |
| `Theme.Font` | Body + title font names, per-role font sizes, loader helpers |
| `Theme.Tick` | Every update interval, animation rate, log line count, bar count, etc. |
| `Theme.Reveal` | Staggered boot-up delays per widget |
| `Theme.Orb` | Radius, compact-mode center + radius |
| `Theme.Backdrop` | Blur material, vibrant appearance, dark-tint color |
| `Theme.Glitch` | RGB-split firing interval (min/max seconds) and burst duration |

Edit a value, rebuild, see the effect everywhere it's used.

## Project Structure

```
Sources/
├── App/                      NSApplication + window + status bar
├── Render/                   Renderer, Pipelines, FrameContext, HUDElement protocol
├── Elements/
│   ├── OrbElement.swift
│   ├── OrnamentElement.swift
│   └── Widgets/              The 10 widget implementations
├── Shaders/                  .metal files (orb, ornament, widget, vitals, spectrum, glitch)
├── Text/                     TextRasterizer (CoreText → MTLTexture)
├── Resources/Fonts/          Bundled Share Tech Mono + Orbitron
└── Theme.swift               All tunable parameters
project.yml                   xcodegen project definition
```

The Xcode project is regenerated from `project.yml`, so `MetalPOC.xcodeproj` is gitignored.

## Tech Stack

Swift 5.9 · AppKit · Metal · MetalKit · CoreText · CoreGraphics · `xcodegen`

## License

[MIT](LICENSE) © James Maes

## Acknowledgments

- Fonts bundled under the [SIL Open Font License](Sources/Resources/Fonts/OFL.txt):
  - [Share Tech Mono](https://fonts.google.com/specimen/Share+Tech+Mono) by Carrois Apostrophe
  - [Orbitron](https://fonts.google.com/specimen/Orbitron) by Matt McInerney
- Inspired by the Jarvis / Iron Man cinematic HUD aesthetic.
