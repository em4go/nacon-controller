# Library edit seam

Every edit that targets the profile on screen goes through one place in `ProfileLibrary`, so the
"find the selected profile, then mutate it" guard stops being copy-pasted into each setting and the
duplicate `setAction` disappears.

## Specs

- **S1.** Request (verbatim): «good. continue with the proposed tasks in order» — C4 of the review,
  *One edit seam for «the selected profile»*.
- **S2.** Card, Solution (verbatim): «Add one mutating seam, `editSelectedProfile`, that resolves the
  selection and applies a change; every existing setter becomes a one-line body and the duplicated
  `setAction` disappears.»
- **S3.** `setAction` exists once, in the same file as the type it edits, and refuses the reserved
  control exactly as it does today.
- **S4.** No caller-visible behaviour change: the existing suite passes untouched, including
  `ProfileLibraryTests`.
- **S5.** The controller loses the forwards the views no longer use (`setAction`, `setLayerAction`)
  and the duplicate rename (`rename(_:to:)` vs `renameSelectedProfile(to:)`).
- **S6.** The layer setters keep their explicit `profileID`: they edit the profile on screen, which
  is not always the selected one, and folding them into the selected-profile seam would lose that.

## Tasks

| ID | Spec | Route | Commit |
| --- | --- | --- | --- |
| T1 | S2, S3, S6 | `ProfileLibrary`: one `editSelectedProfile` seam, setters as one-line bodies, `setAction` moved next to `InputProfile` | `798bcb8` |
| T2 | S4, S5 | Controller cleanup, then the full suite | `798bcb8` |

## Delivery

One commit: the seam, the moved `setAction` and the controller cleanup are about 108 lines and every
part has to compile together. Counted alone the slice sits well under the review budget, even though
the feature branch keeps growing by a few hundred lines per candidate.

## Log

- **L1.** «good. continue with the proposed tasks in order»
- **L2.** The review card overstated this one. Most of the `firstIndex(where:)` guards it pointed at
  belong to the operations that name a profile by id (delete, rename, layer); two of them are
  selection lookups, and only one of those collapsed. `selectedIndex`'s call sites go 3 → 1 (the
  earlier 4 → 2 also counted its declaration), and the duplicate `setAction`, whose own lookup is gone
  (repo-wide 8 → 7). Kept anyway: the
  seam takes the "resolve, then mutate" pattern out of every future setting, which is the leverage the
  card promised even if the count was off.
- **L3.** Evidence: `swift test` → 314 tests, 0 failures, before and after, run by the parent; no test
  file in `git diff --name-only`; `profiles.setAction`, `profiles.setLayerAction` and `.rename(` have
  no callers left.
