# Mapping line

«What this Control sends» is derived once, in the core, and every surface that prints it asks the
same module: the base reading, the MOD reading when the layer really redefines it, and one composed
line for a surface that reads it at a glance. The reserved sentence and the MOD pattern come with
their rules, so a surface cannot spell either its own way.

## Specs

- **S1.** Request (verbatim): «continue with c4 and c5».
- **S2.** Decision, verbatim from `odd/tasks/architecture-review-2.md`: «extract the *derivation* only
  — `(control, column, Perfil) -> text` plus `isReserved`. Do not unify the row layouts: the table
  shows two columns with buttons, the strip shows one line, the summary shows a grid, and that
  difference is design, not duplication.»
- **S3.** One module in `NaconCore` answers, for one Control and one Perfil: the base text, the MOD
  text or nothing, and one composed line. The reserved Control answers the reserved sentence instead
  of an assignment, in all three.
- **S4.** The rule the strip applies today is preserved exactly: the MOD part appears only when a key
  can open the Capa MOD **and** the layer redefines this control; otherwise the base is the whole line.
  The MOD text is `nil` in the same two cases, which is what the summary prints as «—».
- **S5.** One catalog key per sentence. The two near-identical reserved sentences collapse into one,
  and it moves to the core catalog with the rule that prints it; the «%@ · MOD %@» pattern moves with
  the composed line. The reserved row is drawn once and used by both mapping views.
- **S6.** Layouts stay apart: the table's two columns with their buttons, the strip's single line and
  the summary's grid keep their own shapes, spacing and typography. Only the text comes from one place.
- **S7.** The derivation is tested through its own interface: the reserved sentence in both languages,
  the base of a control that sends nothing, the MOD text with no layer, with a layer that does not
  redefine the control, and with a layer that does, and the composed line in both of those cases.

## Tasks

| ID | Spec | Route | Commit |
| --- | --- | --- | --- |
| T1 | S3, S4, S7 | `Sources/NaconCore/MappingLine.swift` + `Tests/NaconCoreTests/MappingLineTests.swift` | `36cc3c9` |
| T2 | S5, S6 | `PadGraphView`, `MappingSummaryWindow`, `MappingEditor`, `ProfileSection` + one shared reserved row; both catalogs | `36cc3c9` |
| T3 | S1, S2 | this document and `architecture-review-2.md` | this commit |

## Delivery

One commit, 281 inserted and 83 deleted: the module, its eight tests, the shared reserved row and the
three surfaces that stop deriving. The catalog move is part of it — a rule and the sentence it prints
travel together, which is how the two reserved keys stopped being able to drift.

## Log

- **L1.** «continue with c4 and c5»
- **L2.** The two reserved keys carried different wording: «Reserved: turns emulation on and off» and
  «…instantly». The surviving sentence is the short one, because the strip prints this line under the
  drawing at the window's minimum width and the longer one is cut there. The immediacy is not lost
  from the app: the settings footnote and the manual acceptance steps already say that PS stops the
  emulation at once.
- **L3.** The module lives in `NaconCore` rather than in the app because the app target has no test
  target: a derivation that three surfaces depend on is worth more testable than convenient.
- **L4.** Evidence: `swift build` clean, no new warnings; `swift test` → 474 tests, 0 failures
  (434 at `origin/main`, plus the nine slices' new cases, of which nine are this module's). Outside
  the tests and the catalogs, the reserved sentence and the MOD pattern appear only in
  `Sources/NaconCore/MappingLine.swift`; both catalog files still parse; the three deleted app keys
  have no reference left, and `AppCatalogCoverageTests` — the check that an app-side literal never
  loses its entry — passes.
- **L5.** The first version of these tests could not fail if `MappingLine.mod` dropped its
  `layer.isActive` guard: every layered fixture had a key. A ninth case now uses a layer that keeps
  an entry and has lost its key — a state «Ninguna» in the inspector really produces — and removing
  that guard fails it twice. Checked by making the change, watching the two failures, and putting the
  guard back.
