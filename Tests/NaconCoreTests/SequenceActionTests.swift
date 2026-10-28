import XCTest
@testable import NaconCore

/// Custom commands: several strokes chained into one action, stored in a profile.
final class SequenceActionTests: XCTestCase {
    private var selectAll: KeyCombo { KeyCombo(keyCode: 0, modifiers: [.command]) }
    private var copy: KeyCombo { KeyCombo(keyCode: 8, modifiers: [.command]) }

    func testASequenceShowsItsStepsInOrder() {
        XCTAssertEqual(
            MappingRules.label(for: .sequence([selectAll, copy])),
            "⌘A luego ⌘C"
        )
    }

    func testChainingNormalisesWhatIsNotASequence() {
        // One stroke is not a chain and no strokes are nothing: the editor and the decoder both come
        // through here, so a degenerate sequence cannot reach a profile.
        XCTAssertEqual(MappedAction.chained([]), .none)
        XCTAssertEqual(MappedAction.chained([copy]), .key(copy))
        XCTAssertEqual(MappedAction.chained([selectAll, copy]), .sequence([selectAll, copy]))
    }

    func testASequenceSurvivesAProfileRoundTrip() throws {
        let profile = InputProfile(
            mappings: [
                .buttonA: .sequence([selectAll, copy]),
                .buttonB: .key(KeyCombo(.escape)),
            ]
        )

        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(InputProfile.self, from: data)

        XCTAssertEqual(decoded.action(for: .buttonA), .sequence([selectAll, copy]))
        XCTAssertEqual(decoded.action(for: .buttonB), .key(KeyCombo(.escape)))
    }

    func testAStoredSingleStepIsReadAsAPlainKey() throws {
        let json = """
        {"mappings":{"buttonA":{"kind":"sequence","steps":[{"keyCode":8,"modifiers":1}]}}}
        """
        let profile = try JSONDecoder().decode(InputProfile.self, from: Data(json.utf8))

        XCTAssertEqual(profile.action(for: .buttonA), .key(KeyCombo(keyCode: 8, modifiers: [.command])))
    }

    func testUnreadableStepsLeaveTheActionEmptyAndTheRestIntact() throws {
        // One bad entry must not cost the user every other assignment in the file.
        let json = """
        {"mappings":{"buttonA":{"kind":"sequence","steps":"no es una lista"},\
        "buttonB":{"kind":"key","key":{"keyCode":36,"modifiers":0}}}}
        """
        let profile = try JSONDecoder().decode(InputProfile.self, from: Data(json.utf8))

        XCTAssertEqual(profile.action(for: .buttonA), .none)
        XCTAssertEqual(profile.action(for: .buttonB), .key(KeyCombo(keyCode: 36)))
    }

    func testAppendingAStepBuildsTheChainInOrder() {
        // How the editor builds a command: capture the first key, then arm the capture once per step.
        // Nothing to chain: an unassigned control starts with a capture, not with a one-step command.
        XCTAssertEqual(MappingRules.appending(step: copy, to: .none), .none)
        XCTAssertEqual(MappingRules.appending(step: copy, to: .key(selectAll)), .sequence([selectAll, copy]))
        XCTAssertEqual(
            MappingRules.appending(step: copy, to: .sequence([selectAll, copy])),
            .sequence([selectAll, copy, copy]),
            "a new step goes to the end and keeps what was there"
        )
    }

    func testOnlyAKeyCanTakeAStep() {
        XCTAssertTrue(MappingRules.canAppendStep(to: .key(copy)))
        XCTAssertTrue(MappingRules.canAppendStep(to: .sequence([selectAll, copy])))
        XCTAssertFalse(MappingRules.canAppendStep(to: .mouseButton(.left)))
        XCTAssertFalse(MappingRules.canAppendStep(to: .scrollLines(3)))
        XCTAssertFalse(MappingRules.canAppendStep(to: .none))

        // And a control that sends a click is not silently turned into a keystroke by appending to it.
        XCTAssertEqual(MappingRules.appending(step: copy, to: .mouseButton(.left)), .mouseButton(.left))
    }

    func testDroppingTheLastStepShortensTheCommand() {
        XCTAssertEqual(MappingRules.droppingLastStep(from: .sequence([selectAll, copy])), .key(selectAll))
        XCTAssertEqual(
            MappingRules.droppingLastStep(from: .sequence([selectAll, copy, copy])),
            .sequence([selectAll, copy])
        )
        // An action that is not a chain is left alone, so the entry cannot erase a mapping by surprise.
        XCTAssertEqual(MappingRules.droppingLastStep(from: .key(copy)), .key(copy))
        XCTAssertEqual(MappingRules.droppingLastStep(from: .none), .none)
    }
}
