# Control facts

One control, one table. The facts the app reads about a single control — its stored key, its label,
its tint and its pointer radius — are answered by one lookup built from one exhaustive switch, so the
compiler walks every case of the enum instead of trusting a count. The mask name is not a field: the
asset is named after the stored key, so the key is also the mask. The measured position and the mask
artwork themselves stay in `PadLayout` and `prototype/tools/make-masks.py`, which are tables of data,
not of labels.

## Specs

- **S1.** Request (verbatim): «good. continue with the proposed tasks in order» — C2 of the review,
  *Collapse the seven parallel tables over one control*.
- **S2.** Card, Solution (verbatim): «A `ControlFacts` value built by a single exhaustive switch, read
  through one lookup; each existing table becomes a field and each caller reads the field it needs.»
- **S3.** The persisted format does not change: the profile keys stay byte-identical, and a test pins
  the exact key set so a rename cannot slip into `profiles.json`.
- **S4.** Two protocol tables stay where they are, and the code says why: the protocol bit
  (`XInputButtons.mask` / `isPressed`) belongs to the XInput decoder, and `XInputControl.rawValue` is
  the diagnostic glyph the live grid prints, not the label a dialog shows. Two per-control data tables
  also stay: `PadLayout.standard` holds the measured positions and `prototype/tools/make-masks.py`
  holds the mask artwork. Adding a control still breaks the build in this catalogue and still fails
  `PadLayoutTests`, and it also needs its mask row in the Python tool — the "one edit" claim is about
  labels and keys, not about the artwork.
- **S5.** Every case of `XInputControl` answers with facts; one test walks `allCases` instead of
  trusting a count.
- **S6.** No behaviour change: same labels, same tints, same mask files, same hit radii, same JSON.

## Tasks

| ID | Spec | Route | Commit |
| --- | --- | --- | --- |
| T1 | S2, S5 | `ControlFacts` in `NaconCore` with its tests (profile key, label, mask name, tint, hit radius) | `8c72763` |
| T2 | S3, S4, S6 | `ProfileCoding`, `MappingRules`, `ControlTint` and the drawing read the facts; JSON pinned | `8c72763` |

## Delivery

One commit, 67 insertions and 169 deletions over 9 files plus two new files: the tables and the
callers that read them cannot compile apart, and the moved assertions are part of the same change.

## Log

- **L1.** «good. continue with the proposed tasks in order»
- **L2.** The card counted higher than the code: five switches across four files (stored key, label,
  tint, hit radius, mask name — the last two in the same file) plus one derived reverse dictionary,
  not seven tables in seven files. `ControlFacts` documents the real count. The card was also wrong
  that a mask-name field was needed: the generator names each file after the stored key.
- **L3.** Evidence: `swift test` → 322 tests, 0 failures, run by the parent; the 17 labels, keys,
  tints, radii and mask names were compared against `git show HEAD:` tables one by one; the stored
  key set is pinned by a coding test that spells the strings out.
