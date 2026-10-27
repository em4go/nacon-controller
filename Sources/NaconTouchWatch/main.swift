import Foundation
import NaconCore

// Watches the six reserved bytes of the XInput report (indices 14...19) while the touchpad is
// pressed, to establish whether this controller reports it at all in PC/XInput mode.
// It also logs every change of the button mask, in case the touchpad press is folded into it.
//
// Usage: swift run nacon-touchpad [seconds]

let duration = CommandLine.arguments.count > 1 ? (Double(CommandLine.arguments[1]) ?? 45) : 45

/// Reserved region of the 20-byte XInput report. Copes with a short packet instead of crashing.
func reservedBytes(of raw: [UInt8]) -> [UInt8] {
    let lower = 14
    guard raw.count > lower else { return [] }
    let upper = min(20, raw.count)
    return Array(raw[lower..<upper])
}

func hex(_ bytes: [UInt8]) -> String {
    bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
}

let lock = NSLock()
var pendingLines: [String] = []
var previousReserved: [UInt8] = []
var previousButtons: UInt16 = 0
var hasBaseline = false
var totalSamples = 0
var nonzeroSamples = 0
var observedValues: Set<String> = []
var firstFullReport: [UInt8] = []

func record(_ report: XInputReport) {
    let raw = report.rawBytes
    let reserved = reservedBytes(of: raw)
    let buttons = report.buttons.rawValue

    lock.lock()
    defer { lock.unlock() }

    totalSamples += 1
    if firstFullReport.isEmpty { firstFullReport = raw }
    if reserved.contains(where: { $0 != 0 }) {
        nonzeroSamples += 1
        observedValues.insert(hex(reserved))
    }

    guard hasBaseline else {
        previousReserved = reserved
        previousButtons = buttons
        hasBaseline = true
        pendingLines.append("línea base  bytes 14-19: \(hex(reserved))   informe: \(hex(raw))")
        return
    }

    if reserved != previousReserved {
        pendingLines.append(
            "cambio  bytes 14-19:  \(hex(previousReserved))  →  \(hex(reserved))   informe: \(hex(raw))"
        )
        previousReserved = reserved
    }

    if buttons != previousButtons {
        pendingLines.append(
            "botones 0x\(String(previousButtons, radix: 16, uppercase: true)) → 0x\(String(buttons, radix: 16, uppercase: true))"
                + "   bytes 14-19: \(hex(reserved))"
        )
        previousButtons = buttons
    }
}

let service = ControllerService()
service.reportObserver = record
service.start()

print("Observando el mando durante \(Int(duration)) s.")
print("Instrucciones: pulsa el touchpad como si fuera un botón, varias veces y con calma.")
print("Los bytes 14-19 se han visto a cero en todas las capturas anteriores;")
print("cualquier cambio ahí es el hallazgo que buscamos.")
print("---")
fflush(stdout)

var lastState = ""
let deadline = Date().addingTimeInterval(duration)

while Date() < deadline {
    RunLoop.current.run(until: Date().addingTimeInterval(0.1))

    let stateDescription = "\(service.state.title)|\(service.state.detail ?? "")"
    if stateDescription != lastState {
        print("estado: \(service.state.title) \(service.state.detail ?? "")")
        fflush(stdout)
        lastState = stateDescription
    }

    lock.lock()
    let lines = pendingLines
    pendingLines.removeAll(keepingCapacity: true)
    lock.unlock()

    if !lines.isEmpty {
        for line in lines { print(line) }
        fflush(stdout)
    }
}

lock.lock()
let samples = totalSamples
let nonzero = nonzeroSamples
let values = observedValues.sorted()
let firstReport = firstFullReport
lock.unlock()

service.stop()
RunLoop.current.run(until: Date().addingTimeInterval(0.3))

print("---")
print("muestras=\(samples)  con bytes 14-19 distintos de cero=\(nonzero)")
if firstReport.isEmpty {
    print("resultado: no se recibió ningún informe. ¿Está el mando conectado y la app cerrada?")
} else if nonzero == 0 {
    print("resultado: los bytes 14-19 siguieron a cero durante toda la captura.")
    print("           El touchpad no deja rastro en el informe XInput.")
} else {
    print("resultado: el touchpad SÍ produce datos. Valores observados:")
    for value in values { print("           \(value)") }
}
fflush(stdout)

exit(firstReport.isEmpty ? 1 : 0)
