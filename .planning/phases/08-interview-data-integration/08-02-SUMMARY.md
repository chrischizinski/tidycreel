---
phase: 08-interview-data-integration
plan: 02
subsystem: interview-data-integration
tags: [tier2-validation, data-quality, example-data, interview-warnings]
dependency_graph:
  requires: ["08-01"]
  provides: ["tier2-interview-warnings", "example-interview-dataset"]
  affects: ["R/survey-bridge.R", "R/creel-design.R", "R/data.R"]
tech_stack:
  added: []
  patterns: ["tier2-validation-pattern", "example-dataset-pattern"]
key_files:
  created:
    - "tests/testthat/test-tier2-interviews.R"
    - "data/example_interviews.rda"
    - "data-raw/create_example_interviews.R"
    - "man/example_interviews.Rd"
  modified:
    - "R/survey-bridge.R"
    - "R/creel-design.R"
    - "R/data.R"
    - "tests/testthat/test-add-interviews.R"
decisions:
  - key: "tier2-warning-triggers"
    summary: "Tier 2 warnings trigger for: short trips (<0.1 hrs), zero/negative catch, negative effort, missing effort (NA), sparse strata (<3 interviews)"
    rationale: "These are data quality issues that should be investigated but don't prevent estimation"
  - key: "example-dataset-design"
    summary: "example_interviews has 22 interviews across 14 calendar days with realistic coverage patterns"
    rationale: "Some days have multiple interviews (realistic for access point surveys), some have none, all values are clean (no Tier 2 warnings)"
  - key: "harvest-optional"
    summary: "example_interviews includes harvest column (catch_kept) to demonstrate optional harvest tracking"
    rationale: "Shows users how to track both total catch and kept fish for harvest rate estimation"
metrics:
  duration_minutes: 6
  tasks_completed: 2
  tests_added: 14
  files_created: 4
  files_modified: 4
  commits: 2
  completed: 2026-02-10T03:55:49Z
---

# Phase 08 Plan 02: Tier 2 Interview Warnings and Example Dataset Summary

**One-liner:** Tier 2 data quality warnings for interview data (short trips, negative values, sparse coverage) and ready-to-use example_interviews dataset demonstrating complete workflow.

## Objective

Complete the interview data integration layer with Tier 2 data quality feedback (warnings for suspicious values) and a ready-to-use example dataset that demonstrates the complete workflow from calendar through interview attachment. This completes all Phase 8 requirements (INTV-01 through INTV-06, QUAL-01, QUAL-03).

## What Was Built

### Task 1: Tier 2 Interview Warnings (Commit 63515ae)

**Implemented `warn_tier2_interview_issues()` function** in R/survey-bridge.R with 6 data quality checks:

1. **Very short trips** (effort < 0.1 hours = 6 minutes)
   - Only checked when effort_col is not NULL
   - Warning: "{n} interview{?s} ha{?s/ve} effort < 0.1 hours (6 minutes)."
   - Hint: "Very short trips may indicate data entry errors."

2. **Zero catch values**
   - Warning: "{n} interview{?s} ha{?s/ve} zero catch."
   - Hint: "Zero catch may be valid (skunked) or indicate missing data."

3. **Negative catch values**
   - Warning: "{n} interview{?s} ha{?s/ve} negative catch values."
   - Alert: "Negative catch indicates data entry errors."
   - Hint: "Review and correct before estimation."

4. **Negative effort values**
   - Only checked when effort_col is not NULL
   - Warning with same pattern as negative catch

5. **Missing effort values (NA)**
   - Only checked when effort_col is not NULL
   - Warning: "{n} interview{?s} ha{?s/ve} missing effort values."
   - Hint: "Missing effort limits CPUE estimation."

6. **Sparse interview coverage** (< 3 interviews per stratum)
   - Creates strata variable same way as warn_tier2_issues (single vs interaction)
   - Provides stratum-specific bullet list
   - Alert: "Sparse strata produce unstable variance estimates."
   - Hint: "Consider combining sparse strata or collecting more data."

**Wired into add_interviews():**
- Function called after interview survey construction, before returning
- Placement ensures survey object exists (needed for strata calculation)
- Warnings are non-blocking (design returned successfully)

**Tests (test-tier2-interviews.R):**
- No warnings for clean data
- Warning for each individual condition (6 tests)
- Multiple warnings issued simultaneously
- Warnings do NOT prevent add_interviews() from succeeding
- Defensive programming: handles effort_col = NULL gracefully

### Task 2: Example Interview Dataset (Commit 953a519)

**Created example_interviews dataset:**
- 22 interviews from June 1-14, 2024 (matching example_calendar dates)
- Realistic coverage: multiple interviews per day, some days have none
- 4 columns: date, hours_fished, catch_total, catch_kept
- All values clean (no Tier 2 warnings triggered)
- Data quality: catch_kept <= catch_total, all effort > 0

**Documentation (R/data.R):**
- Comprehensive roxygen2 documentation
- Format specification with all 4 columns described
- Example usage showing complete workflow:
  - Load example_calendar and example_interviews
  - Create design
  - Add interviews with catch, effort, and harvest
  - Print design
- Cross-references to example_calendar and add_interviews()

**Integration tests (test-add-interviews.R):**
- example_interviews works with example_calendar end-to-end
- Verifies all expected columns present and correct types
- Validates data quality (catch_kept <= catch_total)
- Confirms interview survey constructed successfully

## Verification Results

**R CMD check:** 0 errors, 0 warnings, 1 note (unrelated .mcp.json file)

**Tests:** All 72 tests pass (58 add-interviews + 12 tier2-interviews + 2 integration)

**Lintr:** 0 lints

**Coverage:** Maintained (Tier 2 warnings covered by comprehensive test suite)

**End-to-end workflow verified:**
```r
data(example_calendar)
data(example_interviews)
design <- creel_design(example_calendar, date = date, strata = day_type)
design <- add_interviews(design, example_interviews,
                         catch = catch_total,
                         effort = hours_fished,
                         harvest = catch_kept)
print(design)  # Shows 22 interviews, access type, all fields
```

## Deviations from Plan

None - plan executed exactly as written.

## Technical Notes

**Tier 2 warning design:**
- Follows same pattern as warn_tier2_issues() for count data
- Uses cli::cli_warn() for consistent formatting
- Checks are defensive (only check effort if effort_col exists)
- Sparse strata check reuses same strata construction logic as survey design

**Example dataset design:**
- 22 interviews provide realistic sample size
- Coverage across both weekday (10 days) and weekend (4 days) strata
- Some dates have 0 interviews (realistic - not every survey day has interviews)
- Some dates have 3 interviews (realistic for busy access point days)
- All data clean to avoid confusing users with warnings in examples

**Integration with existing code:**
- warn_tier2_interview_issues() placed after warn_tier2_group_issues() in R/survey-bridge.R
- Function called from add_interviews() after survey construction (line 599)
- example_interviews documented after example_counts in R/data.R

## Phase 8 Requirements Satisfied

This plan completes all Phase 8 requirements:

- **INTV-01:** add_interviews() API ✅ (Plan 01)
- **INTV-02:** Interview data validation (Tier 1) ✅ (Plan 01)
- **INTV-03:** Interview survey construction ✅ (Plan 01)
- **INTV-04:** Calendar integration (strata inheritance) ✅ (Plan 01)
- **INTV-05:** Harvest tracking (optional) ✅ (Plan 01, demonstrated in Plan 02 examples)
- **INTV-06:** Complete trip interviews (access point design) ✅ (Plan 01)
- **QUAL-01:** Tier 2 data quality warnings ✅ (Plan 02 - this plan)
- **QUAL-03:** Example dataset for users ✅ (Plan 02 - this plan)

## Next Steps

Phase 8 is complete. Next phase (09) will focus on variance estimation infrastructure, likely building on the survey objects constructed here.

## Self-Check: PASSED

**Files created exist:**
```
FOUND: tests/testthat/test-tier2-interviews.R
FOUND: data/example_interviews.rda
FOUND: data-raw/create_example_interviews.R
FOUND: man/example_interviews.Rd
```

**Files modified exist:**
```
FOUND: R/survey-bridge.R (warn_tier2_interview_issues function added)
FOUND: R/creel-design.R (function wired into add_interviews)
FOUND: R/data.R (example_interviews documentation added)
FOUND: tests/testthat/test-add-interviews.R (integration tests added)
```

**Commits exist:**
```
FOUND: 63515ae (feat(08-02): implement Tier 2 interview warnings)
FOUND: 953a519 (feat(08-02): create example_interviews dataset)
```

**Tests pass:**
```
✅ All 72 tests pass (0 failures)
✅ R CMD check: 0 errors, 0 warnings
✅ lintr: 0 lints
```

**End-to-end verification:**
```
✅ example_interviews loads successfully
✅ Complete workflow executes without errors
✅ Tier 2 warnings fire for problematic data
✅ Tier 2 warnings do not prevent interview attachment
```
