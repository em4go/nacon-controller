# Emulation run

The emulation's behaviour — silence, Guide, profile step, the mapping summary, the permission gate —
leaves the window and becomes one module in `NaconCore` with one published status. The window keeps
what is genuinely AppKit: the permission prompt and its poll, the panel, the observers, the quit flush.

## Specs

- **S1.** Request (verbatim): «Let's explore all of the worthy and leave them documented. After that,
  let's implement al the strong».
- **S2.** Decision, verbatim from `odd/tasks/architecture-review-2.md`: «move the composition — not the
  engine's internals — into `NaconCore`.»
- **S3.** `EmulationRun` owns the engine and publishes one value: running, stopped by the pad, started
  by the pad, pad silent.
- **S4.** Every rule is preserved: a start needs the Accessibility permission and returns `false` —
  the window prompts and nothing was started — instead of starting; the Perfil in force is read at start and not while running; a
  Guide press starts while stopped and stops while running; the pad going silent raises the flag and
  coming back clears it; MOD+PS asks for the mapping summary through one callback; a profile step is
  applied only while running and goes through the engine's atomic switch; the pad disconnecting stops
  the run and clears the silence flag.
- **S5.** The window keeps `EmulationController` and its published state, so no view changes; the
  controller derives its flags from the run's status instead of restating them.
- **S6.** The summary's content decision — the Perfil in force and the title, with «Standard profile»
  when nothing is selected — lives in the run, and the panel only renders what it is given.

## Tasks

| ID | Spec | Route | Commit |
| --- | --- | --- | --- |
| T1 | S3, S4, S6 | `Sources/NaconCore/EmulationRun.swift` + `Tests/NaconCoreTests/EmulationRunTests.swift` | `88c5f25` |
| T2 | S5, S4 | `EmulationController` becomes the adapter: one status sink, permission prompt, panel, observers | `2bb2b06` |
| T3 | S1, S2 | this document plus the report to the user | this commit |

## Delivery

Two commits, split where the branch stays green on its own: the run and its tests first (513 lines
inserted, the app untouched because nothing referenced the new module yet), then the adapter (83
inserted, 142 removed). Each is reviewable alone and only the second one may need the app opened.

## Log

- **L1.** «Let's explore all of the worthy and leave them documented. After that, let's implement al
  the strong»
- **L2.** The card claimed the engine's public methods are untested; they are exercised through
  internal siblings, which is a legitimate internal seam. Only the composition moves.
- **L3.** Two things surfaced while moving it, both recorded rather than hidden. The standard title
  was resolved from the **app** catalog; the run resolves it from the core one, so the entry had to
  be added or Spanish windows would have read an English sentence. And the engine reports its own
  emergency stop on the main queue, so a test that drives the run must wait for that hop: the guide-
  stop case does, deliberately.
- **L4.** An independent read walked the moved rules one by one and confirmed every one; it also
  confirmed no retain cycle (all six callbacks and the summary callback are `[weak self]`) and that the
  summary's `dropFirst` guard cannot swallow a real stop. Three findings came back and are fixed: a
  step test that never reached the run's guard because the engine stops emitting before it, a
  disconnect test that compared two all-false statuses, and `drain()` waiting synchronously without the
  queue-key guard `stop()` has.
- **L5.** Evidence: `swift build` clean, no new warnings; `swift test` → 465 tests, 0 failures
  (453 + twelve `EmulationRunTests`); no existing test file edited; the 39 view call sites of
  `emulation.isEnabled`/`stoppedByPad`/`startedByPad`/`padSilent`/`hasAccessibility` compile
  unchanged, because the controller kept the names and derives them from one published status.
