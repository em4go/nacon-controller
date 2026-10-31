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
    /// A mouse button that stays down until the control is pressed again.
    ///
    /// It is the answer to the one gesture a stick cannot do comfortably: holding a button down for a
    /// long time while moving — dragging a window, selecting several paragraphs.
    case toggledMouseButton(MouseButton)
    /// Several strokes in order: a custom command, such as ⌘A and then ⌘C. The performance runs one
    /// step per advance and a press runs the whole list once.
    case sequence([KeyCombo])
    /// Slows the pointer and the wheel while the control is held, by the profile's precision scale.
    ///
    /// It is a claim on the speed and nothing else: no key, no click, no repeat, no scroll. Being an
    /// ordinary action is what gives it a MOD-layer reading for free — the same button can slow the
    /// cursor in the base and do something else with MOD held.
    case precision

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

    /// Readable label for a mapping. Never empty, so a row always shows something.
    ///
    /// Keys defer to `KeyCombo.displayName`, which already covers every key code including the ones
    /// the catalog does not know.
    /// This is a composed label, not a translatable unit: a key combination is glyphs plus the words
    /// the key catalog already translated, so the only translatable pieces here are the words of the
    /// cases themselves, and they come from the catalog. The plural travels with the count through
    /// `String.LocalizationValue`, so the catalog decides one line from several and a language can
    /// have more than two forms.
    public var displayName: String { displayName(in: nil) }

    /// The same label in a pinned language.
    public func displayName(in locale: Locale?) -> String {
        switch self {
        case .none:
            return Localization.resolve("Unassigned", locale: locale)
        case .key(let combo):
            return combo.displayName(in: locale)
        case .precision:
            return Localization.resolve("Precision (hold)", locale: locale)
        case .mouseButton(.left):
            return Localization.resolve("Left click", locale: locale)
        case .mouseButton(.right):
            return Localization.resolve("Right click", locale: locale)
        case .mouseButton(.middle):
            return Localization.resolve("Middle click", locale: locale)
        case .toggledMouseButton(.left):
            return Localization.resolve("Toggle left click", locale: locale)
        case .toggledMouseButton(.right):
            return Localization.resolve("Toggle right click", locale: locale)
        case .toggledMouseButton(.middle):
            return Localization.resolve("Toggle middle click", locale: locale)
        case .scrollLines(0):
            return Localization.resolve("No scrolling", locale: locale)
        case .sequence(let steps):
            return steps.map { $0.displayName(in: locale) }
                .joined(separator: " " + Localization.resolve("then", locale: locale) + " ")
        case .scrollLines(let lines):
            // `magnitude`, not `abs`: a hand-edited profile can carry `Int.min`, where `abs` traps.
            let amount = lines.magnitude
            var resource = lines > 0
                ? LocalizedStringResource("Scroll up \(amount) lines", bundle: .module)
                : LocalizedStringResource("Scroll down \(amount) lines", bundle: .module)
            if let locale { resource.locale = locale }
            return String(localized: resource)
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
/// How much slower the pointer and the wheel move while precision is held.
///
/// A profile whose cursor crosses the screen at full speed is hard to aim with, and lowering the speed
/// for everything makes the rest of the work tedious. This is the compromise: the normal speed stays,
/// and a control whose action is `.precision` scales it.
///
/// Which control that is does not live here: it is an ordinary assignment, in the base map or in the
/// layer, so this type is only the fraction and nothing has to be kept in step with a separate field.
public struct PrecisionSettings: Equatable, Sendable {
    /// Fraction of the normal speed while precision is held. 1 would do nothing, so the range starts lower.
    public var scale: Double

    public init(scale: Double = PrecisionSettings.standardScale) {
        self.scale = min(max(scale, Self.minimumScale), Self.maximumScale)
    }

    public static let standardScale = 0.35
    public static let minimumScale = 0.1
    public static let maximumScale = 1.0

    /// The default fraction. It only applies once a control is assigned to `.precision`.
    public static let standard = PrecisionSettings()
}

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
    public var precision: PrecisionSettings

    public init(
        mappings: [XInputControl: MappedAction],
        layer: ProfileLayer = .empty,
        cursor: CursorSettings = .standard,
        keyRepeat: KeyRepeatSettings = .standard,
        precision: PrecisionSettings = .standard
    ) {
        self.mappings = mappings
        self.layer = layer
        self.cursor = cursor
        self.keyRepeat = keyRepeat
        self.precision = precision
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
