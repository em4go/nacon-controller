import Foundation

/// S9: the sections of the mapping table.
///
/// The table drew seventeen identical rows, and a reader looking for «the D-pad» had to scan them all.
/// The grouping is a rule, not a decoration, so it lives here with the other rules and is checked
/// without a window: a control that belongs to no group would silently vanish from the editor, which
/// is the worst way to lose a mapping — nothing fails, the row is just gone.
public enum MappingGroup: String, CaseIterable, Sendable, Identifiable {
    case dpad
    case face
    case shoulders
    case sticks
    case system

    public var id: String { rawValue }

    /// The group's name, in English, as a lookup key: the window translates it like every other string.
    public var title: String {
        switch self {
        case .dpad: return "Directional pad"
        case .face: return "Face buttons"
        case .shoulders: return "Shoulders and triggers"
        case .sticks: return "Stick clicks"
        case .system: return "System buttons"
        }
    }
}

extension XInputControl {
    /// Which section of the table shows this control.
    public var group: MappingGroup {
        switch self {
        case .dpadUp, .dpadDown, .dpadLeft, .dpadRight:
            return .dpad
        case .buttonA, .buttonB, .buttonX, .buttonY:
            return .face
        case .leftBumper, .rightBumper, .leftTrigger, .rightTrigger:
            return .shoulders
        case .leftThumb, .rightThumb:
            return .sticks
        case .back, .start, .guide:
            return .system
        }
    }
}

/// One drawn section: the group and the rows it holds.
public struct ControlSection: Sendable, Identifiable, Equatable {
    public let group: MappingGroup
    public let controls: [XInputControl]

    public var id: String { group.rawValue }
}

extension MappingRules {
    /// The editor's rows, cut into the sections it draws.
    ///
    /// Built by filtering `remappableControls` instead of by listing controls again: a second list
    /// would be a second place to forget a control, and the reserved PS button keeps being excluded by
    /// the rule that already excludes it. Groups with no row are not returned, so the table never
    /// draws an empty header.
    public static var groupedRemappableControls: [ControlSection] {
        let rows = remappableControls
        return MappingGroup.allCases.compactMap { group in
            let controls = rows.filter { $0.group == group }
            return controls.isEmpty ? nil : ControlSection(group: group, controls: controls)
        }
    }
}
