import Foundation

/// S2, S3: one thing to emit, decided by `PadPerformance` and carried out by the engine.
///
/// The value never touches the system: it says what should happen, in the order it should happen, and
/// the engine is the only place that knows about `InputEmitter`. That is what makes the behaviour of a
/// press testable without a timer, a queue or a real event tap.
public enum PerformanceEffect: Equatable, Sendable {
    /// Start holding an action: a key down, a mouse button down, or a stroke of a command.
    case press(MappedAction)
    /// Let go of an action that was held.
    case release(MappedAction)
    /// One repeat of a held key, with the key already down.
    case repeatKey(MappedAction)
    /// Move the pointer by a delta, in points.
    case moveCursor(deltaX: Double, deltaY: Double)
    /// Turn the wheel by a number of pixels.
    case scroll(pixels: Int)
}

/// S2, S3: what one press does over time, with time as an argument.
///
/// This is the behaviour that used to live inside `EmulationEngine`: hold the action, repeat a held
/// key, run a command one step per tick, scroll once, move the cursor from the stick. It is a value
/// with no timer, no queue and no clock — `press`, `release`, `advance(seconds:leftStick:rightStick:)`
/// and `reset` take everything they need and return the effects to emit, so the caller decides when
/// time passes and this type only says what that time produced.
///
/// The engine keeps what depends on the report rather than on the action: the edge computation, the
/// layer read at press time, Guide and MOD+PS, the timer, the App Nap activity and the final release of
/// every held modifier.
public struct PadPerformance {
    /// The mapping being performed. Owned here so a command, a repeat and a scroll cadence all read
    /// the same settings the engine was started with.
    public var profile: InputProfile

    /// A command still emitting: the steps left and the index of the next one.
    private struct PendingCommand {
        let steps: [KeyCombo]
        var next: Int
    }

    private var heldActions: [XInputControl: MappedAction] = [:]
    /// Commands in progress, one per control. A press emits the first step at once and the rest at one
    /// step per advance, which gives the target application a chance to act between them — ⌘A must take
    /// effect before the ⌘C that follows.
    private var pendingCommands: [XInputControl: PendingCommand] = [:]
    private var scroll = ScrollAccumulator()
    private var repeatElapsed: [XInputControl: Double] = [:]
    private var nextRepeatAt: [XInputControl: Double] = [:]

    public init(profile: InputProfile = .standard) {
        self.profile = profile
    }

    /// S6: what one action does when its control goes down, in one place per kind.
    ///
    /// - Scroll: one event, so there is nothing to hold and nothing to release.
    /// - Command: a run, not a hold. Nothing is released at the end and holding the control must not
    ///   repeat it, so it starts its steps and holds nothing.
    /// - Everything else: held, so it is pressed now and released with the control.
    public mutating func press(_ control: XInputControl, action: MappedAction) -> [PerformanceEffect] {
        if case .scrollLines(let lines) = action {
            return [.scroll(pixels: Scroll.pixels(forLines: lines))]
        }
        if case .sequence(let steps) = action, !steps.isEmpty {
            // The first step goes out now so the control answers the press without a delay.
            let effects = Self.stepEffects(steps[0])
            if steps.count > 1 {
                pendingCommands[control] = PendingCommand(steps: steps, next: 1)
            }
            return effects
        }
        heldActions[control] = action
        // A synthesized key-down does not trigger the system keyboard repeat, so a held d-pad direction
        // would move exactly once. The clock starts here and `advance` mirrors the system behaviour: one
        // initial event, then repeats after a delay. A modifier hold never repeats: it is a key held
        // down for another control to combine with, so repeating it would tap the modifier.
        if case .key(let combo) = action, !combo.isModifierHold {
            repeatElapsed[control] = 0
            nextRepeatAt[control] = profile.keyRepeat.initialDelay
        }
        return [.press(action)]
    }

    /// Lets go of one control: its repeat bookkeeping, its pending command and the action it held.
    ///
    /// A run still in progress stops here, because its remaining steps belong to a press that ended.
    public mutating func release(_ control: XInputControl) -> [PerformanceEffect] {
        repeatElapsed.removeValue(forKey: control)
        nextRepeatAt.removeValue(forKey: control)
        pendingCommands.removeValue(forKey: control)
        guard let action = heldActions.removeValue(forKey: control) else { return [] }
        return [.release(action)]
    }

    /// Everything one slice of time produces, in the order the engine emits it: cursor, one step of
    /// each command in progress, scrolling, and key repeats.
    public mutating func advance(
        seconds: Double,
        leftStick: XInputStick,
        rightStick: XInputStick
    ) -> [PerformanceEffect] {
        guard seconds > 0 else { return [] }
        var effects: [PerformanceEffect] = []
        let settings = profile.cursor
        let velocity = StickMotion.cursorVelocity(stick: leftStick, settings: settings)
        if !velocity.isZero {
            effects.append(.moveCursor(deltaX: velocity.dx * seconds, deltaY: velocity.dy * seconds))
        }
        effects.append(contentsOf: advanceCommands())
        let rate = StickMotion.scrollLinesPerSecond(stick: rightStick, settings: settings)
        let pixels = scroll.consume(
            pixelsPerSecond: rate * Scroll.pixelsPerLine,
            seconds: seconds
        )
        if pixels != 0 {
            effects.append(.scroll(pixels: pixels))
        }
        effects.append(contentsOf: advanceKeyRepeats(seconds: seconds))
        return effects
    }

    /// Drops everything and hands back the releases, which is what the safety net in the engine emits
    /// when the emulation stops: a key or a mouse button must never stay stuck down.
    public mutating func reset() -> [PerformanceEffect] {
        scroll.reset()
        let effects = heldActions.values.map { PerformanceEffect.release($0) }
        heldActions.removeAll()
        // A command stops with the emulation: its remaining steps would fire into whatever is in front
        // of the user after they asked it to stop.
        pendingCommands.removeAll()
        repeatElapsed.removeAll()
        nextRepeatAt.removeAll()
        return effects
    }

    // MARK: - Time

    /// One step of every command in progress, one per advance, in the same order the runs started.
    private mutating func advanceCommands() -> [PerformanceEffect] {
        guard !pendingCommands.isEmpty else { return [] }
        var effects: [PerformanceEffect] = []
        for (control, var run) in Array(pendingCommands) {
            effects.append(contentsOf: Self.stepEffects(run.steps[run.next]))
            run.next += 1
            if run.next >= run.steps.count {
                pendingCommands.removeValue(forKey: control)
            } else {
                pendingCommands[control] = run
            }
        }
        return effects
    }

    /// At most one repeat per held key per advance.
    ///
    /// Catching up on missed repeats would burst several key-downs at once after a stall, which would
    /// type faster than the user held it, so the interval is moved forward from the elapsed time
    /// instead of from the due time.
    private mutating func advanceKeyRepeats(seconds: Double) -> [PerformanceEffect] {
        guard !repeatElapsed.isEmpty else { return [] }
        let interval = max(profile.keyRepeat.interval, 0.005)
        var effects: [PerformanceEffect] = []
        for (control, action) in heldActions {
            guard case .key = action else { continue }
            guard var elapsed = repeatElapsed[control], var due = nextRepeatAt[control] else { continue }
            elapsed += seconds
            repeatElapsed[control] = elapsed
            if elapsed >= due {
                effects.append(.repeatKey(action))
                due = elapsed + interval
            }
            nextRepeatAt[control] = due
        }
        return effects
    }

    /// One step of a command: a complete stroke, so a step can never leave a key or a modifier down.
    private static func stepEffects(_ step: KeyCombo) -> [PerformanceEffect] {
        [.press(.key(step)), .release(.key(step))]
    }
}
