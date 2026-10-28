import CoreGraphics
import XCTest

@testable import NaconCore

/// A key event carries its own flags and the receiving side reads those, not the state behind them.
/// Posting ⇥ with no flags while ⌘ is held on another control is a plain Tab, which is why combining
/// a modifier hold with a key did nothing.
final class InputEmitterFlagsTests: XCTestCase {
    private let tabStroke = KeyStroke(keyCode: 48, isDown: true, modifiers: [])

    func testAStrokeCarriesTheModifiersAlreadyHeld() {
        XCTAssertEqual(CGEventEmitter.strokeFlags(for: tabStroke, ambient: [.command]), .maskCommand)
        XCTAssertEqual(
            CGEventEmitter.strokeFlags(for: tabStroke, ambient: [.command, .shift]),
            [.maskCommand, .maskShift]
        )
    }

    func testAStrokeWithNoModifiersAndNothingHeldCarriesNone() {
        XCTAssertEqual(CGEventEmitter.strokeFlags(for: tabStroke, ambient: []), [])
    }

    func testTheStrokesOwnModifiersSurviveTheMerge() {
        // A mapped ⌘⇥ pressed while the pad also holds ⇧ must arrive as ⇧⌘⇥, like on a keyboard.
        let own = KeyStroke(keyCode: 48, isDown: true, modifiers: [.command])
        XCTAssertEqual(
            CGEventEmitter.strokeFlags(for: own, ambient: [.shift]),
            [.maskCommand, .maskShift]
        )
    }

    func testTheEventFlagsAreReadBackIntoTheModelSet() {
        XCTAssertEqual(
            CGEventEmitter.modifiers(from: [.maskCommand, .maskAlternate, .maskControl, .maskShift, .maskSecondaryFn]),
            [.command, .option, .control, .shift, .function]
        )
        XCTAssertEqual(CGEventEmitter.modifiers(from: []), [])
    }

    func testCapsLockAndTheNumericPadAreNeverForwarded() {
        // The inherited NumericPad flag made applications drop the event; an event that says nothing
        // about the modifiers the user is holding is the honest one.
        XCTAssertEqual(CGEventEmitter.modifiers(from: [.maskAlphaShift, .maskNumericPad]), [])
        XCTAssertEqual(CGEventEmitter.modifiers(from: [.maskAlphaShift, .maskCommand]), [.command])
    }
}
