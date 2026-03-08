---
phase: 36-multiple-counts-per-day
plan: 36-02
subsystem: estimation
tags: [variance, rasmussen, two-stage, within-day, effort]
dependency_graph:
  requires: [36-01]
  provides: [VAR-01, VAR-02, VAR-03, VAR-04, EFF-01-ext]
  affects: [estimate_effort, estimate_effort_total, estimate_effort_grouped]
tech_stack:
  added: []
  patterns: [Rasmussen-1998-two-stage-variance, qt-df-CI]
key_files:
  created: []
  modified:
    - R/creel-estimates.R
    - R/creel-design.R
    - tests/testthat/test-estimate-effort.R
decisions:
  - D1: CI recomputed from qt(degf) * se_total instead of confint(svy_result) (qnorm)
  - D2: compute_within_day_var_contribution() returns variance in total scale (N_s factor)
  - D3: se_between and se_within always present in output; se_within=0 for single-count
  - D4: VAR-03 informational message emitted from compute_within_day_var_contribution()
  - D5: Variable names use snake_case to satisfy lintr (n_avail, k_bar, s2_within, v_within)
metrics:
  duration: ~25 minutes
  completed: 2026-03-08
  tasks_completed: 5
  files_modified: 3
requirements_completed:
  - EFF-01
  - VAR-01
  - VAR-02
  - VAR-03
  - VAR-04
---

# Phase 36 Plan 02: Within-Day Variance in estimate_effort() Summary

**One-liner:** Rasmussen 1998 two-stage variance (var_between + var_within) with qt(degf) CI added to estimate_effort_total() and estimate_effort_grouped(), always emitting se_between and se_within columns.

## Tasks Completed

| Task | Description | Commit |
|------|-------------|--------|
| 1 | Write 7 failing TDD tests (RED phase) | 11d0e6a |
| 2 | Add compute_within_day_var_contribution() to R/creel-estimates.R | 11d0e6a |
| 3 | Modify estimate_effort_total() for two-stage variance | 11d0e6a |
| 4 | Modify estimate_effort_grouped() for two-stage variance | 11d0e6a |
| 5 | Update format.creel_design() to show count_time_col and count_type | 11d0e6a |

## Implementation Notes

### compute_within_day_var_contribution()

New `@noRd` internal function placed before `estimate_effort_total()` in `R/creel-estimates.R`.
Implements Rasmussen et al. 1998 formula:

```
s2_within_s = sum(ss_d) / (n_sampled * (k_bar - 1))
v_within_s  = (n_avail / k_bar) * s2_within_s
```

- Returns `0` scalar when `design$within_day_var` is NULL (backward compat)
- For ungrouped: loops strata, sums v_within across all strata
- For grouped: returns named vector keyed by group string

### CI Recomputation (D1)

After Plan 36-02, all `estimate_effort()` CIs use `qt(1 - alpha/2, df = survey::degf())` rather than `confint(svy_result)` which uses `qnorm`. This gives wider (more conservative) CIs. Two existing reference tests updated to verify against the new qt-based formula.

### Always-present columns (D3)

`se_between` and `se_within` appear in every `estimate_effort()` output tibble regardless of whether the design has multiple counts. For single-count designs: `se_between == se`, `se_within == 0`.

## Test Results

- 7 new tests added (Tests A-G per plan spec)
- 2 existing CI reference tests updated (ungrouped + grouped)
- Full suite: **FAIL 0 | PASS 1395** (up from 1383)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] example_counts has no n_anglers column**
- **Found during:** Task 1 (writing test helper make_multi_count_design())
- **Issue:** Plan spec used `counts_pm$n_anglers <- counts_pm$n_anglers + 4L` but `example_counts` has only `date`, `day_type`, `effort_hours`
- **Fix:** Changed to `counts_pm$effort_hours <- counts_pm$effort_hours + 4`
- **Files modified:** tests/testthat/test-estimate-effort.R
- **Commit:** 11d0e6a

**2. [Rule 1 - Naming] Capitalized variable names flagged by lintr**
- **Found during:** Task 2 (lintr pass)
- **Issue:** `N_s`, `K_bar`, `S2_within`, `V_within` violate object_name_linter (snake_case required)
- **Fix:** Renamed to `n_avail`, `k_bar`, `s2_within`, `v_within`; added `# nolint: object_length_linter` on function definition line (function name is 34 chars, exceeds 30-char limit)
- **Files modified:** R/creel-estimates.R
- **Commit:** 11d0e6a

**3. [Rule 1 - Logic] Two CI reference tests broke after switching to qt()**
- **Found during:** Task 3-4 (running tests after implementation)
- **Issue:** Old tests verified `confint(svy_result)` (qnorm-based); new implementation uses `qt(degf)`. Intentional per D1.
- **Fix:** Updated test descriptions and manual computations to match qt-based formula
- **Files modified:** tests/testthat/test-estimate-effort.R
- **Commit:** 11d0e6a

## Acceptance Criteria Verification

1. `estimate_effort(design_single)$estimates` has `se_between` and `se_within` columns — **PASS** (Test D)
2. For single-count design: `se_between == se` and `se_within == 0` — **PASS** (Test A)
3. For multi-count design: `se >= se_between` — **PASS** (Test B)
4. For multi-count design: `se_within > 0` when K_d counts differ — **PASS** (Test B)
5. For multi-count design: `se == sqrt(se_between^2 + se_within^2)` exactly — **PASS** (Test E)
6. Grouped `estimate_effort()` has `se_between` and `se_within` — **PASS** (Test G)
7. Mixed K_d emits `cli_inform()` mentioning "nC = 1" — **PASS** (Test F)
8. `print(design_with_count_time_col)` shows "Count time column:" — **PASS** (Task 5)
9. All existing tests pass (zero regressions) — **PASS** (1395 total, 0 failures)

## Self-Check: PASSED

- `/Users/cchizinski2/Dev/tidycreel/R/creel-estimates.R` — FOUND (modified)
- `/Users/cchizinski2/Dev/tidycreel/R/creel-design.R` — FOUND (modified)
- `/Users/cchizinski2/Dev/tidycreel/tests/testthat/test-estimate-effort.R` — FOUND (modified)
- Commit 11d0e6a — FOUND
