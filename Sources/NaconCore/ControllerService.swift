import Combine
import Foundation
import IOKit
import IOUSBHost

public enum ConnectionState: Equatable, Sendable {
    case searching
    case configuring
    case connected
    case disconnected(String)
    case failed(String)

    public var title: LocalizedStringResource {
        switch self {
        case .searching: return Localization.resource("Searching for a controller")
        case .configuring: return Localization.resource("Configuring the device")
        case .connected: return Localization.resource("Connected")
        case .disconnected: return Localization.resource("Controller disconnected")
        case .failed: return Localization.resource("Access error")
        }
    }

    public var detail: String? {
        switch self {
        case .disconnected(let reason), .failed(let reason): return reason
        default: return nil
        }
    }

    public var isConnected: Bool { self == .connected }
}

/// Reads a NACON pad through IOUSBHost and publishes its live state.
///
/// The pad enumerates as a vendor-specific Xbox 360 interface (0xFF/0x5D/0x01). macOS never
/// configures it, so the interface only appears after an explicit SET_CONFIGURATION(1).
public final class ControllerService: ObservableObject {
    @Published public private(set) var devices: [NaconDevice] = []
    @Published public private(set) var state: ConnectionState = .searching
    @Published public private(set) var activeDevice: NaconDevice?
    /// The live values, coalesced. The window reads them here instead of off this object, so a report
    /// does not rebuild every view that only cares about the connection.
    public let feed = ReportFeed()
    /// Total reports seen, for the command-line tools. Deliberately not published for the same reason:
    /// a published counter would rebuild the window at report rate.
    public private(set) var reportCount = 0
    @Published public private(set) var reconnectCount = 0
    @Published public private(set) var lastWriteStatus = "—"

    /// Called on the I/O queue for every decoded report, before the UI throttling.
    public var reportObserver: ((XInputReport) -> Void)?

    private let ioQueue = DispatchQueue(label: "dev.nacon.controller.io")
    private let staleAfter: TimeInterval = 2.0
    private var timer: DispatchSourceTimer?
    private var link: DeviceLink?
    private var lastReportStamp: Date?
    private var emittedCount = 0
    private var lastPublishedReport: XInputReport?
    private var lastPublishTime = Date.distantPast
    private var started = false

    public init() {}

    public func start() {
        ioQueue.async { [weak self] in
            guard let self, !self.started else { return }
            self.started = true
            let source = DispatchSource.makeTimerSource(queue: self.ioQueue)
            source.schedule(deadline: .now(), repeating: .milliseconds(400))
            source.setEventHandler { [weak self] in self?.reconcile() }
            source.resume()
            self.timer = source
        }
    }

    public func stop() {
        ioQueue.async { [weak self] in
            guard let self, self.started else { return }
            self.started = false
            self.timer?.cancel()
            self.timer = nil
            self.teardown(reason: nil)
        }
    }

    /// Sends a control packet (LED or rumble) to the pad. Safe to call from any thread.
    public func sendOutput(_ packet: [UInt8]) {
        enqueueOutput(packet) {}
    }

    /// Sends a packet and waits until the pad accepted it, or until `timeout` elapses.
    ///
    /// The app needs this at termination: an ordinary send is asynchronous, so asking the pad to go
    /// dark and then exiting immediately leaves the packet unsent and the light on. Blocking briefly
    /// at quit time is acceptable; what is not acceptable is calling this from the I/O queue itself,
    /// which is where the completion runs.
    /// - Returns: whether the write completed before the timeout.
    @discardableResult
    public func sendOutputAndWait(_ packet: [UInt8], timeout: TimeInterval = 0.3) -> Bool {
        let done = DispatchSemaphore(value: 0)
        enqueueOutput(packet) { done.signal() }
        return done.wait(timeout: .now() + timeout) == .success
    }

    private func enqueueOutput(_ packet: [UInt8], completion: @escaping () -> Void) {
        ioQueue.async { [weak self] in
            guard let self else {
                completion()
                return
            }
            guard let current = self.link, let outPipe = current.outPipe else {
                self.publishWriteStatus("sin endpoint de salida")
                completion()
                return
            }
            let buffer = NSMutableData(bytes: packet, length: packet.count)
            do {
                try outPipe.enqueueIORequest(
                    with: buffer,
                    completionTimeout: 0
                ) { [weak self] status, transferred in
                    guard let self else {
                        completion()
                        return
                    }
                    self.ioQueue.async {
                        if !current.isDead {
                            let text = status == kIOReturnSuccess
                                ? "ok (\(transferred) bytes)"
                                : "error \(Self.hex(status))"
                            self.publishWriteStatus(text)
                        }
                        completion()
                    }
                }
            } catch {
                self.publishWriteStatus("no se pudo enviar: \(error.localizedDescription)")
                completion()
            }
        }
    }

    // MARK: - Reconciliation loop

    private func reconcile() {
        let found = Self.scanForNaconDevices()
        publishDevices(found.map(\.info))

        if link != nil {
            let idle = Date().timeIntervalSince(lastReportStamp ?? Date())
            if idle <= staleAfter {
                // Healthy link: the freshly scanned services are not needed.
                found.forEach { IOObjectRelease($0.service) }
                return
            }
            teardown(reason: Localization.resolve("The controller stopped sending data"))
        }

        guard let candidate = found.first(where: { $0.info.isReadable }) else {
            found.forEach { IOObjectRelease($0.service) }
            if link == nil { publish(state: .searching) }
            return
        }
        for entry in found where entry.info.id != candidate.info.id {
            IOObjectRelease(entry.service)
        }
        connect(candidate)
    }

    // MARK: - Connection

    private func connect(_ found: FoundDevice) {
        publish(state: .configuring)
        var device: IOUSBHostDevice?
        var hostInterface: IOUSBHostInterface?
        do {
            let opened = try IOUSBHostDevice(
                __ioService: found.service,
                options: [],
                queue: nil,
                interestHandler: nil
            )
            device = opened
            if opened.configurationDescriptor == nil {
                try opened.__configure(withValue: NaconIDs.xinputConfigurationValue, matchInterfaces: true)
            }
            guard let interfaceService = Self.waitForInterface(number: 0, childOf: found.service) else {
                throw ControllerError.interfaceMissing
            }
            defer { IOObjectRelease(interfaceService) }
            let openedInterface = try IOUSBHostInterface(
                __ioService: interfaceService,
                options: [],
                queue: nil,
                interestHandler: nil
            )
            hostInterface = openedInterface
            let pipe = try openedInterface.copyPipe(withAddress: NaconIDs.xinputEndpointAddress)
            let outPipe = try? openedInterface.copyPipe(withAddress: NaconIDs.xinputOutEndpointAddress)
            let fresh = DeviceLink(
                device: opened,
                hostInterface: openedInterface,
                pipe: pipe,
                outPipe: outPipe,
                service: found.service
            )
            link = fresh
            lastReportStamp = Date()
            emittedCount = 0
            lastPublishedReport = nil
            lastPublishTime = Date.distantPast
            publishDevice(found.info)
            publish(state: .connected)
            publishReport(nil, count: 0, hex: "", at: nil)
            readNext(link: fresh)
        } catch {
            hostInterface?.destroy()
            device?.destroy()
            IOObjectRelease(found.service)
            publish(state: .failed(error.localizedDescription))
        }
    }

    private func readNext(link current: DeviceLink) {
        guard !current.isDead, link === current else { return }
        let buffer = NSMutableData(length: 64) ?? NSMutableData()
        do {
            try current.pipe.enqueueIORequest(
                with: buffer,
                completionTimeout: 0
            ) { [weak self, weak current] status, transferred in
                guard let self, let current else { return }
                self.ioQueue.async {
                    guard !current.isDead, self.link === current else { return }
                    guard status == kIOReturnSuccess else {
                        self.teardown(reason: Localization.format("USB read interrupted (%@)", Self.hex(status)))
                        return
                    }
                    let bytes = [UInt8](Data(bytes: buffer.bytes, count: Int(transferred)))
                    self.handle(packet: bytes)
                    self.readNext(link: current)
                }
            }
        } catch {
            teardown(reason: Localization.format("Could not read from the endpoint: %@", error.localizedDescription))
        }
    }

    private func handle(packet: [UInt8]) {
        guard let decoded = XInputReport.decode(packet) else { return }
        reportObserver?(decoded)
        let stamp = Date()
        lastReportStamp = stamp
        emittedCount += 1

        // The pad streams at roughly 250 Hz. Publishing every packet would flood the main queue,
        // so only publish when the observable state changes or a liveness tick is due.
        let previous = lastPublishedReport
        let stateChanged = previous?.buttons != decoded.buttons
            || previous?.leftTrigger != decoded.leftTrigger
            || previous?.rightTrigger != decoded.rightTrigger
            || previous?.leftStick != decoded.leftStick
            || previous?.rightStick != decoded.rightStick
        let tickDue = stamp.timeIntervalSince(lastPublishTime) >= 0.2
        guard stateChanged || tickDue else { return }

        lastPublishedReport = decoded
        lastPublishTime = stamp
        let hex = packet.map { String(format: "%02x", $0) }.joined(separator: " ")
        publishReport(decoded, count: emittedCount, hex: hex, at: stamp)
    }

    private func teardown(reason: String?) {
        guard let current = link else { return }
        current.isDead = true
        link = nil
        current.hostInterface.destroy()
        current.device.destroy()
        IOObjectRelease(current.service)
        lastReportStamp = nil
        emittedCount = 0
        lastPublishedReport = nil
        lastPublishTime = Date.distantPast
        publishWriteStatus("—")
        publishDevice(nil)
        publishReport(nil, count: 0, hex: "", at: nil)
        if let reason {
            publish(state: .disconnected(reason))
            publishReconnect()
        } else {
            publish(state: .searching)
        }
    }
}

// MARK: - Helpers

private struct FoundDevice {
    let info: NaconDevice
    let service: io_service_t
}

private final class DeviceLink {
    let device: IOUSBHostDevice
    let hostInterface: IOUSBHostInterface
    let pipe: IOUSBHostPipe
    let outPipe: IOUSBHostPipe?
    let service: io_service_t
    var isDead = false

    init(
        device: IOUSBHostDevice,
        hostInterface: IOUSBHostInterface,
        pipe: IOUSBHostPipe,
        outPipe: IOUSBHostPipe?,
        service: io_service_t
    ) {
        self.device = device
        self.hostInterface = hostInterface
        self.pipe = pipe
        self.outPipe = outPipe
        self.service = service
    }
}

private enum ControllerError: LocalizedError {
    case interfaceMissing

    var errorDescription: String? {
        switch self {
        case .interfaceMissing:
            return Localization.resolve("The device did not expose interface 0 after being configured.")
        }
    }
}

extension ControllerService {
    private static func hex(_ value: IOReturn) -> String {
        String(format: "0x%08X", UInt32(bitPattern: value))
    }

    private static func scanForNaconDevices() -> [FoundDevice] {
        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching("IOUSBHostDevice")
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return []
        }
        defer { IOObjectRelease(iterator) }

        var results: [FoundDevice] = []
        var service = IOIteratorNext(iterator)
        while service != 0 {
            if let info = describe(service) {
                results.append(FoundDevice(info: info, service: service))
            } else {
                IOObjectRelease(service)
            }
            service = IOIteratorNext(iterator)
        }
        return results
    }

    private static func describe(_ service: io_service_t) -> NaconDevice? {
        guard let vendor = intProperty(service, "idVendor"),
              vendor == NaconIDs.bigbenVendorID || vendor == NaconIDs.bootloaderVendorID,
              let product = intProperty(service, "idProduct")
        else {
            return nil
        }
        var entryID: UInt64 = 0
        IORegistryEntryGetRegistryEntryID(service, &entryID)
        return NaconDevice(
            id: entryID,
            productName: stringProperty(service, "USB Product Name")
                ?? stringProperty(service, "kUSBProductString")
                ?? Localization.resolve("NACON device"),
            vendorID: vendor,
            productID: product,
            serialNumber: stringProperty(service, "kUSBSerialNumberString"),
            locationID: intProperty(service, "locationID") ?? 0
        )
    }

    private static func waitForInterface(number: Int, childOf parent: io_service_t) -> io_service_t? {
        let deadline = Date().addingTimeInterval(1.5)
        repeat {
            if let match = interfaceService(number: number, childOf: parent) {
                return match
            }
            usleep(50_000)
        } while Date() < deadline
        return nil
    }

    private static func interfaceService(number: Int, childOf parent: io_service_t) -> io_service_t? {
        var children: io_iterator_t = 0
        guard IORegistryEntryGetChildIterator(parent, kIOServicePlane, &children) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(children) }

        var child = IOIteratorNext(children)
        while child != 0 {
            var className = [CChar](repeating: 0, count: 128)
            IOObjectGetClass(child, &className)
            if String(cString: className) == "IOUSBHostInterface",
               intProperty(child, "bInterfaceNumber") == number {
                return child
            }
            IOObjectRelease(child)
            child = IOIteratorNext(children)
        }
        return nil
    }

    private static func intProperty(_ service: io_service_t, _ key: String) -> Int? {
        guard let value = IORegistryEntryCreateCFProperty(
            service,
            key as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? NSNumber else {
            return nil
        }
        return value.intValue
    }

    private static func stringProperty(_ service: io_service_t, _ key: String) -> String? {
        IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue() as? String
    }
}

// MARK: - Publishing

extension ControllerService {
    private func publish(state newState: ConnectionState) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.state != newState else { return }
            self.state = newState
        }
    }

    private func publishDevices(_ newDevices: [NaconDevice]) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.devices != newDevices else { return }
            self.devices = newDevices
        }
    }

    private func publishDevice(_ device: NaconDevice?) {
        DispatchQueue.main.async { [weak self] in
            self?.activeDevice = device
        }
    }

    private func publishReport(_ newReport: XInputReport?, count: Int, hex: String, at date: Date?) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.reportCount = count
            self.feed.submit(
                ReportFeed.Snapshot(
                    report: newReport,
                    count: count,
                    rawPacketHex: hex,
                    receivedAt: date
                )
            )
        }
    }

    private func publishWriteStatus(_ text: String) {
        DispatchQueue.main.async { [weak self] in
            self?.lastWriteStatus = text
        }
    }

    private func publishReconnect() {
        DispatchQueue.main.async { [weak self] in
            self?.reconnectCount += 1
        }
    }
}
