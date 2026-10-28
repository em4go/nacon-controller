import ApplicationServices
import CoreGraphics
import Foundation

/// Receives the effects the emulation engine decides to produce.
///
/// The protocol exists so the engine can be tested without touching the system.
public protocol InputEmitter: AnyObject {
    func press(_ action: MappedAction)
    func release(_ action: MappedAction)
    /// Auto-repeat of a key that is being held down.
    func repeatKey(_ action: MappedAction)
    func moveCursor(deltaX: Double, deltaY: Double)
    func scroll(pixels: Int)
}

public extension InputEmitter {
    /// Auto-repeat of a held key. Repeating the whole action is what a recorder or a test wants; the
    /// real emitter posts the key alone, because a keyboard does not press the modifiers again on
    /// every repeat and doing so would stack presses no release ever balances.
    func repeatKey(_ action: MappedAction) {
        press(action)
    }
}

/// Whether this process may synthesize input events.
public enum AccessibilityPermission {
    public static var isGranted: Bool {
        AXIsProcessTrusted()
    }

    /// Asks the system to show the Accessibility prompt. Returns the current trust state.
    @discardableResult
    public static func requestPrompt() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }
}

/// Posts keyboard and mouse events to the system through CoreGraphics.
public final class CGEventEmitter: InputEmitter {
    private let source = CGEventSource(stateID: .hidSystemState)
    /// The modifiers this emitter is holding down right now, from the strokes it posted.
    private var heldByUs: ModifierSet = []

    public init() {}

    public func press(_ action: MappedAction) {
        switch action {
        case .none, .scrollLines:
            return
        case .key(let combo):
            postKey(combo, isDown: true)
        case .mouseButton(let button):
            postMouse(button, isDown: true)
        }
    }

    public func release(_ action: MappedAction) {
        switch action {
        case .none, .scrollLines:
            return
        case .key(let combo):
            postKey(combo, isDown: false)
        case .mouseButton(let button):
            postMouse(button, isDown: false)
        }
    }

    public func repeatKey(_ action: MappedAction) {
        guard case .key(let combo) = action, let stroke = KeyStrokePlan.repeatStroke(for: combo)
        else { return }
        post(stroke)
    }

    public func moveCursor(deltaX: Double, deltaY: Double) {
        guard deltaX != 0 || deltaY != 0 else { return }
        let displays = ScreenGeometry.activeDisplayBounds()
        let current = ScreenGeometry.clamped(Self.cursorLocation(), to: displays)
        let requested = CGPoint(x: current.x + deltaX, y: current.y + deltaY)
        let target = ScreenGeometry.clamped(requested, to: displays)
        guard let event = CGEvent(
            mouseEventSource: source,
            mouseType: .mouseMoved,
            mouseCursorPosition: target,
            mouseButton: .left
        ) else { return }
        event.flags = []
        event.post(tap: .cghidEventTap)
    }

    public func scroll(pixels: Int) {
        guard pixels != 0 else { return }
        // Pixels, not lines: a line event carries a whole line and cannot express the fraction the
        // stick is asking for, which is what made slow scrolling move in visible steps.
        guard let event = CGEvent(
            scrollWheelEvent2Source: source,
            units: .pixel,
            wheelCount: 1,
            wheel1: Int32(pixels),
            wheel2: 0,
            wheel3: 0
        ) else { return }
        event.flags = []
        event.post(tap: .cghidEventTap)
    }

    private func postKey(_ combo: KeyCombo, isDown: Bool) {
        for stroke in KeyStrokePlan.strokes(for: combo, isDown: isDown) {
            post(stroke)
        }
    }

    private func post(_ stroke: KeyStroke) {
        guard let event = CGEvent(
            keyboardEventSource: source,
            virtualKey: CGKeyCode(stroke.keyCode),
            keyDown: stroke.isDown
        ) else { return }
        event.flags = Self.strokeFlags(
            for: stroke,
            ambient: Self.heldModifiers(),
            held: heldByUs
        )
        // Remember what this app itself is holding. The system's own report arrives a moment later,
        // and the next stroke must not depend on that race: ⌘ held on one control and ⇥ pressed on
        // another have to combine even if the report has not caught up yet.
        if let own = KeyStrokePlan.modifierSet(for: stroke.keyCode) {
            if stroke.isDown {
                heldByUs.insert(own)
            } else {
                heldByUs.remove(own)
            }
        }
        event.post(tap: .cghidEventTap)
    }

    private func postMouse(_ button: MouseButton, isDown: Bool) {
        let type: CGEventType
        let cgButton: CGMouseButton
        switch button {
        case .left:
            type = isDown ? .leftMouseDown : .leftMouseUp
            cgButton = .left
        case .right:
            type = isDown ? .rightMouseDown : .rightMouseUp
            cgButton = .right
        case .middle:
            type = isDown ? .otherMouseDown : .otherMouseUp
            cgButton = .center
        }
        guard let event = CGEvent(
            mouseEventSource: source,
            mouseType: type,
            mouseCursorPosition: Self.cursorLocation(),
            mouseButton: cgButton
        ) else { return }
        event.flags = []
        event.post(tap: .cghidEventTap)
    }

    private static func cursorLocation() -> CGPoint {
        CGEvent(source: nil)?.location ?? .zero
    }

    /// The flags one stroke must carry: its own modifiers plus the ones already held.
    ///
    /// A mapping of a plain ⇥ has to arrive as ⌘⇥ when ⌘ is held on another control of the pad, and as
    /// ⇧⇥ when the keyboard holds shift. Each event carries its own flags and the receiving side reads
    /// those, not the state behind them: an event that claims "no modifiers" is a plain Tab, which is
    /// why combining a modifier hold with a key did nothing at all.
    ///
    /// Still assigned, never inherited: the flags come from the modifiers this app knows about, so an
    /// inherited NumericPad or CapsLock flag can never reach the event — those made many applications
    /// drop it, which looked like the controller disconnecting after a few arrow presses.
    static func strokeFlags(for stroke: KeyStroke, ambient: ModifierSet, held: ModifierSet = []) -> CGEventFlags {
        flags(for: resolvedModifiers(for: stroke, ambient: ambient, held: held))
    }

    /// The modifiers one stroke says are held, which is the state *after* it: its own, the ones the
    /// system reports, and the ones this app is holding.
    ///
    /// A modifier's own release drops it. Without that, the Command key-up still claims Command is
    /// down — the system does report it as held at that instant — and a listener that reads the flags
    /// of a flagsChanged event never sees the release: the application switcher stays on screen after
    /// the button that opened it has been let go.
    static func resolvedModifiers(
        for stroke: KeyStroke,
        ambient: ModifierSet,
        held: ModifierSet
    ) -> ModifierSet {
        var resolved = stroke.modifiers.union(ambient).union(held)
        if !stroke.isDown, let released = KeyStrokePlan.modifierSet(for: stroke.keyCode) {
            resolved.remove(released)
        }
        return resolved
    }

    /// The modifiers the system currently has down, as far as this app is concerned.
    static func heldModifiers() -> ModifierSet {
        modifiers(from: CGEventSource.flagsState(.hidSystemState))
    }

    /// Reads the modifier flags a `CGEvent` can carry into the model's own set.
    static func modifiers(from flags: CGEventFlags) -> ModifierSet {
        var modifiers: ModifierSet = []
        if flags.contains(.maskCommand) { modifiers.insert(.command) }
        if flags.contains(.maskAlternate) { modifiers.insert(.option) }
        if flags.contains(.maskControl) { modifiers.insert(.control) }
        if flags.contains(.maskShift) { modifiers.insert(.shift) }
        if flags.contains(.maskSecondaryFn) { modifiers.insert(.function) }
        return modifiers
    }

    static func flags(for modifiers: ModifierSet) -> CGEventFlags {
        var flags: CGEventFlags = []
        if modifiers.contains(.command) { flags.insert(.maskCommand) }
        if modifiers.contains(.option) { flags.insert(.maskAlternate) }
        if modifiers.contains(.control) { flags.insert(.maskControl) }
        if modifiers.contains(.shift) { flags.insert(.maskShift) }
        if modifiers.contains(.function) { flags.insert(.maskSecondaryFn) }
        return flags
    }
}
