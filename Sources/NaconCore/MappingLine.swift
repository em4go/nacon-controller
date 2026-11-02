import Foundation

/// What one control sends, derived once for every surface that prints it.
///
/// Three surfaces answer «what does this control send»: the strip under the drawing, the summary panel
/// and the help of a drawing hotspot. Each derived it on its own, and they drifted the way duplicated
/// derivations do — one sentence was spelled with two different catalog keys, and the MOD rule had to
/// be remembered in three places to stay the same. The derivation is here so a surface can only ask,
/// never spell it its own way; the row layouts stay where they are, because a table with buttons, a
/// single line and a grid are three different readings of the same fact, not one thing written three
/// times.
public enum MappingLine {
    /// The sentence the reserved Control gets instead of an assignment, in the interface language.
    ///
    /// It is resolved text, not a resource: a view that is handed a `LocalizedStringResource` resolves
    /// it against the system language and would ignore the language the user picked.
    public static var reserved: String {
        Localization.resolve("Reserved: turns emulation on and off")
    }

    /// The base reading: the reserved sentence, or what the Perfil sends for this Control.
    ///
    /// The reserved Control is answered before the profile is asked at all. It is never stored in a
    /// profile, so asking would print «Unassigned» on the one control that always does something.
    public static func base(for control: XInputControl, in profile: InputProfile) -> String {
        guard MappingRules.isRemappable(control) else { return reserved }
        return profile.action(for: control).displayName
    }

    /// The MOD reading, or `nil` when the Capa MOD is not open or has no entry for this Control.
    ///
    /// The nil is the answer, not a missing value: a control the layer does not redefine keeps its base
    /// action while MOD is held, so there is nothing to add to the line — and a surface that prints it
    /// has to print the base instead of inventing a second reading.
    public static func mod(for control: XInputControl, in profile: InputProfile) -> String? {
        guard MappingRules.isRemappable(control) else { return nil }
        guard profile.layer.isActive, let layered = profile.layer.action(for: control) else {
            return nil
        }
        return layered.displayName
    }

    /// One line for a surface that reads a Control at a glance: the base, and the layer's reading only
    /// when the layer really redefines it.
    ///
    /// A layer with a key always shows its column in the table and the summary, but this line is read
    /// once, next to the drawing. Appending a MOD part for a control the layer leaves alone would say
    /// the control does something else with MOD held, which is exactly what it does not do.
    public static func line(for control: XInputControl, in profile: InputProfile) -> String {
        let base = base(for: control, in: profile)
        guard let mod = mod(for: control, in: profile) else { return base }
        return Localization.format("%@ · MOD %@", base, mod)
    }
}
