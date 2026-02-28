---
phase: 25-bus-route-harvest-estimation
plan: 01
subsystem: api
tags: [r-package, creel-survey, bus-route, harvest-estimation, total-catch, horvitz-thompson, jones-pollock]

# Dependency graph
requires:
  - phase: 24-bus-route-effort-estimation
    plan: 01
    provides: "estimate_effort_br() dispatch pattern, creel-estimates-bus-route.R file, site_contributions attribute approach"
  - phase: 24-bus-route-effort-estimation
    plan: 02
    provides: "get_site_contributions() accessor; design$n_counted_col, design$n_interviewed_col"
  - phase: 23-data-integration
    provides: "add_interviews() with .expansion and .pi_i columns in design$interviews"
  - phase: 22-inclusion-probability-calculation
    provides: "design$bus_route$site_col, circuit_col; .pi_i in interview data via sampling frame join"
provides:
  - "estimate_harvest_br() internal estimator implementing Jones & Pollock (2012) Eq. 19.5"
  - "estimate_total_catch_br() internal estimator implementing catch-column variant of Eq. 19.5"
  - "br_build_estimates() shared helper for HT estimate construction from .contribution column"
  - "estimate_harvest() bus-route dispatch with verbose=FALSE and use_trips=NULL parameters"
  - "estimate_total_catch() bus-route dispatch with verbose=FALSE parameter"
  - "site_contributions attribute on returned harvest/total-catch objects: h_i/c_i, pi_i, ratio columns"
  - "use_trips= diagnostic mode returning creel_estimates_diagnostic for harvest bus-route"
affects:
  - 26-primary-source-validation
  - 27-documentation

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Shared br_build_estimates() helper: estimate_harvest_br() and estimate_total_catch_br() both delegate to this helper after computing .contribution column, eliminating duplication"
    - "use_trips= dispatch within bus-route estimator: complete (Eq. 19.5 direct), incomplete (pi_i-weighted MOR), diagnostic (both paths, returns creel_estimates_diagnostic)"
    - "verbose= message emitted once at dispatch level (estimate_harvest dispatch block), then verbose=FALSE passed to internal estimator to avoid double-printing"

key-files:
  created: []
  modified:
    - R/creel-estimates-bus-route.R
    - R/creel-estimates.R
    - R/creel-estimates-total-catch.R
    - man/estimate_harvest.Rd
    - man/estimate_total_catch.Rd

key-decisions:
  - "Bus-route dispatch for estimate_harvest() placed BEFORE interview_survey NULL check: bus-route designs use design$interviews not design$interview_survey; NULL check guarded with !identical(design_type, 'bus_route')"
  - "Bus-route dispatch for estimate_total_catch() placed BEFORE validate_design_compatibility(): that function checks design$survey and design$counts which are NULL for bus-route designs"
  - "verbose=FALSE passed to estimate_harvest_br() from dispatch block (message already emitted in dispatch block — avoids double-printing if user passes verbose=TRUE)"
  - "br_build_estimates() shared helper extracts grouped/ungrouped estimation logic shared by both harvest and catch estimators (key_col parameter accepted but not used for n — n is always nrow(interviews))"
  - "Incomplete trip path for harvest: pi_i-weighted MOR using h_ratio_i = harvest_col / effort_col per row, then contribution_i = h_ratio_i / .pi_i — statistically consistent with bus-route framework"

patterns-established:
  - "Shared internal helper pattern: br_build_estimates() serves as the engine for all bus-route HT estimation, callable from both harvest and catch estimators after setting .contribution column"
  - "Symmetric catch/harvest estimators: estimate_total_catch_br() mirrors estimate_harvest_br() exactly but uses design$catch_col instead of design$harvest_col"

requirements-completed:
  - BUSRT-04
  - BUSRT-10

# Metrics
duration: 7min
completed: 2026-02-24
---

# Phase 25 Plan 01: Bus-Route Harvest Estimation Summary

**Jones & Pollock (2012) Eq. 19.5 bus-route harvest estimator (H_hat = sum(h_i/pi_i)) with estimate_harvest() and estimate_total_catch() dispatch, use_trips= parameter support, and shared br_build_estimates() helper**

## Performance

- **Duration:** 7 min
- **Started:** 2026-02-24T14:53:31Z
- **Completed:** 2026-02-24T15:00:00Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Extended `R/creel-estimates-bus-route.R` with `estimate_harvest_br()` implementing Eq. 19.5: H_hat = sum(h_i / pi_i) where h_i = harvest_col * .expansion
- Added `estimate_total_catch_br()` as symmetric function using catch_col instead of harvest_col: C_hat = sum(c_i / pi_i)
- Added `br_build_estimates()` shared helper that handles ungrouped/grouped estimation, eliminating code duplication between the two estimators
- `use_trips=` parameter supports "complete" (default Eq. 19.5), "incomplete" (pi_i-weighted MOR), and "diagnostic" (returns `creel_estimates_diagnostic` with both results)
- Zero-count site handling: n_counted=0, n_interviewed=0 sets h_i/c_i to 0, contributing 0 to total
- `site_contributions` attribute stored on returned objects with h_i/c_i, pi_i, ratio columns for Phase 26 traceability
- Updated `estimate_harvest()` with `verbose=FALSE` and `use_trips=NULL` parameters; bus-route dispatch block before `interview_survey` NULL check; guard updated for bus-route designs
- Updated `estimate_total_catch()` with `verbose=FALSE` parameter; bus-route dispatch block before `validate_design_compatibility()`
- All 1045 existing tests pass (0 regressions); R CMD check 0 errors, 0 warnings; lintr 0 issues

## Task Commits

Each task was committed atomically:

1. **Task 1: Bus-route harvest and total-catch estimator core** - `5cf9a00` (feat)
2. **Task 2: estimate_harvest() and estimate_total_catch() bus-route dispatch** - `4ecfafd` (feat)

**Plan metadata:** (docs commit below)

## Files Created/Modified

- `R/creel-estimates-bus-route.R` - Extended with `estimate_harvest_br()`, `estimate_total_catch_br()`, and `br_build_estimates()` helper
- `R/creel-estimates.R` - Updated `estimate_harvest()` with `verbose=`, `use_trips=` parameters and bus-route dispatch; guarded `interview_survey` NULL check
- `R/creel-estimates-total-catch.R` - Updated `estimate_total_catch()` with `verbose=` parameter and bus-route dispatch
- `man/estimate_harvest.Rd` - Regenerated by devtools::document() with new @param entries
- `man/estimate_total_catch.Rd` - Regenerated by devtools::document() with new @param entry

## Decisions Made

- Bus-route dispatch for `estimate_harvest()` placed before `interview_survey` NULL check: bus-route designs set `design$interviews` but not `design$interview_survey`. Guard updated to `!identical(design$design_type, "bus_route") && is.null(design$interview_survey)`. Same pattern established in Phase 24-01 for `estimate_effort()`.
- Bus-route dispatch for `estimate_total_catch()` placed before `validate_design_compatibility()`: that helper function checks `design$survey` and `design$counts` which are always NULL for bus-route designs (they use `design$interviews` instead).
- `verbose=FALSE` passed to `estimate_harvest_br()` from the dispatch block: the dispatch block already emitted the informational message when `verbose=TRUE`, so passing `verbose=FALSE` to the internal function prevents double-printing.
- `br_build_estimates()` shared helper: both `estimate_harvest_br()` and `estimate_total_catch_br()` converge on identical survey estimation logic after computing `.contribution`. The helper accepts a `key_col` argument for API symmetry but `n` is always `nrow(interviews)`.
- Incomplete trip path uses pi_i-weighted MOR: `h_ratio_i = harvest_col / effort_col`, then `contribution_i = h_ratio_i / .pi_i`. This is statistically consistent with the bus-route framework (each ratio is weighted by its inclusion probability).

## Deviations from Plan

### Auto-fixed Issues

None - plan executed exactly as written.

---

**Total deviations:** 0
**Impact on plan:** None.

## Issues Encountered

Pre-commit hook (styler) reformatted multi-line function signatures in two commits: both required a second `git add` + `git commit` after styler auto-applied formatting. Standard project workflow — not an error.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Bus-route harvest and total-catch estimation complete: `estimate_harvest()` and `estimate_total_catch()` both dispatch correctly for `design_type == "bus_route"`
- `site_contributions` attribute available for Phase 26 validation against Malvestuto (1996) Box 20.6
- `use_trips=` diagnostic mode available for Phase 26 completeness testing
- Ready for Phase 25-02 (bus-route harvest test suite) or Phase 26 (Malvestuto validation)

## Self-Check: PASSED

- R/creel-estimates-bus-route.R: FOUND (extended)
- R/creel-estimates.R: FOUND (updated)
- R/creel-estimates-total-catch.R: FOUND (updated)
- 25-01-SUMMARY.md: FOUND
- commit 5cf9a00: FOUND
- commit 4ecfafd: FOUND
- devtools::test() FAIL 0: VERIFIED (1045 PASS)
- R CMD check 0 errors 0 warnings: VERIFIED
- lintr::lint_package() 0 issues: VERIFIED

---
*Phase: 25-bus-route-harvest-estimation*
*Completed: 2026-02-24*
