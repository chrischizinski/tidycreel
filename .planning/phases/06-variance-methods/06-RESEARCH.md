# Phase 6: Variance Methods - Research

**Researched:** 2026-02-09
**Domain:** Survey variance estimation methods (bootstrap, jackknife, Taylor linearization)
**Confidence:** HIGH

## Summary

Phase 6 implements variance method selection in `estimate_effort()` through a `variance =` parameter, enabling users to choose between Taylor linearization (current default), bootstrap, and jackknife variance estimation. The R survey package provides replicate weight designs via `as.svrepdesign()` that convert a standard `svydesign` object into replication-based variance estimation. Bootstrap and jackknife methods are particularly valuable for non-smooth statistics (quantiles, medians) and when Taylor linearization assumptions may not hold, though they require more computation and careful selection of replication parameters.

The architecture follows a clean pattern: `estimate_effort()` accepts `variance = "taylor"` (default), `variance = "bootstrap"`, or `variance = "jackknife"`. For replicate methods, an internal helper converts `design$survey` to a replicate-weight design using `as.svrepdesign()` before calling `svytotal()`/`svyby()`. All downstream code remains unchanged because replicate designs work with the same survey package functions. The variance method used is stored in `creel_estimates$variance_method` for reproducibility.

Bootstrap methods require specifying the number of replicates (typically 500-5000 depending on precision needs) and work well for stratified designs when applied separately within each stratum. Jackknife methods (JK1 for unstratified, JKn for stratified) automatically determine replicate count from the design structure. For creel surveys with instantaneous counts and stratified day-type designs, bootstrap methods offer more flexibility but require more replicates, while jackknife provides faster computation with fewer replicates but may be unstable for small sample sizes or non-smooth statistics.

**Primary recommendation:** Implement variance method selection through a `variance =` parameter with values "taylor" (default), "bootstrap", and "jackknife". Use `as.svrepdesign(design$survey, type = "bootstrap", replicates = 500)` for bootstrap and `as.svrepdesign(design$survey, type = "auto")` for jackknife (auto-selects JK1 or JKn based on stratification). Store method in result attributes. Add reference tests comparing replicate methods to Taylor for stable statistics to verify correctness. Warn users that bootstrap/jackknife are slower and require more memory than Taylor.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| survey | 4.4+ | Replicate weight variance estimation | Already in use; as.svrepdesign() converts designs to bootstrap/jackknife |
| cli | Current | User warnings about computational costs | Already in use for error/warning messages |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| testthat | 3.3.2+ | Reference tests for variance methods | Verify bootstrap/jackknife produce reasonable results |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| survey as.svrepdesign | svrep package enhanced methods | svrep adds advanced methods (Rao-Wu-Yue-Beaumont) but adds dependency; survey's built-in methods sufficient for Phase 6 |
| Fixed replicate count | User-specified replicates parameter | Fixed count (500) simpler for users; advanced users can use as_survey_design() escape hatch if needed |
| BRR/Fay methods | Bootstrap/jackknife only | BRR requires paired PSU design; not applicable to creel day-based sampling |

**Installation:**
```bash
# No new dependencies - all packages already in DESCRIPTION
```

## Architecture Patterns

### Pattern 1: Variance Method Routing

**What:** Route to appropriate survey design based on variance parameter

**When to use:** At start of `estimate_effort()` and `estimate_effort_grouped()` after validation

**Example:**
```r
# Internal helper function in R/survey-bridge.R
get_variance_design <- function(design, variance_method, replicates = 500) {
  # For Taylor linearization, use original design
  if (variance_method == "taylor") {
    return(design$survey)
  }

  # For replicate methods, convert using as.svrepdesign
  if (variance_method == "bootstrap") {
    # Convert to bootstrap replicate design
    # Suppress survey package warnings about singleton PSUs (handled in Tier 2)
    suppressWarnings(
      survey::as.svrepdesign(
        design$survey,
        type = "bootstrap",
        replicates = replicates
      )
    )
  } else if (variance_method == "jackknife") {
    # Auto-select JK1 (unstratified) or JKn (stratified)
    suppressWarnings(
      survey::as.svrepdesign(
        design$survey,
        type = "auto"
      )
    )
  } else {
    cli::cli_abort(c(
      "Unknown variance method: {.val {variance_method}}",
      "i" = "Supported: {.val taylor}, {.val bootstrap}, {.val jackknife}"
    ))
  }
}

# Usage in estimate_effort_total()
estimate_effort_total <- function(design, variance_method, conf_level) {
  # Get appropriate design for variance method
  svy_design <- get_variance_design(design, variance_method)

  # Rest of estimation code unchanged - works with any design type
  count_formula <- stats::reformulate(count_var)
  svy_result <- suppressWarnings(survey::svytotal(count_formula, svy_design))
  # ... extract results as before
}
```

### Pattern 2: Variance Method Parameter Validation

**What:** Validate variance parameter and provide helpful errors

**When to use:** In `estimate_effort()` signature and parameter validation

**Example:**
```r
estimate_effort <- function(design, by = NULL, variance = "taylor", conf_level = 0.95) {
  # Capture by parameter
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

  # Validate design class
  if (!inherits(design, "creel_design")) {
    cli::cli_abort(c(
      "{.arg design} must be a {.cls creel_design} object.",
      "x" = "{.arg design} is {.cls {class(design)[1]}}.",
      "i" = "Create a design with {.fn creel_design}."
    ))
  }

  # ... rest of function
}
```

### Pattern 3: Replicate Method Performance Warnings

**What:** Warn users about computational costs of bootstrap/jackknife

**When to use:** When variance != "taylor", issue once-per-session warning

**Example:**
```r
# In estimate_effort() after variance validation
if (variance %in% c("bootstrap", "jackknife")) {
  rlang::warn(
    message = c(
      "Using {variance} variance estimation.",
      "i" = "Replicate methods are slower than Taylor linearization.",
      "i" = "Bootstrap uses 500 replicates by default.",
      "i" = "Jackknife replicate count depends on design structure."
    ),
    .frequency = "once",
    .frequency_id = paste0("tidycreel_variance_", variance)
  )
}
```

### Anti-Patterns to Avoid

- **Exposing replicates parameter in Phase 6:** Keep it simple with fixed defaults. Advanced users can use `as_survey_design()` escape hatch for custom replicate designs.
- **Supporting BRR/Fay in Phase 6:** These require specific design structures (paired PSUs) not typical in creel surveys. Defer to future phases if needed.
- **Changing default from taylor to bootstrap:** Bootstrap is more computationally expensive; taylor is appropriate default for most use cases.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Bootstrap variance calculation | Manual resampling loops with for() | survey::as.svrepdesign(type = "bootstrap") | Survey package handles stratification, PSU resampling, weight scaling, edge cases (lonely PSUs) |
| Jackknife replication | Custom delete-one-PSU logic | survey::as.svrepdesign(type = "auto" or "JKn") | Auto-detection of stratification, proper variance scaling factors |
| Replicate count selection | Arbitrary numbers (100, 1000) | survey package defaults (auto for jackknife, 500+ for bootstrap) | Package defaults based on statistical research; bootstrap needs enough replicates for stable CV |
| Variance method validation | String matching with if/else chains | Match against named vector with cli::cli_abort | Centralized validation with helpful error messages |

**Key insight:** Replicate variance estimation is deceptively complex due to stratification interactions, scaling factors, and edge cases. The survey package's `as.svrepdesign()` encapsulates decades of survey statistics research. Use it rather than reimplementing replication logic.

## Common Pitfalls

### Pitfall 1: Too Few Bootstrap Replicates

**What goes wrong:** Bootstrap variance estimates are unstable or systematically biased when using too few replicates (e.g., 50-100).

**Why it happens:** Bootstrap variance has simulation error proportional to 1/√B where B = number of replicates. Users may choose low counts to save computation time.

**How to avoid:** Use at least 500 replicates for bootstrap (survey package recommendation). For critical analyses, consider 1000+ replicates.

**Warning signs:** Bootstrap variance estimates change substantially when re-run (different random seed), or differ dramatically from Taylor linearization for smooth statistics like totals/means.

### Pitfall 2: Jackknife with Sparse Strata

**What goes wrong:** Jackknife variance estimation fails or produces NA values when strata have too few PSUs.

**Why it happens:** Jackknife requires deleting one PSU at a time. Strata with 1 PSU (lonely PSU) or 2 PSUs produce undefined or unstable variance estimates.

**How to avoid:** Use Tier 2 validation to warn about sparse strata (< 3 PSUs per stratum). Recommend combining strata or using Taylor linearization for small samples.

**Warning signs:** Error from `as.svrepdesign()` about singleton PSUs, or jackknife variance estimates much larger than Taylor.

### Pitfall 3: Assuming Bootstrap Always Better

**What goes wrong:** Users assume bootstrap is more "robust" or "accurate" than Taylor and use it by default.

**Why it happens:** Bootstrap has strong reputation in general statistics. Users may not understand that for smooth statistics (totals, means) and well-behaved designs, Taylor is both faster and asymptotically equivalent.

**How to avoid:** Default to `variance = "taylor"`. Document that bootstrap/jackknife are primarily useful for non-smooth statistics (quantiles, medians) or when verifying Taylor assumptions.

**Warning signs:** Users specify `variance = "bootstrap"` for all calls without justification, or complain about slow performance.

### Pitfall 4: Mixing Variance Methods in Comparisons

**What goes wrong:** Comparing estimates from the same data but different variance methods and interpreting SE differences as data quality issues.

**Why it happens:** Different variance methods have different simulation/approximation error. Small differences in SE are expected, not indicative of problems.

**How to avoid:** Use the same variance method for all estimates being compared. Document which method was used in analysis reports.

**Warning signs:** User reports "different results" when only difference is SE, or creates tables mixing Taylor and bootstrap SEs without labeling method.

## Code Examples

Verified patterns from official sources:

### Converting to Bootstrap Design
```r
# Source: https://r-survey.r-forge.r-project.org/survey/html/as.svrepdesign.html
# Convert existing svydesign to bootstrap replicate design
bootstrap_design <- as.svrepdesign(
  design$survey,
  type = "bootstrap",
  replicates = 500  # 500-5000 recommended for stable estimates
)

# Use with svytotal - same interface as original design
result <- survey::svytotal(~count_var, bootstrap_design)
```

### Converting to Jackknife Design
```r
# Source: https://r-survey.r-forge.r-project.org/survey/html/as.svrepdesign.html
# Auto-select JK1 (unstratified) or JKn (stratified)
jackknife_design <- as.svrepdesign(
  design$survey,
  type = "auto"
)

# Or explicitly choose JKn for stratified
jackknife_design <- as.svrepdesign(
  design$survey,
  type = "JKn"
)

# Use with svytotal
result <- survey::svytotal(~count_var, jackknife_design)
```

### Variance Method Routing in estimate_effort
```r
# Full implementation pattern for estimate_effort_total
estimate_effort_total <- function(design, variance_method, conf_level) {
  counts_data <- design$counts

  # Identify count variable (same logic as Phase 4)
  excluded_cols <- c(design$date_col, design$strata_cols, design$psu_col)
  numeric_cols <- names(counts_data)[sapply(counts_data, is.numeric)]
  count_vars <- setdiff(numeric_cols, excluded_cols)
  count_var <- count_vars[1]

  # Get appropriate design for variance method
  svy_design <- get_variance_design(design, variance_method)

  # Create formula and estimate (unchanged from Phase 4)
  count_formula <- stats::reformulate(count_var)
  svy_result <- suppressWarnings(survey::svytotal(count_formula, svy_design))

  # Extract results (unchanged from Phase 4)
  estimate <- as.numeric(coef(svy_result))
  se <- as.numeric(survey::SE(svy_result))
  ci <- confint(svy_result, level = conf_level)
  ci_lower <- ci[1, 1]
  ci_upper <- ci[1, 2]
  n <- nrow(counts_data)

  # Build estimates tibble
  estimates_df <- tibble::tibble(
    estimate = estimate,
    se = se,
    ci_lower = ci_lower,
    ci_upper = ci_upper,
    n = n
  )

  # Return with variance_method stored
  new_creel_estimates(
    estimates = estimates_df,
    method = "total",
    variance_method = variance_method,  # Store the method used
    design = design,
    conf_level = conf_level,
    by_vars = NULL
  )
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual bootstrap loops | survey::as.svrepdesign() | survey 3.0+ (2010s) | Stratification-aware resampling, proper scaling factors |
| Fixed JK1 for all designs | type = "auto" auto-selection | survey 4.0+ | Correct jackknife method (JK1 vs JKn) based on design |
| Hard-coded 1000 replicates | Data-driven replicate selection | svrep package (2020s) | Estimate simulation error, choose replicates for target precision |
| BRR for all stratified designs | Bootstrap/jackknife for flexible designs | Ongoing | BRR requires paired PSUs; modern methods handle arbitrary designs |

**Deprecated/outdated:**
- **Hard-coded replicate counts below 500:** Modern recommendation is 500-5000 for bootstrap based on simulation error research. Old tutorials often showed 100 replicates for speed, producing unstable estimates.
- **Jackknife for quantiles/medians:** Jackknife performs poorly for non-smooth statistics. Bootstrap is preferred for quantiles, though neither is needed in Phase 6 (totals only).

## Open Questions

1. **Should Phase 6 expose a replicates parameter for bootstrap?**
   - What we know: More replicates = better precision but slower computation. Survey package default is auto-determined.
   - What's unclear: Whether creel survey users need control over replicate count, or if fixed default (500) is sufficient.
   - Recommendation: Use fixed 500 replicates in Phase 6. Advanced users can use `as_survey_design()` escape hatch for custom designs. Defer user-facing `replicates =` parameter to future phase if needed.

2. **Should Phase 6 support BRR/Fay variance methods?**
   - What we know: BRR and Fay's method require specific design structures (paired PSUs within strata). Creel surveys typically use day-based PSUs without natural pairing.
   - What's unclear: Whether any creel survey designs benefit from BRR (e.g., paired day sampling).
   - Recommendation: Defer BRR/Fay to future phase. Focus Phase 6 on bootstrap and jackknife, which work with arbitrary stratified designs.

3. **How should integration tests verify variance method correctness?**
   - What we know: Bootstrap/jackknife should produce similar (not identical) variance estimates to Taylor for smooth statistics like totals.
   - What's unclear: Appropriate tolerance for "similar" given simulation error.
   - Recommendation: Reference tests should verify bootstrap/jackknife don't error and produce positive variance estimates. Don't require exact numeric match to Taylor due to simulation error. Use relative tolerance (e.g., within 20% of Taylor for same data) as sanity check.

4. **Should print method show number of replicates used?**
   - What we know: Bootstrap uses 500 replicates (fixed), jackknife uses auto-determined count based on design structure.
   - What's unclear: Whether users need to see "Bootstrap (500 replicates)" vs just "Bootstrap" in output.
   - Recommendation: Keep simple in Phase 6 - show "Bootstrap" or "Jackknife" without replicate counts. Format method already shows variance method. Advanced users can inspect design$survey if needed.

## Sources

### Primary (HIGH confidence)
- [R survey package documentation - as.svrepdesign](https://r-survey.r-forge.r-project.org/survey/html/as.svrepdesign.html) - Function signature, type options, defaults
- [Survey package PDF manual (v4.4+, August 2025)](https://cran.r-project.org/web/packages/survey/survey.pdf) - Comprehensive reference
- [svrep package - Bootstrap Methods for Surveys](https://bschneidr.github.io/svrep/articles/bootstrap-replicates.html) - Modern recommendations for replicate counts, simulation error

### Secondary (MEDIUM confidence)
- [Sample Size Estimation for On-Site Creel Surveys (McCormick 2017)](https://afspubs.onlinelibrary.wiley.com/doi/full/10.1080/02755947.2017.1342723) - Bootstrap methods for creel survey sample size estimation
- [Resampling Variance Estimation for Complex Survey Data](https://journals.sagepub.com/doi/pdf/10.1177/1536867X1001000201) - Comparative performance of bootstrap, jackknife, BRR

### Tertiary (LOW confidence)
- WebSearch results on bootstrap vs jackknife for small samples - General guidance, not creel-specific

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - survey package documentation confirms as.svrepdesign() with type = "bootstrap"/"auto" for jackknife
- Architecture: HIGH - Verified pattern from Phase 4 research and survey package examples
- Pitfalls: MEDIUM - Based on survey package documentation and general bootstrap literature; creel-specific pitfalls may exist
- Code examples: HIGH - Directly from survey package official documentation and existing tidycreel code patterns

**Research date:** 2026-02-09
**Valid until:** 60 days (survey package stable, methods well-established)

**Notes:**
- No CONTEXT.md exists for this phase - full design freedom
- Phase 6 builds directly on Phase 4/5 architecture - variance method routing is clean extension
- Bootstrap/jackknife primarily useful for non-smooth statistics (quantiles) but implementing now establishes pattern for future estimation types (mean, ratio, regression)
- Integration tests (TEST-05) should verify full workflow with all three variance methods
