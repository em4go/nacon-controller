import Foundation
import NaconCore

// Headless end-to-end check of the production read path.
// Usage: swift run nacon-selftest [seconds]
let duration = CommandLine.arguments.count > 1 ? (Double(CommandLine.arguments[1]) ?? 8) : 8
let service = ControllerService()
service.start()

var lastState = ""
var lastReportCount = 0
let deadline = Date().addingTimeInterval(duration)

while Date() < deadline {
    RunLoop.current.run(until: Date().addingTimeInterval(0.2))
    let stateDescription = "\(service.state.title)|\(service.state.detail ?? "")"
    if stateDescription != lastState {
        print("state: \(service.state.title) \(service.state.detail ?? "")")
        fflush(stdout)
        lastState = stateDescription
    }
    if service.reportCount != lastReportCount {
        lastReportCount = service.reportCount
    }
}

print("devices=\(service.devices.count) reports=\(service.reportCount) reconnects=\(service.reconnectCount)")
RunLoop.current.run(until: Date().addingTimeInterval(0.2))
let lastPacket = service.feed.latest.rawPacketHex
print("lastPacket=\(lastPacket.isEmpty ? "none" : lastPacket)")
fflush(stdout)
let receivedReports = service.reportCount
service.stop()
RunLoop.current.run(until: Date().addingTimeInterval(0.4))
exit(receivedReports > 0 ? 0 : 1)
