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
            SectionTitle("Sensibilidad del cursor")
            Text(
                "Ajustes del perfil «\(profiles.selectedProfile?.name ?? "—")». Cada perfil guarda "
                + "los suyos, así que uno de diseño y uno de juego pueden moverse distinto."
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            ForEach(CursorSensitivity.allCases, id: \.self) { sensitivity in
                slider(for: sensitivity)
            }

            Button("Restablecer") {
                profiles.resetCursorSensitivity()
            }
            .disabled(emulation.isEnabled || profiles.selectedProfile == nil)

            Text(
                "Se aplica al arrancar la emulación: deténla para cambiarlo."
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
