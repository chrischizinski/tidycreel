# Statistical Seam Audit — tidycreel.connect ingestion → tidycreel estimators

**Date:** 2026-08-14 · **Audit 1 of 5** · Protocol: `/statistical-seam-audit` (full)

## Scope

The ingestion seam: raw source (CSV / NGPC REST API) → `fetch_*()` →
`creel_design()` / `add_counts()` / `add_interviews()` → estimators. Focus on the
boat→angler reconstruction path (`mean_party_size()` → `derive_angler_count()`),
flagged as unaudited in `.ai/repo-map.md`. DBI backend not audited (all methods
abort "not yet implemented"). No implementation code was modified.

Method: code trace of `tidycreel.connect/R/fetch-loaders.R`,
`fetch-validators.R`, `creel-connection-api.R`, `creel-connection.R`; consumption
side `R/creel-design.R` (`add_interviews`), `R/derive-angler-count.R`,
`R/creel-estimates-bus-route.R`; executed reproduction on the in-repo
`inst/extdata/calamus-2016/` fixtures.

## Workflows inspected

1. CSV → `fetch_interviews`/`fetch_counts` → instantaneous design → effort/CPUE/totals
2. CSV → `fetch_*` → bus-route design (`p_site`/`p_period`, `.expansion`)
3. API (NGPC field map) → same two paths
4. `fetch_release_lengths`/`fetch_harvest_lengths` → `add_lengths()` → length/biomass
5. `fetch_catch` → harvest aggregation (`catch_type == "harvested"`)

## Information-lineage ledger (ingestion stage)

| Quantity | Origin | Meaning | Unit | Known/est. | Uncertainty | Stored as | Consumers | Point preserved? | Variance preserved? | Grouping preserved? | Unit preserved? |
|---|---|---|---|---|---|---|---|---|---|---|---|
| party size (anglers/party) | source interviews (if recorded) | boat-occupancy multiplier | anglers/party | estimated | sampling SE (#121 machinery) | **nowhere — no map entry** | `mean_party_size` → `derive_angler_count` | **NO — dropped** | NO (never enters) | NO | n/a |
| angler type (bank/boat party) | source interviews (if recorded) | domain marker for party-size estimand | — | observed | — | **nowhere** | `mean_party_size(angler_type=)` | **NO** | n/a | NO | n/a |
| trip effort | `ii_TimeFishedHours(+Minutes)` / `effort_col` | hours fished by the interviewed unit (party) | party-hours | observed | — | `effort` | `add_interviews` → CPUE | yes | n/a | yes | **relabeled**: consumed as angler-hours under party=1 assumption |
| site / circuit | source interviews | π_i join keys (bus-route) | — | design | — | **dropped** | `add_interviews` bus-route join | **NO** | n/a | **NO** | n/a |
| n_counted / n_interviewed | source interviews | enumeration expansion `.expansion = nc/ni` | anglers | observed | — | **dropped** | `estimate_*_br` | **NO** | n/a | NO | n/a |
| bank_anglers | `c_BankAnglers` | anglers on shore at count instant | anglers | observed | — | `bank_anglers` | `derive_angler_count`/`add_counts` | yes | n/a | date only | yes |
| angler_boats | `c_AnglerBoats` | boats with anglers | **boats** | observed | — | `angler_boats` | `derive_angler_count(boat_count=)` | yes | n/a | date only | yes (doc warns) |
| count time / site / period id | source counts (if recorded) | within-day replicate structure | — | design | — | **dropped** (map has date only) | progressive counts, site domains | **NO** | n/a | **NO** | n/a |
| catch per interview (API) | `Num` in GetCatchData | fish per interview×species | fish | observed | — | `catch_count` via `fetch_catch` | user aggregation → `add_interviews(catch=)` | yes (user-assembled) | n/a | yes | yes |
| catch_type | `CatchType` | harvested/released/caught classifier | — | observed | — | raw pass-through | `catch_type == "harvested"` filters | value-dependent | n/a | yes | n/a |
| trip_status | `ii_TripType` | complete/incomplete estimator switch | — | observed | — | raw pass-through, `tolower()` only | `use_trips` dispatch | value-dependent | n/a | yes | n/a |
| release length | `ir_LengthGroup` | **length bin label** | claimed mm | observed | — | `length_mm` | `est_length_distribution`, `est_biomass` | **as bin label** | n/a | yes | **unverified** |
| release bin count | `ir_Count` | fish per length bin | fish | observed | — | **dropped** | length distribution weights | **NO** | n/a | NO | n/a |
| harvest length | `ihl_Length` | measured length | mm | observed | — | `length_mm` | same | yes | n/a | yes | yes |

## Findings

### Finding 1: The fetch layer has no route for party size or angler type, so party-level quantities silently become angler-level downstream

**Severity:** High (candidate Critical pending live-field confirmation)

**Workflow:** `fetch_interviews()` → `add_interviews()` → `estimate_catch_rate()` /
`estimate_total_catch()`; and `fetch_counts()` → `derive_angler_count()` (boat path)

**Information at risk:** anglers per interviewed party (`n_anglers`) and the
bank/boat party marker (`angler_type`).

**Statistical expectation:** Interview effort recorded per party must be
converted to angler-hours with the actual party size before entering CPUE
denominators; the boat count in `fetch_counts()` output must be expanded by a
boat-party mean (with its SE, per #121). Both require a party-size column and a
bank/boat marker from the interviews.

**Minimal reproduction (run 2026-08-14, calamus fixtures):**

```r
schema <- creel_schema(survey_type = "bus_route", interview_uid_col = "interview_uid",
  date_col = "date", catch_col = "catch_count", effort_col = "effort_hours",
  trip_status_col = "trip_status", bank_anglers_col = "bank_anglers",
  angler_boats_col = "angler_boats", non_ang_boats_col = "non_ang_boats")
conn <- creel_connect(list(interviews = ".../interviews.csv", ...), schema)
names(fetch_interviews(conn))
#> interview_uid, date, catch_count, effort, trip_status   — nothing else, no warning
```

Both rename maps are closed, hardcoded lists
(`fetch-loaders.R:88–94` CSV; `creel-connection-api.R:173–205` API defaults with
no `n_anglers`-like entry); `.rename_to_canonical()` / `.rename_api_to_canonical()`
(`fetch-loaders.R:36–66`) discard every unmapped column silently. `creel_schema()`
has no `n_anglers_col` field, so even a custom schema cannot route it on the CSV
backend.

**Expected result:** party size reaches `add_interviews(n_anglers=)` and
`mean_party_size()`.

**Actual result:** it cannot. `add_interviews()` then applies the party=1
assumption with only an `i`-level message ("assuming 1 angler per interview") —
not a warning; `mean_party_size()` has no in-pipeline input; the #121 party-size
SE machinery is unreachable from fetched data.

**Root cause:** `tidycreel.connect/R/fetch-loaders.R` hardcoded rename maps +
silent-drop rename helpers; `.default_api_field_map()$interviews` lacks any
party-size field.

**Downstream consequences:** CPUE/HPUE/RPUE denominators are party-hours
labeled angler-hours; composed with count-based effort (true angler-hours),
total catch/harvest/release scale by roughly the mean party size. The boat
component of `derive_angler_count()` is unusable, so count-based effort must
either omit boat anglers (Finding 7) or use a hand-carried multiplier without
its SE (defeating #121).

**Why existing tests missed it:** connect tests check fetched column names,
types, and values only; no test composes fetch output into a design or
estimator (verified: no connect test file references `creel_design`,
`add_counts`, `add_interviews`, or any estimator). The calamus fixture is a
bank-only fishery (`sum(angler_boats) == 0`), so the boat seam is never
exercised end-to-end anywhere in the repo.

**Recommended regression test:** integration test: source CSV containing a
party-size and angler-type column → fetch → `mean_party_size()` →
`derive_angler_count()` → `add_counts()` → `estimate_effort()`; assert the
party-size SE appears as `se_expansion`.

**Recommended correction (conceptual):** add optional `n_anglers`
(and `angler_type`) entries to both rename maps and `creel_schema()`; propagate
as optional validated columns. Separately: `add_interviews()`'s party=1
assumption arguably deserves `cli_warn` rather than `cli_inform` when
interviews came from a connect fetch — decide at fix time.

**Verify against live API:** whether `GetInterviewData` exposes a party-size /
angler-count field and its name. The drop-if-present behavior is confirmed in
code regardless.

---

### Finding 2: `fetch_interviews()` silently drops the bus-route design columns (site, circuit, n_counted, n_interviewed)

**Severity:** High

**Workflow:** `fetch_interviews()` → `add_interviews()` (bus-route/ice) →
`estimate_effort()` / `estimate_harvest_rate()`

**Information at risk:** π_i join keys (site, circuit) and the enumeration
expansion components (`n_counted`, `n_interviewed`).

**Statistical expectation:** bus-route estimators are Horvitz-Thompson sums
over interviews weighted by 1/π_i and expanded by `n_counted/n_interviewed`;
these columns must survive ingestion.

**Minimal reproduction:** as Finding 1 —
`LOST: site, circuit, effort_hours(renamed), n_counted, n_interviewed`, no
warning, on the package's own validated calamus bus-route fixture.

**Expected result:** fetched interviews feed the same pipeline
`inst/validation/calamus-2016-validation.R` validates.

**Actual result:** they cannot. `add_interviews()` aborts at the π_i join
(missing site/circuit), and `estimate_*_br()` aborts without `.expansion` —
loud, so no wrong number is produced, but the documented handoff ("ready for
`tidycreel::add_interviews()`", `fetch-loaders.R:69–82`; vignette workflow) is
impossible for the design family the fixture was built to validate. The
package's own validation script bypasses its own ingestion layer
(`read.csv` directly) — the strongest available signal that the seam has never
worked.

**Root cause:** same closed rename maps as Finding 1
(`fetch-loaders.R:88–94`); `creel_schema()` bus-route fields exist for the
sampling frame but fetch never maps interview-side site/circuit/n_counted/
n_interviewed.

**Downstream consequences:** every bus-route and ice workflow starting from a
connect source; users are forced into ad-hoc CSV reads that skip fetch-time
validation and type coercion.

**Why existing tests missed it:** same as Finding 1 — no composition test;
validation script sidesteps fetch.

**Recommended regression test:** fetch calamus via the CSV backend and
reproduce `reference-outputs.csv` end-to-end.

**Recommended correction (conceptual):** extend rename maps/schema with
optional bus-route interview columns; emit a message listing dropped source
columns (see Finding 6).

---

### Finding 3: Release lengths — per-bin fish count (`ir_Count`) is discarded and the bin label (`ir_LengthGroup`) is stored as `length_mm`

**Severity:** High (verify-live; becomes Critical if `ir_Count > 1` occurs or the group label is not in mm)

**Workflow:** `fetch_release_lengths()` → `add_lengths()` →
`est_length_distribution()` / `est_mean_length()` / `est_biomass()`

**Information at risk:** the number of fish each release-length row represents,
and the physical unit of the released-fish length variable.

**Statistical expectation:** a binned length table is frequency-weighted: a row
(bin, count=k) contributes k fish at that bin's length. Dropping the count
weights the distribution by row multiplicity instead of fish, biasing length
frequencies, mean length, and biomass of released fish toward
frequently-recorded bins. Separately, `length_mm` must be millimetres by
arithmetic, not by column-name assertion; `ir_LengthGroup` is by its own name a
group label (NGPC length groups are conventionally inch-classes).

**Minimal reproduction:** code only —
`fetch-loaders.R:462–471`: `ir_Count` explicitly excluded ("not in the
canonical field map; dropped by .rename_api_to_canonical"), `length_mm = "ir_LengthGroup"`
(`creel-connection-api.R:199–203`). Harvest path maps a true measurement
(`ihl_Length`); the release path asymmetry is the tell.

**Expected result:** release length data enter with fish-count weights and a
verified mm unit.

**Actual result:** each bin-row counts as one fish; the unit rests on a label.

**Root cause:** `.default_api_field_map()$release_lengths` +
`fetch_release_lengths.creel_connection_api()`.

**Downstream consequences:** all released-fish biological summaries; any
release-biomass estimate (including its #117 error propagation — correct
variance on a biased point estimate).

**Why existing tests missed it:** fixture `release_lengths.csv` is already
canonical one-row-per-fish mm data; API tests mock shapes, not semantics.

**Recommended regression test:** mock API release response with
`ir_Count = c(1, 5)`; assert the resulting distribution weights 6 fish, not 2
(will fail until fixed); unit assertion pending live confirmation.

**Recommended correction (conceptual):** map `ir_Count`, expand or carry as a
frequency column `add_lengths()` understands; confirm `ir_LengthGroup` units
against the live API/NGPC manual and convert explicitly if inch-group.

**Verify against live API:** distribution of `ir_Count`; unit/meaning of
`ir_LengthGroup`.

---

### Finding 4: Coded source values pass through unmapped (`ii_TripType` → trip_status, `CatchType` → catch_type)

**Severity:** Medium (verify-live)

**Workflow:** `fetch_interviews()`/`fetch_catch()` → `add_interviews()` /
harvest aggregation → `use_trips` dispatch, `catch_type == "harvested"` filters

**Information at risk:** the complete/incomplete estimator switch and the
harvested/released classifier.

**Statistical expectation:** downstream code matches literal lowercase
`"complete"`/`"incomplete"` (`creel-design.R:2456–2457, 2609–2618`) and literal
`"harvested"` (e.g. the harvest aggregation pattern in
`inst/validation/calamus-2016-validation.R`). Ingestion must therefore map
source codes to those vocabularies or verify them.

**Actual behavior:** `fetch_interviews` passes `ii_TripType` through
`as.character()` + downstream `tolower()` only; `fetch_catch` passes `CatchType`
through unchecked. `add_interviews()` does not validate trip_status values: an
unrecognized vocabulary yields `n_complete`/`n_incomplete` from absent table
cells and flows on. If the live API returns e.g. codes `"1"`/`"2"` or
`"Completed"`, complete-trip filters select zero rows; whether every downstream
estimator aborts loudly on the empty set was not established for all paths —
any that doesn't inherits a silent estimator switch.

**Root cause:** no value-mapping layer in fetch; no vocabulary validation in
`validate_fetch_interviews*()` (types only) or `add_interviews()`.

**Why existing tests missed it:** fixtures already use the canonical
vocabulary.

**Recommended regression test:** fetch mock with `ii_TripType = "1"`; assert
ingestion either maps or aborts — never passes through.

**Recommended correction (conceptual):** value maps beside the field maps
(canonical vocabulary ← source codes), abort on unmapped values; plus a
trip_status vocabulary check in `add_interviews()` (tidycreel side, separate
issue).

**Verify against live API:** actual `ii_TripType` and `CatchType` value sets
(the 2026-06-26 smoke test verified shapes/joins, not these vocabularies).

---

### Finding 5: Counts are reduced to date + three columns; any within-day or within-waterbody structure in the source is dropped

**Severity:** Medium (verify-live)

**Workflow:** `fetch_counts()` → `add_counts()` → count-based effort

**Information at risk:** count timestamp/period id, site/section identifiers on
count records.

**Statistical expectation:** multiple counts on a date are treated by
`add_counts()` as replicate instantaneous counts of the whole waterbody. That
is only valid if each source row is a whole-waterbody instantaneous count. If
NGPC `GetCountData` rows are per-site or per-circuit-stop counts, pooling them
as whole-lake replicates biases mean instantaneous count (and hence effort)
low; if the source records count times, progressive-count designs are
unreachable.

**Actual behavior:** count map is `date, bank_anglers, angler_boats,
non_ang_boats` only (`creel-connection-api.R:181–186`); everything else on the
record is silently discarded.

**Root cause:** closed counts field map.

**Why existing tests missed it:** calamus counts are one-per-date whole-lake
rows.

**Recommended correction (conceptual):** map count time and site when present;
document the whole-waterbody-instantaneous assumption in `fetch_counts()`.

**Verify against live API:** the grain of a `GetCountData` row.

---

### Finding 6: Root-cause pattern — closed hardcoded field maps + silent column drop

**Severity:** Medium (design; enabler of Findings 1, 2, 3, 5)

`.rename_api_to_canonical()` and `.rename_to_canonical()`
(`fetch-loaders.R:36–66`) return **only** mapped columns and say nothing about
what was discarded. Every information-loss finding above rides through this
one mechanism. The NGPC-fixed hardcoded map policy is a deliberate project
convention (do not reroute through schema keys) — the correction is not to
open the maps, but to (a) make the maps cover the statistically load-bearing
fields, and (b) report dropped source columns once per fetch so loss is
visible.

---

### Finding 7: Documented example builds effort from `bank_anglers` alone; vignette workflow chunk is not runnable

**Severity:** Low (documentation, but statistically directional)

`fetch_counts()` docs (`fetch-loaders.R:167–175`) demonstrate
`add_counts(design, counts, count_col = bank_anglers)`. On any fishery with
boats, that effort omits the entire boat-angler component — a silent
underestimate; the prose warns about summing columns but the only runnable
example is the biased one, and the correct path is blocked by Finding 1. The
vignette's integrated workflow (`creel_design(counts = counts, ...)`) does not
match the actual `creel_design()` signature, so the promised handoff has never
executed.

---

### Finding 8: Test-gap — the ingestion seam has zero composition coverage

**Severity:** Medium (test infrastructure)

- No connect test references any tidycreel design/estimator function.
- `inst/validation/calamus-2016-validation.R` bypasses `fetch_*()`.
- The only end-to-end fixture is bank-only, so the boat→angler path — the one
  flagged as unaudited — is structurally unreachable by every existing test.

Recommended: a `test-statistical-audit-connect-composition.R` exercising
CSV backend → fetch → design → estimate against `reference-outputs.csv`, plus a
boats>0 variant of the fixture.

## Not findings (checked, sound)

- `.coerce_numeric`/`.coerce_date` warn on NA-introducing coercion.
- Empty-API early returns are typed correctly.
- Bus-route estimators hard-abort when `.expansion`/π_i are absent — the
  Finding-2 loss cannot silently corrupt a number.
- UID synthesis by row index for catch/length rows is join-safe.
- API effort = hours + minutes/60 is dimensionally correct; NA propagates.
- `derive_angler_count()`/`mean_party_size()` consumption side: guards are
  comprehensive (mutual exclusion, carrier-column clash, no zero-SE default).

## Verify-against-live-API list (one session, ~30 min)

1. Party-size / angler-type fields in `GetInterviewData` (F1)
2. `ir_Count` values and `ir_LengthGroup` units (F3)
3. `ii_TripType` and `CatchType` value sets (F4)
4. Grain of a `GetCountData` row (F5)

## Suggested issue grouping

- Issue A (F1 + F2 + F6): fetch layer drops statistically load-bearing columns
  — extend maps/schema, report drops.
- Issue B (F3): release-length bin count + unit.
- Issue C (F4): value vocabularies.
- Issue D (F5 + F7): counts grain + docs.
- Issue E (F8): composition test coverage.
