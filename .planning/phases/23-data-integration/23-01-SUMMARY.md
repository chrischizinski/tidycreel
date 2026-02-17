---
phase: 23-data-integration
plan: 01
subsystem: api
tags: [r-package, creel-survey, bus-route, tidy-selectors, validation, inclusion-probability]

# Dependency graph
requires:
  - phase: 22-inclusion-probability-calculation
    provides: ".pi_i computed and stored in design$bus_route$data at creel_design() construction time"
  - phase: 21-bus-route-design
    provides: "bus_route slot on creel_design with site_col, circuit_col, pi_i_col, data"
provides:
  - "add_interviews() extended with n_counted and n_interviewed tidy selectors"
  - "validate_br_interviews_tier3() internal Tier 3 validator for bus-route interview structure"
  - ".pi_i joined from sampling frame to interview rows by site + circuit"
  - ".expansion = n_counted / n_interviewed computed on interview rows"
  - "design$n_counted_col and design$n_interviewed_col stored on returned object"
affects:
  - 23-02-PLAN
  - 24-effort-estimation
  - 25-harvest-estimation

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Tier 3 validation: bus-route-specific checks fire at add_interviews() time using checkmate::makeAssertCollection()"
    - "rlang::enquo() / quo_is_null() / resolve_single_col() for optional tidy selector parameters"
    - "dplyr::left_join with stats::setNames() for site+circuit probability join"
    - "Internal column .expansion follows .pi_i dot-prefix convention for computed fields"

key-files:
  created: []
  modified:
    - R/creel-design.R
    - man/add_interviews.Rd

key-decisions:
  - "validate_br_interviews_tier3 shortened to validate_br_interviews_tier3 (28 chars) to satisfy lintr object_length_linter 30-char limit"
  - "n_interviewed = 0 rows produce NA expansion factor (not error); warn only when n_counted > 0 and n_interviewed = 0"
  - "Unmatched site+circuit combinations produce hard error listing specific bad combos for user diagnosis"
  - "Expansion factor (.expansion) and inclusion probability (.pi_i) both stored as internal dot-prefix columns on interview rows"

patterns-established:
  - "Tier 3 validator pattern: bus-route-specific checks collected via makeAssertCollection() then fired as batch, numeric checks fired individually after"
  - "Optional tidy selector pattern for enumeration params matches existing harvest/trip_duration selector style"

requirements-completed:
  - BUSRT-08
  - BUSRT-02
  - VALID-04

# Metrics
duration: 5min
completed: 2026-02-17
---

# Phase 23 Plan 01: Data Integration Summary

**add_interviews() extended with bus-route enumeration selectors (n_counted, n_interviewed), Tier 3 validation, pi_i join from sampling frame by site+circuit, and .expansion factor computation**

## Performance

- **Duration:** 5 min
- **Started:** 2026-02-17T18:03:22Z
- **Completed:** 2026-02-17T18:08:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Extended `add_interviews()` with two new optional tidy selectors: `n_counted` and `n_interviewed` for bus-route enumeration data
- Added `validate_br_interviews_tier3()` internal function with Tier 3 bus-route-specific validation: missing enumeration columns, missing join key columns, n_counted < n_interviewed constraint, negative values
- Implemented pi_i join from sampling frame to interview rows by site + circuit, with hard error listing specific unmatched site+circuit combinations
- Computed `.expansion = n_counted / n_interviewed` on interview rows (NA when n_interviewed = 0, with warning when n_counted > 0)
- Stored `n_counted_col` and `n_interviewed_col` on returned design object for downstream use in Phases 24-25
- Non-bus-route designs silently ignore enumeration parameters

## Task Commits

Each task was committed atomically:

1. **Task 1+2: add_interviews() extension and validate_br_interviews_tier3()** - `d25055f` (feat)

**Plan metadata:** (docs commit below)

## Files Created/Modified

- `R/creel-design.R` - Extended add_interviews() signature, added n_counted/n_interviewed resolvers, Tier 3 validation call, pi_i join block, .expansion computation, validate_br_interviews_tier3() function
- `man/add_interviews.Rd` - Updated documentation with n_counted and n_interviewed @param entries

## Decisions Made

- Shortened internal validator name from `validate_bus_route_interviews_tier3` (36 chars) to `validate_br_interviews_tier3` (28 chars) to satisfy lintr `object_length_linter` 30-character limit — behavior unchanged
- n_interviewed = 0 rows produce NA expansion factor (not an error); warn only when n_counted > 0 and n_interviewed = 0 to flag "anglers seen but none interviewed" as a data quality signal
- Unmatched site+circuit combinations produce a hard error listing specific combos to help users diagnose typos or incomplete designs

## Deviations from Plan

None - plan executed exactly as written, except function name shortened from `validate_bus_route_interviews_tier3` to `validate_br_interviews_tier3` to satisfy lintr 30-character object name limit. This is a rename deviation (Rule 1 auto-fix class).

### Auto-fixed Issues

**1. [Rule 1 - Bug] Shortened internal validator name for lint compliance**
- **Found during:** Task 2 (Add validate_bus_route_interviews_tier3())
- **Issue:** `validate_bus_route_interviews_tier3` is 36 characters, exceeding lintr object_length_linter 30-char limit
- **Fix:** Renamed to `validate_br_interviews_tier3` (28 chars). All call sites updated.
- **Files modified:** R/creel-design.R
- **Verification:** lintr::lint_package() returns 0 issues
- **Committed in:** d25055f

---

**Total deviations:** 1 auto-fixed (1 lint compliance rename)
**Impact on plan:** Name change only; no behavior change. All Tier 3 validation behaviors identical.

## Issues Encountered

- Pre-commit hook's `styler` reformatted alignment whitespace in the bus-route block (reduced `br          <-` to `br <-` style). Committed the styler output directly — no behavioral change.

## Next Phase Readiness

- `design$interviews` rows now carry `.pi_i` (inclusion probability) and `.expansion` (enumeration expansion factor) for all bus-route interview data
- `design$n_counted_col` and `design$n_interviewed_col` stored for Plan 02 `get_enumeration_counts()` accessor
- Ready for Phase 23 Plan 02: `get_enumeration_counts()` accessor function

---
*Phase: 23-data-integration*
*Completed: 2026-02-17*
