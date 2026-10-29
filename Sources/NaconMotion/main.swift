import Foundation
import NaconCore

// ¿Llevan los bytes 14-19 del informe XInput algo de movimiento?
//
// El protocolo XInput describe 14 bytes útiles y deja el resto como reservado. La app los ignora, así
// que si los sensores de movimiento del mando existieran y el firmware los publicara en este modo, su
// rastro estaría precisamente ahí. Esta sonda no interpreta nada: cuenta valores distintos por byte y
// avisa de cada cambio, para que mover el mando se vea o no se vea.
//
// Uso: swift run nacon-motion [segundos]

let duration = CommandLine.arguments.count > 1 ? (Double(CommandLine.arguments[1]) ?? 20) : 20
let service = ControllerService()

let lock = NSLock()
var reports = 0
var distinct: [Int: Set<UInt8>] = [:]
var changes: [Int: Int] = [:]
var previous: [UInt8]?
var firstPacket = ""

func hex(_ bytes: [UInt8]) -> String {
    bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
}

service.reportObserver = { report in
    let bytes = report.rawBytes
    guard bytes.count >= 14 else { return }
    let tail = Array(bytes.suffix(6))

    lock.lock()
    reports += 1
    if firstPacket.isEmpty { firstPacket = hex(bytes) }
    for (index, byte) in tail.enumerated() {
        distinct[index, default: []].insert(byte)
    }
    if let previous, previous != tail {
        let moved = (0..<6).filter { previous[$0] != tail[$0] }
        for index in moved {
            changes[index, default: 0] += 1
        }
        print("cambio en bytes 14-19 -> \(hex(tail))  (bytes: \(moved.map { 14 + $0 }))")
        fflush(stdout)
    }
    previous = tail
    lock.unlock()
}

print("Sonda de movimiento del mando — \(Int(duration)) s")
print("Mueve el mando en el aire (gíralo, inclínalo) y no pulses ningún botón ni el touchpad.")
print("---")
service.start()

let deadline = Date().addingTimeInterval(duration)
while Date() < deadline {
    RunLoop.current.run(until: Date().addingTimeInterval(0.2))
}

lock.lock()
let snapshot = (reports: reports, distinct: distinct, changes: changes, firstPacket: firstPacket)
lock.unlock()
service.stop()
RunLoop.current.run(until: Date().addingTimeInterval(0.4))

print("---")
guard snapshot.reports > 0 else {
    print("No llegó ningún informe: el mando no está conectado o lo tiene otra aplicación.")
    exit(1)
}

print("Informes recibidos: \(snapshot.reports)")
print("Primer paquete completo: \(snapshot.firstPacket)")
print("Bytes 14-19, valores distintos vistos y número de cambios:")
var moved = 0
for index in 0..<6 {
    let values = (snapshot.distinct[index] ?? []).sorted()
    let changeCount = snapshot.changes[index] ?? 0
    if changeCount > 0 { moved += 1 }
    let list = values.prefix(6).map { String(format: "%02X", $0) }.joined(separator: " ")
    let suffix = values.count > 6 ? " …" : ""
    print("  byte \(14 + index): \(values.count) valor(es) [\(list)\(suffix)] cambios=\(changeCount)")
}

print("---")
if moved == 0 {
    print("VEREDICTO: los bytes 14-19 no cambiaron en toda la prueba.")
    print("En este modo (XInput) el mando no publica movimiento, o no tiene sensores.")
} else {
    print("VEREDICTO: \(moved) byte(s) de 14-19 cambiaron. Algo publica el mando ahí;")
    print("comprobar si el cambio coincide con moverlo y no con pulsar botones.")
}
