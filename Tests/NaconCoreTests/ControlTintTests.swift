import XCTest

@testable import NaconCore

/// S14: the four d-pad directions are tinted with colours of their own.
///
/// They are four similar petals inside one circle, so a single accent made it hard to tell which one
/// the pointer was on. Every other control keeps the app's accent, which is why the model answers with
/// `nil` for them instead of hard-coding a colour that would stop following the system accent.
final class ControlTintTests: XCTestCase {
    func testTheModelOnlyColoursTheDpad() {
        for control in XInputControl.allCases {
            let isDpad = [.dpadUp, .dpadDown, .dpadLeft, .dpadRight].contains(control)
            XCTAssertEqual(
                ControlTint.color(for: control) != nil,
                isDpad,
                "\(control) should \(isDpad ? "" : "not ")carry its own colour"
            )
        }
    }

    func testTheFourDirectionsUseFourDistinctColours() {
        let colours = [XInputControl.dpadUp, .dpadDown, .dpadLeft, .dpadRight]
            .compactMap { ControlTint.color(for: $0) }

        XCTAssertEqual(colours.count, 4)
        XCTAssertEqual(Set(colours.map(\.packed)).count, 4, "two directions share a colour")
    }

    func testEveryColourIsAValidRGBValue() {
        for control in [XInputControl.dpadUp, .dpadDown, .dpadLeft, .dpadRight] {
            guard let tint = ControlTint.color(for: control) else {
                return XCTFail("\(control) has no colour")
            }
            for channel in [tint.red, tint.green, tint.blue] {
                XCTAssertTrue((0...1).contains(channel), "\(control) channel out of range")
            }
        }
    }

    func testTheDirectionsAreEasyToTellApart() {
        // A quick sanity check that the palette was not filled with four neighbouring blues: at least
        // one channel must differ by a noticeable amount between any two directions.
        let colours = [XInputControl.dpadUp, .dpadDown, .dpadLeft, .dpadRight]
            .compactMap { ControlTint.color(for: $0) }
        for (index, first) in colours.enumerated() {
            for second in colours[(index + 1)...] {
                let distance = abs(first.red - second.red)
                    + abs(first.green - second.green)
                    + abs(first.blue - second.blue)
                XCTAssertGreaterThan(distance, 0.35, "\(first.packed) and \(second.packed) look alike")
            }
        }
    }
}
