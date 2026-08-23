# calamus-2016

A real bus-route creel survey: Calamus Reservoir, 2016-06-06 through 2016-06-12,
24 interviews across three sites (North, South, Pier) on one circuit. Bank-only —
`angler_boats` and `non_ang_boats` are zero throughout.

`reference-outputs.csv` is the only set of validated end-to-end numbers in this
repo. Everything else that looks like a reference is arithmetic on invented data.

## Provenance of reference-outputs.csv

Written once at v1.7.0 (`e58ac721`) from the pipeline in
`inst/validation/calamus-2016-validation.R`. The fixture inputs have not changed
since: v1.8.0 (`6db02a43`) renamed the `counts.csv` header
(`angler_count` -> `bank_anglers`/`angler_boats`/`non_ang_boats`) without
touching a single value.

The file is **not** regenerated as a matter of routine. Rewriting it to match
current output asserts the package against itself and destroys the only evidence
that a number moved. Regenerate a row only after establishing, from the source
history, which release moved it and why — and record that here.

## Re-baselined rows

### `catch_total` standard error, v3.0.0 — 55.7238941653612 -> 52.9963220587336

The point estimate (313.190476190476) is unchanged, and was unchanged throughout.

v3.0.0 (`58e0424b`, PR #114, the dimensional seam audit) routed all three
bus-route totals through `br_complete_trips_only()`. Before it,
`estimate_total_catch_br()` applied no trip filter at all, while
`estimate_total_harvest_br()` already filtered inline — so the v1.7.0 file
recorded an unfiltered catch SE alongside a filtered harvest SE.

This fixture carries two incomplete-trip rows (`interview_uid` 5, 2016-06-07),
both with `catch_count = 0`. They contribute nothing to the Horvitz-Thompson sum,
so filtering them cannot move the point estimate — but it drops the interview
count from 24 to 22 and therefore does move the variance. Point-estimate
invariance under the filter is what zero-catch rows produce by construction; it
is not evidence that the filter is irrelevant to the SE.

Verified rather than assumed: disabling the filter on current code (relabelling
those two rows `complete`) reproduces 55.7238941653612 exactly, and the
pre-v3.0.0 source confirms the catch path had no filter. The v1.7.0 behaviour is
no longer reachable — `estimate_total_catch(use_trips = "all")` now aborts on
bus-route designs, because an uncompleted trip contributes catch-so-far under the
inclusion probability of a completed one.

`harvest_total` and `effort_total` are untouched, and have reproduced bit-for-bit
from v1.7.0 to now. See GH #178.
