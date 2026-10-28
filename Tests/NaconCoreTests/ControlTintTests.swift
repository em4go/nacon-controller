import XCTest

@testable import NaconCore

/// S14: the colours the drawing can tint a control with.
///
/// The d-pad directions have one because four similar petals inside one circle are hard to tell apart,
/// and the face buttons because PlayStation gives them one. Everything else keeps the app's accent,
/// which is why the model answers `nil` for them instead of hard-coding a colour that would stop
/// following the system accent.
///
/// These are value tests about the palette itself. *Which* controls own a colour is
/// `ControlFactsTests`' business, so this suite does not list them: it checks every tint the app can
/// possibly show.
final class ControlTintTests: XCTestCase {
    /// Every tint the facts hand out, in a stable order.
    private var tints: [ControlTint] {
        XInputControl.allCases.compactMap { ControlFacts.of($0).tint }
    }

    func testEveryColourIsAValidRGBValue() {
        XCTAssertFalse(tints.isEmpty, "there has to be a palette to check")

        for tint in tints {
            for channel in [tint.red, tint.green, tint.blue] {
                XCTAssertTrue((0...1).contains(channel), "\(tint.packed) channel out of range")
            }
        }
    }

    func testTheDirectionsAreEasyToTellApart() {
        // A quick sanity check that the palette was not filled with four neighbouring blues: at least
        // one channel must differ by a noticeable amount between any two colours.
        let palette = tints
        for (index, first) in palette.enumerated() {
            for second in palette[(index + 1)...] {
                let distance = abs(first.red - second.red)
                    + abs(first.green - second.green)
                    + abs(first.blue - second.blue)
                XCTAssertGreaterThan(distance, 0.35, "\(first.packed) and \(second.packed) look alike")
            }
        }
    }

    func testAPackedValueIsSixHexDigits() {
        for tint in tints {
            XCTAssertEqual(tint.packed.count, 7, "\(tint.packed) is not #RRGGBB")
            XCTAssertTrue(tint.packed.hasPrefix("#"))
        }
    }
}
