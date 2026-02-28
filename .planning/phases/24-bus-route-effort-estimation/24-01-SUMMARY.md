---
phase: 24-bus-route-effort-estimation
plan: 01
subsystem: api
tags: [r-package, creel-survey, bus-route, effort-estimation, horvitz-thompson, jones-pollock]

# Dependency graph
requires:
  - phase: 23-data-integration
    plan: 01
    provides: "add_interviews() with .expansion and .pi_i columns in design$interviews"
  - phase: 23-data-integration
    plan: 02
    provides: "get_enumeration_counts() accessor; design$n_counted_col and design$n_interviewed_col"
  - phase: 22-inclusion-probability-calculation
    provides: "design$bus_route$site_col, circuit_col; .pi_i in interview data via sampling frame join"
  - phase: 21-bus-route-design
    provides: "design$design_type == 'bus_route'; design$bus_route slot structure"
provides:
  - "estimate_effort_br() internal estimator implementing Jones & Pollock (2012) Eq. 19.4"
  - "estimate_effort() bus-route dispatch before standard tier-2 validation"
  - "estimate_effort() verbose=FALSE parameter for opt-in dispatch transparency"
  - "site_contributions attribute on returned object: e_i, pi_i, e_i_over_pi_i per interview row"
  - "Grouped by= output includes proportion column for bus-route designs"
affects:
  - 25-harvest-estimation
  - 26-primary-source-validation
  - 27-documentation

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Bus-route dispatch before tier-2 validation: if (design_type == 'bus_route') return early, bypassing standard count-based validation"
    - "HT estimator via survey::svytotal on .contribution column (e_i/pi_i), preserving variance structure"
    - "Site contributions stored as attribute on creel_estimates object for downstream traceability"
    - "Defensive column existence check pattern: check .expansion and .pi_i before use, hard error on missing"

key-files:
  created:
    - R/creel-estimates-bus-route.R
  modified:
    - R/creel-estimates.R

key-decisions:
  - "Bus-route dispatch placed BEFORE design$survey NULL check: bus-route uses interviews not counts, so design$survey is NULL for bus-route designs; guard updated to skip NULL check for bus_route design_type"
  - "NA .expansion rows (n_counted>0, n_interviewed=0): flow into sum with NA contribution; na.rm=TRUE in sum() silently excludes them (statistically appropriate — cannot estimate effort without interview data)"
  - "Zero-effort sites (n_counted=0, n_interviewed=0): .e_i set to 0 before division (not NA), contributing 0 to total"
  - "verbose=FALSE default keeps API clean; only bus-route dispatch triggers message (standard path silent)"

patterns-established:
  - "Attribute-based diagnostics: store per-site breakdown as attr(result, 'site_contributions') for traceability without cluttering the main creel_estimates structure"
  - "Grouped bus-route output: proportion column added alongside estimate/se/ci for circuit-level breakdown"

requirements-completed:
  - BUSRT-03
  - BUSRT-09

# Metrics
duration: 5min
completed: 2026-02-17
---

# Phase 24 Plan 01: Bus-Route Effort Estimation Summary

**Horvitz-Thompson bus-route effort estimator implementing Jones & Pollock (2012) Eq. 19.4 with estimate_effort() dispatch and per-site diagnostic attribute**

## Performance

- **Duration:** 5 min
- **Started:** 2026-02-17T19:05:24Z
- **Completed:** 2026-02-17T19:10:19Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Created `R/creel-estimates-bus-route.R` with `estimate_effort_br()` implementing Eq. 19.4: E_hat = sum(e_i / pi_i) where e_i = effort * .expansion
- Zero-effort sites (n_counted=0, n_interviewed=0) contribute 0 to the sum; sites where n_counted>0 but n_interviewed=0 contribute NA (excluded by na.rm=TRUE, statistically appropriate)
- Hard error on missing .pi_i that lists specific site+circuit combinations failing the join
- `site_contributions` attribute on returned object with e_i, pi_i, e_i_over_pi_i columns for traceability (Phase 26 validation)
- Grouped by= output includes `proportion` column showing each group's share of total effort
- Updated `estimate_effort()` with `verbose=FALSE` parameter and bus-route dispatch before standard tier-2 validation
- All 1026 existing tests pass; 0 regressions; R CMD check 0 errors, 0 warnings; lintr 0 issues

## Task Commits

Each task was committed atomically:

1. **Task 1: Bus-route effort estimator core (estimate_effort_br)** - `fc975a9` (feat)
2. **Task 2: estimate_effort() dispatch + verbose= parameter** - `f936b4b` (feat)

**Plan metadata:** (docs commit below)

## Files Created/Modified

- `R/creel-estimates-bus-route.R` - New file: estimate_effort_br() internal estimator (Jones & Pollock 2012 Eq. 19.4), handles ungrouped/grouped cases, defensive column checks, site_contributions attribute
- `R/creel-estimates.R` - Updated estimate_effort() with verbose=FALSE parameter, bus-route dispatch block, updated @param/@return roxygen

## Decisions Made

- Bus-route dispatch placed BEFORE the `design$survey` NULL check (not after): bus-route designs never call `add_counts()` and thus `design$survey` is NULL; the guard was updated to skip the NULL check for `bus_route` design_type
- NA expansion handling: sites where n_counted>0 and n_interviewed=0 produce NA .expansion (warned during add_interviews in Phase 23-01). These rows have NA .e_i and NA .contribution — `sum(..., na.rm = TRUE)` silently excludes them. This is statistically appropriate: we know anglers were present but have no interview data to estimate their effort
- verbose=TRUE fires an informational message for bus-route designs only; standard designs produce no message regardless of verbose value

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed design$survey NULL check to allow bus-route designs**
- **Found during:** Task 2 (dispatch implementation)
- **Issue:** The original `if (is.null(design$survey))` check would fire for every bus-route design because bus-route designs use interviews (not counts) and never call add_counts(). This would block bus-route effort estimation entirely
- **Fix:** Changed guard to `if (!identical(design$design_type, "bus_route") && is.null(design$survey))` so the NULL check only applies to non-bus_route designs
- **Files modified:** R/creel-estimates.R
- **Verification:** Standard design still errors without add_counts(); bus-route design proceeds to dispatch without error
- **Committed in:** f936b4b (Task 2 commit)

**2. [Rule 3 - Blocking] Added nolint comments for new_creel_estimates cross-file visibility**
- **Found during:** Task 1 pre-commit hook
- **Issue:** Pre-commit lintr flagged `new_creel_estimates` as "no visible global function definition" because it is defined in creel-estimates.R and lintr evaluates creel-estimates-bus-route.R in isolation
- **Fix:** Added `# nolint: object_usage_linter` to both `new_creel_estimates(` call sites in the new file
- **Files modified:** R/creel-estimates-bus-route.R
- **Verification:** lintr::lint() returns 0 issues; pre-commit passes
- **Committed in:** fc975a9 (Task 1 commit, fix applied before final commit)

---

**Total deviations:** 2 auto-fixed (1 Rule 1 bug, 1 Rule 3 blocking)
**Impact on plan:** Both fixes necessary for correct dispatch behavior and lintr compliance. No scope creep.

## Issues Encountered

- Pre-commit hook failed first commit attempt on Task 1 due to `object_usage_linter` for `new_creel_estimates` cross-file visibility. Added nolint comments and re-committed cleanly.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Bus-route effort estimation complete: `estimate_effort()` dispatches to `estimate_effort_br()` for bus_route designs
- `site_contributions` attribute available for Phase 26 validation against Malvestuto (1996) Box 20.6
- Ready for Phase 25: bus-route harvest estimation following the same dispatch pattern
- Design pattern established: bus-route estimators are internal functions in separate files, dispatched from public API functions

## Self-Check: PASSED

- R/creel-estimates-bus-route.R: FOUND
- R/creel-estimates.R: FOUND (updated)
- 24-01-SUMMARY.md: FOUND
- commit fc975a9: FOUND
- commit f936b4b: FOUND
- devtools::test() FAIL 0: VERIFIED
- R CMD check 0 errors 0 warnings: VERIFIED
- lintr::lint_package() 0 issues: VERIFIED

---
*Phase: 24-bus-route-effort-estimation*
*Completed: 2026-02-17*
