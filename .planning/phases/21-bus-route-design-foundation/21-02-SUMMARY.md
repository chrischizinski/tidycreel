---
phase: 21-bus-route-design-foundation
plan: 02
subsystem: creel-design
tags: [bus-route, creel-design, format, print, get-sampling-frame, testthat, cli, rlang]

# Dependency graph
requires:
  - phase: 21-bus-route-design-foundation
    plan: 01
    provides: "creel_design(survey_type = 'bus_route') constructor with bus_route slot, pi_i precomputation, Tier 1 validation"
provides:
  - "format.creel_design() Bus-Route section: site/circuit/p_site/p_period/pi_i table (up to 10 rows with truncation)"
  - "get_sampling_frame() exported helper returning design$bus_route$data with informative error for non-bus-route designs"
  - "19 new bus-route tests covering constructor, validation, format output, and helper function"
  - "NAMESPACE export for get_sampling_frame"
affects:
  - phase: 22-bus-route-design-validation
  - phase: 23-bus-route-data-integration
  - phase: 24-bus-route-estimation

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Bus-Route print section uses nolint: object_usage_linter on cli interpolation variables (same pattern as validate_creel_design)"
    - "format.creel_design() conditional block: !is.null(x$bus_route) guard before Bus-Route section"
    - "get_sampling_frame() follows same guard pattern as all creel_design helpers: inherit check, then slot-specific check"
    - "Test helpers make_br_sf() and make_br_cal() defined at section scope (not inside test blocks)"

key-files:
  created:
    - man/get_sampling_frame.Rd
  modified:
    - R/creel-design.R
    - NAMESPACE
    - man/creel_design.Rd
    - tests/testthat/test-creel-design.R

key-decisions:
  - "Bus-Route section placed AFTER Interviews block in format.creel_design() so instantaneous designs see no change"
  - "get_sampling_frame() placed after print.creel_design() and before summary.creel_design() — alphabetical proximity to design methods"
  - "Table capped at 10 rows with '... and N more rows' truncation to avoid overwhelming print output"

patterns-established:
  - "Bus-Route test helpers (make_br_sf, make_br_cal) defined at section scope for DRY test setup"
  - "get_sampling_frame() returns raw data frame (not a copy), consistent with other accessor helpers"

# Metrics
duration: 8min
completed: 2026-02-17
---

# Phase 21 Plan 02: Bus-Route Print Output and Tests Summary

**format.creel_design() Bus-Route section with site/circuit/pi_i table, get_sampling_frame() exported helper, and 19 comprehensive tests proving all Phase 21 constructor behaviors**

## Performance

- **Duration:** 8 min
- **Started:** 2026-02-17T03:48:38Z
- **Completed:** 2026-02-17T03:56:00Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Extended `format.creel_design()` with a conditional Bus-Route Design section that shows site, circuit, p_site, p_period, and pi_i values rounded to 4 decimal places (up to 10 rows with truncation)
- Implemented and exported `get_sampling_frame()` helper that returns `design$bus_route$data`; aborts with informative cli error for non-bus-route designs and non-creel_design inputs
- Wrote 19 new bus-route tests covering: constructor acceptance, pi_i computation, column mappings, circuit default/explicit, scalar p_period, validation errors (sum constraint, zero values, exceed-1, missing sampling_frame), floating-point tolerance, backward compatibility, format output, and helper function
- Total test suite increased from 935 (pre-Phase 21) to 972 passing; 0 regressions; R CMD check 0 errors, 0 warnings

## Task Commits

Each task was committed atomically:

1. **Task 1: Add Bus-Route section to format.creel_design() and implement get_sampling_frame()** - `0eb6ce4` (feat)
2. **Task 2: Write tests for bus-route design constructor, validation, print, and helper** - `5f243e4` (test)

## Files Created/Modified

- `/Users/cchizinski2/Dev/tidycreel/R/creel-design.R` - Added Bus-Route section to format.creel_design() after Interviews block; added get_sampling_frame() function with roxygen docs
- `/Users/cchizinski2/Dev/tidycreel/NAMESPACE` - Added export(get_sampling_frame)
- `/Users/cchizinski2/Dev/tidycreel/man/get_sampling_frame.Rd` - Auto-generated from roxygen
- `/Users/cchizinski2/Dev/tidycreel/man/creel_design.Rd` - Auto-updated from roxygen
- `/Users/cchizinski2/Dev/tidycreel/tests/testthat/test-creel-design.R` - Added 19 bus-route test cases in new "Bus-Route design" section

## Decisions Made

- **Bus-Route section after Interviews block**: Placed the conditional bus-route section at the end of `format.creel_design()` so that instantaneous designs (the vast majority) never encounter the new code path, preserving backward compatibility.
- **10-row truncation cap**: Print output shows at most 10 rows of the sampling frame with a "... and N more rows" message for larger frames, preventing overwhelming terminal output on real-world designs with many sites.
- **get_sampling_frame() after print.creel_design()**: Positioned the new helper function between the print and summary methods to maintain logical grouping of creel_design methods, making the file easy to navigate.

## Deviations from Plan

None - plan executed exactly as written.

The one minor auto-action was handling the pre-commit `styler` hook reformatting the new code after the initial commit attempt (same behavior as Task 1 in Plan 01). Staged the styled file and committed cleanly on the second attempt. All hooks passed on the second attempt.

## Issues Encountered

- Pre-commit hook (`styler`) reformatted `R/creel-design.R` after Task 1's first commit attempt. Staged the styled changes and re-committed successfully. This is the same pattern encountered in Phase 21 Plan 01 and is expected behavior for this codebase.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- `format.creel_design()` now shows complete bus-route design information; users can `print(design)` to inspect their sampling frame probabilities
- `get_sampling_frame(design)` provides a clean API for extracting the sampling frame for inspection or downstream use
- All 19 bus-route constructor behaviors are proven by passing tests; Phase 22 can build validation tests with confidence
- Phase 22 (Tier 2 validation: multi-circuit cross-checks, additional warning conditions) can now extend the test file using the established `make_br_sf()` / `make_br_cal()` helpers

## Self-Check: PASSED

- R/creel-design.R: FOUND
- NAMESPACE: FOUND
- man/get_sampling_frame.Rd: FOUND
- tests/testthat/test-creel-design.R: FOUND
- Commit 0eb6ce4: FOUND
- Commit 5f243e4: FOUND
- NAMESPACE export for get_sampling_frame: FOUND
- Bus-Route section in creel-design.R: FOUND
- bus_route tests in test file: FOUND

---
*Phase: 21-bus-route-design-foundation*
*Completed: 2026-02-17*
