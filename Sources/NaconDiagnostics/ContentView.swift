import NaconCore
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var service: ControllerService
    @EnvironmentObject private var emulation: EmulationController

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                StatusBanner(state: service.state)
                DeviceListSection(devices: service.devices)
                EmulationSection(emulation: emulation)
                if service.state.isConnected, let report = service.report {
                    ButtonMatrixSection(report: report)
                    AnalogSection(report: report)
                    PacketSection(
                        reportCount: service.reportCount,
                        lastReportAt: service.lastReportAt,
                        rawPacketHex: service.rawPacketHex
                    )
                } else if service.state.isConnected {
                    Text("Conectado, esperando el primer informe del mando…")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                LegendSection(devices: service.devices)
            }
            .padding(20)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - S2, S6: connection state

struct StatusBanner: View {
    let state: ConnectionState

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Circle()
                .fill(state.tint)
                .frame(width: 12, height: 12)
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 3) {
                Text(state.title)
                    .font(.title3.bold())
                if let detail = state.detail {
                    Text(detail)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(state.tint.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(state.tint.opacity(0.4)))
    }
}

// MARK: - S1, S6: detected devices

struct DeviceListSection: View {
    let devices: [NaconDevice]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("Mandos detectados")
            if devices.isEmpty {
                NoDevicePanel()
            } else {
                ForEach(devices) { device in
                    DeviceRow(device: device)
                }
            }
        }
    }
}

struct NoDevicePanel: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "gamecontroller")
                .font(.system(size: 30))
                .foregroundStyle(.secondary)
            Text("NO SE HA DETECTADO NINGÚN MANDO")
                .font(.headline)
            Text(
                "Conecta el NACON por USB. Si ya está conectado, desconéctalo y vuelve a conectarlo "
                + "sin pulsar botones."
            )
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.08)))
    }
}

struct DeviceRow: View {
    let device: NaconDevice

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(device.productName).font(.headline)
                Spacer()
                Text(device.mode.rawValue)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(
                            device.isReadable ? Color.green.opacity(0.2) : Color.orange.opacity(0.2)
                        )
                    )
            }
            Text("\(device.idHex)   ·   serial \(device.serialNumber ?? "no disponible")")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
            Text(device.mode.readableControls)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.06)))
    }
}

// MARK: - S3: buttons in real time

struct ButtonMatrixSection: View {
    let report: XInputReport

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("Botones")
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(XInputControl.allCases, id: \.self) { control in
                    ControlCell(control: control, pressed: control.isPressed(in: report))
                }
            }
        }
    }
}

struct ControlCell: View {
    let control: XInputControl
    let pressed: Bool

    var body: some View {
        Text(control.rawValue)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, minHeight: 34)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(pressed ? Color.accentColor : Color.secondary.opacity(0.12))
            )
            .foregroundStyle(pressed ? Color.white : Color.primary)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.25)))
            .animation(.easeOut(duration: 0.08), value: pressed)
    }
}

// MARK: - S4: sticks and triggers

struct AnalogSection: View {
    let report: XInputReport

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("Sticks y gatillos")
            HStack(alignment: .top, spacing: 20) {
                StickView(title: "Stick izquierdo", stick: report.leftStick)
                StickView(title: "Stick derecho", stick: report.rightStick)
                VStack(spacing: 16) {
                    TriggerBar(title: "LT", value: report.leftTrigger)
                    TriggerBar(title: "RT", value: report.rightTrigger)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

struct StickView: View {
    let title: String
    let stick: XInputStick

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geometry in
                let side = min(geometry.size.width, geometry.size.height)
                let radius = side / 2 - 10
                ZStack {
                    Circle().stroke(Color.secondary.opacity(0.35), lineWidth: 1)
                    Circle().stroke(Color.secondary.opacity(0.15), lineWidth: 1).scaleEffect(0.5)
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 14, height: 14)
                        .offset(x: radius * stick.normalizedX, y: -radius * stick.normalizedY)
                }
                .frame(width: side, height: side)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: 130)
            Text(title).font(.caption.bold())
            Text("x \(stick.rawX)   y \(stick.rawY)")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct TriggerBar: View {
    let title: String
    let value: UInt8

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.caption.bold())
                Spacer()
                Text("\(value)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.15))
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: geometry.size.width * CGFloat(value) / 255.0)
                }
            }
            .frame(height: 10)
        }
    }
}

// MARK: - Diagnostics

struct PacketSection: View {
    let reportCount: Int
    let lastReportAt: Date?
    let rawPacketHex: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle("Diagnóstico del enlace")
            TimelineView(.periodic(from: .now, by: 0.25)) { context in
                HStack(spacing: 18) {
                    Metric(label: "Informes", value: "\(reportCount)")
                    Metric(label: "Último informe", value: age(from: context.date))
                    Spacer()
                }
            }
            Text(rawPacketHex)
                .font(.system(.caption2, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.08)))
        }
    }

    private func age(from now: Date) -> String {
        guard let lastReportAt else { return "—" }
        let interval = now.timeIntervalSince(lastReportAt)
        return String(format: "hace %.1f s", interval)
    }
}

struct Metric: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.system(.callout, design: .monospaced))
        }
    }
}

// MARK: - S7: what is and is not readable

struct LegendSection: View {
    let devices: [NaconDevice]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionTitle("Qué se puede leer")
            Text(
                "Este mando no es un dispositivo HID, así que GameController y CoreHID no pueden verlo. "
                + "Se lee con IOUSBHost hablando el protocolo XInput: botones, sticks y gatillos."
            )
            .font(.callout)
            .foregroundStyle(.secondary)
            Text(
                "No accesibles por esta vía: touchpad, jack de audio, luz del mando y vibración "
                + "en este modo. Tampoco hay lectura posible en modo PS4 (HID) ni en modo bootloader."
            )
            .font(.callout)
            .foregroundStyle(.secondary)
            if devices.contains(where: { $0.mode == .bootloader }) {
                Text(
                    "El mando está en modo actualizador de firmware. "
                    + "Desconéctalo y vuelve a conectarlo sin pulsar botones."
                )
                    .font(.callout.bold())
                    .foregroundStyle(.orange)
            }
        }
    }
}

struct SectionTitle: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text.uppercased())
            .font(.caption.bold())
            .foregroundStyle(.secondary)
            .tracking(0.8)
    }
}

private extension ConnectionState {
    var tint: Color {
        switch self {
        case .searching: return .gray
        case .configuring: return .blue
        case .connected: return .green
        case .disconnected: return .orange
        case .failed: return .red
        }
    }
}
