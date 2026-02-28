---
phase: 09-cpue-estimation
plan: 01
subsystem: estimation
tags: [cpue, ratio-estimation, survey-bridge, tdd, core-feature]
dependencies:
  requires: [04-01, 06-01, 08-01]
  provides: [estimate_cpue]
  affects: []
tech-stack:
  added: []
  patterns: [ratio-of-means, sample-size-validation]
key-files:
  created:
    - R/creel-estimates.R::estimate_cpue
    - R/creel-estimates.R::estimate_cpue_total
    - R/creel-estimates.R::estimate_cpue_grouped
    - R/survey-bridge.R::validate_cpue_sample_size
    - man/estimate_cpue.Rd
    - tests/testthat/test-estimate-cpue.R
  modified:
    - NAMESPACE (added estimate_cpue export)
decisions:
  - decision: Use survey::svyratio() for ratio-of-means estimation
    rationale: Correct variance accounting for catch/effort correlation, proven approach in survey statistics
    alternatives: Manual ratio calculation would underestimate variance
  - decision: Sample size thresholds n<10 error, n<30 warning
    rationale: Follow survey statistics best practices for ratio estimator stability
    alternatives: No validation would allow unstable estimates with small samples
  - decision: Mirror estimate_effort() pattern exactly
    rationale: Consistency in user interface, code structure, and variance method routing
    alternatives: Different pattern would confuse users and increase maintenance burden
metrics:
  duration_minutes: 16
  tasks_completed: 2
  files_created: 6
  files_modified: 2
  tests_added: 24
  commits: 2
  completed_date: 2026-02-10
---

# Phase 09 Plan 01: Ratio-of-Means CPUE Estimation Summary

**One-liner:** Ratio-of-means CPUE estimation via survey::svyratio() with sample size validation and reference tests

## What Was Built

Implemented `estimate_cpue()` function providing ratio-of-means catch per unit effort estimation from interview data, with sample size validation, grouped estimation support, and reference tests proving correctness against manual survey::svyratio() calculations.

### Core Components

1. **estimate_cpue()** - Exported main function mirroring estimate_effort() pattern
   - Takes creel_design with interviews attached
   - Supports ungrouped and grouped (by parameter) estimation
   - Variance method routing (taylor/bootstrap/jackknife) via get_variance_design()
   - Sample size validation before estimation
   - Returns creel_estimates with method = "ratio-of-means-cpue"

2. **estimate_cpue_total()** - Internal ungrouped estimation
   - Uses survey::svyratio(~catch_col, ~effort_col, design)
   - Extracts point estimate, SE, CI from svyratio result
   - Builds creel_estimates tibble with estimate, se, ci_lower, ci_upper, n

3. **estimate_cpue_grouped()** - Internal grouped estimation
   - Uses survey::svyby() with FUN=survey::svyratio
   - Handles svyratio column naming ("catch_col/effort_col", "se.catch_col/effort_col")
   - Merges per-group sample sizes
   - Returns creel_estimates with by_vars set

4. **validate_cpue_sample_size()** - Sample size validation
   - Ungrouped: error if n<10, warn if 10<=n<30
   - Grouped: error if any group n<10, warn if any group 10<=n<30
   - Uses cli formatting matching existing Tier 2 patterns

### Test Coverage

24 tests across 6 categories:
- **Basic behavior (6):** Class, columns, method, variance_method, conf_level, positive estimate
- **Input validation (4):** Non-creel-design error, no interview_survey error, invalid variance error, missing catch/effort_col error
- **Sample size validation (4):** n<10 error, n<30 warning, n>=30 no warning, grouped n<10 error
- **Grouped estimation (4):** by_vars set, day_type column, one row per group, n column per-group
- **Reference tests (3):** Ungrouped matches manual svyratio, grouped matches manual svyby+svyratio, SE^2 matches vcov
- **Custom confidence (1):** 0.90 produces narrower CI than 0.95

All reference tests use tolerance 1e-10 for numeric equality with manual survey::svyratio() calculations.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed test helper naming inconsistency**
- **Found during:** Task 2 GREEN phase test run
- **Issue:** Test file called `make_test_design_with_interviews()` but helper function was named `make_cpue_design()`
- **Fix:** Updated all test references to use correct `make_cpue_design()` function name
- **Files modified:** tests/testthat/test-estimate-cpue.R
- **Commit:** Part of 64ad065 (included in main GREEN commit)
- **Rationale:** Test bug from Task 1 RED phase - critical to fix for tests to run

**2. [Rule 1 - Bug] Fixed svyby SE column name extraction**
- **Found during:** Task 2 GREEN phase test run
- **Issue:** survey::svyby() with svyratio returns SE column named "se.catch_col/effort_col" not "se"
- **Fix:** Changed SE extraction from `svy_result[["se"]]` to `svy_result[[paste0("se.", ratio_col)]]`
- **Files modified:** R/creel-estimates.R (estimate_cpue_grouped function)
- **Commit:** Part of 64ad065
- **Rationale:** Survey package API detail discovered during implementation - required for grouped estimation to work

## Implementation Notes

### Key Patterns

1. **Ratio column naming:** survey::svyratio() creates columns named "numerator/denominator" for the ratio and "se.numerator/denominator" for the SE. This differs from svytotal() which uses the variable name directly.

2. **Sample size validation before estimation:** validate_cpue_sample_size() is called before calling estimate_cpue_total() or estimate_cpue_grouped() to ensure stable ratio estimation.

3. **Method field distinguishes estimators:** method = "ratio-of-means-cpue" vs "total" allows users and downstream functions to distinguish CPUE from effort estimation.

4. **Variance method routing:** Reuses get_variance_design() from Phase 06, supporting taylor/bootstrap/jackknife without code duplication.

### survey Package Integration

- **svyratio() for ungrouped:** `survey::svyratio(~catch, ~effort, design)` returns svyratio object with coef(), SE(), vcov(), confint() methods
- **svyby() for grouped:** `survey::svyby(~catch, ~day_type, denominator=~effort, FUN=svyratio, vartype=c("se", "ci"))` returns data frame with group columns + ratio + se + ci_l + ci_u
- **Warnings suppressed:** survey package issues "No weights or probabilities supplied" warnings which are expected for our design - suppressWarnings() used strategically

## Testing Results

- **estimate_cpue tests:** 24/24 PASS (0 failures, 24 warnings from survey package expected)
- **Full test suite:** 365/365 PASS (0 failures, 150 warnings)
- **R CMD check:** 0 errors, 0 warnings, 2 NOTEs (hidden files, timestamp verification - both expected)
- **Lintr:** 0 lints

### Reference Test Validation

Reference tests confirm numeric equality (tolerance 1e-10) with manual survey::svyratio() calculations for:
1. Ungrouped estimate, SE, CI_lower, CI_upper
2. Grouped estimates and SEs for each day_type level
3. SE^2 equals variance from vcov()

This proves estimate_cpue() produces identical results to direct survey package usage.

## Self-Check: PASSED

### Files Created
- [✓] R/creel-estimates.R contains estimate_cpue() at line 266
- [✓] R/creel-estimates.R contains estimate_cpue_total() at line 421
- [✓] R/creel-estimates.R contains estimate_cpue_grouped() at line 476
- [✓] R/survey-bridge.R contains validate_cpue_sample_size() at line 574
- [✓] man/estimate_cpue.Rd exists
- [✓] tests/testthat/test-estimate-cpue.R exists

### Commits Verified
- [✓] b631c69 test(09-01): add failing tests for estimate_cpue()
- [✓] 64ad065 feat(09-01): implement estimate_cpue() with ratio-of-means estimation

### NAMESPACE Updated
- [✓] estimate_cpue listed in NAMESPACE exports

All claims verified.

## Next Steps

**Phase 09 Plan 02:** CPUE variance method testing and bootstrap validation (if planned)

**Or Phase 10:** Harvest estimation (if CPUE is sufficient for v0.2.0)

**Ready for:** Users can now estimate CPUE from interview data with `estimate_cpue(design)` or `estimate_cpue(design, by = stratum)` using the same interface as estimate_effort().
