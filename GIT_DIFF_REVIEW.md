# Git Diff Review: Variance Engine Integration

**Date**: 2025-10-27
**Reviewer**: Claude Code
**Scope**: Major refactoring integrating native variance engine across all estimators

---

## Executive Summary

This is a **MAJOR REFACTORING** that rebuilds all core estimators (CPUE, effort, harvest, aggregation) to use a unified variance calculation engine. While the changes enable powerful new features, there are **CRITICAL ISSUES** that must be addressed before merging.

### Severity Classification
- 🔴 **CRITICAL**: Must fix before merge (breaking changes, bugs)
- 🟡 **WARNING**: Should address soon (edge cases, unclear behavior)
- 🟢 **INFO**: Nice to have (improvements, documentation)

---

## 1. Behavioral Changes

### 1.1 Core Behavioral Changes

#### ✅ **INTENTIONAL** - Unified Variance Engine
All estimator functions now delegate to `tc_compute_variance()`:
- `aggregate_cpue()` (R/aggregate-cpue.R:121-142)
- `est_cpue()` (R/est-cpue.R:96-148)
- `est_effort.aerial()` (R/est-effort-aerial.R)
- `est_effort.busroute_design()` (R/est-effort-busroute.R)
- `est_effort.instantaneous()` (R/est-effort-instantaneous.R)
- `est_effort.progressive()` (R/est-effort-progressive.R)
- `est_total_harvest()` (R/est-total-harvest.R)

**Impact**: Consistent variance estimation across all estimators.

#### ✅ **INTENTIONAL** - New Variance Methods
Users can now specify `variance_method`:
- `"survey"` (default, backward compatible)
- `"bootstrap"` (new)
- `"jackknife"` (new)
- `"svyrecvar"` (new, survey internals)
- `"linearization"` (alias for "survey")

**Impact**: Enables advanced variance estimation techniques.

#### ✅ **INTENTIONAL** - New Optional Features
Three new optional capabilities:
1. `decompose_variance = TRUE` → variance component decomposition
2. `design_diagnostics = TRUE` → design diagnostics
3. `n_replicates = 1000` → control resampling

**Impact**: Enhanced diagnostic capabilities for survey analysts.

### 1.2 Output Schema Changes

#### 🔴 **CRITICAL** - Breaking Change in Return Structure

**OLD SCHEMA:**
```r
tibble(
  [grouping_vars],
  estimate, se, ci_low, ci_high, n, method, diagnostics
)
```

**NEW SCHEMA:**
```r
tibble(
  [grouping_vars],
  estimate, se, ci_low, ci_high,
  deff,           # NEW: design effect
  n, method, diagnostics,
  variance_info   # NEW: list-column with variance details
)
```

**Files affected**: All estimator functions.

**Breaking Impact**:
- Code using positional column access will break
- Code expecting specific column names/order will break
- Code using `select(-diagnostics)` may break if not updated

**Example breakage**:
```r
# OLD CODE - WILL BREAK
result <- est_cpue(design, response = "catch_kept")
result[[5]]  # Was 'ci_high', now 'deff'

# SAFE CODE
result$ci_high  # Named access still works
```

#### 🟡 **WARNING** - `deff` Column Always Present

The `deff` (design effect) column is now always included even when `calculate_deff = TRUE` is not explicitly set. However, its value depends on the variance method:

**Concern**: Users may not understand when `deff` is meaningful:
- `NA` when method doesn't support it
- May be misleading for bootstrap/jackknife methods

**Recommendation**: Document clearly when `deff` is reliable.

---

## 2. API/Contract Violations

### 2.1 Function Signature Changes

#### ✅ **BACKWARD COMPATIBLE** - New Optional Parameters

All functions add 4 new optional parameters with safe defaults:
```r
# Example: est_cpue()
est_cpue <- function(
  ...,
  conf_level = 0.95,
  variance_method = "survey",        # NEW, defaults to old behavior
  decompose_variance = FALSE,        # NEW, opt-in
  design_diagnostics = FALSE,        # NEW, opt-in
  n_replicates = 1000               # NEW, only used if needed
)
```

**Assessment**: Safe because all parameters have defaults.

**However**: Return value structure changed (see 1.2) - this IS breaking.

### 2.2 Removed/Changed Exports

#### 🔴 **CRITICAL** - Function Removal

**NAMESPACE diff line 26**: `est_effort_aerial` export removed

**Impact**: Any code calling `est_effort_aerial()` will error.

**Migration Path**: Use `est_effort.aerial()` (S3 method) instead.

**Files affected**: NAMESPACE, man/est_effort_aerial.Rd (deleted)

#### ✅ **GOOD** - S3 Method Standardization

New S3 print methods added:
- `print.qa_checks_result` (was `print.qa_check_result`)
- `print.tc_design_diagnostics` (new)
- `print.tc_variance_decomp` (new)

**Assessment**: Proper S3 method naming convention.

### 2.3 Parameter Passing Issues

#### 🔴 **CRITICAL** - `est_cpue_auto()` Incomplete Parameter Forwarding

**File**: R/est-cpue.R:62-81

The `est_cpue_auto()` helper function now passes new parameters through to the recursive `est_cpue()` calls, but there's a **CRITICAL ISSUE**:

```r
# Line 74-81: Parameters ARE passed through
return(est_cpue_auto(
  design = design,
  by = by,
  response = response,
  effort_col = effort_col,
  min_trip_hours = min_trip_hours,
  conf_level = conf_level,
  variance_method = variance_method,      # ✅ Added
  decompose_variance = decompose_variance, # ✅ Added
  design_diagnostics = design_diagnostics, # ✅ Added
  n_replicates = n_replicates             # ✅ Added
))
```

**Assessment**: Fixed in this diff. Was this working before? Need to verify test coverage.

---

## 3. Edge Cases & Error Handling

### 3.1 Grouped Estimation Edge Cases

#### 🔴 **CRITICAL** - Empty Groups Not Handled

**File**: R/aggregate-cpue.R:121-142, R/est-cpue.R:96-148

When `by = "some_var"` produces empty strata, `tc_compute_variance()` may fail or produce `NA` values. The code does not explicitly check for or handle empty groups.

**Problem locations**:
```r
# R/aggregate-cpue.R:121
variance_result <- tc_compute_variance(
  design = svy_ratio,
  response = ".cpue_ratio",
  method = variance_method,
  by = by,           # <-- What if some groups are empty?
  ...
)
```

**Test case needed**:
```r
# Data with empty stratum
data <- data.frame(
  stratum = c("A", "A", "B"),
  catch = c(5, 3, 2),
  effort = c(2, 1, 1)
)
# Estimate by stratum including empty "C"
est_cpue(design, by = c("stratum"))
```

**Recommendation**: Add explicit empty group handling with warnings.

### 3.2 Variance Method Fallbacks

#### 🟡 **WARNING** - Silent Fallbacks

**File**: R/variance-engine.R:246-278, 293-310, 385-402

When advanced variance methods fail, the code falls back to standard survey variance with only a `cli_warn`:

```r
# R/variance-engine.R:293-310
rep_design <- tryCatch(
  survey::as.svrepdesign(design, type = "bootstrap", replicates = n_replicates),
  error = function(e) {
    cli::cli_warn(...)  # ⚠️ Only warns
    return(NULL)
  }
)

if (is.null(rep_design)) {
  result <- .tc_variance_survey(...)  # Falls back
  result$method_details$fallback <- TRUE
  return(result)
}
```

**Concern**: User requests `method = "bootstrap"` but gets `method = "survey"` with only a warning. The returned `result$method` still says `"bootstrap"` even though it fell back!

**Bug**: Line 156 sets `result$method <- method` AFTER the switch, so fallback methods don't update the method name.

```r
# R/variance-engine.R:140-161
result <- switch(method,
  "bootstrap" = .tc_variance_bootstrap(...),  # This may fall back
  ...
)

# Add method metadata
result$method <- method  # 🔴 BUG: Always sets to requested method, not actual
```

**Recommendation**:
1. Have internal functions return actual method used
2. Update `result$method` to reflect reality
3. Consider making fallback opt-in vs automatic

### 3.3 Missing Data Handling

#### 🟡 **WARNING** - Inconsistent `na.rm` Handling

The code uses `na.rm = TRUE` in survey calls:
```r
# R/variance-engine.R:176
est <- survey::svymean(response_formula, design, na.rm = TRUE)
```

But variance decomposition doesn't explicitly handle NAs:
```r
# R/variance-decomposition-engine.R:160
aov_fit <- aov(formula_nested, data = data)  # No na.action specified
```

**Recommendation**: Standardize NA handling across all variance calculations.

### 3.4 Ratio Estimation Edge Cases

#### 🟡 **WARNING** - Division by Zero Not Checked

**File**: R/aggregate-cpue.R:44-51, R/est-cpue.R:99-102

When creating ratio variables, division by zero is not checked:

```r
# R/est-cpue.R:99
svy_ratio <- stats::update(svy, .cpue_ratio = vars[[response]] / vars[[effort_col]])
```

If `effort_col` contains zeros, this creates `Inf` or `NaN` values.

**Original code** (now removed) had this protection:
```r
# Was in old est_cpue_roving
# Truncate very short trips to avoid unstable ratios
if (mode == "ratio_of_means" && !is.null(min_trip_hours)) {
  # Truncation logic
}
```

**Recommendation**: Add zero-effort checks before ratio creation.

---

## 4. Potential Bugs

### 4.1 Data Flow Bugs

#### 🔴 **CRITICAL** - Sample Size Mismatch in Grouped Estimation

**File**: R/aggregate-cpue.R:131-138, R/est-cpue.R:108-115

When using grouped estimation with the new variance engine, sample sizes are calculated separately:

```r
# R/aggregate-cpue.R:131-138
out <- tibble::tibble(
  !!!setNames(
    lapply(by, function(v) svy_ratio$variables[[v]][seq_along(variance_result$estimate)]),
    by
  ),
  estimate = variance_result$estimate,
  ...
  n = rep(NA_integer_, length(variance_result$estimate))  # <-- Set to NA!
)

# Get sample sizes (separate calculation)
n_by <- updated_data |>
  dplyr::group_by(dplyr::across(dplyr::all_of(by))) |>
  dplyr::summarise(n = dplyr::n(), .groups = "drop")
out <- dplyr::left_join(out, n_by, by = by)  # <-- JOIN
```

**Bugs**:
1. **Indexing Issue**: `svy_ratio$variables[[v]][seq_along(variance_result$estimate)]` assumes variables align with results. What if groups are dropped or reordered?

2. **Join Risk**: `left_join(out, n_by, by = by)` might mismatch if group ordering differs.

3. **Redundant NA**: Why set `n = rep(NA_integer_, ...)` then immediately join to overwrite?

**Recommendation**:
```r
# Better approach: get n from variance_result if available
# Or calculate n_by FIRST and use it consistently
```

#### 🔴 **CRITICAL** - `.interview_id` Collision Risk

**File**: R/aggregate-cpue.R:149-168

The code creates a temporary `.interview_id` column:

```r
# R/aggregate-cpue.R:149
agg_data$.interview_id <- seq_len(nrow(agg_data))
```

**Bug**: If input data already has a `.interview_id` column, it gets silently overwritten!

**Recommendation**: Check for column existence or use a more unique name (e.g., `.tc_internal_interview_id_12345`).

### 4.2 Type Safety Issues

#### 🟡 **WARNING** - Unvalidated List-Column Access

**File**: R/aggregate-cpue.R:315-332

The new `variance_info` list-column stores complex variance results:

```r
# R/aggregate-cpue.R:315-332
if (decompose_variance) {
  variance_result$decomposition <- tryCatch({
    tc_decompose_variance(...)
  }, error = function(e) {
    cli::cli_warn(...)
    NULL  # <-- Can be NULL
  })
}

# Later...
out$variance_info <- replicate(nrow(out), list(variance_result), simplify = FALSE)
```

**Concern**: Downstream code accessing `result$variance_info[[1]]$decomposition` needs to check for `NULL`.

**Recommendation**: Document NULL possibility or provide accessor functions.

### 4.3 Performance Concerns

#### 🟡 **WARNING** - Repeated Replicate Design Creation

**File**: R/variance-engine.R:290-314

When `method = "bootstrap"` is used in grouped estimation, the code creates replicate designs inside `tc_compute_variance()`. If this is called in a loop, it recreates the design each time:

```r
# R/variance-engine.R:293
rep_design <- survey::as.svrepdesign(design, type = "bootstrap", replicates = n_replicates)
```

**Impact**: Creating 1000 bootstrap replicates can be slow. If called 100 times for 100 species, this is very inefficient.

**Recommendation**: Allow pre-computed replicate designs to be passed in, or cache within a session.

### 4.4 Memory Concerns

#### 🟡 **WARNING** - Large List-Columns

The new `variance_info` list-column can be large:
- Bootstrap results with 1000 replicates
- Decomposition results with nested data
- Diagnostics with design information

For datasets with many groups, this multiplies:
```r
# If by = c("species", "location") gives 100 groups
# And variance_info contains 1000 bootstrap replicates each
# Memory usage could be substantial
```

**Recommendation**: Provide option to return lightweight results (summary only).

---

## 5. Data Flow & State Management

### 5.1 State Consistency

#### ✅ **GOOD** - Immutable Design Pattern

The code uses `stats::update()` to create new designs rather than modifying:

```r
# R/aggregate-cpue.R:177
svy_updated <- stats::update(svy_design, aggregated_catch = updated_data$aggregated_catch)
```

**Assessment**: Properly maintains design object immutability.

### 5.2 Variable Scoping

#### 🟡 **WARNING** - Temporary Variable Pollution

Functions create temporary variables in the design:

```r
# R/aggregate-cpue.R:182
svy_ratio <- stats::update(svy_updated, .cpue_ratio = updated_data$aggregated_catch / ...)

# R/est-cpue.R:99
svy_ratio <- stats::update(svy, .cpue_ratio = vars[[response]] / vars[[effort_col]])
```

**Concern**: These `.cpue_ratio`, `.cpue_agg` variables persist in the survey design if user keeps it. Could cause confusion in debugging.

**Recommendation**: Document that temporary variables starting with `.` are internal, or clean them up before returning (though they're not actually returned, so this is minor).

### 5.3 Parameter Flow

#### ✅ **GOOD** - Consistent Parameter Threading

New parameters are consistently threaded through all functions:

```r
# From user → est_cpue → est_cpue_auto → tc_compute_variance
variance_method
decompose_variance
design_diagnostics
n_replicates
```

**Assessment**: Parameter flow is clean and consistent.

---

## 6. Testing Gaps

### 6.1 Required New Tests

#### 🔴 **CRITICAL** - Variance Method Tests

**Required tests**:
```r
test_that("est_cpue supports all variance methods", {
  methods <- c("survey", "bootstrap", "jackknife", "linearization")
  for (method in methods) {
    result <- est_cpue(design, response = "catch", variance_method = method)
    expect_s3_class(result, "data.frame")
    expect_true("deff" %in% names(result))
  }
})

test_that("variance method fallback works correctly", {
  # Test that fallback updates method field correctly
})
```

**Priority**: Must have before merge.

#### 🔴 **CRITICAL** - Backward Compatibility Tests

**Required tests**:
```r
test_that("default parameters maintain backward compatibility", {
  # Old API call (without new parameters)
  result_old_style <- est_cpue(design, response = "catch")

  # Should have new columns but work like before
  expect_true("deff" %in% names(result_old_style))
  expect_true("variance_info" %in% names(result_old_style))

  # Estimate should match previous version (within tolerance)
  # This requires snapshot testing or reference values
})
```

**Priority**: Must have before merge.

#### 🔴 **CRITICAL** - Edge Case Tests

**Required tests**:
```r
test_that("empty groups handled gracefully", {
  # Create data with empty stratum
})

test_that("zero effort handled correctly", {
  # Data with zero effort values
})

test_that(".interview_id collision handled", {
  # Data already containing .interview_id column
})

test_that("single observation per group works", {
  # Variance should be NA or warn
})
```

**Priority**: Must have before merge.

### 6.2 Integration Tests

#### 🟡 **WARNING** - Cross-Function Workflow Tests

**Recommended tests**:
```r
test_that("full workflow with new variance methods works", {
  # effort with bootstrap → cpue with jackknife → harvest combined
})

test_that("aggregate_cpue → est_total_harvest workflow", {
  # Test the documented workflow
})
```

**Priority**: Should have soon.

### 6.3 Performance Tests

#### 🟢 **INFO** - Benchmark New Methods

**Recommended**:
```r
bench::mark(
  survey = est_cpue(design, variance_method = "survey"),
  bootstrap = est_cpue(design, variance_method = "bootstrap", n_replicates = 100),
  iterations = 10
)
```

**Priority**: Nice to have.

### 6.4 Current Test File Status

#### ⚠️ **UNKNOWN** - Test Coverage

The diff shows NO test file changes, but lists:
```
?? tests/testthat/test-architectural-compliance.R
?? tests/testthat/test-estimators-enhanced.R
?? tests/testthat/test-estimators-integration.R
?? tests/testthat/test-survey-internals.R
```

**Questions**:
1. Do these new test files cover the new functionality?
2. Were existing tests updated for schema changes?
3. Do any existing tests now fail due to column additions?

**Action Required**: Run full test suite and review new test files.

---

## 7. Documentation Needs

### 7.1 Function Documentation (Roxygen)

#### 🔴 **CRITICAL** - Incomplete @param Documentation

**Files**: All estimator .R files

The diff shows new parameters added to functions, and some `@param` tags added:

```r
#' @param variance_method **NEW** Variance estimation method (default "survey")
#' @param decompose_variance **NEW** Logical, decompose variance (default FALSE)
#' @param design_diagnostics **NEW** Logical, compute diagnostics (default FALSE)
#' @param n_replicates **NEW** Bootstrap/jackknife replicates (default 1000)
```

**Issues**:
1. **Incomplete details**: What are the valid values for `variance_method`?
2. **No @return updates**: Return value descriptions don't mention `deff` or `variance_info`
3. **No @details updates**: How do these interact? What are the tradeoffs?

**Required updates for each function**:
```r
#' @param variance_method Variance estimation method. One of:
#'   \describe{
#'     \item{"survey"}{Standard survey package (default, Taylor linearization)}
#'     \item{"bootstrap"}{Bootstrap resampling with n_replicates}
#'     \item{"jackknife"}{Jackknife resampling (JK1)}
#'     \item{"svyrecvar"}{Survey package internals (advanced)}
#'     \item{"linearization"}{Alias for "survey"}
#'   }
#' @param n_replicates Number of replicates for bootstrap/jackknife methods (default 1000).
#'   Ignored for other methods. Higher values increase precision but take longer.
#'
#' @return Tibble with columns:
#'   \describe{
#'     \item{estimate}{Point estimate}
#'     \item{se}{Standard error}
#'     \item{ci_low, ci_high}{Confidence interval}
#'     \item{deff}{Design effect (ratio of actual variance to SRS variance)}
#'     \item{n}{Sample size}
#'     \item{variance_info}{List-column with detailed variance information}
#'   }
```

#### 🔴 **CRITICAL** - Missing @export Documentation

New exported functions lack documentation:
```r
# NAMESPACE line 58: tc_compute_variance
# NAMESPACE line 60: tc_decompose_variance
# NAMESPACE line 61: tc_design_diagnostics
# NAMESPACE line 65: tc_extract_design_info
```

**Status**: Code files exist (R/variance-engine.R, R/variance-decomposition-engine.R) and have roxygen comments, but need review for completeness.

### 7.2 Migration Guide

#### 🔴 **CRITICAL** - Breaking Changes Guide Required

**File needed**: `docs/01-migration-variance-engine.md` or similar

**Content needed**:
```markdown
# Migration Guide: Variance Engine Integration

## Breaking Changes

### 1. Return Value Schema Changed

All estimator functions now return additional columns:
- `deff`: Design effect
- `variance_info`: List-column with variance details

**Impact**: Code using positional column access will break.

**Fix**: Use named column access.

### 2. Function Removed

`est_effort_aerial()` removed. Use `est_effort.aerial()` instead.

### 3. New Dependencies

Functions now require:
- survey package (existing)
- Optionally lme4 for mixed model decomposition

## New Features

### 1. Multiple Variance Methods

[Examples...]

### 2. Variance Decomposition

[Examples...]

### 3. Design Diagnostics

[Examples...]

## Compatibility

Old code using default parameters will work but return extra columns.
Test your code to ensure compatibility.
```

### 7.3 User Guide Updates

#### 🔴 **CRITICAL** - Update Getting Started Guide

**Files to update** (under `docs/`):
- `02-quick-start.md` - Show basic usage still works
- `03-user-guide.md` - Document new variance options
- `04-examples.md` - Add examples of new features

**Content needed**:
```markdown
## Variance Estimation Methods

tidycreel now supports multiple variance estimation methods:

### Standard Survey Method (Default)
...use when...

### Bootstrap Method
...use when...

### When to Use Each Method
[Decision tree or table]
```

### 7.4 Man Pages

#### 🔴 **CRITICAL** - .Rd Files Need Regeneration

The diff shows `.Rd` file changes but they may be auto-generated. After updating roxygen comments:

```bash
# Regenerate documentation
devtools::document()

# Check for issues
devtools::check()
```

**Files to verify**:
- All `man/*.Rd` files changed in diff
- New exports: tc_compute_variance.Rd, tc_decompose_variance.Rd, etc.

### 7.5 Vignette Needs

#### 🟡 **WARNING** - Advanced Features Need Vignettes

**Recommended vignettes**:
1. `vignettes/variance-methods.Rmd` - Compare variance methods
2. `vignettes/variance-decomposition.Rmd` - Use decomposition for survey design
3. `vignettes/design-diagnostics.Rmd` - Diagnose survey design issues

**Priority**: Should have for next release.

### 7.6 Internal Documentation

#### 🟢 **INFO** - Code Comments Adequate

The new variance engine files have good inline documentation:
- Clear function purposes
- Parameter descriptions
- Algorithm explanations

**Assessment**: Internal code documentation is good quality.

---

## Summary of Critical Issues

### Must Fix Before Merge (🔴)

1. **Return schema breaking change** - Add deprecation warnings or version bump
2. **Variance method fallback bug** - Fix `result$method` to reflect actual method used
3. **Empty groups not handled** - Add explicit checks and warnings
4. **`.interview_id` collision** - Check for existing column or use unique name
5. **Sample size mismatch risk** - Fix group alignment in grouped estimation
6. **Missing test coverage** - Add tests for new features and edge cases
7. **Documentation incomplete** - Complete @param, @return, @details for all functions
8. **Migration guide missing** - Document breaking changes

### Should Address Soon (🟡)

1. **Silent fallbacks** - Make fallback behavior more explicit
2. **Inconsistent NA handling** - Standardize across all variance functions
3. **Zero-effort not checked** - Add protection before ratio creation
4. **Performance concerns** - Optimize repeated replicate design creation
5. **Memory concerns** - Consider lightweight result options
6. **Temporary variable pollution** - Document or clean up
7. **Advanced vignettes** - Create user guides for new features

### Nice to Have (🟢)

1. **Performance benchmarks** - Compare variance methods
2. **Enhanced code comments** - Already good, could add more examples

---

## Recommended Actions

### Immediate (Before Merge)

1. **Run full test suite**: `devtools::test()`
2. **Check for failures**: Update tests for new schema
3. **Fix critical bugs**: Address all 🔴 issues above
4. **Update documentation**: Regenerate .Rd files
5. **Add migration guide**: Document breaking changes
6. **Version bump**: This is a minor version at minimum (x.Y.z), possibly major

### Short Term (Next Week)

1. **Add comprehensive tests**: Cover all new features
2. **Write vignettes**: Show users how to use new features
3. **Performance testing**: Ensure no regressions
4. **Review by domain expert**: Have a survey statistician review

### Medium Term (Next Month)

1. **User feedback**: Release beta, gather feedback
2. **Optimize performance**: Address any bottlenecks found
3. **Enhanced error messages**: Make errors more actionable
4. **Consider snapshot tests**: For backward compatibility

---

## Diff Quality Assessment

### Strengths ✅
- Clear architectural vision (unified variance engine)
- Backward compatible parameters (defaults maintain old behavior)
- Consistent parameter threading
- Good internal code documentation
- Follows R/tidyverse conventions

### Weaknesses ⚠️
- Breaking changes in return values not clearly flagged
- Insufficient error handling for edge cases
- Missing test coverage in diff
- Incomplete user-facing documentation
- Some subtle bugs in data alignment

### Overall Risk Level
**🟡 MEDIUM-HIGH RISK**

This is high-quality refactoring with a clear purpose, but the breaking changes and edge case handling issues make it risky to merge without additional work. The code itself is well-structured, but needs more defensive programming and testing.

---

## Questions for Author

1. **Versioning**: Is this intended as a major version bump (breaking changes)?
2. **Testing**: Are the new test files (`test-estimators-enhanced.R`, etc.) complete?
3. **Performance**: Have you benchmarked bootstrap with n_replicates=1000?
4. **Backward compat**: Should we add deprecation warnings for schema change?
5. **Documentation**: Timeline for completing vignettes?
6. **Design decision**: Why always include `deff` column even when NA?
7. **Fallback behavior**: Should fallback be automatic or error?

---

## Sign-Off Checklist

Before approving this PR/commit:

- [ ] All 🔴 CRITICAL issues resolved
- [ ] Full test suite passes (`devtools::test()`)
- [ ] R CMD check passes (`devtools::check()`)
- [ ] Documentation regenerated (`devtools::document()`)
- [ ] Migration guide written
- [ ] CHANGELOG.md updated
- [ ] Version number bumped appropriately
- [ ] Code review by second developer
- [ ] Backward compatibility tested with real user code
- [ ] Performance acceptable (benchmark comparison)

---

**Review completed**: 2025-10-27
**Recommendation**: **DO NOT MERGE** until critical issues addressed
**Estimated fix time**: 8-16 hours for critical issues + testing
