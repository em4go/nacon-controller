import NaconCore
import SwiftUI

struct EmulationSection: View {
    @ObservedObject var emulation: EmulationController
    @EnvironmentObject private var service: ControllerService
    /// S2: the vertical-axis setting belongs to the profile being edited, like the mapping does.
    @EnvironmentObject private var profiles: ProfileLibraryController

    /// The pad light state owned by this section.
    @State private var padLight = PadLight()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("Emulación de ratón y teclado")
            permissionRow
            if !emulation.hasAccessibility {
                staleEntryHint
            }
            Toggle("Emulación activa", isOn: Binding(
                get: { emulation.isEnabled },
                set: { emulation.setEnabled($0) }
            ))
            .toggleStyle(.switch)
            .disabled(!emulation.hasAccessibility)
            lightControls
            // S2: the switch shows the value stored in the selected profile, not a leftover global
            // flag, and flipping it edits that profile so two profiles can differ.
            Toggle("Invertir eje vertical", isOn: Binding(
                get: { profiles.selectedInvertVerticalAxis },
                set: { profiles.setInvertVerticalAxis($0) }
            ))
            .toggleStyle(.switch)
            // The value only reaches the engine when emulation starts, so flipping it mid-run would
            // silently do nothing. Disabled while running, like the mapping editor.
            .disabled(emulation.isEnabled)
            Text(
                "Actívalo si al empujar el stick hacia arriba el cursor baja. Afecta al cursor y al "
                + "desplazamiento, no al indicador del stick en pantalla. Se guarda en el perfil "
                + "activo y se aplica cuando arranca la emulación: deténla para cambiarlo."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            Text(
                "El stick izquierdo mueve el cursor y el derecho desplaza. "
                + "A/B/X son los botones del ratón, la cruceta envía flechas. "
                + "El botón Guide (Xbox) detiene la emulación al instante."
            )
            .font(.callout)
            .foregroundStyle(.secondary)
            if emulation.stoppedByPad {
                Text("Emulación detenida desde el mando.")
                    .font(.callout.bold())
                    .foregroundStyle(.orange)
            }
        }
        .onAppear {
            padLight.isEmulationActive = emulation.isEnabled
        }
        .onChange(of: emulation.isEnabled) { isEnabled in
            padLight.isEmulationActive = isEnabled
        }
        .onChange(of: padLight.isOn) { _ in
            // S1/S2/S4: one send point, driven only by the state; a missing pad is harmless.
            service.sendOutput(padLight.packet)
        }
    }

    // MARK: - S3, S4: the pad light

    private var lightControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Luz como indicador de emulación", isOn: Binding(
                get: { padLight.source == .emulation },
                set: { padLight.source = $0 ? .emulation : .manual }
            ))
            .toggleStyle(.switch)
            Toggle("Luz encendida", isOn: $padLight.isManuallyOn)
                .toggleStyle(.switch)
                .disabled(padLight.source == .emulation)
            Text(
                "Con el indicador activado, la luz pequeña bajo el botón PS se enciende mientras la "
                + "emulación está activa y se apaga al detenerla. Desactívalo para encender y apagar "
                + "la luz a mano."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var staleEntryHint: some View {
        Text(
            "Si la app ya aparece activada en esa lista y el indicador sigue en naranja, la entrada es "
            + "antigua: selecciónala, quítala con el botón − y vuelve a añadirla, o ejecuta "
            + "tccutil reset Accessibility dev.nacon.diagnostics y solicita el permiso otra vez."
        )
        .font(.caption)
        .foregroundStyle(.orange)
    }

    private var permissionTitle: String {
        emulation.hasAccessibility
            ? "Permiso de Accesibilidad concedido"
            : "Falta el permiso de Accesibilidad"
    }

    private var permissionRow: some View {
        HStack(spacing: 10) {
            Image(systemName: emulation.hasAccessibility ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(emulation.hasAccessibility ? Color.green : Color.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(permissionTitle)
                    .font(.callout.bold())
                if !emulation.hasAccessibility {
                    Text(
                        "macOS descarta los eventos sin este permiso. Conce­derlo en Ajustes del Sistema "
                        + "› Privacidad y seguridad › Accesibilidad, y volver a esta ventana."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if !emulation.hasAccessibility {
                HStack(spacing: 8) {
                    Button("Comprobar de nuevo") {
                        emulation.refreshPermission()
                    }
                    Button("Solicitar permiso") {
                        emulation.requestAccessibility()
                    }
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill((emulation.hasAccessibility ? Color.green : Color.orange).opacity(0.1))
        )
    }
}
