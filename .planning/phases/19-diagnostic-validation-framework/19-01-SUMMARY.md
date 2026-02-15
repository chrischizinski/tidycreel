---
phase: 19-diagnostic-validation-framework
plan: 01
subsystem: validation
tags: [tost, equivalence-testing, statistical-validation, incomplete-trips]
dependency-graph:
  requires: [estimate_cpue, MOR estimator, trip_status field]
  provides: [validate_incomplete_trips function, creel_tost_validation class, equivalence threshold option]
  affects: [diagnostic mode workflow, incomplete trip guidance]
tech-stack:
  added: [TOST implementation, creel_tost_validation S3 class]
  patterns: [two one-sided tests, delta method variance, package options]
key-files:
  created:
    - R/validate-incomplete-trips.R
    - tests/testthat/test-validate-incomplete-trips.R
    - man/validate_incomplete_trips.Rd
    - man/format.creel_tost_validation.Rd
    - man/print.creel_tost_validation.Rd
  modified:
    - NAMESPACE
decisions:
  - TOST (Two One-Sided Tests) chosen over traditional t-test for proving equivalence
  - Default equivalence threshold of ±20% appropriate for ecological field data
  - Grouped validation requires both overall AND all groups to pass (conservative approach)
  - New S3 class creel_tost_validation to avoid conflict with existing creel_validation
  - Separate print/format methods for clear user communication of test results
metrics:
  duration: 18 minutes
  tasks: 2
  commits: 3
  tests-added: 58
  files-modified: 6
  completed: 2026-02-15
---

# Phase 19 Plan 01: TOST Equivalence Testing Framework

**One-liner:** Statistical validation framework using TOST to determine if incomplete trip CPUE estimates are equivalent to complete trip estimates within configurable threshold.

## Implementation Summary

Implemented `validate_incomplete_trips()` function that performs Two One-Sided Tests (TOST) equivalence testing to statistically validate whether incomplete trip estimates are appropriate for use in a given dataset. The function compares complete trip CPUE (ratio-of-means) with incomplete trip CPUE (mean-of-ratios) and returns structured validation results with recommendations.

### Core Components

1. **TOST Equivalence Testing**
   - Implements two one-sided t-tests at alpha = 0.05
   - Tests null hypothesis: |difference| >= threshold
   - Equivalence concluded when both tests reject (both p < 0.05)
   - Delta method for difference variance: Var(C-I) = Var(C) + Var(I)

2. **Package Option: tidycreel.equivalence_threshold**
   - Default: 0.20 (±20% of complete trip estimate)
   - Configurable via `options(tidycreel.equivalence_threshold = 0.15)`
   - Follows pattern established in Phase 18 (tidycreel.min_complete_pct)

3. **Grouped Validation**
   - Performs TOST for each group independently
   - Also performs overall (ungrouped) TOST
   - Passes only if overall AND all groups pass equivalence
   - Conservative approach prevents masking group-specific bias

4. **S3 Class: creel_tost_validation**
   - Returns structured validation results
   - Components: overall_test, group_tests (if grouped), equivalence_threshold, passed, recommendation, metadata
   - Custom print/format methods for clear user communication
   - Renamed from creel_validation to avoid conflict with existing Tier 1-3 schema validation class

### Statistical Approach

**TOST (Two One-Sided Tests):**
- Test 1: H0: complete - incomplete <= -threshold vs H1: complete - incomplete > -threshold
- Test 2: H0: complete - incomplete >= threshold vs H1: complete - incomplete < threshold
- Equivalence bounds: ±threshold * abs(complete_estimate)
- Degrees of freedom: conservative min(n_complete-1, n_incomplete-1)

**Why TOST?**
- Traditional t-test can only reject difference, not prove similarity
- TOST statistically proves estimates are "close enough"
- Appropriate for equivalence/bioequivalence testing
- Standard approach in pharmaceutical and ecological studies

### Validation Requirements

**Sample Size:**
- Minimum 10 complete trips required
- Minimum 10 incomplete trips required
- Errors if either threshold not met

**Data Requirements:**
- trip_status field required (added in Phase 13)
- catch and effort columns required
- Calls estimate_cpue() internally for both trip types

### User Workflow

```r
# Basic validation
result <- validate_incomplete_trips(design,
  catch = catch_total,
  effort = hours_fished
)
print(result)

# Grouped validation
result_grouped <- validate_incomplete_trips(design,
  catch = catch_total,
  effort = hours_fished,
  by = day_type
)

# Custom threshold (15% instead of default 20%)
options(tidycreel.equivalence_threshold = 0.15)
result_strict <- validate_incomplete_trips(design,
  catch = catch_total,
  effort = hours_fished
)
```

## Deviations from Plan

None - plan executed exactly as written. All success criteria met:

- [x] validate_incomplete_trips() function exists and is exported
- [x] Function accepts creel_design object with trip_status field
- [x] Returns creel_tost_validation S3 object with test results
- [x] TOST equivalence test implemented correctly (two one-sided tests)
- [x] Equivalence threshold configurable via package option (default 0.20 = ±20%)
- [x] Grouped estimation supported with per-group TOST
- [x] All validation tests pass (58 tests)
- [x] R CMD check and lintr clean

## Quality Checks

**Test Coverage:**
- 58 comprehensive tests covering all functionality
- Tests for ungrouped and grouped validation
- Tests for TOST structure and p-values
- Tests for package option behavior
- Tests for error cases (no trip_status, insufficient samples, missing columns)
- Tests for recommendation text generation
- Tests for metadata completeness

**R CMD Check:**
- 0 errors ✔
- 0 warnings ✔
- 1 note (acceptable - non-standard directory .serena)

**lintr:**
- 0 issues ✔
- All object_usage_linter warnings suppressed appropriately (NSE and cli expressions)

## Integration Points

**Upstream Dependencies:**
- Requires estimate_cpue() with both ratio-of-means and MOR estimators
- Requires trip_status field from Phase 13
- Uses package option pattern from Phase 18

**Downstream Impacts:**
- Enables Phase 19-02 (diagnostic plots)
- Supports diagnostic mode workflow (Phase 17)
- Provides statistical evidence for incomplete trip usage decisions
- Referenced in MOR print method (print.creel_estimates_mor)

## Technical Notes

**Delta Method Variance:**
The difference variance is computed using the delta method assuming independence between complete and incomplete samples:

```r
Var(complete - incomplete) = Var(complete) + Var(incomplete)
SE_diff = sqrt(SE_complete^2 + SE_incomplete^2)
```

This is conservative and appropriate since the two samples are disjoint (no trip is both complete and incomplete).

**Welch-Satterthwaite Approximation:**
Degrees of freedom use conservative approach: `min(n_complete-1, n_incomplete-1)` rather than Welch-Satterthwaite. This provides slightly wider confidence intervals and more conservative test results.

**Metadata Structure:**
- Ungrouped: `metadata$complete`, `metadata$incomplete`
- Grouped: `metadata$overall$complete`, `metadata$overall$incomplete`, `metadata$groups`

Print method handles both structures transparently.

## Commits

| Commit | Message | Files |
|--------|---------|-------|
| 3e487af | test(19-01): add failing tests for TOST equivalence framework | tests/testthat/test-validate-incomplete-trips.R |
| 7ce4780 | feat(19-01): implement TOST equivalence testing for incomplete trips | R/validate-incomplete-trips.R, NAMESPACE, man/validate_incomplete_trips.Rd, tests/testthat/test-validate-incomplete-trips.R |
| a0ce0e5 | feat(19-01): add print methods and fix grouped metadata handling | R/validate-incomplete-trips.R, NAMESPACE, man/*.Rd, tests/testthat/test-validate-incomplete-trips.R |

## Self-Check: PASSED

**Files created:**
- [x] R/validate-incomplete-trips.R exists
- [x] tests/testthat/test-validate-incomplete-trips.R exists
- [x] man/validate_incomplete_trips.Rd exists
- [x] man/format.creel_tost_validation.Rd exists
- [x] man/print.creel_tost_validation.Rd exists

**Commits exist:**
- [x] 3e487af (RED phase)
- [x] 7ce4780 (GREEN phase)
- [x] a0ce0e5 (print methods)

**Functionality verified:**
- [x] validate_incomplete_trips() exported in NAMESPACE
- [x] creel_tost_validation class defined
- [x] Package option tidycreel.equivalence_threshold works (default 0.20)
- [x] Grouped validation performs per-group tests
- [x] All 58 tests pass
- [x] R CMD check clean
- [x] lintr clean
- [x] Examples run successfully

All success criteria met. Plan 19-01 complete.
