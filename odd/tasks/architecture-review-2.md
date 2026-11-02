# Architecture review 2 — what was explored and what was left

Second deep-module review of the package, run after the five slices of the first one (mapping write,
library edit seam, control facts, action names, pad performance). The report named seven candidates;
this document records the verdict for every one of them so the next explorer does not re-derive them.

Candidates C1, C3 and C2 are implemented in this branch and have their own feature documents:
`odd/tasks/pad-reconnect.md`, `odd/tasks/library-controller-seam.md`, `odd/tasks/emulation-run.md`.

## Decisions

### C1 — pad link seam → **narrowed and implemented**

The card proposed a `PadLink` port with two adapters. Reading `ControllerService` shows the port is
premature: the only thing that varies across that seam today is the device itself, and a fake
transport would have to imitate `IOUSBHostPipe`'s asynchronous read/re-arm cycle to be worth
anything — a large adapter bought for one test suite.

What the friction actually is: the reconciliation branch (healthy link, stale link, candidate,
nothing found) is entombed inside a class that also owns IOKit scanning, I/O and publication, so no
test can reach it. Decision: extract the branch, keep the transport. See `pad-reconnect.md`.

### C2 — one interface for the emulation run → **implemented as a composition module**

The card also claimed the engine's public methods are never tested. They are exercised through
internal siblings (`setEnabledNow`, `handle`, `tick`, `advance`), which the depth vocabulary allows:
an *internal* seam used by the module's own tests is legitimate, and exposing it would be worse.

The friction that survives that correction is the composition: eleven wires created inside
`EmulationController.attach`, in a target with no test target. Decision: move the composition — not
the engine's internals — into `NaconCore`. See `emulation-run.md`.

### C3 — collapse the forwarding wall → **implemented**

27 one-line forwards over a `library` the controller already publishes. See
`library-controller-seam.md`.

### C4 — the Captura owns its own module → **delivered** (`95cb3b7`, `odd/tasks/capture-module.md`)

Evidence: `MappingCapture` lives in `MappingEditor.swift:350`, and `PadGraphView` reads
`capture.session.isArmed`, `.armedControl` and `.intent` at `:97, :146, :244, :373` to re-derive
"which cell is armed". `ProfileSection` sets `onFinish` at `:97` and ends the capture at `:110`;
`MappingEditor` ends it on disappear at `:110`.

Verdict: real, small, and independent of this delivery. The slice is: move the type to its own file,
replace the published `session` with `armed(for:) -> MappingColumn?`, keep `KeyCaptureSession`
private to the implementation. Two adapters are not needed — the solitaire is the pure session, which
is already tested in `KeyCaptureSessionTests`.

It shipped after C1–C3 on the same branch, as its own commit, once the files it touches had stopped
moving.

### C5 — one renderer for "what a Control sends" → **delivered, narrowed** (`36cc3c9`, `odd/tasks/mapping-line.md`)

Evidence: the reserved PS row is drawn twice (`ProfileSection.swift:153` and `MappingEditor.swift:150`),
the drawing strip re-derives the same sentence at `PadGraphView.swift:355`, and the catalog carries two
keys for it (`Localizable.xcstrings:1045` and `:1055`). The base + Capa MOD presentation is derived
again in `MappingSummaryWindow.swift:128-138` and `:158-170`.

Verdict: extract the *derivation* only — `(control, column, Perfil) -> text` plus `isReserved`. Do not
unify the row layouts: the table shows two columns with buttons, the strip shows one line, the summary
shows a grid, and that difference is design, not duplication.

Delivered in the same shape: `MappingLine` in the core, layouts untouched, one sentence and one
pattern instead of two keys each. The derivation went to `NaconCore` rather than the app precisely
because the app has no test target, so the rule is now covered instead of merely relocated.

### C6 — split `ProfileLibrary` → **declined for now**

Evidence: 519 lines, 47 public declarations, six sections (`:106` management, `:209` stepping,
`:266` settings, `:325` sensitivity, `:362` Capa MOD, `:445` mapping write, `:497` coding).

The deletion test fails. The selected-profile resolution (`selectedIndex`, private at `:269`) has to
stay with the array it indexes; every candidate split either hands the array to a second module or
duplicates the resolution guard. `editSelectedProfile` (`:282`) already concentrates all mutation, and
the per-setting bodies are one-liners over `InputProfile`, `ProfileLayer` and `CursorSensitivity`,
which are their own modules.

Decision: `ProfileLibrary` stays one module. Its size is a review cost, not a design cost. Reopen it
only if a second consumer of per-Perfil editing appears (a CLI that edits `profiles.json` would be
exactly that) — then the split has two callers and stops being file-shuffling.

The price of that decision was paid immediately: C3 added five selected-profile operations to the
same type (579 lines, 52 public declarations, and a `type_body_length` advisory from the linter). The
app-facing interface shrank from 27 members to 2, so the net is fewer places to learn, but the core
type is now the largest file in the package. That is the trade this decision chose, and it is the
number to look at if this candidate comes back.

### C7 — `InputProfile.swift` as a vocabulary file → **deferred**

Ten public types, ~53 declarations, one file. It is a move, not a design change: no interface moves,
no behaviour changes. Verdict: do it in the next commit that changes any of those types for a real
reason, so the churn has a purpose.

## Also found, out of scope

- `docs/pruebas-debiles.md` records two tests that cannot fail for the right reason (a pure-function
  guard test and a fixture where "first profile" equals "standard profile"). Still open.
- `Sources/NaconCore/Localization.swift:19` is process-global mutable state in the "pure" target, and
  `AppLanguage.swift:34-44` talks to `UserDefaults` from it. Every test that pins a language has to
  save and restore it. Not a deepening candidate with two adapters behind it; noted for whoever
  touches localization next.

## Log

- **L1.** Request (verbatim): «Let's explore all of the worthy and leave them documented. After that,
  let's implement al the strong».
- **L2.** Reading order: `ControllerService` in full, `EmulationEngine`'s public surface and its test
  usage, `EmulationController` in full, `ProfileLibrary` sections 100-486, `MappingCapture` in full,
  `MappingEditor`/`PadGraphView`/`ProfileSection`/`MappingSummaryWindow` at the cited lines, the
  catalog keys, `Package.swift` targets. Two read-only exploration passes had already mapped both
  targets before this branch existed.
- **L3.** Two of the seven cards overstated their case and are narrowed above rather than implemented
  as written (C1's port, C2's "public API untested" claim). The reviewer of this document should read
  those two decisions before judging the feature documents.
- **L4.** The branch was used with the pad after the last commit and no defect appeared; the record of
  what that does and does not cover is in `docs/manual-acceptance.md`. One check is still worth doing
  before a merge, because this branch moved the path it exercises: step 40, where the permission
  really is absent.
- **L5.** Merged into `main` at the user's request as `a87d6ae` (`Merge branch
  'feature/architecture-deepening'`, `--no-ff`, following the convention of `profile-colour`,
  `mod-layer` and `ux-shell`). Twelve commits, 32 files, 1995 inserted and 605 removed. `main`
  verified after the merge: `swift build` clean with no warnings, `swift test` → 474 tests, 0
  failures. The feature branch is kept where it is instead of deleted, and the push to `origin/main`
  is not made: it stays the user's decision.
