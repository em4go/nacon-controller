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
    /// Releases every modifier this emitter is holding. A safety net for emulation stopping: a
    /// modifier left in its own count would be added to every later event, which looks exactly like a
    /// key stuck down.
    func releaseHeldModifiers()
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

    func releaseHeldModifiers() {}
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
    /// The mouse buttons this emitter has pressed and not released yet.
    private var pressedButtons: Set<MouseButton> = []

    public init() {}

    public func press(_ action: MappedAction) {
        switch action {
        case .none, .scrollLines, .sequence:
            // A sequence never reaches the emitter: the performance expands it into steps, and each step is
            // an ordinary key with its own press and release.
            return
        case .key(let combo):
            postKey(combo, isDown: true)
        case .mouseButton(let button):
            postMouse(button, isDown: true)
        }
    }

    public func release(_ action: MappedAction) {
        switch action {
        case .none, .scrollLines, .sequence:
            return
        case .key(let combo):
            postKey(combo, isDown: false)
        case .mouseButton(let button):
            postMouse(button, isDown: false)
        }
    }

    public func releaseHeldModifiers() {
        guard !heldByUs.isEmpty else { return }
        for pair in KeyStrokePlan.modifiers where heldByUs.contains(pair.set) {
            post(KeyStroke(keyCode: pair.keyCode, isDown: false, modifiers: []))
        }
        heldByUs = []
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
            mouseType: Self.movementType(pressed: pressedButtons),
            mouseCursorPosition: target,
            mouseButton: Self.cgButton(for: pressedButtons)
        ) else { return }
        event.flags = Self.mouseFlags(held: heldByUs)
        event.post(tap: .cghidEventTap)
    }

    /// The flags a mouse event carries: the modifiers this app is holding, for the same reason the
    /// key strokes carry them. A ⌘-click is a click whose event says ⌘.
    static func mouseFlags(held: ModifierSet) -> CGEventFlags {
        flags(for: held)
    }

    /// The type of a movement event: a drag while a button is held, a plain move otherwise.
    ///
    /// A real mouse reports a drag, not a move, when it travels with a button down. Views that compute
    /// a selection inside their own mouse-down loop only react to dragged events, so posting `.mouseMoved`
    /// made the movement invisible to them: the screenshot area tool opened and the selection stayed
    /// empty because it never learned the pointer had travelled.
    static func movementType(pressed buttons: Set<MouseButton>) -> CGEventType {
        if buttons.contains(.left) { return .leftMouseDragged }
        if buttons.contains(.right) { return .rightMouseDragged }
        if buttons.contains(.middle) { return .otherMouseDragged }
        return .mouseMoved
    }

    /// The button a movement event names. It has to match the pressed button, or the drag is
    /// delivered as belonging to another one.
    static func cgButton(for pressed: Set<MouseButton>) -> CGMouseButton {
        if pressed.contains(.left) { return .left }
        if pressed.contains(.right) { return .right }
        if pressed.contains(.middle) { return .center }
        return .left
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
        event.flags = Self.strokeFlags(for: stroke, held: heldByUs)
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
        // The click carries the modifiers this app is holding, like any other stroke: a view that
        // reacts to ⌘-click reads the flags of the event, and a click that claims none is a plain
        // click no matter what is held on the pad.
        event.flags = Self.mouseFlags(held: heldByUs)
        // A real click says how many clicks it is, and a zero means "not a click": views that ask for
        // a click rather than a press ignored every press of this app until this was set. Confirmed on
        // hardware with a link in a formatted text and with a control that had never responded.
        // Every click declares itself the first, so a double-click gesture is still not expressible.
        event.setIntegerValueField(.mouseEventClickState, value: 1)
        event.post(tap: .cghidEventTap)
        // Tracked so that movement while this button is down is published as a drag.
        if isDown {
            pressedButtons.insert(button)
        } else {
            pressedButtons.remove(button)
        }
    }

    private static func cursorLocation() -> CGPoint {
        CGEvent(source: nil)?.location ?? .zero
    }

    /// The flags one stroke carries: its own modifiers plus the ones this app is holding.
    ///
    /// Deliberately not the system's reported state. That report lags: right after posting the release
    /// of ⇧ it still says ⇧ is down, so the next event — the release of ⌃ that follows it — carried ⇧
    /// again, and from then on every event claimed Shift was held. Applications read the flags of the
    /// event, so Shift behaved as if it were stuck. The pad is its own keyboard: it combines exactly
    /// the modifiers it is holding itself.
    ///
    /// Still assigned, never inherited: the flags are built from the model's own set, so an inherited
    /// NumericPad or CapsLock flag can never reach the event — those made applications drop it, which
    /// looked like the controller disconnecting after a few arrow presses.
    static func strokeFlags(for stroke: KeyStroke, held: ModifierSet) -> CGEventFlags {
        var resolved = stroke.modifiers.union(held)
        // A modifier's own release drops it, so the event describes the state after itself.
        if !stroke.isDown, let released = KeyStrokePlan.modifierSet(for: stroke.keyCode) {
            resolved.remove(released)
        }
        return flags(for: resolved)
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
