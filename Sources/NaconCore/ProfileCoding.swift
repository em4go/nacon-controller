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
        case steps
    }

    private enum Kind: String {
        case noAction = "none"
        case key
        case mouseButton
        case scrollLines
        case sequence
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
        case .sequence:
            // Unreadable steps leave the action empty instead of failing the whole profile: one bad
            // entry must not cost the user every other assignment in the file.
            let steps = (try? container.decodeIfPresent([KeyCombo].self, forKey: .steps)) ?? nil ?? []
            self = MappedAction.chained(steps)
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
        case .sequence(let steps):
            try container.encode(Kind.sequence.rawValue, forKey: .kind)
            try container.encode(steps, forKey: .steps)
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

extension PrecisionSettings: Codable {
    private enum CodingKeys: String, CodingKey {
        case key
        case scale
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let stored = try container.decodeIfPresent(String.self, forKey: .key)
        let control = stored.flatMap(XInputControl.init(profileKey:))
        // The eligibility rule holds in the model: a file cannot make PS the slow key.
        let key = control.flatMap { MappingRules.isPrecisionKeyEligible($0) ? $0 : nil }
        self.init(
            key: key,
            scale: try container.decodeIfPresent(Double.self, forKey: .scale) ?? Self.standardScale
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(key.map { ControlFacts.of($0).profileKey }, forKey: .key)
        try container.encode(scale, forKey: .scale)
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

/// Key for one control inside a JSON object of assignments, shared by the base map and the layer.
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

extension InputProfile: Codable {
    private enum CodingKeys: String, CodingKey {
        case mappings
        case layer
        case cursor
        case keyRepeat
        case precision
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let cursor = try container.decodeIfPresent(CursorSettings.self, forKey: .cursor) ?? .standard
        let precision = try container.decodeIfPresent(PrecisionSettings.self, forKey: .precision) ?? .off
        let keyRepeat = try container.decodeIfPresent(KeyRepeatSettings.self, forKey: .keyRepeat) ?? .standard
        let layer = try container.decodeIfPresent(ProfileLayer.self, forKey: .layer) ?? .empty

        guard let storedMappings = try container.decodeIfPresent(
            [String: MappedAction].self,
            forKey: .mappings
        ) else {
            // An older file without mappings still opens with the standard assignment.
            self.init(
                mappings: InputProfile.standard.mappings,
                layer: layer,
                cursor: cursor,
                keyRepeat: keyRepeat,
                precision: precision
            )
            return
        }

        var mappings: [XInputControl: MappedAction] = [:]
        for (name, action) in storedMappings {
            // Unknown control names come from another version; drop them, keep the rest.
            guard let control = XInputControl(profileKey: name) else { continue }
            // Guide is the emergency stop and is never remappable. A hand-edited or foreign file
            // must not be able to give it a key or a click, so the mapping is dropped here: the
            // invariant holds in the model instead of resting on the engine alone. The explicit
            // `none` entry of the standard profile survives, because it maps nothing.
            guard MappingRules.isRemappable(control) || action == .none else { continue }
            mappings[control] = action
        }
        self.init(
            mappings: mappings,
            layer: layer,
            cursor: cursor,
            keyRepeat: keyRepeat,
            precision: precision
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        var mappingsContainer = container.nestedContainer(keyedBy: ControlKey.self, forKey: .mappings)
        // Iterating the cases instead of the dictionary keeps the output byte-stable.
        for control in XInputControl.allCases {
            guard let action = mappings[control] else { continue }
            try mappingsContainer.encode(action, forKey: ControlKey(ControlFacts.of(control).profileKey))
        }
        // Only written when it says something, so a profile that never used the layer keeps the file
        // it already had, byte for byte.
        if !layer.isEmpty {
            try container.encode(layer, forKey: .layer)
        }
        try container.encode(cursor, forKey: .cursor)
        try container.encode(keyRepeat, forKey: .keyRepeat)
        // Only written when it says something, like the layer: a profile without a precision key keeps
        // the file it already had, byte for byte.
        if precision.key != nil {
            try container.encode(precision, forKey: .precision)
        }
    }
}

extension ProfileLayer: Codable {
    private enum CodingKeys: String, CodingKey {
        case key
        case mappings
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let storedMappings = try container.decodeIfPresent(
            [String: MappedAction].self,
            forKey: .mappings
        ) ?? [:]

        var mappings: [XInputControl: MappedAction] = [:]
        for (name, action) in storedMappings {
            // Same rule as the base map: unknown names come from another version and are dropped,
            // and Guide is never remappable. The invariant holds here, not only in the engine.
            guard let control = XInputControl(profileKey: name),
                  MappingRules.isRemappable(control) || action == .none
            else { continue }
            mappings[control] = action
        }

        // A key that may not select the layer is dropped instead of kept: PS is the emergency stop,
        // and a hand-edited file must not be able to turn it into a selector (S5).
        let key = try container.decodeIfPresent(String.self, forKey: .key).flatMap { name in
            XInputControl(profileKey: name).flatMap { control in
                MappingRules.isLayerKeyEligible(control) ? control : nil
            }
        }
        self.init(key: key, mappings: mappings)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(key.map { ControlFacts.of($0).profileKey }, forKey: .key)
        var mappingsContainer = container.nestedContainer(keyedBy: ControlKey.self, forKey: .mappings)
        // Iterating the cases instead of the dictionary keeps the output byte-stable.
        for control in XInputControl.allCases {
            guard let action = mappings[control] else { continue }
            try mappingsContainer.encode(action, forKey: ControlKey(ControlFacts.of(control).profileKey))
        }
    }
}
