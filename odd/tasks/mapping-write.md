# Mapping write

One rule decides what a finished key capture writes. The intent (which column, replace or
extend) travels with the armed capture instead of living in view flags, and the write itself is a
pure function in `NaconCore` that the views only apply.

## Specs

- **S1.** Request (verbatim): «I'd like to explore all of them. Spend the time you need on it.
  Build C1 first and then you can continue with the exploration» — where C1 is the report card
  *Deepen the mapping write: one intent, one resolve*.
- **S2.** C1 card, Solution (verbatim): «Carry the arming intent (`column × mode`) in
  `KeyCaptureSession` and add one core type, `MappingWrite`, whose single
  `resolve(intent:outcome:selected:)` returns the write to apply or a drop. The view only
  forwards.»
- **S3.** The intent a capture was armed with comes back with its outcome. A finished capture
  cannot lose it, because `handleKey` disarms before returning.
- **S4.** F5 is preserved: a capture armed for one profile never writes to another. A capture whose
  profile is no longer selected is dropped, and dropping changes nothing.
- **S5.** A step appended to a control with nothing assigned **replaces** instead of clearing it,
  and a step appended in the MOD column chains onto the MOD entry, never the base one.
- **S6.** A capture armed in one column writes only that column, and Escape still cancels without
  touching the previous mapping. Two table details change on purpose: a menu pick «Capturar tecla…»
  re-arms instead of cancelling, and a MOD capture lights the whole row, as a base capture already did.
- **S7.** The drawing's MOD submenu offers the same destinations as the table's, capture and steps
  included. Repository contract, README: «Las dos vistas ofrecen la misma lista de destinos porque
  comparten una sola definición», and `docs/manual-acceptance.md` row 31.
- **S8.** The docs that describe capture say where a capture writes; the stale README line «La
  captura de teclado escribe en la base» is corrected.

## Tasks

| ID | Spec | Route | Commit |
| --- | --- | --- | --- |
| T1 | S2, S3, S5 | Core: `CaptureIntent` carried by `KeyCaptureSession`, `MappingWrite.resolve`, `ProfileLibrary.apply`, tests | `8e6d580` |
| T2 | S2, S4, S6 | Views: delete the two flags, one write seam in `ProfileSection`, narrower row interface | `8e6d580` |
| T3 | S7, S8 | Drawing offers capture into the MOD column; README and manual acceptance | `9e6fc1a` |

## Delivery

Slice boundary: T1 and T2 landed in one commit (`8e6d580`, 714 lines added and 192 removed with the new
`MappingWrite.swift` and its tests) because they cannot compile apart. The library changes the shape
of `KeyCaptureSession.Outcome` and deletes the two flags the views read, so a commit holding only the
core would leave `NaconDiagnostics` unbuilt; the alternative, a transitional shim, is exactly the
layering this change removes. The tests travel with the behaviour they pin. T3 is a second commit
(`9e6fc1a`) and can be reverted alone without touching the rule.

## Log

- **L1.** «I'd like to explore all of them. Spend the time you need on it. Build C1 first and then
  you can continue with the exploration»
- **L2.** Decisions taken while building C1. The intent travels inside the outcome because
  `handleKey` disarms before returning, which is the reason the two view flags existed at all. The
  append rule is total (`canAppendStep` guards it) so an append on an unassigned control replaces
  instead of clearing it — the two old branches disagreed on exactly that. Two verbs, not one: a
  button labelled «Cancelar» cancels whatever the mode, a menu entry only ever arms. Nothing in the
  persisted format changed. The table keeps its behaviour apart from the two details S6 names; the
  drawing gained the entries it was documented to share (S7).
- **L3.** Evidence: `swift test` → 314 tests, 0 failures, run by the parent after both commits;
  `swift build --build-tests` clean; no `isAppendingStep`, `isLayerCapture` or `includesCapture`
  reference remains; `ProfileLibraryController.setAction` / `setLayerAction` stay (unused by the views)
  for the library edit seam of a later candidate.
- **L4.** Superseded by `library-edit-seam.md`: the "later candidate" this note bet on is #2, and it
  removed both unused `ProfileLibraryController` forwards. The sentence above describes the state at
  #1, not the head of the chain.
