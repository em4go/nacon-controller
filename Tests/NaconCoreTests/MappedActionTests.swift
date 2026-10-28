import XCTest

@testable import NaconCore

/// S2, S5: an action carries its own name, the way a key combo already does.
///
/// These are the labels the rules enum used to print, moved here with the code. The text is
/// pinned per case on purpose: it is what the table, the strip, the summary and both assign menus show,
/// so changing one is a user-visible change and has to be a deliberate edit. One test per case also
/// means a failure names the case instead of pointing at a table of assertions.
final class MappedActionTests: XCTestCase {
    private var selectAll: KeyCombo { KeyCombo(keyCode: 0, modifiers: [.command]) }
    private var copy: KeyCombo { KeyCombo(keyCode: 8, modifiers: [.command]) }

    // MARK: - Keys

    func testKeyActionsRenderWithTheirShortcutName() {
        let action = MappedAction.key(KeyCombo(keyCode: 12, modifiers: [.command]))

        XCTAssertEqual(action.displayName, "⌘Q")
        // The name of a key action comes from `KeyCatalog`, so it reads in Spanish like the badges.
        XCTAssertEqual(MappedAction.key(KeyCombo(.tab)).displayName, "⇥")
    }

    // MARK: - Mouse buttons

    func testMouseButtonActionsRenderReadably() {
        XCTAssertEqual(MappedAction.mouseButton(.left).displayName, "Clic izquierdo")
        XCTAssertEqual(MappedAction.mouseButton(.right).displayName, "Clic derecho")
        XCTAssertEqual(MappedAction.mouseButton(.middle).displayName, "Clic central")
    }

    // MARK: - Scrolling

    func testScrollActionsRenderDirectionAndAmount() {
        XCTAssertEqual(MappedAction.scrollLines(3).displayName, "Desplazar arriba 3 líneas")
        XCTAssertEqual(MappedAction.scrollLines(-3).displayName, "Desplazar abajo 3 líneas")
    }

    func testZeroScrollNamesNoMovement() {
        XCTAssertEqual(MappedAction.scrollLines(0).displayName, "Sin desplazamiento")
    }

    func testOneLineUpUsesTheSingular() {
        XCTAssertEqual(MappedAction.scrollLines(1).displayName, "Desplazar arriba 1 línea")
    }

    func testTwoLinesUpUseThePlural() {
        XCTAssertEqual(MappedAction.scrollLines(2).displayName, "Desplazar arriba 2 líneas")
    }

    func testOneLineDownUsesTheSingular() {
        XCTAssertEqual(MappedAction.scrollLines(-1).displayName, "Desplazar abajo 1 línea")
    }

    func testTwoLinesDownUseThePlural() {
        XCTAssertEqual(MappedAction.scrollLines(-2).displayName, "Desplazar abajo 2 líneas")
    }

    // MARK: - Sequences

    func testASequenceShowsItsStepsInOrder() {
        XCTAssertEqual(
            MappedAction.sequence([selectAll, copy]).displayName,
            "⌘A luego ⌘C"
        )
    }

    // MARK: - Nothing assigned

    func testNoActionRendersAsUnassigned() {
        XCTAssertEqual(MappedAction.none.displayName, "Sin asignar")
    }

    /// The invariant behind every row: a mapping always says something, even when it says nothing is
    /// assigned. An empty cell would look like a control the editor forgot.
    func testNoActionNameIsEmpty() {
        let actions: [MappedAction] = [
            .none,
            .key(KeyCombo(.tab)),
            .key(KeyCombo(keyCode: 12, modifiers: [.command, .shift])),
            .mouseButton(.left),
            .mouseButton(.right),
            .mouseButton(.middle),
            .scrollLines(0),
            .scrollLines(1),
            .scrollLines(-1),
            .sequence([selectAll, copy]),
        ]

        for action in actions {
            XCTAssertFalse(action.displayName.isEmpty, "\(action) prints an empty cell")
        }
    }
}
