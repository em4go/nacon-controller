# Pad performance

The behaviour of a press — hold it, repeat it, run a command one step per tick, scroll, move the
cursor — leaves the engine and becomes one value that takes time as an argument and returns what to
emit. The engine keeps the queue, the clock and the safety net.

## Specs

- **S1.** Request (verbatim): «good. continue with the proposed tasks in order» — C3 of the review,
  *Split the performance of a mapping from the clock*.
- **S2.** Card, Solution (verbatim): «Move the per-press behaviour into a `PadPerformance` value with
  `press/release/advance` returning effects; the engine keeps the queue, the clock, enable/disable
  and the release-everything safety net.»
- **S3.** `PadPerformance` holds no timer, no queue and no clock: `press`, `release`, `advance(seconds:)`
  and `reset` take everything they need as arguments and return an ordered list of effects. Time is a
  number the caller measured, never something the value waits for.
- **S4.** The engine keeps what depends on the report rather than on the action: the edge
  computation, reading the layer at press time, the Guide and MOD+PS branch and its ordering, the
  timer, the App Nap activity, enable/disable and the final release of every held modifier.
- **S5.** No behaviour change, and the proof is the tests that already exist: `EmulationEngineTests`,
  `SequenceEngineTests`, `SummaryPressTests` and `MouseMovementTests` pass **untouched**.
- **S6.** One place per action kind: the inline `.scrollLines` / `.sequence` / `.key` branches leave
  `handle`, so a new kind of action is one case instead of a hunt through the engine.

## Tasks

| ID | Spec | Route | Commit |
| --- | --- | --- | --- |
| T1 | S3, S6 | `PerformanceEffect` and `PadPerformance` (press, release, one command step per advance, repeat, cursor and scroll integration, reset) with their own tests | `f947677` |
| T2 | S4, S5 | The engine delegates and emits effects; existing engine tests untouched | `f947677` |

## Delivery

One commit, 38 insertions and 106 deletions in the engine plus two new files. It cannot be split: the
engine has to hand its fields to the performance in the same change that removes them, and the new
tests pin what the moved code does. Counted alone it is the largest slice of the series, so it ships
last, on a quiet tree, with the four pre-existing engine suites as the acceptance test.

## Log

- **L1.** «good. continue with the proposed tasks in order»
- **L2.** Evidence: `swift test` → 344 tests, 0 failures, run by the parent after the commit; the four
  acceptance suites (`EmulationEngineTests`, `SequenceEngineTests`, `SummaryPressTests`,
  `MouseMovementTests`, 42 tests) passed untouched, and `git status` showed no modified test file. The
  effect ordering was read against the old `handle`/`tick`/`disableOnQueue`: same press order (scroll,
  command, hold), same repeat gate and "one per advance, due from elapsed" rule, same advance order,
  same release-before-press emission, Guide still after the layer read, safety net unchanged.
