# Apply the accepted review fixes to the 5 stacked refactor PRs

The five PRs were reviewed slice by slice (`.build/review/pr-1.md` … `pr-5.md`) and adjudicated in
`.build/review/decision.md`. This feature implements every accepted finding, each on the branch that
owns it, with the downstream branches rebased.

## Specs

- **S1.** Implement exactly the items marked *Accepted* in `.build/review/decision.md`; leave every
  item marked *Rejected* untouched.
- **S2.** No behaviour change beyond what each accepted finding asks for. No persisted-format change,
  no new dependency, no public contract broken beyond the two agreed narrowing edits
  (`MappingWrite.resolve` signature, `ControlFacts.init`/`PadPerformance` visibility).
- **S3.** `swift test` must be green on every branch after its own fixes and again on the stack tip.
  Each fix's test asserts an observable effect and would fail if the fix were reverted.
- **S4.** The simplicity rulings hold: no `maskName` field, no ordered structure behind
  `advanceCommands`, no `plural(_:)` helper, no shared row model, no merged `CaptureMode`.
- **S5.** Commits stay on their own branch as reviewable work units, with tests and docs alongside the
  behaviour; downstream branches are rebased onto the fixed parent; **nothing is pushed**.
- **S6.** The review artifacts under `.build/review/` stay untracked; the project-local
  `.pi/agents/refactor-reviewer.md` is left in place and reported, not committed.

## Tasks

| ID | Branch | Work | Commit |
|----|--------|------|--------|
| T1 | `pr/1-mapping-write` | PR1-01 resolve takes one `StoredProfile?`; PR1-02 apply-guard tests; PR1-04 delete the copied write rule from the tests; PR1-05 toggle is column-aware; PR1-03 drawing disarms on profile change; PR1-06/07/08/09 docs | `fix: a capture resolves against the profile it edits` |
| T2 | `pr/2-library-edit-seam` | PR2-02 drop the unreachable guard; PR2-01 pin the reset guard; PR2-03/04/05 docs | `fix: one edit seam keeps one rule` |
| T3 | `pr/3-control-facts` | PR3-04 pin the format; PR3-02 mask-file test; PR3-05/07/08/01 doc and surface corrections | `fix: the catalogue states what it covers` |
| T4 | `pr/4-action-names` | PR4-01 header, PR4-02 L2, PR4-06 header; PR4-04 `magnitude`; PR4-05 `displayName` in the enum body | `fix: an action name keeps its contract` |
| T5 | `pr/5-pad-performance` | PR5-01 advance-order test; PR5-03 reset test observes both halves; PR5-02/05/07 comments; PR5-04 one held map; PR5-08/09/10 | `fix: the performance keeps one clock per key` |

## Log

- **L1.** "I want to review all 5 PRs in this repo for refactoring the codebase. Invoke one subagent
  for each to check everything needed in the refactor. Well written tests that probe real situations,
  maintainable and composable code, etc. Make sure each of the subagents propose exact fixes for each
  smell / error / bug they find and write them in a temporal file for that agent so they don't
  interfere. Your task is to overview the work of the agents and have the final decision on wether to
  follow the subagents review or not. One important rule: if something can be done simpler and
  reaching the same result, we should probably do it simpler"
- **L2.** "go with all of them" — authorizes implementing the accepted set, including the follow-up
  slices, on their own branches.
- **L3.** Review-time corrections already made: PR3-01's "compiles unclickable" is false (no `default`
  in `ControlFacts.of`, and `PadLayoutTests` pins the layout); PR4-03 is covered by
  `KeyCatalogTests:68`; PR1-03's leak predates PR1 (`fcad4d0` already armed from the drawing).
- **L4.** T1 on `pr/1-mapping-write`: PR1-01's one-argument `resolve` now has its four test call sites
  updated too; PR1-02 added the three `ProfileLibrary.apply` guard tests (another profile in either
  column, the never-remappable PS, no profile at all); PR1-05 made `KeyCaptureSession.toggle`
  column-aware with its doc and one new test, `arm` untouched; PR1-04 replaced the copied write rule in
  `KeyCaptureSessionTests` with `resolve` + `apply` against a real library; PR1-03 has `PadGraphView`
  end the capture in `onChange(of: profileID)`; PR1-06/07/08/09 corrected README, GLOSSARY,
  `manual-acceptance.md` row 19 and `mapping-write.md` S6/T2/delivery/L3. `swift test` → 318 tests, 0
  failures (314 before: +3 guards, +1 toggle).
- **L4.** T1 done on `pr/1-mapping-write`: `resolve` takes one `StoredProfile?`; three guard tests added
  (F5 in either column, PS refusal, no profile); the copied write rule left the capture tests in favour
  of `resolve` + `apply`; `toggle` matches control, profile and column; the drawing ends a capture when
  the profile changes; the PR1 docs corrected. `swift test` → 318 tests, 0 failures.
- **L5.** Slice boundary: the fixes ride on `pr/1-mapping-write`, whose own 1129-line slice cannot
  split (the core type, its tests and the view call sites do not compile apart — `mapping-write.md`
  records the same boundary). Each review fix is its own small commit; no commit here adds a new
  oversized unit.
- **L6.** T2 on `pr/2-library-edit-seam` (rebased onto the fixed #1): the unreachable `isRemappable`
  guard left `ProfileLibrary.setAction`; the reset-guard and no-selection cases are pinned; the log's
  own counts and #1's L3 supersession corrected. `swift test` → 320 tests, 0 failures.
- **L7.** T3 on `pr/3-control-facts` (rebased): the mask files are compared with the stored keys; the
  JSON pin asserts its own premise; `ControlFacts.init` is internal; the doc states which per-control
  tables the catalogue does not own. `swift test` → 329 tests, 0 failures.
- **L8.** T4 on `pr/4-action-names` (rebased): `displayName` lives inside the enum and uses `magnitude`
  (pinned by a rendering test); the stale header and the duplicated `L2` are fixed. `swift test` → 336
  tests, 0 failures.
- **L9.** T5 on `pr/5-pad-performance` (rebased): the advance order and the reset behaviour are pinned;
  `advanceCommands` no longer claims an order a map cannot give; the three held maps are one; the two
  types are internal; the stale owner comments and the task file corrected. `swift test` → 353 tests,
  0 failures. All five branches rebased in order; nothing pushed.
