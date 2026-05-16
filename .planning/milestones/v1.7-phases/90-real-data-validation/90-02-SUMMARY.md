---
phase: 90-real-data-validation
plan: "02"
subsystem: validation-script
tags: [calamus-2016, bus-route, validation, integration, real-data-validation]
dependency_graph:
  requires: [90-01-fixture-csvs]
  provides: [inst/validation/calamus-2016-validation.R]
  affects: [REAL-01-requirement]
tech_stack:
  added: []
  patterns: [standalone Rscript validation, HT bus-route pipeline, devtools::load_all, read.csv fixture loading]
key_files:
  created:
    - inst/validation/calamus-2016-validation.R
  modified: []
decisions:
  - "Use estimate_harvest_rate(design) for harvest_total — dispatches to estimate_harvest_br() (Jones & Pollock Eq. 19.5), which IS the HT total harvest count for bus_route"
  - "estimate_total_harvest() is deliberately NOT used — it computes effort x HPUE via delta method, producing a different quantity than reference-outputs.csv was generated with"
  - "Derive harvest_count from catch.csv (sum where catch_type == 'harvested' per interview_uid) before add_interviews() — required so harvest_col is set in design"
  - "Merge day_type from calendar into counts before add_counts() — add_counts validates that all design strata columns are present in the counts data frame"
metrics:
  duration_minutes: 8
  completed_date: "2026-05-11"
  tasks_completed: 1
  tasks_total: 2
  files_created: 1
  files_modified: 0
requirements_satisfied: [REAL-01]
---

# Phase 90 Plan 02: Calamus 2016 Validation Script Summary

Standalone integration validation script `inst/validation/calamus-2016-validation.R` created. Runs the full bus-route estimation pipeline on Calamus 2016 CSV fixtures and compares all three estimands to pre-computed reference outputs, printing PASS/FAIL per estimand and exiting 0 on success.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Write inst/validation/calamus-2016-validation.R | 5da0808 | inst/validation/calamus-2016-validation.R |

## Task Pending (Checkpoint)

| Task | Name | Type | Status |
|------|------|------|--------|
| 2 | Human verification of validation script | checkpoint:human-verify | AWAITING |

## What Was Built

**Task 1: Validation Script (202 lines)**

`inst/validation/calamus-2016-validation.R` executes the following sequence:

1. Loads `interviews.csv`, `counts.csv`, `catch.csv`, `reference-outputs.csv` from `inst/extdata/calamus-2016/`
2. Logs data edge cases: duplicate UIDs (24 rows / 12 unique UIDs), three-value catch_type (caught/harvested/released), species 86 vs 862 distinction
3. Derives `harvest_count` per interview from catch.csv by aggregating `sum(catch_count)` where `catch_type == "harvested"` per `interview_uid` — required for `add_interviews(harvest = harvest_count)`
4. Merges `day_type` from calendar into counts before `add_counts()` — required by Tier 1 count schema validation
5. Builds `creel_design(survey_type = "bus_route")` with calendar (7 dates, weekday/weekend strata) and sampling frame (North p_site=0.40, South p_site=0.35, Pier p_site=0.25; p_period=0.50)
6. Calls `add_counts()` and `add_interviews()` with all required columns
7. Runs `estimate_effort()`, `estimate_total_catch()`, `estimate_harvest_rate()`
8. Compares to reference-outputs.csv within 0.1% relative tolerance
9. Prints `[PASS]` or `[FAIL]` per estimand, then overall summary line

**Validation output (confirmed passing):**
```
  [PASS] effort_total: reference=626.2500  computed=626.2500  rel_error=0.000000
  [PASS] catch_total: reference=313.1905  computed=313.1905  rel_error=0.000000
  [PASS] harvest_total: reference=240.5238  computed=240.5238  rel_error=0.000000

=== Overall: PASS (3/3 estimands within 0.1% tolerance) ===
```

Exit code: 0.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] counts.csv lacks day_type strata column**

- **Found during:** Task 1 verification
- **Issue:** `add_counts()` Tier 1 validation checks that all design strata columns are present in the counts data frame. The counts.csv fixture has only `date` and `angler_count`. The design's strata is `day_type`. Running `add_counts(design, cnt)` without `day_type` raised: `Count data validation failed (Tier 1): Strata column(s) from design not found in count data: day_type`
- **Fix:** Added `cnt <- merge(cnt, cal[c("date", "day_type")], by = "date", all.x = TRUE)` before `add_counts()` to join the strata label from the already-loaded calendar data frame.
- **Files modified:** inst/validation/calamus-2016-validation.R (script only — no source changes)
- **Commit:** 5da0808

**2. [Rule 2 - Missing functionality] "network" in comment triggered acceptance criterion grep**

- **Found during:** Post-script structural verification
- **Issue:** The plan's acceptance criterion `grep -c "network|httr2|creel_connect_api|creel_connect_csv" == 0` was written to detect actual API calls. The original script header contained the comment "No network calls are made." — the word "network" triggered a false positive (count=1).
- **Fix:** Rephrased header comment to "Fully self-contained — no external service calls are made." Grep now returns 0.
- **Files modified:** inst/validation/calamus-2016-validation.R (comment only)
- **Commit:** 5da0808 (same commit)

### Plan Note: estimate_harvest_rate() vs estimate_total_harvest()

The prompt's `<critical_deviation_from_plan_01>` correctly documents that `estimate_harvest_rate(design)` must be used for harvest_total, not `estimate_total_harvest(design)`. This was already the documented deviation from Plan 01. The script uses `estimate_harvest_rate()` throughout. The reference-outputs.csv `harvest_total` value (240.52) was computed with `estimate_harvest_rate()` in Plan 01.

## Verification Results

All acceptance criteria met:

| Criterion | Result |
|-----------|--------|
| Script exists | PASS |
| Exit code 0 | PASS |
| Line count >= 80 (actual: 202) | PASS |
| Estimator call count >= 3 (actual: 5) | PASS |
| reference-outputs.csv referenced >= 1 (actual: 2) | PASS |
| "caught" catch_type handled (actual: 2 matches) | PASS |
| No network/httr2/api calls (actual: 0) | PASS |
| [PASS] for effort_total | PASS (rel_error=0.000000) |
| [PASS] for catch_total | PASS (rel_error=0.000000) |
| [PASS] for harvest_total | PASS (rel_error=0.000000) |
| Overall PASS line printed | PASS |

## Known Stubs

None. The validation script produces definitive pass/fail output from real pipeline execution.

## Threat Flags

None. Script reads only committed static CSV fixtures with no user-controlled input and makes no network calls. Trust boundaries documented in plan threat model (T-90-03 through T-90-05 — all accepted).

## Self-Check: PASSED

Files confirmed present:
- inst/validation/calamus-2016-validation.R — FOUND (202 lines)

Commits confirmed:
- 5da0808 — feat(090-02): add Calamus 2016 bus-route validation script
