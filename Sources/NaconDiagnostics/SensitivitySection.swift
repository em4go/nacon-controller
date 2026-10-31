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

    /// The precision factor of the profile being edited.
    ///
    /// Which control slows the pointer is an assignment like any other, so it is chosen in the table
    /// or in **Elegir…**, including in the MOD column; this row only owns the fraction it applies,
    /// because a speed is a number of the profile and not of a control.
    private var precisionRow: some View {
        let precision = profiles.selectedPrecision
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(AppText.resolve("Precision factor"))
                Spacer()
                Text("\(Int((precision.scale * 100).rounded())) %")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(
                value: Binding<Double>(
                    get: { precision.scale },
                    set: { profiles.setPrecisionScale($0) }
                ),
                in: PrecisionSettings.minimumScale...PrecisionSettings.maximumScale
            )
            .disabled(emulation.isEnabled || profiles.selectedProfile == nil)
            Text(
                AppText.resolve(
                    "Assign “Precision (hold)” to a control — in the base column or in the MOD column — and the cursor and the scroll move at this fraction while you hold it."
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
