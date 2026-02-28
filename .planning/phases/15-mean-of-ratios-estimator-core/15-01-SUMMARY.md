---
phase: 15-mean-of-ratios-estimator-core
plan: 01
subsystem: creel-estimation
tags: [cpue, mor, incomplete-trips, estimator-core]
dependency_graph:
  requires:
    - "13-01: trip_status infrastructure for incomplete trip identification"
    - "09-01: estimate_cpue baseline with ratio-of-means estimator"
  provides:
    - "estimator parameter for estimate_cpue() with 'mor' option"
    - "validate_mor_availability() validation function"
    - "Mean-of-ratios estimation for incomplete trips"
  affects:
    - "estimate_cpue() API expanded with estimator parameter"
tech_stack:
  added:
    - "survey::svymean() for mean-of-ratios estimation"
  patterns:
    - "Estimator dispatch pattern in estimate_cpue_total/grouped()"
    - "Filter-then-recreate survey design pattern for MOR"
key_files:
  created:
    - "R/survey-bridge.R::validate_mor_availability()"
  modified:
    - "R/creel-estimates.R::estimate_cpue()"
    - "R/creel-estimates.R::estimate_cpue_total()"
    - "R/creel-estimates.R::estimate_cpue_grouped()"
    - "tests/testthat/test-estimate-cpue.R"
    - "man/estimate_cpue.Rd"
decisions:
  - "MOR uses survey::svymean() on individual catch/effort ratios (not svyratio)"
  - "MOR automatically filters to incomplete trips only before estimation"
  - "Sample size validation (n<10 error, n<30 warning) applies to incomplete trips only when using MOR"
  - "All variance methods (taylor, bootstrap, jackknife) supported for MOR"
metrics:
  duration_minutes: 11
  tasks_completed: 2
  tests_added: 11
  tests_total: 713
  commits: 2
  files_modified: 5
completed: 2026-02-15
---

# Phase 15 Plan 01: Mean-of-Ratios Estimator Core Summary

**One-liner:** Add mean-of-ratios (MOR) estimator to estimate_cpue() for statistically appropriate incomplete trip CPUE estimation via survey::svymean() on individual catch/effort ratios.

## Objective Achieved

Implemented core MOR estimation capability in estimate_cpue() enabling incomplete trip CPUE analysis. MOR provides the statistically appropriate estimator for incomplete trips (interview during trip) by computing the mean of individual catch/effort ratios rather than the ratio of totals. This complements the existing ratio-of-means estimator for complete trips.

## Implementation Summary

### Task 1: Add MOR Estimator Tests (RED Phase)
**Commit:** `8432f59`

Added 11 comprehensive test cases for MOR estimator functionality:

1. **Basic Functionality Tests (4 tests):**
   - MOR uses incomplete trips only (filters from 40 total to 25 incomplete)
   - MOR produces valid estimates with SE and CI
   - MOR supports all variance methods (taylor, bootstrap, jackknife)
   - MOR supports grouped estimation

2. **Validation Tests (6 tests):**
   - Error when trip_status field missing
   - Error when no incomplete trips available
   - Error when MOR used with complete-only trips
   - Sample size validation: error when n<10
   - Sample size validation: warning when 10≤n<30
   - No warning when n≥30

3. **Reference Test (1 test):**
   - MOR matches manual survey::svymean calculation (tolerance 1e-10)

Created test helpers:
- Extended `make_small_cpue_design()` to support n_incomplete parameter
- Added `make_mor_design()` for specific complete/incomplete trip mixes
- Added `make_mor_grouped_design()` for grouped estimation tests

All MOR tests initially failed (RED state confirmed) with "unused argument (estimator = 'mor')". All 73 existing CPUE tests passed (no regressions).

### Task 2: Implement MOR Estimator (GREEN Phase)
**Commit:** `9c5fea4`

**Core Implementation:**

1. **estimate_cpue() function:**
   - Added `estimator` parameter with options "ratio-of-means" (default) and "mor"
   - Added estimator validation with clear error messages
   - If MOR requested: validate availability → filter to incomplete trips → rebuild survey design
   - Pass estimator to internal functions

2. **validate_mor_availability() function (R/survey-bridge.R):**
   - Check trip_status_col exists on design
   - Check trip_status column exists in data
   - Count incomplete trips
   - Error if no incomplete trips available (clear message with counts)

3. **estimate_cpue_total() function:**
   - Accept estimator parameter
   - If MOR: compute individual ratios → rebuild survey design with ratio column → call svymean
   - If ratio-of-means: use existing svyratio approach
   - Set method field: "mean-of-ratios-cpue" vs "ratio-of-means-cpue"

4. **estimate_cpue_grouped() function:**
   - Accept estimator parameter
   - Add ratio column if MOR requested
   - Rebuild survey design with ratio column for MOR (handles different column naming)
   - If MOR: use svyby + svymean on ratio (column names: cpue_ratio, se, ci_l, ci_u)
   - If ratio-of-means: use svyby + svyratio (column names: catch/effort, se.*, ci_l, ci_u)
   - Set method field appropriately

**Documentation:**
- Updated @param section with estimator parameter description
- Expanded @details with Ratio-of-Means vs Mean-of-Ratios sections
- Updated @return to mention both method types
- Added MOR example to @examples section

**Testing Results:**
- All 11 new MOR tests pass (GREEN state)
- All 702 existing tests pass (no regressions)
- Total: 713 tests, 0 failures

**Quality Checks:**
- R CMD check: 0 errors, 0 warnings, 1 note (.serena directory)
- lintr: 0 issues
- Fixed pre-existing line length issues in survey-bridge.R

## Deviations from Plan

None - plan executed exactly as written.

## Key Technical Decisions

**MOR uses svymean, not svyratio:**
The plan correctly specified using survey::svymean() on individual catch/effort ratios. This is fundamentally different from ratio-of-means which uses svyratio(). The implementation correctly creates an individual cpue_ratio column and applies svymean to it.

**Filter-then-recreate pattern:**
When MOR is requested, the implementation filters interviews to incomplete trips only, then rebuilds the survey design object. This ensures sample size validation and variance estimation use only incomplete trips, which is statistically correct.

**Grouped estimation column naming:**
Discovered that svymean returns simpler column names (cpue_ratio, se, ci_l, ci_u) compared to svyratio (catch/effort, se.*, ci_l, ci_u). Implementation handles both patterns correctly in estimate_cpue_grouped().

**Survey design rebuild for zero-effort filtering:**
Extended the existing zero-effort filtering logic to also rebuild survey design when MOR is used (even without zero-effort interviews) to ensure the cpue_ratio column is available in the survey design object.

## Dependencies & Integration

**Requires:**
- Phase 13-01: trip_status infrastructure (trip_status_col, "incomplete"/"complete" values)
- Phase 09-01: estimate_cpue baseline with ratio-of-means estimator

**Provides:**
- `estimator` parameter API for choosing estimation method
- `validate_mor_availability()` for ensuring MOR prerequisites
- Foundation for Phase 16 (trip truncation), Phase 17 (complete trip defaults), Phase 19 (validation framework)

**Affects:**
- estimate_cpue() API: new parameter (backward compatible - defaults to existing behavior)
- creel_estimates objects: method field can now be "mean-of-ratios-cpue"

## Testing & Validation

**Test Coverage:**
- 11 new tests specifically for MOR functionality
- All tests pass, including reference test proving numeric correctness
- Existing 702 tests still pass (100% backward compatibility)

**Reference Test Result:**
MOR estimates match manual survey::svymean calculation to tolerance 1e-10, proving implementation correctness.

**Sample Size Validation:**
MOR correctly applies the same sample size thresholds as ratio-of-means:
- Error if n<10 (tested with 8 incomplete trips)
- Warning if 10≤n<30 (tested with 15 incomplete trips)
- No warning if n≥30 (tested with 35 incomplete trips)

**Variance Methods:**
All three variance methods work correctly with MOR:
- Taylor (default): fastest, appropriate for smooth statistics
- Bootstrap: verified with seed for reproducibility
- Jackknife: alternative resampling method

## Future Considerations

**Phase 16: Trip Truncation**
Will add truncation thresholds (e.g., 20-30 min) to improve MOR estimates by excluding very short incomplete trips that may have unstable catch rates.

**Phase 17: Complete Trip Defaults**
Will make complete trips the default behavior, requiring explicit opt-in for incomplete trip estimation. This follows Colorado C-SAP best practices.

**Phase 19: Validation Framework**
Will add validate_incomplete_trips() function to check for length-of-stay bias and nonstationary catch rates before accepting incomplete trip estimates.

**Diagnostic Mode:**
Future phases may add diagnostic warnings or special S3 class for MOR results to emphasize their research/diagnostic nature vs production use.

## Self-Check

**Files created:**
- [✓] `.planning/phases/15-mean-of-ratios-estimator-core/15-01-SUMMARY.md` (this file)

**Key files modified:**
- [✓] `R/creel-estimates.R` (estimate_cpue, estimate_cpue_total, estimate_cpue_grouped)
- [✓] `R/survey-bridge.R` (validate_mor_availability)
- [✓] `tests/testthat/test-estimate-cpue.R` (11 new tests)
- [✓] `man/estimate_cpue.Rd` (documentation updated)

**Commits exist:**
- [✓] `8432f59`: test(15-01): add failing tests for MOR estimator
- [✓] `9c5fea4`: feat(15-01): implement MOR estimator for incomplete trips

**Test results verified:**
- [✓] All 713 tests pass
- [✓] R CMD check: 0 errors, 0 warnings
- [✓] lintr: 0 issues

## Self-Check: PASSED

All files created, commits exist, tests pass, documentation complete.
