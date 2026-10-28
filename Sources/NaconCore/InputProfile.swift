import Foundation

/// Modifier keys applied to a synthesized keystroke.
public struct ModifierSet: OptionSet, Hashable, Sendable {
    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    public static let command = ModifierSet(rawValue: 1 << 0)
    public static let option = ModifierSet(rawValue: 1 << 1)
    public static let control = ModifierSet(rawValue: 1 << 2)
    public static let shift = ModifierSet(rawValue: 1 << 3)
    /// The `fn` key. It is a modifier for the system — arrows and function keys carry it on a laptop —
    /// and it is also a key of its own, which is why a control can hold it.
    public static let function = ModifierSet(rawValue: 1 << 4)
}

/// A virtual key plus the modifiers held with it. Key codes are `CGKeyCode` values.
public struct KeyCombo: Hashable, Sendable {
    public let keyCode: UInt16
    public let modifiers: ModifierSet

    public init(_ key: VirtualKey, modifiers: ModifierSet = []) {
        self.keyCode = key.rawValue
        self.modifiers = modifiers
    }

    public init(keyCode: UInt16, modifiers: ModifierSet = []) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
}

/// The virtual keys this first profile needs.
public enum VirtualKey: UInt16, CaseIterable, Sendable {
    case returnKey = 36
    case tab = 48
    case space = 49
    case deleteKey = 51
    case escape = 53
    case leftArrow = 123
    case rightArrow = 124
    case downArrow = 125
    case upArrow = 126
}

public enum MouseButton: String, Hashable, Sendable {
    case left
    case right
    case middle
}

/// What a physical control does when pressed.
public enum MappedAction: Hashable, Sendable {
    case none
    case key(KeyCombo)
    case mouseButton(MouseButton)
    case scrollLines(Int)
    /// Several strokes in order: a custom command, such as ⌘A and then ⌘C. The engine runs one step
    /// per tick and a press runs the whole list once.
    case sequence([KeyCombo])

    /// A sequence only exists when there is something to chain: one stroke is a key and none is
    /// nothing. The editor and the decoder both come through here, so a degenerate sequence cannot
    /// reach a profile.
    public static func chained(_ steps: [KeyCombo]) -> MappedAction {
        switch steps.count {
        case 0: return .none
        case 1: return .key(steps[0])
        default: return .sequence(steps)
        }
    }
}

/// Parameters of the stick-to-cursor curve.
public struct CursorSettings: Equatable, Sendable {
    /// Radial dead zone: below this deflection the cursor does not move at all.
    public var deadzone: Double
    /// Deflection at which the cursor reaches its maximum speed.
    public var fullSpeedFraction: Double
    /// Cursor speed in points per second at full deflection.
    public var maxSpeed: Double
    /// Shape of the response curve. 1 is linear, higher values give finer control near the centre.
    public var curveExponent: Double
    /// Scroll lines per second at full deflection of the right stick.
    public var scrollLinesPerSecond: Double
    /// Flips the vertical direction of cursor movement and scrolling. Some units report the Y axis
    /// with the opposite sign for the same physical movement.
    public var invertVerticalAxis: Bool

    public init(
        deadzone: Double = 0.18,
        fullSpeedFraction: Double = 0.85,
        maxSpeed: Double = 1_400,
        curveExponent: Double = 2.0,
        scrollLinesPerSecond: Double = 14,
        invertVerticalAxis: Bool = false
    ) {
        self.deadzone = deadzone
        self.fullSpeedFraction = fullSpeedFraction
        self.maxSpeed = maxSpeed
        self.curveExponent = curveExponent
        self.scrollLinesPerSecond = scrollLinesPerSecond
        self.invertVerticalAxis = invertVerticalAxis
    }

    public static let standard = CursorSettings()
}

/// How a held key behaves, mirroring the system keyboard repeat.
public struct KeyRepeatSettings: Equatable, Sendable {
    public var initialDelay: Double
    public var interval: Double

    public init(initialDelay: Double = 0.35, interval: Double = 0.05) {
        self.initialDelay = initialDelay
        self.interval = interval
    }

    public static let standard = KeyRepeatSettings()
}

/// The full mapping used by the emulation engine.
public struct InputProfile: Equatable, Sendable {
    public var mappings: [XInputControl: MappedAction]
    /// The MOD layer: a second reading of the same controls, applied only while its key is held.
    public var layer: ProfileLayer
    public var cursor: CursorSettings
    public var keyRepeat: KeyRepeatSettings

    public init(
        mappings: [XInputControl: MappedAction],
        layer: ProfileLayer = .empty,
        cursor: CursorSettings = .standard,
        keyRepeat: KeyRepeatSettings = .standard
    ) {
        self.mappings = mappings
        self.layer = layer
        self.cursor = cursor
        self.keyRepeat = keyRepeat
    }

    /// Left stick moves the cursor, right stick scrolls, face buttons click, d-pad sends arrows.
    public static let standard = InputProfile(mappings: [
        .buttonA: .mouseButton(.left),
        .buttonB: .mouseButton(.right),
        .buttonX: .mouseButton(.middle),
        .buttonY: .key(KeyCombo(.escape)),
        .dpadUp: .key(KeyCombo(.upArrow)),
        .dpadDown: .key(KeyCombo(.downArrow)),
        .dpadLeft: .key(KeyCombo(.leftArrow)),
        .dpadRight: .key(KeyCombo(.rightArrow)),
        .leftBumper: .key(KeyCombo(.tab)),
        .rightBumper: .key(KeyCombo(.returnKey)),
        .back: .key(KeyCombo(.deleteKey)),
        .start: .key(KeyCombo(.space)),
        .leftThumb: .none,
        .rightThumb: .none,
        .guide: .none,
        .leftTrigger: .none,
        .rightTrigger: .none,
    ])

    public func action(for control: XInputControl) -> MappedAction {
        mappings[control] ?? .none
    }

    /// The action a control produces right now, with the MOD layer open or closed.
    ///
    /// The layer only replaces what it redefines; every other control keeps its base action, which is
    /// what lets the user add one exception without rebuilding the whole map.
    public func action(for control: XInputControl, layerActive: Bool) -> MappedAction {
        if layerActive, let layered = layer.action(for: control) {
            return layered
        }
        return action(for: control)
    }

    /// Controls that produce a discrete press/release action, in a stable order.
    public var discreteControls: [XInputControl] {
        XInputControl.allCases.filter { action(for: $0) != .none }
    }
}
