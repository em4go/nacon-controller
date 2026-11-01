import XCTest

@testable import NaconCore

/// S5, S6: changing the active profile from the pad, and the invariant that makes it safe.
///
/// The switch is atomic: everything the previous profile claimed is released with the actions that
/// claimed it, and only then is the new profile applied. A toggled button that survived the swap would
/// leave the system dragging with no visible cause, so the order is the behaviour under test here, not
/// an implementation detail.
final class ProfileSwitchTests: XCTestCase {
    private func report(buttons: XInputButtons = []) -> XInputReport {
        XInputReport(
            rawBytes: [],
            buttons: buttons,
            leftTrigger: 0,
            rightTrigger: 0,
            leftStick: .center,
            rightStick: .center
        )
    }

    // MARK: - S6: the action itself

    func testTheStepActionHasALabelInBothLanguages() {
        let english = Locale(identifier: "en")
        let spanish = Locale(identifier: "es")

        XCTAssertEqual(MappedAction.profileStep(.next).displayName(in: english), "Next profile")
        XCTAssertEqual(MappedAction.profileStep(.previous).displayName(in: english), "Previous profile")
        XCTAssertEqual(MappedAction.profileStep(.next).displayName(in: spanish), "Perfil siguiente")
        XCTAssertEqual(MappedAction.profileStep(.previous).displayName(in: spanish), "Perfil anterior")
    }

    func testTheStepActionSurvivesASave() throws {
        let profile = InputProfile(mappings: [
            .buttonB: .profileStep(.next),
            .buttonX: .profileStep(.previous),
        ])

        let decoded = try JSONDecoder().decode(
            InputProfile.self,
            from: JSONEncoder().encode(profile)
        )

        XCTAssertEqual(decoded.action(for: .buttonB), .profileStep(.next))
        XCTAssertEqual(decoded.action(for: .buttonX), .profileStep(.previous))
    }

    // MARK: - S6: pressing it emits the step and nothing else

    func testAPressEmitsOneStepEffectAndTheReleaseEmitsNothing() {
        var performance = PadPerformance(
            profile: InputProfile(mappings: [.buttonB: .profileStep(.next)])
        )

        XCTAssertEqual(performance.press(.buttonB, action: .profileStep(.next)), [.profileStep(.next)])
        // No key, no click, no repeat and no scroll however long the control stays down.
        XCTAssertEqual(performance.advance(seconds: 1, leftStick: .center, rightStick: .center), [])
        XCTAssertEqual(performance.release(.buttonB), [])
        XCTAssertEqual(performance.reset(), [])
    }

    func testTheStepReachesTheEngineCallbackAndNoEventIsPosted() {
        let emitter = RecordingEmitter()
        let engine = EmulationEngine(
            emitter: emitter,
            profile: InputProfile(mappings: [.buttonB: .profileStep(.next)])
        )
        var steps: [ProfileStep] = []
        engine.onProfileStep = { steps.append($0) }
        engine.setEnabledNow(true)
        engine.handle(report())
        engine.handle(report(buttons: [.buttonB]))
        engine.handle(report())

        XCTAssertEqual(steps, [.next])
        XCTAssertEqual(emitter.events, [], "the step is a claim on the active profile, not a keystroke")
    }

    // MARK: - S5: the switch is atomic

    func testAHeldKeyIsReleasedBeforeTheNewProfileIsUsed() {
        // The order is the assertion: the release of the old claim must be posted before anything from
        // the new profile goes out, so a key cannot be left down in a profile that no longer knows it.
        let emitter = RecordingEmitter()
        let engine = EmulationEngine(
            emitter: emitter,
            profile: InputProfile(mappings: [.buttonA: .key(KeyCombo(.tab))])
        )
        engine.setEnabledNow(true)
        engine.handle(report())
        engine.handle(report(buttons: [.buttonA]))

        XCTAssertEqual(emitter.events, [.press(.key(KeyCombo(.tab)))])

        engine.switchProfileNow(InputProfile(mappings: [.buttonA: .key(KeyCombo(.space))]))

        // Let go and press again: the report is the same button, the mapping behind it is the new one.
        engine.handle(report())
        engine.handle(report(buttons: [.buttonA]))

        XCTAssertEqual(emitter.events, [
            .press(.key(KeyCombo(.tab))),
            .release(.key(KeyCombo(.tab))),
            .releaseAllMouseButtons,
            .press(.key(KeyCombo(.space))),
        ])
        XCTAssertEqual(
            emitter.releasedHeldModifiers,
            1,
            "the modifiers the emitter was holding are let go with the rest of the old profile"
        )
    }

    func testAToggledMouseButtonClaimedByTheOldProfileIsReleased() {
        // The worst case of a half-applied switch: a left button held by a toggle becomes a drag nobody
        // can explain. It belongs to the profile that toggled it, so the switch lets it go.
        let emitter = RecordingEmitter()
        let engine = EmulationEngine(
            emitter: emitter,
            profile: InputProfile(mappings: [.buttonY: .toggledMouseButton(.left)])
        )
        engine.setEnabledNow(true)
        engine.handle(report())
        engine.handle(report(buttons: [.buttonY]))
        engine.handle(report())

        XCTAssertEqual(emitter.events, [.toggleMouseButton(.left)])

        engine.switchProfileNow(InputProfile(mappings: [.buttonY: .key(KeyCombo(.escape))]))

        XCTAssertEqual(emitter.events, [.toggleMouseButton(.left), .releaseAllMouseButtons])
    }

    func testTheNextReportAfterASwitchUsesTheNewProfile() {
        let emitter = RecordingEmitter()
        let engine = EmulationEngine(
            emitter: emitter,
            profile: InputProfile(mappings: [.buttonA: .key(KeyCombo(.tab))])
        )
        engine.setEnabledNow(true)
        engine.handle(report())

        engine.switchProfileNow(InputProfile(mappings: [.buttonA: .key(KeyCombo(.space))]))
        engine.handle(report(buttons: [.buttonA]))

        XCTAssertEqual(emitter.events, [.releaseAllMouseButtons, .press(.key(KeyCombo(.space)))])
    }

    func testEmulationKeepsRunningAcrossASwitch() {
        let emitter = RecordingEmitter()
        let engine = EmulationEngine(
            emitter: emitter,
            profile: InputProfile(mappings: [.buttonA: .key(KeyCombo(.tab))])
        )
        engine.setEnabledNow(true)
        engine.handle(report())

        engine.switchProfileNow(InputProfile(mappings: [.buttonB: .key(KeyCombo(.escape))]))
        emitter.reset()
        engine.handle(report(buttons: [.buttonB]))

        XCTAssertEqual(
            emitter.events,
            [.press(.key(KeyCombo(.escape)))],
            "a switch replaces the mapping, it does not stop the emulation"
        )
    }

    // MARK: - The library step

    func testTheLibraryStepsForwardAndBackWithWraparound() {
        let first = StoredProfile(name: "Uno", profile: .standard)
        let second = StoredProfile(name: "Dos", profile: .standard)
        let third = StoredProfile(name: "Tres", profile: .standard)
        var library = ProfileLibrary(profiles: [first, second, third], selectedProfileID: third.id)

        XCTAssertTrue(library.stepProfile(.next))
        XCTAssertEqual(library.selectedProfileID, first.id, "the last profile steps forward to the first")
        XCTAssertTrue(library.stepProfile(.next))
        XCTAssertEqual(library.selectedProfileID, second.id)
        XCTAssertTrue(library.stepProfile(.previous))
        XCTAssertEqual(library.selectedProfileID, first.id)
        XCTAssertTrue(library.stepProfile(.previous))
        XCTAssertEqual(library.selectedProfileID, third.id, "the first profile steps back to the last")
    }

    func testASingleProfileStepsNowhere() {
        let only = StoredProfile(name: "Uno", profile: .standard)
        var library = ProfileLibrary(profiles: [only], selectedProfileID: only.id)

        XCTAssertFalse(library.stepProfile(.next), "one profile has nowhere to go")
        XCTAssertFalse(library.stepProfile(.previous))
        XCTAssertEqual(library.selectedProfileID, only.id)
    }

    // MARK: - S9: each profile points to the next one

    /// Three profiles where list order and the links disagree: Ratón points at Dibujo, and Dibujo points
    /// back at Ratón, while Texto sits between them in the list and belongs to no chain.
    private func chainedLibrary() -> ProfileLibrary {
        var raton = StoredProfile(name: "Ratón", profile: .standard)
        let texto = StoredProfile(name: "Texto", profile: .standard)
        var dibujo = StoredProfile(name: "Dibujo", profile: .standard)
        raton.nextProfileID = dibujo.id
        dibujo.nextProfileID = raton.id
        return ProfileLibrary(profiles: [raton, texto, dibujo], selectedProfileID: raton.id)
    }

    func testTheStepFollowsTheLinkInsteadOfTheListOrder() {
        var library = chainedLibrary()
        let names = library.profiles.map(\.name)
        let dibujo = library.profiles[2].id
        let raton = library.profiles[0].id

        XCTAssertTrue(library.stepProfile(.next))
        XCTAssertEqual(library.selectedProfileID, dibujo, "next must skip Texto, which is only a list neighbour")
        XCTAssertTrue(library.stepProfile(.next))
        XCTAssertEqual(library.selectedProfileID, raton, "Dibujo points back at Ratón, closing the cycle")
        XCTAssertTrue(library.stepProfile(.previous))
        XCTAssertEqual(library.selectedProfileID, dibujo, "backwards is the reverse link, not the previous row")
        XCTAssertEqual(names, ["Ratón", "Texto", "Dibujo"], "stepping must not reorder the library")
    }

    func testAProfileWithNoLinkKeepsTheListOrderSoOldFilesStillStep() {
        let first = StoredProfile(name: "Uno", profile: .standard)
        let second = StoredProfile(name: "Dos", profile: .standard)
        var library = ProfileLibrary(profiles: [first, second], selectedProfileID: first.id)

        XCTAssertTrue(library.stepProfile(.next))
        XCTAssertEqual(library.selectedProfileID, second.id)
        XCTAssertTrue(library.stepProfile(.previous))
        XCTAssertEqual(library.selectedProfileID, first.id)
    }

    func testALinkToAProfileThatIsGoneFallsBackToTheListOrder() {
        var first = StoredProfile(name: "Uno", profile: .standard)
        let second = StoredProfile(name: "Dos", profile: .standard)
        first.nextProfileID = UUID()
        var library = ProfileLibrary(profiles: [first, second], selectedProfileID: first.id)

        XCTAssertTrue(library.stepProfile(.next))
        XCTAssertEqual(library.selectedProfileID, second.id, "a dangling link must not leave nowhere to go")
        XCTAssertTrue(library.profiles.contains { $0.id == library.selectedProfileID })
    }

    func testAProfileCannotPointAtItselfAndAnUnchangedLinkReportsNothing() {
        var library = chainedLibrary()
        let raton = library.profiles[0].id
        let dibujo = library.profiles[2].id

        XCTAssertFalse(library.setNextProfile(raton), "a profile that points at itself can never leave")
        XCTAssertEqual(library.profiles[0].nextProfileID, dibujo, "the refused link must not be written")
        XCTAssertFalse(library.setNextProfile(dibujo), "the link already says that")
        XCTAssertTrue(library.setNextProfile(nil))
        XCTAssertNil(library.profiles[0].nextProfileID, "removing the link is a change, not a refusal")
    }

    func testDeletingAProfileClearsTheLinksThatPointedAtIt() {
        var library = chainedLibrary()
        let texto = library.profiles[1].id
        let dibujo = library.profiles[2].id

        XCTAssertTrue(library.deleteProfile(id: dibujo))
        XCTAssertNil(library.profiles[0].nextProfileID, "a link to a deleted profile is a lie the file keeps")
        XCTAssertEqual(library.profiles.map(\.name), ["Ratón", "Texto"])
        XCTAssertNotEqual(library.selectedProfileID, dibujo)
        XCTAssertNotNil(texto)
    }

    func testTheLinkSurvivesEncodingAndAnOldEntryLoadsWithoutOne() throws {
        let library = chainedLibrary()
        let decoded = try JSONDecoder().decode(
            ProfileLibrary.self,
            from: JSONEncoder().encode(library)
        )
        XCTAssertEqual(decoded, library, "the link is part of the saved state")

        var legacy = StoredProfile(name: "Viejo", profile: .standard)
        legacy.nextProfileID = nil
        let json = #"{"id":"\#(legacy.id.uuidString)","name":"Viejo","profile":{"mappings":{}}}"#
        let loaded = try JSONDecoder().decode(StoredProfile.self, from: Data(json.utf8))
        XCTAssertEqual(loaded.name, "Viejo")
        XCTAssertNil(loaded.nextProfileID, "a file written before links existed has no link, not a broken one")
    }
}
