# Library controller seam

`ProfileLibraryController` stops restating the Biblioteca's interface. Views read the published
library, and every write goes through one `edit` that keeps the sequencing the controller exists for:
apply, drop a no-op, normalize, publish, save.

## Specs

- **S1.** Request (verbatim): «Let's explore all of the worthy and leave them documented. After that,
  let's implement al the strong».
- **S2.** Decision, verbatim from the review card: «Views read the published Library and write through
  one `edit(_:)` that keeps the sequencing the module exists for — change, normalize, save, report the
  failure — so its implementation stays deep.»
- **S3.** `edit` keeps the order and the guards the current `mutate` has: the change runs first, an
  unchanged library is dropped, `normalized()` runs before publication, publication happens before the
  save, and a failed save reports one sentence while the change stays on screen.
- **S4.** No behaviour changes. Every action the window performs reaches the same `ProfileLibrary`
  operation as before, and no test in `NaconCoreTests` is edited to accommodate this slice.
- **S5.** Reads move to the library itself: `profiles`, `selectedProfile`, `canDeleteProfile`,
  `runtimeProfile`, `selectedColor`, `selectedLayer`, `selectedInvertVerticalAxis`,
  `selectedNextProfileID`, `selectedValue(for:)`, `layerValue(for:)`, `saveFailure`.
- **S6.** No rule moves. The slice deletes forwards in the app target and adds five delegations to
  `ProfileLibrary` — `deleteSelectedProfile()`, `renameSelectedProfile(to:)`, `setLayerKey(_:)`,
  `setPrecisionScale(_:)`, `clearLayer()` — each of which resolves the profile on screen and calls the
  identifier-taking original unchanged. They exist so that no view resolves a profile identifier to
  drive an edit; the guards, the clamping and the `.none` rule all stay where they were.

## Tasks

| ID | Spec | Route | Commit |
| --- | --- | --- | --- |
| T1 | S2, S3 | `ProfileLibraryController`: one `edit`, the forwards removed | `9ee70be` |
| T2 | S5, S4, S6 | Views read through `profiles.library`, then the full suite | `9ee70be` |
| T3 | S1, S2 | this document and `odd/tasks/architecture-review-2.md` | this commit |

## Delivery

One commit of about 510 authored lines. The controller and its call sites cannot compile apart, so
the alternative was a transitional shim that would have kept the forwards alive — the layering this
change removes. Same reasoning the repository recorded for `mapping-write.md`. The core additions
travel with it because the views need them to stop resolving profile identifiers by hand.

## Log

- **L1.** «Let's explore all of the worthy and leave them documented. After that, let's implement al
  the strong»
- **L2.** Counted before the slice: 27 member declarations in the controller, 23 references to
  `library`, one call site per setter. `library` was already public and already read directly from
  `EmulationController`.
- **L3.** Two derivations did not move into the core: `otherProfiles` and `selectedPrecision` became
  two lines in the one view that shows each. Growing `ProfileLibrary` for a display fallback would
  work against the decision recorded in `architecture-review-2.md` (C6 declined, module already 519
  lines). If a second surface needs either, they move together.
- **L4.** An independent read compared `edit` with the removed `mutate` step by step and found the
  order intact; it confirmed that no operation returns `false` after mutating, so replacing the
  change's `Bool` with whole-library equality skips nothing that used to run. It also caught S6's
  earlier claim that `NaconCore` was untouched, which the same commit contradicts; S6 and the task
  table now name the five delegations.
- **L5.** Evidence: `swift build` clean with no new warnings; `swift test` → 453 tests, 0 failures
  (443 + the ten new `SelectedProfileOpsTests`); no existing test file edited; every remaining
  `profiles.` reference in the app target is `profiles.library.*` or `profiles.edit { ... }`, plus
  `profiles.saveFailure`, which is the controller's own published message and not a library member.
