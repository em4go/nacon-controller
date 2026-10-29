import Foundation

/// S2, S3: one thing to emit, decided by `PadPerformance` and carried out by the engine.
///
/// The value never touches the system: it says what should happen, in the order it should happen, and
/// the engine is the only place that knows about `InputEmitter`. That is what makes the behaviour of a
/// press testable without a timer, a queue or a real event tap.
enum PerformanceEffect: Equatable, Sendable {
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
struct PadPerformance {
    /// The mapping being performed. Owned here so a command, a repeat and a scroll cadence all read
    /// the same settings the engine was started with.
    var profile: InputProfile

    /// A command still emitting: the steps left and the index of the next one.
    private struct PendingCommand {
        let steps: [KeyCombo]
        var next: Int
    }

    /// Everything held for one control: the action that went down and, for a key that repeats, its
    /// clock. One map carries both, so a repeat clock cannot outlive the key it belongs to.
    private struct Held {
        let action: MappedAction
        var repeatState: RepeatState?
    }

    /// The repeat clock of one held key: time since the press and when the next repeat is due.
    private struct RepeatState {
        var elapsed: Double
        var due: Double
    }

    private var held: [XInputControl: Held] = [:]
    /// Commands in progress, one per control. A press emits the first step at once and the rest at one
    /// step per advance, which gives the target application a chance to act between them — ⌘A must take
    /// effect before the ⌘C that follows.
    private var pendingCommands: [XInputControl: PendingCommand] = [:]
    private var scroll = ScrollAccumulator()

    init(profile: InputProfile = .standard) {
        self.profile = profile
    }

    /// S6: what one action does when its control goes down, in one place per kind.
    ///
    /// - Scroll: one event, so there is nothing to hold and nothing to release.
    /// - Command: a run, not a hold. Nothing is released at the end and holding the control must not
    ///   repeat it, so it starts its steps and holds nothing.
    /// - Everything else: held, so it is pressed now and released with the control.
    mutating func press(_ control: XInputControl, action: MappedAction) -> [PerformanceEffect] {
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
        // A synthesized key-down does not trigger the system keyboard repeat, so a held d-pad direction
        // would move exactly once. The clock starts here and `advance` mirrors the system behaviour: one
        // initial event, then repeats after a delay. A modifier hold never repeats: it is a key held
        // down for another control to combine with, so repeating it would tap the modifier.
        var repeatState: RepeatState?
        if case .key(let combo) = action, !combo.isModifierHold {
            repeatState = RepeatState(elapsed: 0, due: profile.keyRepeat.initialDelay)
        }
        held[control] = Held(action: action, repeatState: repeatState)
        return [.press(action)]
    }

    /// Lets go of one control: its repeat bookkeeping, its pending command and the action it held.
    ///
    /// A run still in progress stops here, because its remaining steps belong to a press that ended.
    mutating func release(_ control: XInputControl) -> [PerformanceEffect] {
        pendingCommands.removeValue(forKey: control)
        // One removal drops the action and its repeat clock together.
        guard let entry = held.removeValue(forKey: control) else { return [] }
        return [.release(entry.action)]
    }

    /// Everything one slice of time produces, in the order the engine emits it: cursor, one step of
    /// each command in progress, scrolling, and key repeats.
    mutating func advance(
        seconds: Double,
        leftStick: XInputStick,
        rightStick: XInputStick,
        precisionActive: Bool = false
    ) -> [PerformanceEffect] {
        guard seconds > 0 else { return [] }
        var effects: [PerformanceEffect] = []
        let settings = profile.cursor
        // One factor for both axes and for the wheel: slowing the pointer but not the scroll would
        // make the two disagree while the same control is held.
        let factor = precisionActive ? profile.precision.factor : 1
        let velocity = StickMotion.cursorVelocity(stick: leftStick, settings: settings)
        if !velocity.isZero {
            effects.append(
                .moveCursor(deltaX: velocity.dx * seconds * factor, deltaY: velocity.dy * seconds * factor)
            )
        }
        effects.append(contentsOf: advanceCommands())
        let rate = StickMotion.scrollLinesPerSecond(stick: rightStick, settings: settings)
        let pixels = scroll.consume(
            pixelsPerSecond: rate * Scroll.pixelsPerLine * factor,
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
    mutating func reset() -> [PerformanceEffect] {
        scroll.reset()
        let effects = held.values.map { PerformanceEffect.release($0.action) }
        held.removeAll()
        // A command stops with the emulation: its remaining steps would fire into whatever is in front
        // of the user after they asked it to stop.
        pendingCommands.removeAll()
        return effects
    }

    // MARK: - Time

    /// One step of every command in progress, one per advance.
    ///
    /// The map gives no cross-command order, and none is needed: each step is a complete stroke of its
    /// own command, so two runs advancing in the same slice do not interact.
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
        guard held.contains(where: { $0.value.repeatState != nil }) else { return [] }
        let interval = max(profile.keyRepeat.interval, 0.005)
        var effects: [PerformanceEffect] = []
        // A copy, because every clock is written back into the same map.
        for (control, var entry) in Array(held) {
            guard case .key = entry.action, var state = entry.repeatState else { continue }
            state.elapsed += seconds
            if state.elapsed >= state.due {
                effects.append(.repeatKey(entry.action))
                state.due = state.elapsed + interval
            }
            entry.repeatState = state
            held[control] = entry
        }
        return effects
    }

    /// One step of a command: a complete stroke, so a step can never leave a key or a modifier down.
    private static func stepEffects(_ step: KeyCombo) -> [PerformanceEffect] {
        [.press(.key(step)), .release(.key(step))]
    }
}
