# Implementation Plan: Roving/Incomplete Trip Estimators
## Pollock et al. (1997) Methods for tidycreel

**Created:** 2025-10-24
**Priority:** P0 (Highest - Critical Gap)
**Estimated Effort:** 2-3 weeks
**Target Sprint:** Sprint 1-2

---

## Executive Summary

This plan implements **roving creel survey estimators** based on Pollock et al. (1997) methods for incomplete trip interviews. While `tidycreel` has basic incomplete trip handling in `est_cpue()`, it lacks the specialized statistical methods and corrections needed for proper roving survey analysis.

**Key Additions:**
1. Length-biased sampling correction (longer trips more likely intercepted)
2. Pollock et al. (1997) mean-of-ratios variance formulas
3. Trip truncation framework (< 0.5 hours)
4. Roving-specific CPUE estimation function
5. Integration with existing survey-first architecture

---

## Current State Analysis

### What We Have ✅

**File:** `R/est-cpue.R` (lines 1-150)

```r
est_cpue(
  design,
  by = NULL,
  response = c("catch_total", "catch_kept", "weight_total"),
  effort_col = "hours_fished",
  mode = c("auto", "ratio_of_means", "mean_of_ratios"),
  min_trip_hours = 0.5,  # Basic truncation
  conf_level = 0.95
)
```

**Existing Capabilities:**
- Auto-detection of trip completion status via `trip_complete` field
- Basic trip truncation (`min_trip_hours = 0.5`)
- Hybrid estimator combining complete and incomplete trips
- `ratio_of_means` for incomplete trips (via `survey::svyratio`)
- `mean_of_ratios` for complete trips (via `survey::svymean`)

**Limitations:**
- No length-biased sampling correction
- Generic variance formulas (not Pollock et al. specific)
- No roving-specific diagnostics
- Missing specialized interview type handling
- No integration with effort estimation for roving designs

---

## Gap Analysis: What's Missing

### Critical Gaps 🔴

1. **Length-Biased Sampling Correction**
   - Longer fishing trips have higher probability of being intercepted
   - Uncorrected estimates are **biased upward**
   - Pollock et al. (1997) provides correction formulas

2. **Pollock et al. (1997) Variance Formulas**
   - Current: Generic survey package variance
   - Needed: Roving-specific variance accounting for length-bias

3. **Interview Type Handling**
   - Access-point (complete): Different estimator
   - Roving (incomplete): Different estimator
   - Current implementation doesn't explicitly distinguish survey type

4. **Trip Completion Status Validation**
   - Current: Relies on user-provided `trip_complete` field
   - Needed: Validation logic and warnings

### Important Gaps 🟡

5. **Roving Effort Integration**
   - Roving surveys estimate effort differently than access-point
   - Need to link CPUE estimation with roving effort methods

6. **Diagnostic Information**
   - Bias correction factors
   - Effective sample sizes
   - Trip length distributions

---

## Implementation Specification

### Phase 1: Core Function - `est_cpue_roving()` ✨

**New File:** `R/est-cpue-roving.R` (~400 lines)

#### Function Signature

```r
#' Estimate CPUE for Roving Creel Surveys (Pollock et al. 1997)
#'
#' Design-based CPUE estimation for roving (incomplete trip) interviews with
#' length-biased sampling correction. Uses Pollock et al. (1997) methods
#' specifically designed for roving surveys where anglers are intercepted
#' during their fishing trips.
#'
#' @param design A `svydesign`/`svrepdesign` built on interview data with
#'   incomplete trips (roving surveys).
#' @param by Character vector of grouping variables (e.g., `c("location", "species")`).
#' @param response One of `"catch_total"`, `"catch_kept"`, `"catch_released"`.
#' @param effort_col Interview effort column (default `"hours_fished"`).
#'   For incomplete trips, this is **observed effort at time of interview**.
#' @param min_trip_hours Minimum trip duration for inclusion. Trips shorter
#'   than this threshold are excluded to avoid unstable ratios. Default 0.5
#'   hours (Hoenig et al. 1997 recommendation).
#' @param length_bias_correction Apply length-biased sampling correction
#'   (Pollock et al. 1997). Options:
#'   - `"none"`: No correction (assumes complete trips or no length bias)
#'   - `"pollock"`: Pollock et al. (1997) correction (recommended for roving)
#'   - `"simple_ratio"`: Simple ratio correction (alternative method)
#' @param total_trip_effort_col Column containing **total planned trip effort**
#'   (only needed if `length_bias_correction != "none"`). For incomplete trips,
#'   this is the angler's stated total planned fishing time.
#' @param conf_level Confidence level for confidence intervals (default 0.95).
#' @param diagnostics Include diagnostic information in output (default `TRUE`).
#'
#' @return Tibble with standard tidycreel schema:
#'   - Grouping columns (from `by` parameter)
#'   - `estimate`: CPUE estimate (catch per unit effort)
#'   - `se`: Standard error
#'   - `ci_low`, `ci_high`: Confidence interval bounds
#'   - `n`: Sample size (after truncation)
#'   - `method`: Method identifier
#'   - `diagnostics`: List-column with diagnostic information
#'
#' @details
#' ## Statistical Method
#'
#' Roving surveys interview anglers **during their trips**, creating two issues:
#' 1. **Incomplete catch data** - Trip not yet finished
#' 2. **Length-biased sampling** - Longer trips more likely intercepted
#'
#' ### Mean-of-Ratios Estimator (Pollock et al. 1997)
#'
#' For each interview \eqn{i}, calculate individual catch rate:
#' \deqn{r_i = \frac{c_i}{e_i}}
#'
#' where:
#' - \eqn{c_i} = catch at time of interview
#' - \eqn{e_i} = effort at time of interview
#'
#' Mean catch rate:
#' \deqn{\bar{r} = \frac{1}{n} \sum_{i=1}^n r_i}
#'
#' Variance (mean-of-ratios):
#' \deqn{Var(\bar{r}) = \frac{1}{n(n-1)} \sum_{i=1}^n (r_i - \bar{r})^2}
#'
#' ### Length-Biased Sampling Correction
#'
#' When `length_bias_correction = "pollock"`:
#'
#' Correction factor for each observation:
#' \deqn{w_i = \frac{1}{T_i}}
#'
#' where \eqn{T_i} is total planned trip duration.
#'
#' Corrected estimator:
#' \deqn{\bar{r}_{corrected} = \frac{\sum_{i=1}^n w_i r_i}{\sum_{i=1}^n w_i}}
#'
#' ## When to Use This Function
#'
#' **Use `est_cpue_roving()` when:**
#' - Conducting roving (on-water, circuit) surveys
#' - Interviewing anglers **during their trips** (incomplete)
#' - Trip completion times unknown at interview
#' - Need length-bias correction for accurate estimates
#'
#' **Use `est_cpue()` instead when:**
#' - Access-point interviews with **completed trips**
#' - Trip duration and catch fully observed
#' - No length-biased sampling concerns
#'
#' @examples
#' \dontrun{
#' library(tidycreel)
#' library(survey)
#'
#' # Roving survey data (incomplete trips)
#' data(roving_interviews)  # hours_fished = observed so far, catch_kept = current
#'
#' # Create survey design
#' svy_roving <- svydesign(
#'   ids = ~1,
#'   strata = ~location,
#'   data = roving_interviews
#' )
#'
#' # Estimate CPUE with Pollock correction (requires total_trip_effort)
#' cpue_roving <- est_cpue_roving(
#'   design = svy_roving,
#'   by = c("location", "species"),
#'   response = "catch_kept",
#'   effort_col = "hours_fished",
#'   total_trip_effort_col = "planned_hours",  # Stated total trip duration
#'   length_bias_correction = "pollock",
#'   min_trip_hours = 0.5
#' )
#'
#' # Without length-bias correction (assumes no bias or complete trips)
#' cpue_simple <- est_cpue_roving(
#'   design = svy_roving,
#'   by = "location",
#'   response = "catch_total",
#'   length_bias_correction = "none"
#' )
#' }
#'
#' @references
#' Pollock, K.H., C.M. Jones, and T.L. Brown. 1994. Angler Survey Methods
#'   and Their Applications in Fisheries Management. American Fisheries
#'   Society Special Publication 25. Bethesda, Maryland.
#'
#' Hoenig, J.M., C.M. Jones, K.H. Pollock, D.S. Robson, and D.L. Wade. 1997.
#'   Calculation of catch rate and total catch in roving and access point
#'   surveys. Biometrics 53:306-317.
#'
#' @seealso
#' [est_cpue()], [est_effort()], [aggregate_cpue()]
#'
#' @export
est_cpue_roving <- function(
  design,
  by = NULL,
  response = c("catch_total", "catch_kept", "catch_released"),
  effort_col = "hours_fished",
  min_trip_hours = 0.5,
  length_bias_correction = c("pollock", "none", "simple_ratio"),
  total_trip_effort_col = NULL,
  conf_level = 0.95,
  diagnostics = TRUE
) {
  # Implementation in Phase 1
}
```

#### Implementation Steps

**Step 1.1: Input Validation** (~50 lines)
- Validate `design` is survey object
- Check required columns exist
- Validate `length_bias_correction` parameter
- If correction requested, require `total_trip_effort_col`
- Validate `min_trip_hours > 0`
- Check grouping variables exist

**Step 1.2: Trip Truncation** (~40 lines)
- Filter trips with `effort_col < min_trip_hours`
- Count and report truncated trips
- Subset survey design to valid trips only
- Issue warning if >10% truncated

**Step 1.3: Calculate Individual Catch Rates** (~60 lines)
```r
# For each interview, compute r_i = catch_i / effort_i
vars <- design$variables
vars$.catch_rate <- vars[[response]] / vars[[effort_col]]

# Handle Inf/NaN (zero effort after truncation)
vars$.catch_rate[!is.finite(vars$.catch_rate)] <- NA_real_

# Update design with catch rate variable
design_updated <- update(design, .catch_rate = vars$.catch_rate)
```

**Step 1.4: Length-Bias Correction** (~80 lines)

```r
if (length_bias_correction == "pollock") {
  # Require total trip effort column
  if (is.null(total_trip_effort_col)) {
    cli::cli_abort(c(
      "x" = "Length-bias correction requires {.arg total_trip_effort_col}.",
      "i" = "This should contain anglers' stated total planned trip duration.",
      ">" = "Use {.code total_trip_effort_col = 'planned_hours'} or similar."
    ))
  }

  # Calculate weights: w_i = 1 / T_i
  total_effort <- vars[[total_trip_effort_col]]

  # Validate: total_effort must be >= observed effort
  invalid <- total_effort < vars[[effort_col]]
  if (any(invalid, na.rm = TRUE)) {
    cli::cli_warn(c(
      "!" = "{sum(invalid, na.rm = TRUE)} interview{?s} have total planned effort < observed effort.",
      "i" = "This is illogical - setting to observed effort."
    ))
    total_effort[invalid] <- vars[[effort_col]][invalid]
  }

  weights <- 1 / total_effort
  weights[!is.finite(weights)] <- 0

  # Update design with correction weights
  design_updated <- update(design_updated, .length_bias_weights = weights)

} else {
  # No correction - equal weights
  design_updated <- update(design_updated, .length_bias_weights = 1)
}
```

**Step 1.5: Grouped or Ungrouped Estimation** (~100 lines)

```r
if (length(by) > 0) {
  # Grouped estimation
  by_formula <- as.formula(paste("~", paste(by, collapse = "+")))

  if (length_bias_correction != "none") {
    # Weighted mean of catch rates
    est <- survey::svyby(
      ~.catch_rate,
      by = by_formula,
      design = design_updated,
      FUN = survey::svymean,
      na.rm = TRUE,
      # Apply length-bias weights
      weights = ~.length_bias_weights
    )
  } else {
    # Unweighted mean of catch rates
    est <- survey::svyby(
      ~.catch_rate,
      by = by_formula,
      design = design_updated,
      FUN = survey::svymean,
      na.rm = TRUE
    )
  }

  # Extract estimates and standard errors
  out <- as_tibble(est)
  names(out)[names(out) == ".catch_rate"] <- "estimate"
  out$se <- SE(est)

} else {
  # Ungrouped estimation
  if (length_bias_correction != "none") {
    est <- survey::svymean(~.catch_rate, design_updated, na.rm = TRUE,
                           weights = ~.length_bias_weights)
  } else {
    est <- survey::svymean(~.catch_rate, design_updated, na.rm = TRUE)
  }

  out <- tibble(
    estimate = as.numeric(coef(est)),
    se = as.numeric(SE(est))
  )
}
```

**Step 1.6: Confidence Intervals** (~20 lines)
```r
z <- qnorm(1 - (1 - conf_level) / 2)
out$ci_low <- out$estimate - z * out$se
out$ci_high <- out$estimate + z * out$se
```

**Step 1.7: Sample Sizes** (~30 lines)
```r
# Sample size by group (after truncation)
if (length(by) > 0) {
  n_by <- vars |>
    filter(!is.na(.catch_rate)) |>
    group_by(across(all_of(by))) |>
    summarise(n = n(), .groups = "drop")
  out <- left_join(out, n_by, by = by)
} else {
  out$n <- sum(!is.na(vars$.catch_rate))
}
```

**Step 1.8: Method Label** (~10 lines)
```r
method_str <- paste0(
  "cpue_roving:mean_of_ratios:",
  response,
  ":",
  length_bias_correction
)
out$method <- method_str
```

**Step 1.9: Diagnostics** (~60 lines)
```r
if (diagnostics) {
  diag_list <- vector("list", nrow(out))

  for (i in seq_len(nrow(out))) {
    # Calculate group-specific diagnostics
    if (length(by) > 0) {
      group_filter <- out[i, by]
      group_data <- vars
      for (col in by) {
        group_data <- group_data[group_data[[col]] == group_filter[[col]], ]
      }
    } else {
      group_data <- vars
    }

    diag_list[[i]] <- list(
      n_original = nrow(group_data),
      n_truncated = sum(group_data[[effort_col]] < min_trip_hours, na.rm = TRUE),
      n_used = sum(!is.na(group_data$.catch_rate)),
      truncation_rate = mean(group_data[[effort_col]] < min_trip_hours, na.rm = TRUE),
      mean_effort_observed = mean(group_data[[effort_col]], na.rm = TRUE),
      sd_effort_observed = sd(group_data[[effort_col]], na.rm = TRUE),
      length_bias_correction = length_bias_correction,
      correction_applied = length_bias_correction != "none"
    )

    if (length_bias_correction != "none" && !is.null(total_trip_effort_col)) {
      diag_list[[i]]$mean_total_effort = mean(group_data[[total_trip_effort_col]], na.rm = TRUE)
      diag_list[[i]]$mean_bias_weight = mean(1 / group_data[[total_trip_effort_col]], na.rm = TRUE)
    }
  }

  out$diagnostics <- diag_list
} else {
  out$diagnostics <- replicate(nrow(out), list(NULL), simplify = FALSE)
}
```

**Step 1.10: Return Tidy Schema** (~10 lines)
```r
# Standard column order
result_cols <- c(
  if (length(by) > 0) by else character(0),
  "estimate", "se", "ci_low", "ci_high", "n", "method", "diagnostics"
)

select(out, all_of(intersect(result_cols, names(out))))
```

---

### Phase 2: Testing - `tests/testthat/test-est-cpue-roving.R` 📋

**New File:** `tests/testthat/test-est-cpue-roving.R` (~500 lines)

#### Test Coverage Plan

**Test Suite 1: Input Validation** (~100 lines, 8 tests)
```r
test_that("est_cpue_roving validates design object", {
  expect_error(est_cpue_roving(design = list()), "survey")
})

test_that("est_cpue_roving requires response column", {
  svy <- svydesign(ids = ~1, data = tibble(hours_fished = 1:10))
  expect_error(est_cpue_roving(svy, response = "catch_kept"), "catch_kept")
})

test_that("est_cpue_roving requires effort column", {
  svy <- svydesign(ids = ~1, data = tibble(catch_kept = 1:10))
  expect_error(est_cpue_roving(svy, effort_col = "hours_fished"), "hours_fished")
})

test_that("est_cpue_roving validates length_bias_correction parameter", {
  svy <- svydesign(ids = ~1, data = tibble(catch_kept = 1:10, hours_fished = 1:10))
  expect_error(est_cpue_roving(svy, length_bias_correction = "invalid"), "should be one of")
})

test_that("est_cpue_roving requires total_trip_effort_col when correction requested", {
  svy <- svydesign(ids = ~1, data = tibble(catch_kept = 1:10, hours_fished = 1:10))
  expect_error(
    est_cpue_roving(svy, length_bias_correction = "pollock"),
    "total_trip_effort_col"
  )
})

test_that("est_cpue_roving validates min_trip_hours > 0", {
  svy <- svydesign(ids = ~1, data = tibble(catch_kept = 1:10, hours_fished = 1:10))
  expect_error(est_cpue_roving(svy, min_trip_hours = -1), "> 0")
})

test_that("est_cpue_roving validates grouping variables exist", {
  svy <- svydesign(ids = ~1, data = tibble(catch_kept = 1:10, hours_fished = 1:10))
  expect_error(est_cpue_roving(svy, by = "location"), "location")
})

test_that("est_cpue_roving validates conf_level in (0, 1)", {
  svy <- svydesign(ids = ~1, data = tibble(catch_kept = 1:10, hours_fished = 1:10))
  expect_error(est_cpue_roving(svy, conf_level = 1.5), "0.*1")
})
```

**Test Suite 2: Trip Truncation** (~80 lines, 6 tests)
```r
test_that("est_cpue_roving truncates short trips", {
  data <- tibble(
    catch_kept = c(0, 1, 2, 3, 4),
    hours_fished = c(0.1, 0.3, 0.6, 1.0, 2.0)  # First 2 should be truncated
  )
  svy <- svydesign(ids = ~1, data = data)

  result <- est_cpue_roving(svy, response = "catch_kept", min_trip_hours = 0.5,
                            length_bias_correction = "none")

  # Should use only last 3 observations
  expect_equal(result$n, 3)
})

test_that("est_cpue_roving warns when >10% truncated", {
  data <- tibble(
    catch_kept = 1:20,
    hours_fished = c(rep(0.2, 5), rep(1.0, 15))  # 25% short trips
  )
  svy <- svydesign(ids = ~1, data = data)

  expect_warning(
    est_cpue_roving(svy, min_trip_hours = 0.5, length_bias_correction = "none"),
    "truncated"
  )
})

test_that("est_cpue_roving handles all trips below threshold", {
  data <- tibble(catch_kept = 1:10, hours_fished = rep(0.2, 10))
  svy <- svydesign(ids = ~1, data = data)

  expect_error(
    est_cpue_roving(svy, min_trip_hours = 0.5, length_bias_correction = "none"),
    "No valid"
  )
})

# ... more truncation tests
```

**Test Suite 3: Known Value Calculations** (~120 lines, 10 tests)
```r
test_that("est_cpue_roving calculates correct mean-of-ratios without correction", {
  # Known data
  data <- tibble(
    catch_kept = c(2, 4, 6),
    hours_fished = c(1, 2, 3)
  )
  # Individual rates: 2/1=2, 4/2=2, 6/3=2
  # Mean rate: (2+2+2)/3 = 2

  svy <- svydesign(ids = ~1, data = data)
  result <- est_cpue_roving(svy, response = "catch_kept",
                            length_bias_correction = "none")

  expect_equal(result$estimate, 2.0, tolerance = 1e-6)
})

test_that("est_cpue_roving applies Pollock correction correctly", {
  # Known data with length bias
  data <- tibble(
    catch_kept = c(4, 6, 8),
    hours_fished = c(2, 3, 4),  # Observed effort
    planned_hours = c(4, 6, 8)  # Total planned (2x observed)
  )
  # Rates: 4/2=2, 6/3=2, 8/4=2
  # Weights: 1/4=0.25, 1/6≈0.167, 1/8=0.125
  # Weighted mean: (2*0.25 + 2*0.167 + 2*0.125) / (0.25+0.167+0.125)

  svy <- svydesign(ids = ~1, data = data)
  result <- est_cpue_roving(
    svy,
    response = "catch_kept",
    total_trip_effort_col = "planned_hours",
    length_bias_correction = "pollock"
  )

  # Should still be 2.0 since rates are constant (but variance differs)
  expect_equal(result$estimate, 2.0, tolerance = 1e-6)
})

# Test with actual bias
test_that("est_cpue_roving correction reduces bias from long trips", {
  # Simulate length bias: longer trips have higher catch rates
  data <- tibble(
    catch_kept = c(1, 2, 3, 4, 5),  # Increasing catch
    hours_fished = c(1, 2, 3, 4, 5),  # Proportional to duration
    planned_hours = c(1, 2, 3, 4, 5) * 2  # All trips sampled at midpoint
  )
  # Rates: all 1.0, so no bias in this case
  # But weights down-weight longer trips

  svy <- svydesign(ids = ~1, data = data)

  result_uncorrected <- est_cpue_roving(svy, length_bias_correction = "none")
  result_corrected <- est_cpue_roving(
    svy,
    total_trip_effort_col = "planned_hours",
    length_bias_correction = "pollock"
  )

  # Both should be close to 1.0 here
  expect_equal(result_uncorrected$estimate, 1.0, tolerance = 1e-6)
  expect_equal(result_corrected$estimate, 1.0, tolerance = 1e-6)
})

# ... more known value tests with realistic bias scenarios
```

**Test Suite 4: Grouped Estimation** (~100 lines, 8 tests)
```r
test_that("est_cpue_roving handles grouped data correctly", {
  data <- tibble(
    location = rep(c("A", "B"), each = 5),
    catch_kept = c(1, 2, 3, 4, 5, 2, 4, 6, 8, 10),
    hours_fished = c(1, 1, 1, 1, 1, 2, 2, 2, 2, 2)
  )

  svy <- svydesign(ids = ~1, data = data)
  result <- est_cpue_roving(svy, by = "location", length_bias_correction = "none")

  expect_equal(nrow(result), 2)
  expect_equal(result$location, c("A", "B"))

  # Location A: mean(1/1, 2/1, 3/1, 4/1, 5/1) = 3
  # Location B: mean(2/2, 4/2, 6/2, 8/2, 10/2) = 3
  expect_equal(result$estimate[result$location == "A"], 3.0, tolerance = 1e-6)
  expect_equal(result$estimate[result$location == "B"], 3.0, tolerance = 1e-6)
})

# Test multiple grouping variables
test_that("est_cpue_roving handles multiple grouping variables", {
  data <- expand_grid(
    location = c("A", "B"),
    species = c("bass", "trout")
  ) |>
    mutate(
      catch_kept = rep(1:4, each = 1),
      hours_fished = 1
    )

  svy <- svydesign(ids = ~1, data = data)
  result <- est_cpue_roving(svy, by = c("location", "species"),
                            length_bias_correction = "none")

  expect_equal(nrow(result), 4)
  expect_true(all(c("location", "species") %in% names(result)))
})

# ... more grouped tests
```

**Test Suite 5: Edge Cases** (~80 lines, 6 tests)
```r
test_that("est_cpue_roving handles zero catches", {
  data <- tibble(catch_kept = rep(0, 10), hours_fished = rep(2, 10))
  svy <- svydesign(ids = ~1, data = data)

  result <- est_cpue_roving(svy, length_bias_correction = "none")

  expect_equal(result$estimate, 0.0)
  expect_true(result$se >= 0)
})

test_that("est_cpue_roving handles all NA catches", {
  data <- tibble(catch_kept = rep(NA_real_, 10), hours_fished = 1:10)
  svy <- svydesign(ids = ~1, data = data)

  result <- est_cpue_roving(svy, length_bias_correction = "none")

  expect_true(is.na(result$estimate))
})

test_that("est_cpue_roving handles single observation", {
  data <- tibble(catch_kept = 5, hours_fished = 2)
  svy <- svydesign(ids = ~1, data = data)

  result <- est_cpue_roving(svy, length_bias_correction = "none")

  expect_equal(result$estimate, 2.5)
  expect_equal(result$n, 1)
})

# ... more edge case tests
```

**Test Suite 6: Diagnostics** (~60 lines, 5 tests)
```r
test_that("est_cpue_roving includes diagnostics when requested", {
  data <- tibble(catch_kept = 1:10, hours_fished = rep(1, 10))
  svy <- svydesign(ids = ~1, data = data)

  result <- est_cpue_roving(svy, diagnostics = TRUE, length_bias_correction = "none")

  expect_true("diagnostics" %in% names(result))
  expect_true(is.list(result$diagnostics))
  expect_true(length(result$diagnostics) == 1)

  diag <- result$diagnostics[[1]]
  expect_true(!is.null(diag$n_original))
  expect_true(!is.null(diag$n_truncated))
  expect_true(!is.null(diag$n_used))
})

test_that("est_cpue_roving diagnostics includes correction info when applied", {
  data <- tibble(
    catch_kept = 1:10,
    hours_fished = 1:10,
    planned_hours = (1:10) * 2
  )
  svy <- svydesign(ids = ~1, data = data)

  result <- est_cpue_roving(
    svy,
    total_trip_effort_col = "planned_hours",
    length_bias_correction = "pollock",
    diagnostics = TRUE
  )

  diag <- result$diagnostics[[1]]
  expect_equal(diag$length_bias_correction, "pollock")
  expect_true(diag$correction_applied)
  expect_true(!is.null(diag$mean_total_effort))
  expect_true(!is.null(diag$mean_bias_weight))
})

# ... more diagnostic tests
```

**Test Suite 7: Integration with Survey Package** (~60 lines, 5 tests)
```r
test_that("est_cpue_roving works with stratified designs", {
  data <- tibble(
    catch_kept = 1:20,
    hours_fished = rep(c(1, 2), 10),
    stratum = rep(c("weekday", "weekend"), each = 10)
  )

  svy <- svydesign(ids = ~1, strata = ~stratum, data = data)

  result <- est_cpue_roving(svy, length_bias_correction = "none")

  expect_true(!is.na(result$estimate))
  expect_true(!is.na(result$se))
})

test_that("est_cpue_roving works with replicate designs", {
  data <- tibble(
    catch_kept = 1:20,
    hours_fished = rep(2, 20)
  )

  svy_simple <- svydesign(ids = ~1, data = data)
  svy_rep <- as.svrepdesign(svy_simple, type = "bootstrap", replicates = 50)

  result <- est_cpue_roving(svy_rep, length_bias_correction = "none")

  expect_true(!is.na(result$estimate))
  expect_true(!is.na(result$se))
})

# ... more integration tests
```

---

### Phase 3: Documentation & Vignette ✍️

**File:** `vignettes/roving-surveys.Rmd` (~800 lines)

#### Vignette Structure

```r
---
title: "Roving Creel Surveys: Incomplete Trip Analysis"
output: rmarkdown::html_vignette
vignette: >
  %\VignetteIndexEntry{Roving Creel Surveys: Incomplete Trip Analysis}
  %\VignetteEngine{knitr::rmarkdown}
  %\VignetteEncoding{UTF-8}
---
```

**Section 1: Introduction** (~100 lines)
- What are roving surveys?
- When to use them
- Statistical challenges (incomplete trips, length bias)
- Overview of Pollock et al. methods

**Section 2: Simulated Example Data** (~150 lines)
```r
# Simulate realistic roving survey data
library(tidycreel)
library(survey)
library(dplyr)

# Setup
set.seed(2025)
n_interviews <- 200

# Simulate true fishing behavior
roving_data <- tibble(
  interview_id = 1:n_interviews,
  location = sample(c("Lake A", "Lake B", "Lake C"), n_interviews, replace = TRUE),

  # True total trip duration (angler's plan)
  true_trip_hours = rexp(n_interviews, rate = 1/4) + 0.5,  # Mean ~4.5 hours

  # Interview occurs at random point during trip
  interview_time = runif(n_interviews, 0, 1) * true_trip_hours,

  # Observed effort at interview (partial)
  hours_fished = interview_time,

  # Angler states planned total (might not equal true)
  planned_hours = true_trip_hours * runif(n_interviews, 0.9, 1.1),

  # Catch accumulates over time (Poisson rate = 0.5 fish/hour)
  catch_rate_true = 0.5,
  catch_kept = rpois(n_interviews, lambda = catch_rate_true * hours_fished),
  catch_released = rpois(n_interviews, lambda = catch_rate_true * 0.3 * hours_fished)
) |>
  mutate(
    catch_total = catch_kept + catch_released,
    trip_complete = FALSE  # All roving interviews are incomplete
  )

# Add species composition
roving_data <- roving_data |>
  rowwise() |>
  mutate(
    species = sample(
      c("bass", "trout", "panfish"),
      size = 1,
      prob = c(0.5, 0.3, 0.2)
    )
  ) |>
  ungroup()
```

**Section 3: Basic CPUE Estimation** (~150 lines)
```r
# Create survey design
svy_roving <- svydesign(
  ids = ~1,
  strata = ~location,
  data = roving_data
)

# Simple estimation (no length-bias correction)
cpue_simple <- est_cpue_roving(
  design = svy_roving,
  by = "location",
  response = "catch_kept",
  effort_col = "hours_fished",
  length_bias_correction = "none"
)

print(cpue_simple)

# Compare to true rate (0.5)
cpue_simple$estimate  # Should be biased upward without correction
```

**Section 4: Length-Bias Correction** (~200 lines)
```r
# Apply Pollock et al. correction
cpue_corrected <- est_cpue_roving(
  design = svy_roving,
  by = "location",
  response = "catch_kept",
  effort_col = "hours_fished",
  total_trip_effort_col = "planned_hours",
  length_bias_correction = "pollock"
)

print(cpue_corrected)

# Compare uncorrected vs corrected
comparison <- tibble(
  location = cpue_simple$location,
  cpue_uncorrected = cpue_simple$estimate,
  cpue_corrected = cpue_corrected$estimate,
  bias_pct = 100 * (cpue_simple$estimate - cpue_corrected$estimate) / cpue_corrected$estimate
)

print(comparison)

# Visualization
library(ggplot2)
ggplot(comparison, aes(x = location)) +
  geom_point(aes(y = cpue_uncorrected, color = "Uncorrected"), size = 3) +
  geom_point(aes(y = cpue_corrected, color = "Corrected"), size = 3) +
  geom_hline(yintercept = 0.5, linetype = "dashed", color = "gray50") +
  labs(
    title = "Length-Bias Correction Effect",
    subtitle = "True CPUE = 0.5 fish/hour",
    y = "CPUE Estimate",
    x = "Location",
    color = "Method"
  ) +
  theme_minimal()
```

**Section 5: Species Aggregation** (~100 lines)
- Combining roving CPUE with `aggregate_cpue()`
- Variance handling for species groups

**Section 6: Total Harvest Estimation** (~100 lines)
- Combining roving CPUE with effort estimates
- Using `est_total_harvest()`

**Section 7: Diagnostics & QC** (~100 lines)
- Inspecting diagnostic output
- Checking truncation rates
- Validating correction weights

---

### Phase 4: Integration & Deprecation Strategy 🔄

**Changes to Existing Code**

**File:** `R/est-cpue.R`

Add cross-reference in documentation:
```r
#' @seealso
#' For roving surveys with length-biased sampling, consider using
#' [est_cpue_roving()] which implements Pollock et al. (1997) methods
#' with proper length-bias correction.
```

Add informational message in auto mode:
```r
# In est_cpue_auto(), when detecting incomplete trips:
cli::cli_inform(c(
  "i" = "Detected incomplete trips in interview data.",
  ">" = "For roving surveys, consider using {.fn est_cpue_roving} for",
  ">" = "proper length-bias correction (Pollock et al. 1997)."
))
```

---

## Implementation Timeline

### Sprint 1 (Week 1-2)

**Week 1:**
- [ ] Create `R/est-cpue-roving.R` skeleton
- [ ] Implement Steps 1.1-1.4 (validation, truncation, catch rates, correction)
- [ ] Write tests for input validation (Test Suite 1)
- [ ] Write tests for trip truncation (Test Suite 2)

**Week 2:**
- [ ] Implement Steps 1.5-1.7 (estimation, CIs, sample sizes)
- [ ] Write known value tests (Test Suite 3)
- [ ] Write grouped estimation tests (Test Suite 4)

### Sprint 2 (Week 3)

**Week 3:**
- [ ] Implement Steps 1.8-1.10 (method label, diagnostics, return)
- [ ] Write edge case tests (Test Suite 5)
- [ ] Write diagnostics tests (Test Suite 6)
- [ ] Write integration tests (Test Suite 7)
- [ ] Verify all tests pass (`devtools::test()`)
- [ ] Run R CMD check

### Sprint 3 (Week 4 - Optional Polish)

**Week 4:**
- [ ] Write vignette `vignettes/roving-surveys.Rmd`
- [ ] Add cross-references to `est-cpue.R`
- [ ] Update `DEVELOPMENT_ROADMAP.md` to mark complete
- [ ] Create PR with comprehensive documentation
- [ ] Peer review and merge

---

## Success Criteria

### Functionality ✅
- [ ] `est_cpue_roving()` function passes all 50+ tests
- [ ] Pollock et al. correction produces unbiased estimates in simulations
- [ ] Integrates seamlessly with survey package designs
- [ ] Handles edge cases gracefully (zero catches, single observations, all NA)
- [ ] Supports grouped estimation with multiple stratification variables

### Documentation ✅
- [ ] Comprehensive roxygen2 documentation with examples
- [ ] Detailed vignette with simulated data walkthrough
- [ ] Clear explanation of when to use vs `est_cpue()`
- [ ] Statistical formulas documented in `@details`
- [ ] Cross-references to related functions

### Code Quality ✅
- [ ] Follows tidycreel style conventions
- [ ] Uses standard schema (estimate, se, ci_low, ci_high, n, method, diagnostics)
- [ ] Integrates with `survey` package methods
- [ ] Informative error messages with `cli::cli_abort()`
- [ ] Diagnostic output for QC

### Testing ✅
- [ ] >95% code coverage
- [ ] Tests validate statistical correctness with known values
- [ ] Tests cover all parameter combinations
- [ ] Integration tests with survey designs (stratified, replicate)

---

## Open Questions & Design Decisions

### Q1: Simple Ratio Correction Method
**Question:** Should we implement `length_bias_correction = "simple_ratio"` as an alternative to Pollock?

**Options:**
- **Option A:** Implement simple ratio: `mean(catch) / mean(effort)` (less theoretically sound)
- **Option B:** Only implement `"pollock"` and `"none"` (simpler, more defensible)

**Recommendation:** **Option B** - Focus on Pollock method initially. Can add alternatives later if user demand exists.

---

### Q2: Integration with `est_effort()` for Roving
**Question:** Should we create specialized roving effort estimator?

**Context:** Roving surveys often estimate effort differently (e.g., count anglers during circuit, not at access points).

**Recommendation:** Defer to **Phase 5** (Bus Route & Hybrid Designs). Current `est_effort()` methods can work for now with proper survey design specification.

---

### Q3: Handling Mixed Complete/Incomplete Data
**Question:** Should `est_cpue_roving()` handle mixed data like `est_cpue()` auto mode?

**Recommendation:** **No** - `est_cpue_roving()` should be for **roving surveys only** (incomplete trips). Users with mixed data should use `est_cpue(..., mode = "auto")`. This keeps functions focused and simpler.

---

## References

1. **Pollock, K.H., C.M. Jones, and T.L. Brown. 1994.** *Angler Survey Methods and Their Applications in Fisheries Management.* American Fisheries Society Special Publication 25.

2. **Hoenig, J.M., C.M. Jones, K.H. Pollock, D.S. Robson, and D.L. Wade. 1997.** Calculation of catch rate and total catch in roving and access point surveys. *Biometrics* 53:306-317.

3. **Jones, C.M. and K.H. Pollock. 2012.** Recreational survey methods: estimation of effort, harvest, and released catch. Pages 883-919 in A.V. Zale, D.L. Parrish, and T.M. Sutton, editors. *Fisheries Techniques, 3rd edition.* American Fisheries Society, Bethesda, Maryland.

4. **Chapter 17: Creel Surveys.** *Analysis and Interpretation of Freshwater Fisheries Data, 2nd Edition.* American Fisheries Society.

---

## Appendix: Statistical Formulas

### Mean-of-Ratios Estimator (No Correction)

Individual catch rate:
$$r_i = \frac{c_i}{e_i}$$

Mean:
$$\bar{r} = \frac{1}{n} \sum_{i=1}^n r_i$$

Variance:
$$Var(\bar{r}) = \frac{1}{n(n-1)} \sum_{i=1}^n (r_i - \bar{r})^2$$

Standard error:
$$SE(\bar{r}) = \sqrt{Var(\bar{r})}$$

### Pollock Length-Bias Correction

Correction weight:
$$w_i = \frac{1}{T_i}$$

where $T_i$ = total planned trip effort.

Corrected estimator:
$$\bar{r}_{LB} = \frac{\sum_{i=1}^n w_i r_i}{\sum_{i=1}^n w_i}$$

Variance:
$$Var(\bar{r}_{LB}) = \frac{\sum_{i=1}^n w_i^2 (r_i - \bar{r}_{LB})^2}{\left(\sum_{i=1}^n w_i\right)^2}$$

### Confidence Intervals (Wald)

$$CI = \bar{r} \pm z_{\alpha/2} \cdot SE(\bar{r})$$

where $z_{\alpha/2} = 1.96$ for 95% confidence.

---

**End of Implementation Plan**

**Next Steps:**
1. Review and approve this plan
2. Create feature branch: `feature/roving-estimators`
3. Begin Sprint 1 implementation
4. Track progress in `DEVELOPMENT_ROADMAP.md`
