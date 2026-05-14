import Cocoa

enum HUDMode {
    case full        // orb at center + all widgets + ornaments visible
    case compact     // only orb visible, positioned in lower-right corner
    case hidden      // window not visible
}

final class HUDWindowController: NSWindowController {
    private let hudWindow: HUDWindow
    private let hudView: HUDView
    private var backdropViews: [NSVisualEffectView] = []
    private var mode: HUDMode = .full

    // Persistent element references — reused across mode switches.
    private let orbElement = OrbElement()
    private let ornamentElement = OrnamentElement()
    private let vitalsWidget = VitalsRingWidget()
    private let spectrumWidget = SpectrumBarsWidget()

    // Framed text widgets (strong references so state is preserved across mode switches).
    private let kpi: KPIClusterWidget
    private let llm: LLMTelemetryWidget
    private let clocks: WorldClocksWidget
    private let log: LogStreamWidget
    private let tasks: TaskListWidget
    private let compass: CompassWidget
    private let schedule: ScheduleStripWidget
    private let ticker: StatusTickerWidget

    init() {
        let screenFrame = (NSScreen.main ?? NSScreen.screens.first!).frame
        self.hudView = HUDView(frame: NSRect(origin: .zero, size: screenFrame.size))
        self.hudWindow = HUDWindow()

        // Build staggered-reveal framed widgets.
        let kpi_ = KPIClusterWidget();         kpi_.revealDelay = Theme.Reveal.kpiCluster
        let llm_ = LLMTelemetryWidget();       llm_.revealDelay = Theme.Reveal.llmTelemetry
        let clocks_ = WorldClocksWidget();     clocks_.revealDelay = Theme.Reveal.worldClocks
        let log_ = LogStreamWidget();          log_.revealDelay = Theme.Reveal.logStream
        let tasks_ = TaskListWidget();         tasks_.revealDelay = Theme.Reveal.taskList
        let compass_ = CompassWidget();        compass_.revealDelay = Theme.Reveal.compass
        let schedule_ = ScheduleStripWidget(); schedule_.revealDelay = Theme.Reveal.scheduleStrip
        let ticker_ = StatusTickerWidget();    ticker_.revealDelay = Theme.Reveal.statusTicker

        self.kpi = kpi_
        self.llm = llm_
        self.clocks = clocks_
        self.log = log_
        self.tasks = tasks_
        self.compass = compass_
        self.schedule = schedule_
        self.ticker = ticker_

        super.init(window: hudWindow)

        // Collect all framed widgets to build backdrops.
        let framedWidgets: [HUDElement] = [kpi, llm, clocks, log, tasks, compass, schedule, ticker]

        let container = hudWindow.containerView
        let sz = screenFrame.size
        let aspect = sz.width / sz.height

        // Add NSVisualEffectView backdrops for every framed widget (beneath the MTKView).
        for element in framedWidgets {
            guard let framed = element as? FramedHUDWidget else { continue }
            let widgetRect = NSRect(
                x: CGFloat(framed.origin.x) * sz.width,
                y: CGFloat(framed.origin.y) * sz.height,
                width: CGFloat(framed.size.x) * sz.width,
                height: CGFloat(framed.size.y) * sz.height
            )
            let backdrop = NSVisualEffectView(frame: widgetRect)
            backdrop.material = Theme.Backdrop.blurMaterial
            backdrop.blendingMode = .behindWindow
            backdrop.state = .active
            backdrop.appearance = NSAppearance(named: Theme.Backdrop.blurAppearanceName)
            backdrop.wantsLayer = true
            backdrop.autoresizingMask = []
            let halfXadj = CGFloat(framed.size.x) * aspect * 0.5
            let halfY = CGFloat(framed.size.y) * 0.5
            let chamferLeg = 2.0 * min(halfXadj, halfY) * 0.10 * sz.height
            let chamferPath = HUDWindowController.chamferedRectPath(
                width: widgetRect.width,
                height: widgetRect.height,
                chamfer: chamferLeg
            )
            let mask = CAShapeLayer()
            mask.frame = CGRect(origin: .zero, size: widgetRect.size)
            mask.path = chamferPath
            mask.fillColor = NSColor.black.cgColor
            backdrop.layer?.mask = mask
            let darkTint = CALayer()
            darkTint.frame = CGRect(origin: .zero, size: widgetRect.size)
            darkTint.backgroundColor = Theme.Backdrop.tintColor
            backdrop.layer?.addSublayer(darkTint)
            container.addSubview(backdrop)
            backdropViews.append(backdrop)
        }

        // Add HUDView (MTKView, transparent) on top of all backdrops.
        hudView.frame = NSRect(origin: .zero, size: sz)
        hudView.autoresizingMask = [.width, .height]
        container.addSubview(hudView)

        // Wire up the scene via setMode so there is one code path.
        setMode(.full)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func showWindow(_ sender: Any?) {
        hudWindow.orderFrontRegardless()
    }

    // MARK: - Mode switching

    func setMode(_ newMode: HUDMode) {
        mode = newMode
        switch newMode {
        case .hidden:
            hudWindow.orderOut(nil)

        case .full:
            orbElement.center = SIMD2(0, 0)
            orbElement.radius = Theme.Orb.radius
            hudView.renderer.scene = [
                ornamentElement,
                orbElement,
                vitalsWidget,
                spectrumWidget,
                kpi, llm, clocks, log, tasks, compass, schedule, ticker
            ]
            for v in backdropViews { v.isHidden = false }
            hudWindow.orderFrontRegardless()

        case .compact:
            orbElement.center = Theme.Orb.compactCenter
            orbElement.radius = Theme.Orb.compactRadius
            // Only the orb: no ornament, no vitals/spectrum (sized for center), no framed widgets.
            hudView.renderer.scene = [orbElement]
            for v in backdropViews { v.isHidden = true }
            hudWindow.orderFrontRegardless()
        }
    }

    func cycleMode() {
        let next: HUDMode
        switch mode {
        case .full:    next = .compact
        case .compact: next = .hidden
        case .hidden:  next = .full
        }
        setMode(next)
    }

    func setFull()    { setMode(.full) }
    func setCompact() { setMode(.compact) }
    func setHidden()  { setMode(.hidden) }

    // MARK: - Chamfered backdrop path

    /// Builds a CGPath for a rectangle with top-left and bottom-right 45° chamfered corners
    /// (top-right and bottom-left stay square) — matches the shape of the Metal widget frame.
    private static func chamferedRectPath(width w: CGFloat, height h: CGFloat, chamfer n: CGFloat) -> CGPath {
        let clampedN = max(0, min(n, min(w, h) * 0.5))
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: w - clampedN, y: 0))
        path.addLine(to: CGPoint(x: w, y: clampedN))
        path.addLine(to: CGPoint(x: w, y: h))
        path.addLine(to: CGPoint(x: clampedN, y: h))
        path.addLine(to: CGPoint(x: 0, y: h - clampedN))
        path.closeSubpath()
        return path
    }
}
