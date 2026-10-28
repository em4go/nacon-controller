import XCTest

@testable import NaconCore

/// The bug these pin: a shortcut posted as "key with modifier flags" tells the system that Command
/// is held and never tells it that Command was released, so the switcher stays open and every later
/// keystroke is read as Command-something.
final class KeyStrokePlanTests: XCTestCase {
    private let commandTab = KeyCombo(.tab, modifiers: [.command])

    private func downKeyCodes(_ combo: KeyCombo) -> [UInt16] {
        KeyStrokePlan.strokes(for: combo, isDown: true).map(\.keyCode)
    }

    private func upKeyCodes(_ combo: KeyCombo) -> [UInt16] {
        KeyStrokePlan.strokes(for: combo, isDown: false).map(\.keyCode)
    }

    func testACommandShortcutPressesCommandBeforeTheKey() {
        XCTAssertEqual(downKeyCodes(commandTab), [55, 48])
        XCTAssertEqual(
            KeyStrokePlan.strokes(for: commandTab, isDown: true),
            [
                KeyStroke(keyCode: 55, isDown: true, modifiers: [.command]),
                KeyStroke(keyCode: 48, isDown: true, modifiers: [.command]),
            ]
        )
    }

    func testAReleaseLiftsTheKeyBeforeTheModifier() {
        XCTAssertEqual(upKeyCodes(commandTab), [48, 55])
        XCTAssertEqual(
            KeyStrokePlan.strokes(for: commandTab, isDown: false),
            [
                KeyStroke(keyCode: 48, isDown: false, modifiers: [.command]),
                KeyStroke(keyCode: 55, isDown: false, modifiers: []),
            ],
            "the last modifier release must carry no flags, or the system keeps it held"
        )
    }

    func testEveryModifierThatGoesDownComesBackUp() {
        let combos = [
            commandTab,
            KeyCombo(.space, modifiers: [.command]),
            KeyCombo(.tab, modifiers: [.shift]),
            KeyCombo(.escape, modifiers: [.option, .command]),
            KeyCombo(keyCode: 12, modifiers: [.control, .option, .shift, .command]),
        ]
        let modifierCodes: Set<UInt16> = [55, 56, 58, 59]

        for combo in combos {
            let down = downKeyCodes(combo).filter(modifierCodes.contains)
            let up = upKeyCodes(combo).filter(modifierCodes.contains)
            XCTAssertEqual(up.sorted(), down.sorted(), "\(combo) leaves a modifier down")
            XCTAssertEqual(Set(down).count, down.count, "\(combo) presses a modifier twice")

            let flags = KeyStrokePlan.strokes(for: combo, isDown: false)
                .filter { modifierCodes.contains($0.keyCode) }
                .last
                .map(\.modifiers)
            XCTAssertEqual(flags, [], "\(combo) ends with a held flag")
        }
    }

    func testSeveralModifiersAreBracketedInAppleOrder() {
        let combo = KeyCombo(keyCode: 12, modifiers: [.command, .shift, .option, .control])

        XCTAssertEqual(downKeyCodes(combo), [59, 58, 56, 55, 12], "⌃⌥⇧⌘ then the key")
        XCTAssertEqual(upKeyCodes(combo), [12, 55, 56, 58, 59], "the key, then the modifiers inside out")
    }

    func testAPlainKeyIsASingleStroke() {
        XCTAssertEqual(
            KeyStrokePlan.strokes(for: KeyCombo(.space), isDown: true),
            [KeyStroke(keyCode: 49, isDown: true, modifiers: [])]
        )
        XCTAssertEqual(
            KeyStrokePlan.strokes(for: KeyCombo(.space), isDown: false),
            [KeyStroke(keyCode: 49, isDown: false, modifiers: [])]
        )
    }

    func testAModifierOnItsOwnIsAHoldNotAShortcut() {
        XCTAssertEqual(
            KeyStrokePlan.strokes(for: KeyCombo(keyCode: 55), isDown: true),
            [KeyStroke(keyCode: 55, isDown: true, modifiers: [.command])]
        )
        XCTAssertEqual(
            KeyStrokePlan.strokes(for: KeyCombo(keyCode: 55), isDown: false),
            [KeyStroke(keyCode: 55, isDown: false, modifiers: [])]
        )
    }

    func testAHoldWithAStraySelfReferenceStillReleasesCleanly() {
        // A hand-edited profile can say "Command with Command". The release must not leave the flag.
        let odd = KeyCombo(keyCode: 55, modifiers: [.command])
        XCTAssertEqual(downKeyCodes(odd), [55])
        XCTAssertEqual(
            KeyStrokePlan.strokes(for: odd, isDown: false),
            [KeyStroke(keyCode: 55, isDown: false, modifiers: [])]
        )
    }

    func testTheRepeatPostsTheKeyAlone() {
        // Pressing Command again on every repeat would stack presses no release balances.
        XCTAssertEqual(
            KeyStrokePlan.repeatStroke(for: commandTab),
            KeyStroke(keyCode: 48, isDown: true, modifiers: [.command])
        )
    }

    func testTheHoldCombosAreTheFourModifiers() {
        XCTAssertEqual(KeyStrokePlan.holdCombos.map(\.keyCode), [59, 58, 56, 55])
        for combo in KeyStrokePlan.holdCombos {
            XCTAssertTrue(combo.modifiers.isEmpty, "a hold is the key, not a shortcut")
            XCTAssertEqual(KeyStrokePlan.strokes(for: combo, isDown: true).count, 1)
        }
    }
}
