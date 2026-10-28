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
    func scroll(lines: Int)
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
        guard case .key(let combo) = action else { return }
        post(KeyStrokePlan.repeatStroke(for: combo))
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

    public func scroll(lines: Int) {
        guard lines != 0 else { return }
        guard let event = CGEvent(
            scrollWheelEvent2Source: source,
            units: .line,
            wheelCount: 1,
            wheel1: Int32(lines),
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
        // Assign, never OR: an inherited NumericPad flag makes many applications drop the event,
        // which looks like the controller disconnecting after a few arrow presses.
        event.flags = Self.flags(for: stroke.modifiers)
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

    private static func flags(for modifiers: ModifierSet) -> CGEventFlags {
        var flags: CGEventFlags = []
        if modifiers.contains(.command) { flags.insert(.maskCommand) }
        if modifiers.contains(.option) { flags.insert(.maskAlternate) }
        if modifiers.contains(.control) { flags.insert(.maskControl) }
        if modifiers.contains(.shift) { flags.insert(.maskShift) }
        return flags
    }
}
