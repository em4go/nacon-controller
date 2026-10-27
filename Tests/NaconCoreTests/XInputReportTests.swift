import XCTest

@testable import NaconCore

final class XInputReportTests: XCTestCase {
    private func packet(
        byte2: UInt8 = 0,
        byte3: UInt8 = 0,
        leftTrigger: UInt8 = 0,
        rightTrigger: UInt8 = 0,
        leftX: Int16 = 0,
        leftY: Int16 = 0,
        rightX: Int16 = 0,
        rightY: Int16 = 0
    ) -> [UInt8] {
        func halves(_ value: Int16) -> (low: UInt8, high: UInt8) {
            let bits = UInt16(bitPattern: value)
            return (UInt8(bits & 0xFF), UInt8(bits >> 8))
        }
        var bytes: [UInt8] = [0x00, 0x14, byte2, byte3, leftTrigger, rightTrigger]
        let lx = halves(leftX)
        let ly = halves(leftY)
        let rx = halves(rightX)
        let ry = halves(rightY)
        bytes += [lx.low, lx.high, ly.low, ly.high, rx.low, rx.high, ry.low, ry.high]
        bytes += [UInt8](repeating: 0, count: XInputReport.expectedLength - bytes.count)
        return bytes
    }

    func testDecodesIdlePacketAsNeutral() throws {
        let report = try XCTUnwrap(XInputReport.decode(packet()))
        XCTAssertTrue(report.buttons.isEmpty)
        XCTAssertEqual(report.leftTrigger, 0)
        XCTAssertEqual(report.rightTrigger, 0)
        XCTAssertEqual(report.leftStick, .center)
        XCTAssertEqual(report.rightStick, .center)
        XCTAssertEqual(report.rawBytes.count, XInputReport.expectedLength)
    }

    func testRejectsPacketsThatAreNotInputReports() {
        // The pad sends status packets on the same endpoint; these must not decode as input.
        XCTAssertNil(XInputReport.decode([0x01, 0x03, 0x0e]))
        XCTAssertNil(XInputReport.decode([0x08, 0x03, 0x00]))
    }

    func testRejectsTruncatedPacket() {
        let truncated = Array(packet().prefix(XInputReport.minimumLength - 1))
        XCTAssertNil(XInputReport.decode(truncated))
    }

    func testRejectsPacketWithWrongLengthMarker() {
        var bytes = packet()
        bytes[1] = 0x03
        XCTAssertNil(XInputReport.decode(bytes))
    }

    func testDecodesFaceButtons() throws {
        for (bit, expected) in [(UInt8(0x10), XInputButtons.buttonA),
                                (UInt8(0x20), .buttonB),
                                (UInt8(0x40), .buttonX),
                                (UInt8(0x80), .buttonY)] {
            let report = try XCTUnwrap(XInputReport.decode(packet(byte3: bit)))
            XCTAssertTrue(report.buttons.contains(expected))
        }
    }

    func testDecodesDpadAndThumbClicks() throws {
        for (bit, expected) in [(UInt8(0x01), XInputButtons.dpadUp),
                                (UInt8(0x02), .dpadDown),
                                (UInt8(0x04), .dpadLeft),
                                (UInt8(0x08), .dpadRight),
                                (UInt8(0x10), .start),
                                (UInt8(0x20), .back),
                                (UInt8(0x40), .leftThumb),
                                (UInt8(0x80), .rightThumb)] {
            let report = try XCTUnwrap(XInputReport.decode(packet(byte2: bit)))
            XCTAssertTrue(report.buttons.contains(expected))
        }
    }

    func testDecodesBumpersAndGuide() throws {
        for (bit, expected) in [(UInt8(0x01), XInputButtons.leftBumper),
                                (UInt8(0x02), .rightBumper),
                                (UInt8(0x04), .guide)] {
            let report = try XCTUnwrap(XInputReport.decode(packet(byte3: bit)))
            XCTAssertTrue(report.buttons.contains(expected))
        }
    }

    func testDecodesTriggers() throws {
        let report = try XCTUnwrap(XInputReport.decode(packet(leftTrigger: 255, rightTrigger: 128)))
        XCTAssertEqual(report.leftTrigger, 255)
        XCTAssertEqual(report.rightTrigger, 128)
        XCTAssertEqual(report.leftTriggerNormalized, 1.0, accuracy: 0.0001)
        XCTAssertEqual(report.rightTriggerNormalized, 128.0 / 255.0, accuracy: 0.0001)
    }

    func testDecodesStickExtremes() throws {
        let report = try XCTUnwrap(XInputReport.decode(packet(
            leftX: 32_767,
            leftY: -32_768,
            rightX: -32_768,
            rightY: 32_767
        )))
        XCTAssertEqual(report.leftStick.rawX, 32_767)
        XCTAssertEqual(report.leftStick.rawY, -32_768)
        XCTAssertEqual(report.rightStick.rawX, -32_768)
        XCTAssertEqual(report.rightStick.rawY, 32_767)
        XCTAssertEqual(report.leftStick.normalizedX, 1.0, accuracy: 0.0001)
        XCTAssertEqual(report.rightStick.normalizedX, -1.0, accuracy: 0.0001)
    }

    func testVerticalAxisIsInvertedForDisplay() throws {
        let up = try XCTUnwrap(XInputReport.decode(packet(leftY: -32_768)))
        let down = try XCTUnwrap(XInputReport.decode(packet(leftY: 32_767)))
        XCTAssertEqual(up.leftStick.normalizedY, 1.0, accuracy: 0.0001)
        XCTAssertEqual(down.leftStick.normalizedY, -1.0, accuracy: 0.0001)
    }

    func testTriggerPressUsesThreshold() throws {
        let threshold = XInputControl.triggerPressedThreshold
        let below = try XCTUnwrap(XInputReport.decode(packet(leftTrigger: threshold)))
        let above = try XCTUnwrap(XInputReport.decode(packet(leftTrigger: threshold + 1)))
        XCTAssertFalse(XInputControl.leftTrigger.isPressed(in: below))
        XCTAssertTrue(XInputControl.leftTrigger.isPressed(in: above))
    }

    func testEveryControlMapsToADistinctButtonBit() {
        let digital = XInputControl.allCases.filter { !$0.mask.isEmpty }
        XCTAssertEqual(Set(digital.map(\.mask)).count, digital.count)
        XCTAssertEqual(XInputControl.allCases.count, 17)
    }
}
