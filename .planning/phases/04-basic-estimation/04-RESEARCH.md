# Phase 4: Basic Estimation - Research

**Researched:** 2026-02-08
**Domain:** Survey estimation with R survey package, variance methods, confidence intervals
**Confidence:** HIGH

## Summary

Phase 4 implements `estimate_effort()` to compute total effort estimates with standard errors and confidence intervals using the survey package's design-based inference machinery. The survey package provides `svytotal()` and `svymean()` functions that use Taylor linearization (default) for variance estimation, with bootstrap and jackknife methods available via replicate weights (`as.svrepdesign()`). Results are returned as `creel_estimates` S3 objects containing tidy data frames with point estimates, standard errors, confidence intervals, and sample sizes, following broom package patterns (tidy/glance/augment).

Phase 3 already constructed the internal `survey.design2` object during `add_counts()`, so Phase 4's core task is calling survey package estimation functions and transforming results into tidycreel's domain vocabulary. Tier 2 validation (statistical quality checks) happens during estimation - warning about zero/negative effort values and sparse strata (< 3 observations per stratum) that may produce unreliable variance estimates.

Key insight: The survey package returns S3 objects (class `svystat`) from `svytotal()`/`svymean()` with methods for extracting components: `coef()` for point estimates, `SE()` for standard errors, `confint()` for confidence intervals, and `cv()` for coefficient of variation. Transform these into tidy tibbles for the `creel_estimates` object.

**Primary recommendation:** Use `svytotal()` with Taylor linearization (default) for total effort estimation. Store variance method in `creel_estimates` attributes for reproducibility. Implement Tier 2 validation as warnings (not errors) to educate users about data quality issues without blocking legitimate edge-case analyses. Follow testthat reference testing patterns (comparing numeric results with `expect_equal()` and tolerance) to verify estimates match manual survey package calculations.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| survey | 4.4+ | Design-based variance estimation | Already added in Phase 3, provides svytotal/svymean with Taylor linearization |
| cli | Current | User-facing warnings for Tier 2 validation | Already in DESCRIPTION, used for error/warning messages |
| rlang | Current | Attribute manipulation, validation | Already in DESCRIPTION, standard for tidyverse packages |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| testthat | 3.3.2+ | Reference tests with numeric tolerance | Already in DESCRIPTION (Suggests), use expect_equal with tolerance for comparing estimates |
| tibble | Current | Tidy result data frames | Already in DESCRIPTION via tidyselect, use tibble() for result objects |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| survey svytotal | Manual variance formulas | Manual formulas don't handle edge cases (lonely PSU, domain estimation covariances) |
| tibble results | Base data.frame | tibbles print better, integrate with tidyverse, minimal overhead |
| testthat tolerance | Exact equality | Floating point math requires tolerance for numeric comparisons |

**Installation:**
```bash
# All packages already in DESCRIPTION from Phase 1-3
# No new dependencies needed for Phase 4
```

## Architecture Patterns

### Recommended Project Structure
Current structure already established:
```
R/
├── creel-design.R           # creel_design constructor, add_counts (Phase 2-3)
├── creel-estimates.R        # estimate_effort() goes here (Phase 4)
├── survey-bridge.R          # construct_survey_design (Phase 3)
├── validate-schemas.R       # validate_count_schema (Phase 1)
└── creel-validation.R       # Tier 2 validation functions (Phase 4)

tests/testthat/
├── test-creel-estimates.R   # Expand for estimate_effort() unit tests
├── test-estimate-effort.R   # NEW: reference tests for Phase 4
└── helpers.R                # NEW: shared test fixtures for estimation
```

### Pattern 1: Survey Function Result Extraction

**What:** Transform survey package S3 result objects into tidy data frames

**When to use:** All estimation functions that wrap `svytotal()`, `svymean()`, etc.

**Example:**
```r
# Source: survey package documentation - surveysummary functions
# https://r-survey.r-forge.r-project.org/survey/html/surveysummary.html

estimate_effort <- function(design, formula = ~count, variance = "taylor", conf_level = 0.95) {
  # Validate design has counts attached
  if (is.null(design$survey)) {
    cli::cli_abort(c(
      "No survey design available.",
      "x" = "Call {.fn add_counts} before estimating effort.",
      "i" = "Example: {.code design <- add_counts(design, counts)}"
    ))
  }

  # Tier 2 validation (warnings, not errors)
  warn_tier2_issues(design)

  # Call survey package
  svy_result <- survey::svytotal(formula, design$survey)

  # Extract components using survey S3 methods
  estimate <- as.numeric(coef(svy_result))
  se <- as.numeric(SE(svy_result))
  ci <- confint(svy_result, level = conf_level)
  n <- nrow(design$counts)  # Total sample size

  # Build tidy data frame
  estimates_df <- tibble::tibble(
    estimate = estimate,
    se = se,
    ci_lower = ci[, 1],
    ci_upper = ci[, 2],
    n = n
  )

  # Return creel_estimates object
  new_creel_estimates(
    estimates = estimates_df,
    method = "total",
    variance_method = variance,
    design = design,
    conf_level = conf_level
  )
}
```

### Pattern 2: Variance Method Selection (Taylor vs Replicate Weights)

**What:** Default to Taylor linearization, support bootstrap/jackknife via replicate weights

**When to use:** `variance = "bootstrap"` or `variance = "jackknife"` parameter

**Example:**
```r
# Source: survey package as.svrepdesign documentation
# https://rdrr.io/rforge/survey/man/as.svrepdesign.html

# Internal helper to select variance method
get_design_for_variance <- function(design, variance_method) {
  if (variance_method == "taylor") {
    # Use original design with Taylor linearization (default)
    return(design$survey)
  } else if (variance_method == "bootstrap") {
    # Convert to replicate weights design
    survey::as.svrepdesign(design$survey, type = "bootstrap")
  } else if (variance_method == "jackknife") {
    # Convert to jackknife replicate weights
    survey::as.svrepdesign(design$survey, type = "JK1")
  } else {
    cli::cli_abort(c(
      "Unknown variance method: {.val {variance_method}}",
      "i" = "Supported methods: {.val taylor}, {.val bootstrap}, {.val jackknife}"
    ))
  }
}

# Usage in estimate_effort
estimate_effort <- function(design, formula = ~count, variance = "taylor", conf_level = 0.95) {
  # Select appropriate design object for variance method
  svy_design <- get_design_for_variance(design, variance)

  # Call appropriate survey function
  if (variance == "taylor") {
    svy_result <- survey::svytotal(formula, svy_design)
  } else {
    # Replicate weight designs use same interface
    svy_result <- survey::svytotal(formula, svy_design)
  }

  # Extract and return results (same extraction code)
  # ...
}
```

### Pattern 3: Tier 2 Validation (Statistical Quality Warnings)

**What:** Issue warnings for data quality issues that may affect estimate reliability

**When to use:** During estimation, before calling survey package functions

**Example:**
```r
# Tier 2 validation function
warn_tier2_issues <- function(design) {
  counts <- design$counts

  # EST-13: Warn on zero/negative effort values
  if (any(counts$count <= 0, na.rm = TRUE)) {
    n_zero <- sum(counts$count == 0, na.rm = TRUE)
    n_negative <- sum(counts$count < 0, na.rm = TRUE)

    cli::cli_warn(c(
      "Count data contains {n_zero + n_negative} zero or negative value{?s}.",
      "!" = "Zero counts: {n_zero}, Negative counts: {n_negative}",
      "i" = "Effort estimates may be biased if these represent true counts vs missing data.",
      "i" = "Consider filtering or investigating these observations."
    ))
  }

  # EST-14: Warn on sparse strata (< 3 observations)
  strata_counts <- table(counts$.strata)
  sparse_strata <- strata_counts[strata_counts < 3]

  if (length(sparse_strata) > 0) {
    cli::cli_warn(c(
      "Sparse strata detected: {length(sparse_strata)} stratum/strata with < 3 observations.",
      "!" = paste(
        "Strata with few observations produce unreliable variance estimates.",
        "Consider combining strata or collecting more data."
      ),
      "i" = "Sparse strata: {.val {names(sparse_strata)}}"
    ))
  }
}
```

### Pattern 4: Reference Testing with Tolerance

**What:** Compare tidycreel estimates to manual survey package calculations

**When to use:** TEST-06, TEST-07 requirements - verify implementation correctness

**Example:**
```r
# Source: testthat equality-expectations documentation
# https://testthat.r-lib.org/reference/equality-expectations.html

test_that("estimate_effort matches manual svytotal calculation", {
  # Construct design via tidycreel
  cal <- make_test_calendar()
  design <- creel_design(cal, date = date, strata = day_type)
  counts <- make_test_counts()
  design <- add_counts(design, counts)

  # Estimate via tidycreel
  result <- estimate_effort(design)

  # Manual calculation with survey package
  svy_manual <- survey::svydesign(
    ids = ~date,
    strata = ~day_type,
    data = counts,
    nest = TRUE
  )
  manual_total <- survey::svytotal(~count, svy_manual)
  manual_se <- SE(manual_total)
  manual_ci <- confint(manual_total, level = 0.95)

  # Compare with tolerance (floating point arithmetic)
  expect_equal(result$estimates$estimate, as.numeric(coef(manual_total)), tolerance = 1e-10)
  expect_equal(result$estimates$se, as.numeric(manual_se), tolerance = 1e-10)
  expect_equal(result$estimates$ci_lower, manual_ci[1], tolerance = 1e-10)
  expect_equal(result$estimates$ci_upper, manual_ci[2], tolerance = 1e-10)
})

test_that("variance estimates match survey package calculations", {
  # TEST-07: Verify variance estimates
  design <- make_test_design_with_counts()

  result <- estimate_effort(design)

  # Manual variance calculation
  svy_manual <- survey::svydesign(
    ids = ~date,
    strata = ~day_type,
    data = design$counts,
    nest = TRUE
  )
  manual_total <- survey::svytotal(~count, svy_manual)
  manual_variance <- vcov(manual_total)[1, 1]

  # Variance is SE^2
  tidycreel_variance <- result$estimates$se^2

  expect_equal(tidycreel_variance, manual_variance, tolerance = 1e-10)
})
```

### Pattern 5: Grouped Estimation with svyby

**What:** Estimate totals/means for subgroups using `svyby()`

**When to use:** EST-07, EST-08 - grouped estimation via `by = ` parameter

**Example:**
```r
# Source: survey package svyby documentation
# https://r-survey.r-forge.r-project.org/survey/html/svyby.html

# Future enhancement for Phase 4 (or Phase 5)
estimate_effort <- function(design, formula = ~count, by = NULL, variance = "taylor", conf_level = 0.95) {
  svy_design <- design$survey

  if (is.null(by)) {
    # Total estimate (no grouping) - EST-06
    svy_result <- survey::svytotal(formula, svy_design)

    # Extract single row result
    estimates_df <- tibble::tibble(
      estimate = as.numeric(coef(svy_result)),
      se = as.numeric(SE(svy_result)),
      ci_lower = confint(svy_result, level = conf_level)[1],
      ci_upper = confint(svy_result, level = conf_level)[2],
      n = nrow(design$counts)
    )
  } else {
    # Grouped estimation - EST-07
    # Use svyby for domain estimation
    by_formula <- reformulate(by)
    svy_result <- survey::svyby(formula, by_formula, svy_design, survey::svytotal)

    # svyby returns data frame with groups and estimates
    # Extract and reshape into tidy format
    estimates_df <- tibble::tibble(
      group = svy_result[[by]],
      estimate = svy_result[[attr(svy_result, "svyby")$variables]],
      se = svy_result[[attr(svy_result, "svyby")$vartype]]
    )

    # Add confidence intervals (svyby doesn't include by default)
    # Calculate from SE: CI = estimate ± (z * SE)
    z <- qnorm(1 - (1 - conf_level) / 2)
    estimates_df$ci_lower <- estimates_df$estimate - z * estimates_df$se
    estimates_df$ci_upper <- estimates_df$estimate + z * estimates_df$se
    estimates_df$n <- NA  # Sample size per group requires separate calculation
  }

  # Return creel_estimates object
  new_creel_estimates(
    estimates = estimates_df,
    method = ifelse(is.null(by), "total", "total_by_group"),
    variance_method = variance,
    design = design,
    conf_level = conf_level
  )
}
```

### Anti-Patterns to Avoid

- **Manual variance calculations:** Don't reimplement Taylor linearization formulas - use survey package methods (handles edge cases)
- **Hardcoded confidence levels:** Don't assume 95% CI - accept `conf_level` parameter and pass to `confint()`
- **Ignoring variance method in results:** Always store `variance_method` in creel_estimates for reproducibility
- **Erroring on Tier 2 issues:** Sparse strata warnings should be informative, not blocking (users may have legitimate reasons)
- **Non-tidy result structure:** Don't return list of vectors - use tibble data frame for consistency with tidyverse ecosystem

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Taylor linearization variance | Custom derivative calculations | survey::svytotal with design object | Handles PSU nesting, stratification, FPC automatically |
| Confidence intervals | Manual t-distribution/z-score calculations | confint() method on survey results | Accounts for design degrees of freedom correctly |
| Bootstrap variance | Custom resampling loops | as.svrepdesign(type = "bootstrap") | Implements Rao-Wu-Yue-Beaumont method for complex designs |
| Jackknife variance | Custom leave-one-out variance | as.svrepdesign(type = "JK1" or "JKn") | Handles PSU deletion correctly, multiple jackknife variants |
| Domain (group) estimation | Subsetting and separate estimates | svyby() | Correctly estimates covariances between domains, handles empty groups |
| Sparse strata detection | Custom stratum counting logic | table() on .strata, check counts | Simple and reliable, works with interaction strata |

**Key insight:** Survey variance estimation has subtle dependencies on design structure (PSU nesting, stratification, finite population corrections). The survey package has 20+ years of edge-case handling. Don't reimplement.

## Common Pitfalls

### Pitfall 1: Assuming svytotal/svymean Return Simple Vectors

**What goes wrong:** Code like `result <- svytotal(~count, design); mean(result)` fails because `svytotal()` returns an S3 object of class `svystat`, not a simple numeric vector.

**Why it happens:**
- Intuition from `sum()` and `mean()` base R functions returning vectors
- Survey results are complex objects containing estimate + variance + design info
- Need to use S3 methods to extract components

**How to avoid:**
- **Always use accessor methods:** `coef()` for estimates, `SE()` for standard errors, `confint()` for CI, `vcov()` for variance-covariance matrix
- Pattern: `estimate <- as.numeric(coef(svy_result))`
- Don't use `svy_result[1]` or `svy_result$estimate` - these don't exist

**Warning signs:**
- Error: "$ operator is invalid for atomic vectors"
- Unexpected result types when trying to extract values
- Getting entire object structure when expecting numbers

**Implementation guidance:** Explicitly use `coef()`, `SE()`, `confint()` in estimate_effort(). Document in code comments that survey returns S3 objects, not vectors.

### Pitfall 2: Incorrect Confidence Interval Calculation for Replicate Weights

**What goes wrong:** Using normal distribution z-scores for confidence intervals when using replicate weights may underestimate variance for small samples.

**Why it happens:**
- `confint()` method on replicate weight designs uses appropriate method automatically
- Manual calculation with z-score (`qnorm()`) assumes large sample
- Replicate weights may have different degrees of freedom

**How to avoid:**
- **Always use `confint()` method** rather than manual CI calculation
- Let survey package handle degrees of freedom adjustments
- Only calculate CI manually if absolutely necessary (e.g., for custom statistics)

**Warning signs:**
- CIs narrower than expected for small samples
- CIs don't match survey package results

**Implementation guidance:** Use `confint(svy_result, level = conf_level)` in all variance methods. Don't assume normal distribution.

### Pitfall 3: Not Storing Variance Method in Results

**What goes wrong:** User runs `estimate_effort()`, gets results, but later can't reproduce because they don't remember which variance method was used.

**Why it happens:**
- Variance method affects results (bootstrap != Taylor for small samples)
- Default method may change between package versions
- EST-15 requires storing method for reproducibility

**How to avoid:**
- **Always store variance method** in creel_estimates attributes
- Include in print output so it's visible
- Document in result object even if it's just the default

**Warning signs:**
- User questions: "How did you calculate this?"
- Inability to reproduce results from saved R objects
- Confusion when comparing estimates from different methods

**Implementation guidance:** `variance_method` is a required argument to `new_creel_estimates()`. Always populate it. Display in `format.creel_estimates()`.

### Pitfall 4: Tier 2 Validation Blocking Valid Edge Cases

**What goes wrong:** Erroring on sparse strata prevents users from running preliminary analyses or exploring small datasets.

**Why it happens:**
- Sparse strata DO produce unreliable variance - tempting to error
- But users may legitimately want to see point estimates even with high uncertainty
- Power users may be doing simulation studies with deliberately small samples

**How to avoid:**
- **Warn, don't error** for Tier 2 validation (EST-13, EST-14)
- Educational messages: explain the problem and implications
- Trust users to make informed decisions
- Tier 1 (structural) errors vs Tier 2 (statistical quality) warnings

**Warning signs:**
- Users complaining they can't run estimation on exploratory data
- Feature requests for "allow_sparse" flags
- Package feels rigid/inflexible

**Implementation guidance:** Use `cli::cli_warn()` for Tier 2, reserve `cli::cli_abort()` for Tier 1. Document the distinction in function help.

### Pitfall 5: Forgetting Sample Size in Grouped Estimates

**What goes wrong:** `svyby()` returns estimates and SE for each group but doesn't include per-group sample sizes in standard output. Result objects missing `n` column.

**Why it happens:**
- `svyby()` focuses on estimates, not sample sizes
- Sample size per group requires separate calculation
- EST-05 requires including sample sizes in results

**How to avoid:**
- **Calculate group sample sizes separately**: `table(counts[[by_variable]])`
- Join sample sizes to `svyby()` results
- For total estimates (no grouping), sample size is `nrow(counts)`

**Warning signs:**
- Missing `n` column in grouped results
- Tests failing on result structure validation

**Implementation guidance:** Add explicit sample size calculation for both total and grouped estimates. Document that `n` represents sample size (number of PSUs), not population size.

## Code Examples

Verified patterns from research:

### Basic Total Estimation
```r
# Source: survey package surveysummary documentation
# https://r-survey.r-forge.r-project.org/survey/html/surveysummary.html

estimate_effort <- function(design, formula = ~count, variance = "taylor", conf_level = 0.95) {
  # Validate inputs
  if (!inherits(design, "creel_design")) {
    cli::cli_abort("{.arg design} must be a {.cls creel_design} object.")
  }

  if (is.null(design$survey)) {
    cli::cli_abort(c(
      "No survey design available.",
      "x" = "Call {.fn add_counts} before estimating effort."
    ))
  }

  # Tier 2 validation (warnings)
  warn_tier2_issues(design)

  # Get appropriate design for variance method
  svy_design <- get_design_for_variance(design, variance)

  # Compute total with survey package
  svy_result <- survey::svytotal(formula, svy_design)

  # Extract components with S3 methods
  estimate <- as.numeric(coef(svy_result))
  se <- as.numeric(SE(svy_result))
  ci <- confint(svy_result, level = conf_level)
  n <- nrow(design$counts)

  # Build tidy result
  estimates_df <- tibble::tibble(
    estimate = estimate,
    se = se,
    ci_lower = ci[1, 1],
    ci_upper = ci[1, 2],
    n = n
  )

  # Return creel_estimates S3 object
  new_creel_estimates(
    estimates = estimates_df,
    method = "total",
    variance_method = variance,
    design = design,
    conf_level = conf_level
  )
}
```

### Extracting Survey Result Components
```r
# Pattern for working with survey package results
# Source: survey package S3 methods

# svystat objects have specific S3 methods
svy_result <- survey::svytotal(~count, design$survey)

# Extract point estimate (coefficient)
estimate <- coef(svy_result)        # Returns named vector
estimate_num <- as.numeric(coef(svy_result))  # Numeric scalar

# Extract standard error
se <- SE(svy_result)                # Returns vector
se_num <- as.numeric(SE(svy_result))  # Numeric scalar

# Extract variance-covariance matrix
vcov_matrix <- vcov(svy_result)     # Returns matrix
variance <- vcov_matrix[1, 1]       # Extract variance

# Extract confidence interval
ci <- confint(svy_result, level = 0.95)  # Returns 2-column matrix
ci_lower <- ci[1, 1]  # Lower bound
ci_upper <- ci[1, 2]  # Upper bound

# Extract coefficient of variation
cv <- cv(svy_result)  # Returns CV (SE/estimate)
```

### Tier 2 Validation Implementation
```r
# Validation function for estimation-time quality checks
warn_tier2_issues <- function(design) {
  counts <- design$counts

  # EST-13: Zero/negative effort values
  # Pattern: any() with logical condition
  if (any(counts$count <= 0, na.rm = TRUE)) {
    n_zero <- sum(counts$count == 0, na.rm = TRUE)
    n_negative <- sum(counts$count < 0, na.rm = TRUE)

    # Use cli structured warnings
    cli::cli_warn(c(
      "Count data contains zero or negative values.",
      "!" = "Zero: {n_zero}, Negative: {n_negative}",
      "i" = "Effort estimates may be biased if these are data errors vs true zeros.",
      "i" = "Review these observations: investigate or filter before estimation."
    ))
  }

  # EST-14: Sparse strata (< 3 observations)
  # Use .strata variable created during survey construction
  if (".strata" %in% names(counts)) {
    strata_tbl <- table(counts$.strata)
    sparse <- strata_tbl[strata_tbl < 3]

    if (length(sparse) > 0) {
      cli::cli_warn(c(
        "Sparse strata detected ({length(sparse)} stratum/strata with < 3 observations).",
        "!" = "Few observations per stratum produce unreliable variance estimates.",
        "i" = "Consider combining strata, using different stratification, or collecting more data.",
        "i" = "Sparse strata: {paste(names(sparse), collapse = ', ')}"
      ))
    }
  }
}
```

### Reference Test with Tolerance
```r
# Source: testthat equality-expectations
# https://testthat.r-lib.org/reference/equality-expectations.html

test_that("estimate_effort produces same results as manual svytotal", {
  # Setup
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-08", "2024-06-09")),
    day_type = rep(c("weekday", "weekend"), each = 2)
  )
  counts <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-08", "2024-06-09")),
    day_type = rep(c("weekday", "weekend"), each = 2),
    count = c(15, 23, 45, 52)
  )

  # tidycreel workflow
  design <- creel_design(cal, date = date, strata = day_type)
  design <- add_counts(design, counts)
  result <- estimate_effort(design)

  # Manual survey package workflow
  svy_manual <- survey::svydesign(
    ids = ~date,
    strata = ~day_type,
    data = counts,
    nest = TRUE
  )
  manual_total <- survey::svytotal(~count, svy_manual)
  manual_se <- SE(manual_total)
  manual_ci <- confint(manual_total, level = 0.95)

  # Compare with tolerance (floating point requires tolerance)
  # Default tolerance is sqrt(.Machine$double.eps) ≈ 1.5e-8
  expect_equal(result$estimates$estimate, as.numeric(coef(manual_total)), tolerance = 1e-10)
  expect_equal(result$estimates$se, as.numeric(manual_se), tolerance = 1e-10)
  expect_equal(result$estimates$ci_lower, manual_ci[1, 1], tolerance = 1e-10)
  expect_equal(result$estimates$ci_upper, manual_ci[1, 2], tolerance = 1e-10)
})
```

### Variance Method Selection
```r
# Helper to select design based on variance method
get_design_for_variance <- function(design, variance_method) {
  # Source: survey package as.svrepdesign documentation
  # https://rdrr.io/rforge/survey/man/as.svrepdesign.html

  if (variance_method == "taylor") {
    # Default: use original survey.design2 object
    return(design$survey)
  }

  if (variance_method == "bootstrap") {
    # Convert to bootstrap replicate weights
    # Uses Rao-Wu-Yue-Beaumont bootstrap by default
    return(survey::as.svrepdesign(design$survey, type = "bootstrap"))
  }

  if (variance_method == "jackknife") {
    # Convert to jackknife replicate weights
    # JK1 removes one PSU at a time (delete-1 jackknife)
    return(survey::as.svrepdesign(design$survey, type = "JK1"))
  }

  # Unknown method
  cli::cli_abort(c(
    "Unknown variance method: {.val {variance_method}}",
    "i" = "Supported methods: {.val taylor}, {.val bootstrap}, {.val jackknife}"
  ))
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual variance formulas | survey package Taylor linearization | survey pkg 2004+ | Handles edge cases automatically |
| Base data.frame results | tibble with tidy format | broom pkg 2014+, widespread adoption 2020+ | Better printing, tidyverse integration |
| Hardcoded 95% CI | Parameterized conf_level | Modern API design | User flexibility, different confidence levels |
| Separate estimation functions | Unified estimate_effort with variance parameter | API design evolution | Cleaner interface, method stored in results |
| Manual t-distribution degrees of freedom | confint() method handles it | survey package S3 methods | Correct df for complex designs |

**Deprecated/outdated:**
- **as.svrepdesign type = "BRR":** Requires paired PSUs within strata (uncommon for creel surveys). Bootstrap and jackknife more general.
- **svyvar() for variance:** Use `vcov()` method on svytotal/svymean results instead - more general approach
- **Manual SE extraction from result objects:** Use `SE()` method, not `sqrt(vcov(result))`
- **expect_identical() for numeric tests:** testthat 3rd edition uses `expect_equal()` with tolerance for floating point comparisons

## Open Questions

### Question 1: Should estimate_effort() support grouped estimation (EST-07) in Phase 4 or defer to Phase 5?

**What we know:**
- Requirements list EST-07 (grouped estimation via `by = `) for Phase 4
- `svyby()` function exists and works well for domain estimation
- Adds complexity to first implementation
- Ungrouped total estimates (EST-06) are simpler and prove the architecture

**What's unclear:**
- Is grouped estimation essential for Phase 4 success criteria or "nice to have"?
- Does deferring to Phase 5 impact user testing/feedback?

**Recommendation:**
- **Phase 4 (Basic Estimation):** Implement total estimates only (EST-06, no grouping). Proves architecture, handles core requirements (EST-01 through EST-06, EST-10, EST-13-15).
- **Phase 5 (Grouped Estimation):** Add `by = ` parameter and `svyby()` support (EST-07, EST-08). Cleaner separation of concerns.
- Rationale: "Basic Estimation" suggests ungrouped totals. Grouped estimation is "Advanced Estimation" feature.

### Question 2: How should variance method parameter be exposed - string vs enum?

**What we know:**
- Three variance methods needed: taylor, bootstrap, jackknife (EST-10, EST-11, EST-12)
- String parameter (`variance = "taylor"`) is R-idiomatic
- Could use match.arg() for validation
- survey package uses `type = ` with strings

**What's unclear:**
- Should we define a constant (e.g., `VARIANCE_TAYLOR <- "taylor"`) or accept strings directly?
- Trade-off: autocomplete vs simplicity

**Recommendation:**
- **Use strings with match.arg():** `variance = match.arg(variance, c("taylor", "bootstrap", "jackknife"))`
- R-idiomatic, clear error messages, simple documentation
- Example from survey package: `as.svrepdesign(type = "bootstrap")` uses strings

### Question 3: Should Tier 2 warnings be suppressible via option or parameter?

**What we know:**
- Tier 2 warnings educate users about data quality (EST-13, EST-14)
- Power users may run many estimates and want to suppress repetitive warnings
- Standard R: `suppressWarnings()` works but suppresses ALL warnings
- Could add `quiet = FALSE` parameter or global option

**What's unclear:**
- Is a suppression mechanism needed in Phase 4 or wait for user feedback?
- Package-level option vs function parameter?

**Recommendation:**
- **Phase 4:** No suppression mechanism - users can use `suppressWarnings()`
- **Phase 5 (if needed):** Add `quiet = FALSE` parameter to `estimate_effort()` if users request it
- Rationale: Keep Phase 4 simple. Warnings are valuable for learning users. Wait for user feedback before adding suppression.

### Question 4: How to handle formulas - hardcoded ~count or allow user-specified formulas?

**What we know:**
- Creel surveys typically estimate effort from count variable
- survey package uses formulas: `svytotal(~count, design)`
- Future phases may need catch estimation: `svytotal(~catch, design)`
- Formula interface is flexible but adds complexity

**What's unclear:**
- Should Phase 4 accept `formula = ~count` parameter or hardcode to `~count`?
- What's the right abstraction for "estimate this variable"?

**Recommendation:**
- **Phase 4:** Hardcode to `~count` for simplicity - `estimate_effort(design)` with no formula parameter
- **Phase 5:** Add flexible formula support - `estimate_effort(design, formula = ~catch)` or variable name approach
- Rationale: Basic Estimation = effort from counts. Formula flexibility is an advanced feature. Defer until catch estimation is needed.

## Sources

### Primary (HIGH confidence)
- [Package 'survey' August 28, 2025](https://cran.r-project.org/web/packages/survey/survey.pdf) - Official CRAN package documentation
- [R: Summary statistics for sample surveys](https://r-survey.r-forge.r-project.org/survey/html/surveysummary.html) - Official svytotal/svymean documentation
- [R: Survey statistics on subsets](https://r-survey.r-forge.r-project.org/survey/html/svyby.html) - Official svyby documentation for grouped estimation
- [as.svrepdesign: Convert to replicate weights](https://rdrr.io/rforge/survey/man/as.svrepdesign.html) - Official documentation for bootstrap/jackknife
- [testthat Package January 11, 2026](https://cran.r-project.org/web/packages/testthat/testthat.pdf) - Official testthat documentation
- [testthat equality-expectations](https://testthat.r-lib.org/reference/equality-expectations.html) - expect_equal tolerance documentation
- [Introduction to broom](https://cran.r-project.org/web/packages/broom/vignettes/broom.html) - Tidy statistical object patterns
- [broom Package January 27, 2026](https://broom.tidymodels.org/) - Current broom package documentation

### Secondary (MEDIUM confidence)
- [Estimates in subpopulations - Thomas Lumley August 28, 2025](https://cran.r-project.org/web/packages/survey/vignettes/domain.pdf) - Official vignette on domain estimation with svyby
- [Survey Data Analysis with R - UCLA](https://stats.oarc.ucla.edu/r/seminars/survey-data-analysis-with-r/) - Educational materials on survey package usage
- [Introduction to Regression Methods for Public Health Using R - Survey](https://www.bookdown.org/rwnahhas/RMPH/survey-desc.html) - Weighted descriptive statistics patterns
- [Bootstrap Methods for Surveys - svrep package](https://cran.r-project.org/web/packages/svrep/vignettes/bootstrap-replicates.html) - Bootstrap variance estimation details
- [Sample Size Estimation for On-Site Creel Surveys - McCormick 2017](https://afspubs.onlinelibrary.wiley.com/doi/full/10.1080/02755947.2017.1342723) - Creel survey stratification and variance
- [13 S3 | Advanced R - Hadley Wickham](https://adv-r.hadley.nz/s3.html) - S3 class design patterns

### Tertiary (LOW confidence - domain background)
- [The Mechanics of Onsite Creel Surveys in Alaska](https://www.adfg.alaska.gov/fedaidpdfs/sp98-01.pdf) - Creel survey design patterns and variance
- [Simulating Creel Surveys](https://cran.r-project.org/web/packages/AnglerCreelSurveySimulation/vignettes/creel_survey_simulation.html) - Creel survey structures and estimation

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - survey package is established (20+ years), all dependencies already in DESCRIPTION from Phase 1-3
- Architecture: HIGH - S3 patterns from Advanced R, survey package S3 methods documented, testthat tolerance patterns verified
- Estimation patterns: HIGH - svytotal/svymean extraction methods verified from official docs, coef/SE/confint methods standard
- Variance methods: HIGH - as.svrepdesign documented with type parameter, Taylor linearization is default and well-established
- Testing patterns: HIGH - testthat tolerance approach verified from official docs, reference testing is standard practice
- Tier 2 validation: MEDIUM - sparse strata threshold (< 3) is judgment call, not hard requirement from survey theory
- Grouped estimation: MEDIUM - svyby() documented but not verified in practice for this phase (recommended for Phase 5)

**Research date:** 2026-02-08
**Valid until:** ~60 days (survey package is stable; R patterns are stable; testthat is stable)

**Key gaps filled:**
- Verified survey package S3 methods (coef, SE, confint, vcov) for extracting results
- Confirmed as.svrepdesign type parameter for bootstrap/jackknife variance methods
- Documented pattern for Tier 2 validation (warnings vs errors for statistical quality)
- Established reference testing approach with testthat tolerance for numeric comparisons
- Clarified difference between total estimation (EST-06) and grouped estimation (EST-07) - recommend phasing
- Confirmed tidy result structure following broom package patterns
- Verified existing creel_estimates S3 class needs expansion for estimate_effort() integration

**Implementation readiness:** HIGH - All core patterns documented, existing Phase 3 infrastructure provides survey design objects, creel_estimates class exists and ready for use, test patterns established, survey package methods well-documented with examples
