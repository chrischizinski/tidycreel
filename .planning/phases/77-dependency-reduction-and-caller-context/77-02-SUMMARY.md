---
phase: 77-dependency-reduction-and-caller-context
plan: 02
subsystem: api
tags: [rlang, cli, caller-env, bus-route, creel-estimates, error-handling]

# Dependency graph
requires:
  - phase: 77-dependency-reduction-and-caller-context
    provides: 77-01 lubridate soft-dependency pattern (Suggests + check_installed)
provides:
  - 5 bus-route estimators with call = rlang::caller_env() for accurate error call frames
  - get_site_contributions() relocated to R/creel-estimates-utils.R (Layer 2)
  - R/creel-design.R cleaned of Layer 2 estimation utility
affects: [Phase 78, any future work touching bus-route error messages or get_site_contributions()]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "caller_env thread pattern: add call = rlang::caller_env() as last function param, pass call = call to all cli_abort() calls"
    - "Recursive caller propagation: explicit call = call in recursive calls inside estimate_harvest_br()"
    - "Architectural layering: estimation utilities (Layer 2) separated from design utilities (Layer 1)"

key-files:
  created:
    - R/creel-estimates-utils.R
  modified:
    - R/creel-estimates-bus-route.R
    - R/creel-design.R

key-decisions:
  - "get_site_contributions() relocated to creel-estimates-utils.R because it consumes creel_estimates (Layer 2) output, not creel_design (Layer 1) objects"
  - "call = call passed explicitly in estimate_harvest_br() recursive calls to preserve the user's call frame through diagnostic mode dispatch"

patterns-established:
  - "caller_env thread pattern: add call = rlang::caller_env() as last function param, pass call = call to all cli_abort() calls — matching survey-bridge.R:309 precedent"
  - "Layer separation: creel-estimates-utils.R holds functions that consume creel_estimates objects; creel-design.R holds functions that consume creel_design objects"

requirements-completed: [CODE-02, CODE-03]

# Metrics
duration: 8min
completed: 2026-04-20
---

# Phase 77 Plan 02: caller_env Threading and get_site_contributions Relocation Summary

**All 5 bus-route estimator internals now thread call = rlang::caller_env() for accurate user-frame error reporting; get_site_contributions() relocated from creel-design.R (Layer 1) to new creel-estimates-utils.R (Layer 2)**

## Performance

- **Duration:** 8 min
- **Started:** 2026-04-20T21:08:38Z
- **Completed:** 2026-04-20T21:16:42Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Added `call = rlang::caller_env()` to all 5 bus-route estimator function signatures: `estimate_effort_br()`, `estimate_harvest_br()`, `estimate_total_catch_br()`, `estimate_total_harvest_br()`, `estimate_total_release_br()`
- Threaded `call = call` through all 13 `cli::cli_abort()` calls in those functions, including both recursive calls in `estimate_harvest_br()` diagnostic mode
- Created `R/creel-estimates-utils.R` with the complete `get_site_contributions()` block (pure relocation, no functional change)
- Removed `get_site_contributions()` from `R/creel-design.R`, correcting the architectural mismatch between the function's input type (creel_estimates) and its source file's layer (creel_design)

## Task Commits

Each task was committed atomically:

1. **Task 1: Thread caller_env into 5 bus-route estimator functions** - `74d228f` (feat)
2. **Task 2: Relocate get_site_contributions() to new creel-estimates-utils.R** - `54573b0` (feat)

**Plan metadata:** (docs commit below)

## Files Created/Modified
- `R/creel-estimates-bus-route.R` - 5 function signatures + 13 cli_abort calls updated with caller_env/call = call
- `R/creel-estimates-utils.R` - New file: bus-route estimation utilities; get_site_contributions() with full roxygen block
- `R/creel-design.R` - get_site_contributions() removed (60 lines deleted)

## Decisions Made
- `get_site_contributions()` relocated to `creel-estimates-utils.R` because it operates on `creel_estimates` objects (Layer 2 output), not `creel_design` objects (Layer 1) — the @seealso cross-reference from `get_site_contributions()` to `get_enumeration_counts()` is retained since both relate to bus-route HT estimation context
- The `get_enumeration_counts()` @seealso in creel-design.R did not reference `get_site_contributions()` and required no change

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Phase 77 Plan 02 complete; bus-route error messages now cite the user's call frame
- Ready for Phase 77 Plan 03 or Phase 78 @family tag work
- 2528 tests passing, 0 failures

---
*Phase: 77-dependency-reduction-and-caller-context*
*Completed: 2026-04-20*
