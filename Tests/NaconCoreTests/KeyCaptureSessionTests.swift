import XCTest

@testable import NaconCore

/// S3, F5: the key-capture state machine behind the mapping editor.
///
/// The editor needs a window and an `NSEvent` monitor to read a real press, but every decision it
/// takes while a capture is armed -- whether arming is safe, what a press means, which profile the
/// result belongs to, and when the capture ends -- lives in `KeyCaptureSession`, so it can be
/// checked here without SwiftUI, AppKit or an event loop.
final class KeyCaptureSessionTests: XCTestCase {
    private let profileA = UUID()
    private let profileB = UUID()

    // MARK: - Arming

    func testArmingWhileEmulationRunsIsRefused() {
        var session = KeyCaptureSession()

        let result = session.arm(.buttonA, for: profileA, isEmulationRunning: true)

        XCTAssertEqual(result, .refusedWhileEmulating)
        XCTAssertFalse(session.isArmed)
        XCTAssertNil(session.armedControl)
        XCTAssertNil(session.armedProfileID)
    }

    func testRefusedArmingLeavesALaterKeyPressWithoutEffect() {
        var session = KeyCaptureSession()
        session.arm(.buttonA, for: profileA, isEmulationRunning: true)

        let outcome = session.handleKey(keyCode: 12, modifiers: [.command])

        XCTAssertEqual(outcome, .ignored, "a refused arming must not start swallowing key presses")
        XCTAssertFalse(session.isArmed)
    }

    func testArmingWhileEmulationIsStoppedSucceeds() {
        var session = KeyCaptureSession()

        XCTAssertEqual(session.arm(.buttonA, for: profileA, isEmulationRunning: false), .armed)
        XCTAssertTrue(session.isArmed)
        XCTAssertEqual(session.armedControl, .buttonA)
        XCTAssertEqual(session.armedProfileID, profileA)
        XCTAssertTrue(session.isArmed(.buttonA))
        XCTAssertFalse(session.isArmed(.buttonB))
    }

    func testArmingAnotherControlReplacesTheArmedOne() {
        var session = KeyCaptureSession()
        session.arm(.buttonA, for: profileA, isEmulationRunning: false)

        session.arm(.buttonB, for: profileA, isEmulationRunning: false)

        XCTAssertEqual(session.armedControl, .buttonB)
    }

    func testToggleDisarmsTheControlItJustArmed() {
        var session = KeyCaptureSession()
        session.arm(.buttonA, for: profileA, isEmulationRunning: false)

        XCTAssertEqual(session.toggle(.buttonA, for: profileA, isEmulationRunning: false), .disarmed)
        XCTAssertFalse(session.isArmed, "pressing «Capturar» again has to end the capture")
    }

    func testToggleRefusesToArmWhileEmulationRuns() {
        var session = KeyCaptureSession()

        XCTAssertEqual(
            session.toggle(.buttonA, for: profileA, isEmulationRunning: true),
            .refusedWhileEmulating
        )
        XCTAssertFalse(session.isArmed)
    }

    // MARK: - The arming intent (S2, S3)

    func testArmingRemembersTheIntent() {
        var session = KeyCaptureSession()

        session.arm(.buttonA, for: profileA, intent: .modCommand, isEmulationRunning: false)

        XCTAssertEqual(session.intent, .modCommand)
    }

    func testDefaultArmingIsTheBaseColumn() {
        var session = KeyCaptureSession()

        session.arm(.buttonA, for: profileA, isEmulationRunning: false)

        XCTAssertEqual(session.intent, .base, "a capture that says nothing writes to the base")
    }

    func testTheCaptureButtonCancelsACommandCaptureWhateverItsMode() {
        var session = KeyCaptureSession()
        session.arm(.buttonA, for: profileA, intent: .baseCommand, isEmulationRunning: false)

        // The button reads «Cancelar» as soon as the control is armed, so pressing it has to cancel.
        let result = session.toggle(
            .buttonA,
            for: profileA,
            intent: .base,
            isEmulationRunning: false
        )

        XCTAssertEqual(result, .disarmed, "a button labelled «Cancelar» must always cancel")
        XCTAssertFalse(session.isArmed)
        XCTAssertNil(session.intent)
    }

    func testArmingWithADifferentIntentReplacesTheArmedCaptureWithoutCancelling() {
        var session = KeyCaptureSession()
        session.arm(.buttonA, for: profileA, intent: .baseCommand, isEmulationRunning: false)

        // A menu pick names a destination; it is never a request to cancel.
        let result = session.arm(.buttonA, for: profileA, intent: .mod, isEmulationRunning: false)

        XCTAssertEqual(result, .armed)
        XCTAssertTrue(session.isArmed(.buttonA))
        XCTAssertEqual(session.intent, .mod)
    }

    func testDisarmClearsTheIntent() {
        var session = KeyCaptureSession()
        session.arm(.buttonA, for: profileA, intent: .modCommand, isEmulationRunning: false)

        session.disarm()

        XCTAssertNil(session.intent, "a finished capture must not leave a destination behind")
    }

    // MARK: - Presses with nothing armed

    func testKeyPressWithoutArmingChangesNothing() {
        var session = KeyCaptureSession()
        let before = session

        let outcome = session.handleKey(keyCode: 12, modifiers: [.command, .shift])

        XCTAssertEqual(outcome, .ignored)
        XCTAssertEqual(session, before, "an unarmed capture must not react to key presses")
    }

    func testKeyPressAfterAnExplicitDisarmChangesNothing() {
        var session = KeyCaptureSession()
        session.arm(.buttonA, for: profileA, isEmulationRunning: false)
        session.disarm()

        XCTAssertFalse(session.isArmed)
        XCTAssertEqual(session.handleKey(keyCode: 12, modifiers: []), .ignored)
        XCTAssertFalse(session.isArmed, "a disarmed capture must not re-arm itself")
    }

    // MARK: - Cancelling

    func testPlainEscapeCancelsTheCapture() {
        var session = KeyCaptureSession()
        session.arm(.buttonA, for: profileA, isEmulationRunning: false)

        let outcome = session.handleKey(keyCode: VirtualKey.escape.rawValue, modifiers: [])

        XCTAssertEqual(outcome, .cancelled(.buttonA))
        XCTAssertFalse(session.isArmed, "a cancelled capture ends too")
    }

    func testCancellingLeavesThePreviousMappingUntouched() {
        var profile = InputProfile.standard
        var session = KeyCaptureSession()
        session.arm(.buttonA, for: profileA, isEmulationRunning: false)

        let outcome = session.handleKey(keyCode: VirtualKey.escape.rawValue, modifiers: [])

        guard case .cancelled = outcome else {
            return XCTFail("plain Escape has to cancel the capture")
        }
        apply(outcome, to: &profile, selected: profileA)
        XCTAssertEqual(profile, .standard, "a cancelled capture must not write anything")
    }

    func testEscapeWithAModifierIsMappable() {
        var session = KeyCaptureSession()
        session.arm(.buttonA, for: profileA, isEmulationRunning: false)

        let outcome = session.handleKey(keyCode: VirtualKey.escape.rawValue, modifiers: [.shift])

        XCTAssertEqual(
            outcome,
            .mapped(
                profileID: profileA,
                control: .buttonA,
                action: .key(KeyCombo(keyCode: 53, modifiers: [.shift])),
                intent: .base
            )
        )
    }

    // MARK: - Mapping

    func testAnyOtherKeyMapsToAKeyAction() {
        var session = KeyCaptureSession()
        session.arm(.buttonA, for: profileA, isEmulationRunning: false)

        let outcome = session.handleKey(keyCode: 12, modifiers: [])

        XCTAssertEqual(
            outcome,
            .mapped(
                profileID: profileA,
                control: .buttonA,
                action: .key(KeyCombo(keyCode: 12)),
                intent: .base
            )
        )
    }

    func testMappedOutcomeCarriesTheArmingIntent() {
        var session = KeyCaptureSession()
        session.arm(.buttonA, for: profileA, intent: .modCommand, isEmulationRunning: false)

        let outcome = session.handleKey(keyCode: 12, modifiers: [])

        XCTAssertEqual(
            outcome,
            .mapped(
                profileID: profileA,
                control: .buttonA,
                action: .key(KeyCombo(keyCode: 12)),
                intent: .modCommand
            ),
            "the press has to come back with the column and mode it was armed with"
        )
    }

    func testTheIntentSurvivesTheDisarmThatEndsTheCapture() {
        var session = KeyCaptureSession()
        session.arm(.buttonA, for: profileA, intent: .mod, isEmulationRunning: false)

        let outcome = session.handleKey(keyCode: 12, modifiers: [])

        guard case let .mapped(_, _, _, intent) = outcome else {
            return XCTFail("a key press has to become a mapping")
        }
        XCTAssertEqual(intent, .mod)
        XCTAssertNil(session.intent, "the session let go of the intent; the outcome kept it")
    }

    func testModifiersSurviveIntoTheMappedAction() {
        var session = KeyCaptureSession()
        session.arm(.start, for: profileA, isEmulationRunning: false)

        guard case let .mapped(_, control, action, _) = session.handleKey(
            keyCode: 12,
            modifiers: [.command, .option]
        ) else {
            return XCTFail("a key press has to become a key action")
        }

        XCTAssertEqual(control, .start)
        XCTAssertEqual(action, .key(KeyCombo(keyCode: 12, modifiers: [.command, .option])))
    }

    func testMappedOutcomeCarriesTheProfileTheCaptureWasArmedFor() {
        var session = KeyCaptureSession()
        // The user arms a capture while profile A is selected...
        session.arm(.buttonA, for: profileA, isEmulationRunning: false)
        // ...and the selection moves to profile B before the key arrives.
        let selectedNow = profileB

        let outcome = session.handleKey(keyCode: 12, modifiers: [])

        guard case let .mapped(armedProfileID, _, _, _) = outcome else {
            return XCTFail("a key press has to become a mapping")
        }
        XCTAssertEqual(armedProfileID, profileA)
        XCTAssertNotEqual(
            armedProfileID,
            selectedNow,
            "the caller must be able to tell that the selection moved"
        )
    }

    func testAStaleCaptureCannotWriteToTheNewlySelectedProfile() {
        var armedProfile = InputProfile.standard
        var newlySelected = InputProfile.standard
        var session = KeyCaptureSession()
        session.arm(.buttonA, for: profileA, isEmulationRunning: false)
        let outcome = session.handleKey(keyCode: 12, modifiers: [])

        // The selection moved to profile B before the press landed: the write is dropped.
        apply(outcome, to: &newlySelected, selected: profileB)
        // The same outcome does write to the profile it was armed for, so the guard is what saved B.
        apply(outcome, to: &armedProfile, selected: profileA)

        XCTAssertEqual(newlySelected, .standard, "the press was armed for another profile")
        XCTAssertEqual(
            armedProfile.action(for: .buttonA),
            .key(KeyCombo(keyCode: 12)),
            "the outcome has to be applicable to the profile it was armed for"
        )
    }

    func testMappedCaptureDisarmsItself() {
        var session = KeyCaptureSession()
        session.arm(.buttonA, for: profileA, isEmulationRunning: false)

        let first = session.handleKey(keyCode: 12, modifiers: [])

        XCTAssertNotEqual(first, .ignored, "the armed control has to consume the press")
        XCTAssertFalse(session.isArmed)
        XCTAssertNil(session.armedControl)
        XCTAssertNil(session.armedProfileID)
        XCTAssertEqual(session.handleKey(keyCode: 13, modifiers: []), .ignored)
    }

    // MARK: - Helpers

    /// The write the editor performs: only a mapping armed for the profile still on screen lands.
    private func apply(
        _ outcome: KeyCaptureSession.Outcome,
        to profile: inout InputProfile,
        selected: UUID?
    ) {
        guard case let .mapped(armedProfileID, control, action, _) = outcome else { return }
        guard selected == nil || armedProfileID == selected else { return }
        profile.setAction(action, for: control)
    }
}
