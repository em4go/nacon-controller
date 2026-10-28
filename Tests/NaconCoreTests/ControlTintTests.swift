import XCTest

@testable import NaconCore

/// S14: the controls that have a colour of their own keep it.
///
/// The d-pad because four similar petals inside one circle are hard to tell apart, and the face
/// buttons because PlayStation gives them one. Everything else keeps the app's accent, which is why
/// the model answers `nil` for them instead of hard-coding a colour that would stop following the
/// system accent.
final class ControlTintTests: XCTestCase {
    private let coloured: [XInputControl] = [
        .dpadUp, .dpadDown, .dpadLeft, .dpadRight,
        .buttonA, .buttonB, .buttonX, .buttonY,
    ]

    func testOnlyTheControlsWithAColourOfTheirOwnAreColoured() {
        for control in XInputControl.allCases {
            let expected = coloured.contains(control)
            XCTAssertEqual(
                ControlTint.color(for: control) != nil,
                expected,
                "\(control) should \(expected ? "" : "not ")carry its own colour"
            )
        }
    }

    func testTheFourDirectionsUseFourDistinctColours() {
        let colours = coloured.compactMap { ControlTint.color(for: $0) }

        XCTAssertEqual(colours.count, coloured.count)
        XCTAssertEqual(Set(colours.map(\.packed)).count, colours.count, "two controls share a colour")
    }

    func testEveryColourIsAValidRGBValue() {
        for control in coloured {
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
        let colours = coloured.compactMap { ControlTint.color(for: $0) }
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
