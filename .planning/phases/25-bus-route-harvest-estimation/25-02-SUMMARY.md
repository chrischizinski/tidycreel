---
phase: 25-bus-route-harvest-estimation
plan: 02
subsystem: testing
tags: [testthat, bus-route, harvest, total-catch, Horvitz-Thompson, jones-pollock]

# Dependency graph
requires:
  - phase: 25-01
    provides: estimate_harvest_br(), estimate_total_catch_br(), bus-route dispatch in estimate_harvest() and estimate_total_catch()
  - phase: 24-02
    provides: Phase 24 bus-route test patterns (make_br_effort_design/interviews helpers, verbose/dispatch patterns)
provides:
  - Bus-route harvest estimation test suite (10 tests) in test-estimate-harvest.R
  - Bus-route total-catch estimation test suite (6 tests) in test-estimate-total-catch.R
  - make_br_harvest_design() / make_br_harvest_interviews() section-scope helpers
  - make_br_catch_design() / make_br_catch_interviews() section-scope helpers
affects:
  - phase-26-malvestuto-validation (uses site_contributions attribute; these tests document expected accessor behavior)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Section-scope test helpers (make_br_*_design/interviews) per Phase 21-02 / 22-02 convention
    - Interview dates spread across 4 calendar dates to satisfy survey PSU requirement for trip filtering paths
    - expect_no_message(suppressWarnings()) for verbose=FALSE tests (survey pkg emits expected 'no weights' warning)
    - trip_status always included in interview data frame and always passed to add_interviews()

key-files:
  created: []
  modified:
    - tests/testthat/test-estimate-harvest.R
    - tests/testthat/test-estimate-total-catch.R

key-decisions:
  - "Interview dates spread across 4 calendar dates (not all on same date) to satisfy survey PSU requirement when filtering to incomplete/diagnostic trip paths"
  - "trip_status column always included in interviews_df with default 'complete'; trip_status_col=TRUE overrides with mixed complete/incomplete values spanning 2+ dates per stratum"
  - "H_hat golden value recalculated with 2 Site B rows (B=0.40 pi_i) replacing original single-row design; golden value remains 135.833... because Site B rows (1,0) contribute 2.5+0=2.5 same as original"

patterns-established:
  - "Bus-route test helpers: define make_br_*_design() and make_br_*_interviews() at section scope, mirroring Phase 24 effort pattern"
  - "Golden test arithmetic: hand-compute H_hat = sum(h_i/pi_i) with expansion factors, verify to tolerance 1e-6"
  - "verbose=FALSE test uses expect_no_message(suppressWarnings(...)) not expect_silent() due to survey package warning"

requirements-completed: [BUSRT-04, BUSRT-10]

# Metrics
duration: 6min
completed: 2026-02-24
---

# Phase 25 Plan 02: Bus-Route Harvest and Total-Catch Test Suite Summary

**16 new tests covering bus-route dispatch, Eq. 19.5 golden arithmetic (H_hat=135.833...), use_trips modes, verbose, site_contributions, and grouped estimation for both harvest and total-catch estimators**

## Performance

- **Duration:** 6 min
- **Started:** 2026-02-24T15:04:14Z
- **Completed:** 2026-02-24T15:10:51Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Bus-route harvest estimation test suite (10 tests) appended to test-estimate-harvest.R with section-scope helpers
- Bus-route total-catch estimation test suite (6 tests) appended to test-estimate-total-catch.R with section-scope helpers
- Full test suite grows from 1045 to 1066 tests, FAIL = 0, lintr 0 issues, R CMD check 0 errors/0 warnings

## Task Commits

Each task was committed atomically:

1. **Task 1: Bus-route harvest estimation test suite** - `21bbbee` (test)
2. **Task 2: Bus-route total-catch estimation test suite** - `6766fa2` (test)

**Plan metadata:** (final commit, see below)

## Files Created/Modified
- `tests/testthat/test-estimate-harvest.R` - Bus-route harvest estimation section appended (144 lines: 2 helpers + 10 tests)
- `tests/testthat/test-estimate-total-catch.R` - Bus-route total-catch estimation section appended (105 lines: 2 helpers + 6 tests)

## Decisions Made
- Interview dates spread across 4 calendar dates (not all on same date) so that when trip filtering reduces to incomplete-only rows, each stratum still has >= 2 PSUs for survey::svydesign()
- trip_status column always present in interviews_df (with default "complete") and always passed to add_interviews() since it is a required parameter
- For trip_status_col=TRUE, incomplete trips assigned to 2 different dates (one per stratum group) to prevent single-PSU failure in use_trips="incomplete" path

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Added date column and strata to creel_design() call in make_br_harvest_design()**
- **Found during:** Task 1 (Bus-route harvest estimation test suite)
- **Issue:** Plan's creel_design() call omitted required `date = date` and `strata = day_type` arguments; creel_design() requires both
- **Fix:** Added `date = date, strata = day_type` to match Phase 24 effort helper pattern
- **Files modified:** tests/testthat/test-estimate-harvest.R
- **Verification:** Tests run without error
- **Committed in:** 21bbbee (Task 1 commit)

**2. [Rule 1 - Bug] Spread interview dates across 4 dates to prevent single-PSU failure for use_trips=incomplete**
- **Found during:** Task 1 (use_trips='incomplete' and 'diagnostic' tests)
- **Issue:** Original 6 interviews all on "2024-06-01" caused survey::svydesign() to fail with "Design has only one primary sampling unit" when filtered to incomplete trips (1 row remaining)
- **Fix:** Spread 6 interviews across dates 2024-06-01 through 2024-06-04 (2 per date pair), ensuring >= 2 PSUs survive trip filtering; golden H_hat preserved at 135.833...
- **Files modified:** tests/testthat/test-estimate-harvest.R
- **Verification:** FAIL 0 on use_trips=incomplete and diagnostic tests
- **Committed in:** 21bbbee (Task 1 commit)

---

**Total deviations:** 2 auto-fixed (1 missing critical, 1 bug)
**Impact on plan:** Both fixes necessary for tests to run; golden arithmetic unchanged; no scope creep.

## Issues Encountered
None beyond the two auto-fixed deviations above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Phase 25 complete: harvest + total-catch bus-route estimators implemented (Plan 01) and tested (Plan 02)
- Phase 26 (Malvestuto Validation) can proceed: site_contributions attribute available for Box 20.6 traceability
- Test suite provides regression protection for all bus-route estimation paths

## Self-Check: PASSED

- FOUND: tests/testthat/test-estimate-harvest.R
- FOUND: tests/testthat/test-estimate-total-catch.R
- FOUND: .planning/phases/25-bus-route-harvest-estimation/25-02-SUMMARY.md
- FOUND: commit 21bbbee (Task 1)
- FOUND: commit 6766fa2 (Task 2)

---
*Phase: 25-bus-route-harvest-estimation*
*Completed: 2026-02-24*
