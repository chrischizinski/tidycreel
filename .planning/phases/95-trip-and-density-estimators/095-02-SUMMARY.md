---
phase: "095-trip-and-density-estimators"
plan: "02"
subsystem: "creel-estimates"
tags: [estimate_effort_per_acre, density, effort, creel_estimates, RPT-02]
dependency_graph:
  requires: ["095-01"]
  provides: [estimate_effort_per_acre]
  affects: [NAMESPACE, man/estimate_effort_per_acre.Rd]
tech_stack:
  added: []
  patterns: [composable-estimator, linear-SE-propagation]
key_files:
  created:
    - man/estimate_effort_per_acre.Rd
  modified:
    - R/creel-estimates-trip-density.R
    - tests/testthat/test-estimate-trip-density.R
    - NAMESPACE
decisions:
  - "Linear SE propagation (se / acres) — acres is a constant, no Delta Method"
  - "Guard se_between and se_within with %in% names() — not guaranteed in all creel_estimates"
  - "Fix pre-existing non-ASCII em-dash chars (deviation Rule 1) — blocked rcmdcheck gate"
metrics:
  duration: "~15 minutes"
  completed: "2026-05-25"
  tasks: 2
  tests_passing: 36
  total_tests: 2775
---

# Phase 95 Plan 02: estimate_effort_per_acre() Summary

**One-liner:** Scalar-divisor density estimator dividing all effort estimate columns by `acres`, with guarded `se_between`/`se_within` scaling and linear SE propagation.

## What Was Implemented

### Function: `estimate_effort_per_acre(effort, acres, ...)`

**File:** `R/creel-estimates-trip-density.R` (appended after `estimate_angler_trips()`)

**Signature:** `estimate_effort_per_acre(effort, acres, ...)`

**Key behaviors:**
- Takes a pre-computed `creel_estimates` from `estimate_effort()` — does not call `estimate_effort()` internally (composable pattern, D-08)
- `acres` must be a single positive numeric scalar; `cli::cli_abort()` fires for zero, negative, or non-numeric inputs (threat T-095-04)
- Divides all estimate columns by `acres`:
  - `estimate`, `se`, `ci_lower`, `ci_upper` — always present
  - `se_between`, `se_within` — only when present in the input (`%in% names()` guard, D-11)
- Inherits `variance_method`, `conf_level`, and `by_vars` from the effort object
- Returns `new_creel_estimates()` with `method = "effort-per-acre"`
- Carries through all by_vars grouping columns and `n` unchanged
- No `.overall` row added (already present in effort if effort had one)

## Test Results

**Filter:** `devtools::test(filter = "trip-density")`
- 36 expectations pass, 0 failures, 0 warnings, 0 skips
- Tests A–L: RPT-01 (estimate_angler_trips) — all passing
- Tests M–V: RPT-02 (estimate_effort_per_acre) — all passing

**Full suite:** `devtools::test()`
- 2775 tests pass, 0 failures (up from 2668 pre-phase-95)

## rcmdcheck Gate

`devtools::check(error_on = "warning")`:
- **0 errors**
- **0 warnings**
- 1 pre-existing NOTE (cross-reference resolution for writexl, unrelated to this plan)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed non-ASCII em-dash characters in estimate_angler_trips()**
- **Found during:** Task 2 — rcmdcheck reported `R CMD check found WARNINGs` due to non-ASCII characters
- **Issue:** Two em-dash characters (`—`, Unicode U+2014) were present in `cli::cli_abort()` error messages within `estimate_angler_trips()`. These existed in the Wave 1 code committed in Plan 095-01 and blocked the mandatory rcmdcheck gate.
- **Fix:** Replaced em-dashes with ASCII semicolons (`;`) in two error message strings.
- **Files modified:** `R/creel-estimates-trip-density.R`
- **Commit:** 7cf9c93

## Commits

| Hash | Message |
|------|---------|
| bea1780 | feat(95-02): implement estimate_effort_per_acre() appended to creel-estimates-trip-density.R |
| 7cf9c93 | feat(95-02): add RPT-02 tests, NAMESPACE export, fix non-ASCII chars; rcmdcheck 0e 0w |

## Self-Check

- [x] `R/creel-estimates-trip-density.R` contains both `estimate_angler_trips` and `estimate_effort_per_acre`
- [x] `NAMESPACE` contains `export(estimate_effort_per_acre)`
- [x] `man/estimate_effort_per_acre.Rd` created by devtools::document()
- [x] All 36 trip-density tests pass (A–V)
- [x] Full suite: 2775 pass, 0 failures
- [x] rcmdcheck: 0 errors, 0 warnings
- [x] Commits bea1780 and 7cf9c93 exist in git log
