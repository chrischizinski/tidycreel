---
phase: 36-multiple-counts-per-day
plan: 36-01
subsystem: counts
tags: [tdd, add_counts, within-day-aggregation, CNT-02, CNT-04, CNT-06, EFF-03]
dependency_graph:
  requires: [35-docs]
  provides: [multiple-counts-per-psu, within-day-variance]
  affects: [add_counts, creel_design, survey-bridge]
tech_stack:
  added: []
  patterns: [split-lapply aggregation, rlang tidy eval, cli_warn CNT guard]
key_files:
  created: []
  modified:
    - R/creel-design.R
    - R/survey-bridge.R
    - tests/testthat/test-add-counts.R
    - man/add_counts.Rd
decisions:
  - CNT-06 behavior is warn not abort per REQUIREMENTS.md spec
  - count_time_col is grouping key only — equal weight for each sub-PSU count
  - aggregate_within_day() drops count_time_col from aggregated output
  - count_type = "progressive" aborts immediately with "not yet implemented"
  - Within-day variance formulas trace to Rasmussen et al. 1998
metrics:
  duration: ~30 minutes
  completed: 2026-03-08
  tasks_completed: 3
  files_modified: 4
---

# Phase 36 Plan 01: Multiple Counts Infrastructure Summary

## One-liner

`add_counts()` extended with `count_time_col` tidy selector and `count_type` param; multiple sub-PSU counts aggregated to C-bar_d via `aggregate_within_day()`; within-day variance components (SS_d, K_d) stored in `design$within_day_var`; CNT-06 duplicate PSU warning added via `detect_duplicate_psus()`.

## What Was Built

### Task 1: Failing tests (RED phase)

Added 7 new `test_that` blocks to `tests/testthat/test-add-counts.R`:
- Test A (CNT-02): `count_time_col` accepted without error
- Test B (EFF-03): aggregates to one row per PSU
- Test C: `within_day_var` slot has `ss_d` and `k_d` columns with correct row count
- Test D (CNT-04): single-count path leaves `within_day_var = NULL` (backward compat)
- Test E (CNT-06): duplicate PSU rows without `count_time_col` emits warning
- Test F: `count_type` slot defaults to `"instantaneous"`
- Test G: `count_type = "progressive"` aborts with "not yet implemented"

All 7 tests failed before implementation (RED confirmed).

### Task 2: New internals in R/survey-bridge.R

Added after `validate_counts_tier1()`:

**`detect_duplicate_psus(counts, psu, call)`** — Checks for duplicate PSU values using `duplicated()`. Emits `cli::cli_warn()` with CNT-06 message including count of duplicates and hint to use `count_time_col`. Called from `add_counts()` when `count_time_col` is NULL.

**`aggregate_within_day(counts, psu_col, count_var, count_time_col, key_cols)`** — Groups multiple count rows per PSU using `split()` + `for` loop (no dplyr). For each PSU group: computes C-bar_d = mean(count_var), SS_d = sum of squared deviations, K_d = number of counts. Returns list with `$aggregated` (one row per PSU, count_time_col dropped) and `$within_day_var` (key_cols + ss_d + k_d).

### Task 3: Extended add_counts() in R/creel-design.R

New signature: `add_counts(design, counts, psu = NULL, count_time_col = NULL, count_type = "instantaneous", allow_invalid = FALSE)`

Body additions (in order):
1. `count_type` validation — aborts if not in `c("instantaneous", "progressive")`; aborts with "not yet implemented" if `"progressive"`
2. `count_time_col` tidy selector resolution via `rlang::enquo()` + `rlang::quo_is_null()` + `tidyselect::eval_select()`
3. CNT-06 guard: calls `detect_duplicate_psus()` when `count_time_col_name` is NULL
4. Within-day aggregation block: calls `aggregate_within_day()` when `count_time_col_name` is not NULL; replaces `counts` with `$aggregated`; captures `within_day_var`
5. New design slots: `count_type`, `count_time_col`, `within_day_var`, `n_counts_per_psu`

## Verification

- 7 new tests: GREEN (all pass)
- Full suite: 1383 tests, 0 failures, 0 regressions
- `lintr::lint_package()`: 0 issues
- `devtools::check()`: 0 errors, 0 warnings (2 pre-existing NOTEs unrelated to this plan)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed Test A construction that caused rbind column mismatch**
- **Found during:** Task 1 (RED phase execution)
- **Issue:** Plan spec used `rbind(example_counts, transform(example_counts, count_time = "pm"))` — `example_counts` has 3 columns, `transform()` result has 4, causing `rbind()` to abort with "numbers of columns of arguments do not match"
- **Fix:** Replaced with the consistent pattern used in Tests B/C: assign `count_time` column to each frame individually before `rbind()`
- **Files modified:** `tests/testthat/test-add-counts.R`
- **Commit:** 2201b5c (included in implementation commit)

## Decisions Made

1. **CNT-06 behavior:** Implemented as warning (`cli::cli_warn()`) not abort, per REQUIREMENTS.md text and Plan D1
2. **count_time_col grouping:** Column identifies distinct observations within a day; not ordered, not interpolated, not weighted — all K_d counts receive equal weight (Plan D2)
3. **count_time_col dropped from aggregated output:** After aggregation, sub-PSU time column is meaningless at PSU level; removed from `$aggregated` to keep `design$counts` clean (Plan D3)
4. **count_type = "progressive" aborts immediately:** API accepts the parameter but fails with "not yet implemented" — preferable to deferring the parameter (Plan D4)
5. **Variance attribution:** SS_d/K_d trace to Rasmussen et al. 1998 (Plan D5)

## Self-Check: PASSED

- R/creel-design.R: FOUND
- R/survey-bridge.R: FOUND
- tests/testthat/test-add-counts.R: FOUND
- Commit 2201b5c: FOUND
