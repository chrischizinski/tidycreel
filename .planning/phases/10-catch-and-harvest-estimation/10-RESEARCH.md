# Phase 10: Catch and Harvest Estimation - Research

**Researched:** 2026-02-10
**Domain:** Harvest per unit effort (HPUE) estimation using ratio-of-means with survey package
**Confidence:** HIGH

## Summary

Phase 10 extends Phase 9's CPUE infrastructure to support harvest estimation. The key distinction in creel surveys is between **catch** (all fish caught, including those released) and **harvest** (only fish kept by anglers). This phase implements harvest per unit effort (HPUE) estimation using the same ratio-of-means estimator and survey package infrastructure proven in Phase 9, but applied to the `catch_kept` variable instead of `catch_total`.

The implementation is architecturally straightforward: `estimate_cpue()` already exists and uses `survey::svyratio()` for ratio-of-means CPUE estimation. Phase 10 adds an `estimate_harvest()` function that mirrors this pattern exactly, substituting `design$harvest_col` for `design$catch_col` as the numerator in the ratio. All variance infrastructure (Taylor/bootstrap/jackknife), sample size validation (n≥30 warn, n≥10 error), zero-effort handling, and grouped estimation patterns carry forward unchanged. The harvest column (`catch_kept`) is already validated in Phase 8's `add_interviews()` Tier 1 validation, which checks that harvest ≤ catch for all interviews.

The user workflow becomes: (1) call `add_interviews(design, data, catch = catch_total, effort = hours, harvest = catch_kept)` to attach interview data with harvest tracking, (2) call `estimate_cpue(design)` to get total catch per effort, (3) call `estimate_harvest(design)` to get kept-fish per effort. Total harvest in a fishery is then estimated as HPUE × total effort (from `estimate_effort()`), exactly mirroring the catch estimation workflow. Output uses `method = "ratio-of-means-hpue"` to distinguish harvest rates from catch rates, with human-readable formatting as "Ratio-of-Means HPUE".

**Primary recommendation:** Create `estimate_harvest()` function in `R/creel-estimates.R` that mirrors `estimate_cpue()` structure exactly. Use `design$harvest_col` as numerator, `design$effort_col` as denominator in `survey::svyratio()` calls. Reuse all existing infrastructure: `validate_cpue_sample_size()` (rename to `validate_ratio_sample_size()` for shared use), `get_variance_design()` helper, zero-effort filtering logic, and `creel_estimates` S3 class. Add validation check that `design$harvest_col` exists before estimation (error if NULL, informing user to pass harvest parameter to `add_interviews()`). Store `method = "ratio-of-means-hpue"` in output. Update `format.creel_estimates()` switch statement to display "Ratio-of-Means HPUE" for human readability.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| survey | 4.4+ | Ratio-of-means estimation via svyratio() | Already in use for CPUE; identical API for HPUE |
| cli | Current | Validation errors/warnings | Already in use throughout package |
| dplyr | Current | Interview data manipulation | Already in use throughout package |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| testthat | 3.3.2+ | Reference tests for harvest estimation | Verify harvest estimates match expected rates |
| tibble | Current | Result formatting | Already in use for creel_estimates output |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Reusing estimate_cpue() with parameter | Separate estimate_harvest() function | Separate function provides clearer API and method identification, avoids conditional logic complexity |
| Total harvest estimation (HPUE × effort) | Separate function estimate_total_harvest() | Defer total harvest to future phase - Phase 10 scope is HPUE rates only, users can manually multiply |
| Manual rename of validate_cpue_sample_size | New validate_harvest_sample_size function | Rename to validate_ratio_sample_size for shared use - same validation logic applies to both CPUE and HPUE |

**Installation:**
```bash
# No new dependencies - all packages already in DESCRIPTION
```

## Architecture Patterns

### Pattern 1: HPUE Estimation Function Signature

**What:** User-facing function matching estimate_cpue() API exactly, but operating on harvest data

**When to use:** User calls estimate_harvest() on design with interviews that include harvest column

**Example:**
```r
# Add to R/creel-estimates.R after estimate_cpue()

#' Estimate harvest per unit effort (HPUE) from a creel survey design
#'
#' Computes HPUE estimates with standard errors and confidence intervals
#' from a creel survey design with attached interview data including harvest
#' (kept fish) information. Uses ratio-of-means estimator (survey::svyratio)
#' appropriate for complete trip interviews from access point surveys.
#'
#' @param design A creel_design object with interviews attached via
#'   \code{\link{add_interviews}}. The design must have an interview survey
#'   object constructed with catch, effort, and harvest columns.
#' @param by Optional tidy selector for grouping variables (same as estimate_cpue)
#' @param variance Character string specifying variance estimation method:
#'   "taylor" (default), "bootstrap", or "jackknife"
#' @param conf_level Numeric confidence level (default: 0.95)
#'
#' @return A creel_estimates S3 object with method = "ratio-of-means-hpue"
#'
#' @details
#' HPUE (harvest per unit effort) estimates the rate of kept fish per unit
#' effort. This differs from CPUE (catch per unit effort) which includes all
#' fish caught (kept + released). The function uses ratio-of-means estimator:
#' HPUE = E[harvest]/E[effort].
#'
#' Sample size validation: warns if n<30 (unstable variance), errors if n<10
#' (unreliable variance estimation) per group.
#'
#' @examples
#' # Basic usage
#' library(tidycreel)
#' data(example_calendar)
#' data(example_interviews)
#'
#' design <- creel_design(example_calendar, date = date, strata = day_type)
#' design <- add_interviews(design, example_interviews,
#'                          catch = catch_total,
#'                          effort = hours_fished,
#'                          harvest = catch_kept)
#'
#' # Estimate HPUE
#' hpue <- estimate_harvest(design)
#' print(hpue)
#'
#' # Compare to CPUE
#' cpue <- estimate_cpue(design)
#' # CPUE includes released fish, HPUE only kept fish
#' # cpue$estimates$estimate > hpue$estimates$estimate
#'
#' # Grouped by stratum
#' hpue_by_type <- estimate_harvest(design, by = day_type)
#'
#' @export
estimate_harvest <- function(design, by = NULL, variance = "taylor", conf_level = 0.95) {
  # Capture by parameter BEFORE validation
  by_quo <- rlang::enquo(by)

  # Validate variance parameter
  valid_methods <- c("taylor", "bootstrap", "jackknife")
  if (!variance %in% valid_methods) {
    cli::cli_abort(c(
      "Invalid variance method: {.val {variance}}",
      "x" = "Must be one of: {.val {valid_methods}}",
      "i" = "Default is {.val taylor} (Taylor linearization)"
    ))
  }

  # Validate input is creel_design
  if (!inherits(design, "creel_design")) {
    cli::cli_abort(c(
      "{.arg design} must be a {.cls creel_design} object.",
      "x" = "{.arg design} is {.cls {class(design)[1]}}.",
      "i" = "Create a design with {.fn creel_design}."
    ))
  }

  # Validate design$interview_survey exists
  if (is.null(design$interview_survey)) {
    cli::cli_abort(c(
      "No interview survey design available.",
      "x" = "Call {.fn add_interviews} before estimating harvest.",
      "i" = "Example: {.code design <- add_interviews(design, interviews, catch = catch_total, effort = hours_fished, harvest = catch_kept)}"
    ))
  }

  # Validate harvest_col exists (distinguishes from CPUE)
  if (is.null(design$harvest_col)) {
    cli::cli_abort(c(
      "No harvest column available.",
      "x" = "Harvest estimation requires harvest (kept fish) data.",
      "i" = "Call {.fn add_interviews} with harvest parameter:",
      "i" = "{.code design <- add_interviews(design, interviews, catch = catch, effort = effort, harvest = kept)}"
    ))
  }

  # Validate effort_col exists
  if (is.null(design$effort_col)) {
    cli::cli_abort(c(
      "No effort column available.",
      "x" = "Design must have effort_col set.",
      "i" = "Call {.fn add_interviews} with effort parameter."
    ))
  }

  # Route to grouped or ungrouped estimation
  if (rlang::quo_is_null(by_quo)) {
    # Ungrouped estimation
    # Validate sample size
    validate_ratio_sample_size(design, NULL, type = "harvest")
    return(estimate_harvest_total(design, variance, conf_level))
  } else {
    # Grouped estimation
    # Resolve by parameter to column names
    by_cols <- tidyselect::eval_select(
      by_quo,
      data = design$interviews,
      allow_rename = FALSE,
      allow_empty = FALSE,
      error_call = rlang::caller_env()
    )
    by_vars <- names(by_cols)

    # Validate sample size per group
    validate_ratio_sample_size(design, by_vars, type = "harvest")
    return(estimate_harvest_grouped(design, by_vars, variance, conf_level))
  }
}
```

### Pattern 2: Internal Harvest Estimation Functions

**What:** Internal functions for ungrouped and grouped HPUE estimation, mirroring CPUE pattern

**When to use:** Called internally by estimate_harvest() after validation

**Example:**
```r
# Add to R/creel-estimates.R after estimate_cpue_grouped()

#' Ungrouped HPUE estimation (ratio-of-means)
#'
#' @keywords internal
#' @noRd
estimate_harvest_total <- function(design, variance_method, conf_level) {
  interviews_data <- design$interviews
  harvest_col <- design$harvest_col
  effort_col <- design$effort_col

  # Filter out zero-effort interviews with warning (same as CPUE)
  zero_effort <- !is.na(interviews_data[[effort_col]]) & interviews_data[[effort_col]] == 0
  if (any(zero_effort)) {
    n_zero <- sum(zero_effort)
    cli::cli_warn(c(
      "{n_zero} interview{?s} with zero effort excluded from harvest estimation.",
      "i" = "HPUE requires effort > 0 (harvest/effort is undefined for effort = 0)."
    ))
    interviews_data <- interviews_data[!zero_effort, , drop = FALSE]
  }

  # Build temporary survey design from filtered data if filtering occurred
  if (any(zero_effort)) {
    strata_cols <- design$strata_cols
    if (!is.null(strata_cols) && length(strata_cols) > 0) {
      strata_formula <- stats::reformulate(strata_cols)
      temp_survey <- survey::svydesign(
        ids = ~1,
        strata = strata_formula,
        data = interviews_data
      )
    } else {
      temp_survey <- survey::svydesign(
        ids = ~1,
        data = interviews_data
      )
    }
    svy_design <- get_variance_design(temp_survey, variance_method)
  } else {
    svy_design <- get_variance_design(design$interview_survey, variance_method)
  }

  # Create formulas for ratio estimation (harvest / effort)
  harvest_formula <- stats::reformulate(harvest_col)
  effort_formula <- stats::reformulate(effort_col)

  # Call survey::svyratio (suppress expected survey package warnings)
  svy_result <- suppressWarnings(
    survey::svyratio(harvest_formula, effort_formula, svy_design)
  )

  # Extract estimates
  estimate <- as.numeric(coef(svy_result))
  se <- as.numeric(survey::SE(svy_result))
  ci <- confint(svy_result, level = conf_level)
  ci_lower <- ci[1, 1]
  ci_upper <- ci[1, 2]
  n <- nrow(interviews_data)

  # Build estimates tibble
  estimates_df <- tibble::tibble(
    estimate = estimate,
    se = se,
    ci_lower = ci_lower,
    ci_upper = ci_upper,
    n = n
  )

  # Return creel_estimates object
  new_creel_estimates(
    estimates = estimates_df,
    method = "ratio-of-means-hpue",
    variance_method = variance_method,
    design = design,
    conf_level = conf_level,
    by_vars = NULL
  )
}

#' Grouped HPUE estimation using svyby + svyratio
#'
#' @keywords internal
#' @noRd
estimate_harvest_grouped <- function(design, by_vars, variance_method, conf_level) {
  interviews_data <- design$interviews
  harvest_col <- design$harvest_col
  effort_col <- design$effort_col

  # Filter out zero-effort interviews with warning
  zero_effort <- !is.na(interviews_data[[effort_col]]) & interviews_data[[effort_col]] == 0
  if (any(zero_effort)) {
    n_zero <- sum(zero_effort)
    cli::cli_warn(c(
      "{n_zero} interview{?s} with zero effort excluded from harvest estimation.",
      "i" = "HPUE requires effort > 0 (harvest/effort is undefined for effort = 0)."
    ))
    interviews_data <- interviews_data[!zero_effort, , drop = FALSE]
  }

  # Build temporary survey design from filtered data if filtering occurred
  if (any(zero_effort)) {
    strata_cols <- design$strata_cols
    if (!is.null(strata_cols) && length(strata_cols) > 0) {
      strata_formula <- stats::reformulate(strata_cols)
      temp_survey <- survey::svydesign(
        ids = ~1,
        strata = strata_formula,
        data = interviews_data
      )
    } else {
      temp_survey <- survey::svydesign(
        ids = ~1,
        data = interviews_data
      )
    }
    svy_design <- get_variance_design(temp_survey, variance_method)
  } else {
    svy_design <- get_variance_design(design$interview_survey, variance_method)
  }

  # Build formulas for svyby
  harvest_formula <- stats::reformulate(harvest_col)
  effort_formula <- stats::reformulate(effort_col)
  by_formula <- stats::reformulate(by_vars)

  # Call survey::svyby with svyratio (suppress expected survey package warnings)
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

  # Extract estimate columns from svyby result
  ratio_col <- paste0(harvest_col, "/", effort_col)
  se_col <- paste0("se.", ratio_col)
  estimate <- svy_result[[ratio_col]]
  se <- svy_result[[se_col]]
  ci_lower <- svy_result[["ci_l"]]
  ci_upper <- svy_result[["ci_u"]]

  # Calculate per-group sample sizes
  group_data_for_n <- interviews_data[by_vars]
  group_data_for_n$.count <- 1
  n_by_group <- stats::aggregate(
    .count ~ .,
    data = group_data_for_n,
    FUN = sum
  )
  names(n_by_group)[names(n_by_group) == ".count"] <- "n"

  # Build result tibble with group columns first, then estimates
  estimates_df <- svy_result[by_vars]
  estimates_df$estimate <- estimate
  estimates_df$se <- se
  estimates_df$ci_lower <- ci_lower
  estimates_df$ci_upper <- ci_upper

  # Join sample sizes
  estimates_df <- merge(estimates_df, n_by_group, by = by_vars, all.x = TRUE, sort = FALSE)

  # Convert to tibble and reorder columns
  estimates_df <- tibble::as_tibble(estimates_df)
  col_order <- c(by_vars, "estimate", "se", "ci_lower", "ci_upper", "n")
  estimates_df <- estimates_df[col_order]

  # Return creel_estimates object
  new_creel_estimates(
    estimates = estimates_df,
    method = "ratio-of-means-hpue",
    variance_method = variance_method,
    design = design,
    conf_level = conf_level,
    by_vars = by_vars
  )
}
```

### Pattern 3: Shared Sample Size Validation

**What:** Rename validate_cpue_sample_size to validate_ratio_sample_size for use by both CPUE and HPUE

**When to use:** Called at start of estimate_cpue() and estimate_harvest() before estimation

**Example:**
```r
# In R/survey-bridge.R, rename validate_cpue_sample_size to:

#' Validate ratio estimation sample size
#'
#' Internal function that checks sample size adequacy for ratio estimation
#' (CPUE or HPUE). Errors if n < 10 (ungrouped or any group), warns if
#' 10 <= n < 30. These thresholds follow best practices for ratio estimation
#' stability.
#'
#' @param design A creel_design object with interviews attached
#' @param by_vars NULL for ungrouped, or character vector of grouping variable names
#' @param type Character string "cpue" or "harvest" for error message clarity
#'
#' @return NULL (invisible) - function called for side effects (errors/warnings)
#'
#' @keywords internal
#' @noRd
validate_ratio_sample_size <- function(design, by_vars, type = "cpue") {
  interviews <- design$interviews

  # Set descriptive name for messages
  estimation_type <- if (type == "harvest") "harvest" else "CPUE"

  if (is.null(by_vars)) {
    # Ungrouped validation
    n <- nrow(interviews)

    if (n < 10) {
      cli::cli_abort(c(
        "Insufficient sample size for {estimation_type} estimation.",
        "x" = "Sample size is {n}, but ratio estimation requires n >= 10.",
        "i" = "Collect more interview observations before estimating {estimation_type}."
      ))
    }

    if (n >= 10 && n < 30) {
      cli::cli_warn(c(
        "Small sample size for {estimation_type} estimation.",
        "!" = "Sample size is {n}. Ratio estimates are more stable with n >= 30.",
        "i" = "Variance estimates may be unstable with n < 30."
      ))
    }
  } else {
    # Grouped validation - same logic as existing
    # [... rest of grouped validation code unchanged ...]
  }

  invisible(NULL)
}

# Update estimate_cpue() calls:
# validate_cpue_sample_size(design, NULL) → validate_ratio_sample_size(design, NULL, "cpue")
# validate_cpue_sample_size(design, by_vars) → validate_ratio_sample_size(design, by_vars, "cpue")
```

### Pattern 4: Update format.creel_estimates for HPUE Display

**What:** Add "ratio-of-means-hpue" case to method display switch statement

**When to use:** When printing creel_estimates objects with HPUE method

**Example:**
```r
# In R/creel-estimates.R format.creel_estimates()
# Update switch statement:

method_display <- switch(x$method,
  total = "Total",
  "ratio-of-means-cpue" = "Ratio-of-Means CPUE",
  "ratio-of-means-hpue" = "Ratio-of-Means HPUE",
  x$method
)
```

### Anti-Patterns to Avoid

- **Reusing estimate_cpue() with toggle parameter:** Don't add `type = c("catch", "harvest")` parameter to estimate_cpue() - creates confusing API where function name doesn't match behavior. Separate functions provide clarity.
- **Not validating harvest_col exists:** User may call estimate_harvest() on design without harvest data - must check design$harvest_col and provide informative error directing to add_interviews() with harvest parameter.
- **Creating separate validation function:** Don't duplicate validate_cpue_sample_size as validate_harvest_sample_size - identical logic, rename to validate_ratio_sample_size and add type parameter for message clarity.
- **Skipping zero-effort filtering:** Must apply same zero-effort handling as CPUE - undefined ratios cause svyratio to fail.
- **Different method identifier format:** Use consistent naming: "ratio-of-means-cpue" and "ratio-of-means-hpue" (not "hpue" or "harvest-rate" or other variants) for clear machine-readable distinction.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Harvest ratio variance | Manual delta method for harvest/effort | survey::svyratio with harvest numerator | Identical variance propagation math as CPUE, no new implementation needed |
| Total harvest estimation | Custom multiplication of HPUE × effort with variance pooling | Manual calculation by user (defer to future phase) | Phase 10 scope is rates only; total harvest requires combining estimates across strata which is complex enough for dedicated phase |
| Validation for harvest vs catch | Separate validation functions | Rename validate_cpue_sample_size to validate_ratio_sample_size | Identical thresholds (n≥30, n≥10) apply to all ratio estimators |
| Method display names | Storing display names in method field | Switch statement in format.creel_estimates() | Keeps method field machine-readable while supporting human-friendly display |

**Key insight:** Harvest estimation is architecturally identical to CPUE estimation - both are ratio-of-means estimators with different numerators. The only implementation differences are: (1) which column to use (harvest_col vs catch_col), (2) validation that harvest_col exists, (3) method identifier string. All statistical logic, variance infrastructure, and sample size requirements are identical.

## Common Pitfalls

### Pitfall 1: Forgetting harvest_col Validation

**What goes wrong:** User calls estimate_harvest() on design without harvest data (NULL harvest_col), producing cryptic error from svyratio about missing variable.

**Why it happens:** harvest parameter in add_interviews() is optional - users may attach interviews with only catch and effort, forgetting harvest is required for harvest estimation.

**How to avoid:** Add explicit check at start of estimate_harvest() that design$harvest_col is not NULL. Provide informative error message with example showing how to pass harvest parameter to add_interviews().

**Warning signs:** Error message from survey package "object 'NULL' not found" or similar. User reports "harvest estimation doesn't work but CPUE works fine."

### Pitfall 2: Harvest > Catch Data Entry Errors

**What goes wrong:** Interview data contains rows where harvest (kept) exceeds catch (total), violating physical impossibility. This produces nonsensical HPUE > CPUE results.

**Why it happens:** Data entry errors, column confusion (swapping catch_total and catch_kept), or misunderstanding of definitions.

**How to avoid:** Phase 8's `validate_interviews_tier1()` already checks harvest ≤ catch consistency during add_interviews() (Tier 1 validation). Document this check prominently. In Phase 10, mention in estimate_harvest() docs that harvest ≤ catch is pre-validated.

**Warning signs:** HPUE estimate exceeds CPUE estimate for same fishery, which is physically impossible since harvest is subset of catch.

### Pitfall 3: Comparing CPUE and HPUE Without Context

**What goes wrong:** User expects CPUE and HPUE to be similar magnitudes, but HPUE may be much lower (indicating high release rate) or similar (indicating high retention), causing confusion about "correct" value.

**Why it happens:** Not understanding that CPUE includes all fish (kept + released) while HPUE only includes kept fish. The ratio HPUE/CPUE is the retention rate.

**How to avoid:** Document relationship clearly in both estimate_cpue() and estimate_harvest() help: CPUE = total catch rate (kept + released), HPUE = harvest rate (kept only), retention rate = HPUE/CPUE. Provide vignette example showing all three.

**Warning signs:** User asks "which is right, CPUE or HPUE?" or reports "HPUE is much lower than CPUE, is this a bug?"

### Pitfall 4: Attempting Total Harvest Estimation in Phase 10

**What goes wrong:** User wants total harvest (not rate), tries to multiply HPUE × effort themselves, gets confused about variance calculation and stratified multiplication.

**Why it happens:** Phase 10 scope is HPUE rates only. Total harvest requires combining HPUE estimates with effort estimates across strata, with proper variance propagation - complex enough for dedicated future phase.

**How to avoid:** Document in estimate_harvest() that function returns rates (harvest per unit effort), not totals. Mention that total harvest estimation is future work. Provide manual calculation example without variance for simple cases.

**Warning signs:** User opens issue requesting "estimate_total_harvest()" function, or asks how to calculate standard error for total harvest.

### Pitfall 5: Not Renaming validate_cpue_sample_size

**What goes wrong:** Developer creates validate_harvest_sample_size() function that duplicates identical logic from validate_cpue_sample_size(), increasing maintenance burden and test coverage requirements.

**Why it happens:** Function naming suggests CPUE-specific validation, but logic applies to all ratio estimators identically.

**How to avoid:** Rename validate_cpue_sample_size to validate_ratio_sample_size with type parameter. Update estimate_cpue() calls to pass type="cpue", estimate_harvest() passes type="harvest". Same validation logic, type parameter only affects error message wording.

**Warning signs:** Two validation functions with 95% identical code, tests duplicated across both functions.

## Code Examples

Verified patterns from official sources and existing codebase:

### Reusing svyratio for Different Numerator

```r
# CPUE: catch / effort
cpue_result <- survey::svyratio(~catch_total, ~hours_fished, interview_design)

# HPUE: harvest / effort (identical API, different numerator)
hpue_result <- survey::svyratio(~catch_kept, ~hours_fished, interview_design)

# Extract estimates identically
cpue <- coef(cpue_result)
hpue <- coef(hpue_result)

# Retention rate = HPUE / CPUE (proportion of catch kept)
retention_rate <- hpue / cpue
```

### Validation Pattern with Type Parameter

```r
# Shared validation function for CPUE and HPUE
validate_ratio_sample_size <- function(design, by_vars, type = "cpue") {
  estimation_type <- if (type == "harvest") "harvest" else "CPUE"

  if (n < 10) {
    cli::cli_abort(c(
      "Insufficient sample size for {estimation_type} estimation.",
      "x" = "Sample size is {n}, but ratio estimation requires n >= 10."
    ))
  }
}

# Called from estimate_cpue
validate_ratio_sample_size(design, NULL, type = "cpue")

# Called from estimate_harvest
validate_ratio_sample_size(design, NULL, type = "harvest")
```

### User Workflow Example

```r
# 1. Create design with calendar
design <- creel_design(calendar, date = date, strata = day_type)

# 2. Attach interviews with harvest tracking
design <- add_interviews(
  design, interview_data,
  catch = catch_total,      # All fish caught
  effort = hours_fished,
  harvest = catch_kept      # Only fish kept
)
# Validation automatically checks: harvest <= catch for all rows

# 3. Estimate catch rate (all fish)
cpue <- estimate_cpue(design)
print(cpue)  # Shows "Ratio-of-Means CPUE"

# 4. Estimate harvest rate (kept fish only)
hpue <- estimate_harvest(design)
print(hpue)  # Shows "Ratio-of-Means HPUE"

# 5. Compare rates
retention_rate <- hpue$estimates$estimate / cpue$estimates$estimate
# Example: retention_rate = 0.75 means 75% of caught fish were kept

# 6. Estimate total effort
effort <- estimate_effort(design)

# 7. Calculate total harvest (manual for now, future phase will automate)
total_harvest_approx <- hpue$estimates$estimate * effort$estimates$estimate
# Note: variance calculation for total harvest is complex, defer to future phase
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Single "catch" variable | Separate catch (total) and harvest (kept) variables | 1990s-2000s fisheries data standards | Enables estimation of release mortality, retention rates, and harvest separately from total catch |
| Manual ratio calculation | survey::svyratio() for both CPUE and HPUE | survey package 2.0+ (2000s) | Consistent variance estimation across all ratio estimators |
| Harvest ≤ catch assumed, no validation | Explicit Tier 1 validation | Modern data quality standards | Catches data entry errors before producing nonsensical estimates |
| Total harvest only | Both rates (HPUE) and totals | Modern creel analysis | Rates enable comparison across fisheries with different effort levels |

**Deprecated/outdated:**
- **Harvest-only reporting:** Older creel surveys sometimes reported only harvest, not distinguishing total catch. Modern surveys record both to assess release mortality and fishing pressure.
- **Assuming 100% retention:** Early creel analysis sometimes assumed all caught fish were kept. Modern fisheries often have catch-and-release practices, making harvest < catch common.

## Open Questions

1. **Should Phase 10 include total harvest estimation (HPUE × effort)?**
   - What we know: HPUE rates × effort totals → total harvest. User workflow wants this.
   - What's unclear: Variance calculation for product of two survey estimates across strata is non-trivial, requires additional survey package knowledge.
   - Recommendation: Defer to future phase. Phase 10 provides HPUE rates only. Document that users can manually multiply for point estimates, but variance estimation for total harvest is future work. This keeps Phase 10 scope manageable.

2. **Should estimate_harvest() warn if retention rate is very low or very high?**
   - What we know: Retention rate = HPUE/CPUE. Values near 0 (heavy catch-and-release) or 1 (keeping all fish) may indicate specific fishery characteristics.
   - What's unclear: Whether low/high retention is "unusual" depends on fishery type, regulations, species. No universal threshold.
   - Recommendation: Do not add retention rate warnings in Phase 10. If user wants retention rate analysis, they can calculate manually. Avoid false positives from legitimate fishery practices.

3. **Should harvest column support NA values (incomplete harvest data)?**
   - What we know: Phase 8 validates harvest_col is numeric, but doesn't explicitly forbid NAs (unlike date_col which errors on NA).
   - What's unclear: Whether interviews with catch but missing harvest should be excluded from harvest estimation or treated as zero harvest.
   - Recommendation: Treat NA harvest as missing data - exclude from harvest estimation with warning (similar to zero-effort handling). Document that interviews must have non-NA harvest for inclusion in HPUE estimation.

4. **Should release rate (1 - retention) be calculated automatically?**
   - What we know: Release rate = (CPUE - HPUE) / CPUE = proportion of catch released. Useful for catch-and-release management.
   - What's unclear: Whether this is core Phase 10 scope or a derived metric for future analysis functions.
   - Recommendation: Defer release rate calculation to future phase or vignette. Phase 10 provides HPUE estimates; users can calculate derived metrics manually or via future helper functions.

## Sources

### Primary (HIGH confidence)
- [R survey package - svyratio documentation](https://r-survey.r-forge.r-project.org/survey/html/svyratio.html) - Ratio estimation with arbitrary numerator/denominator
- Existing tidycreel codebase - Phase 9 estimate_cpue() implementation, Phase 8 add_interviews() validation
- [NOAA Fisheries - Estimation Methods Overview](https://www.fisheries.noaa.gov/recreational-fishing-data/estimation-methods-overview) - Catch vs harvest definitions
- [ASMFC Recreational Data Collection](https://asmfc.org/programs/management/recreational-data-collection/) - Catch, harvest, and release distinctions in fisheries surveys

### Secondary (MEDIUM confidence)
- [Sample Design: Banks Lake Annual Creel Survey](https://www.monitoringresources.org/Designer/OpportunisticDesign/Detail/16249) - Harvest per unit effort in creel survey context
- [Evaluation of bus-route creel survey method (ScienceDirect)](https://www.sciencedirect.com/science/article/abs/pii/S0165783697000672) - Harvest estimation in recreational fisheries
- WebSearch results on harvest vs catch definitions (2026) - Confirms harvest = kept fish, catch = total fish caught

### Tertiary (LOW confidence)
- General fisheries management literature on retention rates - Qualitative understanding, not specific to tidycreel implementation

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Identical to Phase 9 CPUE (survey::svyratio proven)
- Architecture: HIGH - Direct copy of estimate_cpue() pattern with harvest_col substitution
- Pitfalls: HIGH - Harvest ≤ catch validation already implemented in Phase 8; CPUE/HPUE distinction well-established in fisheries literature
- Code examples: HIGH - Directly from Phase 9 working code and survey package documentation

**Research date:** 2026-02-10
**Valid until:** 60 days (survey package stable, established fisheries methods)

**Notes:**
- No CONTEXT.md exists for this phase - full design freedom
- Phase 10 builds directly on Phase 9 CPUE infrastructure - minimal new code required
- harvest_col already validated in Phase 8's add_interviews() Tier 1 validation (harvest ≤ catch check line 782-797 in survey-bridge.R)
- Test data in test-estimate-cpue.R already includes catch_kept column - can reuse for harvest tests
- Scope: HPUE rates only (harvest per unit effort). Total harvest estimation (rates × effort with variance) deferred to future phase
- Single species only in v0.2.0 scope - multi-species harvest deferred to v0.3.0+
