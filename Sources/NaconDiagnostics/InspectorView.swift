import NaconCore
import SwiftUI

/// S1, S4, S6: the third zone of the window — the settings of the profile on screen.
///
/// Every control here was in the content column and was moved, not rewritten: the light colour, the
/// next profile, the MOD key with its three actions, and the cursor numbers that
/// `SensitivitySection` renders. What belongs to the mapping itself — how it is read, the
/// assignment editor, the PS row and the footnotes — stayed in the content column.
///
/// The shell decides whether this column is on screen (S4), so nothing here knows about widths: a
/// column that folded itself would sooner or later disagree with the button that opens it.
struct InspectorView: View {
    @ObservedObject var profiles: ProfileLibraryController
    /// The same rule the sections had in the content column: the profile is captured when emulation
    /// starts, so the layer and the numbers are frozen while it runs. The colour is the exception,
    /// and the reason sits where the picker is.
    @EnvironmentObject private var emulation: EmulationController

    var body: some View {
        // The column scrolls on its own: at the window's minimum height the fields are taller than
        // the window, and the mapping beside it scrolls separately instead of pushing them off.
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Whose settings these are. The dot is the same mark the sidebar row and the pad's
                // light show, so the column cannot be read as another profile's.
                HStack(spacing: 8) {
                    Circle()
                        .fill(profiles.library.selectedProfile?.profile.color.tint ?? Color.clear)
                        .frame(width: 9, height: 9)
                    Text(profiles.library.selectedProfile?.name ?? AppText.resolve("Nothing selected"))
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 0)
                }
                Divider()
                colourField
                Divider()
                invertField
                Divider()
                nextProfileField
                Divider()
                modKeyField
                Divider()
                // S9 lives in its own file: the sliders, the precision factor and the reset are one
                // block, and rendering it here is what keeps a second copy out of the mapping.
                SensitivitySection(profiles: profiles)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// The colour the pad's light shows while this profile runs.
    ///
    /// It is deliberately not disabled during emulation, unlike the mapping editor and the MOD row:
    /// the colour is the profile's only visible mark, and changing it live is how the user checks
    /// that the light is telling the truth about which profile is running.
    /// S2: whether pushing the stick up moves the cursor down, stored in the profile.
    ///
    /// It belongs here and not among the app's settings: it is a value of the profile, and every
    /// profile can answer it differently. It is frozen while the emulation runs because the value only
    /// reaches the engine when a run starts.
    private var invertField: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionTitle(AppText.resolve("Invert vertical axis"))
            Toggle(AppText.resolve("Invert vertical axis"), isOn: Binding(
                get: { profiles.library.selectedInvertVerticalAxis },
                set: { value in profiles.edit { $0.setInvertVerticalAxis(value) } }
            ))
            .toggleStyle(.switch)
            .disabled(emulation.isEnabled)
            .help(
                AppText.resolve(
                    "Turn it on if pushing the stick up moves the cursor down. It affects the cursor and "
                    + "scrolling, not the on-screen stick indicator. It is saved in the active profile and "
                    + "applied when emulation starts: stop it to change the setting."
                )
            )
        }
    }

    private var colourField: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionTitle(AppText.resolve("Light colour"))
            Picker("", selection: Binding(
                get: { profiles.library.selectedColor },
                set: { value in profiles.edit { $0.setColor(value) } }
            )) {
                ForEach(ProfileColour.allCases, id: \.self) { colour in
                    Text(colour.label).tag(colour)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .disabled(profiles.library.selectedProfile == nil)
            .help(AppText.resolve("It is the colour the pad's light shows while this profile is running."))
        }
    }

    /// Where the pad goes when it asks this profile for the next one.
    ///
    /// It is frozen with the rest of the profile while emulation runs, like every other structural
    /// setting: the engine captured the profile it is running, so rewriting the chain mid-flight
    /// would describe a step the pad cannot take yet.
    private var nextProfileField: some View {
        // Every profile except this one: a profile may not point at itself, so the row it cannot
        // offer is the only one the view leaves out.
        let others = profiles.library.profiles.filter { $0.id != profiles.library.selectedProfile?.id }
        return VStack(alignment: .leading, spacing: 6) {
            SectionTitle(AppText.resolve("Next profile"))
            Picker("", selection: Binding(
                get: { profiles.library.selectedProfile?.nextProfileID },
                set: { value in profiles.edit { $0.setNextProfile(value) } }
            )) {
                Text(AppText.resolve("Library order")).tag(UUID?.none)
                ForEach(others) { stored in
                    Text(stored.name).tag(UUID?.some(stored.id))
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .disabled(profiles.library.selectedProfile == nil || emulation.isEnabled)
            .help(AppText.resolve("Where the pad goes on the next profile step. With no link it follows the list order."))
        }
    }

    /// S5: the control that opens the layer, and the one way to remove the layer entirely.
    ///
    /// The entries are not listed here: they belong to the rows of the mapping, in the MOD column,
    /// so the layer is edited where the controls are instead of in two places at once.
    private var modKeyField: some View {
        let layer = profiles.library.selectedLayer
        return VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    SectionTitle(AppText.resolve("MOD key:"))
                    Text(layer.key.map { AppText.resolve(ControlFacts.of($0).label) } ?? AppText.resolve("None"))
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(layer.isActive ? Color.primary : Color.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                modActions
            }
            // S7: the layer is frozen with the rest of the profile once emulation starts, so the
            // selector goes with the editor it belongs to instead of staying clickable.
            .disabled(emulation.isEnabled)
            if layer.isActive {
                Text(AppText.resolve("While you hold the MOD key down, the buttons send what the MOD column says; the MOD key itself sends nothing."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                // The gesture needs a layer to open. Saying it here is what stops someone pressing
                // MOD+PS on a profile without one and turning the emulation off instead.
                Text(AppText.resolve("Without a MOD key there is no layer and no MOD+PS on the pad: PS alone turns emulation on and off. Use “Show mapping” to see the map."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// The three actions of the layer, in one row when they fit and in a column when they do not.
    ///
    /// The inspector is a narrow column and the labels must not be cut: a row whose labels have
    /// shortened themselves would hide which action is which, so the fallback is tried before any
    /// truncation can happen.
    private var modActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) { modButtons }
            VStack(alignment: .leading, spacing: 6) { modButtons }
        }
    }

    @ViewBuilder
    private var modButtons: some View {
        let layer = profiles.library.selectedLayer
        Menu {
            // «Ninguna» closes the layer but keeps its entries; «Quitar capa» is the one that
            // throws them away, so a slip of this menu cannot undo a whole set of assignments.
            Button(AppText.resolve("None")) {
                profiles.edit { $0.setLayerKey(nil) }
            }
            Divider()
            // S5: PS is not in this list. It is the emergency stop, and as a selector it would
            // be spent choosing a layer instead of stopping the emulation.
            ForEach(
                XInputControl.allCases.filter { MappingRules.isLayerKeyEligible($0) },
                id: \.self
            ) { control in
                Button(ControlFacts.of(control).label) {
                    profiles.edit { $0.setLayerKey(control) }
                }
            }
        } label: {
            Label(AppText.resolve("Choose…"), systemImage: "chevron.up.chevron.down")
                .labelStyle(.titleAndIcon)
        }
        .menuStyle(.borderlessButton)
        .controlSize(.small)
        .fixedSize()
        Button(AppText.resolve("Remove layer")) {
            profiles.edit { $0.clearLayer() }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .fixedSize()
        .disabled(layer.isEmpty)
        .help(
            AppText.resolve("Removes the MOD key and all its assignments. The base does not change.")
        )
        Button(AppText.resolve("Show mapping")) {
            emulation.toggleSummary()
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .fixedSize()
        // Reading the map is allowed while emulating: it changes nothing.
        .help(AppText.resolve("Shows what each control sends. It stays open until you close it."))
    }
}
