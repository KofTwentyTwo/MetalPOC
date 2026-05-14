import Cocoa

final class HUDWindowController: NSWindowController {
    private let hudWindow: HUDWindow
    private let hudView: HUDView
    private var backdropViews: [NSVisualEffectView] = []

    init() {
        let screenFrame = (NSScreen.main ?? NSScreen.screens.first!).frame
        self.hudView = HUDView(frame: NSRect(origin: .zero, size: screenFrame.size))
        self.hudWindow = HUDWindow()
        super.init(window: hudWindow)

        // Staggered boot-up reveal: ornament/orb/rings appear immediately,
        // text widgets pop in sequentially 200ms apart.
        let kpi = KPIClusterWidget();          kpi.revealDelay = 0.3
        let llm = LLMTelemetryWidget();        llm.revealDelay = 0.5
        let clocks = WorldClocksWidget();      clocks.revealDelay = 0.7
        let log = LogStreamWidget();           log.revealDelay = 0.9
        let tasks = TaskListWidget();          tasks.revealDelay = 1.1
        let compass = CompassWidget();         compass.revealDelay = 1.3
        let schedule = ScheduleStripWidget();  schedule.revealDelay = 1.5
        let ticker = StatusTickerWidget();     ticker.revealDelay = 1.7

        let widgets: [HUDElement] = [
            OrnamentElement(),
            OrbElement(),
            VitalsRingWidget(),
            SpectrumBarsWidget(),
            kpi, llm, clocks, log, tasks, compass, schedule, ticker
        ]
        hudView.renderer.scene = widgets

        let container = hudWindow.containerView
        let sz = screenFrame.size

        // Step 1: add NSVisualEffectView backdrops UNDER the MTKView. Each framed widget
        // gets a blur-behind-window backdrop sized to its widget frame, clipped to the same
        // chamfered shape (TL + BR 45° cuts) as the Metal widget frame so the gray doesn't
        // peek out past the chamfered corners.
        let aspect = sz.width / sz.height
        for element in widgets {
            guard let framed = element as? FramedHUDWidget else { continue }
            let widgetRect = NSRect(
                x: CGFloat(framed.origin.x) * sz.width,
                y: CGFloat(framed.origin.y) * sz.height,
                width: CGFloat(framed.size.x) * sz.width,
                height: CGFloat(framed.size.y) * sz.height
            )
            let backdrop = NSVisualEffectView(frame: widgetRect)
            // .sidebar + vibrantLight gives the classic Apple frosted-glass look:
            // lighter overall tint, more transparent than fullScreenUI, with the
            // heavier gaussian blur that sidebars and popovers use.
            backdrop.material = .sidebar
            backdrop.blendingMode = .behindWindow
            backdrop.state = .active
            backdrop.appearance = NSAppearance(named: .vibrantLight)
            backdrop.wantsLayer = true
            backdrop.autoresizingMask = []
            // Compute chamfer leg in NSView points to match the Metal shader exactly.
            // The Metal SDF plane `tlPlane = -(px.x + half_.x - notchSize) + (px.y - half_.y + notchSize)`
            // intersects the edges at distance 2*notchSize from each corner (solve tlPlane=0
            // on px.y=half_.y → px.x = -half_.x + 2*notchSize; ditto on left edge). So the
            // chamfer leg in normalized-y units is 2 * notchSize, not 1 * notchSize.
            //   notchSize_metal = min(half_x_aspectAdjusted, half_y) * 0.10  (normalized y)
            //   chamferLeg_pts  = 2 * notchSize_metal * screen_height_pts
            let halfXadj = CGFloat(framed.size.x) * aspect * 0.5
            let halfY = CGFloat(framed.size.y) * 0.5
            let chamferLeg = 2.0 * min(halfXadj, halfY) * 0.10 * sz.height
            let mask = CAShapeLayer()
            mask.frame = CGRect(origin: .zero, size: widgetRect.size)
            mask.path = HUDWindowController.chamferedRectPath(
                width: widgetRect.width,
                height: widgetRect.height,
                chamfer: chamferLeg
            )
            mask.fillColor = NSColor.black.cgColor
            backdrop.layer?.mask = mask
            container.addSubview(backdrop)
            backdropViews.append(backdrop)
        }

        // Step 2: add HUDView (MTKView, transparent) ON TOP of all backdrops.
        hudView.frame = NSRect(origin: .zero, size: sz)
        hudView.autoresizingMask = [.width, .height]
        container.addSubview(hudView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func showWindow(_ sender: Any?) {
        hudWindow.orderFrontRegardless()
    }

    func toggleVisibility() {
        if hudWindow.isVisible {
            hudWindow.orderOut(nil)
        } else {
            hudWindow.orderFrontRegardless()
        }
    }

    /// Builds a CGPath for a rectangle with top-left and bottom-right 45° chamfered corners
    /// (top-right and bottom-left stay square) — matches the shape of the Metal widget frame.
    /// Coordinates are bottom-left origin (NSView default).
    private static func chamferedRectPath(width w: CGFloat, height h: CGFloat, chamfer n: CGFloat) -> CGPath {
        let clampedN = max(0, min(n, min(w, h) * 0.5))
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 0))                // BL (square)
        path.addLine(to: CGPoint(x: w - clampedN, y: 0))   // → bottom edge to start of BR chamfer
        path.addLine(to: CGPoint(x: w, y: clampedN))       // → BR chamfer diagonal
        path.addLine(to: CGPoint(x: w, y: h))              // → right edge to TR (square)
        path.addLine(to: CGPoint(x: clampedN, y: h))       // → top edge to start of TL chamfer
        path.addLine(to: CGPoint(x: 0, y: h - clampedN))   // → TL chamfer diagonal
        path.closeSubpath()                                 // → left edge back to BL
        return path
    }
}
