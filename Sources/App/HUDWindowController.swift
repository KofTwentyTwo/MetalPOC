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
        // gets a blur-behind-window backdrop sized to its widget frame, inset slightly so
        // the chamfered Metal frame sits cleanly around it.
        for element in widgets {
            guard let framed = element as? FramedHUDWidget else { continue }
            let widgetRect = NSRect(
                x: CGFloat(framed.origin.x) * sz.width,
                y: CGFloat(framed.origin.y) * sz.height,
                width: CGFloat(framed.size.x) * sz.width,
                height: CGFloat(framed.size.y) * sz.height
            ).insetBy(dx: 3, dy: 3)
            let backdrop = NSVisualEffectView(frame: widgetRect)
            backdrop.material = .hudWindow              // dark-tinted content-aware blur
            backdrop.blendingMode = .behindWindow       // blur what's behind the WINDOW
            backdrop.state = .active                     // always on regardless of key state
            backdrop.wantsLayer = true
            backdrop.layer?.cornerRadius = 4             // soft corners, close to chamfer feel
            backdrop.layer?.masksToBounds = true
            backdrop.autoresizingMask = []               // we manage frames manually
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
}
