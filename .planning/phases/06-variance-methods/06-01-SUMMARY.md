---
phase: 06-variance-methods
plan: 01
subsystem: estimation
tags: [variance, bootstrap, jackknife, taylor, survey, replication, resampling]

# Dependency graph
requires:
  - phase: 05-grouped-estimation
    provides: estimate_effort() with by parameter using survey::svyby()
provides:
  - estimate_effort() with variance parameter ("taylor", "bootstrap", "jackknife")
  - get_variance_design() helper for replicate-weight conversion
  - Bootstrap variance via as.svrepdesign(type="bootstrap", replicates=500)
  - Jackknife variance via as.svrepdesign(type="auto")
  - Reference tests verifying bootstrap/jackknife correctness
affects: [07-output-formats, future-variance-extensions]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Variance method routing via get_variance_design() helper"
    - "Replicate-weight designs (svrepdesign) for bootstrap/jackknife"
    - "Reference tests with set.seed() for reproducible bootstrap tests"

key-files:
  created: []
  modified:
    - R/creel-estimates.R
    - R/survey-bridge.R
    - tests/testthat/test-estimate-effort.R
    - man/estimate_effort.Rd

key-decisions:
  - "Fixed 500 replicates for bootstrap (research recommendation, no user-facing parameter)"
  - "Jackknife uses type='auto' (survey package selects JKn vs JK1 based on design)"
  - "Taylor remains default variance method (appropriate for most smooth statistics)"
  - "Bootstrap and jackknife work with grouped estimation (same svyby routing)"

patterns-established:
  - "Internal helper pattern: get_variance_design() converts design based on method"
  - "variance_method parameter flows through estimate_effort() → internal functions → new_creel_estimates()"
  - "Reference tests compare tidycreel output to manual survey package calculations"

# Metrics
duration: 14min
completed: 2026-02-09
---

# Phase 6 Plan 1: Variance Method Selection Summary

**estimate_effort() gains variance parameter with bootstrap (500 replicates) and jackknife via survey::as.svrepdesign(), verified by reference tests matching manual calculations**

## Performance

- **Duration:** 14 min
- **Started:** 2026-02-09T16:21:13Z
- **Completed:** 2026-02-09T16:35:40Z
- **Tasks:** 2 (TDD: RED → GREEN)
- **Files modified:** 4

## Accomplishments
- Variance method selection: estimate_effort() accepts variance = "taylor" | "bootstrap" | "jackknife"
- Bootstrap variance uses as.svrepdesign(type="bootstrap", replicates=500) with suppressWarnings
- Jackknife variance uses as.svrepdesign(type="auto") for automatic JKn/JK1 selection
- get_variance_design() internal helper converts designs for replicate-weight methods
- 19 new tests covering validation, behavior, backward compatibility, grouped estimation, and reference tests
- Reference tests verify bootstrap/jackknife estimates match manual survey package calculations (tolerance 1e-10)
- Backward compatible: estimate_effort(design) still defaults to variance="taylor"
- Works with grouped estimation: by parameter and variance parameter compose correctly

## Task Commits

Each task was committed atomically following TDD protocol:

1. **Task 1: RED - Write failing tests** - `754fa93` (test)
   - 19 new tests for variance parameter validation, bootstrap behavior, jackknife behavior
   - Backward compatibility tests, grouped estimation tests, reference tests
   - All fail with "unused argument (variance = ...)" as expected

2. **Task 2: GREEN - Implement variance method selection** - `5128ab0` (feat)
   - Add variance parameter to estimate_effort() with validation
   - Implement get_variance_design() helper in R/survey-bridge.R
   - Update estimate_effort_total() and estimate_effort_grouped() to use variance_method
   - Pass actual variance_method (not hardcoded "taylor") to new_creel_estimates()
   - Update roxygen2 documentation
   - All 238 tests pass (197 existing + 19 new variance + 22 other)

## Files Created/Modified
- `R/creel-estimates.R` - Added variance parameter to estimate_effort(), updated estimate_effort_total() and estimate_effort_grouped() to accept and use variance_method
- `R/survey-bridge.R` - Added get_variance_design() internal helper for replicate-weight conversion
- `tests/testthat/test-estimate-effort.R` - Added 19 tests for variance method selection
- `man/estimate_effort.Rd` - Updated with variance parameter documentation

## Decisions Made

**Fixed bootstrap replicates at 500:**
- Research (06-RESEARCH.md) recommended 500 as sweet spot for accuracy/speed
- No user-facing replicates parameter to avoid complexity
- Users choosing bootstrap/jackknife understand tradeoffs

**Jackknife type="auto":**
- Survey package automatically selects JKn or JK1 based on design structure
- Eliminates need for user to understand technical jackknife variants
- Follows survey package best practices

**Taylor remains default:**
- Research confirmed Taylor linearization appropriate for smooth statistics
- Bootstrap/jackknife are opt-in for special cases (non-smooth stats, assumption verification)
- Maintains Phase 4/5 behavior for existing code

**SuppressWarnings on as.svrepdesign:**
- Survey package issues warnings about singleton PSUs during conversion
- Warnings are expected and non-critical for replicate-weight conversion
- Following pattern from construct_survey_design()

## Deviations from Plan

None - plan executed exactly as written. All tasks completed as specified, no auto-fixes needed.

## Issues Encountered

**Pre-existing Rd warnings from Phase 4:**
- estimate_effort.Rd has "Lost braces" warnings during R CMD check
- Issue exists since Phase 4, documented in 04-01-SUMMARY.md and 05-01-SUMMARY.md
- Does not affect package functionality: all 238 tests pass, examples run correctly
- Affects estimate_effort.Rd only; other .Rd files (add_counts.Rd, creel_design.Rd) check cleanly
- Code works correctly, documentation displays properly in help system
- Issue appears to be roxygen2 parsing quirk with specific file structure
- Documented as known issue, not blocking for Phase 6

## User Setup Required

None - no external service configuration required. Variance method selection is pure computation using existing survey package capabilities.

## Next Phase Readiness

**Ready for Phase 7 (output formats):**
- estimate_effort() now complete with full variance method support
- variance_method field in creel_estimates object correctly reflects method used
- format.creel_estimates() already handles bootstrap/jackknife display (switch statement from Phase 4)
- All must-have requirements for EST-09, EST-11, EST-12 satisfied
- TEST-05 integration tests pass with all variance methods
- Backward compatibility maintained: existing code continues to work

**No blockers:** Phase 6 Plan 1 complete, ready to proceed to output format enhancements.

---
*Phase: 06-variance-methods*
*Completed: 2026-02-09*

## Self-Check: PASSED

**Files verified:**
- R/creel-estimates.R - EXISTS
- R/survey-bridge.R - EXISTS
- tests/testthat/test-estimate-effort.R - EXISTS
- man/estimate_effort.Rd - EXISTS

**Commits verified:**
- 754fa93 - test(06-01): add failing tests for variance method selection
- 5128ab0 - feat(06-01): implement variance method selection (bootstrap, jackknife)

**Tests verified:**
- 238 tests passing (0 failures)
- 197 existing tests + 19 new variance tests + 22 other tests
- All variance method selection tests passing

**Claims verified:**
- estimate_effort() accepts variance parameter with three valid values
- Bootstrap uses as.svrepdesign(type="bootstrap", replicates=500)
- Jackknife uses as.svrepdesign(type="auto")
- get_variance_design() helper implemented in R/survey-bridge.R
- Backward compatible: variance="taylor" is default
- Reference tests verify correctness with tolerance 1e-10
