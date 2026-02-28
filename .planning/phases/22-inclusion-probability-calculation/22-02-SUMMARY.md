---
phase: 22-inclusion-probability-calculation
plan: 02
subsystem: creel-design
tags: [bus-route, inclusion-probability, pi_i, p_period, golden-tests, property-tests, tdd, jones-pollock]

# Dependency graph
requires:
  - phase: 22-inclusion-probability-calculation
    plan: 01
    provides: p_period uniformity validation, pi_i range check, get_inclusion_probs() implementation

provides:
  - Comprehensive test section "Inclusion probability calculation" in test-creel-design.R
  - 4 golden tests proving pi_i = p_site * p_period to 1e-10 tolerance
  - 4 p_period uniformity validation tests (including multi-circuit and scalar p_period cases)
  - 5 get_inclusion_probs() unit tests (structure, values, multi-circuit, error cases)
  - 2 property tests (range invariant, vectorization consistency)

affects:
  - 23-data-integration
  - 24-effort-estimation
  - 25-harvest-estimation
  - 26-validation

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Golden tests use tolerance = 1e-10 (consistent with package reference test standard)"
    - "expect_error() checks both error message pattern and rlang_error class for validation tests"
    - "make_br_sf_2circuit() helper defined at section scope for multi-circuit test reuse"
    - "CLI-formatted error messages matched with partial pattern ('must be a') not exact class name string"

key-files:
  created: []
  modified:
    - tests/testthat/test-creel-design.R

key-decisions:
  - "Error message pattern for 'must be a creel_design object' test uses 'must be a' partial match because CLI formatting adds angle brackets around class name: '<creel_design>'"
  - "make_br_sf_2circuit() helper defined at Inclusion probability calculation section scope (not Bus-Route scope) to keep helper locality"
  - "15 test cases covers all spec requirements: 4 golden + 4 uniformity + 5 accessor + 2 property"

patterns-established:
  - "Section helper functions (make_br_sf_2circuit) defined immediately before section tests"
  - "Golden tests verify exact arithmetic products with 1e-10 tolerance using same values as spec"

# Metrics
duration: 3min
completed: 2026-02-17
---

# Phase 22 Plan 02: Inclusion Probability Calculation Tests Summary

**15-test inclusion probability test section with golden pi_i arithmetic tests, p_period uniformity validation, get_inclusion_probs() unit tests, and range invariant property tests (BUSRT-05, VALID-03)**

## Performance

- **Duration:** 3 min
- **Started:** 2026-02-17T04:34:13Z
- **Completed:** 2026-02-17T04:37:13Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments
- Added "Inclusion probability calculation" test section (15 test cases) to test-creel-design.R
- Golden tests prove pi_i = p_site * p_period to 1e-10 tolerance for single-circuit scalar p_period, column p_period, multi-circuit, and boundary (1.0) cases
- Validation tests confirm p_period uniformity check fires with circuit name in error message and that circuits with different-but-uniform p_period values pass without error
- get_inclusion_probs() tests verify 3-column return structure, correct column names, matching values against bus_route$data$.pi_i, multi-circuit case, and both error conditions
- Property tests confirm all pi_i values are in (0, 1] for edge-case combinations and that vectorization produces independent per-site products
- Total suite: 1000 tests, 0 failures; R CMD check 0 errors, 0 warnings; lintr 0 issues

## Task Commits

Each task was committed atomically:

1. **Task 1: Inclusion probability test section** - `16f691c` (test)

## Files Created/Modified
- `tests/testthat/test-creel-design.R` - Added "Inclusion probability calculation" section with 15 test cases: 4 golden, 4 uniformity validation, 5 get_inclusion_probs() unit tests, 2 property tests; added make_br_sf_2circuit() helper

## Decisions Made
- Error message pattern for non-creel_design input test uses "must be a" partial match because CLI's `{.cls class}` formatting wraps the class name in angle brackets ("must be a `<creel_design>` object"), making exact string matching brittle
- `make_br_sf_2circuit()` helper defined at "Inclusion probability calculation" section scope rather than "Bus-Route design" scope — keeps helper co-located with its users without polluting the earlier section
- 15 test cases aligns exactly with plan spec: 4+4+5+2 distribution

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Test pattern "must be a creel_design object" didn't match CLI-formatted error**
- **Found during:** Task 1 (get_inclusion_probs() error tests)
- **Issue:** The expect_error() pattern "must be a creel_design object" failed because CLI formatting wraps the class name with angle brackets: the actual error reads "must be a `<creel_design>` object"
- **Fix:** Changed pattern to "must be a" (partial match) and added a second expect_error() checking for class = "rlang_error" to maintain strong test coverage
- **Files modified:** tests/testthat/test-creel-design.R
- **Verification:** Test passed after fix; 94 tests pass in creel-design test file
- **Committed in:** 16f691c (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 Rule 1 bug)
**Impact on plan:** Minor fix required for CLI formatting behavior. No scope creep.

## Issues Encountered
- CLI's `{.cls}` inline markup adds angle brackets around class names in error messages, making exact string matching fail for the error message test

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Test suite fully documents pi_i calculation behavior with golden values and property guarantees
- BUSRT-05 (nonuniform probability sampling) and VALID-03 (two-stage sampling produces correct probability products) demonstrably addressed
- Phase 23 (data integration) can proceed — test infrastructure and production code both complete

## Self-Check: PASSED

- FOUND: tests/testthat/test-creel-design.R (modified with 15 new tests)
- FOUND: .planning/phases/22-inclusion-probability-calculation/22-02-SUMMARY.md
- FOUND commit: 16f691c (Task 1 - test section)
- VERIFIED: 1000 tests pass (devtools::test()), 0 failures
- VERIFIED: 0 errors, 0 warnings (devtools::check(cran = FALSE))
- VERIFIED: 0 lint issues (lintr::lint_package())

---
*Phase: 22-inclusion-probability-calculation*
*Completed: 2026-02-17*
