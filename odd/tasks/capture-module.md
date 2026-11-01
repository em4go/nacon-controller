# Captura module

`MappingCapture` leaves the view file it grew inside and stops publishing its key session. The two
mapping surfaces ask it questions instead of reading its state, so «which cell is waiting for a key»
is derived in one place.

## Specs

- **S1.** Request (verbatim): «continue with c4 and c5».
- **S2.** Decision, verbatim from `odd/tasks/architecture-review-2.md`: «The slice is: move the type to
  its own file, replace the published `session` with `armed(for:) -> MappingColumn?`, keep
  `KeyCaptureSession` private to the implementation.»
- **S3.** `MappingCapture` lives in its own file and publishes no session. It answers three questions:
  which control is armed, whether anything is armed at all, and which column of a given control is
  waiting. `KeyCaptureSession` and the event monitor stay private to its implementation.
- **S4.** No behaviour change. Arming, cancelling, the refusal while emulation runs, ending the
  capture when the editor disappears, when the profile changes and when emulation starts, and the one
  `onFinish` per finished capture all stay exactly where they are and do exactly what they do.
- **S5.** The drawing stops reading session state: `PadGraphView` references no `capture.session`, and
  the table asks for a column instead of testing two booleans.
- **S6.** The views keep their own layout and their own wording; only the questions they ask change.

## Tasks

| ID | Spec | Route | Commit |
| --- | --- | --- | --- |
| T1 | S2, S3 | `Sources/NaconDiagnostics/MappingCapture.swift` (new), the type and the `NSEvent` modifier helper out of `MappingEditor.swift` | — |
| T2 | S4, S5, S6 | `MappingEditor` and `PadGraphView` ask the new questions, then suite and build | — |

## Log

- **L1.** «continue with c4 and c5»
- **L2.** The card named `armed(for:) -> MappingColumn?`; the drawing also needs «is anything armed»
  for its `onChange`, so the module answers that too. Keeping a derived boolean there rather than an
  optional control preserves the current behaviour: re-arming a different control does not clear the
  strip's last pick, and testing the optional would.
