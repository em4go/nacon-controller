import XCTest

@testable import NaconCore

/// S2, S5: an action carries its own name, the way a key combo already does.
///
/// These are the labels the rules enum used to print, moved here with the code. The text is
/// pinned per case on purpose: it is what the table, the strip, the summary and both assign menus show,
/// so changing one is a user-visible change and has to be a deliberate edit. Cases that read the same
/// way share a test where the assertion stays precise; a failure still names the string it broke.
final class MappedActionTests: XCTestCase {
    private let spanish = Locale(identifier: "es")
    private let english = Locale(identifier: "en")
    private var selectAll: KeyCombo { KeyCombo(keyCode: 0, modifiers: [.command]) }
    private var copy: KeyCombo { KeyCombo(keyCode: 8, modifiers: [.command]) }

    // MARK: - Keys

    func testKeyActionsRenderWithTheirShortcutName() {
        let action = MappedAction.key(KeyCombo(keyCode: 12, modifiers: [.command]))

        XCTAssertEqual(action.displayName(in: spanish), "⌘Q")
        // The name of a key action comes from `KeyCatalog`, so it reads in Spanish like the badges.
        XCTAssertEqual(MappedAction.key(KeyCombo(.tab)).displayName(in: spanish), "⇥")
    }

    // MARK: - Mouse buttons

    func testMouseButtonActionsRenderReadably() {
        XCTAssertEqual(MappedAction.mouseButton(.left).displayName(in: spanish), "Clic izquierdo")
        XCTAssertEqual(MappedAction.mouseButton(.left).displayName(in: english), "Left click")
        XCTAssertEqual(MappedAction.mouseButton(.right).displayName(in: spanish), "Clic derecho")
        XCTAssertEqual(MappedAction.mouseButton(.middle).displayName(in: spanish), "Clic central")
    }

    // MARK: - Scrolling

    func testScrollActionsRenderDirectionAndAmount() {
        XCTAssertEqual(MappedAction.scrollLines(3).displayName(in: spanish), "Desplazar arriba 3 líneas")
        XCTAssertEqual(MappedAction.scrollLines(-3).displayName(in: spanish), "Desplazar abajo 3 líneas")
    }

    /// A hand-edited file can hold `Int.min`, where `abs` traps; the number is now formatted by the
    /// catalog, so it also arrives with the grouping of the language instead of raw digits.
    func testTheSmallestIntegerAmountNamesTheDirectionInsteadOfTrapping() {
        // A hand-edited profile can carry Int.min, where `abs` traps; the label still has to render.
        XCTAssertEqual(
            MappedAction.scrollLines(.min).displayName(in: spanish),
            "Desplazar abajo 9.223.372.036.854.775.808 líneas"
        )
    }

    func testZeroScrollNamesNoMovement() {
        XCTAssertEqual(MappedAction.scrollLines(0).displayName(in: spanish), "Sin desplazamiento")
    }

    func testOneLineUpUsesTheSingular() {
        XCTAssertEqual(MappedAction.scrollLines(1).displayName(in: spanish), "Desplazar arriba 1 línea")
    }

    func testTwoLinesUpUseThePlural() {
        XCTAssertEqual(MappedAction.scrollLines(2).displayName(in: spanish), "Desplazar arriba 2 líneas")
    }

    func testOneLineDownUsesTheSingular() {
        XCTAssertEqual(MappedAction.scrollLines(-1).displayName(in: spanish), "Desplazar abajo 1 línea")
    }

    func testTwoLinesDownUseThePlural() {
        XCTAssertEqual(MappedAction.scrollLines(-2).displayName(in: spanish), "Desplazar abajo 2 líneas")
    }

    // MARK: - Sequences

    func testASequenceShowsItsStepsInOrder() {
        XCTAssertEqual(
            MappedAction.sequence([selectAll, copy]).displayName(in: spanish),
            "⌘A luego ⌘C"
        )
    }

    // MARK: - Nothing assigned

    func testNoActionRendersAsUnassigned() {
        XCTAssertEqual(MappedAction.none.displayName(in: spanish), "Sin asignar")
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
