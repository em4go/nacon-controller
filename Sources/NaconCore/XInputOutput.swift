import Foundation

/// Packets the host sends to the pad on its interrupt OUT endpoint.
///
/// These are the commands the Linux `xpad` driver uses for the same hardware: a 3-byte LED
/// command and an 8-byte rumble command. Both are documented as harmless to send.
public enum XInputOutputReport {
    public static let ledPacketLength = 3
    public static let rumblePacketLength = 8

    /// LED patterns accepted by the pad's 3-byte command.
    public enum LEDPattern: UInt8, CaseIterable, Sendable {
        case off = 0x00
        case blink = 0x01
        case blinkThenSolid = 0x02
        case player1 = 0x06
        case player2 = 0x07
        case player3 = 0x08
        case player4 = 0x09
        case rotate = 0x0A

        public var label: String {
            switch self {
            case .off: return "apagado"
            case .blink: return "parpadeo"
            case .blinkThenSolid: return "parpadeo y fijo"
            case .player1: return "jugador 1 fijo"
            case .player2: return "jugador 2 fijo"
            case .player3: return "jugador 3 fijo"
            case .player4: return "jugador 4 fijo"
            case .rotate: return "rotación"
            }
        }
    }

    /// `01 03 <pattern>`; the pad itself sends the same shape on its input endpoint.
    public static func led(_ pattern: LEDPattern) -> [UInt8] {
        [0x01, 0x03, pattern.rawValue]
    }

    /// `00 08 00 <left> <right> 00 00 00`, the Xbox 360 rumble packet.
    public static func rumble(left: UInt8, right: UInt8) -> [UInt8] {
        [0x00, 0x08, 0x00, left, right, 0x00, 0x00, 0x00]
    }
}
