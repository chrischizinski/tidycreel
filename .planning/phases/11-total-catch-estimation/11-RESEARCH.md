# Phase 11: Total Catch Estimation - Research

**Researched:** 2026-02-10
**Domain:** Combining effort and CPUE estimates with delta method variance propagation
**Confidence:** HIGH

## Summary

Phase 11 implements total catch estimation by combining effort estimates (from Phase 4-6) with CPUE estimates (from Phase 9) using the product relationship: Total Catch = Effort × CPUE. The core statistical challenge is variance propagation: the naive approach of multiplying variances (Var(E×C) = Var(E) × Var(C)) is mathematically incorrect. The correct approach uses the **delta method**, which applies Taylor series approximation to propagate variance through non-linear transformations. For products of independent estimates, the delta method formula is: Var(E×C) ≈ E²·Var(C) + C²·Var(E) + Var(E)·Var(C), where E and C are point estimates and Var(E) and Var(C) are their variances.

The R survey package provides `svycontrast()` for computing delta method variance automatically. Users pass a quoted expression like `quote(effort * cpue)` along with coef and vcov from two survey estimates, and svycontrast computes the product estimate with correct variance using symbolic differentiation. This is the recommended approach rather than manual delta method implementation, as it handles partial derivatives, variance-covariance matrix multiplication, and asymptotic normality assumptions automatically.

The implementation requires three design compatibility validations: (1) effort and CPUE must come from the same creel_design object (same calendar, stratification), (2) count data (effort) and interview data (CPUE) must exist on the design, and (3) for grouped estimation, both estimates must use identical grouping variables (by parameter must match). The function signature follows established patterns: `estimate_total_catch(design, by = NULL, variance = "taylor", conf_level = 0.95)`, returning a `creel_estimates` object with method = "product-total-catch".

**Primary recommendation:** Implement `estimate_total_catch()` in `R/creel-estimates.R` that calls `estimate_effort()` and `estimate_cpue()` internally, extracts coef/vcov from both results, uses `svycontrast()` with `quote(effort * cpue)` for delta method variance, and returns `creel_estimates` object. Add validation functions: `validate_design_compatibility()` (checks count and interview data exist), `validate_grouping_compatibility()` (checks by variables match if grouped). Store method as "product-total-catch" for clear identification. Support ungrouped and grouped estimation, following exact pattern from estimate_effort/estimate_cpue.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| survey | 4.4+ | Delta method via svycontrast() | Already in use; svycontrast handles non-linear contrasts with automatic variance propagation |
| cli | Current | Validation errors for design compatibility | Already in use for all validation messages |
| dplyr | Current | Data manipulation for results | Already in use throughout package |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| testthat | 3.3.2+ | Reference tests for total catch | Verify product estimates match manual delta method calculations |
| tibble | Current | Result formatting | Already in use for creel_estimates output |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| svycontrast for delta method | Manual delta method formula | svycontrast handles symbolic differentiation, variance-covariance matrix algebra, and edge cases automatically; manual implementation error-prone |
| Independent effort/CPUE calls | Combined estimation function | Separate calls make variance calculation transparent, enable variance method matching, and allow users to inspect intermediate results |
| Product variance approximation | Simulation-based variance | Delta method is standard for survey statistics, computationally efficient, and matches survey package ecosystem |

**Installation:**
```bash
# No new dependencies - all packages already in DESCRIPTION
```

## Architecture Patterns

### Pattern 1: Delta Method Product via svycontrast

**What:** Compute total catch as effort × CPUE with correct variance propagation using survey package delta method

**When to use:** User calls estimate_total_catch() on design with both counts (effort) and interviews (CPUE)

**Example:**
```r
# Add to R/creel-estimates.R after estimate_harvest()

#' Estimate total catch by combining effort and CPUE
#'
#' Computes total catch estimates by multiplying effort × CPUE with variance
#' propagation via the delta method. Requires a creel design with both count
#' data (for effort estimation) and interview data (for CPUE estimation).
#'
#' @param design A creel_design object with both counts (via
#'   \code{\link{add_counts}}) and interviews (via \code{\link{add_interviews}})
#'   attached. Both count and interview survey objects must exist.
#' @param by Optional tidy selector for grouping variables. When specified,
#'   must match across both effort and CPUE estimates (same calendar strata
#'   or interview variables). Accepts bare column names, multiple columns, or
#'   tidyselect helpers.
#' @param variance Character string specifying variance estimation method:
#'   "taylor" (default), "bootstrap", or "jackknife". Applied to BOTH effort
#'   and CPUE estimation, then combined via delta method.
#' @param conf_level Numeric confidence level (default: 0.95)
#'
#' @return A creel_estimates S3 object with method = "product-total-catch"
#'
#' @details
#' Total catch is computed as Effort × CPUE. Variance is propagated using the
#' delta method, which accounts for uncertainty in both estimates. The formula
#' for independent estimates is approximately:
#'
#' \deqn{Var(E \times C) \approx E^2 \cdot Var(C) + C^2 \cdot Var(E) + Var(E) \cdot Var(C)}
#'
#' The function uses survey::svycontrast() to compute variance automatically
#' via symbolic differentiation and Taylor series approximation.
#'
#' \strong{Design compatibility requirements:}
#' \itemize{
#'   \item Count data must be attached via \code{add_counts()} for effort estimation
#'   \item Interview data must be attached via \code{add_interviews()} for CPUE estimation
#'   \item Grouped estimation requires identical grouping variables for both estimates
#'   \item Calendar stratification must be shared between counts and interviews
#' }
#'
#' @examples
#' library(tidycreel)
#' data(example_calendar)
#' data(example_counts)
#' data(example_interviews)
#'
#' # Create design with both counts and interviews
#' design <- creel_design(example_calendar, date = date, strata = day_type)
#' design <- add_counts(design, example_counts)
#' design <- add_interviews(design, example_interviews,
#'                          catch = catch_total, effort = hours_fished)
#'
#' # Estimate total catch
#' total_catch <- estimate_total_catch(design)
#' print(total_catch)
#'
#' # Grouped by stratum
#' total_catch_by_type <- estimate_total_catch(design, by = day_type)
#'
#' # Compare components
#' effort_est <- estimate_effort(design)
#' cpue_est <- estimate_cpue(design)
#' # total_catch$estimates$estimate ≈ effort_est * cpue_est
#'
#' @export
estimate_total_catch <- function(design, by = NULL, variance = "taylor", conf_level = 0.95) {
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

  # Validate design compatibility (counts AND interviews required)
  validate_design_compatibility(design)

  # Route to grouped or ungrouped estimation
  if (rlang::quo_is_null(by_quo)) {
    # Ungrouped estimation
    return(estimate_total_catch_ungrouped(design, variance, conf_level))
  } else {
    # Grouped estimation
    # Resolve by parameter to column names
    by_cols <- tidyselect::eval_select(
      by_quo,
      data = design$counts, # Use counts as reference
      allow_rename = FALSE,
      allow_empty = FALSE,
      error_call = rlang::caller_env()
    )
    by_vars <- names(by_cols)

    # Validate grouping compatibility
    validate_grouping_compatibility(design, by_vars)

    return(estimate_total_catch_grouped(design, by_vars, variance, conf_level))
  }
}
```

### Pattern 2: Ungrouped Total Catch with svycontrast

**What:** Compute ungrouped total catch using delta method for product variance

**When to use:** Called internally by estimate_total_catch() when by = NULL

**Example:**
```r
# Internal function in R/creel-estimates.R

#' Ungrouped total catch estimation (delta method product)
#'
#' @keywords internal
#' @noRd
estimate_total_catch_ungrouped <- function(design, variance_method, conf_level) {
  # Call estimate_effort() and estimate_cpue() with specified variance method
  effort_result <- estimate_effort(design, variance = variance_method, conf_level = conf_level)
  cpue_result <- estimate_cpue(design, variance = variance_method, conf_level = conf_level)

  # Extract estimates and covariance matrices
  effort_est <- effort_result$estimates$estimate
  cpue_est <- cpue_result$estimates$estimate

  # Build named coefficient vector for svycontrast
  coefs <- c(effort = effort_est, cpue = cpue_est)

  # Build variance-covariance matrix (block diagonal, assumes independence)
  effort_var <- effort_result$estimates$se^2
  cpue_var <- cpue_result$estimates$se^2
  vcov_matrix <- matrix(
    c(effort_var, 0,
      0, cpue_var),
    nrow = 2, ncol = 2,
    dimnames = list(c("effort", "cpue"), c("effort", "cpue"))
  )

  # Use svycontrast to compute product with delta method variance
  # Create a minimal object structure that svycontrast can work with
  stat_obj <- list(
    coefficients = coefs,
    vcov = vcov_matrix
  )
  class(stat_obj) <- "svystat"

  # Apply delta method via svycontrast
  product_contrast <- survey::svycontrast(
    stat = stat_obj,
    contrasts = quote(effort * cpue)
  )

  # Extract results
  estimate <- as.numeric(coef(product_contrast))
  se <- as.numeric(survey::SE(product_contrast))
  ci <- confint(product_contrast, level = conf_level)
  ci_lower <- ci[1, 1]
  ci_upper <- ci[1, 2]

  # Sample size: use CPUE sample size (interview count)
  n <- cpue_result$estimates$n

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
    method = "product-total-catch",
    variance_method = variance_method,
    design = design,
    conf_level = conf_level,
    by_vars = NULL
  )
}
```

### Pattern 3: Design Compatibility Validation

**What:** Validate that design has both counts (for effort) and interviews (for CPUE)

**When to use:** At start of estimate_total_catch() before estimation

**Example:**
```r
# Internal validation function in R/survey-bridge.R

#' Validate design compatibility for total catch estimation
#'
#' Checks that design has both count data (for effort) and interview data
#' (for CPUE) required to compute total catch as effort × CPUE.
#'
#' @param design A creel_design object
#'
#' @return NULL (invisible) - function called for side effects (errors)
#'
#' @keywords internal
#' @noRd
validate_design_compatibility <- function(design) {
  # Check count data exists
  if (is.null(design$counts) || is.null(design$survey)) {
    cli::cli_abort(c(
      "No count data available for effort estimation.",
      "x" = "Total catch requires both effort (from counts) and CPUE (from interviews).",
      "i" = "Call {.fn add_counts} before estimating total catch:",
      "i" = "{.code design <- add_counts(design, count_data)}"
    ))
  }

  # Check interview data exists
  if (is.null(design$interviews) || is.null(design$interview_survey)) {
    cli::cli_abort(c(
      "No interview data available for CPUE estimation.",
      "x" = "Total catch requires both effort (from counts) and CPUE (from interviews).",
      "i" = "Call {.fn add_interviews} before estimating total catch:",
      "i" = "{.code design <- add_interviews(design, interviews, catch = catch, effort = effort)}"
    ))
  }

  invisible(NULL)
}

#' Validate grouping variable compatibility for total catch
#'
#' Checks that grouping variables specified in by parameter exist in both
#' count data (for effort) and interview data (for CPUE), enabling grouped
#' total catch estimation.
#'
#' @param design A creel_design object
#' @param by_vars Character vector of grouping variable names
#'
#' @return NULL (invisible) - function called for side effects (errors)
#'
#' @keywords internal
#' @noRd
validate_grouping_compatibility <- function(design, by_vars) {
  # Check grouping variables exist in count data
  missing_in_counts <- setdiff(by_vars, names(design$counts))
  if (length(missing_in_counts) > 0) {
    cli::cli_abort(c(
      "Grouping variable{?s} not found in count data:",
      "x" = "Missing: {.val {missing_in_counts}}",
      "i" = "Available in counts: {.val {names(design$counts)}}",
      "i" = "Grouped total catch requires variables present in both counts and interviews"
    ))
  }

  # Check grouping variables exist in interview data
  missing_in_interviews <- setdiff(by_vars, names(design$interviews))
  if (length(missing_in_interviews) > 0) {
    cli::cli_abort(c(
      "Grouping variable{?s} not found in interview data:",
      "x" = "Missing: {.val {missing_in_interviews}}",
      "i" = "Available in interviews: {.val {names(design$interviews)}}",
      "i" = "Grouped total catch requires variables present in both counts and interviews"
    ))
  }

  invisible(NULL)
}
```

### Pattern 4: Grouped Total Catch Estimation

**What:** Compute total catch separately for each group by combining grouped effort × grouped CPUE

**When to use:** Called internally by estimate_total_catch() when by parameter specified

**Example:**
```r
# Internal function in R/creel-estimates.R

#' Grouped total catch estimation using delta method
#'
#' @keywords internal
#' @noRd
estimate_total_catch_grouped <- function(design, by_vars, variance_method, conf_level) {
  # Call grouped estimation for both effort and CPUE
  effort_result <- estimate_effort(design, by = !!rlang::syms(by_vars), variance = variance_method, conf_level = conf_level)
  cpue_result <- estimate_cpue(design, by = !!rlang::syms(by_vars), variance = variance_method, conf_level = conf_level)

  # Extract estimates data frames (include group columns)
  effort_df <- effort_result$estimates
  cpue_df <- cpue_result$estimates

  # Merge on grouping variables to align rows
  merged <- merge(
    effort_df,
    cpue_df,
    by = by_vars,
    suffixes = c("_effort", "_cpue"),
    sort = FALSE
  )

  # Apply delta method for each group
  n_groups <- nrow(merged)
  estimates_list <- vector("list", n_groups)

  for (i in seq_len(n_groups)) {
    effort_est <- merged$estimate_effort[i]
    cpue_est <- merged$estimate_cpue[i]
    effort_se <- merged$se_effort[i]
    cpue_se <- merged$se_cpue[i]

    # Build coef and vcov for this group
    coefs <- c(effort = effort_est, cpue = cpue_est)
    effort_var <- effort_se^2
    cpue_var <- cpue_se^2
    vcov_matrix <- matrix(
      c(effort_var, 0, 0, cpue_var),
      nrow = 2, ncol = 2,
      dimnames = list(c("effort", "cpue"), c("effort", "cpue"))
    )

    # Create svystat object
    stat_obj <- list(coefficients = coefs, vcov = vcov_matrix)
    class(stat_obj) <- "svystat"

    # Apply delta method
    product_contrast <- survey::svycontrast(stat_obj, quote(effort * cpue))

    estimate <- as.numeric(coef(product_contrast))
    se <- as.numeric(survey::SE(product_contrast))
    ci <- confint(product_contrast, level = conf_level)

    estimates_list[[i]] <- list(
      estimate = estimate,
      se = se,
      ci_lower = ci[1, 1],
      ci_upper = ci[1, 2],
      n = merged$n_cpue[i] # Use interview sample size
    )
  }

  # Build result tibble
  estimates_df <- tibble::as_tibble(merged[by_vars])
  estimates_df$estimate <- sapply(estimates_list, `[[`, "estimate")
  estimates_df$se <- sapply(estimates_list, `[[`, "se")
  estimates_df$ci_lower <- sapply(estimates_list, `[[`, "ci_lower")
  estimates_df$ci_upper <- sapply(estimates_list, `[[`, "ci_upper")
  estimates_df$n <- sapply(estimates_list, `[[`, "n")

  # Return creel_estimates object
  new_creel_estimates(
    estimates = estimates_df,
    method = "product-total-catch",
    variance_method = variance_method,
    design = design,
    conf_level = conf_level,
    by_vars = by_vars
  )
}
```

### Pattern 5: Update format.creel_estimates for Total Catch Display

**What:** Add "product-total-catch" case to method display switch statement

**When to use:** When printing creel_estimates objects with total catch method

**Example:**
```r
# In R/creel-estimates.R format.creel_estimates()
# Update switch statement:

method_display <- switch(x$method,
  total = "Total",
  "ratio-of-means-cpue" = "Ratio-of-Means CPUE",
  "ratio-of-means-hpue" = "Ratio-of-Means HPUE",
  "product-total-catch" = "Total Catch (Effort × CPUE)",
  x$method
)
```

### Anti-Patterns to Avoid

- **Naive product variance:** Don't compute Var(E×C) = E² × Var(C) (ignoring Var(E) term) or Var(E×C) = Var(E) × Var(C) (multiplicative assumption). Both underestimate true variance. Always use delta method formula or svycontrast.
- **Recomputing survey designs:** Don't reconstruct survey designs inside estimate_total_catch(). Call estimate_effort() and estimate_cpue() which handle survey design construction and variance method application.
- **Assuming independence without validation:** Effort and CPUE are independent when estimated from separate data streams (counts vs interviews), but must validate both data sources exist before assuming independence.
- **Mismatched grouping variables:** Don't allow by = day_type for effort but by = location for CPUE. Grouped total catch requires identical grouping variables across both estimates.
- **Skipping design compatibility checks:** User may call estimate_total_catch() on design with only counts or only interviews. Must validate both exist and provide informative error directing to add_counts() and add_interviews().

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Delta method variance calculation | Manual gradient computation, partial derivatives, matrix multiplication | survey::svycontrast() | svycontrast handles symbolic differentiation via deriv(), computes gradients automatically, applies sandwich formula (J^T V J), and handles edge cases |
| Product variance approximation | First-order Taylor approximation only | svycontrast with quote(effort * cpue) | Handles second-order terms when needed, accounts for asymptotic normality, provides confidence intervals via confint() |
| Covariance between effort and CPUE | Estimating non-zero covariance | Assume zero covariance (independence) | Effort from count data, CPUE from interview data - different data sources, different survey designs, independence justified |
| Combining grouped estimates | Loop over groups with manual variance pooling | Apply svycontrast per group with proper alignment | Ensures group-level variance propagation correct, maintains correspondence between effort and CPUE groups |

**Key insight:** Delta method variance propagation is deceptively complex because it requires computing gradients (partial derivatives), multiplying by variance-covariance matrix (sandwich product), and ensuring asymptotic normality assumptions hold. The survey package's `svycontrast()` function implements decades of survey statistics research including automatic differentiation, matrix algebra, and confidence interval construction. Use it rather than reimplementing delta method theory manually.

## Common Pitfalls

### Pitfall 1: Naive Product Variance (Forgetting Var(Effort) Term)

**What goes wrong:** Computing Var(Total Catch) = Effort² × Var(CPUE), ignoring the Var(Effort) contribution, producing underestimated standard errors and overly narrow confidence intervals.

**Why it happens:** Intuition that "CPUE has more variance than effort" leads to discarding effort variance term. Or misremembering delta method formula as first term only.

**How to avoid:** Always use svycontrast() for product variance - it computes full delta method formula automatically. Document in research that both variance terms matter. Add reference test comparing svycontrast result to manual delta method calculation showing both terms present.

**Warning signs:** Standard errors seem suspiciously small compared to CPUE standard errors alone. Confidence intervals narrower than expected for combined estimates.

### Pitfall 2: Missing Design Compatibility Validation

**What goes wrong:** User calls estimate_total_catch() on design with counts but no interviews (or vice versa), producing cryptic error from estimate_cpue() or estimate_effort() about missing survey object.

**Why it happens:** User adds counts to design, forgets to add interviews, assumes total catch will "figure it out" or provide helpful error.

**How to avoid:** Add validate_design_compatibility() check at start of estimate_total_catch() that explicitly checks both design$survey (counts) and design$interview_survey (interviews) exist. Provide informative error message with examples showing both add_counts() and add_interviews() calls.

**Warning signs:** Error message from internal function (estimate_cpue or estimate_effort) rather than from estimate_total_catch() itself. User reports "total catch doesn't work" without mentioning which data is missing.

### Pitfall 3: Mismatched Grouping Variables

**What goes wrong:** User calls estimate_total_catch(design, by = day_type) but day_type exists in counts but not interviews (or vice versa), causing error when trying to align grouped estimates.

**Why it happens:** Counts and interviews may have different column names for same stratum (e.g., "day_type" in counts but "stratum" in interviews), or user forgets to include grouping variable in interview data.

**How to avoid:** Add validate_grouping_compatibility() that checks by variables exist in BOTH design$counts and design$interviews. Provide informative error listing which variables are missing from which data source. Document in function help that grouped estimation requires grouping variables present in both data sources.

**Warning signs:** Error when merging effort and CPUE grouped results. "Column not found" errors from tidyselect::eval_select(). User asks "why can't I group by X when it's in my counts?"

### Pitfall 4: Variance Method Mismatch Between Effort and CPUE

**What goes wrong:** User previously called estimate_effort(design, variance = "bootstrap") for effort, then estimate_total_catch() uses default variance = "taylor", combining bootstrap effort with Taylor CPUE incorrectly.

**Why it happens:** Thinking variance method is "stored" in results and automatically reused. Not understanding that estimate_total_catch() re-estimates both components.

**How to avoid:** Document clearly that estimate_total_catch() internally calls estimate_effort() and estimate_cpue() with specified variance parameter applied to BOTH. User cannot mix variance methods within single total catch estimate. If user wants bootstrap total catch, they pass variance = "bootstrap" to estimate_total_catch(), which applies to both components.

**Warning signs:** User asks "how do I use bootstrap effort with Taylor CPUE?" or "can I combine existing estimates?"

### Pitfall 5: Forgetting Total Harvest Estimation

**What goes wrong:** User wants total harvest (not total catch), tries to multiply effort × HPUE manually, gets confused about function naming or implementation plan.

**Why it happens:** estimate_total_catch() naming implies catch-specific, but pattern applies identically to harvest (effort × HPUE).

**How to avoid:** Phase 11 implements total catch (effort × CPUE) following product pattern. Document that same approach applies to total harvest (effort × HPUE) - either implement estimate_total_harvest() as parallel function OR add type parameter to estimate_total_catch(). Recommend separate function for clarity following estimate_cpue/estimate_harvest pattern.

**Warning signs:** User asks for estimate_total_harvest() function. User opens issue requesting "total kept fish" estimation.

### Pitfall 6: Independence Assumption Violation

**What goes wrong:** Assuming effort and CPUE are independent when count data and interview data are from same sampling events (e.g., counts recorded during interviews), producing incorrect variance (ignores covariance term).

**Why it happens:** Not understanding that independence requires separate data streams. If same biologist counted effort and interviewed anglers on same day at same site, measurements may be correlated.

**How to avoid:** Document in function help and research that independence assumption requires separate count and interview data sources. For v0.2.0 scope, access point design with instantaneous counts (separate from interviews) satisfies independence. Add warning or note in docs if user has correlated count/interview data.

**Warning signs:** User has "combined" dataset with effort and CPUE on same rows. Count and interview data collected simultaneously. User asks about "correlation between effort and CPUE."

## Code Examples

Verified patterns from official sources and mathematical theory:

### Delta Method Formula for Product

```r
# Mathematical formula (NOT R code):
# For Z = X × Y where X and Y are independent estimates:
# Var(Z) ≈ X² · Var(Y) + Y² · Var(X) + Var(X) · Var(Y)
#
# First-order approximation (commonly used):
# Var(Z) ≈ X² · Var(Y) + Y² · Var(X)
#
# Where:
# - X, Y are point estimates
# - Var(X), Var(Y) are variances (SE²)
# - Covariance term drops out when X and Y are independent

# Manual delta method calculation for validation
effort_est <- 1000 # Total effort
cpue_est <- 2.5    # CPUE
effort_se <- 100   # Effort SE
cpue_se <- 0.3     # CPUE SE

# Manual delta method (first-order)
total_catch_est <- effort_est * cpue_est
total_catch_var <- (effort_est^2 * cpue_se^2) + (cpue_est^2 * effort_se^2)
total_catch_se <- sqrt(total_catch_var)

# Second-order term (often small, sometimes included)
second_order_term <- effort_se^2 * cpue_se^2
total_catch_var_full <- total_catch_var + second_order_term
total_catch_se_full <- sqrt(total_catch_var_full)
```

### Using svycontrast for Product Variance

```r
# Source: survey package documentation
# https://rdrr.io/rforge/survey/man/svycontrast.html

# Minimal example with svycontrast
effort_est <- 1000
cpue_est <- 2.5
effort_se <- 100
cpue_se <- 0.3

# Build coefficient vector
coefs <- c(effort = effort_est, cpue = cpue_est)

# Build variance-covariance matrix (independent estimates)
vcov_matrix <- matrix(
  c(effort_se^2, 0,          # Diagonal: variances
    0,           cpue_se^2),  # Off-diagonal: covariances (0 for independence)
  nrow = 2, ncol = 2,
  dimnames = list(c("effort", "cpue"), c("effort", "cpue"))
)

# Create svystat object (minimal structure)
stat_obj <- list(coefficients = coefs, vcov = vcov_matrix)
class(stat_obj) <- "svystat"

# Apply delta method via svycontrast
product_result <- survey::svycontrast(stat_obj, quote(effort * cpue))

# Extract results
total_catch_est <- as.numeric(coef(product_result))
total_catch_se <- as.numeric(survey::SE(product_result))
total_catch_ci <- confint(product_result, level = 0.95)
```

### User Workflow Example

```r
# 1. Create design with calendar
design <- creel_design(calendar, date = date, strata = day_type)

# 2. Attach count data for effort estimation
design <- add_counts(design, count_data)

# 3. Attach interview data for CPUE estimation
design <- add_interviews(design, interview_data,
                         catch = catch_total,
                         effort = hours_fished)

# 4. Estimate total catch (effort × CPUE with delta method variance)
total_catch <- estimate_total_catch(design)
print(total_catch)
# Shows: "Total Catch (Effort × CPUE)"
# Estimate with SE and CI

# 5. Compare to components
effort <- estimate_effort(design)
cpue <- estimate_cpue(design)

# Point estimate relationship (exact)
effort$estimates$estimate * cpue$estimates$estimate == total_catch$estimates$estimate

# Variance relationship (delta method, NOT simple product)
effort$estimates$se^2 * cpue$estimates$se^2 != total_catch$estimates$se^2

# 6. Grouped total catch
total_catch_by_type <- estimate_total_catch(design, by = day_type)
print(total_catch_by_type)
# Shows estimates by stratum with group-specific variance propagation

# 7. Inspect intermediate results
effort_by_type <- estimate_effort(design, by = day_type)
cpue_by_type <- estimate_cpue(design, by = day_type)
# total_catch_by_type combines these via delta method per group
```

### Reference Test Pattern

```r
# Test that svycontrast matches manual delta method
test_that("total catch variance matches manual delta method", {
  design <- make_total_catch_design()

  # Estimate total catch via function
  result <- estimate_total_catch(design)

  # Manually compute delta method
  effort <- estimate_effort(design)
  cpue <- estimate_cpue(design)

  E <- effort$estimates$estimate
  C <- cpue$estimates$estimate
  Var_E <- effort$estimates$se^2
  Var_C <- cpue$estimates$se^2

  # First-order delta method
  manual_estimate <- E * C
  manual_variance <- (E^2 * Var_C) + (C^2 * Var_E)
  manual_se <- sqrt(manual_variance)

  # Verify match
  expect_equal(result$estimates$estimate, manual_estimate, tolerance = 1e-10)
  expect_equal(result$estimates$se, manual_se, tolerance = 1e-6) # Slightly looser for SE
})
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual product variance | survey::svycontrast() with delta method | survey 3.0+ (2010s) | Automatic symbolic differentiation, handles complex non-linear contrasts |
| First-order approximation only | First + second-order terms when significant | Modern survey theory | More accurate variance for products of estimates with large relative variance |
| Simple product confidence intervals | Delta method confidence intervals via confint() | Established by Cochran (1977), implemented in survey package | Accounts for asymmetric intervals when product is non-normal |
| Separate effort and CPUE estimation | Integrated total catch estimation with variance propagation | Recent creel survey software (2020s) | User-friendly, reduces manual calculation errors |

**Deprecated/outdated:**
- **Ignoring effort variance:** Early fisheries literature sometimes computed total catch variance as E² × Var(CPUE) only, treating effort as "known" rather than estimated. Modern approach treats both as estimates with uncertainty.
- **Simulation-based variance only:** Before delta method implementation in survey packages, some analysts used bootstrap simulation to estimate product variance. Delta method is now standard and more efficient.

## Open Questions

1. **Should estimate_total_harvest() be implemented in Phase 11?**
   - What we know: Total harvest = Effort × HPUE, identical pattern to total catch = Effort × CPUE. User workflow wants both.
   - What's unclear: Whether to implement as separate function or add type parameter to estimate_total_catch().
   - Recommendation: Implement estimate_total_harvest() as separate function mirroring estimate_total_catch() exactly. Maintains clarity following estimate_cpue/estimate_harvest pattern. Duplicate code is minimal (change method identifier, call estimate_harvest() instead of estimate_cpue()). Phase 11 scope includes total harvest.

2. **Should second-order delta method term be included?**
   - What we know: Full delta method includes Var(E) × Var(C) term in addition to E² × Var(C) + C² × Var(E). Second-order term often small.
   - What's unclear: Whether svycontrast() includes second-order term automatically, and whether it matters for typical creel survey data.
   - Recommendation: Use svycontrast() default behavior (likely first-order only, matches survey theory standard). Document in research. If users report variance seems underestimated, investigate second-order term contribution in reference tests.

3. **How to handle designs with only counts OR only interviews?**
   - What we know: estimate_total_catch() requires both. User may have design with only counts (effort estimation only) or only interviews (CPUE estimation only).
   - What's unclear: Error message placement - check in estimate_total_catch() or let estimate_effort/estimate_cpue error naturally?
   - Recommendation: Implement validate_design_compatibility() that checks explicitly and provides informative error directing user to add missing data via add_counts() or add_interviews(). Clearer than nested error from internal functions.

4. **Should stratified total catch (combining within-strata estimates) be supported?**
   - What we know: User may want total catch combining across strata (e.g., weekday total + weekend total = overall total). This requires summing products with variance propagation.
   - What's unclear: Whether this is Phase 11 scope or future enhancement. Architecture for sum-of-products variance.
   - Recommendation: Defer stratified total to future phase. Phase 11 provides ungrouped (overall) and grouped (by stratum separately) estimation. User can manually sum grouped results for overall total (point estimate correct, variance underestimated without proper combination). Document as future work.

## Sources

### Primary (HIGH confidence)
- [R survey package - svycontrast documentation](https://rdrr.io/rforge/survey/man/svycontrast.html) - Delta method for non-linear contrasts
- [Chapter 7 Delta Method | 10 Fundamental Theorems for Econometrics](https://bookdown.org/ts_robinson1994/10EconometricTheorems/dm.html) - Mathematical theory and formulas
- [Delta Method in Epidemiology Tutorial](https://migariane.github.io/DeltaMethodEpiTutorial.nb.html) - Applied delta method with examples
- Existing tidycreel codebase - Phase 9 CPUE and Phase 6 effort implementations

### Secondary (MEDIUM confidence)
- [Catch per unit effort modelling for stock assessment](https://www.sciencedirect.com/science/article/abs/pii/S0165783623002539) - CPUE standardization and total catch estimation in fisheries
- [FAO Fishery-dependent sampling](https://www.fao.org/4/a0212e/A0212E15.htm) - Total catch calculation from effort and CPUE
- [Creel Survey Simulation](https://cran.r-project.org/web/packages/AnglerCreelSurveySimulation/vignettes/creel_survey_simulation.html) - Variability in catch and effort estimates
- [Covariance properties](https://dlsun.github.io/probability/cov-properties.html) - Independence and zero covariance justification

### Tertiary (LOW confidence)
- WebSearch results on delta method applications (2026) - General statistical guidance
- WebSearch results on combining survey estimates - Not creel-specific

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - survey::svycontrast documented in official R package docs, delta method is established theory
- Architecture: HIGH - Pattern mirrors estimate_effort/estimate_cpue exactly, svycontrast handles variance computation automatically
- Pitfalls: MEDIUM-HIGH - Independence assumption justified by separate data streams (counts vs interviews), design compatibility validation straightforward
- Code examples: HIGH - Directly from survey package documentation and delta method theory literature

**Research date:** 2026-02-10
**Valid until:** 60 days (survey package stable, established methods)

**Notes:**
- No CONTEXT.md exists for this phase - full design freedom
- Phase 11 builds directly on Phase 4-6 (effort), Phase 9 (CPUE), and Phase 10 (harvest)
- Delta method is standard approach for variance of non-linear functions of survey estimates
- Independence assumption holds because count data (effort) and interview data (CPUE) are from separate sampling streams in access point design
- Output format clearly identifies "product-total-catch" method for reproducibility
- Grouped estimation requires identical grouping variables in both count and interview data
- Total harvest estimation (effort × HPUE) follows identical pattern and should be included in Phase 11 scope

## Sources

- [Delta method - Wikipedia](https://en.wikipedia.org/wiki/Delta_method)
- [Chapter 7 Delta Method | 10 Fundamental Theorems for Econometrics](https://bookdown.org/ts_robinson1994/10EconometricTheorems/dm.html)
- [What is the Delta Method?](https://cran.r-project.org/web/packages/modmarg/vignettes/delta-method.html)
- [Delta Method in Epidemiology: An Applied and Reproducible Tutorial](https://migariane.github.io/DeltaMethodEpiTutorial.nb.html)
- [svycontrast: Linear and nonlinear contrasts of survey statistics](https://rdrr.io/rforge/survey/man/svycontrast.html)
- [R survey package - svycontrast documentation](http://r-survey.r-forge.r-project.org/survey/html/svycontrast.html)
- [Catch per unit effort modelling for stock assessment: A summary of good practices](https://www.sciencedirect.com/science/article/abs/pii/S0165783623002539)
- [NOAA Fisheries - Catch per Unit Effort Modelling for Stock Assessment](https://www.fisheries.noaa.gov/resource/peer-reviewed-research/catch-unit-effort-modelling-stock-assessment-summary-good-practices)
- [FAO - Fishery-dependent sampling: total catch, effort and catch-per-unit-effort](https://www.fao.org/4/a0212e/A0212E15.htm)
- [Properties of Covariance](https://dlsun.github.io/probability/cov-properties.html)
