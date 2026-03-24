---
phase: 49-power-and-sample-size
plan: 02
subsystem: statistics
tags: [power-analysis, sample-size, stats, normal-approximation, cv, ratio-estimator]

# Dependency graph
requires:
  - phase: 49-01
    provides: creel_n_effort() and creel_n_cpue() implementations used in round-trip tests
provides:
  - creel_power(): two-sample normal approximation power calculation
  - cv_from_n(): algebraic inverse of creel_n_effort() and creel_n_cpue()
  - Complete four-function pre-season planning suite (POWER-01 through POWER-04)
affects: [49-03-validate-design, 49-04-season-summary, vignettes]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "stats::qnorm/pnorm called directly — no new dependencies for normal approximation power"
    - "match.arg(type) dispatch pattern for two-branch function (effort/cpue)"
    - "Round-trip property: ceiling in creel_n_*() means cv_from_n() <= cv_target (lte not equal)"

key-files:
  created:
    - man/creel_power.Rd
    - man/cv_from_n.Rd
  modified:
    - R/power-sample-size.R
    - tests/testthat/test-power-sample-size.R
    - NAMESPACE

key-decisions:
  - "creel_power() uses two-sample normal approximation (equal group sizes) — ncp = delta_pct * sqrt(n/2) / cv_historical"
  - "delta_pct > 5 triggers cli_warn (not error) — biologists may pass 6 meaning 6% not 600%"
  - "cv_from_n() dispatches on type='effort'/'cpue' via match.arg — single entry point for both inverse functions"
  - "cv_from_n() round-trip uses expect_lte not expect_equal — ceiling() in forward functions guarantees recovered CV <= target"

patterns-established:
  - "Power formula: ncp = abs(delta_pct) * sqrt(n/2) / cv_historical"
  - "cv_from_n effort: CV = sqrt(sum(N_h * s2_h) / n) / E_total"
  - "cv_from_n cpue: CV = sqrt((cv_catch^2 + cv_effort^2 - 2*rho*cv_catch*cv_effort) / n)"

requirements-completed: [POWER-03, POWER-04]

# Metrics
duration: 22min
completed: 2026-03-24
---

# Phase 49 Plan 02: Power and Sample Size — creel_power / cv_from_n Summary

**creel_power() and cv_from_n() complete the four-function pre-season planning suite using a two-sample normal approximation and algebraic CV inversion**

## Performance

- **Duration:** 22 min
- **Started:** 2026-03-24T00:08:29Z
- **Completed:** 2026-03-24T00:30:00Z
- **Tasks:** 2 (TDD: 3 commits per task — RED/GREEN)
- **Files modified:** 5

## Accomplishments

- Implemented creel_power(): two-sample normal approximation with two.sided/one.sided options; known-value check n=100, cv=0.5, delta=0.20 produces 0.807 to tolerance 0.001
- Implemented cv_from_n(): algebraic inverse dispatching on type="effort"/"cpue"; round-trips cleanly (recovered CV <= target CV) for both branches
- All 42 power-suite tests green (POWER-01 through POWER-04); replaced Plan 01 skip() stubs with full test coverage

## Task Commits

Each task was committed atomically:

1. **RED: Failing tests for POWER-03 and POWER-04** - `f5e5401` (test)
2. **GREEN: creel_power() implementation** - `cb0b32b` (feat)
3. **GREEN: cv_from_n() implementation** - `0472a54` (feat)

_Note: TDD tasks have multiple commits (test RED -> feat GREEN)_

## Files Created/Modified

- `R/power-sample-size.R` - creel_power() and cv_from_n() appended to existing file
- `tests/testthat/test-power-sample-size.R` - POWER-03/04 skip() stubs replaced with full assertions
- `man/creel_power.Rd` - roxygen2 documentation with known-value example
- `man/cv_from_n.Rd` - roxygen2 documentation with round-trip examples and seealso links
- `NAMESPACE` - creel_power and cv_from_n exported

## Decisions Made

- creel_power() uses delta_pct as a fraction (0.20 = 20%) with a warning when delta_pct > 5; chosen because biologists occasionally pass percent points rather than fractions
- cv_from_n() uses a single function with type= dispatch rather than two separate functions; keeps the API symmetric with the forward pair
- Round-trip tests use expect_lte not expect_equal because ceiling() in creel_n_effort/creel_n_cpue means the inverse always produces a CV slightly at or below target

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Lint fix: nolint comments on calculation comments in test file**
- **Found during:** RED commit (test task)
- **Issue:** commented_code_linter flagged mathematical derivation comments in test_that block
- **Fix:** Added `# nolint: commented_code_linter` to three math-derivation comments
- **Files modified:** tests/testthat/test-power-sample-size.R
- **Verification:** Pre-commit lintr hook passed on second attempt
- **Committed in:** f5e5401 (part of RED commit)

**2. [Rule 3 - Blocking] Styler auto-formatted R source after cv_from_n() addition**
- **Found during:** GREEN commit for cv_from_n()
- **Issue:** style-files pre-commit hook modified R/power-sample-size.R spacing
- **Fix:** Re-staged modified file, recommitted
- **Files modified:** R/power-sample-size.R
- **Verification:** Second commit attempt passed all hooks
- **Committed in:** 0472a54

---

**Total deviations:** 2 auto-fixed (both Rule 3 — blocking hook failures resolved inline)
**Impact on plan:** Trivial formatting corrections. No scope creep, no logic changes.

## Issues Encountered

The pre-existing WARNING in devtools::check() (`read_schedule.Rd: coerce_schedule_columns` cross-reference) was confirmed pre-existing from Phase 48. Not introduced by this plan. Verification confirmed 0 new errors or warnings attributable to this plan's changes.

## Next Phase Readiness

- Complete four-function pre-season planning suite ready: creel_n_effort(), creel_n_cpue(), creel_power(), cv_from_n()
- Phase 49 Plans 03 and 04 are now skippable — their requirement stubs were implemented here in Plan 02
- Phase 50 (validate_design) can proceed: creel_n_effort() and creel_n_cpue() are available for internal calls

## Self-Check: PASSED

All files and commits verified present.

---
*Phase: 49-power-and-sample-size*
*Completed: 2026-03-24*
