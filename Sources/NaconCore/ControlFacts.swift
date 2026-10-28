import Foundation

/// S2: every fact the app knows about one control, built by one exhaustive switch.
///
/// The same seventeen controls were described by five parallel switches across four files: the stored
/// key for the JSON, the label the editor prints, the colour of the highlight, the size of the pointer
/// circle and the name of the drawing's mask — the last two in the same file, both naming a control.
/// Adding a control meant editing all of them, and forgetting one showed up as a blank cell or a
/// control that could not be clicked. This value answers all of it in one place, and the switch has no
/// `default`: a new case of `XInputControl` breaks the build until it is described.
///
/// There is deliberately no mask-name field. The mask files are named after the stored key by
/// `prototype/tools/make-masks.py`, so the drawing reads `profileKey` for them and a second name could
/// only be a second thing to keep in sync.
///
/// Two tables stay where they are, because they answer different questions: `XInputButtons.mask` and
/// `XInputControl.isPressed(in:)` decode the wire protocol, and `XInputControl.rawValue` is the
/// glyph the diagnostic live grid prints — not the label a dialog shows.
public struct ControlFacts: Equatable, Sendable {
    /// Stable, language-independent identifier used as the key of the persisted mapping.
    public let profileKey: String
    /// Name of the control as shown to the user. Spanish, like the rest of the user-facing copy.
    public let label: String
    /// Colour of the control while it is lit, or `nil` when it takes the system accent.
    public let tint: ControlTint?
    /// Radius of the control's hit circle, in pixels of the artwork `PadLayout` measures.
    public let hitRadius: Double

    public init(profileKey: String, label: String, tint: ControlTint?, hitRadius: Double) {
        self.profileKey = profileKey
        self.label = label
        self.tint = tint
        self.hitRadius = hitRadius
    }

    /// The facts of one control.
    public static func of(_ control: XInputControl) -> ControlFacts {
        switch control {
        case .dpadUp:
            return ControlFacts(
                profileKey: "dpadUp",
                label: "Cruceta ↑",
                tint: ControlTint(red: 0.184, green: 0.749, blue: 0.427),      // verde
                hitRadius: 42
            )
        case .dpadDown:
            return ControlFacts(
                profileKey: "dpadDown",
                label: "Cruceta ↓",
                tint: ControlTint(red: 0.604, green: 0.361, blue: 1.000),      // violeta
                hitRadius: 42
            )
        case .dpadLeft:
            return ControlFacts(
                profileKey: "dpadLeft",
                label: "Cruceta ←",
                tint: ControlTint(red: 0.145, green: 0.780, blue: 0.851),      // cian
                hitRadius: 42
            )
        case .dpadRight:
            return ControlFacts(
                profileKey: "dpadRight",
                label: "Cruceta →",
                tint: ControlTint(red: 0.961, green: 0.651, blue: 0.137),      // ámbar
                hitRadius: 42
            )
        case .buttonA:
            return ControlFacts(
                profileKey: "buttonA",
                label: "✕ Cruz",
                tint: ControlTint(red: 0.239, green: 0.435, blue: 0.878),      // azul
                hitRadius: 46
            )
        case .buttonB:
            return ControlFacts(
                profileKey: "buttonB",
                label: "○ Círculo",
                tint: ControlTint(red: 0.886, green: 0.231, blue: 0.231),      // rojo
                hitRadius: 46
            )
        case .buttonX:
            return ControlFacts(
                profileKey: "buttonX",
                label: "□ Cuadrado",
                tint: ControlTint(red: 0.878, green: 0.439, blue: 0.722),      // rosa
                hitRadius: 46
            )
        case .buttonY:
            return ControlFacts(
                profileKey: "buttonY",
                label: "△ Triángulo",
                tint: ControlTint(red: 0.043, green: 0.478, blue: 0.220),      // verde oscuro
                hitRadius: 46
            )
        case .leftBumper:
            return ControlFacts(profileKey: "leftBumper", label: "L1", tint: nil, hitRadius: 60)
        case .rightBumper:
            return ControlFacts(profileKey: "rightBumper", label: "R1", tint: nil, hitRadius: 60)
        case .leftTrigger:
            return ControlFacts(profileKey: "leftTrigger", label: "L2", tint: nil, hitRadius: 60)
        case .rightTrigger:
            return ControlFacts(profileKey: "rightTrigger", label: "R2", tint: nil, hitRadius: 60)
        case .back:
            return ControlFacts(profileKey: "back", label: "Share", tint: nil, hitRadius: 34)
        case .start:
            return ControlFacts(profileKey: "start", label: "Options", tint: nil, hitRadius: 34)
        case .guide:
            return ControlFacts(profileKey: "guide", label: "PS", tint: nil, hitRadius: 40)
        case .leftThumb:
            return ControlFacts(profileKey: "leftThumb", label: "L3", tint: nil, hitRadius: 62)
        case .rightThumb:
            return ControlFacts(profileKey: "rightThumb", label: "R3", tint: nil, hitRadius: 62)
        }
    }
}

extension XInputControl {
    /// The control a stored profile key names, or `nil` when the key came from another version.
    ///
    /// The inverse of `ControlFacts.profileKey`, resolved through the same facts so the stored names
    /// have one source. A key no control answers is dropped by the decoders instead of failing the
    /// whole file.
    init?(profileKey: String) {
        guard let match = XInputControl.allCases.first(where: {
            ControlFacts.of($0).profileKey == profileKey
        }) else { return nil }
        self = match
    }
}
