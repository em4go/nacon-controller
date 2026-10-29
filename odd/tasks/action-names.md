# Action names

An action carries its own name the same way a key combo already does, so the rules enum stops
holding display copy and every surface that prints a mapping reads one property.

## Specs

- **S1.** Request (verbatim): «good. continue with the proposed tasks in order» — C5 of the review,
  *Let an action name itself, and derive one reading*. Only the first half is built; the second half
  is dropped on purpose (see L3).
- **S2.** Card, Solution (verbatim, first half): «Give `MappedAction` a `displayName` beside
  `KeyCombo.displayName` […]».
- **S3.** The visible text does not change: every label is byte-identical to what
  `MappingRules.label(for:)` prints today, including the singular/plural scroll wording.
- **S4.** `MappingRules` keeps invariants and step editing and loses display copy: after this and
  the control-facts change it holds no user-facing string at all.
- **S5.** The label tests move with the code instead of being deleted: one place asserts the text of
  every action case.

## Tasks

| ID | Spec | Route | Commit |
| --- | --- | --- | --- |
| T1 | S2, S3 | `MappedAction.displayName` in the file that declares the value; call sites read it | `bd7cde5` |
| T2 | S4, S5 | `MappingRules.label(for:)` deleted; label assertions move to `MappedActionTests` | `bd7cde5` |

## Delivery

One commit, 42 insertions and 73 deletions over 8 files plus one new test file. The move cannot be
split: deleting the rules label and pointing eleven call sites at the property has to compile at once.

## Log

- **L1.** «good. continue with the proposed tasks in order»
- **L2.** Scope correction found before the first edit: `MappingRules.label(for:)` has a ninth call
  site in `Tests/NaconCoreTests/SequenceActionTests.swift`, outside the surfaces the brief allowed.
  Authorized, and the sequence label test moves into `MappedActionTests` rather than staying behind
  with a one-line redirect, so one file keeps every label assertion (S5) instead of two.
- **L3.** The second half of the card — one `ControlReading` printed by table, strip and summary — is
  dropped. The three surfaces compose a row differently *by design*: the summary omits unassigned
  controls, the strip appends «· MOD …» only when the layer redefines the control, and the table
  prints «—» for a control the layer leaves to the base. A shared reading would need a flag for each
  of those differences, i.e. an interface as wide as its three call sites; the part that is genuinely
  shared is the text of one cell, which is exactly this `displayName`.
- **L4.** Evidence: `swift test` → 328 tests, 0 failures, run by the parent; the moved switch was read
  against the old body (same case order, same singular/plural branch, same strings); no string literal
  is left in `MappingRules.swift`.
