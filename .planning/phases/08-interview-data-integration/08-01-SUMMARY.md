---
phase: 08-interview-data-integration
plan: 01
subsystem: interview-data
tags: [data-integration, validation, survey-design, tidy-selectors]
dependency-graph:
  requires:
    - add_counts() pattern (Phase 2)
    - validate_count_schema() pattern (Phase 2)
    - construct_survey_design() pattern (Phase 2)
    - creel_validation infrastructure (Phase 2)
  provides:
    - add_interviews() exported function
    - validate_interview_schema() internal function
    - validate_interviews_tier1() internal function
    - construct_interview_survey() internal function
    - Interview data attachment API
  affects:
    - format.creel_design() output
tech-stack:
  added:
    - dplyr (for left_join calendar linkage)
  patterns:
    - Tidy selector API (rlang::enquo, resolve_single_col)
    - Progressive validation (Tier 1)
    - Eager survey construction (interview_survey)
    - Immutable design pattern
key-files:
  created:
    - man/add_interviews.Rd (exported function documentation)
    - tests/testthat/test-add-interviews.R (28 tests, 100% pass rate)
  modified:
    - R/creel-design.R (add_interviews function, format.creel_design update)
    - R/validate-schemas.R (validate_interview_schema)
    - R/survey-bridge.R (validate_interviews_tier1, construct_interview_survey)
    - DESCRIPTION (added dplyr and stats to Imports)
    - NAMESPACE (exported add_interviews)
decisions:
  - "Interview survey uses ids=~1 (terminal units) not ids=~psu (day-PSU) because interviews are individual observations not clustered by day"
  - "Harvest column is optional - function works without it (harvest=NULL default)"
  - "Calendar linking via dplyr::left_join with date matching - strata inherited automatically"
  - "Validation consistency check: harvest <= catch when both provided"
metrics:
  duration: 7 min
  tasks: 2
  tests: 28
  coverage: 83.41%
  commits: 2
  completed: 2026-02-10
---

# Phase 08 Plan 01: Interview Data Integration - Foundation

**Add interview data attachment with tidy selector API mirroring add_counts() pattern exactly**

## One-liner

Implemented add_interviews() function with tidy selectors for catch/effort/harvest, Tier 1 validation, and eager interview survey construction using ids=~1 (terminal units)

## What Was Built

Implemented `add_interviews()` function with complete validation infrastructure and interview survey design construction, establishing the data integration foundation for catch rate and harvest estimation in Phases 9-11. The function mirrors the proven `add_counts()` pattern exactly, providing users with a consistent tidy selector API for attaching interview data (catch, effort, and optional harvest per trip) to existing creel_design objects.

### Core Components

**1. add_interviews() Function (R/creel-design.R)**
- Full roxygen2 documentation with examples
- Tidy selector API: `catch`, `effort`, `harvest` (optional)
- Parameters: `date_col` (defaults to design$date_col), `interview_type` ("access" or "roving"), `allow_invalid` (FALSE)
- Validates design is creel_design, checks interviews not already attached
- Resolves tidy selectors using resolve_single_col() helper
- Calls validate_interview_schema() for schema validation
- Calls validate_interviews_tier1() for structural validation
- Joins interviews with calendar via dplyr::left_join (strata inherited)
- Constructs interview survey eagerly via construct_interview_survey()
- Stores validation results in design$validation
- Returns new creel_design object (immutable pattern)

**2. validate_interview_schema() Function (R/validate-schemas.R)**
- Internal function mirroring validate_count_schema() exactly
- Uses checkmate::makeAssertCollection() for validation
- Checks: data.frame with min.rows=1, at least one Date column, at least one numeric column
- Error message format: "Interview data validation failed:" with x bullets and i hint
- Returns invisible(data) on success
- @keywords internal @noRd

**3. validate_interviews_tier1() Function (R/survey-bridge.R)**
- Internal function mirroring validate_counts_tier1() pattern
- Parameters: interviews, design, catch_col, effort_col, harvest_col, date_col, allow_invalid
- Checks:
  - date_col exists in interviews
  - catch_col exists and is numeric
  - effort_col exists and is numeric
  - harvest_col exists and is numeric (only if not NULL)
  - No NA values in date_col
  - Interview dates exist in design calendar (Tier 1 error if missing)
  - harvest <= catch for all non-NA rows (Tier 1 error if violated)
- Returns new_creel_validation(results, tier=1L, context="add_interviews validation")
- If allow_invalid=FALSE, aborts with cli::cli_abort; if TRUE, warns and continues

**4. construct_interview_survey() Function (R/survey-bridge.R)**
- Internal function similar to construct_survey_design() but with key difference
- Uses `ids = ~1` (terminal sampling units) instead of `ids = ~psu_col` (day-PSU)
- Interviews are individual observations, not clustered by day
- Single stratum: uses directly; multiple strata: uses interaction()
- strata_formula via stats::reformulate(".strata")
- Same tryCatch error wrapping with domain-specific messages
- Handles "Stratum has only one PSU" error (less likely for interviews)
- Handles variable not found and generic survey errors

**5. format.creel_design() Update (R/creel-design.R)**
- Added interview display block after counts block
- Shows: number of interviews, interview type, catch column, effort column, harvest column (if present), survey class
- Uses cli formatting with nolint comments on glue variables

### Test Coverage

**28 tests in test-add-interviews.R (100% pass rate):**
- **12 happy path tests**: S3 class return, data attachment, eager survey construction, immutability, field retention, catch/effort/harvest column storage, interview_type default, parallel streams (counts + interviews), calendar join with strata inheritance
- **10 validation error tests**: interviews already attached, not creel_design class, no Date column, no numeric column, date_col not found, catch column not found, effort column not found, date NA values, dates not in calendar, harvest > catch
- **3 survey construction tests**: survey.design2 class, ids=~1 formula, strata from calendar join
- **3 validation storage tests**: creel_validation object, passed=TRUE flag, tier=1L

**Package-level metrics:**
- Overall coverage: 83.41% (target: 85%)
- R CMD check: 0 errors, 0 warnings, 1 note (.mcp.json)
- lintr: 0 lints

## Deviations from Plan

None - plan executed exactly as written.

## Auth Gates

None encountered.

## Commits

| Task | Description | Commit | Files |
|------|-------------|--------|-------|
| 1 | Implement add_interviews() core function and validation infrastructure | 315041c | R/creel-design.R, R/validate-schemas.R, R/survey-bridge.R, DESCRIPTION, NAMESPACE, man/add_interviews.Rd |
| 2 | Create comprehensive test suite for add_interviews() | 13fe515 | tests/testthat/test-add-interviews.R |

## Self-Check: PASSED

**Created files verified:**
- [x] R/creel-design.R contains add_interviews() (lines 406-539)
- [x] R/validate-schemas.R contains validate_interview_schema() (lines 91-132)
- [x] R/survey-bridge.R contains validate_interviews_tier1() (lines 465-645)
- [x] R/survey-bridge.R contains construct_interview_survey() (lines 647-710)
- [x] man/add_interviews.Rd exists and is properly formatted
- [x] tests/testthat/test-add-interviews.R exists with 28 tests

**Commits verified:**
- [x] Commit 315041c exists: feat(08-01): implement add_interviews() with validation infrastructure
- [x] Commit 13fe515 exists: test(08-01): add comprehensive test suite for add_interviews()

**Functionality verified:**
- [x] devtools::check() passes (0 errors, 0 warnings)
- [x] devtools::test() passes (28 new tests, 293 total tests, 0 failures)
- [x] lintr::lint_package() returns 0 lints
- [x] add_interviews() exported in NAMESPACE
- [x] Interview survey uses ids=~1 (terminal units)
- [x] Harvest column is optional
- [x] Calendar linking works (strata inherited)

## Success Criteria: MET

- [x] add_interviews() works with tidy selectors for catch, effort, and optional harvest columns
- [x] Validation matches add_counts() error styles exactly
- [x] Interview survey design object constructed eagerly with correct ids=~1
- [x] Interview type stored in design metadata (defaults to "access")
- [x] format.creel_design() shows interview information
- [x] All existing tests still pass (no regression)
- [x] 28 new tests pass for interview functionality

## Technical Notes

**ids=~1 vs ids=~psu Decision:**
The key architectural decision was using `ids=~1` for interview surveys instead of `ids=~psu_col` used for count surveys. This correctly represents that interviews are individual terminal sampling units (each interview is independent), whereas counts are clustered by day (multiple counts per day are dependent). This affects variance estimation in later phases.

**Optional Harvest Column:**
The harvest parameter defaults to NULL and the function fully supports interviews without harvest data. This is important for surveys focused only on catch rates, or for multi-species scenarios where harvest regulations vary by species.

**Calendar Integration:**
Interview data is automatically joined with the design calendar via date matching using dplyr::left_join(). This ensures that calendar strata (e.g., weekday/weekend) are inherited by interview observations, enabling stratified catch rate estimation.

**Validation Consistency:**
When harvest column is provided, the function validates that harvest <= catch for all non-NA rows. This is a domain-specific business rule that catches data entry errors early.

## Next Steps

Phase 08 Plan 02 will implement Tier 2 data quality checks for interview data (sparse strata, zero/negative values) and interview-specific validation warnings, completing the interview data integration foundation before moving to catch rate estimation in Phase 09.
