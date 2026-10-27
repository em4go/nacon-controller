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
default:
    print("uso: nacon-padtest [led|rumble]")
}
print("última escritura: \(service.lastWriteStatus)")
service.stop()
pump(0.4)
