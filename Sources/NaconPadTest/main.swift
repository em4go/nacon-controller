import Foundation
import NaconCore

func pump(_ seconds: TimeInterval) {
    let deadline = Date().addingTimeInterval(seconds)
    while Date() < deadline {
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    }
}

let mode = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "led"
let service = ControllerService()
service.start()

let connectDeadline = Date().addingTimeInterval(6)
while Date() < connectDeadline, !service.state.isConnected {
    pump(0.1)
}
guard service.state.isConnected else {
    print("ERROR: no hay mando conectado (\(service.state.title))")
    fflush(stdout)
    service.stop()
    exit(2)
}
print("conectado al mando")
fflush(stdout)

switch mode {
case "led":
    let sequence: [XInputOutputReport.LEDPattern] = [.off, .player1, .blink, .rotate, .player1]
    for pattern in sequence {
        let value = String(format: "%02x", pattern.rawValue)
        print("LED -> \(pattern.label)  (byte 0x\(value))")
        fflush(stdout)
        service.sendOutput(XInputOutputReport.led(pattern))
        pump(3)
    }
case "rumble":
    for step in 1...3 {
        print("vibración pulso \(step)")
        fflush(stdout)
        service.sendOutput(XInputOutputReport.rumble(left: 200, right: 200))
        pump(0.6)
        service.sendOutput(XInputOutputReport.rumble(left: 0, right: 0))
        pump(0.6)
    }
case "both":
    // Differential test: rumble proves the output channel actually has an effect on the pad,
    // so a silent LED afterwards means the light is not host-controllable rather than unreachable.
    print("1) vibración fuerte — ¿la notas?")
    fflush(stdout)
    service.sendOutput(XInputOutputReport.rumble(left: 220, right: 220))
    pump(0.3)
    print("   escritura: \(service.lastWriteStatus)")
    fflush(stdout)
    pump(0.9)
    service.sendOutput(XInputOutputReport.rumble(left: 0, right: 0))
    pump(1.3)

    let alternation: [(String, XInputOutputReport.LEDPattern)] = [
        ("2) LED apagado", .off),
        ("3) LED encendido", .player1),
        ("4) LED apagado", .off),
        ("5) LED encendido", .player1),
    ]
    for (label, pattern) in alternation {
        let value = String(format: "%02x", pattern.rawValue)
        print("\(label) — byte 0x\(value) — 3 s")
        fflush(stdout)
        service.sendOutput(XInputOutputReport.led(pattern))
        pump(0.3)
        print("   escritura: \(service.lastWriteStatus)")
        fflush(stdout)
        pump(2.7)
    }
default:
    print("uso: nacon-padtest [led|rumble]")
}
print("última escritura: \(service.lastWriteStatus)")
service.stop()
pump(0.4)
