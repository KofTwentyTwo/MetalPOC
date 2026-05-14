import Cocoa

final class HUDWindowController: NSWindowController {
    private let hudWindow: HUDWindow
    private let hudView: HUDView

    init() {
        let screenFrame = (NSScreen.main ?? NSScreen.screens.first!).frame
        self.hudView = HUDView(frame: NSRect(origin: .zero, size: screenFrame.size))
        self.hudWindow = HUDWindow(contentView: hudView)
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

        hudView.renderer.scene = [
            OrnamentElement(),
            OrbElement(),
            VitalsRingWidget(),
            SpectrumBarsWidget(),
            kpi, llm, clocks, log, tasks, compass, schedule, ticker
        ]
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
