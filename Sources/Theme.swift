import Foundation
import AppKit
import simd

/// All user-tunable visual + timing parameters in one place.
/// Edit values here to retune the HUD; widgets reference these constants.
enum Theme {

    // MARK: - Color palette (RGBA)

    enum Palette {
        static let cyanTint        = SIMD4<Float>(0.20, 0.85, 1.0, 1.0)
        static let brightCyanTint  = SIMD4<Float>(0.55, 0.95, 1.0, 1.0)

        // NSColors used inside rasterized text
        static let textWhite       = NSColor.white
        static let textLogWarn     = NSColor(red: 1.0, green: 0.85, blue: 0.4, alpha: 1.0)
        static let textLogError    = NSColor(red: 1.0, green: 0.50, blue: 0.5, alpha: 1.0)
        static let textTaskActive  = NSColor(red: 0.60, green: 1.0,  blue: 0.8, alpha: 1.0)
        static let textTaskBlocked = NSColor(red: 1.0,  green: 0.55, blue: 0.55, alpha: 1.0)
        static let textTaskDone    = NSColor(white: 0.55, alpha: 1.0)
        static let textScheduleFlash = NSColor(red: 1.0, green: 0.90, blue: 0.40, alpha: 1.0)
        static let textMicroReadout  = NSColor(red: 0.20, green: 0.85, blue: 1.00, alpha: 0.40)
    }

    // MARK: - Widget layout (screen-normalized [0..1], bottom-left origin)

    struct WidgetFrame {
        let origin: SIMD2<Float>
        let size: SIMD2<Float>
    }

    enum Layout {
        static let kpiCluster    = WidgetFrame(origin: SIMD2(0.050, 0.825), size: SIMD2(0.250, 0.065))
        static let llmTelemetry  = WidgetFrame(origin: SIMD2(0.700, 0.810), size: SIMD2(0.250, 0.080))
        static let worldClocks   = WidgetFrame(origin: SIMD2(0.330, 0.895), size: SIMD2(0.340, 0.040))
        static let logStream     = WidgetFrame(origin: SIMD2(0.050, 0.500), size: SIMD2(0.260, 0.260))
        // NOTE: taskList origin/size come from the actual source file, which differs from the
        // original spec suggestion.
        static let taskList      = WidgetFrame(origin: SIMD2(0.690, 0.290), size: SIMD2(0.260, 0.470))
        // NOTE: compass origin/size come from the actual source file.
        static let compass       = WidgetFrame(origin: SIMD2(0.050, 0.170), size: SIMD2(0.220, 0.100))
        static let scheduleStrip = WidgetFrame(origin: SIMD2(0.300, 0.090), size: SIMD2(0.400, 0.045))
        static let statusTicker  = WidgetFrame(origin: SIMD2(0.050, 0.055), size: SIMD2(0.900, 0.025))
        // New procedural widgets
        static let networkTopology = WidgetFrame(origin: SIMD2(0.050, 0.290), size: SIMD2(0.260, 0.180))
        static let forceGraph      = WidgetFrame(origin: SIMD2(0.690, 0.300), size: SIMD2(0.260, 0.300))
        static let wireframeModel  = WidgetFrame(origin: SIMD2(0.430, 0.730), size: SIMD2(0.140, 0.140))
        static let localNetwork    = WidgetFrame(origin: SIMD2(0.330, 0.150), size: SIMD2(0.340, 0.135))
    }

    // MARK: - Fonts

    enum Font {
        // Title font name (Orbitron Bold, bundled). Use with NSFont(name:size:) and fall back to system bold.
        static let titleFamilyName = "Orbitron-Bold"
        // Body font name (Share Tech Mono Regular, bundled). Fall back to system monospaced.
        static let bodyFamilyName  = "ShareTechMono-Regular"

        // Sizes per widget role (in points)
        static let widgetTitleSize:   CGFloat = 13   // matches existing usage across all widgets
        static let widgetBodySize:    CGFloat = 12
        static let logBodySize:       CGFloat = 11
        static let taskBodySize:      CGFloat = 11
        static let microReadoutSize:  CGFloat = 9
        // ScheduleStrip uses size 8 for its micro-readout (intentionally smaller than others).
        static let scheduleStripMicroSize: CGFloat = 8
        static let scheduleStripSize: CGFloat = 36   // intentionally large — fills the strip
        static let statusTickerSize:  CGFloat = 12
        static let compassBodySize:   CGFloat = 12

        // Loaders — return the configured font or a sensible fallback.
        static func title(size: CGFloat) -> NSFont {
            NSFont(name: titleFamilyName, size: size)
                ?? NSFont.monospacedSystemFont(ofSize: size, weight: .bold)
        }
        static func body(size: CGFloat) -> NSFont {
            NSFont(name: bodyFamilyName, size: size)
                ?? NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        }
    }

    // MARK: - Update intervals and animation rates

    enum Tick {
        // KPI cluster random-walk update
        static let kpiUpdateSec: Float = 0.5

        // LLM telemetry
        static let llmUpdateSec: Float = 0.5
        static let llmModelSwapSec: Float = 30

        // World clocks
        static let worldClocksUpdateSec: Float = 1.0

        // Log stream: random delay between new lines
        static let logMinDelaySec: Float = 0.30
        static let logMaxDelaySec: Float = 1.10
        static let logMaxLines: Int = 22

        // Task list
        static let taskShuffleIntervalSec: Float = 8.0
        static let taskActiveProgressPerSec: Float = 0.04

        // Compass
        static let compassDriftDegPerSec: Float = 3.0
        static let compassRedrawSec: Float = 0.25

        // Schedule strip
        static let scheduleRedrawSec: Float = 0.5
        static let scheduleFlashDurSec: Float = 2.0
        static let scheduleResetMinSec: Float = 120
        static let scheduleResetMaxSec: Float = 600

        // Status ticker
        static let tickerScrollSpeedPtsPerSec: Float = 140

        // Spectrum bars
        static let spectrumUpdateSec: Float = 1.0 / 30.0
        static let spectrumBarCount: Int = 32

        // Vitals ring
        static let vitalsUpdateSec: Float = 0.25

        // Boot-up sequence stagger (per-widget reveal delay)
        static let widgetRevealStagger: Float = 0.2

        // New procedural widget rates
        static let forceGraphPhysicsHz: Float = 60
        static let topologyFlowSpeedPerSec: Float = 0.4
        static let modelRotationDegPerSec: Float = 18
    }

    // MARK: - Per-widget reveal delays (staggered boot-up sequence)

    enum Reveal {
        static let kpiCluster:    Float = 0.3
        static let llmTelemetry:  Float = 0.5
        static let worldClocks:   Float = 0.7
        static let logStream:     Float = 0.9
        static let taskList:      Float = 1.1
        static let compass:       Float = 1.3
        static let scheduleStrip: Float = 1.5
        static let statusTicker:  Float = 1.7
        static let networkTopology: Float = 1.9
        static let forceGraph:      Float = 2.1
        static let wireframeModel:  Float = 2.3
        static let localNetwork:    Float = 1.5
    }

    // MARK: - Local Network widget config

    enum LocalNetwork {
        /// Case-insensitive substrings used to identify "the user's phone" in Bonjour names.
        /// Edit this to match your phone's iCloud/Bluetooth name (e.g. "James", "iPhone").
        static let myPhoneNamePatterns: [String] = ["iPhone", "James"]
        /// Max number of devices to display in the body of the widget.
        static let maxDevicesShown: Int = 8
        /// Widget refresh rate (the Bonjour scanner runs continuously; this only controls
        /// how often the rasterized text is rebuilt).
        static let refreshSec: Float = 1.0
    }

    // MARK: - Orb

    enum Orb {
        /// Orb radius in normalized vertical-axis units.
        static let radius: Float = 0.18
        /// Lower-right corner position in aspect-adjusted NDC space.
        /// x = (0.84 * aspect), y = -0.70  (aspect ≈ 1.778 for 16:9 / 6K displays).
        static let compactCenter = SIMD2<Float>(0.84 * 1.778, -0.70)
        /// Smaller radius in compact mode so it sits comfortably in the corner.
        static let compactRadius: Float = 0.10
    }

    // MARK: - Backdrop (NSVisualEffectView + tint sublayer)

    enum Backdrop {
        /// Dark tint applied as a sublayer ON TOP of the NSVisualEffectView blur.
        /// Adjust the alpha to make widgets darker (higher) or more translucent (lower).
        static let tintColor = NSColor(red: 0.03, green: 0.06, blue: 0.10, alpha: 0.55).cgColor
        /// NSVisualEffectView material — chooses the blur style.
        static let blurMaterial: NSVisualEffectView.Material = .hudWindow
        /// Force a dark vibrant appearance regardless of system mode.
        static let blurAppearanceName: NSAppearance.Name = .vibrantDark
    }

    // MARK: - Glitch (RGB-split post-process)

    enum Glitch {
        static let minIntervalSec: Float = 480   // 8 min
        static let maxIntervalSec: Float = 720   // 12 min
        static let burstDurationSec: Float = 0.15
    }
}
