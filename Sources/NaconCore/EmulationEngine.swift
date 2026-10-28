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

    /// Whether the current physical Guide press has already been acted on.
    ///
    /// It lasts until the button is released. `disableOnQueue` clears `previousReport`, so an edge
    /// computed from nil sees the same press again, and without this the emulation would start back up
    /// the instant it stopped.
    private var guideActed = false

    private let queue = DispatchQueue(label: "dev.nacon.emulation")
    private let queueKey = DispatchSpecificKey<Void>()
    private let emitter: InputEmitter
    private var profile: InputProfile
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
    private var heldActions: [XInputControl: MappedAction] = [:]
    private var leftStick: XInputStick = .center
    private var rightStick: XInputStick = .center
    private var scroll = ScrollAccumulator()
    private var repeatElapsed: [XInputControl: Double] = [:]
    private var nextRepeatAt: [XInputControl: Double] = [:]

    public init(
        emitter: InputEmitter,
        profile: InputProfile = .standard,
        uptime: @escaping () -> TimeInterval = {
            TimeInterval(DispatchTime.now().uptimeNanoseconds) / 1_000_000_000
        }
    ) {
        self.emitter = emitter
        self.profile = profile
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

        // S12: Guide toggles the emulation, so it is decided from the button itself and not from the
        // edge. One press means one toggle, whichever direction it went.
        if XInputControl.guide.isPressed(in: report) {
            guard !guideActed else { return }
            guideActed = true
            if enabled {
                disableOnQueue(notify: true)
            } else {
                onGuidePress?()
            }
            return
        }
        guideActed = false

        guard enabled else { return }
        // Release first so a control that swaps action can never leave the old one held.
        for control in transitions.released {
            repeatElapsed.removeValue(forKey: control)
            nextRepeatAt.removeValue(forKey: control)
            if let action = heldActions.removeValue(forKey: control) {
                emitter.release(action)
            }
        }
        for control in transitions.pressed {
            let action = profile.action(for: control)
            guard action != .none else { continue }
            if case .scrollLines(let lines) = action {
                // A press is one step, so there is nothing to hold and nothing to release.
                emitter.scroll(pixels: Scroll.pixels(forLines: lines))
                continue
            }
            heldActions[control] = action
            emitter.press(action)
            if case .key = action {
                repeatElapsed[control] = 0
                nextRepeatAt[control] = profile.keyRepeat.initialDelay
            }
        }
    }

    func setEnabledNow(_ newValue: Bool) {
        if newValue {
            enabled = true
        } else {
            disableOnQueue(notify: false)
        }
    }

    func tick(seconds: Double) {
        guard enabled, seconds > 0 else { return }
        let settings = profile.cursor
        let velocity = StickMotion.cursorVelocity(stick: leftStick, settings: settings)
        if !velocity.isZero {
            emitter.moveCursor(deltaX: velocity.dx * seconds, deltaY: velocity.dy * seconds)
        }
        let rate = StickMotion.scrollLinesPerSecond(stick: rightStick, settings: settings)
        let pixels = scroll.consume(
            pixelsPerSecond: rate * Scroll.pixelsPerLine,
            seconds: seconds
        )
        if pixels != 0 {
            emitter.scroll(pixels: pixels)
        }
        advanceKeyRepeats(seconds: seconds)
    }

    /// A synthesized key-down does not trigger the system keyboard repeat, so a held d-pad
    /// direction would move exactly once. This mirrors the system behaviour: one initial event,
    /// then repeats after a delay.
    private func advanceKeyRepeats(seconds: Double) {
        guard !repeatElapsed.isEmpty else { return }
        let interval = max(profile.keyRepeat.interval, 0.005)
        for (control, action) in heldActions {
            guard case .key = action else { continue }
            guard var elapsed = repeatElapsed[control], var due = nextRepeatAt[control] else { continue }
            elapsed += seconds
            repeatElapsed[control] = elapsed
            // At most one repeat per tick: catching up on missed repeats would burst several
            // key-downs at once after a stall, which would type faster than the user held it.
            if elapsed >= due {
                emitter.repeatKey(action)
                due = elapsed + interval
            }
            nextRepeatAt[control] = due
        }
    }

    private func disableOnQueue(notify: Bool) {
        guard enabled else { return }
        enabled = false
        endActivity()
        scroll.reset()
        for action in heldActions.values {
            emitter.release(action)
        }
        heldActions.removeAll()
        repeatElapsed.removeAll()
        nextRepeatAt.removeAll()
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
