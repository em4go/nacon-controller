import NaconCore
import SwiftUI

struct EmulationSection: View {
    @ObservedObject var emulation: EmulationController

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("Emulación de ratón y teclado")
            permissionRow
            Toggle("Emulación activa", isOn: Binding(
                get: { emulation.isEnabled },
                set: { emulation.setEnabled($0) }
            ))
            .toggleStyle(.switch)
            .disabled(!emulation.hasAccessibility)
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
                Button("Solicitar permiso") {
                    emulation.requestAccessibility()
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
