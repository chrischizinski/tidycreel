---
phase: 80-inv-06-fix-and-quickcheck-proof
plan: "01"
subsystem: testing
tags: [estimation, stratified-sum, delta-method, tdd, quickcheck, invariants]

requires:
  - phase: 79-quickcheck-pbt-coverage
    provides: quickcheck generators, build_multispecies_design_for_tests helper

provides:
  - Fixed estimate_total_catch_ungrouped() using stratified-sum via compute_stratum_product_sum()
  - Fixed estimate_total_catch_grouped() using stratum_by_vars = union(strata_cols, by_vars)
  - cpue_for_stratum_product() helper that mirrors trip filtering of public API
  - Multi-strata test helper build_multistrata_multispecies_design_for_tests()
  - INV-06 multi-strata quickcheck property (gen_valid_creel_design_multistrata_multispecies)

affects: [creel-estimates-total-catch, test-invariants, test-estimate-total-catch]

tech-stack:
  added: []
  patterns:
    - "stratified-sum product estimator: per-stratum E_h * CPUE_h summed, not pooled E * CPUE"
    - "cpue_for_stratum_product(): filter to complete trips before estimate_cpue_grouped() call"
    - "stratum_by_vars = unique(c(strata_cols, by_vars)) for grouped total catch"

key-files:
  created: []
  modified:
    - R/creel-estimates-total-catch.R
    - tests/testthat/helper-generators.R
    - tests/testthat/test-invariants.R
    - tests/testthat/test-estimate-total-catch.R

key-decisions:
  - "Use cpue_for_stratum_product() helper to filter complete trips and call estimate_cpue_grouped() directly rather than going through public NSE estimate_catch_rate() API"
  - "Update reference tests to use single-stratum design where pooled delta == stratified sum, avoiding n<10 validation failure in example_data weekend stratum"
  - "Add build_multistrata_multispecies_design_for_tests() fixture with weekday/weekend strata as the canonical INV-06 multi-strata regression guard"

requirements-completed:
  - ESTIM-01

duration: 30min
completed: 2026-04-27
---

# Phase 80 Plan 01: INV-06 Fix and Quickcheck Proof Summary

**Stratified-sum product estimator (sum E_h*CPUE_h per stratum) replacing combined-ratio (E_pooled*CPUE_pooled) in estimate_total_catch_ungrouped() and estimate_total_catch_grouped(), verified by quickcheck INV-06 property across single- and multi-strata designs**

## Performance

- **Duration:** ~30 min
- **Started:** 2026-04-27T01:00:00Z
- **Completed:** 2026-04-27T01:26:03Z
- **Tasks:** 2 (Task 1: TDD fix + Task 2: rcmdcheck)
- **Files modified:** 4

## Accomplishments

- Diagnosed and fixed combined-ratio bug in `estimate_total_catch_ungrouped()` — multi-strata designs diverged from per-species sum by ~2 fish in seed-42 test
- Diagnosed and fixed combined-ratio bug in `estimate_total_catch_grouped()` — old code only grouped by by_vars, not union(strata_cols, by_vars)
- Added `cpue_for_stratum_product()` helper to replicate complete-trip filtering of public API without NSE complexity
- Added `build_multistrata_multispecies_design_for_tests()` and `gen_valid_creel_design_multistrata_multispecies()` for the two-stratum INV-06 regression guard
- INV-06 quickcheck property now covers both single-stratum and multi-strata designs (24/24 invariant tests pass)
- rcmdcheck: 0 errors, 0 warnings (2 pre-existing notes: hidden files, lifecycle import)

## Task Commits

1. **Task 1 RED: failing INV-06 multi-strata test** - `061c449` (test)
2. **Task 1 GREEN: stratified-sum fix** - `262d64a` (feat)

## Files Created/Modified

- `/Users/cchizinski2/Dev/tidycreel/R/creel-estimates-total-catch.R` - Added `cpue_for_stratum_product()` helper; rewrote `estimate_total_catch_ungrouped()` and `estimate_total_catch_grouped()` to use stratified-sum path
- `/Users/cchizinski2/Dev/tidycreel/tests/testthat/helper-generators.R` - Added `build_multistrata_multispecies_design_for_tests()` and `gen_valid_creel_design_multistrata_multispecies()`
- `/Users/cchizinski2/Dev/tidycreel/tests/testthat/test-invariants.R` - Added INV-06 multi-strata test with quickcheck property
- `/Users/cchizinski2/Dev/tidycreel/tests/testthat/test-estimate-total-catch.R` - Updated reference tests to use single-stratum fixture (stratified sum == pooled delta for 1 stratum)

## Decisions Made

- Used `cpue_for_stratum_product()` to filter complete trips before calling `estimate_cpue_grouped()` directly. This avoids NSE issues with the public `estimate_catch_rate()` API while preserving the same `n=` counts.
- Reference tests updated to use a 7-day, single-stratum (all weekday) design rather than `example_data` which has only 7 weekend complete trips (fails n>=10 validation). Single-stratum equivalence (pooled delta == stratified sum) keeps the mathematical identity testable.
- `build_multistrata_multispecies_design_for_tests()` added as permanent fixture alongside the existing single-stratum `build_multispecies_design_for_tests()`. The old fixture comment updated to remove the "re-evaluate once inconsistency resolved" note.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] estimate_cpue_grouped() bypasses complete-trip filtering**
- **Found during:** Task 1 GREEN (implementing fix)
- **Issue:** Calling `estimate_cpue_grouped()` directly skipped the `use_trips='complete'` filtering that `estimate_catch_rate()` applies, causing `n` to include incomplete trips and breaking the existing grouped test at line 491
- **Fix:** Added `cpue_for_stratum_product()` helper that explicitly filters to complete trips (mirroring public API) before calling internal helpers
- **Files modified:** R/creel-estimates-total-catch.R
- **Verification:** Grouped test `sum(result$estimates$n) == n_complete` passes
- **Committed in:** `262d64a`

**2. [Rule 1 - Bug] Reference tests assumed combined-ratio behavior**
- **Found during:** Task 1 GREEN
- **Issue:** Tests at lines 356, 372, 608 asserted `estimate == effort_pooled * cpue_pooled` — true for the old combined-ratio estimator but not the correct stratified-sum estimator. The `example_data` also has only 7 weekend complete trips, causing n<10 validation failure when grouped by day_type
- **Fix:** Updated reference tests to use a deterministic 15-interview, single-stratum (all weekday) design where pooled delta == stratified sum, keeping the invariant testable without requiring data changes
- **Files modified:** tests/testthat/test-estimate-total-catch.R
- **Verification:** 114/114 total-catch tests pass
- **Committed in:** `262d64a`

---

**Total deviations:** 2 auto-fixed (both Rule 1 bugs found during GREEN implementation)
**Impact on plan:** Both auto-fixes necessary for correctness. No scope creep.

## Issues Encountered

The plan referenced `estimate_catch_rate_grouped()` as the internal helper name, but the actual function is `estimate_cpue_grouped()`. Used the correct function name without issue.

## Next Phase Readiness

- INV-06 invariant holds for single-stratum, multi-strata, and quickcheck-generated designs
- `cpue_for_stratum_product()` helper is available for any future total-catch variant paths
- Ready for Phase 80 Plan 02 (remaining quickcheck proof tasks)

---
*Phase: 80-inv-06-fix-and-quickcheck-proof*
*Completed: 2026-04-27*
