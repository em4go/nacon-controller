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
  waiting. The session and the event monitor stay private to its implementation; only a finished
  capture's `KeyCaptureSession.Outcome` still crosses, because that is the value `MappingWrite`
  resolves and the section applies.
- **S4.** No behaviour change. Arming, cancelling, the refusal while emulation runs, ending the
  capture when the editor disappears, when the profile changes and when emulation starts, and the one
  `onFinish` per finished capture all stay exactly where they are and do exactly what they do.
- **S5.** The drawing stops reading session state: `PadGraphView` references no `capture.session`, and
  the table asks for a column instead of testing two booleans.
- **S6.** The views keep their own layout and their own wording; only the questions they ask change.

## Tasks

| ID | Spec | Route | Commit |
| --- | --- | --- | --- |
| T1 | S2, S3 | `Sources/NaconDiagnostics/MappingCapture.swift` (new), the type and the `NSEvent` modifier helper out of `MappingEditor.swift` | `95cb3b7` |
| T2 | S4, S5, S6 | `MappingEditor` and `PadGraphView` ask the new questions, then suite and build | `95cb3b7` |
| T3 | S1, S2 | this document and `architecture-review-2.md` | this commit |

## Delivery

One commit, 218 inserted and 167 deleted: the type moves (175 lines into the new file, 157 out of the
view file) and the call sites ask the new questions. The app target has no test target, so the slice
is verified by the whole suite plus the compiler: `session` is `private`, which makes «no view reads
the session» a build error rather than a convention.

## Log

- **L1.** «continue with c4 and c5»
- **L2.** The card named `armed(for:) -> MappingColumn?`; the drawing also needs «is anything armed»
  for its `onChange`, so the module answers that too. Keeping a derived boolean there rather than an
  optional control preserves the current behaviour: re-arming a different control does not clear the
  strip's last pick, and testing the optional would.
- **L3.** Evidence: `swift build` clean with no new warnings; `swift test` → 465 tests, 0 failures;
  `MappingEditor.swift` 486 → 331 lines at that commit; `grep -rn "capture\.session|isCapturing("`
  over the app target finds nothing. The move also dropped a doc comment left orphaned above a MARK
  when the colour rule moved to `ControlFacts`, and an `import AppKit` whose only user left with the
  type.
- **L4.** An earlier draft of this log claimed the move added `@MainActor` to the class. It did not:
  `git show 95cb3b7^:Sources/NaconDiagnostics/MappingEditor.swift` already annotates it, so isolation
  did not change and no call site was at risk. Corrected after an independent read compared the two
  versions of the class, which also confirmed `follow`, `end`, `deinit`, the monitor's install and
  removal, and the single `onFinish` are textually unchanged.
