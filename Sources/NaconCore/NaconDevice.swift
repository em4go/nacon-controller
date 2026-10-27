import Foundation

/// USB identities this project knows about.
public enum NaconIDs {
    public static let bigbenVendorID = 0x146B
    public static let xinputProductID = 0x0603
    public static let ps4ProductID = 0x0D05
    public static let bootloaderVendorID = 0x2F24
    public static let bootloaderProductID = 0x0001

    /// Interrupt IN endpoint of the XInput interface.
    public static let xinputEndpointAddress: Int = 0x81
    public static let xinputConfigurationValue = 1
}

public enum NaconDeviceMode: String, Sendable {
    case xinput = "XInput"
    case ps4HID = "PS4 / HID"
    case bootloader = "Bootloader"
    case unknown = "Desconocido"

    /// Controls that this project can actually read in the given mode.
    public var readableControls: String {
        switch self {
        case .xinput:
            return "Todos los botones, sticks y gatillos mediante el protocolo XInput."
        case .ps4HID:
            return "Modo HID de PS4: no lo lee esta aplicación."
        case .bootloader:
            return "Modo de actualización de firmware: no envía entradas."
        case .unknown:
            return "Identidad desconocida: no se intenta leer."
        }
    }
}

public struct NaconDevice: Identifiable, Equatable, Sendable {
    public let id: UInt64
    public let productName: String
    public let vendorID: Int
    public let productID: Int
    public let serialNumber: String?
    public let locationID: Int

    public init(
        id: UInt64,
        productName: String,
        vendorID: Int,
        productID: Int,
        serialNumber: String?,
        locationID: Int
    ) {
        self.id = id
        self.productName = productName
        self.vendorID = vendorID
        self.productID = productID
        self.serialNumber = serialNumber
        self.locationID = locationID
    }

    public var mode: NaconDeviceMode {
        if vendorID == NaconIDs.bootloaderVendorID { return .bootloader }
        guard vendorID == NaconIDs.bigbenVendorID else { return .unknown }
        switch productID {
        case NaconIDs.xinputProductID: return .xinput
        case NaconIDs.ps4ProductID: return .ps4HID
        default: return .unknown
        }
    }

    public var isReadable: Bool { mode == .xinput }

    public var vendorHex: String { String(format: "0x%04X", vendorID) }
    public var productHex: String { String(format: "0x%04X", productID) }
    public var idHex: String { String(format: "%04X:%04X", vendorID, productID) }
}
