import XCTest

@testable import NaconCore

/// S10: the rumble packet is built from a clamped intensity, in the layout the pad documents.
///
/// The motors are the one output that keeps acting after the packet is sent, so the value that
/// reaches them must be impossible to malform: any stored or dragged number ends up inside 0...1
/// before it becomes a byte.
final class PadRumbleTests: XCTestCase {
    func testSilenceIsTheStopPacket() {
        let rumble = PadRumble(intensity: 0)

        XCTAssertTrue(rumble.isSilent)
        XCTAssertEqual(rumble.packet, PadRumble.stopPacket)
    }

    func testHalfIntensityUsesHalfOfBothMotorRanges() {
        let packet = PadRumble(intensity: 0.5).packet

        XCTAssertEqual(packet[3], 128)
        XCTAssertEqual(packet[4], 128)
    }

    func testFullIntensityDrivesBothMotorsToTheMaximum() {
        let packet = PadRumble(intensity: 1).packet

        XCTAssertEqual(packet[3], 255)
        XCTAssertEqual(packet[4], 255)
    }

    func testIntensityOutsideTheRangeClamps() {
        XCTAssertEqual(PadRumble(intensity: -3).intensity, 0)
        XCTAssertEqual(PadRumble(intensity: 5).intensity, 1)
        XCTAssertEqual(PadRumble(intensity: .nan).intensity, 0, "a NaN must never reach a byte")
    }

    func testTheLayoutAlwaysKeepsTheCommandHeaderAndTheTrailingZeros() {
        for intensity in [0.0, 0.3, 0.999, 1.0] {
            let packet = PadRumble(intensity: intensity).packet

            XCTAssertEqual(packet.count, XInputOutputReport.rumblePacketLength, "\(intensity)")
            XCTAssertEqual(Array(packet.prefix(3)), [0x00, 0x08, 0x00], "\(intensity)")
            XCTAssertEqual(Array(packet.suffix(3)), [0x00, 0x00, 0x00], "\(intensity)")
        }
    }

    func testTheStopPacketSilencesBothMotors() {
        let packet = PadRumble.stopPacket

        XCTAssertEqual(packet.count, XInputOutputReport.rumblePacketLength)
        XCTAssertEqual(packet[3], 0)
        XCTAssertEqual(packet[4], 0)
    }

    func testAnIntensityIsNeverNegativeAfterMutation() {
        var rumble = PadRumble(intensity: 0.4)
        rumble.intensity = -9

        XCTAssertEqual(rumble.intensity, 0)
        XCTAssertEqual(rumble.packet, PadRumble.stopPacket)
    }
}
