---
phase: 15-mean-of-ratios-estimator-core
plan: 02
subsystem: estimation
tags: [S3-classes, print-methods, diagnostics, warnings, cli-messaging]

# Dependency graph
requires:
  - phase: 15-01
    provides: MOR estimator core with estimate_cpue(estimator="mor") parameter
provides:
  - creel_estimates_mor S3 class enabling Phase 19 validation framework detection
  - Custom print method with diagnostic banner emphasizing complete trip preference
  - mor_estimation_warning() issuing warnings on every MOR call with trip counts
  - Print infrastructure in R/print-methods.R for MOR-specific messaging
affects: [phase-19-validation-framework]

# Tech tracking
tech-stack:
  added: [R/print-methods.R]
  patterns: [S3 class inheritance for diagnostic modes, cli diagnostic banners]

key-files:
  created:
    - R/print-methods.R
  modified:
    - R/creel-estimates.R
    - R/survey-bridge.R
    - tests/testthat/test-creel-estimates.R
    - tests/testthat/test-estimate-cpue.R

key-decisions:
  - "MOR class added BEFORE creel_estimates in class vector for S3 dispatch priority"
  - "Warning issued on EVERY MOR call (not once-per-session) per CONTEXT.md locked decisions"
  - "Trip counts (n_incomplete, n_total) stored in design object during MOR filtering for constructor access"

patterns-established:
  - "S3 class inheritance pattern: subclass constructor calls parent, adds metadata, prepends class name"
  - "Diagnostic mode pattern: Special S3 class with custom print showing warning banner + base output"
  - "cli::cli_format_method() for building multi-line banners in format methods"

# Metrics
duration: 6min
completed: 2026-02-15
---

# Phase 15 Plan 02: MOR Estimator Diagnostic Messaging Summary

**creel_estimates_mor S3 class with diagnostic banner, trip count metadata, and every-call warnings for incomplete trip estimation**

## Performance

- **Duration:** 6 min
- **Started:** 2026-02-15T17:41:30Z
- **Completed:** 2026-02-15T17:47:54Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- MOR estimates use creel_estimates_mor S3 class inheriting from creel_estimates
- Print method displays diagnostic banner with trip counts (n_incomplete of n_total)
- Every MOR call warns about incomplete trip assumptions and complete trip preference
- Phase 19 validation framework can detect MOR results via class check

## Task Commits

Each task was committed atomically:

1. **Task 1: Create MOR S3 class and print methods** - `94f77d9` (feat)
2. **Task 2: Add tests for MOR S3 class and messaging** - `924be76` (test)

## Files Created/Modified
- `R/print-methods.R` - Created with format.creel_estimates_mor() and print.creel_estimates_mor() methods
- `R/creel-estimates.R` - Added new_creel_estimates_mor() constructor, updated estimate_cpue_total/grouped to use MOR constructor
- `R/survey-bridge.R` - Added mor_estimation_warning() function
- `tests/testthat/test-creel-estimates.R` - Added 4 MOR S3 class tests with make_mor_test_design() helper
- `tests/testthat/test-estimate-cpue.R` - Added 4 MOR warning tests
- `NAMESPACE` - Exported format.creel_estimates_mor and print.creel_estimates_mor

## Decisions Made

**MOR class dispatch priority:** Added "creel_estimates_mor" BEFORE "creel_estimates" in class vector to ensure custom format/print methods are called first via S3 dispatch.

**Trip count storage:** Stored n_incomplete and n_total in design object (design$mor_n_incomplete, design$mor_n_total) during MOR filtering to preserve values after design reassignment. Alternative would have been passing counts through function parameters, but storing in design object kept function signatures cleaner.

**Warning timing:** Issue warning BEFORE estimation (after validation) so users see it even if estimation fails. This ensures the warning appears on every attempt, not just successful ones.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

**cli::cli_rule line parameter:** Initial implementation used `cli::cli_rule(line = 2)` which doesn't exist in current cli version. Fixed by removing the parameter - cli_rule draws a rule line by default.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- MOR S3 class infrastructure complete
- Phase 16 (trip truncation thresholds) can proceed
- Phase 19 validation framework can detect MOR results via `inherits(result, "creel_estimates_mor")`
- All 718 tests pass (8 new MOR-specific tests)
- R CMD check: 0 errors, 0 warnings
- lintr: 0 issues in modified files

## Self-Check: PASSED

All files and commits verified:
- ✓ R/print-methods.R created
- ✓ R/creel-estimates.R modified
- ✓ R/survey-bridge.R modified
- ✓ tests/testthat/test-creel-estimates.R modified
- ✓ tests/testthat/test-estimate-cpue.R modified
- ✓ Commit 94f77d9 exists
- ✓ Commit 924be76 exists

---
*Phase: 15-mean-of-ratios-estimator-core*
*Completed: 2026-02-15*
