---
phase: 45-ice-fishing-survey-support
plan: "02"
subsystem: estimation
tags: [ice-fishing, add-interviews, estimate-catch-rate, estimate-total-catch, bus-route, TDD]

# Dependency graph
requires:
  - phase: 45-01
    provides: "ice constructor, synthetic bus_route slot, effort dispatch via estimate_effort_br()"
provides:
  - "validate_ice_interviews_tier3(): n_counted/n_interviewed presence check for ice without site/circuit join-key validation"
  - "add_interviews() ice Tier 3 path: validates then attaches n_counted, n_interviewed, and .pi_i (scalar broadcast)"
  - "estimate_total_catch() dispatch widened to include 'ice' via %in% c('bus_route','ice')"
  - "estimate_total_catch_br() site_table: uses intersect() to skip synthetic .ice_site/.circuit cols absent from ice interviews"
affects:
  - 45-03
  - 46-camera-survey-support

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Ice interview validation as separate Tier 3 helper that shares presence checks but skips site/circuit join-key assertions"
    - "intersect() on site/circuit cols before building site_table — pattern now applied in both estimate_effort_br() and estimate_total_catch_br()"

key-files:
  created: []
  modified:
    - "R/creel-design.R"
    - "R/creel-estimates-total-catch.R"
    - "R/creel-estimates-bus-route.R"
    - "tests/testthat/test-creel-design.R"
    - "tests/testthat/test-estimate-catch-rate.R"
    - "tests/testthat/test-estimate-total-catch.R"

key-decisions:
  - "Ice Tier 3 validation is a new helper (validate_ice_interviews_tier3) rather than conditionally calling validate_br_interviews_tier3 — avoids contaminating bus_route slot dereferences with ice guard logic"
  - "estimate_total_catch_br() site_table uses intersect() to omit synthetic .ice_site/.circuit columns absent in ice interviews — same pattern already used by estimate_effort_br()"
  - "catch rate fixture requires >= 10 complete trips (survey package minimum for stable CPUE); ice test fixture uses 10-day calendar"

patterns-established:
  - "New survey types that reuse bus_route estimator path must guard synthetic column names with intersect() in site_table construction"

requirements-completed: [ICE-04]

# Metrics
duration: 12min
completed: 2026-03-16
---

# Phase 45 Plan 02: Ice Interview Pipeline Summary

**add_interviews() extended for ice (n_counted/n_interviewed validation + .pi_i scalar broadcast) and estimate_total_catch() dispatch widened to include ice; full CPUE and total catch estimation confirmed working**

## Performance

- **Duration:** 12 min
- **Started:** 2026-03-16T00:07:59Z
- **Completed:** 2026-03-16T00:19:38Z
- **Tasks:** 2 (TDD: RED + GREEN + REFACTOR)
- **Files modified:** 6

## Accomplishments

- validate_ice_interviews_tier3(): new internal helper enforces n_counted and n_interviewed presence for ice designs (skips site/circuit join-key checks used by bus_route)
- add_interviews() Tier 3 dispatch now fires for ice; .pi_i scalar broadcast from p_period_scalar confirmed working in interviews data frame
- estimate_total_catch() dispatch guard widened from `== "bus_route"` to `%in% c("bus_route", "ice")`; ice reuses HT total catch path unchanged
- Full test suite: 1622 tests, 0 failures (net +12 from ICE-04 tests)

## Task Commits

Each task was committed atomically:

1. **RED phase: failing ICE-04 tests** - `add57fa` (test)
2. **GREEN phase: ice validation, dispatch, intersect fix** - `fcae6f5` (feat)

_Note: TDD tasks produce test then feat commits_

## Files Created/Modified

- `R/creel-design.R` - Added validate_ice_interviews_tier3() helper; added ice Tier 3 dispatch block in add_interviews()
- `R/creel-estimates-total-catch.R` - Widened dispatch guard to %in% c("bus_route", "ice")
- `R/creel-estimates-bus-route.R` - estimate_total_catch_br(): use intersect() for site_table column selection
- `tests/testthat/test-creel-design.R` - ICE-04 tests: missing n_counted/n_interviewed abort, valid path attaches interview_survey and .pi_i
- `tests/testthat/test-estimate-catch-rate.R` - ICE-04 test: 10-day ice fixture confirms estimate_catch_rate() returns valid creel_estimates
- `tests/testthat/test-estimate-total-catch.R` - ICE-04 test: 4-day ice fixture confirms estimate_total_catch() returns valid creel_estimates

## Decisions Made

- Ice Tier 3 validation implemented as a separate helper (validate_ice_interviews_tier3) rather than reusing validate_br_interviews_tier3 with guards. The bus-route validator has hard site/circuit column dereferences that would require messy conditional logic for ice.
- estimate_total_catch_br() site_table construction adopted the intersect() pattern already present in estimate_effort_br(). This is the canonical way to handle synthetic columns absent from ice interview rows.
- catch rate fixture needs >= 10 complete trips (survey package hard requirement). Used a 10-day calendar with 6 weekday + 4 weekend days; total catch fixture uses a 4-day calendar which is sufficient for the HT estimator.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] estimate_total_catch_br() crashed on ice due to synthetic column selection**
- **Found during:** GREEN phase Task 2 (estimate_total_catch dispatch)
- **Issue:** `site_table <- interviews[c(site_col, circuit_col, ".c_i", ".pi_i", ".contribution")]` failed because `.ice_site` and `.circuit` (synthetic bus_route slot column names) do not exist in ice interview data frames
- **Fix:** Changed site_table construction to `avail_site_cols <- intersect(c(site_col, circuit_col), names(interviews))` — same pattern already used in estimate_effort_br()
- **Files modified:** R/creel-estimates-bus-route.R
- **Verification:** estimate_total_catch() ice test passes; all 86 estimate-total-catch tests green
- **Committed in:** fcae6f5 (GREEN phase commit)

**2. [Rule 1 - Bug] Test fixtures produced "one PSU" survey error from single-stratum interview**
- **Found during:** GREEN phase Task 2 (fixture design)
- **Issue:** 3-interview fixture with 2 weekday + 1 weekend gave "Stratum (weekend) has only one PSU at stage 1" from survey package
- **Fix:** Expanded to 4 rows (2 per stratum) for total catch; 10 rows for catch rate (minimum 10 complete trips requirement)
- **Files modified:** test-estimate-catch-rate.R, test-estimate-total-catch.R
- **Verification:** Both estimator ICE-04 tests pass; no survey errors
- **Committed in:** fcae6f5 (GREEN phase commit)

---

**Total deviations:** 2 auto-fixed (2 Rule 1 bugs)
**Impact on plan:** Both fixes were necessary to reach green. No scope creep — same fix pattern (intersect()) already existed in estimate_effort_br().

## Issues Encountered

- test_that() bare column names in add_interviews() calls (walleye_catch, n_counted, etc.) are tidy-eval and don't trigger object_usage_linter. Helper function creel_design() and day_type bare column do trigger it — required # nolint: object_usage_linter on those lines only.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- ICE-04 complete: full ice fishing survey pipeline (constructor → effort → interviews → catch rate → total catch) is operational
- Phase 45-03 (quality gate) can confirm 1622 tests pass and R CMD check clean before camera survey work begins
- camera survey (Phase 46) can follow the established pattern: synthetic bus_route slot + intersect() for site_table construction

## Self-Check: PASSED

All files verified present. All commits verified in git log.

---
*Phase: 45-ice-fishing-survey-support*
*Completed: 2026-03-16*
