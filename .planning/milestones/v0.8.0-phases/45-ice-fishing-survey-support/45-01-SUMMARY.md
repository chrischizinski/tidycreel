---
phase: 45-ice-fishing-survey-support
plan: 01
subsystem: creel-design
tags: [ice-fishing, bus-route, effort-estimation, tdd, r-package]

# Dependency graph
requires:
  - phase: 44-design-type-enum
    provides: VALID_SURVEY_TYPES enum guard and ice/camera/aerial stubs in creel_design()
provides:
  - Ice constructor with effort_type validation and p_site=1.0 enforcement
  - Synthetic bus_route slot for ice designs (enables pi_i join in add_interviews)
  - estimate_effort() dispatch for ice designs routed through estimate_effort_br()
  - Post-dispatch column rename: total_effort_hr_on_ice or total_effort_hr_active
  - estimate_effort(by=shelter_mode) grouping on ice designs
affects: [45-02-camera, 45-03-aerial, any future ice-specific estimation work]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Ice as degenerate bus-route: p_site=1.0 synthetic frame, pi_i=p_period"
    - "effort_type string controls column naming in estimate_effort() output"
    - "Synthetic bus_route slot on ice designs bypasses tier3 validation and probability checks"
    - "estimate_effort_br() site_table guards against missing synthetic cols with intersect()"

key-files:
  created: []
  modified:
    - R/creel-design.R
    - R/creel-estimates.R
    - R/creel-estimates-bus-route.R
    - man/creel_design.Rd
    - tests/testthat/test-creel-design.R
    - tests/testthat/test-estimate-effort.R

key-decisions:
  - "Ice dispatch reuses estimate_effort_br() without modification to the estimator itself"
  - "Synthetic bus_route slot (p_site=1.0, pi_i=p_period) lets add_interviews() add .pi_i without a new code path"
  - "effort_type is required (no default) — omitting it aborts with informative message naming valid values"
  - "p_site=1.0 enforcement uses abs(val-1.0)>1e-9 (floating-point safe); auto-detects 'p_site' column by name if selector not passed"
  - "validate_creel_design() and validate_br_interviews_tier3() skip p_site checks for ice (always 1.0)"
  - "site_table in estimate_effort_br() uses intersect() to skip synthetic .ice_site/.circuit cols missing from ice interviews"

patterns-established:
  - "Print method: ice section shown before bus_route section; bus_route section guarded by !identical(design_type, 'ice')"
  - "Post-dispatch rename pattern: result$estimates column renamed after estimate_effort_br() returns"

requirements-completed: [ICE-01, ICE-02, ICE-03]

# Metrics
duration: 14min
completed: 2026-03-15
---

# Phase 45 Plan 01: Ice Constructor, Dispatch, and Column Labeling Summary

**Ice fishing constructor with effort_type validation and p_site=1.0 enforcement, dispatching through bus-route HT estimator with renamed effort column**

## Performance

- **Duration:** 14 min
- **Started:** 2026-03-15T21:09:46Z
- **Completed:** 2026-03-15T21:23:45Z
- **Tasks:** 3 (RED, GREEN Task 1, GREEN Task 2 + REFACTOR)
- **Files modified:** 6

## Accomplishments
- Ice constructor filled: validates effort_type (required, "time_on_ice" or "active_fishing_time"), enforces p_site=1.0 in sampling_frame, builds ice slot with effort_type and p_period info
- Synthetic bus_route slot created for all ice designs (pi_i = p_period) so add_interviews() attaches .pi_i without a new code path
- estimate_effort() dispatch widened to include ice; post-dispatch renames "estimate" column to total_effort_hr_on_ice or total_effort_hr_active
- estimate_effort(by=shelter_mode) grouping works on ice designs (14 new tests, all passing)
- Full regression: 1610 tests passing, 0 errors, 0 warnings in R CMD check

## Task Commits

1. **RED: Failing tests for ice constructor and dispatch** - `8759f97` (test)
2. **GREEN: Implement ice constructor, p_site enforcement, and dispatch** - `ad538c2` (feat)
3. **REFACTOR: Document effort_type parameter** - `d9e6f45` (refactor)

## Files Created/Modified
- `R/creel-design.R` - Added effort_type param, filled ice branch with validation + synthetic bus_route, ice print section, skip bus_route tier3/probability validation for ice
- `R/creel-estimates.R` - Widened dispatch guard to include "ice", added post-dispatch column rename
- `R/creel-estimates-bus-route.R` - Guard site_table build with intersect() to tolerate missing synthetic cols
- `man/creel_design.Rd` - Added @param effort_type documentation (fixes R CMD check warning)
- `tests/testthat/test-creel-design.R` - ICE-01 and ICE-02 constructor tests (8 tests); updated stub test to require effort_type
- `tests/testthat/test-estimate-effort.R` - ICE-01/02/03 dispatch tests (6 tests)

## Decisions Made
- Ice reuses estimate_effort_br() without changing the estimator — the "degenerate bus-route with p_site=1.0" architecture holds exactly
- Synthetic bus_route slot is simpler than a parallel ice-specific join path in add_interviews()
- effort_type has no default — requiring it is more informative than defaulting to one value silently
- p_site column auto-detected by name ("p_site") in sampling_frame if no tidy selector passed, satisfying test case

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Skip bus_route probability validation for ice designs**
- **Found during:** GREEN Task 1 (ice constructor)
- **Issue:** validate_creel_design() accessed bus_route$p_site_col which is NULL for ice (p_site always 1.0)
- **Fix:** Added !identical(x$design_type, "ice") guard to Tier 1 bus-route probability validation block
- **Files modified:** R/creel-design.R
- **Verification:** creel-design tests pass
- **Committed in:** ad538c2 (feat commit)

**2. [Rule 2 - Missing Critical] Skip validate_br_interviews_tier3 for ice designs**
- **Found during:** GREEN Task 2 (dispatch integration)
- **Issue:** Tier3 validation checks interviews for synthetic site/circuit cols that ice interviews don't have
- **Fix:** Added !identical(design$design_type, "ice") guard before tier3 call
- **Files modified:** R/creel-design.R
- **Verification:** estimate-effort tests pass
- **Committed in:** ad538c2 (feat commit)

**3. [Rule 1 - Bug] Guard site_table build in estimate_effort_br() against missing cols**
- **Found during:** GREEN Task 2 (ice dispatch through estimate_effort_br)
- **Issue:** site_table used site_col/circuit_col directly; for ice these are synthetic and not in interviews
- **Fix:** Use intersect(c(site_col, circuit_col), names(interviews)) before selecting columns
- **Files modified:** R/creel-estimates-bus-route.R
- **Verification:** All 1610 tests pass
- **Committed in:** ad538c2 (feat commit)

**4. [Rule 2 - Missing] Document effort_type in roxygen to fix R CMD check warning**
- **Found during:** REFACTOR (R CMD check)
- **Issue:** New function parameter effort_type was undocumented — R CMD check WARNING
- **Fix:** Added @param effort_type entry to creel_design() roxygen; regenerated Rd
- **Files modified:** R/creel-design.R, man/creel_design.Rd
- **Verification:** devtools::check() returns 0 errors, 0 warnings
- **Committed in:** d9e6f45 (refactor commit)

---

**Total deviations:** 4 auto-fixed (2 missing critical, 1 bug, 1 missing doc)
**Impact on plan:** All fixes necessary for the ice-as-synthetic-bus-route architecture to work end-to-end. No scope creep.

## Issues Encountered
- p_site=1.0 enforcement silently skipped when user doesn't pass `p_site =` selector — resolved by also checking for a column literally named "p_site" in the sampling_frame by name

## Next Phase Readiness
- ICE-01, ICE-02, ICE-03 complete; ice designs fully functional through estimate_effort()
- Phase 45-02 (camera) and 45-03 (aerial) can proceed independently
- estimate_harvest_rate() not yet extended for ice — not in scope for this plan

---
*Phase: 45-ice-fishing-survey-support*
*Completed: 2026-03-15*

## Self-Check: PASSED

All key files found. All commits verified (8759f97, ad538c2, d9e6f45).
