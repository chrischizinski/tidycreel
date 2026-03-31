---
phase: 41-product-estimators
plan: 02
subsystem: estimation
tags: [tdd, section-dispatch, product-estimators, delta-method]
requirements-completed: [PROD-01, PROD-02]
dependency_graph:
  requires: [41-01, 40-02, 39-03]
  provides: [section-dispatch-total-catch, section-dispatch-total-harvest, section-dispatch-total-release]
  affects: [estimate_total_catch, estimate_total_harvest, estimate_total_release]
tech_stack:
  added: []
  patterns:
    - sections-slot-NULL-guard to prevent recursive section dispatch in sub-designs
    - inline delta-method using internal helpers to bypass public-API sample-size validation
    - dual rebuild pattern (rebuild_counts_survey + rebuild_interview_survey) for product section helpers
key_files:
  created: []
  modified:
    - R/creel-estimates-total-catch.R
    - R/creel-estimates-total-harvest.R
    - R/creel-estimates-total-release.R
    - man/estimate_total_catch.Rd
    - man/estimate_total_harvest.Rd
    - man/estimate_total_release.Rd
decisions:
  - Set sec_counts_design[["sections"]] <- NULL before passing to per-section computation so sub-designs do not re-trigger section dispatch in the effort/rate public functions
  - Inline delta-method in section loop using estimate_effort_total() + estimate_cpue_total()/estimate_harvest_total() directly — avoids validate_ratio_sample_size() abort on n=9 per-section interviews
  - Release section helper mirrors estimate_release_rate_sections() pattern: build release data inline then call estimate_cpue_total()
  - prop_of_lake_total denominator = sum(TC_i) not full-design svytotal — guarantees proportions sum to 1.0 per plan spec
  - lake_total SE = sqrt(sum(se_i^2)) zero-covariance arithmetic; CI uses qt() from full-design degf() for consistency with rate section helpers
  - line_length_linter suppressed on the 121-char missing-sections error message line in all three helpers — identical pattern to Phase 40-02
metrics:
  duration_minutes: 32
  completed_date: "2026-03-14"
  tasks_completed: 1
  files_modified: 6
---

# Phase 41 Plan 02: Section Dispatch for Product Estimators Summary

**One-liner:** Per-section total catch/harvest/release via dual rebuild + inline delta-method, with .lake_total = sum(TC_i) and SE = sqrt(sum(se_i^2)).

## What Was Built

Three section dispatch helpers and updated public function signatures for all product estimators:

- `estimate_total_catch_sections()` — loops over registered sections, calls `rebuild_counts_survey()` + `rebuild_interview_survey()` per section, computes E_i * CPUE_i inline via `estimate_effort_total()` + `estimate_cpue_total()`, appends `prop_of_lake_total` and `.lake_total` row
- `estimate_total_harvest_sections()` — identical structure using `estimate_effort_total()` + `estimate_harvest_total()`
- `estimate_total_release_sections()` — builds release data inline (same as `estimate_release_rate_sections()`) then calls `estimate_effort_total()` + `estimate_cpue_total()`

Each public function gained `aggregate_sections = TRUE` and `missing_sections = "warn"` parameters. Section dispatch guard placed:
- `estimate_total_catch()`: after bus-route dispatch, before `validate_design_compatibility()`
- `estimate_total_harvest()`: after `validate_design_compatibility()` + species block
- `estimate_total_release()`: after `validate_design_compatibility()` + species block

All three man/ files regenerated with new `@param` entries and `@details` sections documenting zero-covariance assumption.

## Test Results

- 1555 tests GREEN (19 PROD stubs from Plan 01 now passing + all 1481+ pre-existing tests)
- 0 lintr issues
- 0 R CMD check errors/warnings (1 pre-existing NOTE for hidden files unrelated to this plan)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Sub-designs re-triggered section dispatch**
- **Found during:** First test run
- **Issue:** `sec_counts_design` retained the `sections` slot from the parent design; calling `estimate_effort()` on it dispatched to `estimate_effort_sections()`, which tried to compute a lake-wide total from a single-section counts design and failed with `dimnames` error on `vcov(by_result)`
- **Fix:** Add `sec_counts_design[["sections"]] <- NULL` immediately after `rebuild_counts_survey()` in all three section helpers
- **Files modified:** R/creel-estimates-total-catch.R, R/creel-estimates-total-harvest.R, R/creel-estimates-total-release.R
- **Commit:** 59440dc

**2. [Rule 1 - Bug] Sample-size validation aborted per-section estimation**
- **Found during:** Second test run (after Fix 1)
- **Issue:** Calling `estimate_total_harvest_ungrouped()` / `estimate_release_rate()` on filtered 9-interview section designs triggered `validate_ratio_sample_size()` abort (n < 10 threshold)
- **Fix:** Replace calls to public `_ungrouped` wrappers with inline delta-method computation using internal helpers (`estimate_effort_total()` + `estimate_harvest_total()` / `estimate_cpue_total()`), matching the pattern already used in `estimate_catch_rate_sections()` and `estimate_release_rate_sections()`
- **Files modified:** R/creel-estimates-total-catch.R, R/creel-estimates-total-harvest.R, R/creel-estimates-total-release.R
- **Commit:** 59440dc

## Self-Check: PASSED

All 6 key files present. Commit 59440dc verified. All 3 Rd files contain `aggregate_sections` param. 1555 tests GREEN.
