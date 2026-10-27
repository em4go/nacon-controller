import Foundation

// JSON representation of a profile.
//
// The format is meant to survive version drift: every field of `InputProfile` is optional when
// decoding and falls back to the standard value, `MappedAction` carries an explicit string
// discriminator instead of relying on enum order, and mappings are keyed by a stable control
// name rather than by an enum ordinal. A file written by an older or newer build therefore
// degrades instead of failing.

extension JSONEncoder {
    /// Canonical encoder for profile data.
    ///
    /// Sorted keys make the file byte-stable across runs, so two machines with the same library
    /// write the same bytes.
    static var profileEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

extension ModifierSet: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(rawValue: try container.decode(UInt8.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

extension KeyCombo: Codable {
    private enum CodingKeys: String, CodingKey {
        case keyCode
        case modifiers
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            keyCode: try container.decodeIfPresent(UInt16.self, forKey: .keyCode) ?? 0,
            modifiers: try container.decodeIfPresent(ModifierSet.self, forKey: .modifiers) ?? []
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(keyCode, forKey: .keyCode)
        try container.encode(modifiers, forKey: .modifiers)
    }
}

extension MappedAction: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
        case key
        case button
        case lines
    }

    private enum Kind: String {
        case noAction = "none"
        case key
        case mouseButton
        case scrollLines
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard let rawKind = try container.decodeIfPresent(String.self, forKey: .kind),
              let kind = Kind(rawValue: rawKind)
        else {
            // Unknown action from another version: keep the profile usable rather than failing.
            self = .none
            return
        }

        switch kind {
        case .noAction:
            self = .none
        case .key:
            self = .key(try container.decode(KeyCombo.self, forKey: .key))
        case .mouseButton:
            let rawButton = try container.decode(String.self, forKey: .button)
            guard let button = MouseButton(rawValue: rawButton) else {
                self = .none
                return
            }
            self = .mouseButton(button)
        case .scrollLines:
            self = .scrollLines(try container.decode(Int.self, forKey: .lines))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .none:
            try container.encode(Kind.noAction.rawValue, forKey: .kind)
        case .key(let combo):
            try container.encode(Kind.key.rawValue, forKey: .kind)
            try container.encode(combo, forKey: .key)
        case .mouseButton(let button):
            try container.encode(Kind.mouseButton.rawValue, forKey: .kind)
            try container.encode(button.rawValue, forKey: .button)
        case .scrollLines(let lines):
            try container.encode(Kind.scrollLines.rawValue, forKey: .kind)
            try container.encode(lines, forKey: .lines)
        }
    }
}

extension CursorSettings: Codable {
    private enum CodingKeys: String, CodingKey {
        case deadzone
        case fullSpeedFraction
        case maxSpeed
        case curveExponent
        case scrollLinesPerSecond
        case invertVerticalAxis
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let standard = CursorSettings.standard
        self.init(
            deadzone: try container.decodeIfPresent(Double.self, forKey: .deadzone) ?? standard.deadzone,
            fullSpeedFraction: try container.decodeIfPresent(Double.self, forKey: .fullSpeedFraction)
                ?? standard.fullSpeedFraction,
            maxSpeed: try container.decodeIfPresent(Double.self, forKey: .maxSpeed) ?? standard.maxSpeed,
            curveExponent: try container.decodeIfPresent(Double.self, forKey: .curveExponent)
                ?? standard.curveExponent,
            scrollLinesPerSecond: try container.decodeIfPresent(Double.self, forKey: .scrollLinesPerSecond)
                ?? standard.scrollLinesPerSecond,
            invertVerticalAxis: try container.decodeIfPresent(Bool.self, forKey: .invertVerticalAxis)
                ?? standard.invertVerticalAxis
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(deadzone, forKey: .deadzone)
        try container.encode(fullSpeedFraction, forKey: .fullSpeedFraction)
        try container.encode(maxSpeed, forKey: .maxSpeed)
        try container.encode(curveExponent, forKey: .curveExponent)
        try container.encode(scrollLinesPerSecond, forKey: .scrollLinesPerSecond)
        try container.encode(invertVerticalAxis, forKey: .invertVerticalAxis)
    }
}

extension KeyRepeatSettings: Codable {
    private enum CodingKeys: String, CodingKey {
        case initialDelay
        case interval
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let standard = KeyRepeatSettings.standard
        self.init(
            initialDelay: try container.decodeIfPresent(Double.self, forKey: .initialDelay) ?? standard.initialDelay,
            interval: try container.decodeIfPresent(Double.self, forKey: .interval) ?? standard.interval
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(initialDelay, forKey: .initialDelay)
        try container.encode(interval, forKey: .interval)
    }
}

extension InputProfile: Codable {
    private enum CodingKeys: String, CodingKey {
        case mappings
        case cursor
        case keyRepeat
    }

    /// Key for one control inside the `mappings` JSON object.
    private struct ControlKey: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }

        init(_ stringValue: String) {
            self.stringValue = stringValue
        }

        init?(stringValue: String) {
            self.init(stringValue)
        }

        init?(intValue: Int) {
            return nil
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let cursor = try container.decodeIfPresent(CursorSettings.self, forKey: .cursor) ?? .standard
        let keyRepeat = try container.decodeIfPresent(KeyRepeatSettings.self, forKey: .keyRepeat) ?? .standard

        guard let storedMappings = try container.decodeIfPresent(
            [String: MappedAction].self,
            forKey: .mappings
        ) else {
            // An older file without mappings still opens with the standard assignment.
            self.init(mappings: InputProfile.standard.mappings, cursor: cursor, keyRepeat: keyRepeat)
            return
        }

        var mappings: [XInputControl: MappedAction] = [:]
        for (name, action) in storedMappings {
            // Unknown control names come from another version; drop them, keep the rest.
            guard let control = XInputControl(profileKey: name) else { continue }
            mappings[control] = action
        }
        self.init(mappings: mappings, cursor: cursor, keyRepeat: keyRepeat)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        var mappingsContainer = container.nestedContainer(keyedBy: ControlKey.self, forKey: .mappings)
        // Iterating the cases instead of the dictionary keeps the output byte-stable.
        for control in XInputControl.allCases {
            guard let action = mappings[control] else { continue }
            try mappingsContainer.encode(action, forKey: ControlKey(control.profileKey))
        }
        try container.encode(cursor, forKey: .cursor)
        try container.encode(keyRepeat, forKey: .keyRepeat)
    }
}

extension XInputControl {
    /// Stable, language-independent identifier used as the key of the persisted mapping.
    var profileKey: String {
        switch self {
        case .dpadUp: return "dpadUp"
        case .dpadDown: return "dpadDown"
        case .dpadLeft: return "dpadLeft"
        case .dpadRight: return "dpadRight"
        case .buttonA: return "buttonA"
        case .buttonB: return "buttonB"
        case .buttonX: return "buttonX"
        case .buttonY: return "buttonY"
        case .leftBumper: return "leftBumper"
        case .rightBumper: return "rightBumper"
        case .leftTrigger: return "leftTrigger"
        case .rightTrigger: return "rightTrigger"
        case .back: return "back"
        case .start: return "start"
        case .guide: return "guide"
        case .leftThumb: return "leftThumb"
        case .rightThumb: return "rightThumb"
        }
    }

    private static let controlsByProfileKey: [String: XInputControl] = Dictionary(
        uniqueKeysWithValues: allCases.map { ($0.profileKey, $0) }
    )

    init?(profileKey: String) {
        guard let control = XInputControl.controlsByProfileKey[profileKey] else { return nil }
        self = control
    }
}
