---
phase: 90-real-data-validation
plan: "01"
subsystem: validation-fixtures
tags: [calamus-2016, bus-route, fixtures, csv, real-data-validation]
dependency_graph:
  requires: [89-discovery-generics]
  provides: [inst/extdata/calamus-2016/]
  affects: [validation-script-plan-02]
tech_stack:
  added: []
  patterns: [bus-route HT estimator, Jones & Pollock 2012 Eq 19.5, CSV fixtures]
key_files:
  created:
    - inst/extdata/calamus-2016/interviews.csv
    - inst/extdata/calamus-2016/counts.csv
    - inst/extdata/calamus-2016/catch.csv
    - inst/extdata/calamus-2016/harvest_lengths.csv
    - inst/extdata/calamus-2016/release_lengths.csv
    - inst/extdata/calamus-2016/reference-outputs.csv
  modified: []
decisions:
  - "Use estimate_harvest_rate() instead of estimate_total_harvest() for bus_route harvest reference value"
  - "Harvest column derived from catch.csv aggregation (catch_type == harvested) per interview_uid"
metrics:
  duration_minutes: 6
  completed_date: "2026-05-11"
  tasks_completed: 2
  tasks_total: 2
  files_created: 6
  files_modified: 0
requirements_satisfied: [REAL-01]
---

# Phase 90 Plan 01: Calamus 2016 Fixture CSV Files Summary

Six static CSV fixture files created in `inst/extdata/calamus-2016/` representing a realistic bus-route survey with known edge cases, plus a pre-computed reference-outputs.csv from running the tidycreel bus-route pipeline on those fixtures.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create fixture CSV files for Calamus 2016 | 8728940 | interviews.csv, counts.csv, catch.csv, harvest_lengths.csv, release_lengths.csv |
| 2 | Compute and write reference-outputs.csv | 029f3eb | reference-outputs.csv |

## What Was Built

**Task 1: Fixture CSV files**

Five CSV files in `inst/extdata/calamus-2016/` covering a realistic bus-route survey:

- `interviews.csv` — 24 rows; UIDs 1-12 each appearing exactly twice (bus-route duplication behavior); 3 sites (North, South, Pier) on circuit1 over 5 survey dates; columns: interview_uid, date, site, circuit, effort_hours, catch_count, n_counted, n_interviewed, trip_status
- `counts.csv` — 7 rows; one angler_count per date spanning weekday (5) and weekend (2) strata
- `catch.csv` — 16 rows; three-value `catch_type` (harvested, released, caught); species "86" and "862" as distinct character values; sequential catch_uid 1–16
- `harvest_lengths.csv` — 10 length measurements for harvested fish from 7 interview_uids
- `release_lengths.csv` — 4 length measurements for released fish from 3 interview_uids

**Task 2: Reference outputs**

Pipeline executed via `devtools::load_all(".")` on the fixtures:
- Calendar: 7 dates, weekday/weekend strata
- Sampling frame: North (p_site=0.40), South (p_site=0.35), Pier (p_site=0.25); p_period=0.50
- Design built with `creel_design(survey_type="bus_route")`
- Interviews loaded directly (not via fetch_interviews) to get all columns including site, circuit, n_counted, n_interviewed
- Harvest column derived from catch.csv: `sum(catch_count)` per `interview_uid` where `catch_type == "harvested"`

**Reference values produced:**

| estimand | estimate | se | ci_lower | ci_upper |
|----------|----------|-----|----------|----------|
| effort_total | 626.25 | 45.65 | 536.78 | 715.72 |
| catch_total | 313.19 | 55.72 | 203.97 | 422.41 |
| harvest_total | 240.52 | 46.59 | 149.22 | 331.83 |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] estimate_total_harvest() has no bus_route dispatch**

- **Found during:** Task 2
- **Issue:** The plan called `estimate_total_harvest(design)` for the harvest reference value. However, `estimate_total_harvest()` does not have a bus_route dispatch — it calls `validate_design_compatibility(design)` which requires `design$survey` (from `add_counts()`), then fails if `harvest_col` is NULL. Neither condition is met when only `add_interviews()` is called without `harvest=` and without `add_counts()`.
- **Fix:** Two adaptations:
  1. Added `harvest_count` column to interviews before `add_interviews()` by aggregating `catch.csv` rows where `catch_type == "harvested"` per `interview_uid` — this sets `design$harvest_col`
  2. Used `estimate_harvest_rate(design)` instead of `estimate_total_harvest(design)`. For bus_route designs, `estimate_harvest_rate()` dispatches to `estimate_harvest_br()` (Jones & Pollock 2012 Eq. 19.5: H_hat = sum(h_i/pi_i)) which IS the total harvest count, not a per-unit rate. The function naming is domain-specific; for bus_route the "rate" function returns the HT total.
- **Files modified:** None (no source changes — only the reference script approach adapted)
- **Commit:** 029f3eb

## Verification

Plan verification script passed:
```
Phase 90 Plan 01 verification PASSED
```

All acceptance criteria met:
- `nrow(interviews.csv) == 24` — PASS
- `all(table(interviews$interview_uid) == 2)` — PASS (each UID appears exactly twice)
- `"caught" %in% catch$catch_type` — PASS
- `"86" %in% catch$species` and `"862" %in% catch$species` — PASS
- `nrow(reference-outputs.csv) == 3` — PASS
- All estimates finite — PASS
- All estimates > 0 — PASS

## Known Stubs

None. All CSV files contain complete data values derived from the fixture design parameters.

## Threat Flags

None. Files are static committed CSV fixtures with synthetic non-sensitive data as documented in the plan's threat model (T-90-01, T-90-02 — both accepted).

## Self-Check: PASSED

Files confirmed present:
- inst/extdata/calamus-2016/interviews.csv — FOUND
- inst/extdata/calamus-2016/counts.csv — FOUND
- inst/extdata/calamus-2016/catch.csv — FOUND
- inst/extdata/calamus-2016/harvest_lengths.csv — FOUND
- inst/extdata/calamus-2016/release_lengths.csv — FOUND
- inst/extdata/calamus-2016/reference-outputs.csv — FOUND

Commits confirmed:
- 8728940 — FOUND (feat(090-01): add Calamus 2016 bus-route fixture CSV files)
- 029f3eb — FOUND (feat(090-01): compute and write reference-outputs.csv from bus-route pipeline)
