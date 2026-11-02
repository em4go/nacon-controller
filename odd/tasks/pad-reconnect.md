# Pad reconnect

The decision "keep the link, reopen it, or say the Mando is gone" leaves `ControllerService` and
becomes one pure function, so the rule with the worst failure mode stops being reachable only by
unplugging hardware. The IOKit and IOUSBHost calls stay where they are.

## Specs

- **S1.** Request (verbatim): «Let's explore all of the worthy and leave them documented. After that,
  let's implement al the strong».
- **S2.** Decision, verbatim from `odd/tasks/architecture-review-2.md`: «extract the branch, keep the
  transport.»
- **S3.** One pure function in `NaconCore` answers, from the devices a scan found, whether a link is
  open and how long it has been quiet, one of four outcomes: keep the link, connect to the device at
  an index (releasing the current link first or not), tear the link down and stop, or report
  «searching».
- **S4.** Behaviour is preserved exactly as the service has it today: a link quiet for at most the
  threshold keeps the link and the scan results are not used; a link quiet for longer is torn down in
  the same pass that attaches to the first readable device, when there is one; with no readable device
  and no open link the published state becomes `.searching`; with no readable device after a teardown
  the teardown reports the disconnect and moves `reconnectCount` exactly once, and the same pass then
  publishes `.searching` — which is what the code did before the extraction, because `teardown` clears
  the link before the old `if link == nil` was read.
- **S5.** The threshold stays 2.0 seconds and is a parameter of the function, so a test states it
  instead of waiting for it.
- **S6.** `ControllerService` keeps every IOKit and IOUSBHost call, including releasing the services it
  scanned: the function decides, the service performs.

## Tasks

| ID | Spec | Route | Commit |
| --- | --- | --- | --- |
| T1 | S3, S5 | `Sources/NaconCore/PadReconnect.swift` + `Tests/NaconCoreTests/PadReconnectTests.swift` | `ef8de9a` |
| T2 | S4, S6 | `ControllerService.reconcile` becomes the adapter that performs the outcome | `ef8de9a` |
| T3 | S1, S2 | this document, `architecture-review-2.md`, `odd/tasks/emulation-run.md` | this commit |

## Delivery

One commit. The function and the service that performs it cannot compile apart — an unused module
plus a rewritten `reconcile` is one change — and the slice is 234 authored lines, well inside the
review budget.

## Log

- **L1.** «Let's explore all of the worthy and leave them documented. After that, let's implement al
  the strong»
- **L3.** Evidence: `swift build` clean with no new warnings; `swift test` → 443 tests, 0 failures
  (434 + 9 new). The nine cases cover the inclusive threshold, a stale link replaced in the same pass,
  a stale link with nothing to attach to, an unreadable device refusing to be a candidate, and both
  «nothing is here» outcomes. A tenth pins the two seconds itself: the extraction must not widen the
  silence the service treats as a dead link.
- **L4.** An independent read confirmed all four outcomes against `origin/main`, the single
  `reconnectCount` move per stale teardown, no leaked or doubly released `io_service_t` on any path,
  and the `.quiet(0)` equivalence for a link with no stamp. It also caught this document claiming the
  state stayed `.disconnected` after a teardown; the code publishes `.searching`, as it always did,
  and S4 now says so.
- **L2.** The card asked for a `PadLink` port with two adapters. Reading the service showed a fake
  transport would have to imitate `IOUSBHostPipe`'s asynchronous read-and-re-arm cycle, and the only
  thing that varies across the seam today is the device itself. Port declined, decision extracted:
  the depth lives in the branch, not in the transport.
