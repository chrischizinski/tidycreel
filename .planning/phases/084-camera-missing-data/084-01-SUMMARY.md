---
phase: 084-camera-missing-data
plan: "01"
subsystem: camera-imputation
tags: [imputation, camera, glm, glmm, estimation]
dependency_graph:
  requires: []
  provides: [impute_camera_counts]
  affects: [add_counts, est_effort_camera]
tech_stack:
  added: [glmmTMB (Suggests)]
  patterns: [per-stratum lapply loop, rlang::check_installed guard, storage.mode coercion]
key_files:
  created:
    - R/impute-camera-counts.R
    - man/impute_camera_counts.Rd
    - tests/testthat/test-impute-camera-counts.R
  modified:
    - DESCRIPTION
    - NAMESPACE
    - _pkgdown.yml
decisions:
  - "Intercept-only GLM per stratum (count ~ 1) because strata_col has one unique value within each stratum subset — using count ~ strata_col would fail with 'contrasts need 2+ levels'"
  - "GLMM formula also uses intercept-only fixed effect (count ~ 1 + (1|site_col)) for the same reason"
  - "CAMP-05 test uses suppressWarnings() because 100%-missing strata fire cli_warn before the cli_abort; expect_error with withCallingHandlers caught the warning first"
metrics:
  duration: "4 minutes"
  completed: "2026-05-03"
  tasks_completed: 2
  tasks_total: 2
  files_created: 3
  files_modified: 4
---

# Phase 84 Plan 01: impute_camera_counts() Implementation Summary

**One-liner:** Poisson GLM (default) and nbinom2 GLMM (opt-in) per-stratum imputation for camera count outages, with `.imputed` flag, integer coercion, high-missingness warning, and all-NA stratum abort.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| TDD RED | Failing tests for impute_camera_counts() | ba33b48 | tests/testthat/test-impute-camera-counts.R |
| TDD GREEN | Implement impute_camera_counts() | fa5450f | R/impute-camera-counts.R (+ test update) |
| 2 | Register glmmTMB, pkgdown entry, devtools::document() | 7fb3315 | DESCRIPTION, NAMESPACE, _pkgdown.yml, man/ |

## What Was Built

`impute_camera_counts(data, count_col, strata_col, status_col = "camera_status", method = "glm", site_col = NULL)`:

- Identifies outage rows where `status_col != "operational"` AND `count_col` is NA (D-02)
- Warns once if any stratum has > 50% outages (CAMP-04)
- Aborts if any stratum has zero observed counts (CAMP-05)
- Per-stratum loop: intercept-only Poisson GLM (default) or nbinom2 GLMM with `tryCatch` fallback to GLM on convergence failure (D-14)
- Returns all rows with imputed counts rounded to integer, original `camera_status` preserved (D-07), `.imputed` flag appended (D-06)
- `storage.mode(result[[count_col]]) <- "integer"` for schema compatibility with `add_counts()` (D-08)
- `rlang::check_installed("glmmTMB", ...)` guard before any GLMM fitting (D-12, T-084-03)

## Test Coverage (22 tests)

- Input validation: non-data-frame, bad method, missing columns
- CAMP-01: all rows returned, no NA in count column, .imputed column present
- CAMP-02: imputed rows have `.imputed = TRUE`, operational rows have FALSE
- CAMP-03: count column is integer type
- CAMP-04: warns on > 50% missingness
- CAMP-05: aborts on all-NA stratum
- D-07: original camera_status preserved in imputed rows
- Output structure: column order, date/day_type passthrough

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Intercept-only GLM formula required (not `count ~ strata_col`)**

- **Found during:** TDD GREEN phase — all GLM tests failed with "contrasts can be applied only to factors with 2 or more levels"
- **Issue:** Within a per-stratum loop, `strata_col` has exactly one unique value. Fitting `count ~ strata_col` fails because R cannot create a contrast matrix for a factor with 1 level. The plan noted this at line 241 but the formula was still written as `count_col ~ strata_col`.
- **Fix:** Changed GLM formula to `count_col ~ 1` (intercept-only = per-stratum Poisson mean, consistent with D-09/D-10 and Hartill 2016). Same fix applied to GLMM path: `count_col ~ 1 + (1 | site_col)`.
- **Files modified:** R/impute-camera-counts.R
- **Commit:** fa5450f

**2. [Rule 2 - Test correctness] CAMP-05 test needed suppressWarnings()**

- **Found during:** TDD GREEN phase — `expect_error()` was catching a `cli_warn()` instead of the `cli_abort()`
- **Issue:** For a 100%-missing stratum, the high-missingness warning fires first (computed globally before the loop), and `testthat::expect_error` uses `withCallingHandlers` which intercepts the warning before the error reaches `tryCatch`. The test was never reaching the abort.
- **Fix:** Wrapped the call in `suppressWarnings()` inside `expect_error()` with an explanatory comment. The abort still fires correctly.
- **Files modified:** tests/testthat/test-impute-camera-counts.R
- **Commit:** fa5450f

## TDD Gate Compliance

- RED gate: `test(084-01): add failing tests...` — commit ba33b48
- GREEN gate: `feat(084-01): implement impute_camera_counts()...` — commit fa5450f

Both gates satisfied.

## Known Stubs

None. `impute_camera_counts()` is fully implemented with real GLM/GLMM fitting and prediction.

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or trust boundary changes introduced. All mitigations in the plan's threat register are implemented:

| Threat ID | Status |
|-----------|--------|
| T-084-01 | Mitigated: checkmate assertions + column existence cli_abort |
| T-084-02 | Mitigated: cli_abort() guard before model fitting |
| T-084-03 | Mitigated: rlang::check_installed() inside method == "glmm" only |
| T-084-04 | Mitigated: tryCatch fallback to GLM with cli_warn() |

## Self-Check: PASSED

| Item | Status |
|------|--------|
| R/impute-camera-counts.R | FOUND |
| man/impute_camera_counts.Rd | FOUND |
| tests/testthat/test-impute-camera-counts.R | FOUND |
| 084-01-SUMMARY.md | FOUND |
| commit ba33b48 (RED) | FOUND |
| commit fa5450f (GREEN) | FOUND |
| commit 7fb3315 (chore) | FOUND |
