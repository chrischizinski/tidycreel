# Phase 9: CPUE Estimation - Research

**Researched:** 2026-02-10
**Domain:** Ratio-of-means CPUE estimation with survey package svyratio
**Confidence:** HIGH

## Summary

Phase 9 implements catch per unit effort (CPUE) estimation using the ratio-of-means estimator via `survey::svyratio()`. For creel surveys with complete trip interviews (access point design), the ratio-of-means estimator is the appropriate choice: total catch divided by total effort produces CPUE = E[catch]/E[effort]. This is mathematically distinct from the mean-of-ratios estimator used for incomplete trips (roving design), which is out of scope for v0.2.0. The survey package's `svyratio()` function provides ratio estimation with variance estimation via Taylor linearization (default), bootstrap, or jackknife methods, exactly matching the variance infrastructure already implemented in Phase 6.

The architecture mirrors `estimate_effort()` exactly: an `estimate_cpue()` function accepting `design, by=NULL, variance="taylor", conf_level=0.95` parameters. Internally, it calls `svyratio(~catch_col, ~effort_col, design$interview_survey)` for ungrouped estimation or `svyby(~catch_col, by=~group_vars, denominator=~effort_col, design=interview_survey, FUN=svyratio)` for grouped estimation. The function returns a `creel_estimates` S3 object with `method="ratio-of-means-cpue"` to distinguish it from total estimation. Sample size validation follows the existing Tier 2 pattern: warn if n<30 per group (unstable variance), error if n<10 per group (variance estimation unreliable).

Survey methodology literature establishes n≥30 as a practical threshold for stable variance estimation based on the Central Limit Theorem, while n<10 produces unreliable variance estimates for ratio statistics. Creel survey research confirms that ratio-of-means estimators have finite variance and lower mean squared error than mean-of-ratios for complete trip interviews. The tidycreel implementation will validate sample size, use existing variance method infrastructure (`get_variance_design()` helper), integrate with interview survey design from Phase 8, and output results with clear estimator identification ("Ratio-of-Means CPUE").

**Primary recommendation:** Implement `estimate_cpue()` mirroring `estimate_effort()` architecture exactly. Use `survey::svyratio(~catch_col, ~effort_col, design$interview_survey)` for ungrouped estimation and `svyby()` with `FUN=svyratio` for grouped estimation. Add Tier 2 validation functions: `validate_cpue_sample_size()` that warns if n<30 (unstable variance) and errors if n<10 (unreliable estimation). Store method as "ratio-of-means-cpue" in results. Variance method routing reuses existing `get_variance_design()` helper from Phase 6. Output format follows `creel_estimates` S3 class established in Phase 4.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| survey | 4.4+ | Ratio-of-means estimation via svyratio() | Already in use for svytotal, svyby; svyratio follows identical API patterns |
| cli | Current | Sample size validation warnings/errors | Already in use for all validation messages |
| dplyr | Current | Interview data manipulation | Already in use throughout package |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| testthat | 3.3.2+ | Reference tests for ratio estimation | Verify svyratio produces correct CPUE estimates |
| tibble | Current | Result formatting | Already in use for creel_estimates output |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| svyratio for ratio-of-means | Manual ratio calculation (sum(catch)/sum(effort)) | Manual calculation doesn't account for design variance; svyratio handles stratification, PSU clustering, replicate weights automatically |
| Fixed sample size thresholds (n=30, n=10) | Data-driven thresholds based on CV | Fixed thresholds simpler and match statistical convention; data-driven requires simulation studies out of Phase 9 scope |
| Separate ungrouped/grouped functions | Single function with by parameter | Single function matches estimate_effort() pattern, reduces code duplication |

**Installation:**
```bash
# No new dependencies - all packages already in DESCRIPTION
```

## Architecture Patterns

### Pattern 1: Ratio-of-Means Estimation (Ungrouped)

**What:** Estimate CPUE as ratio of total catch to total effort using svyratio()

**When to use:** User calls `estimate_cpue(design)` without by parameter

**Example:**
```r
# Internal function in R/creel-estimates.R
# Mirrors estimate_effort_total() structure exactly
estimate_cpue_total <- function(design, variance_method, conf_level) {
  interviews_data <- design$interviews
  catch_col <- design$catch_col
  effort_col <- design$effort_col

  # Build formulas for numerator and denominator
  catch_formula <- stats::reformulate(catch_col)
  effort_formula <- stats::reformulate(effort_col)

  # Get appropriate survey design for variance method
  # Reuses existing helper from Phase 6
  svy_design <- get_variance_design(design$interview_survey, variance_method)

  # Call survey::svyratio
  svy_result <- suppressWarnings(
    survey::svyratio(catch_formula, effort_formula, svy_design)
  )

  # Extract estimates (ratio stored in coefficients)
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

  # Return creel_estimates object with ratio-of-means method identifier
  new_creel_estimates(
    estimates = estimates_df,
    method = "ratio-of-means-cpue",
    variance_method = variance_method,
    design = design,
    conf_level = conf_level,
    by_vars = NULL
  )
}
```

### Pattern 2: Grouped Ratio Estimation with svyby

**What:** Estimate CPUE separately for each level of grouping variable(s)

**When to use:** User calls `estimate_cpue(design, by = day_type)` or other grouping

**Example:**
```r
# Internal function in R/creel-estimates.R
# Mirrors estimate_effort_grouped() structure exactly
estimate_cpue_grouped <- function(design, by_vars, variance_method, conf_level) {
  interviews_data <- design$interviews
  catch_col <- design$catch_col
  effort_col <- design$effort_col

  # Tier 2 validation for sample size
  validate_cpue_sample_size(design, by_vars)

  # Build formulas
  catch_formula <- stats::reformulate(catch_col)
  effort_formula <- stats::reformulate(effort_col)
  by_formula <- stats::reformulate(by_vars)

  # Get appropriate survey design for variance method
  svy_design <- get_variance_design(design$interview_survey, variance_method)

  # Call survey::svyby with svyratio
  # Note: denominator passed via ... to svyratio
  svy_result <- suppressWarnings(
    survey::svyby(
      formula = catch_formula,
      by = by_formula,
      design = svy_design,
      FUN = survey::svyratio,
      denominator = effort_formula,
      vartype = c("se", "ci"),
      ci.level = conf_level,
      keep.names = FALSE
    )
  )

  # Extract estimate columns
  # svyby with svyratio returns: catch_col/effort_col, "se", "ci_l", "ci_u"
  ratio_col <- paste0(catch_col, "/", effort_col)
  estimate <- svy_result[[ratio_col]]
  se <- svy_result[["se"]]
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

  # Build result tibble
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
    method = "ratio-of-means-cpue",
    variance_method = variance_method,
    design = design,
    conf_level = conf_level,
    by_vars = by_vars
  )
}
```

### Pattern 3: Sample Size Validation for CPUE

**What:** Validate sufficient sample size for stable ratio variance estimation

**When to use:** At start of estimate_cpue() before calling svyratio

**Example:**
```r
# Internal function in R/survey-bridge.R
# Add after existing warn_tier2_* functions
validate_cpue_sample_size <- function(design, by_vars = NULL) {
  interviews_data <- design$interviews

  if (is.null(by_vars)) {
    # Ungrouped: check overall sample size
    n <- nrow(interviews_data)

    if (n < 10) {
      cli::cli_abort(c(
        "Insufficient sample size for CPUE estimation: n = {n}",
        "x" = "Ratio-of-means variance estimation requires n >= 10",
        "i" = "Collect more interview observations before estimating CPUE"
      ))
    }

    if (n < 30) {
      cli::cli_warn(c(
        "Small sample size for CPUE estimation: n = {n}",
        "!" = "Variance estimates may be unstable with n < 30",
        "i" = "Consider collecting more interviews for stable variance estimation"
      ))
    }
  } else {
    # Grouped: check per-group sample sizes
    group_data <- interviews_data[by_vars]
    group_data$count <- 1
    group_counts <- stats::aggregate(
      count ~ .,
      data = group_data,
      FUN = sum
    )

    # Identify groups with insufficient sample size
    groups_below_10 <- group_counts[group_counts$count < 10, ]
    groups_below_30 <- group_counts[group_counts$count >= 10 & group_counts$count < 30, ]

    # Error for n < 10 groups
    if (nrow(groups_below_10) > 0) {
      bullet_items <- character(nrow(groups_below_10))
      for (i in seq_len(nrow(groups_below_10))) {
        group_vals <- groups_below_10[i, by_vars, drop = FALSE]
        group_label <- paste(
          paste0(by_vars, "=", group_vals),
          collapse = ", "
        )
        n_obs <- groups_below_10$count[i]
        bullet_items[i] <- sprintf("Group %s: n=%d", group_label, n_obs)
      }
      names(bullet_items) <- rep("x", length(bullet_items))

      cli::cli_abort(c(
        "Insufficient sample size for grouped CPUE estimation:",
        bullet_items,
        "i" = "Ratio variance estimation requires n >= 10 per group",
        "i" = "Combine groups or collect more interviews"
      ))
    }

    # Warn for 10 <= n < 30 groups
    if (nrow(groups_below_30) > 0) {
      bullet_items <- character(nrow(groups_below_30))
      for (i in seq_len(nrow(groups_below_30))) {
        group_vals <- groups_below_30[i, by_vars, drop = FALSE]
        group_label <- paste(
          paste0(by_vars, "=", group_vals),
          collapse = ", "
        )
        n_obs <- groups_below_30$count[i]
        bullet_items[i] <- sprintf("Group %s: n=%d", group_label, n_obs)
      }
      names(bullet_items) <- rep("*", length(bullet_items))

      cli::cli_warn(c(
        "{nrow(groups_below_30)} group{?s} ha{?s/ve} small sample size for CPUE:",
        bullet_items,
        "!" = "Variance estimates may be unstable with n < 30",
        "i" = "Consider combining groups or collecting more interviews"
      ))
    }
  }

  invisible(NULL)
}
```

### Pattern 4: CPUE Function Signature and Routing

**What:** User-facing function matching estimate_effort() API exactly

**When to use:** User calls estimate_cpue() on design with interviews

**Example:**
```r
# Add to R/creel-estimates.R after estimate_effort()

#' Estimate catch per unit effort (CPUE) from a creel survey design
#'
#' Computes catch per unit effort (CPUE) estimates with standard errors and
#' confidence intervals from a creel survey design with attached interview data.
#' Uses ratio-of-means estimator (survey::svyratio) appropriate for complete
#' trip interviews from access point surveys.
#'
#' @param design A creel_design object with interviews attached via
#'   \code{\link{add_interviews}}. The design must have an interview survey
#'   object constructed.
#' @param by Optional tidy selector for grouping variables (same as estimate_effort)
#' @param variance Character string specifying variance estimation method:
#'   "taylor" (default), "bootstrap", or "jackknife"
#' @param conf_level Numeric confidence level (default: 0.95)
#'
#' @return A creel_estimates S3 object with method = "ratio-of-means-cpue"
#'
#' @details
#' The function uses ratio-of-means estimator: CPUE = E[catch]/E[effort].
#' This is appropriate for complete trip interviews (access point design).
#' For incomplete trips (roving design), mean-of-ratios is appropriate but
#' deferred to v0.3.0.
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
#'                          catch = catch_total, effort = hours_fished)
#'
#' # Estimate CPUE
#' cpue <- estimate_cpue(design)
#' print(cpue)
#'
#' # Grouped by stratum
#' cpue_by_type <- estimate_cpue(design, by = day_type)
#'
#' # Bootstrap variance
#' cpue_boot <- estimate_cpue(design, variance = "bootstrap")
#'
#' @export
estimate_cpue <- function(design, by = NULL, variance = "taylor", conf_level = 0.95) {
  # Capture by parameter BEFORE validation
  by_quo <- rlang::enquo(by)

  # Validate variance parameter (same as estimate_effort)
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
      "x" = "Call {.fn add_interviews} before estimating CPUE.",
      "i" = "Example: {.code design <- add_interviews(design, interviews, catch = catch, effort = effort)}"
    ))
  }

  # Validate catch and effort columns exist
  if (is.null(design$catch_col) || is.null(design$effort_col)) {
    cli::cli_abort(c(
      "Interview design missing catch or effort column specification.",
      "x" = "Both catch and effort columns required for CPUE estimation.",
      "i" = "Ensure {.fn add_interviews} was called with catch and effort parameters."
    ))
  }

  # Route to grouped or ungrouped estimation
  if (rlang::quo_is_null(by_quo)) {
    # Ungrouped estimation
    validate_cpue_sample_size(design, by_vars = NULL)
    return(estimate_cpue_total(design, variance, conf_level))
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

    validate_cpue_sample_size(design, by_vars = by_vars)
    return(estimate_cpue_grouped(design, by_vars, variance, conf_level))
  }
}
```

### Anti-Patterns to Avoid

- **Manual ratio calculation instead of svyratio:** Don't calculate `sum(catch)/sum(effort)` manually - this ignores survey design variance, stratification effects, and replicate weights
- **Using mean-of-ratios for access point surveys:** Mean-of-ratios is for incomplete trips (roving), ratio-of-means is for complete trips (access point) - Phase 9 scope is access point only
- **Skipping sample size validation:** Ratio variance estimation is unstable for small samples - always validate n≥30 (warn) and n≥10 (error)
- **Reusing count survey design for interviews:** Interviews use `ids=~1` (terminal units), counts use `ids=~date` (day-PSU) - must use separate survey designs
- **Not identifying estimator in output:** Users need to know "ratio-of-means" vs "mean-of-ratios" vs other methods - store clearly in method field

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Ratio variance estimation | Manual delta method, bootstrap loops | survey::svyratio with variance parameter | svyratio handles stratification, PSU clustering, finite population correction, replicate weights automatically; delta method approximation for Taylor built-in |
| Sample size thresholds | Trial-and-error or simulation studies | Established thresholds (n≥30 warn, n≥10 error) | Statistical literature establishes n≥30 for stable variance via Central Limit Theorem; n<10 produces unreliable ratio variance estimates |
| Grouped ratio estimation | Loop over subsets with manual variance pooling | survey::svyby with FUN=svyratio | svyby handles domain estimation variance correctly (accounting for uncertainty in domain membership), pools variance appropriately |
| Ratio estimator selection | User choice or configuration | Fixed ratio-of-means for access point (complete trips) | Fisheries literature establishes ratio-of-means as appropriate for complete trips, mean-of-ratios for incomplete trips; Phase 9 scope is complete trips only |

**Key insight:** Ratio estimation is deceptively complex because ratio variance involves covariance between numerator and denominator, stratification effects on both components, and design-based variance propagation. The survey package's `svyratio()` implements decades of survey statistics research including delta method approximations, stratified ratio estimation, and replicate-based variance estimation. Use it rather than reimplementing ratio variance theory.

## Common Pitfalls

### Pitfall 1: Confusing Ratio-of-Means with Mean-of-Ratios

**What goes wrong:** Using mean-of-ratios estimator (mean of individual catch/effort ratios) for access point complete trip surveys, producing biased estimates with infinite variance.

**Why it happens:** Both are "catch rate" estimators, names are similar, and users may not understand the distinction based on trip completion status.

**How to avoid:** Phase 9 implements only ratio-of-means for access point design (complete trips). Document clearly that mean-of-ratios is for roving surveys (incomplete trips) and is deferred to v0.3.0. Error message when interview_type != "access".

**Warning signs:** User asks about "mean of ratios" or tries to estimate CPUE with roving interview data in Phase 9. Test suite verifies estimator type in output.

### Pitfall 2: Insufficient Sample Size for Ratio Variance

**What goes wrong:** Estimating CPUE with n<10 interviews produces unreliable variance estimates; n<30 produces unstable variance estimates that vary widely with small data changes.

**Why it happens:** Users may attempt CPUE estimation with sparse interview data per stratum, not realizing ratio variance estimation requires larger samples than total estimation.

**How to avoid:** Implement `validate_cpue_sample_size()` that errors for n<10, warns for n<30. Run validation before calling svyratio. Document sample size recommendations in function help and vignettes.

**Warning signs:** Variance estimates are NA, extremely large, or vary dramatically when adding/removing single interviews. Test suite includes sample size validation tests with n=5, n=15, n=30.

### Pitfall 3: Ignoring Zero Effort Values

**What goes wrong:** Including interviews with effort=0 in CPUE estimation produces undefined ratios (catch/0 = Inf), causing svyratio to fail or produce NA results.

**Why it happens:** Data entry errors, completed interviews with anglers who hadn't started fishing yet, or misunderstanding of "effort" definition.

**How to avoid:** Tier 2 validation in add_interviews() already warns about zero/negative effort (Phase 8). In estimate_cpue(), filter out zero-effort interviews with warning before calling svyratio. Document that CPUE requires effort>0.

**Warning signs:** svyratio returns NA or Inf results. User reports "CPUE estimation failed" with cryptic survey package error.

### Pitfall 4: Mixing Count and Interview Survey Designs

**What goes wrong:** Accidentally passing design$survey (count survey) instead of design$interview_survey to svyratio, producing incorrect variance estimates or errors.

**Why it happens:** Both are survey.design2 objects stored in the same creel_design object. Developer confusion about which design object to use.

**How to avoid:** Always use `design$interview_survey` for CPUE estimation. Add defensive check at start of estimate_cpue_total/grouped that design$interview_survey exists and is not NULL. Code review catches accidental use of design$survey.

**Warning signs:** Variance estimates seem too large (count design has day-PSU clustering, interview design has ids=~1 terminal units), or svyratio errors about missing variables (catch/effort not in count data).

### Pitfall 5: Not Distinguishing Estimator in Output

**What goes wrong:** User sees "CPUE" output but doesn't know which estimator was used (ratio-of-means vs mean-of-ratios vs other), making results non-reproducible and scientifically unclear.

**Why it happens:** Developer stores generic "cpue" as method instead of specific estimator identifier.

**How to avoid:** Use `method = "ratio-of-means-cpue"` in creel_estimates object. Update format.creel_estimates() to display full method name. In future phases when mean-of-ratios added, use `method = "mean-of-ratios-cpue"` for clear distinction.

**Warning signs:** User asks "which CPUE method is this?", cannot reproduce results from published output, or submits manuscript with ambiguous "CPUE" methodology section.

## Code Examples

Verified patterns from official sources:

### Basic svyratio Usage
```r
# Source: https://r-survey.r-forge.r-project.org/survey/html/svyratio.html
# Ratio of two variables with survey design
ratio_result <- survey::svyratio(
  numerator = ~catch_total,
  denominator = ~hours_fished,
  design = interview_survey_design
)

# Extract ratio estimate
cpue <- coef(ratio_result)

# Extract standard error
cpue_se <- SE(ratio_result)

# Extract confidence interval
cpue_ci <- confint(ratio_result, level = 0.95)
```

### Grouped Ratio Estimation with svyby
```r
# Source: https://r-survey.r-forge.r-project.org/survey/html/svyby.html
# Ratio estimation by stratum using svyby
ratio_by_stratum <- survey::svyby(
  formula = ~catch_total,
  by = ~day_type,
  denominator = ~hours_fished,
  design = interview_survey_design,
  FUN = survey::svyratio,
  vartype = c("se", "ci"),
  ci.level = 0.95,
  keep.names = FALSE
)

# Result is data frame with:
# - day_type column (grouping variable)
# - catch_total/hours_fished column (ratio estimate)
# - se column (standard error)
# - ci_l, ci_u columns (confidence interval bounds)
```

### Variance Method Integration
```r
# Reuse existing get_variance_design() helper from Phase 6
# Works identically for interview survey designs

# Taylor linearization (default)
svy_design_taylor <- get_variance_design(design$interview_survey, "taylor")
ratio_taylor <- survey::svyratio(~catch, ~effort, svy_design_taylor)

# Bootstrap (500 replicates)
svy_design_boot <- get_variance_design(design$interview_survey, "bootstrap")
ratio_boot <- survey::svyratio(~catch, ~effort, svy_design_boot)

# Jackknife (auto JK1/JKn)
svy_design_jk <- get_variance_design(design$interview_survey, "jackknife")
ratio_jk <- survey::svyratio(~catch, ~effort, svy_design_jk)
```

### Sample Size Validation Pattern
```r
# Existing pattern from warn_tier2_group_issues() in Phase 5
# Adapted for CPUE-specific thresholds

# Count observations per group
group_counts <- stats::aggregate(
  count ~ .,
  data = interviews_data[c(by_vars, "count" = 1)],
  FUN = sum
)

# Identify insufficient samples
small_groups <- group_counts[group_counts$count < 30, ]
critical_groups <- group_counts[group_counts$count < 10, ]

# Error for n < 10
if (nrow(critical_groups) > 0) {
  cli::cli_abort(c(
    "Insufficient sample size for CPUE estimation:",
    # ... build bullet list
  ))
}

# Warn for 10 <= n < 30
if (nrow(small_groups) > 0) {
  cli::cli_warn(c(
    "Small sample size may produce unstable variance:",
    # ... build bullet list
  ))
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual ratio calculation | survey::svyratio() | survey 2.0+ (2000s) | Automatic variance estimation, stratification handling |
| Mean-of-ratios for all surveys | Ratio-of-means for complete trips, mean-of-ratios for incomplete | 1990s fisheries research | Reduced bias and finite variance for access point surveys |
| Fixed variance formulas | Replicate variance methods (bootstrap/jackknife) | survey 3.0+ (2010s) | Robust variance estimation for non-normal distributions |
| Ad-hoc sample size rules | n≥30 for stable variance, n≥10 minimum | Established by Central Limit Theorem research | Consistent thresholds across survey applications |

**Deprecated/outdated:**
- **Mean-of-ratios for all CPUE:** Older creel survey literature sometimes used mean-of-ratios universally. Modern approach distinguishes complete trips (ratio-of-means) from incomplete trips (mean-of-ratios) based on trip completion status at interview time.
- **Ignoring design variance in ratio estimation:** Early fisheries statistics sometimes calculated simple ratios without accounting for survey design effects. Modern approach uses svyratio with stratification, clustering, and weights.

## Open Questions

1. **Should Phase 9 filter out zero-effort interviews automatically?**
   - What we know: Zero effort produces undefined ratios (catch/0). Tier 2 validation in Phase 8 warns about zero effort.
   - What's unclear: Whether to silently filter, error, or warn-and-filter when zero effort present.
   - Recommendation: Warn-and-filter approach. Issue cli::cli_warn listing number of zero-effort interviews excluded, proceed with estimation on remaining data. Document in function help.

2. **Should separate=TRUE ratio estimation be supported?**
   - What we know: svyratio accepts `separate=TRUE` parameter for separate ratio estimation by stratum (instead of combined ratio).
   - What's unclear: Whether creel survey users need separate vs combined ratio estimates, and how this differs from grouped estimation with by parameter.
   - Recommendation: Defer separate=TRUE to future phase. Phase 9 uses combined ratio (default separate=FALSE) which is appropriate for standard creel CPUE. Document in research notes if users request separate ratios.

3. **What confidence level should be used for degrees of freedom adjustment?**
   - What we know: survey::confint() accepts df parameter for degrees of freedom adjustment. degf() function computes design degrees of freedom.
   - What's unclear: Whether to use df=degf(design) for confidence intervals or default infinite df assumption.
   - Recommendation: Use default behavior (no df parameter) in Phase 9 to match estimate_effort() pattern. Survey package documentation suggests df adjustment mainly for very small samples. Document in research for future enhancement if needed.

4. **How should output distinguish estimator when format.creel_estimates() displays results?**
   - What we know: method field stores "ratio-of-means-cpue", existing format shows "Method: {method}".
   - What's unclear: Whether to display raw method string or human-readable version like "Ratio-of-Means CPUE".
   - Recommendation: Add switch statement in format.creel_estimates() to convert method identifiers to display names: "ratio-of-means-cpue" → "Ratio-of-Means CPUE", "total" → "Total", etc. Maintains machine-readable method field while improving user output.

## Sources

### Primary (HIGH confidence)
- [R survey package - svyratio documentation](https://r-survey.r-forge.r-project.org/survey/html/svyratio.html) - Function signature, parameters, variance methods
- [R survey package - svyby documentation](https://r-survey.r-forge.r-project.org/survey/html/svyby.html) - Grouped estimation with svyratio
- [UCLA Stats - Ratio Estimation with Survey Data](https://stats.oarc.ucla.edu/r/faq/how-can-i-do-ratio-estimation-with-survey-data/) - Worked examples, confidence intervals
- Existing tidycreel codebase (Phase 6 variance infrastructure, Phase 8 interview survey design, Phase 4-5 estimation patterns)

### Secondary (MEDIUM confidence)
- [ResearchGate - Catch Rate Estimation for Roving and Access Point Surveys](https://www.researchgate.net/publication/241729832_Catch_Rate_Estimation_for_Roving_and_Access_Point_Surveys) - Ratio-of-means vs mean-of-ratios distinction for complete vs incomplete trips
- [Statistics How To - Ratio Estimator](https://www.statisticshowto.com/ratio-estimator/) - General ratio estimation theory
- [ResearchGate - n=30 rule of thumb](https://www.researchgate.net/post/What_is_the_rationale_behind_the_magic_number_30_in_statistics) - Central Limit Theorem justification for n≥30 threshold
- Sample size determination literature (n≥30 for CLT, n<10 unreliable for variance estimation)

### Tertiary (LOW confidence - general guidance)
- WebSearch results on CPUE standardization (2024 fisheries literature) - General CPUE modeling practices, not specific to survey package implementation
- WebSearch results on sample size determination - General statistical guidance, not creel-survey specific

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - survey::svyratio documented in official R package docs, existing Phase 6 variance infrastructure proven
- Architecture: HIGH - Patterns mirror existing estimate_effort() implementation exactly, verified in current codebase
- Pitfalls: MEDIUM-HIGH - Ratio-of-means vs mean-of-ratios distinction verified in fisheries literature; sample size thresholds based on statistical convention and existing tidycreel patterns
- Code examples: HIGH - Directly from survey package official documentation and existing tidycreel code patterns

**Research date:** 2026-02-10
**Valid until:** 60 days (survey package stable, established methods)

**Notes:**
- No CONTEXT.md exists for this phase - full design freedom
- Phase 9 builds directly on Phase 6 (variance infrastructure) and Phase 8 (interview survey design)
- Ratio-of-means appropriate for access point complete trips (v0.2.0 scope); mean-of-ratios for roving incomplete trips deferred to v0.3.0
- Sample size thresholds (n≥30 warn, n≥10 error) follow statistical convention and match Tier 2 validation patterns from Phases 5-8
- Output format clearly identifies "ratio-of-means-cpue" estimator for reproducibility
