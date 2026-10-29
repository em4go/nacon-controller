import XCTest

@testable import NaconCore

/// S9: the cursor settings a profile stores are editable, clamped, and isolated per profile.
///
/// Before this, only the vertical axis was reachable from the app, so the model allowed two profiles
/// to differ in speed while the UI made it impossible. The clamping rule matters beyond the sliders:
/// a hand-edited file can carry any number, and a value that reached the engine as 0 pt/s would look
/// exactly like a frozen cursor.
final class CursorSensitivityTests: XCTestCase {
    private func libraryWithTwoProfiles() -> ProfileLibrary {
        let first = StoredProfile(
            name: "Diseño",
            profile: InputProfile(mappings: [.buttonA: .mouseButton(.left)])
        )
        let second = StoredProfile(name: "Juego", profile: .standard)
        return ProfileLibrary(profiles: [first, second], selectedProfileID: first.id)
    }

    func testEverySensitivityClampsBothEnds() {
        for sensitivity in CursorSensitivity.allCases {
            var low = libraryWithTwoProfiles()
            XCTAssertTrue(low.setCursorSensitivity(sensitivity, to: -1_000), "\(sensitivity)")
            XCTAssertEqual(low.selectedValue(for: sensitivity), sensitivity.range.lowerBound, "\(sensitivity)")

            var high = libraryWithTwoProfiles()
            XCTAssertTrue(high.setCursorSensitivity(sensitivity, to: 1_000_000), "\(sensitivity)")
            XCTAssertEqual(high.selectedValue(for: sensitivity), sensitivity.range.upperBound, "\(sensitivity)")
        }
    }

    func testEditingTheSelectedProfileLeavesTheSiblingUntouched() {
        var library = libraryWithTwoProfiles()

        XCTAssertTrue(library.setCursorSensitivity(.maxSpeed, to: 600))

        XCTAssertEqual(library.profiles[0].profile.cursor.maxSpeed, 600)
        XCTAssertEqual(library.profiles[1].profile.cursor.maxSpeed, InputProfile.standard.cursor.maxSpeed)
    }

    func testWritingTheValueAlreadyStoredReportsNoChange() {
        var library = libraryWithTwoProfiles()
        let current = library.selectedValue(for: .maxSpeed)

        XCTAssertNotNil(current)
        XCTAssertFalse(library.setCursorSensitivity(.maxSpeed, to: current ?? 0))
    }

    func testResetReportsNoChangeWhenAlreadyStandard() {
        var library = libraryWithTwoProfiles()

        // Nothing to restore: the library must say so instead of reporting a write that did not happen.
        XCTAssertFalse(library.resetCursorSensitivity())
    }

    func testResetRestoresTheStandardValuesForTheSelectedProfileOnly() {
        var library = libraryWithTwoProfiles()
        XCTAssertTrue(library.setCursorSensitivity(.maxSpeed, to: 400))
        XCTAssertTrue(library.setCursorSensitivity(.curve, to: 3.5))

        XCTAssertTrue(library.resetCursorSensitivity())

        XCTAssertEqual(library.selectedValue(for: .maxSpeed), InputProfile.standard.cursor.maxSpeed)
        XCTAssertEqual(library.selectedValue(for: .curve), InputProfile.standard.cursor.curveExponent)
    }

    func testResetKeepsTheVerticalAxisCalibration() {
        // The axis direction is a property of the unit, not a preference, so a reset must not undo it.
        var library = libraryWithTwoProfiles()
        XCTAssertTrue(library.setInvertVerticalAxis(true))
        XCTAssertTrue(library.setCursorSensitivity(.maxSpeed, to: 400))

        XCTAssertTrue(library.resetCursorSensitivity())

        XCTAssertTrue(library.selectedInvertVerticalAxis)
        XCTAssertEqual(library.selectedValue(for: .maxSpeed), InputProfile.standard.cursor.maxSpeed)
    }

    func testMutatorsReportFailureWithoutASelection() {
        var library = ProfileLibrary(profiles: [], selectedProfileID: nil)

        XCTAssertNil(library.selectedValue(for: .maxSpeed))
        XCTAssertFalse(library.setCursorSensitivity(.maxSpeed, to: 500))
        XCTAssertFalse(library.resetCursorSensitivity())
    }

    func testFormattingCarriesTheUnit() {
        // The formatter is what the slider shows next to the thumb; a bare number would not say
        // whether 1400 means points per second or something else.
        XCTAssertTrue(CursorSensitivity.maxSpeed.formatted(1_400).contains("pt/s"))
        XCTAssertTrue(CursorSensitivity.scrollSpeed.formatted(14, locale: Locale(identifier: "es")).contains("líneas/s"))
        XCTAssertTrue(CursorSensitivity.curve.formatted(2).contains("×"))
        XCTAssertTrue(CursorSensitivity.deadzone.formatted(0.18).contains("18"))
    }

    func testEverySensitivityHasASpanishLabel() {
        for sensitivity in CursorSensitivity.allCases {
            XCTAssertFalse(sensitivity.label.isEmpty, "\(sensitivity)")
            XCTAssertFalse(sensitivity.detail.isEmpty, "\(sensitivity)")
        }
    }
}
