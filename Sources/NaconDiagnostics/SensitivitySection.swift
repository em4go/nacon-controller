import NaconCore
import SwiftUI

/// S9: the cursor numbers of the profile being edited, in the app window.
///
/// The section renders what `ProfileLibrary` reports and forwards intents; the ranges, the clamping
/// and the isolation between profiles live there and are covered by tests. Nothing here decides a
/// value, which is why a slider can be dragged over its range without any risk of leaving it.
struct SensitivitySection: View {
    @ObservedObject var profiles: ProfileLibraryController
    /// The numbers only reach the engine when emulation starts, so editing mid-run would silently do
    /// nothing. The controls are locked for the same reason the mapping editor is (defect F3).
    @EnvironmentObject private var emulation: EmulationController

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(AppText.resolve("Cursor sensitivity"))
            Text(
                AppText.format(
                    "Settings for the “%@” profile. Each profile keeps its own, so one for design and one for games can move differently.",
                    profiles.selectedProfile?.name ?? "—"
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            ForEach(CursorSensitivity.allCases, id: \.self) { sensitivity in
                slider(for: sensitivity)
            }

            precisionRow

            Button(AppText.resolve("Reset")) {
                profiles.resetCursorSensitivity()
            }
            .disabled(emulation.isEnabled || profiles.selectedProfile == nil)

            Text(
                AppText.resolve(
                    "Applied when emulation starts: stop it to change the setting."
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    /// The slow-speed control: which one, and how slow.
    ///
    /// It is a control and not a key combination because the pad already has enough ways to send keys;
    /// what the cursor needs is one button held down, like the MOD key chooses a mapping.
    private var precisionRow: some View {
        let precision = profiles.selectedPrecision
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                Text(AppText.resolve("Precision key"))
                Menu(precision.key.map { Localization.resolve(ControlFacts.of($0).label) } ?? AppText.resolve("None")) {
                    Button(AppText.resolve("None")) {
                        profiles.setPrecisionKey(nil as XInputControl?)
                    }
                    Divider()
                    ForEach(MappingRules.remappableControls, id: \.self) { control in
                        Button(Localization.resolve(ControlFacts.of(control).label)) {
                            profiles.setPrecisionKey(control)
                        }
                    }
                }
                .menuStyle(.borderlessButton)
                .controlSize(.small)
                .fixedSize()
                .disabled(emulation.isEnabled || profiles.selectedProfile == nil)
                Spacer()
                Text("\(Int((precision.scale * 100).rounded())) %")
                    .monospacedDigit()
                    .foregroundStyle(precision.isActive ? Color.primary : Color.secondary)
            }
            Slider(
                value: Binding<Double>(
                    get: { precision.scale },
                    set: { profiles.setPrecisionScale($0) }
                ),
                in: PrecisionSettings.minimumScale...PrecisionSettings.maximumScale
            )
            .disabled(emulation.isEnabled || !precision.isActive)
            Text(
                AppText.resolve(
                    "While you hold it, the cursor and the scroll move slower. The speed above is the normal one."
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func slider(for sensitivity: CursorSensitivity) -> some View {
        let current = profiles.selectedValue(for: sensitivity) ?? sensitivity.range.lowerBound
        return VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(sensitivity.label)
                Spacer()
                Text(sensitivity.formatted(current))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(
                value: Binding(
                    get: { current },
                    set: { profiles.setCursorSensitivity(sensitivity, to: $0) }
                ),
                in: sensitivity.range
            )
            .disabled(emulation.isEnabled)
            Text(sensitivity.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
