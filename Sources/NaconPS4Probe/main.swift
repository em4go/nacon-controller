import Foundation
import IOKit
import IOKit.hid

// Watches every BigBen HID device and reports, with millisecond timestamps, how long the
// controller stays in PS4/HID mode before it re-enumerates as XInput.
//
// Two runs make a controlled experiment:
//   swift run nacon-ps4probe 40 --no-open   control: only observe
//   swift run nacon-ps4probe 40             treatment: open the HID device and read its reports
//
// Usage: swift run nacon-ps4probe [seconds] [--no-open]

let arguments = CommandLine.arguments
let duration = arguments.count > 1 ? (Double(arguments[1]) ?? 40) : 40
let shouldOpen = !arguments.contains("--no-open")

let started = Date()

func stamp() -> String { String(format: "+%07.3f", Date().timeIntervalSince(started)) }

func log(_ message: String) {
    print("[\(stamp())] \(message)")
    fflush(stdout)
}

struct Observation {
    let product: String
    let productID: Int
    let appearedAt: Date
    var reportValues = 0
    var digitizerEvents = 0
}

var observations: [UInt64: Observation] = [:]
var completed: [Observation] = []

func entryID(of device: IOHIDDevice) -> UInt64 {
    let service = IOHIDDeviceGetService(device)
    guard service != 0 else { return 0 }
    var identifier: UInt64 = 0
    IORegistryEntryGetRegistryEntryID(service, &identifier)
    return identifier
}

func intProperty(_ device: IOHIDDevice, _ key: String) -> Int? {
    (IOHIDDeviceGetProperty(device, key as CFString) as? NSNumber)?.intValue
}

func stringProperty(_ device: IOHIDDevice, _ key: String) -> String? {
    IOHIDDeviceGetProperty(device, key as CFString) as? String
}

/// Checks whether the report descriptor declares a Digitizer usage page, which is where a
/// touchpad has to appear if the firmware exposes one.
func declaresDigitizer(_ data: Data) -> Bool {
    let pattern: [UInt8] = [0x05, 0x0D]
    let bytes = [UInt8](data)
    guard bytes.count >= pattern.count else { return false }
    for index in 0...(bytes.count - pattern.count) {
        if bytes[index] == pattern[0], bytes[index + 1] == pattern[1] { return true }
    }
    return false
}

let onValue: IOHIDValueCallback = { _, _, sender, value in
    let element = IOHIDValueGetElement(value)
    let page = IOHIDElementGetUsagePage(element)
    let usage = IOHIDElementGetUsage(element)
    let integer = IOHIDValueGetIntegerValue(value)

    var identifier: UInt64 = 0
    if let sender {
        identifier = entryID(of: Unmanaged<IOHIDDevice>.fromOpaque(sender).takeUnretainedValue())
    }

    observations[identifier]?.reportValues += 1

    // Axes and buttons are noise here; the only thing worth printing as it happens is a
    // digitizer element, because that is the touchpad.
    if page == 0x0D {
        observations[identifier]?.digitizerEvents += 1
        log("  DIGITIZER  uso=0x\(String(format: "%02X", usage))  valor=\(integer)")
    }
}

let onMatch: IOHIDDeviceCallback = { _, _, _, device in
    let productID = intProperty(device, kIOHIDProductIDKey) ?? -1
    let product = stringProperty(device, kIOHIDProductKey) ?? "sin nombre"
    let identifier = entryID(of: device)
    let usagePage = intProperty(device, kIOHIDPrimaryUsagePageKey) ?? -1
    let usage = intProperty(device, kIOHIDPrimaryUsageKey) ?? -1

    var descriptorSummary = "sin descriptor de informe"
    if let descriptor = IOHIDDeviceGetProperty(device, kIOHIDReportDescriptorKey as CFString) as? Data {
        let path = "/tmp/nacon-rdesc-\(String(format: "%04X", productID)).bin"
        try? descriptor.write(to: URL(fileURLWithPath: path))
        let digitizer = declaresDigitizer(descriptor) ? "SÍ" : "no"
        descriptorSummary = "descriptor=\(descriptor.count)B  touchpad en descriptor=\(digitizer)  \(path)"
    }

    observations[identifier] = Observation(product: product, productID: productID, appearedAt: Date())

    log("APARECE    \(product)  PID=0x\(String(format: "%04X", productID))  uso=\(usagePage)/\(usage)")
    log("           \(descriptorSummary)")

    if shouldOpen {
        let status = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
        let description = status == kIOReturnSuccess ? "OK" : "error 0x\(String(format: "%08X", status))"
        log("           apertura: \(description)")
        if status == kIOReturnSuccess {
            IOHIDDeviceRegisterInputValueCallback(device, onValue, nil)
            IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        }
    }
}

let onRemoval: IOHIDDeviceCallback = { _, _, _, device in
    let identifier = entryID(of: device)
    guard let observation = observations.removeValue(forKey: identifier) else {
        log("DESAPARECE dispositivo no registrado")
        return
    }
    let seconds = Date().timeIntervalSince(observation.appearedAt)
    log(String(
        format: "DESAPARECE %@  tras %.3f s  valores=%@  eventos de touchpad=%@",
        observation.product,
        seconds,
        String(observation.reportValues),
        String(observation.digitizerEvents)
    ))
    completed.append(observation)
}

print("Sonda del modo PS4 — ventana de 0D05")
print("Modo: \(shouldOpen ? "abre el dispositivo y lee sus informes" : "solo observa (control)")")
print("Duración: \(Int(duration)) s")
print("Desenchufa y vuelve a enchufar el mando ahora.")
print("---")
fflush(stdout)

let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))

IOHIDManagerRegisterDeviceMatchingCallback(manager, onMatch, nil)
IOHIDManagerRegisterDeviceRemovalCallback(manager, onRemoval, nil)
IOHIDManagerSetDeviceMatching(manager, [kIOHIDVendorIDKey: 0x146B] as CFDictionary)
IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)

let openStatus = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
if openStatus != kIOReturnSuccess {
    log("aviso: IOHIDManagerOpen devolvió 0x\(String(format: "%08X", openStatus))")
}

let deadline = Date().addingTimeInterval(duration)
while Date() < deadline {
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))
}

print("---")
if completed.isEmpty {
    print("No se observó ninguna aparición y desaparición completa.")
    print("Si el mando ya estaba enchufado antes de arrancar, desenchúfalo y vuelve a ejecutar.")
} else {
    print("Resumen:")
    for observation in completed {
        print("  PID=0x\(String(format: "%04X", observation.productID))  \(observation.product)")
        print("    valores de entrada=\(observation.reportValues)  eventos de touchpad=\(observation.digitizerEvents)")
    }
}
fflush(stdout)
exit(completed.isEmpty ? 1 : 0)
