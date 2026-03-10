---
phase: 37
plan: "01"
subsystem: creel-design
tags: [counts, progressive, effort-estimation, TDD]
dependency_graph:
  requires: [36-01, 36-02]
  provides: [progressive-count-estimation]
  affects: [add_counts, estimate_effort, format.creel_design]
tech_stack:
  added: []
  patterns: [enquo-tidyselect, compute-effort-internal]
key_files:
  created: []
  modified:
    - R/survey-bridge.R
    - R/creel-design.R
    - man/add_counts.Rd
    - tests/testthat/test-add-counts.R
    - tests/testthat/test-estimate-effort.R
decisions:
  - "Pope et al. formula simplifies to Ê_d = C × T_d (κ cancels with τ), but keep τ × κ form in code for traceability"
  - "Two-PSU helper needed in Pope et al. test so estimate_effort() can compute between-PSU variance"
  - "period_length_col dropped from design$counts after Ê_d computation to prevent misidentification as count variable"
metrics:
  duration: "~30 minutes"
  completed: "2026-03-09"
  tasks_completed: 5
  files_modified: 5
---

# Phase 37 Plan 01: Progressive Count Estimator Summary

**One-liner:** Progressive count support in `add_counts()` — `circuit_time` (τ) + `period_length_col` parameters compute Ê_d = C × τ × κ per PSU before survey construction.

## What Was Implemented

`add_counts()` now accepts `count_type = "progressive"` with two required new parameters:

- `circuit_time` (τ): time in hours to complete one roving count circuit
- `period_length_col`: tidy selector for the column containing T_d (shift duration per PSU)

The progressive count formula (Hoenig et al. 1993; Pope et al. Ch. 17):

```
Ê_d = C × τ × κ   where κ = T_d / τ
    = C × T_d      (simplified)
```

Raw counts in the count column are replaced with Ê_d values (angler-hours) before the survey design is constructed. The `period_length_col` column is then dropped so it cannot be misidentified as a second count variable by `estimate_effort()`. The downstream estimation pipeline requires zero changes.

### New internal function

`compute_progressive_effort()` in `R/survey-bridge.R` — takes `counts`, `count_var`, `period_length_col`, `circuit_time`; returns modified data frame with Ê_d in place of raw counts.

### New design slots

- `design$circuit_time` — τ value (or NULL for instantaneous)
- `design$period_length_col` — character name of the T_d column (or NULL)

### format.creel_design() update

When `circuit_time` is set, `print()` displays: `Circuit time (τ): X hours`

## Tests Added

**test-add-counts.R** (8 new tests):
- Stub test replaced: `count_type = "progressive"` without `circuit_time` aborts mentioning "circuit_time" (CNT-05)
- CNT-01: accepted with all required args
- CNT-05: aborts without `period_length_col`
- EFF-02: Ê_d = n_anglers × shift_hours after progressive computation
- `period_length_col` dropped from `design$counts` after computation
- CNT-03: `circuit_time` and `period_length_col` stored as design slots
- `count_time_col + progressive` combination aborts
- Non-positive `period_length` values abort with "positive" in message

**test-estimate-effort.R** (1 new test):
- Pope et al. worked example: C=234, τ=2h, T_d=8h → Ê_d=1872 (first PSU)
- `estimate_effort()` returns positive finite estimate
- `se_between` and `se_within` present in result

## Files Modified

| File | Change |
|------|--------|
| `R/survey-bridge.R` | Added `compute_progressive_effort()` internal function |
| `R/creel-design.R` | Extended `add_counts()` signature; removed stub abort; added validation; added Ê_d computation; stored new slots; updated `format.creel_design()` |
| `man/add_counts.Rd` | Documented `circuit_time` and `period_length_col` parameters |
| `tests/testthat/test-add-counts.R` | Replaced stub test; added 8 new progressive tests + `make_progressive_counts()` helper |
| `tests/testthat/test-estimate-effort.R` | Added `make_pope_progressive_design()` helper + Pope et al. spot-check test |

## Acceptance Criteria

| # | Criterion | Status |
|---|-----------|--------|
| 1 | `add_counts(..., count_type = "progressive", circuit_time = 2, period_length_col = shift_hours)` succeeds | PASS |
| 2 | `add_counts(..., count_type = "progressive")` aborts mentioning "circuit_time" | PASS |
| 3 | `add_counts(..., count_type = "progressive", circuit_time = 2)` aborts mentioning "period_length_col" | PASS |
| 4 | Count column values equal `n_anglers × shift_hours` after progressive computation | PASS |
| 5 | `design$circuit_time` equals τ; `design$period_length_col` equals column name | PASS |
| 6 | `d$counts` does NOT contain `shift_hours` after progressive computation | PASS |
| 7 | `count_time_col + progressive` combination aborts | PASS |
| 8 | `period_length` values ≤ 0 abort with "positive" | PASS |
| 9 | Pope et al. example: C=234, τ=2h, T=8h → `d$counts$n_anglers[1] == 1872` | PASS |
| 10 | `estimate_effort(progressive_design)$estimates$estimate` is positive finite | PASS |
| 11 | `print(progressive_design)` shows "Circuit time (τ): X hours" | PASS |
| 12 | All existing `test-add-counts.R` tests pass | PASS |
| 13 | All existing `test-estimate-effort.R` tests pass | PASS |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] cli glue parse error in period_length_col error message**
- **Found during:** Task 3 (RED→GREEN transition)
- **Issue:** Multi-line `{.code ...}` span across two "i" entries caused cli glue parser to fail with "Expecting '}'"
- **Fix:** Collapsed to single "i" line without `{.code }` wrapper; added `# nolint: line_length_linter` for the 124-char line
- **Files modified:** `R/creel-design.R`

**2. [Rule 2 - Missing functionality] Pope et al. test helper needed 2 PSUs**
- **Found during:** Task 5 (GREEN verification)
- **Issue:** Plan's helper had 1 count row (1 PSU); survey package hard-errors with "Stratum has only one PSU" when computing variance
- **Fix:** Extended `make_pope_progressive_design()` to include both calendar dates as counted PSUs; updated test assertions to check by date index
- **Files modified:** `tests/testthat/test-estimate-effort.R`

## Commit

- `8884c35` — feat(37-01): add progressive count estimator

## Self-Check: PASSED

- `R/survey-bridge.R` contains `compute_progressive_effort` — FOUND
- `R/creel-design.R` contains `circuit_time` parameter — FOUND
- `man/add_counts.Rd` documents `circuit_time` and `period_length_col` — FOUND
- Commit `8884c35` exists — FOUND
- 1409 tests passing, 0 failures — VERIFIED
- R CMD check: 0 errors, 0 warnings — VERIFIED
