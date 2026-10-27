import XCTest

@testable import NaconCore

/// S3: the pure rules behind the per-control mapping editor.
///
/// The editor itself is SwiftUI, but every decision it takes -- which controls may be remapped, what
/// a captured key press turns into, when a capture is cancelled, how an action is labelled, and what
/// clearing a mapping means -- lives in `MappingRules` and in `InputProfile`/`ProfileLibrary`, so it
/// can be checked here without a window or an event monitor.
final class MappingRulesTests: XCTestCase {
    // MARK: - Remappable controls

    func testEveryControlExceptGuideIsRemappable() {
        let remappable = MappingRules.remappableControls

        XCTAssertEqual(
            remappable.count,
            XInputControl.allCases.count - 1,
            "every control except the reserved one has to be remappable"
        )
        XCTAssertFalse(remappable.contains(.guide))
        for control in XInputControl.allCases where control != .guide {
            XCTAssertTrue(MappingRules.isRemappable(control), "\(control) should be remappable")
            XCTAssertTrue(remappable.contains(control), "\(control) is missing from the editor rows")
        }
    }

    func testGuideIsRefusedAsAMappingTarget() {
        XCTAssertFalse(MappingRules.isRemappable(.guide))
        XCTAssertEqual(MappingRules.reservedControl, .guide)

        // A profile without a Guide entry, so a stored action would be visible in the assertions.
        var profile = InputProfile(mappings: [:])
        let changed = profile.setAction(.key(KeyCombo(.tab)), for: .guide)

        XCTAssertFalse(changed, "the emergency stop must not be assignable")
        XCTAssertEqual(profile.action(for: .guide), .none)
        XCTAssertNil(profile.mappings[.guide], "a refused edit must not store anything")
    }

    func testRefusedGuideEditLeavesTheRestOfTheProfileAlone() {
        var profile = InputProfile.standard
        let before = profile

        profile.setAction(.mouseButton(.middle), for: .guide)

        XCTAssertEqual(profile, before)
    }

    // MARK: - Capturing a key press

    func testCapturedKeyWithModifiersBecomesAKeyAction() {
        let outcome = MappingRules.capture(forKeyCode: 12, modifiers: [.command, .shift])

        XCTAssertEqual(outcome, .mapped(.key(KeyCombo(keyCode: 12, modifiers: [.command, .shift]))))
    }

    func testCapturedKeyWithoutModifiersBecomesAPlainKeyAction() {
        let outcome = MappingRules.capture(forKeyCode: 0, modifiers: [])

        XCTAssertEqual(outcome, .mapped(.key(KeyCombo(keyCode: 0))))
    }

    func testEveryModifierSurvivesTheCapture() {
        let modifiers: ModifierSet = [.command, .option, .control, .shift]

        guard case let .mapped(.key(combo)) = MappingRules.capture(forKeyCode: 45, modifiers: modifiers)
        else {
            return XCTFail("a key press has to become a key action")
        }
        XCTAssertEqual(combo.modifiers, modifiers)
        XCTAssertEqual(combo.displayName, "⌃⌥⇧⌘N", "the captured shortcut must render readably")
    }

    func testPlainEscapeCancelsTheCapture() {
        XCTAssertEqual(MappingRules.capture(forKeyCode: VirtualKey.escape.rawValue, modifiers: []), .cancel)
    }

    func testEscapeWithModifiersCanStillBeMapped() {
        // Escape on its own is the way out of the capture, so a shortcut that merely includes
        // Escape has to stay reachable.
        let outcome = MappingRules.capture(forKeyCode: VirtualKey.escape.rawValue, modifiers: [.shift])

        XCTAssertEqual(outcome, .mapped(.key(KeyCombo(keyCode: 53, modifiers: [.shift]))))
    }

    // MARK: - Clearing a mapping

    func testSettingNoneClearsTheMapping() {
        var profile = InputProfile.standard
        XCTAssertEqual(profile.action(for: .buttonA), .mouseButton(.left))

        let changed = profile.setAction(.none, for: .buttonA)

        XCTAssertTrue(changed)
        XCTAssertEqual(profile.action(for: .buttonA), .none)
        XCTAssertNil(profile.mappings[.buttonA], "clearing removes the entry instead of storing .none")
        XCTAssertFalse(profile.discreteControls.contains(.buttonA))
    }

    func testSettingANonNoneActionStoresIt() {
        var profile = InputProfile(mappings: [:])

        profile.setAction(.scrollLines(MappingRules.scrollStepLines), for: .rightThumb)

        XCTAssertEqual(profile.action(for: .rightThumb), .scrollLines(MappingRules.scrollStepLines))
    }

    // MARK: - Readable labels

    func testKeyActionsRenderWithTheirShortcutName() {
        let action = MappedAction.key(KeyCombo(keyCode: 12, modifiers: [.command]))

        XCTAssertEqual(MappingRules.label(for: action), "⌘Q")
        XCTAssertEqual(MappingRules.label(for: .key(KeyCombo(.tab))), "Tab")
    }

    func testMouseButtonActionsRenderReadably() {
        XCTAssertEqual(MappingRules.label(for: .mouseButton(.left)), "Clic izquierdo")
        XCTAssertEqual(MappingRules.label(for: .mouseButton(.right)), "Clic derecho")
        XCTAssertEqual(MappingRules.label(for: .mouseButton(.middle)), "Clic central")
    }

    func testScrollActionsRenderDirectionAndAmount() {
        XCTAssertEqual(MappingRules.label(for: .scrollLines(3)), "Desplazar arriba 3 líneas")
        XCTAssertEqual(MappingRules.label(for: .scrollLines(-3)), "Desplazar abajo 3 líneas")
    }

    func testNoActionRendersAsUnassigned() {
        XCTAssertEqual(MappingRules.label(for: .none), "Sin asignar")
    }

    // MARK: - Library level: the selected profile only

    func testEditAppliesToTheSelectedProfileOnly() {
        let other = StoredProfile(name: "Otro", profile: .standard)
        let selected = StoredProfile(name: "Trabajo", profile: .standard)
        var library = ProfileLibrary(profiles: [other, selected], selectedProfileID: selected.id)

        let changed = library.setAction(.key(KeyCombo(keyCode: 12, modifiers: [.command])), for: .start)

        XCTAssertTrue(changed)
        XCTAssertEqual(
            library.profiles[1].profile.action(for: .start),
            .key(KeyCombo(keyCode: 12, modifiers: [.command]))
        )
        XCTAssertEqual(
            library.profiles[0].profile.action(for: .start),
            InputProfile.standard.action(for: .start),
            "the other profile keeps its own mapping"
        )
    }

    func testLibraryRefusesToRemapGuide() {
        let profile = StoredProfile(name: "Trabajo", profile: InputProfile(mappings: [:]))
        var library = ProfileLibrary(profiles: [profile], selectedProfileID: profile.id)

        XCTAssertFalse(library.setAction(.key(KeyCombo(.tab)), for: .guide))
        XCTAssertNil(library.selectedProfile?.profile.mappings[.guide])
    }
}
