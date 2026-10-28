import Foundation

/// Turns pad reports into cursor movement and synthesized input.
///
/// The engine is inert until `setEnabled(true)`. Disabling it always releases every action it is
/// holding, so a key or a mouse button can never stay stuck down.
public final class EmulationEngine {
    /// Called on the main queue when the pad itself requests an emergency stop.
    public var onEmergencyStop: (() -> Void)?

    /// Called on the I/O queue when Guide is pressed while the emulation is stopped.
    ///
    /// Only that direction is reported: while the emulation runs, Guide is the engine's own emergency
    /// stop, and reporting it as well would toggle twice on a single press. The observer hops to the
    /// main thread, because this fires on the USB queue.
    public var onGuidePress: (() -> Void)?
    /// MOD held while PS was pressed: show the mapping summary instead of toggling. Reading the map
    /// must never stop the pad, so this path bypasses the toggle entirely.
    public var onSummaryPress: (() -> Void)?

    /// Whether the current physical Guide press has already been acted on.
    ///
    /// It lasts until the button is released. `disableOnQueue` clears `previousReport`, so an edge
    /// computed from nil sees the same press again, and without this the emulation would start back up
    /// the instant it stopped.
    private var guideActed = false

    private let queue = DispatchQueue(label: "dev.nacon.emulation")
    private let queueKey = DispatchSpecificKey<Void>()
    /// The mapping being performed. Owned by `performance`, so the mapping the engine reads and the one
    /// the performance plays are the same value instead of two copies to keep in sync.
    private var profile: InputProfile {
        get { performance.profile }
        set { performance.profile = newValue }
    }
    private let emitter: InputEmitter
    private let tickInterval: TimeInterval = 1.0 / 60.0

    private var timer: DispatchSourceTimer?
    private var enabled = false
    /// The clock. Injected so tests can simulate a throttled timer instead of sleeping.
    private let uptime: () -> TimeInterval
    /// Reading of that clock at the previous advance.
    private var lastTick: TimeInterval?
    /// Largest step one callback may advance. A stalled thread must not fling the pointer across the
    /// screen when it wakes up.
    private let maxTickStep: TimeInterval = 0.1
    /// Held while emulation runs. Without it macOS coalesces the timer and throttles the app once it is
    /// in the background, which is where the user actually is.
    private var activity: NSObjectProtocol?
    private var previousReport: XInputReport?
    /// S2, S3: what a press does over time — hold, repeat, command steps, scroll, cursor. It takes the
    /// seconds as an argument and answers with effects, so nothing here waits for a clock.
    private var performance = PadPerformance()
    /// The sticks of the last report. They belong to the engine, which is what reads the report; the
    /// performance only receives them when time advances.
    private var leftStick: XInputStick = .center
    private var rightStick: XInputStick = .center

    public init(
        emitter: InputEmitter,
        profile: InputProfile = .standard,
        uptime: @escaping () -> TimeInterval = {
            TimeInterval(DispatchTime.now().uptimeNanoseconds) / 1_000_000_000
        }
    ) {
        self.emitter = emitter
        self.performance = PadPerformance(profile: profile)
        self.uptime = uptime
        queue.setSpecific(key: queueKey, value: ())
    }

    deinit {
        timer?.cancel()
    }

    public func start() {
        queue.async { [weak self] in
            guard let self, self.timer == nil else { return }
            let source = DispatchSource.makeTimerSource(queue: self.queue)
            source.schedule(deadline: .now(), repeating: self.tickInterval)
            source.setEventHandler { [weak self] in
                guard let self else { return }
                self.advance(now: self.uptime())
            }
            source.resume()
            self.timer = source
            self.lastTick = nil
        }
    }

    /// Stops the engine and releases anything it is holding.
    ///
    /// This runs synchronously so that a caller on the way out (window close, application
    /// termination) can be sure the key-release events were posted before the process ends.
    public func stop() {
        let shutdown = { [weak self] in
            guard let self else { return }
            self.disableOnQueue(notify: false)
            self.timer?.cancel()
            self.timer = nil
            self.lastTick = nil
        }
        if DispatchQueue.getSpecific(key: queueKey) != nil {
            shutdown()
        } else {
            queue.sync(execute: shutdown)
        }
    }

    public func setEnabled(_ newValue: Bool) {
        queue.async { [weak self] in
            guard let self else { return }
            if newValue {
                self.enabled = true
                self.beginActivity()
            } else {
                self.disableOnQueue(notify: false)
            }
        }
    }

    /// Replaces the active profile, for example after the user flips the vertical axis.
    public func setProfile(_ newProfile: InputProfile) {
        queue.async { [weak self] in
            self?.profile = newProfile
        }
    }

    /// Feeds one input report. Called for every report, before any UI throttling.
    public func ingest(_ report: XInputReport) {
        queue.async { [weak self] in
            self?.handle(report)
        }
    }

    // MARK: - Synchronous core (also used directly by tests)

    func handle(_ report: XInputReport) {
        leftStick = report.leftStick
        rightStick = report.rightStick
        let transitions = ControlEdges.transitions(from: previousReport, to: report)
        previousReport = report

        // The layer is read from the report that presses the control, and the MOD key itself emits
        // nothing: it is a selector, not a "hold modifier". What a control already sent lives in
        // `performance`, so releasing the MOD key later never swaps the action under a button that is
        // still down — the release is always the release of what was pressed. It is computed before
        // the Guide branch because MOD+PS means "show the summary", even while stopped.
        let layerKey = profile.layer.key
        let layerHeld = layerKey.map { $0.isPressed(in: report) } ?? false

        // S12: Guide toggles the emulation, so it is decided from the button itself and not from the
        // edge. One press means one toggle, whichever direction it went.
        if XInputControl.guide.isPressed(in: report) {
            guard !guideActed else { return }
            guideActed = true
            if layerHeld {
                onSummaryPress?()
            } else if enabled {
                disableOnQueue(notify: true)
            } else {
                onGuidePress?()
            }
            return
        }
        guideActed = false
        let layerActive = layerHeld

        guard enabled else { return }
        // Release first so a control that swaps action can never leave the old one held.
        var effects: [PerformanceEffect] = []
        for control in transitions.released {
            effects.append(contentsOf: performance.release(control))
        }
        for control in transitions.pressed {
            guard control != layerKey else { continue }
            let action = profile.action(for: control, layerActive: layerActive)
            guard action != .none else { continue }
            effects.append(contentsOf: performance.press(control, action: action))
        }
        emit(effects)
    }

    func setEnabledNow(_ newValue: Bool) {
        if newValue {
            enabled = true
        } else {
            disableOnQueue(notify: false)
        }
    }

    func tick(seconds: Double) {
        guard enabled else { return }
        emit(performance.advance(seconds: seconds, leftStick: leftStick, rightStick: rightStick))
    }

    /// One place that turns effects into emitter calls.
    ///
    /// `releaseHeldModifiers` is deliberately not an effect: it is the engine's safety net for the
    /// modifiers it is holding outside any mapping, so it stays a call the engine makes itself.
    private func emit(_ effects: [PerformanceEffect]) {
        for effect in effects {
            switch effect {
            case .press(let action):
                emitter.press(action)
            case .release(let action):
                emitter.release(action)
            case .repeatKey(let action):
                emitter.repeatKey(action)
            case .moveCursor(let deltaX, let deltaY):
                emitter.moveCursor(deltaX: deltaX, deltaY: deltaY)
            case .scroll(let pixels):
                emitter.scroll(pixels: pixels)
            }
        }
    }

    private func disableOnQueue(notify: Bool) {
        guard enabled else { return }
        enabled = false
        endActivity()
        // Everything held is released and every run stops: a key or a button must never stay stuck down
        // after the user asked for the emulation to stop.
        emit(performance.reset())
        emitter.releaseHeldModifiers()
        previousReport = nil
        if notify {
            DispatchQueue.main.async { [weak self] in
                self?.onEmergencyStop?()
            }
        }
    }

    /// Advances the engine to `now` on the injected clock.
    ///
    /// This is what the timer handler calls, and the only thing it does is decide how much time passed:
    /// keeping it separate from the timer is what makes the throttled case testable without waiting for
    /// macOS to throttle anything.
    func advance(now: TimeInterval) {
        let elapsed = lastTick.map { now - $0 }
        lastTick = now
        tick(
            seconds: Self.tickStep(elapsed: elapsed, nominal: tickInterval, limit: maxTickStep)
        )
    }

    /// How long one timer callback may advance the pointer.
    ///
    /// The timer is a hint, not a metronome: macOS coalesces it, and once the app sits in the
    /// background it can run far less often. Advancing a fixed step per callback made the cursor crawl
    /// exactly when the user was working in another application, which is the usual case for a tool
    /// like this. The step is therefore the time that really passed, capped so a woken thread cannot
    /// move the pointer across the screen in one go.
    static func tickStep(elapsed: TimeInterval?, nominal: TimeInterval, limit: TimeInterval) -> Double {
        guard let elapsed, elapsed.isFinite, elapsed > 0 else { return nominal }
        return min(elapsed, limit)
    }

    /// Tells macOS this process is busy driving the pointer, so it stops throttling it.
    ///
    /// Without it the timer above keeps working but is coalesced, and the app is a candidate for App
    /// Nap as soon as its window is not in front — exactly when the emulation is being used.
    private func beginActivity() {
        guard activity == nil else { return }
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .latencyCritical],
            reason: "La emulación mueve el cursor y pulsa teclas"
        )
    }

    private func endActivity() {
        guard let activity else { return }
        ProcessInfo.processInfo.endActivity(activity)
        self.activity = nil
    }
}
