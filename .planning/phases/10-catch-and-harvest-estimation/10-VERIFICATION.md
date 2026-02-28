---
phase: 10-catch-and-harvest-estimation
verified: 2026-02-10T18:30:00Z
status: passed
score: 4/4 must-haves verified
re_verification: false
---

# Phase 10: Catch and Harvest Estimation Verification Report

**Phase Goal:** Users can estimate species-specific catch and harvest rates using CPUE infrastructure
**Verified:** 2026-02-10T18:30:00Z
**Status:** passed
**Re-verification:** No - initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | User can estimate catch per unit effort for single species fisheries | ✓ VERIFIED | estimate_cpue() exists and is exported (Phase 9), 40 passing tests |
| 2 | User can estimate harvest per unit effort (HPUE) separately from total catch | ✓ VERIFIED | estimate_harvest() exported, uses harvest_col, method="ratio-of-means-hpue", 79 passing tests |
| 3 | System distinguishes between caught (total) and kept (harvest) fish | ✓ VERIFIED | Separate catch_col and harvest_col in design, separate estimators, format displays distinct labels |
| 4 | System validates catch_kept ≤ catch_total consistency | ✓ VERIFIED | validate_interviews_tier1() enforces harvest <= catch (R/survey-bridge.R:785-802) |

**Score:** 4/4 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| R/creel-estimates.R | estimate_harvest() function | ✓ VERIFIED | Lines 516-595: full implementation with validation, routing to total/grouped |
| R/creel-estimates.R | estimate_harvest_total() | ✓ VERIFIED | Lines 943-1036: svyratio with harvest_col, zero-effort filtering, NA handling |
| R/creel-estimates.R | estimate_harvest_grouped() | ✓ VERIFIED | Lines 1042+: svyby+svyratio for grouped estimation |
| R/survey-bridge.R | validate_ratio_sample_size() | ✓ VERIFIED | Line 588: shared validation for CPUE and harvest, type parameter |
| tests/testthat/test-estimate-harvest.R | Comprehensive test suite | ✓ VERIFIED | 621 lines, 79 tests passing, includes reference tests with 1e-10 tolerance |
| man/estimate_harvest.Rd | Generated documentation | ✓ VERIFIED | 107 lines, exported in NAMESPACE |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| R/creel-estimates.R::estimate_harvest | survey::svyratio | harvest_formula + effort_formula | ✓ WIRED | Line 1007: survey::svyratio(harvest_formula, effort_formula, svy_design) |
| R/creel-estimates.R::estimate_harvest | R/survey-bridge.R::validate_ratio_sample_size | type = "harvest" | ✓ WIRED | Lines 577, 592: validate_ratio_sample_size(design, NULL/by_vars, type = "harvest") |
| R/creel-design.R::add_interviews | harvest parameter | harvest_col assignment | ✓ WIRED | Lines 512, 554-557, 589: harvest parameter captured and stored in design$harvest_col |
| R/survey-bridge.R::validate_interviews_tier1 | harvest <= catch check | Tier 1 validation | ✓ WIRED | Lines 785-802: validates harvest_vals <= catch_vals, errors if violated |
| R/creel-estimates.R::format.creel_estimates | "ratio-of-means-hpue" | Switch statement display | ✓ WIRED | Lines 83-86: maps to "Ratio-of-Means HPUE" |

### Requirements Coverage

Phase 10 requirements from ROADMAP.md:
- **HARV-01:** Ratio-of-means HPUE estimation - ✓ SATISFIED (estimate_harvest with svyratio)
- **HARV-02:** Separate harvest from total catch - ✓ SATISFIED (distinct harvest_col and catch_col)
- **HARV-03:** Distinguish caught vs kept - ✓ SATISFIED (terminology and separate columns)
- **HARV-04:** Validate harvest <= catch - ✓ SATISFIED (Tier 1 validation enforces constraint)

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| None found | - | - | - | - |

**Code quality:** Clean implementation. No TODO/FIXME placeholders, no stub functions, proper error handling with informative messages, comprehensive test coverage.

### Human Verification Required

**1. Visual output formatting**

**Test:** Create a creel_design with example data, attach interviews with harvest data, run estimate_harvest(design), and print the result.

**Expected:** Output should display "Ratio-of-Means HPUE" clearly, show estimate with SE and confidence interval, be distinguishable from CPUE output.

**Why human:** Visual formatting and user experience require human judgment. Automated tests verify the string appears but not that the formatting is actually helpful.

**2. Real-world workflow integration**

**Test:** Follow a complete workflow: create design with example_calendar, attach example_interviews with harvest parameter, estimate both CPUE and HPUE, compare results.

**Expected:** HPUE estimate should be less than or equal to CPUE estimate (since harvest is subset of catch). Both should return reasonable values for the example data. Grouped estimation by day_type should work or provide clear error if sample size insufficient.

**Why human:** End-to-end workflow requires checking multiple function interactions and verifying the user experience is smooth. Integration tests verify correctness but not usability.

**3. Error message clarity**

**Test:** Attempt to call estimate_harvest() on a design without harvest data (no harvest parameter in add_interviews). Attempt with zero-effort interviews. Attempt with all NA harvest values.

**Expected:** Each error should clearly explain what's wrong and how to fix it. Zero-effort and NA harvest should produce warnings with counts and proceed with filtered data. All-zero or all-NA should error with clear message.

**Why human:** Error message quality requires human judgment about whether the guidance is actually helpful to users encountering the error.

### Gaps Summary

**No gaps found.** All must-have truths verified, all artifacts exist and are substantive, all key links wired correctly. Tests pass (79/79 for harvest, 475 total package tests). R CMD check clean (0 errors, 0 warnings, 1 expected NOTE for hidden .mcp.json).

---

## Detailed Verification Evidence

### Truth 1: User can estimate CPUE for single species

**Artifact Evidence:**
- estimate_cpue() exists in R/creel-estimates.R (Phase 9)
- Exported in NAMESPACE
- 40 passing tests in test-estimate-cpue.R
- Uses survey::svyratio with catch_col as numerator

**Wiring Evidence:**
- Called with creel_design object created by add_interviews(catch = ..., effort = ...)
- Handles ungrouped and grouped estimation
- Returns creel_estimates with method = "ratio-of-means-cpue"

**Status:** ✓ VERIFIED - CPUE infrastructure from Phase 9 is complete and working

### Truth 2: User can estimate HPUE separately from CPUE

**Artifact Evidence:**
- estimate_harvest() exported function (R/creel-estimates.R:516-595)
  - Same signature as estimate_cpue (by, variance, conf_level parameters)
  - Validates design has harvest_col (lines 551-562)
  - Routes to estimate_harvest_total() or estimate_harvest_grouped()
  - Returns creel_estimates with method = "ratio-of-means-hpue"

- estimate_harvest_total() (R/creel-estimates.R:943-1036)
  - Uses harvest_col instead of catch_col
  - Calls survey::svyratio(~harvest_col, ~effort_col, svy_design)
  - Filters zero-effort interviews with warning
  - Filters NA harvest interviews with warning
  - Rebuilds survey design from filtered data when needed

- estimate_harvest_grouped() (R/creel-estimates.R:1042+)
  - Uses svyby with harvest_col
  - Same zero-effort and NA harvest filtering as ungrouped
  - Returns per-group estimates

**Test Evidence:**
- 79 passing tests in test-estimate-harvest.R:
  - Basic behavior: returns creel_estimates, correct structure, method = "ratio-of-means-hpue"
  - Input validation: errors when harvest_col missing, informative error message
  - Sample size validation: n < 10 errors, n < 30 warns (shared with CPUE)
  - Grouped estimation: works with by = day_type
  - Reference tests: matches manual survey::svyratio within 1e-10 tolerance
  - HPUE vs CPUE: HPUE <= CPUE verified (harvest is subset of catch)
  - Variance methods: bootstrap and jackknife work
  - Integration: works with example_calendar and example_interviews
  - Zero-effort: filters with warning, errors if all zero
  - NA harvest: filters with warning, errors if all NA

**Wiring Evidence:**
```bash
# Function calls svyratio with harvest column
grep -A 5 "survey::svyratio" R/creel-estimates.R | grep -A 2 "estimate_harvest"
# Line 1007: survey::svyratio(harvest_formula, effort_formula, svy_design)

# Function uses shared validation
grep "validate_ratio_sample_size.*harvest" R/creel-estimates.R
# Lines 577, 592: validate_ratio_sample_size(design, NULL/by_vars, type = "harvest")

# harvest_col comes from design object set by add_interviews
grep "design\$harvest_col" R/creel-estimates.R
# Used in estimate_harvest, estimate_harvest_total, estimate_harvest_grouped
```

**Import Evidence:**
- estimate_harvest used in 79 test cases across test-estimate-harvest.R
- Referenced in documentation examples (man/estimate_harvest.Rd)
- Exported in NAMESPACE for user access

**Status:** ✓ VERIFIED - Fully implemented and tested

### Truth 3: System distinguishes caught vs kept fish

**Conceptual Distinction:**
- catch_col: Total fish caught (includes released fish)
- harvest_col: Kept fish only (subset of catch)
- CPUE: Catch per unit effort (estimate_cpue uses catch_col)
- HPUE: Harvest per unit effort (estimate_harvest uses harvest_col)

**Artifact Evidence:**
- Separate columns in creel_design:
  - design$catch_col (set by add_interviews catch parameter)
  - design$harvest_col (set by add_interviews harvest parameter)

- Separate estimator functions:
  - estimate_cpue() uses catch_col
  - estimate_harvest() uses harvest_col

- Distinct method identifiers:
  - CPUE: method = "ratio-of-means-cpue"
  - HPUE: method = "ratio-of-means-hpue"

- Distinct display labels:
  - format.creel_estimates() displays "Ratio-of-Means CPUE" vs "Ratio-of-Means HPUE"
  - Test verifies: grep "Ratio-of-Means HPUE" in test-format-estimates.R:39

**Documentation Evidence:**
- man/estimate_harvest.Rd documents: "HPUE is estimated as the ratio of total harvest (kept fish) to total effort"
- man/estimate_harvest.Rd documents: "harvest (kept fish) is a subset of total catch"
- R/data.R documents example_interviews: "catch_kept: Integer fish kept (harvest), always <= catch_total"

**Test Evidence:**
- test-estimate-harvest.R lines 391-410: "HPUE vs CPUE relationship tests"
  - Verifies HPUE estimate <= CPUE estimate
  - Verifies both use same sample size
- Test creates data with catch_kept <= catch_total constraint

**Status:** ✓ VERIFIED - Clear conceptual and implementation distinction

### Truth 4: System validates harvest <= catch

**Validation Code:**
R/survey-bridge.R:785-802 in validate_interviews_tier1():

```r
# Check 7: harvest <= catch consistency (if harvest_col provided)
harvest_col_present <- !is.null(harvest_col) && harvest_col %in% names(interviews)
catch_col_present <- catch_col %in% names(interviews)
if (harvest_col_present && catch_col_present) {
  catch_vals <- interviews[[catch_col]]
  harvest_vals <- interviews[[harvest_col]]
  # Check only non-NA rows
  valid_rows <- !is.na(catch_vals) & !is.na(harvest_vals)
  if (any(valid_rows)) {
    violations <- sum(harvest_vals[valid_rows] > catch_vals[valid_rows])
    if (violations > 0) {
      collection$push(sprintf(
        "Harvest exceeds catch in %d row(s) - harvest must be <= catch",
        violations
      ))
    }
  }
}
```

**When validation runs:**
- Called from add_interviews() at line 574
- Runs before interviews are attached to design
- Errors accumulate in validation collection
- User sees all validation errors at once if allow_invalid = FALSE (default)

**Documentation:**
- R/creel-design.R:426 documents: "If provided, will be validated for consistency (harvest <= catch)"
- R/creel-design.R:466 documents: "Harvest <= catch consistency (if harvest provided)"

**Example Data:**
- R/data.R:69 documents: "catch_kept: Integer fish kept (harvest), always <= catch_total"
- example_interviews dataset respects this constraint

**Test Construction:**
- All test helpers in test-estimate-harvest.R create harvest data with:
  - catch_kept = pmax(0, catch_total - sample(...))
  - Ensures catch_kept <= catch_total by construction

**Status:** ✓ VERIFIED - Validation enforced at data attachment time

---

## Technical Quality Assessment

### Implementation Patterns

**1. Shared Validation Abstraction**
- validate_cpue_sample_size refactored to validate_ratio_sample_size
- Type parameter: "cpue" or "harvest"
- Eliminates duplication while maintaining context-aware messages
- No regressions in CPUE tests (40/40 still pass)

**2. Parallel Architecture**
- estimate_harvest mirrors estimate_cpue exactly
- Same parameter signature (by, variance, conf_level)
- Same routing pattern (total vs grouped)
- Same variance method support (taylor, bootstrap, jackknife)
- Reduces cognitive load for maintainers and users

**3. Edge Case Handling**
- Zero-effort filtering: warns and excludes (ratio undefined)
- NA harvest filtering: warns and excludes (harvest-specific edge case)
- Empty data check: clear error if all interviews filtered out
- Temporary survey design rebuild: maintains variance calculation integrity

**4. Reference Tests**
- Ungrouped HPUE matches manual survey::svyratio within 1e-10 tolerance
- Grouped HPUE matches manual survey::svyby within 1e-10 tolerance
- SE^2 matches vcov() diagonal
- Provides strong numerical correctness guarantees

### Test Coverage

**Total package tests:** 475 PASS, 0 FAIL
**Harvest-specific tests:** 79 PASS
**Test categories:**
- Basic behavior (6 tests)
- Input validation (5 tests)
- Sample size validation (4 tests)
- Grouped estimation (4 tests)
- Reference tests (3 tests)
- HPUE vs CPUE relationship (2 tests)
- Variance methods (3 tests)
- Integration with example data (3 tests)
- Zero-effort handling (2 tests)
- NA harvest handling (2 tests)
- Custom confidence levels (1 test)
- Format display (1 test in test-format-estimates.R)

### Code Quality

**R CMD check:** 0 errors, 0 warnings, 1 NOTE (hidden .mcp.json - expected)
**lintr:** 0 lints
**Test warnings:** 44 (all expected survey package "No weights or probabilities supplied")

**Documentation:** Complete roxygen2 documentation with:
- Description of HPUE concept
- Parameter documentation
- Return value structure
- Details section explaining ratio-of-means estimator
- Examples with realistic data
- Cross-references to estimate_cpue

---

_Verified: 2026-02-10T18:30:00Z_
_Verifier: Claude (gsd-verifier)_
