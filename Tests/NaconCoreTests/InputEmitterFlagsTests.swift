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

    func testAModifiersOwnReleaseNeverClaimsItIsStillHeld() {
        // The system does report Command as held at the instant its key-up is posted. An event that
        // repeats that leaves the switcher on screen after the button was let go.
        let commandUp = KeyStroke(keyCode: 55, isDown: false, modifiers: [])
        XCTAssertEqual(
            CGEventEmitter.resolvedModifiers(for: commandUp, ambient: [.command], held: [.command]),
            []
        )
    }

    func testAModifierPressAndItsReleaseEndWithNothingHeld() {
        let commandDown = KeyStroke(keyCode: 55, isDown: true, modifiers: [.command])
        XCTAssertEqual(
            CGEventEmitter.strokeFlags(for: commandDown, ambient: []),
            .maskCommand
        )
        let commandUp = KeyStroke(keyCode: 55, isDown: false, modifiers: [])
        XCTAssertEqual(CGEventEmitter.strokeFlags(for: commandUp, ambient: []), [])
    }

    func testWhatThisAppHoldsCountsEvenBeforeTheSystemReportsIt() {
        // ⌘ held on one control and ⇥ pressed on another: the next stroke must combine without
        // depending on the race with the system's own report.
        XCTAssertEqual(
            CGEventEmitter.strokeFlags(for: tabStroke, ambient: [], held: [.command]),
            .maskCommand
        )
    }

    func testAnOrdinaryKeyReleaseKeepsTheModifiersHeld() {
        let tabUp = KeyStroke(keyCode: 48, isDown: false, modifiers: [])
        XCTAssertEqual(
            CGEventEmitter.strokeFlags(for: tabUp, ambient: [.command], held: [.command]),
            .maskCommand
        )
    }
}
