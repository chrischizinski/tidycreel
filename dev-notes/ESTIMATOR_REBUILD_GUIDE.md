# Estimator Rebuild Guide

## Overview

This guide provides the **exact pattern** to rebuild all remaining tidycreel estimators with native survey integration. Follow this pattern for consistent, ground-up integration.

## ✅ Completed Estimators

1. `est_effort.instantaneous` → `R/est-effort-instantaneous-REBUILT.R`
2. `est_effort.progressive` → `R/est-effort-progressive-REBUILT.R`
3. `est_effort.aerial` → `R/est-effort-aerial-REBUILT.R`

## 🔨 Remaining Estimators to Rebuild

### Effort Estimators
- [ ] `est_effort.busroute_design` (partially shown in `R/est-effort-busroute.R`)

### CPUE/Harvest Estimators
- [ ] `aggregate_cpue` (`R/aggregate-cpue.R`)
- [ ] `est_cpue` (`R/est-cpue.R`)
- [ ] `est_total_harvest` (`R/est-total-harvest.R`)

## The Standard Rebuilding Pattern

### Step 1: Copy Original Function Structure

Keep all the original logic for:
- Input validation
- Data preparation
- Grouping logic
- Design construction
- Fallback (non-design) path

### Step 2: Add NEW Parameters

Add these parameters to the function signature:

```r
function_name <- function(
  # ... existing parameters ...
  conf_level = 0.95,

  # NEW PARAMETERS (add these):
  variance_method = "survey",
  decompose_variance = FALSE,
  design_diagnostics = FALSE,
  n_replicates = 1000
)
```

### Step 3: Replace Direct Survey Calls

**OLD Pattern** (Direct survey package calls):
```r
if (length(by_all) > 0) {
  by_formula <- stats::as.formula(paste("~", paste(by_all, collapse = "+")))
  est <- survey::svyby(~response_var, by = by_formula, design_eff, survey::svytotal, na.rm = TRUE)
  out <- tibble::as_tibble(est)
  names(out)[names(out) == "response_var"] <- "estimate"
  V <- attr(est, "var")
  # ... extract SE, compute CI ...
} else {
  total_est <- survey::svytotal(~response_var, design_eff, na.rm = TRUE)
  estimate <- as.numeric(total_est[1])
  se <- sqrt(as.numeric(survey::vcov(total_est)))
  ci <- tc_confint(estimate, se, level = conf_level)
  # ... build output ...
}
```

**NEW Pattern** (Use core variance engine):
```r
# Grouped estimation
if (length(by_all) > 0) {
  variance_result <- tc_compute_variance(
    design = design_eff,
    response = "response_var",
    method = variance_method,
    by = by_all,
    conf_level = conf_level,
    n_replicates = n_replicates,
    calculate_deff = TRUE
  )

  out <- tibble::tibble(
    !!!setNames(
      lapply(by_all, function(v) design_eff$variables[[v]][seq_along(variance_result$estimate)]),
      by_all
    ),
    estimate = variance_result$estimate,
    se = variance_result$se,
    ci_low = variance_result$ci_lower,
    ci_high = variance_result$ci_upper,
    deff = variance_result$deff,
    n = rep(NA_integer_, length(variance_result$estimate)),
    method = "your_method_name"
  )
} else {
  # Overall estimation
  variance_result <- tc_compute_variance(
    design = design_eff,
    response = "response_var",
    method = variance_method,
    by = NULL,
    conf_level = conf_level,
    n_replicates = n_replicates,
    calculate_deff = TRUE
  )

  out <- tibble::tibble(
    estimate = variance_result$estimate,
    se = variance_result$se,
    ci_low = variance_result$ci_lower,
    ci_high = variance_result$ci_upper,
    deff = variance_result$deff,
    n = NA_integer_,
    method = "your_method_name"
  )
}
```

### Step 4: Add Variance Decomposition

After creating the output tibble, add:

```r
# ── NEW: Variance Decomposition if requested ─────────────────────────────
if (decompose_variance) {
  variance_result$decomposition <- tryCatch({
    tc_decompose_variance(
      design = design_eff,
      response = "response_var",
      cluster_vars = c(day_id),  # Adjust based on design structure
      method = "anova",
      conf_level = conf_level
    )
  }, error = function(e) {
    cli::cli_warn("Variance decomposition failed: {e$message}")
    NULL
  })
}
```

### Step 5: Add Design Diagnostics

```r
# ── NEW: Design Diagnostics if requested ─────────────────────────────────
if (design_diagnostics) {
  variance_result$diagnostics <- tryCatch({
    tc_design_diagnostics(design = design_eff, detailed = FALSE)
  }, error = function(e) {
    cli::cli_warn("Design diagnostics failed: {e$message}")
    NULL
  })
}
```

### Step 6: Add variance_info List-Column

```r
# ── NEW: Add variance_info list-column ───────────────────────────────────
out$variance_info <- replicate(nrow(out), list(variance_result), simplify = FALSE)
```

### Step 7: Update Return Statement

Ensure the return includes the new columns:

```r
return(dplyr::select(
  out,
  dplyr::any_of(by_all),           # Grouping columns
  estimate, se, ci_low, ci_high,   # Core estimates
  deff,                            # NEW: Design effect
  n, method,                       # Metadata
  variance_info                    # NEW: Variance information
))
```

### Step 8: Update Fallback Path

For the non-design fallback path, add:

```r
out$deff <- NA_real_
out$variance_info <- replicate(nrow(out), list(NULL), simplify = FALSE)
```

### Step 9: Update Documentation

Add to the roxygen2 documentation:

```r
#' @param variance_method **NEW** Variance estimation method:
#'   \describe{
#'     \item{"survey"}{Standard survey package variance (default, backward compatible)}
#'     \item{"svyrecvar"}{survey:::svyrecvar internals for maximum accuracy}
#'     \item{"bootstrap"}{Bootstrap resampling variance}
#'     \item{"jackknife"}{Jackknife resampling variance}
#'     \item{"linearization"}{Taylor linearization (alias for "survey")}
#'   }
#' @param decompose_variance **NEW** Logical, whether to decompose variance into
#'   components. Adds variance decomposition to variance_info output. Default FALSE.
#' @param design_diagnostics **NEW** Logical, whether to compute design quality
#'   diagnostics. Adds diagnostic information to variance_info output. Default FALSE.
#' @param n_replicates **NEW** Number of bootstrap/jackknife replicates (default 1000)
```

And update the return documentation:

```r
#' @return Tibble with grouping columns plus:
#'   \describe{
#'     \item{estimate}{Estimated total}
#'     \item{se}{Standard error}
#'     \item{ci_low, ci_high}{Confidence interval limits}
#'     \item{deff}{**NEW** Design effect}
#'     \item{n}{Sample size}
#'     \item{method}{Estimation method}
#'     \item{variance_info}{**NEW** List-column with comprehensive variance information}
#'   }
```

## Complete Example Template

```r
#' Function Name (REBUILT with Native Survey Integration)
#'
#' Description...
#'
#' **NEW**: Native support for multiple variance methods, variance decomposition,
#' and design diagnostics without requiring wrapper functions.
#'
#' @param ... existing parameters ...
#' @param variance_method **NEW** Variance estimation method (default "survey")
#' @param decompose_variance **NEW** Logical, decompose variance (default FALSE)
#' @param design_diagnostics **NEW** Logical, compute diagnostics (default FALSE)
#' @param n_replicates **NEW** Bootstrap/jackknife replicates (default 1000)
#'
#' @return Tibble with estimate, se, ci_low, ci_high, deff, n, method, variance_info
#'
#' @examples
#' \dontrun{
#' # BACKWARD COMPATIBLE
#' result <- function_name(data, svy = design)
#'
#' # NEW: Advanced features
#' result <- function_name(
#'   data,
#'   svy = design,
#'   variance_method = "bootstrap",
#'   decompose_variance = TRUE,
#'   design_diagnostics = TRUE
#' )
#' }
#'
#' @export
function_name <- function(
  # ... existing parameters ...
  conf_level = 0.95,
  variance_method = "survey",
  decompose_variance = FALSE,
  design_diagnostics = FALSE,
  n_replicates = 1000
) {

  # ── Input Validation (unchanged) ────────────────────────────────────────
  # Keep all existing validation logic

  # ── Data Preparation (unchanged) ────────────────────────────────────────
  # Keep all existing data prep logic

  # ── Design-Based Path (REBUILT) ─────────────────────────────────────────
  if (!is.null(svy)) {

    # ... existing design construction logic ...

    # ── NEW: Use Core Variance Engine ────────────────────────────────────
    if (length(by_all) > 0) {
      variance_result <- tc_compute_variance(
        design = design_eff,
        response = "response_var",
        method = variance_method,
        by = by_all,
        conf_level = conf_level,
        n_replicates = n_replicates,
        calculate_deff = TRUE
      )

      out <- tibble::tibble(
        !!!setNames(
          lapply(by_all, function(v) design_eff$variables[[v]][seq_along(variance_result$estimate)]),
          by_all
        ),
        estimate = variance_result$estimate,
        se = variance_result$se,
        ci_low = variance_result$ci_lower,
        ci_high = variance_result$ci_upper,
        deff = variance_result$deff,
        n = rep(NA_integer_, length(variance_result$estimate)),
        method = "method_name"
      )
    } else {
      variance_result <- tc_compute_variance(
        design = design_eff,
        response = "response_var",
        method = variance_method,
        by = NULL,
        conf_level = conf_level,
        n_replicates = n_replicates,
        calculate_deff = TRUE
      )

      out <- tibble::tibble(
        estimate = variance_result$estimate,
        se = variance_result$se,
        ci_low = variance_result$ci_lower,
        ci_high = variance_result$ci_upper,
        deff = variance_result$deff,
        n = NA_integer_,
        method = "method_name"
      )
    }

    # ── NEW: Variance Decomposition ───────────────────────────────────────
    if (decompose_variance) {
      variance_result$decomposition <- tryCatch({
        tc_decompose_variance(
          design = design_eff,
          response = "response_var",
          cluster_vars = c(day_id),
          method = "anova",
          conf_level = conf_level
        )
      }, error = function(e) {
        cli::cli_warn("Variance decomposition failed: {e$message}")
        NULL
      })
    }

    # ── NEW: Design Diagnostics ───────────────────────────────────────────
    if (design_diagnostics) {
      variance_result$diagnostics <- tryCatch({
        tc_design_diagnostics(design = design_eff, detailed = FALSE)
      }, error = function(e) {
        cli::cli_warn("Design diagnostics failed: {e$message}")
        NULL
      })
    }

    # ── NEW: Add variance_info ────────────────────────────────────────────
    out$variance_info <- replicate(nrow(out), list(variance_result), simplify = FALSE)

    return(dplyr::select(
      out,
      dplyr::any_of(by_all),
      estimate, se, ci_low, ci_high, deff, n, method, variance_info
    ))
  }

  # ── Fallback: non-design path (updated) ──────────────────────────────
  # ... existing fallback logic ...

  out$deff <- NA_real_
  out$variance_info <- replicate(nrow(out), list(NULL), simplify = FALSE)

  dplyr::select(
    out,
    dplyr::any_of(by_all),
    estimate, se, ci_low, ci_high, deff, n, method, variance_info
  )
}
```

## Checklist for Each Estimator

When rebuilding an estimator, verify:

- [ ] New parameters added (`variance_method`, `decompose_variance`, `design_diagnostics`, `n_replicates`)
- [ ] Direct survey calls replaced with `tc_compute_variance()`
- [ ] Variance decomposition added if requested
- [ ] Design diagnostics added if requested
- [ ] `variance_info` list-column added
- [ ] `deff` column added to output
- [ ] Fallback path updated with `deff` and `variance_info`
- [ ] Documentation updated with NEW parameters
- [ ] Return value documentation updated
- [ ] Examples show both old (backward compatible) and new usage
- [ ] Function saved as `*-REBUILT.R` initially for testing

## Testing Each Rebuilt Estimator

```r
# 1. Test backward compatibility
result_old <- original_function(data, svy = design)
result_new <- rebuilt_function(data, svy = design)

# Should match (within floating point tolerance)
all.equal(result_old$estimate, result_new$estimate)
all.equal(result_old$se, result_new$se)

# 2. Test new features
result_advanced <- rebuilt_function(
  data,
  svy = design,
  variance_method = "bootstrap",
  decompose_variance = TRUE,
  design_diagnostics = TRUE
)

# Should have enhanced information
expect_true(!is.null(result_advanced$variance_info))
expect_true(!is.null(result_advanced$variance_info[[1]]$decomposition))
expect_true(!is.null(result_advanced$variance_info[[1]]$diagnostics))
```

## Quick Reference: Key Changes

| Aspect | OLD | NEW |
|--------|-----|-----|
| Variance calculation | `survey::svytotal()` directly | `tc_compute_variance()` |
| SE extraction | Manual from `attr(est, "var")` | Automatic in `variance_result$se` |
| CI calculation | Manual Z-score | Automatic in `variance_result$ci_*` |
| Design effects | Not included | `variance_result$deff` |
| Variance methods | Survey package default only | Survey, bootstrap, jackknife, svyrecvar |
| Decomposition | Not available | Built-in via parameter |
| Diagnostics | Not available | Built-in via parameter |
| Output structure | Basic tibble | Enhanced with `variance_info` |

## After Rebuilding All Estimators

1. **Test thoroughly** - Compare old vs new results
2. **Replace originals** - `mv *-REBUILT.R` to original names
3. **Update NAMESPACE** - Export new functions
4. **Run cleanup** - `bash scripts/cleanup-patches.sh`
5. **Run tests** - `Rscript -e 'devtools::test()'`
6. **Check architecture** - `bash scripts/check-architecture.sh`
7. **Commit** - Clean, compliant architecture

---

*This guide ensures consistent, ground-up integration across ALL tidycreel estimators.*
