import Foundation

/// Turns pad reports into cursor movement and synthesized input.
///
/// The engine is inert until `setEnabled(true)`. Disabling it always releases every action it is
/// holding, so a key or a mouse button can never stay stuck down.
public final class EmulationEngine {
    /// Called on the main queue when the pad itself requests an emergency stop.
    public var onEmergencyStop: (() -> Void)?

    private let queue = DispatchQueue(label: "dev.nacon.emulation")
    private let queueKey = DispatchSpecificKey<Void>()
    private let emitter: InputEmitter
    private var profile: InputProfile
    private let tickInterval: TimeInterval = 1.0 / 60.0

    private var timer: DispatchSourceTimer?
    private var enabled = false
    private var previousReport: XInputReport?
    private var heldActions: [XInputControl: MappedAction] = [:]
    private var leftStick: XInputStick = .center
    private var rightStick: XInputStick = .center
    private var scroll = ScrollAccumulator()
    private var repeatElapsed: [XInputControl: Double] = [:]
    private var nextRepeatAt: [XInputControl: Double] = [:]

    public init(emitter: InputEmitter, profile: InputProfile = .standard) {
        self.emitter = emitter
        self.profile = profile
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
                self.tick(seconds: self.tickInterval)
            }
            source.resume()
            self.timer = source
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
        guard enabled else { return }

        if transitions.pressed.contains(.guide) {
            disableOnQueue(notify: true)
            return
        }
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
            if case .scrollLines = action { continue }
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
        let lines = scroll.consume(linesPerSecond: rate, seconds: seconds)
        if lines != 0 {
            emitter.scroll(lines: lines)
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
                emitter.press(action)
                due = elapsed + interval
            }
            nextRepeatAt[control] = due
        }
    }

    private func disableOnQueue(notify: Bool) {
        guard enabled else { return }
        enabled = false
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
}
