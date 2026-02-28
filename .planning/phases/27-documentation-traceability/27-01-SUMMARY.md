---
phase: 27-documentation-traceability
plan: 01
subsystem: documentation
tags: [vignette, rmarkdown, bus-route, horvitz-thompson, malvestuto, creel]

# Dependency graph
requires:
  - phase: 26-primary-source-validation
    provides: Validated bus-route estimation workflow reproducing Malvestuto (1996) Box 20.6
  - phase: 24-bus-route-effort-estimation
    provides: estimate_effort(), get_site_contributions() for bus-route designs
  - phase: 25-bus-route-harvest-estimation
    provides: estimate_harvest(), estimate_total_catch() for bus-route designs
  - phase: 23-bus-route-data-integration
    provides: add_interviews() with n_counted/n_interviewed bus-route support
  - phase: 21-bus-route-design-constructor
    provides: creel_design() with survey_type="bus_route" and sampling_frame
provides:
  - "vignettes/bus-route-surveys.Rmd: fully knittable bus-route workflow vignette (DOCS-01 to DOCS-03, DOCS-05)"
  - "Step-by-step code walkthrough reproducing E_hat = 847.5 angler-hours (Malvestuto 1996 Box 20.6)"
  - "Educational explanation of pi_i = p_site * p_period vs incorrect existing implementations"
affects:
  - phase: 27-02 (bus-route-equations.Rmd traceability document)
  - downstream: v0.4.0 milestone completion

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Vignette structure mirrors interview-estimation.Rmd: YAML header, setup chunk with knitr::opts_chunk$set, library() in first chunk"
    - "Inline data for small datasets (15 rows) rather than package dataset"
    - "trip_status='complete' required even for bus-route designs (add_interviews API)"

key-files:
  created:
    - vignettes/bus-route-surveys.Rmd
  modified: []

key-decisions:
  - "trip_status='complete' added to add_interviews() call — required parameter even for bus-route designs where trip completion is always complete"
  - "Interview data row ordering follows validated test data in test-primary-source-validation.R (D at rows 13-14, C row 6 at row 15) to match E_hat = 847.5 exactly"
  - "Vignette uses Malvestuto (1996) Box 20.6 Example 1 inline data — same as primary source validation tests for traceability"

patterns-established:
  - "Vignette example data matches test suite data exactly for result traceability"

requirements-completed: [DOCS-01, DOCS-02, DOCS-03, DOCS-05]

# Metrics
duration: 2min
completed: 2026-02-28
---

# Phase 27 Plan 01: Bus-Route Surveys Vignette Summary

**Bus-route survey workflow vignette teaching inclusion probability (pi_i = p_site * p_period), enumeration expansion, and Horvitz-Thompson estimation with Malvestuto (1996) Box 20.6 data producing E_hat = 847.5 angler-hours**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-28T21:02:52Z
- **Completed:** 2026-02-28T21:05:21Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments
- Created `vignettes/bus-route-surveys.Rmd` (317 lines) covering all five required sections
- Vignette knits without errors with `pkgload::load_all()` active
- E_hat = 847.5 angler-hours confirmed in code output, matching Malvestuto (1996) Box 20.6
- Documents correct pi_i = p_site * p_period vs hardcoded pi_i in existing R packages

## Task Commits

Each task was committed atomically:

1. **Task 1: Write vignettes/bus-route-surveys.Rmd** - `667a586` (feat)

## Files Created/Modified
- `vignettes/bus-route-surveys.Rmd` - Complete bus-route workflow vignette (317 lines, knits cleanly)

## Decisions Made
- `trip_status = "complete"` added to `add_interviews()` call because it is a required parameter in the function signature even for bus-route designs
- Interview data row ordering follows the validated test data from `test-primary-source-validation.R` (Site D at rows 13-14, Site C row 6 at row 15) to ensure E_hat = 847.5

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Added missing required `trip_status` parameter to `add_interviews()` call**
- **Found during:** Task 1 (Write vignettes/bus-route-surveys.Rmd)
- **Issue:** The plan's vignette code called `add_interviews()` without `trip_status`, which is a required positional parameter in the function signature. The call would error: `argument "trip_status" is missing`.
- **Fix:** Added `trip_status = trip_status` to the `add_interviews()` call and `trip_status = "complete"` column to the interview data frame
- **Files modified:** vignettes/bus-route-surveys.Rmd
- **Verification:** Vignette knits without error, `add_interviews()` call succeeds
- **Committed in:** `667a586` (Task 1 commit)

**2. [Rule 1 - Bug] Corrected interview data row ordering to match validated test data**
- **Found during:** Task 1 (Write vignettes/bus-route-surveys.Rmd)
- **Issue:** The plan's data had Site D at rows 13-14 and Site C at row 15 (site column: `"C","C","C","C","C","C","D","D","D","D"` grouping), but cross-referencing the validated `test-primary-source-validation.R` showed Site C row 6 appears at position 15, with Site D at positions 13-14. The correct sequence is `..., "D", "D", "C"` for the last three rows.
- **Fix:** Used exact row layout from `make_box20_6_example1()` in the test file: dates/sites/hours_fished match the validated test helper
- **Files modified:** vignettes/bus-route-surveys.Rmd
- **Verification:** E_hat = 847.5 confirmed by running the vignette's data inline
- **Committed in:** `667a586` (Task 1 commit)

---

**Total deviations:** 2 auto-fixed (both Rule 1 - Bug)
**Impact on plan:** Both auto-fixes required for vignette to knit and produce correct results. No scope creep.

## Issues Encountered
- Pre-commit hook (styler) reformatted trailing whitespace in R code chunks on first commit attempt; staged restyled file and committed successfully on second attempt.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- `vignettes/bus-route-surveys.Rmd` complete and validated — ready for Plan 02 (equation traceability vignette)
- DOCS-01, DOCS-02, DOCS-03, DOCS-05 satisfied
- DOCS-04 (equation traceability) remains for Plan 02

---
*Phase: 27-documentation-traceability*
*Completed: 2026-02-28*
