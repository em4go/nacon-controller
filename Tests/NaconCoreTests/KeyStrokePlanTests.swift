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

    func testTheHoldCombosAreTheSinglesAndThePairs() {
        let holds = KeyStrokePlan.holdCombos
        XCTAssertEqual(holds.count, 10, "four modifiers alone and the six pairs between them")
        XCTAssertEqual(Set(holds).count, holds.count, "no hold is offered twice")
        for combo in holds {
            XCTAssertTrue(combo.isModifierHold, "\(combo.keyCode) is not a modifier")
        }
        XCTAssertEqual(holds.prefix(4).map(\.keyCode), [59, 58, 56, 55], "singles first")
    }

    func testAHoldCanHoldTwoModifiersAtOnce() {
        // The dictation case: an application that listens for ⌃⇧ and nothing else.
        let hold = KeyCombo(keyCode: 59, modifiers: [.shift])

        XCTAssertEqual(
            KeyStrokePlan.strokes(for: hold, isDown: true),
            [
                KeyStroke(keyCode: 59, isDown: true, modifiers: [.control]),
                KeyStroke(keyCode: 56, isDown: true, modifiers: [.control, .shift]),
            ],
            "both modifiers must be pressed as real keys, not as flags on one of them"
        )
        XCTAssertEqual(
            KeyStrokePlan.strokes(for: hold, isDown: false),
            [
                KeyStroke(keyCode: 56, isDown: false, modifiers: [.control]),
                KeyStroke(keyCode: 59, isDown: false, modifiers: []),
            ]
        )
    }

    func testEveryHoldPressesAndReleasesEachOfItsModifiers() {
        for hold in KeyStrokePlan.holdCombos {
            let pressed = KeyStrokePlan.strokes(for: hold, isDown: true)
            let released = KeyStrokePlan.strokes(for: hold, isDown: false)
            let expected = KeyStrokePlan.heldModifiers(for: hold)

            XCTAssertEqual(pressed.count, expected.rawValue.nonzeroBitCount, "\(hold.displayName)")
            XCTAssertEqual(released.map(\.keyCode), pressed.map(\.keyCode).reversed(), "\(hold.displayName)")
            XCTAssertEqual(released.last?.modifiers, [], "\(hold.displayName) ends with a held flag")
        }
    }

    func testAHoldPrintsItsModifiersInAppleOrder() {
        XCTAssertEqual(KeyCombo(keyCode: 59, modifiers: [.shift]).displayName, "⌃⇧")
        XCTAssertEqual(KeyCombo(keyCode: 55).displayName, "⌘")
        XCTAssertEqual(KeyCombo(.tab, modifiers: [.command]).displayName, "⌘⇥")
    }

    func testAHoldHasNoRepeat() {
        // A modifier does not autorepeat, and a repeat would post the key without its partner.
        XCTAssertNil(KeyStrokePlan.repeatStroke(for: KeyCombo(keyCode: 59, modifiers: [.shift])))
        XCTAssertNil(KeyStrokePlan.repeatStroke(for: KeyCombo(keyCode: 55)))
    }
}
