import XCTest

@testable import NaconCore

/// S2, S4, S5, S6: the one rule that decides what a finished key capture writes.
///
/// The intent (which column, replace or extend) travels inside the outcome, so the resolve is a pure
/// function of the outcome and the profile being edited. Every test states the write first and then
/// applies it through `ProfileLibrary`, because that pair — resolve then apply — is the whole path a
/// captured key takes once it leaves `KeyCaptureSession`.
final class MappingWriteTests: XCTestCase {
    private let profileAID = UUID()
    private let profileBID = UUID()

    /// What the base of the fixture profile sends for ✕ and ○.
    private let baseA = KeyCombo(keyCode: 12)
    private let baseB = KeyCombo(keyCode: 13)
    /// What its MOD layer sends for the same two controls.
    private let modA = KeyCombo(keyCode: 14)
    private let modB = KeyCombo(keyCode: 15)
    /// The key a capture produces in these tests.
    private let captured = KeyCombo(keyCode: 16, modifiers: [.command])

    // MARK: - Replacing

    func testABaseCaptureReplacesTheBaseAndLeavesTheLayerAlone() {
        var library = makeLibrary()

        let write = resolve(.buttonA, .key(captured), intent: .base, in: library)
        XCTAssertEqual(
            write,
            .apply(profileID: profileAID, control: .buttonA, column: .base, action: .key(captured))
        )
        XCTAssertTrue(library.apply(write))

        let written = profileA(in: library)
        XCTAssertEqual(written.action(for: .buttonA), .key(captured))
        XCTAssertEqual(written.layer.action(for: .buttonA), .key(modA), "the layer must not move")
        XCTAssertEqual(written.action(for: .buttonB), .key(baseB), "only one control is written")
    }

    func testAModCaptureWritesOnlyTheLayerEntryAndLeavesTheBaseAlone() {
        var library = makeLibrary()

        let write = resolve(.buttonA, .key(captured), intent: .mod, in: library)
        XCTAssertEqual(
            write,
            .apply(profileID: profileAID, control: .buttonA, column: .mod, action: .key(captured))
        )
        XCTAssertTrue(library.apply(write))

        let written = profileA(in: library)
        XCTAssertEqual(written.layer.action(for: .buttonA), .key(captured))
        XCTAssertEqual(written.action(for: .buttonA), .key(baseA), "the base must not move")
        XCTAssertEqual(written.layer.action(for: .buttonB), .key(modB), "only one entry is written")
    }

    // MARK: - Appending a step (S5)

    func testAppendingAKeyExtendsTheBaseCommand() {
        var library = makeLibrary()

        let write = resolve(.buttonA, .key(captured), intent: .baseCommand, in: library)
        XCTAssertEqual(
            write,
            .apply(
                profileID: profileAID,
                control: .buttonA,
                column: .base,
                action: .sequence([baseA, captured])
            )
        )
        XCTAssertTrue(library.apply(write))
        XCTAssertEqual(profileA(in: library).action(for: .buttonA), .sequence([baseA, captured]))
    }

    func testAppendingInTheModColumnChainsOntoTheLayerEntryNotTheBase() {
        var library = makeLibrary()

        let write = resolve(.buttonA, .key(captured), intent: .modCommand, in: library)
        XCTAssertEqual(
            write,
            .apply(
                profileID: profileAID,
                control: .buttonA,
                column: .mod,
                action: .sequence([modA, captured])
            )
        )
        XCTAssertTrue(library.apply(write))

        let written = profileA(in: library)
        XCTAssertEqual(written.layer.action(for: .buttonA), .sequence([modA, captured]))
        XCTAssertEqual(
            written.action(for: .buttonA),
            .key(baseA),
            "a step appended in the MOD column never touches the base"
        )
    }

    func testAppendingToAnUnassignedControlReplacesInsteadOfClearingIt() {
        var library = makeLibrary()

        let write = resolve(.buttonX, .key(captured), intent: .baseCommand, in: library)

        XCTAssertEqual(
            write,
            .apply(profileID: profileAID, control: .buttonX, column: .base, action: .key(captured)),
            "appending to nothing must not become an empty command"
        )
        XCTAssertTrue(library.apply(write))
        XCTAssertEqual(profileA(in: library).action(for: .buttonX), .key(captured))
    }

    func testAppendingInTheModColumnWhereTheLayerHasNoEntryReplacesAndLeavesTheBaseAlone() {
        var library = makeLibrary(layerMappings: [.buttonA: .key(modA)])

        let write = resolve(.buttonB, .key(captured), intent: .modCommand, in: library)

        XCTAssertEqual(
            write,
            .apply(profileID: profileAID, control: .buttonB, column: .mod, action: .key(captured)),
            "the layer had nothing to extend, so the captured action replaces it"
        )
        XCTAssertTrue(library.apply(write))

        let written = profileA(in: library)
        XCTAssertEqual(written.layer.action(for: .buttonB), .key(captured))
        XCTAssertEqual(
            written.action(for: .buttonB),
            .key(baseB),
            "the base of that control is what the layer fell back to, so it stays"
        )
    }

    func testAnAppendIntentWithAMouseButtonStoresThatActionAsItCame() {
        var library = makeLibrary()

        let write = resolve(.buttonA, .mouseButton(.middle), intent: .baseCommand, in: library)

        XCTAssertEqual(
            write,
            .apply(
                profileID: profileAID,
                control: .buttonA,
                column: .base,
                action: .mouseButton(.middle)
            ),
            "a mouse button is not a step, so it replaces the command"
        )
        XCTAssertTrue(library.apply(write))
        XCTAssertEqual(profileA(in: library).action(for: .buttonA), .mouseButton(.middle))
    }

    // MARK: - Dropping (S4, S6)

    func testACaptureArmedForAProfileThatIsNoLongerSelectedIsDropped() {
        var library = makeLibrary()
        let armedProfileID = profileAID
        // The user arms the capture while A is selected, then picks B before the key arrives.
        library.selectProfile(id: profileBID)
        let before = library

        let write = MappingWrite.resolve(
            .mapped(
                profileID: armedProfileID,
                control: .buttonA,
                action: .key(captured),
                intent: .baseCommand
            ),
            editing: library.selectedProfile?.profile,
            selectedProfileID: library.selectedProfile?.id
        )

        XCTAssertEqual(write, .drop)
        XCTAssertFalse(library.apply(write), "a dropped write reports that nothing changed")
        XCTAssertEqual(library, before, "neither profile may change")
        XCTAssertEqual(profileA(in: library).action(for: .buttonA), .key(baseA))
        XCTAssertEqual(profileB(in: library), .standard)
    }

    func testACancelledCaptureDrops() {
        var library = makeLibrary()
        let before = library

        let write = MappingWrite.resolve(
            .cancelled(.buttonA),
            editing: library.selectedProfile?.profile,
            selectedProfileID: library.selectedProfile?.id
        )

        XCTAssertEqual(write, .drop)
        XCTAssertFalse(library.apply(write))
        XCTAssertEqual(library, before, "Escape leaves the previous mapping as it was")
    }

    func testAnUnarmedPressDrops() {
        var library = makeLibrary()
        let before = library

        let write = MappingWrite.resolve(
            .ignored,
            editing: library.selectedProfile?.profile,
            selectedProfileID: library.selectedProfile?.id
        )

        XCTAssertEqual(write, .drop)
        XCTAssertFalse(library.apply(write))
        XCTAssertEqual(library, before)
    }

    func testApplyingADropChangesNothing() {
        var library = makeLibrary()
        let before = library

        XCTAssertFalse(library.apply(.drop))

        XCTAssertEqual(library, before)
    }

    // MARK: - Fixture

    /// Profile A: a base and a MOD layer that both assign ✕ and ○, so a write can be shown to land in
    /// one column and leave the other alone. Profile B is the standard one and is not selected.
    private func makeLibrary(
        layerMappings: [XInputControl: MappedAction]? = nil
    ) -> ProfileLibrary {
        let layer = layerMappings ?? [.buttonA: .key(modA), .buttonB: .key(modB)]
        let profileA = InputProfile(
            mappings: [.buttonA: .key(baseA), .buttonB: .key(baseB)],
            layer: ProfileLayer(key: .leftThumb, mappings: layer)
        )
        return ProfileLibrary(
            profiles: [
                StoredProfile(id: profileAID, name: "A", profile: profileA),
                StoredProfile(id: profileBID, name: "B", profile: .standard),
            ],
            selectedProfileID: profileAID
        )
    }

    private func profileA(in library: ProfileLibrary) -> InputProfile {
        library.profiles.first { $0.id == profileAID }?.profile ?? .standard
    }

    private func profileB(in library: ProfileLibrary) -> InputProfile {
        library.profiles.first { $0.id == profileBID }?.profile ?? .standard
    }

    /// The write the section performs: resolve against the profile on screen, then apply.
    private func resolve(
        _ control: XInputControl,
        _ action: MappedAction,
        intent: CaptureIntent,
        in library: ProfileLibrary
    ) -> MappingWrite {
        MappingWrite.resolve(
            .mapped(
                profileID: profileAID,
                control: control,
                action: action,
                intent: intent
            ),
            editing: library.selectedProfile?.profile,
            selectedProfileID: library.selectedProfile?.id
        )
    }
}
