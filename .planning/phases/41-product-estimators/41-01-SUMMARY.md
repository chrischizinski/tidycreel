---
phase: 41-product-estimators
plan: "01"
subsystem: tests
tags: [tdd, section-dispatch, total-catch, total-harvest, total-release, PROD-01, PROD-02]
dependency_graph:
  requires: [40-02-SUMMARY.md]
  provides: [PROD-01 RED stubs, PROD-02 RED stubs, test-estimate-total-release.R]
  affects: [test-estimate-total-catch.R, test-estimate-total-harvest.R, test-estimate-total-release.R]
tech_stack:
  added: []
  patterns: [TDD RED, fixture duplication across test files, withCallingHandlers for cli_warn capture]
key_files:
  created:
    - tests/testthat/test-estimate-total-release.R
  modified:
    - tests/testthat/test-estimate-total-catch.R
    - tests/testthat/test-estimate-total-harvest.R
decisions:
  - make_3section_total_catch_design() name used in all three files — explicit about product-estimator context, identical data shape to Phase 40 make_3section_design_with_interviews()
  - test-estimate-total-release.R fixture adds interview_id column and catch data via add_catch() — required because estimate_total_release() mandates add_catch() with released records (unlike harvest which uses interview-level catch_kept)
  - harvest fixture includes catch_kept column — required for estimate_total_harvest() to dispatch correctly
  - All line length violations (>120 chars) in test description strings resolved — shortened without changing semantic meaning
metrics:
  duration: "11 minutes"
  completed: "2026-03-14"
  tasks_completed: 1
  files_changed: 3
---

# Phase 41 Plan 01: Section TDD Fixtures and Stubs Summary

**One-liner:** TDD RED phase — three section test fixtures (make_3section_total_catch_design) and 19 PROD-01/PROD-02 failing stubs for product estimator section dispatch, plus new test-estimate-total-release.R file.

## What Was Done

Added the Wave 0 TDD stubs for Phase 41 product estimator section dispatch. Three test files now contain the `make_3section_total_catch_design()` fixture (3-section creel design with North/Central/South, 27 interviews, 36-row counts) and RED failing test cases expressing the PROD-01 and PROD-02 behaviors that Plan 02 will implement.

**test-estimate-total-release.R** was created from scratch, modeled on `test-estimate-total-harvest.R` structure with release-specific function calls and an extended fixture that includes `interview_id` and `add_catch()` data with `catch_type = "released"` rows — required because `estimate_total_release()` mandates catch data via `add_catch()`.

## Tasks Completed

| Task | Description | Commit | Files |
|------|-------------|--------|-------|
| 1    | TDD RED: section fixtures + stubs for PROD-01/02 | ff74561 | test-estimate-total-catch.R, test-estimate-total-harvest.R, test-estimate-total-release.R (new) |

## Test Results

- **Pre-existing tests:** 175 PASS (GREEN) — all pre-Phase-41 tests unaffected
- **New section stubs:** 19 FAIL (RED) — fail with "unused argument (aggregate_sections)" confirming dispatch not yet implemented
- **FAIL reasons:** All failures are "unused argument" errors — correct RED behavior (function doesn't yet accept section parameters)

## PROD-01 Stubs (per-section rows)

- estimate_total_catch on 3-section design returns a tibble with a "section" column
- estimate_total_catch on 3-section design returns exactly 3 rows when aggregate_sections = FALSE
- missing section inserts NA row with data_available = FALSE for estimate_total_catch
- estimate_total_harvest on 3-section design returns a tibble with a "section" column
- estimate_total_harvest returns 3 section rows when aggregate_sections = FALSE
- estimate_total_release on 3-section design returns a tibble with a "section" column
- estimate_total_release returns 3 section rows when aggregate_sections = FALSE

## PROD-02 Stubs (lake total row)

- aggregate_sections=TRUE appends a .lake_total row (4 rows total) — catch, harvest, release
- .lake_total$estimate equals sum of per-section estimates — catch, harvest, release
- .lake_total$se equals sqrt(sum(se_i^2)) — catch, harvest, release
- prop_of_lake_total for present sections sums to 1.0 — catch, harvest, release

## Regression Guards (already GREEN)

- Non-sectioned designs return identical results to pre-Phase-41 — catch, harvest, release (3 stubs)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Fixed line_length_linter violations in new test descriptions**
- **Found during:** Pre-commit hook lintr check after first commit attempt
- **Issue:** Five test description strings in the new section stubs exceeded 120-char line limit
- **Fix:** Shortened test descriptions while preserving semantic meaning (e.g., "returns exactly 3 rows when aggregate_sections = FALSE" → "returns 3 section rows (aggregate_sections=FALSE)")
- **Files modified:** test-estimate-total-catch.R, test-estimate-total-harvest.R, test-estimate-total-release.R
- **Commit:** ff74561 (included in same commit after fixing)

**2. [Rule 2 - Missing Critical] Added # nolint: object_usage_linter to example_catch args in release fixtures**
- **Found during:** Lintr run on test-estimate-total-release.R
- **Issue:** example_catch passed directly to add_catch() without nolint comment, triggering object_usage_linter
- **Fix:** Added # nolint: object_usage_linter inline per project convention (same pattern as test-add-catch.R)
- **Files modified:** test-estimate-total-release.R

## Self-Check

### Files Created/Modified

- [x] FOUND: tests/testthat/test-estimate-total-catch.R (modified)
- [x] FOUND: tests/testthat/test-estimate-total-harvest.R (modified)
- [x] FOUND: tests/testthat/test-estimate-total-release.R (created)
- [x] FOUND: .planning/phases/41-product-estimators/41-01-SUMMARY.md (this file)

### Commits

- [x] FOUND: ff74561 — test(41-01): add section fixtures and failing stubs for PROD-01/02

## Self-Check: PASSED
