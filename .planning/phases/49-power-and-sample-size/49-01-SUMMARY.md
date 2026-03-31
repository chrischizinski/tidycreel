---
phase: 49
plan: 01
subsystem: power-and-sample-size
tags: [sample-size, stratified-survey, cochran, creel, power, POWER-01, POWER-02]
dependency_graph:
  requires: []
  provides: [creel_n_effort, creel_n_cpue]
  affects: [Phase 50 validate_design internals]
tech_stack:
  added: []
  patterns:
    - checkmate::assert_number / assert_numeric for input validation
    - cli::cli_abort would be used for non-checkmate errors (not needed here)
    - storage.mode(x) <- "integer" for integer coercion of ceiling results
    - nolint: object_name_linter for statistical uppercase notation (N_h, E_total, V_0)
key_files:
  created:
    - R/power-sample-size.R
    - tests/testthat/test-power-sample-size.R
    - man/creel_n_effort.Rd
    - man/creel_n_cpue.Rd
  modified:
    - NAMESPACE (export entries added by devtools::document)
decisions:
  - "FPC omitted intentionally in creel_n_effort() -- standard for pre-season planning (confirmed by Cochran 1977 rationale)"
  - "creel_n_cpue() parameterised as cv_catch/cv_effort/rho not raw variances -- biologist-friendly interface"
  - "rho=0 default is conservative (over-estimates n) -- document clearly"
  - "\\% in roxygen @param escapes as \\\\% in Rd which triggers a comment stripping the closing } -- replaced with 'percent' in prose"
  - "Statistical notation (N_h, E_total, V_0, s_h, w_h, n_h) kept as-is with # nolint: object_name_linter -- renaming would destroy readability against the textbook formula"
metrics:
  duration: 24 minutes
  completed: 2026-03-23
  tasks_completed: 2
  files_created: 4
  files_modified: 1
---

# Phase 49 Plan 01: creel_n_effort() and creel_n_cpue() Summary

**One-liner:** Stratified effort sample size (Cochran eq. 5.25) and CPUE ratio-estimator interview count functions with checkmate validation and full roxygen2 docs.

## Objective

Implement POWER-01 (`creel_n_effort`) and POWER-02 (`creel_n_cpue`) — the two pre-season sample size planning functions for Phase 49. Both functions are pure numeric calculations with no dependency on `creel_design` objects.

## What Was Built

### creel_n_effort()

- Implements Cochran (1977) equation 5.25 under proportional allocation
- Inputs: `cv_target` (scalar), `N_h` (named numeric vector), `ybar_h`, `s2_h`
- Returns named integer vector: per-stratum days + `"total"` element
- FPC intentionally omitted (pre-season planning convention)
- Validates: N_h must be named, lengths must match, cv_target in (0, 1]

### creel_n_cpue()

- Implements ratio-estimator variance approximation from Cochran (1977) Chapter 6
- Inputs: `cv_catch`, `cv_effort`, `rho` (default 0), `cv_target`
- Returns integer scalar >= 1
- `rho = 0` is conservative (over-estimates n when catch and effort are correlated)
- Numerical spot-check: cv_catch=0.8, cv_effort=0.5, rho=0, cv_target=0.20 gives n=23

## Tests

27 tests passing, 2 skipped (stubs for Plans 49-03 and 49-04).

Key tests:
- Named vector return with "total" element
- Proportional allocation: sum(n_h) >= n_total (ceiling artifacts)
- Structural monotonicity: smaller cv_target gives larger n
- Numerical: n=23 for known inputs
- rho=0 conservatism: n(rho=0) >= n(rho=0.5)
- Error on mismatched lengths, invalid cv_target, invalid rho

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Rd file parsed incorrectly due to \% in @param**

- **Found during:** Task 1 (devtools::check)
- **Issue:** `0.20 for 20\%` in roxygen comment produces `20\\%` in Rd, where `%` is the Rd comment character. This caused the `\item{cv_target}{...}` to never close its brace, breaking the entire `\arguments{}` section.
- **Fix:** Replaced `20\%` with `20 percent` in the @param description
- **Files modified:** R/power-sample-size.R, man/creel_n_effort.Rd
- **Commit:** 94dbc86

**2. [Rule 2 - Style] Non-ASCII em dashes in roxygen comments**

- **Found during:** Task 1 (devtools::check)
- **Issue:** UTF-8 em dashes in @param and @examples generated Non-ASCII Rd warnings
- **Fix:** Replaced em dashes with semicolons/parentheses throughout
- **Files modified:** R/power-sample-size.R
- **Commit:** 94dbc86

**3. [Rule 2 - Style] object_name_linter for statistical notation variables**

- **Found during:** Pre-commit hook (lintr)
- **Issue:** `N_h`, `E_total`, `V_0`, `s_h`, `w_h`, `n_h` are standard statistical notation from Cochran (1977) but violate snake_case convention
- **Fix:** Added `# nolint: object_name_linter` to all affected lines in both R source and test file. Variables kept as-is for readability against textbook formula.
- **Files modified:** R/power-sample-size.R, tests/testthat/test-power-sample-size.R
- **Commit:** 94dbc86

**4. [Rule 2 - Style] commented_code_linter on formula trace comment**

- **Found during:** Pre-commit hook (lintr)
- **Issue:** `# ceiling((0.64 + 0.25 - 0) / 0.04) = ceiling(22.25) = 23` in test flagged as commented code
- **Fix:** Added `# nolint: commented_code_linter` to that line
- **Files modified:** tests/testthat/test-power-sample-size.R
- **Commit:** 94dbc86

## Decisions Made

1. FPC omitted in `creel_n_effort()` — pre-season planning convention; documented in `@details`
2. `creel_n_cpue()` exposed as `cv_catch`/`cv_effort`/`rho` (not raw variances) — biologist-friendly
3. Statistical notation preserved with nolint rather than renamed — formula readability is critical for maintainability
4. Both functions floored at 1L via `max(n, 1L)` / `storage.mode <- "integer"` pattern

## Self-Check

- R/power-sample-size.R: exists and exports creel_n_effort, creel_n_cpue
- tests/testthat/test-power-sample-size.R: 27 PASS, 0 FAIL, 2 SKIP
- man/creel_n_effort.Rd: clean (tools::checkRd passes)
- man/creel_n_cpue.Rd: clean (tools::checkRd passes)
- Commit 94dbc86: present in git log
