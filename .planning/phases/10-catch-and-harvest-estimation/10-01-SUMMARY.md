---
phase: 10-catch-and-harvest-estimation
plan: 01
subsystem: estimation
tags: [hpue, harvest-estimation, ratio-estimation, survey-design, tdd]
dependency_graph:
  requires:
    - phase-09-cpue-estimation
    - survey::svyratio
  provides:
    - estimate_harvest()
    - validate_ratio_sample_size() (shared)
  affects:
    - R/creel-estimates.R (estimation layer)
    - R/survey-bridge.R (validation layer)
tech_stack:
  added:
    - HPUE ratio-of-means estimator via survey::svyratio
  patterns:
    - TDD red-green cycle
    - Shared validation abstraction (ratio estimation)
    - Reference tests for numerical correctness
key_files:
  created:
    - tests/testthat/test-estimate-harvest.R (426 lines, 24 tests)
    - man/estimate_harvest.Rd (generated documentation)
  modified:
    - R/creel-estimates.R (+188 lines: estimate_harvest, estimate_harvest_total, estimate_harvest_grouped)
    - R/survey-bridge.R (refactored validate_cpue_sample_size → validate_ratio_sample_size)
    - NAMESPACE (+1 export: estimate_harvest)
decisions:
  - title: "Shared validation function for ratio estimators"
    rationale: "CPUE and HPUE use identical sample size thresholds (n<10 error, n<30 warn). Refactoring validate_cpue_sample_size to validate_ratio_sample_size with type parameter eliminates duplication while maintaining context-aware error messages."
    alternatives: ["Duplicate validation logic", "Generic validation without type context"]
    outcome: "Clean abstraction, no regressions in CPUE tests"
  - title: "HPUE method identifier: ratio-of-means-hpue"
    rationale: "Distinguishes harvest rate estimation from CPUE (ratio-of-means-cpue) and total estimation. Enables correct human-readable display via format.creel_estimates switch."
    alternatives: ["Generic 'harvest' method", "Reuse 'ratio-of-means' without qualifier"]
    outcome: "Clear method identification, extensible for future estimators"
metrics:
  duration_minutes: 10
  completed_date: "2026-02-10"
  tasks_completed: 2
  files_modified: 4
  tests_added: 24
  test_coverage: "comprehensive (basic, validation, sample size, grouped, reference, HPUE vs CPUE)"
---

# Phase 10 Plan 01: Implement estimate_harvest() Summary

**One-liner:** JWT-style ratio-of-means HPUE estimation with shared sample size validation, proven correct via reference tests against manual survey::svyratio calculations within 1e-10 tolerance.

## Objective Achieved

Implemented `estimate_harvest()` function using ratio-of-means estimation for harvest per unit effort (HPUE). Harvest represents kept fish (subset of total catch), so HPUE <= CPUE for same data. Refactored sample size validation into shared `validate_ratio_sample_size()` function used by both CPUE and harvest estimation. Comprehensive TDD test suite with reference tests proving numerical correctness.

## Work Completed

### Task 1: RED - Write Failing Tests (Commit: a1b9a2e)

**Created:** `tests/testthat/test-estimate-harvest.R` (426 lines, 24 tests)

**Test structure mirrors test-estimate-cpue.R exactly:**

**Test helpers:**
- `make_harvest_design()`: 32 interviews (16 weekday, 16 weekend) with catch_total, hours_fished, catch_kept
- `make_design_without_harvest()`: Design with interviews but NO harvest parameter (harvest_col NULL)
- `make_small_harvest_design(n)`: Exactly n interviews for sample size testing
- `make_unbalanced_harvest_design()`: 15 weekday, 5 weekend (for grouped validation)

**Test sections (24 tests total):**

1. **Basic behavior (6 tests):**
   - Returns creel_estimates class
   - Has estimates tibble with correct columns (estimate, se, ci_lower, ci_upper, n)
   - Method is "ratio-of-means-hpue"
   - variance_method is "taylor" by default
   - conf_level is 0.95 by default
   - Estimate is positive numeric (HPUE >= 0)

2. **Input validation (5 tests):**
   - Error when design not creel_design
   - Error when no interview_survey
   - Error for invalid variance method
   - Error when missing effort_col
   - **NEW:** Error when design has no harvest_col (uses make_design_without_harvest) - error message mentions add_interviews harvest parameter

3. **Sample size validation (4 tests):**
   - Error when n < 10 ungrouped
   - Warning when 10 <= n < 30 ungrouped
   - No warning when n >= 30 ungrouped
   - Error when any group has n < 10

4. **Grouped estimation (4 tests):**
   - Grouped by day_type returns creel_estimates with by_vars set
   - Grouped result has day_type column
   - Grouped result has one row per group level (2 for weekday/weekend)
   - Grouped result has n column reflecting per-group sample sizes

5. **Reference tests (3 tests):**
   - Ungrouped HPUE matches manual `survey::svyratio(~catch_kept, ~hours_fished, svy)` (tolerance 1e-10)
   - Grouped HPUE matches manual `survey::svyby(..., FUN=svyratio)` (tolerance 1e-10)
   - SE^2 matches variance from vcov() diagonal

6. **HPUE vs CPUE relationship (2 tests):**
   - HPUE estimate <= CPUE estimate (since harvest is subset of catch)
   - Both use same n (sample size should match)

**Verification state:** All tests FAIL with "could not find function estimate_harvest" (correct RED state). Existing CPUE tests still pass.

---

### Task 2: GREEN - Implement estimate_harvest() (Commit: 6bb0460)

**Part A: Refactor validation in R/survey-bridge.R**

Renamed `validate_cpue_sample_size()` to `validate_ratio_sample_size()`:

```r
validate_ratio_sample_size <- function(design, by_vars, type = "cpue") {
  estimation_type <- if (type == "harvest") "harvest" else "CPUE"

  # Error if n < 10: "Insufficient sample size for {estimation_type} estimation."
  # Warning if 10 <= n < 30: "Small sample size for {estimation_type} estimation."
  # ... (rest of validation logic unchanged)
}
```

**Changes:**
- Added `type = "cpue"` parameter (default "cpue" for backward compatibility)
- Parameterized hardcoded "CPUE" strings to `{estimation_type}` in error/warning messages
- All validation logic (n<10 error, n<30 warning, grouped validation) unchanged
- Updated roxygen2 comment to document type parameter

**Part B: Update estimate_cpue() in R/creel-estimates.R**

Updated calls to use renamed function:
- Ungrouped: `validate_ratio_sample_size(design, NULL, type = "cpue")`
- Grouped: `validate_ratio_sample_size(design, by_vars, type = "cpue")`

**Verified:** All 40 CPUE tests still pass (no regressions from rename).

**Part C: Implement estimate_harvest() in R/creel-estimates.R**

**1. estimate_harvest() exported function:**

```r
estimate_harvest <- function(design, by = NULL, variance = "taylor", conf_level = 0.95)
```

**Full implementation:**
- Same signature as estimate_cpue()
- Same validation pattern: variance method, creel_design class, interview_survey existence
- **NEW validation:** Checks `design$harvest_col` exists (not NULL). Error message:
  ```
  "No harvest column available."
  "Design must have harvest_col set."
  "Call add_interviews() with the harvest parameter."
  "Example: design <- add_interviews(design, interviews,
            catch = catch_total, harvest = catch_kept, effort = hours_fished)"
  ```
- Validates `design$effort_col` exists
- Calls `validate_ratio_sample_size(design, NULL/by_vars, type = "harvest")` for sample size validation
- Routes to `estimate_harvest_total()` or `estimate_harvest_grouped()`

**Roxygen2 documentation:**
- @description: Explains HPUE = harvest per unit effort, only kept fish, distinguished from CPUE
- @param: All parameters documented (design, by, variance, conf_level)
- @return: Describes creel_estimates structure with method = "ratio-of-means-hpue"
- @details:
  - Ratio-of-means estimator using survey::svyratio
  - HPUE <= CPUE relationship (harvest is subset of catch)
  - Sample size validation thresholds (n<10 error, n<30 warning)
  - Variance methods (taylor, bootstrap, jackknife)
- @seealso: References estimate_cpue
- @examples: Working examples with set.seed, harvest <= catch constraint
- @export tag

**2. estimate_harvest_total() internal function (@keywords internal @noRd):**

```r
estimate_harvest_total <- function(design, variance_method, conf_level) {
  harvest_col <- design$harvest_col
  effort_col <- design$effort_col

  svy_design <- get_variance_design(design$interview_survey, variance_method)
  harvest_formula <- stats::reformulate(harvest_col)
  effort_formula <- stats::reformulate(effort_col)

  svy_result <- suppressWarnings(
    survey::svyratio(harvest_formula, effort_formula, svy_design)
  )

  # Extract estimates, SE, CI
  # Return creel_estimates with method = "ratio-of-means-hpue"
}
```

**Key differences from estimate_cpue_total:**
- Uses `harvest_col` instead of `catch_col` in formulas
- Returns `method = "ratio-of-means-hpue"` instead of "ratio-of-means-cpue"
- **NOTE:** Does NOT include zero-effort filtering (that's Plan 02 scope)

**3. estimate_harvest_grouped() internal function (@keywords internal @noRd):**

```r
estimate_harvest_grouped <- function(design, by_vars, variance_method, conf_level) {
  harvest_col <- design$harvest_col
  effort_col <- design$effort_col

  svy_design <- get_variance_design(design$interview_survey, variance_method)
  harvest_formula <- stats::reformulate(harvest_col)
  effort_formula <- stats::reformulate(effort_col)
  by_formula <- stats::reformulate(by_vars)

  svy_result <- suppressWarnings(survey::svyby(
    formula = harvest_formula,
    by = by_formula,
    design = svy_design,
    FUN = survey::svyratio,
    denominator = effort_formula,
    vartype = c("se", "ci"),
    ci.level = conf_level,
    keep.names = FALSE
  ))

  # Extract ratio column: "harvest_col/effort_col"
  # Extract se column: "se.harvest_col/effort_col"
  # Merge per-group sample sizes
  # Return creel_estimates with method = "ratio-of-means-hpue"
}
```

**Key differences from estimate_cpue_grouped:**
- Uses `harvest_col` instead of `catch_col` in formulas
- `ratio_col = paste0(harvest_col, "/", effort_col)`
- `se_col = paste0("se.", ratio_col)`
- Returns `method = "ratio-of-means-hpue"`
- **NOTE:** Does NOT include zero-effort filtering (Plan 02 scope)

**4. Updated format.creel_estimates() to display "Ratio-of-Means HPUE":**

```r
method_display <- switch(x$method,
  total = "Total",
  "ratio-of-means-cpue" = "Ratio-of-Means CPUE",
  "ratio-of-means-hpue" = "Ratio-of-Means HPUE",  # NEW
  x$method
)
```

**Part D: Generate docs and verify**

- Ran `devtools::document()` → generated `man/estimate_harvest.Rd`, updated NAMESPACE
- Added nolint comments for cli glue variables: `# nolint: object_usage_linter`
- Fixed linting issues:
  - Split long error message strings across lines
  - Refactored complex if condition to avoid styler/lintr conflict
- **All tests pass:** 440 tests PASS (24 harvest + 40 CPUE + 376 others)
- **R CMD check:** 0 errors, 0 warnings
- **lintr:** 0 lints (clean code style)

---

## Deviations from Plan

**None - plan executed exactly as written.**

All tasks completed as specified. No blocking issues encountered. No architectural changes needed.

---

## Verification Results

### Test Results

**Harvest tests (test-estimate-harvest.R):**
- 24 tests PASS
- 27 warnings (expected survey package "No weights or probabilities supplied")

**CPUE tests (test-estimate-cpue.R):**
- 40 tests PASS (no regressions from validation rename)
- 40 warnings (expected survey package warnings)

**All package tests:**
- **440 tests PASS**
- 0 FAIL
- 0 SKIP
- 193 warnings (all expected survey package warnings)
- Duration: 6.4 seconds

### Reference Test Verification

**Ungrouped HPUE correctness:**
```r
# tidycreel result
result <- estimate_harvest(design)

# Manual calculation
svy <- design$interview_survey
manual_result <- survey::svyratio(~catch_kept, ~hours_fished, svy)

# Verification
expect_equal(result$estimates$estimate, coef(manual_result), tolerance = 1e-10)
expect_equal(result$estimates$se, survey::SE(manual_result), tolerance = 1e-10)
expect_equal(result$estimates$se^2, vcov(manual_result), tolerance = 1e-10)
```
**Result:** All match within 1e-10 tolerance ✓

**Grouped HPUE correctness:**
```r
# tidycreel grouped result
result <- estimate_harvest(design, by = day_type)

# Manual calculation
manual_result <- survey::svyby(
  ~catch_kept, ~day_type,
  denominator = ~hours_fished,
  design = svy,
  FUN = survey::svyratio,
  vartype = c("se", "ci"),
  ci.level = 0.95,
  keep.names = FALSE
)

# Verification for each group
for (day in c("weekday", "weekend")) {
  expect_equal(
    result$estimates$estimate[result$estimates$day_type == day],
    manual_result$`catch_kept/hours_fished`[manual_result$day_type == day],
    tolerance = 1e-10
  )
}
```
**Result:** All groups match within 1e-10 tolerance ✓

**HPUE vs CPUE relationship:**
```r
result_hpue <- estimate_harvest(design)
result_cpue <- estimate_cpue(design)

expect_true(result_hpue$estimates$estimate <= result_cpue$estimates$estimate)
expect_equal(result_hpue$estimates$n, result_cpue$estimates$n)
```
**Result:** HPUE <= CPUE verified, sample sizes match ✓

### R CMD check

```
Duration: 56s
0 errors ✔
0 warnings ✔
1 note (pre-existing .mcp.json)
```

### lintr

```
0 lints ✔
```

**Code style:** Clean. All files pass styler and lintr checks.

---

## Technical Implementation Notes

### Ratio-of-Means Estimator

HPUE uses the same ratio-of-means estimator as CPUE, but with harvest as numerator:

```
HPUE = (Σ harvest_i) / (Σ effort_i)
```

**Why ratio-of-means (not mean-of-ratios)?**
- Correctly handles variable trip lengths (effort varies)
- Accounts for correlation between harvest and effort in variance calculation
- survey::svyratio uses Taylor linearization for variance: `Var(R) ≈ (1/μ_x^2) * Var(Y - RX)`
- Appropriate for stratified designs

**Harvest vs Catch:**
- Harvest = kept fish (subset of total catch)
- Catch = harvest + released fish
- Always: harvest_i <= catch_i for all interviews
- Therefore: HPUE <= CPUE for same data

### Shared Validation Architecture

**Before refactoring (Phase 9):**
```
validate_cpue_sample_size(design, by_vars)
  ├─ n < 10 → error: "Insufficient sample size for CPUE estimation."
  └─ 10 <= n < 30 → warn: "Small sample size for CPUE estimation."
```

**After refactoring (Phase 10):**
```
validate_ratio_sample_size(design, by_vars, type = "cpue"|"harvest")
  ├─ estimation_type <- if (type == "harvest") "harvest" else "CPUE"
  ├─ n < 10 → error: "Insufficient sample size for {estimation_type} estimation."
  └─ 10 <= n < 30 → warn: "Small sample size for {estimation_type} estimation."
```

**Benefits:**
- Eliminates duplication (same thresholds for all ratio estimators)
- Context-aware error messages (users see "harvest" or "CPUE")
- Extensible (future ratio estimators just pass `type` parameter)
- Zero regressions (all CPUE tests still pass)

### Method Identification

**Internal method field values:**
- `"total"` → Total estimation (survey::svytotal)
- `"ratio-of-means-cpue"` → CPUE estimation (survey::svyratio with catch)
- `"ratio-of-means-hpue"` → Harvest estimation (survey::svyratio with harvest)

**Human-readable display (format.creel_estimates):**
- `"total"` → "Total"
- `"ratio-of-means-cpue"` → "Ratio-of-Means CPUE"
- `"ratio-of-means-hpue"` → "Ratio-of-Means HPUE"

**Why separate identifiers?**
- Users need to distinguish CPUE from HPUE in results
- Enables method-specific formatting/reporting in future
- Clear audit trail in saved creel_estimates objects

---

## Files Modified

### Created Files

| File | Lines | Purpose |
|------|-------|---------|
| tests/testthat/test-estimate-harvest.R | 426 | Comprehensive test suite for estimate_harvest() |
| man/estimate_harvest.Rd | ~150 | Generated roxygen2 documentation |

### Modified Files

| File | Changes | Key Additions |
|------|---------|---------------|
| R/creel-estimates.R | +188 lines | estimate_harvest() exported, estimate_harvest_total(), estimate_harvest_grouped(), format update |
| R/survey-bridge.R | refactor | validate_cpue_sample_size → validate_ratio_sample_size (type parameter) |
| NAMESPACE | +1 export | Added estimate_harvest |

### Commits

| Commit | Hash | Message | Files |
|--------|------|---------|-------|
| Task 1 | a1b9a2e | test(10-01): add failing tests for estimate_harvest() | test-estimate-harvest.R |
| Task 2 | 6bb0460 | feat(10-01): implement estimate_harvest() with ratio-of-means HPUE estimation | creel-estimates.R, survey-bridge.R, estimate_harvest.Rd, NAMESPACE |

---

## Success Criteria Met

- ✅ estimate_harvest(design) returns creel_estimates with method = "ratio-of-means-hpue"
- ✅ estimate_harvest(design, by = day_type) returns grouped results
- ✅ estimate_harvest(design_without_harvest) errors with informative message about harvest parameter
- ✅ Sample size validation shared: validate_ratio_sample_size used by both CPUE and harvest
- ✅ HPUE estimates <= CPUE estimates for same data (harvest is subset of catch)
- ✅ Reference tests match manual survey::svyratio within tolerance 1e-10
- ✅ Variance parameter accepts "taylor", "bootstrap", "jackknife" (reuses get_variance_design)
- ✅ All existing tests pass (no regressions)
- ✅ R CMD check: 0 errors, 0 warnings

---

## Key Insights

### What Worked Well

1. **TDD pattern execution:** RED → GREEN cycle enforced correct behavior from start. Reference tests caught potential numerical errors before they occurred.

2. **Mirroring CPUE architecture:** estimate_harvest() implementation was straightforward because it follows the exact same pattern as estimate_cpue(). Test structure also mirrors test-estimate-cpue.R, making it easy to verify completeness.

3. **Shared validation abstraction:** Refactoring to validate_ratio_sample_size() eliminated duplication while improving maintainability. Adding a future ratio estimator just requires passing `type = "new_estimator"`.

4. **Reference test precision:** Using tolerance = 1e-10 for manual svyratio comparison provides strong numerical correctness guarantees. Tests verify not just approximate correctness but exact equivalence to survey package calculations.

### Technical Decisions

1. **Why not include zero-effort filtering in this plan?**
   - Plan scope: Basic harvest estimation functionality
   - Plan 02 scope: Quality assurance, edge cases, zero-effort handling
   - Mirrors Phase 9 split: 09-01 (basic CPUE), 09-02 (CPUE quality assurance)
   - Keeps this plan focused and atomic

2. **Why separate estimate_harvest_total and estimate_harvest_grouped?**
   - Mirrors CPUE implementation pattern
   - Different return structures (ungrouped: single row; grouped: multiple rows)
   - Different sample size validation contexts
   - Easier to test independently

3. **Why add type parameter instead of separate validation functions?**
   - Validation logic is identical (thresholds, grouped checks)
   - Only difference is error message context ("CPUE" vs "harvest")
   - Single source of truth for ratio estimator requirements
   - Easier to maintain (one function to update if thresholds change)

### Potential Future Extensions

1. **Zero-effort handling:** Plan 10-02 will add filtering logic (mirroring 09-02 implementation for CPUE)

2. **Additional ratio estimators:** Framework now supports any ratio estimator:
   - Just add `type = "new_estimator"` to validate_ratio_sample_size calls
   - Follow estimate_harvest pattern (replace numerator column)
   - Example: Effort per trip, harvest per trip, etc.

3. **Method-specific formatting:** format.creel_estimates could add harvest-specific details (e.g., harvest rate as percentage, comparison to CPUE if both available)

---

## Self-Check: PASSED

**Verified created files exist:**
```bash
✓ tests/testthat/test-estimate-harvest.R exists (426 lines)
✓ man/estimate_harvest.Rd exists (~150 lines)
```

**Verified commits exist:**
```bash
✓ a1b9a2e: test(10-01): add failing tests for estimate_harvest()
✓ 6bb0460: feat(10-01): implement estimate_harvest() with ratio-of-means HPUE estimation
```

**Verified exports:**
```bash
✓ estimate_harvest in NAMESPACE
✓ estimate_harvest() callable from package namespace
```

**Verified test results:**
```bash
✓ All 24 harvest tests PASS
✓ All 40 CPUE tests PASS (no regressions)
✓ All 440 package tests PASS
✓ R CMD check: 0 errors, 0 warnings
✓ lintr: 0 lints
```

**All claims verified. Self-check PASSED.**
