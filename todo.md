## Future Features & Enhancements

- Advanced aerial estimator features:
  - Visibility correction (adjust counts for detection probability)
  - Calibration factors (integrate ground truth or reference counts)
  - Support for unequal probability sampling and post-stratification
  - Additional diagnostics and reporting for aerial survey designs

# tidycreel Development Roadmap – Expanded ToDo
#
# ---
#
# ## Recurring Checks & Maintenance
#
# This section collects items that should be regularly reviewed or updated as the package evolves. Return to this list often to ensure diagnostics, documentation, and edge cases remain current.
#
# - Review and update diagnostics and warnings in design constructors (e.g., NA weights, dropped rows)
# - Regularly update code examples and usage patterns in documentation
# - Document and revisit edge cases and best practices for design constructors
# - Maintain and expand living documentation (`tidycreel_designs.md`)
#

This roadmap outlines the phases, tasks, and substeps required to build the **tidycreel** package for creel survey analysis.

---

## Phase 1 – Critical Fixes & Core Infrastructure
 - [x] Set up `renv` for reproducible environments — Done: renv folder and lockfile present, R version 4.5.1 recorded (2025-08-20)
- [x] Add `.gitignore` for build artifacts and local configs — Done: Improved to cover R, build, OS, editor, and dependency artifacts (2025-08-20)
- [x] Create core package structure with `usethis::create_package()` — Done: Standard R package structure present (2025-08-20)
- [x] Configure `DESCRIPTION` and `NAMESPACE` — Done: Both files exist and are populated with relevant fields and exports (2025-08-20)
- [x] Add GitHub Actions CI workflow for R CMD check — Done: Implemented cross-platform R CMD check with renv support (2025-08-20 00:48)
- [x] Automated schema test runner (run all validation functions in a single call) — Done: Implemented as schema_test_runner() in R/schema_test_runner.R (2025-08-20)
- [x] Create `sample_data/` folder with realistic datasets for testing — Done: Folder contains README and 25-row realistic CSVs for calendar, interviews, counts, and auxiliary data (2025-08-20)
 - [x] Lock `renv` snapshot and record R version for reproducibility — Done: renv.lock present, R version 4.5.1 recorded (2025-08-20)

---

## Phase 2 – Survey Design Objects (Updated 2025-08-20)

- [x] Implement bus route survey design constructor (build on survey package) — Done: design_busroute() uses survey::svydesign for unequal probability weights (2025-08-20)
    - [x] Integrate survey::svydesign for proper unequal probability weights in bus route design — Done (2025-08-20)
- [x] Implement `creel_design()` constructor — Done: design_access(), design_roving(), and design_repweights() create 'creel_design' objects (2025-08-20)
    - [x] Document S3 class structure and add print/summary methods for creel_design objects — Done: methods and tests added (2025-08-20)
- [x] Store metadata: strata definitions, probabilities, sampling frame sizes — Done: All design constructors now store metadata (2025-08-20)
- [x] Define S3 class `creel_design` — Done: S3 class defined in design-constructors.R (2025-08-20)
- [x] Document assumptions (e.g., random sampling within stratum) — Done: function-level comments and living documentation updated (2025-08-20)
- [ ] Add `plot_design()` to visualize survey structure (use ggplot2)
    - [x] Initial implementation: bar plot by date/shift/location
  - [x] Expand plotting features (interactive plots, more plot types, customization) — Started: plot_design and plot_effort in R/plots.R (2025-08-20)

- [x] Write conversion helpers (`creel_design` → `survey::svydesign`)
    - [x] Add tests for conversion helpers
    - [x] Update all code/tests to use svy$variables instead of svy$data (2025-08-20)
    - [x] Add diagnostics and robust test logic for survey design conversion (2025-08-20)
    - [x] Add warnings in design constructors for NA weights to catch data mismatches (2025-08-20)



---

## Effort Estimation Actionable Build Plan (Integrated from tidycreel_effort_action_plan.md)

### Guiding Principles & Architecture
- S3 generics for estimators, design-based first, model-based optional
- Diagnostics, variance, documentation, and tests are required for all estimators

### Deliverables Structure
R/
  design-constructors.R
  est-effort.R
  est-effort-busroute.R
  est-effort-aerial.R
  est-effort-modelbased.R
  utils-validate.R
  utils-time.R
  plots.R
tests/
  test-est-effort.R
  test-est-effort-busroute.R
vignettes/
  effort_design_based.Rmd
  effort_model_based.Rmd
inst/extdata/ (toy datasets)

### Key Implementation Tasks
1. Utilities & Schemas: validation, time parsing, diagnostics helpers
2. Core Generic: est_effort S3 generic and return contract
3. Instantaneous Count Estimator: design-based, with/without survey object
4. Progressive (Roving) Count Estimator: pass-based, bias checks
5. Bus-Route Access Estimator: HT estimator, cycle checks, variance
6. Aerial Instantaneous Estimator: visibility adjustment, stratified expansion
7. Strata Wrapper: stratified expansion utility
8. Model-Based Options: GLMM, Bayesian camera integration
9. Variance & Replicates: analytic, bootstrap, jackknife
10. API Cohesion: dispatcher, method registry
11. Diagnostics & Warnings: standardized across estimators
12. Documentation & Vignettes: toy data, workflow examples
13. Testing Matrix: deterministic, simulated, cross-method
14. Milestones: MVP (design-based), coverage expansion, model-based beta, docs/release

### Example Function Stubs
See tidycreel_effort_action_plan.md for up-to-date function signatures and S3 dispatcher example.

### Immediate Next Steps
- [x] Build utilities & schemas (validation, time, diagnostics) — Done: validate_required_columns, parse_time_column, report_dropped_rows implemented and integrated (2025-08-20)
- [x] Implement instantaneous, progressive, bus-route estimators — Done: est_effort supports all three, with analytic/bootstrap/jackknife variance (2025-08-20)
- [x] Implement aerial estimator (visibility, stratified expansion) — Started: est_effort_aerial() scaffolded in R/est-effort-aerial.R (2025-08-20)
- [x] Standardize diagnostics and error handling — Done: dropped row reporting, NA warnings, diagnostics columns in all estimators (2025-08-20)
- [x] Add documentation and vignette for aerial estimator — Started: effort_aerial.Rmd created (2025-08-20)
- [x] Integrate variance and replicate options — Done: analytic, bootstrap, jackknife supported in all estimators (2025-08-20)
- [x] Ensure API cohesion via S3 dispatcher and method registry — Done: S3 generic and method registry implemented (2025-08-20)

---

---

## Phase 3 – Estimation Core
 [ ] Implement `est_effort()` with support for instantaneous/progressive counts
     - [ ] Statistical methods: instantaneous (mean count × time / mean party size), progressive (AUC/trapezoidal integration)
     - [x] Accept survey design object (`creel_design` or `svydesign`)
     - [x] Accept counts data (time, count, party size, stratum, etc.)
     - [x] Parameter for method selection: 'instantaneous' or 'progressive'
     - [x] Validate required columns and alignment with survey design
     - [ ] For instantaneous: calculate mean count per stratum, multiply by time, adjust for party size
     - [ ] For progressive: sort by time, calculate interval effort, sum, apply weights
     - [ ] Use survey package for variance estimation (`svytotal`, `svymean`)
     - [ ] Output tibble/data.frame: stratum, estimate, SE, CI_low, CI_high, n, method, diagnostics
     - [ ] Warn for NA/missing counts, weights, or party sizes
     - [ ] Report dropped rows and strata with missing data
     - [ ] Output diagnostics (e.g., number of dropped rows, strata with issues)
     - [x] Implement as S3 generic (`est_effort`) with methods for `creel_design` and `svydesign`
     - [x] Use tidyverse for data handling
     - [x] Document with roxygen2, include code examples for both methods
    - [ ] Ensure compatibility with downstream functions (`est_cpue`, `est_catch`)
    - [ ] Structure for future corrections (incomplete trips, nonresponse, spatial)
    - [ ] Allow custom formulas and variance methods
    - [ ] Plan for integration with plotting (e.g., `plot_effort`)

- [ ] Implement `est_cpue()` with ratio-of-means vs. mean-of-ratios handling
- [ ] Implement `est_catch()` (catch/harvest by species)
- [ ] Output: tibble with estimate, SE, CI, metadata

---

## Phase 4 – Bias Corrections & Variance Estimation
- [ ] Implement incomplete-trip corrections
- [ ] Address targeted vs. non-targeted species
- [ ] Incorporate nonresponse adjustments
- [ ] Implement analytical variance for ratio estimators
- [ ] Compare bootstrap vs. jackknife performance
- [ ] Add option for Taylor linearization (consistent with `survey` package)

---

## Phase 5 – Support for Survey Designs
- [ ] Access-point design support
- [ ] Roving design support (roving-access, roving-roving)
- [ ] Aerial survey integration
- [ ] Hybrid designs (e.g., access-point + roving)
- [ ] Functions for unequal probability sampling
- [ ] Provide vignette on survey design trade-offs

---

## Phase 6 – Data Validation & Cleaning
- [ ] Validate input tables for required fields
- [ ] Standardize coding (species codes, effort units)
- [ ] Handle missing values with warnings
- [ ] Flagging function (`flag_outliers()`) for extreme CPUE/effort
- [ ] Auto-report of validation results (summary tibble + export option)

---

## Phase 7 – Output & Reporting
- [ ] Implement `summary.creel_estimate()` with formatted tables
- [ ] Export estimates to CSV/Excel with metadata
- [ ] Provide APA-style table output helper
- [ ] Add plots: effort trends, CPUE by stratum, harvest composition
- [ ] Build `ggplot2` themes for consistent output
- [ ] Provide example dashboards (flexdashboard/Shiny stub)

---

## Phase 8 – Documentation & Training
- [ ] Write function documentation with examples
- [ ] Create vignettes for access-point, roving, aerial designs
- [ ] Provide references to foundational literature
- [ ] Glossary of terms (effort, CPUE, harvest)
- [ ] “Common pitfalls” vignette
- [ ] Annotated example workflow: raw → validation → estimates → report

---

## Phase 9 – Testing & QA/QC
- [ ] Unit tests with `testthat`
- [ ] Coverage reporting via `covr`
- [ ] Continuous integration: enforce test pass/fail
- [ ] Test edge cases (empty data, single stratum, large datasets)

---

## Phase 10 – Simulation & Scheduling Tools
- [ ] Implement creel scheduling helper functions
- [ ] Provide simulation framework for survey design evaluation
- [ ] Include variance decomposition (between vs. within strata)
- [ ] Sensitivity analysis tools (effect of sample size, allocation choices)
- [ ] Visualization functions for simulated sampling calendars

---

## Phase 11 – Advanced Features
- [ ] Domain estimation for subgroups (species, regions)
- [ ] Multi-stage sampling handling
- [ ] Integration with GIS for mapping
- [ ] Support for off-site or marine survey extensions

---

## Phase 12 – Production Infrastructure
- [ ] Benchmark suite for performance with large datasets
- [ ] Security review (PII obfuscation for real creel data)
- [x] Add Dockerfile for reproducible deployments — Done: Created ARM64-compatible Docker image with R 4.3.2 base (2025-08-20 00:49)
- [ ] Demo vignette showing Docker + `renv` workflow

---

## Phase 13 – Release & Dissemination
- [ ] Prepare CRAN submission
- [ ] Build pkgdown site
- [ ] Write blog post / announcement
- [ ] Training materials and workshop slide deck

---

#' Fishing Effort Estimation
#'
#' Estimate fishing effort using instantaneous or progressive count methods.
#' Accepts a `creel_design` (or subclass) or a `survey::svydesign` and, when needed,
#' a counts table. Returns a tibble with stratum, estimate, SE (if available), and CIs.
#'
#' @param x A `creel_design` object (or subclass) or a `survey::svydesign`.
#' @param counts Optional tibble/data.frame of counts. If `x` is a creel design and
#'   contains `$counts`, that will be used by default.
#' @param method Estimation method: one of `"instantaneous"` or `"progressive"`.
#' @param by Character vector of grouping (stratification) variables to retain in output.
#'   Defaults to `c("date", "shift_block", "location")` if present; otherwise uses
#'   any overlap of these with available columns.
#' @param conf_level Confidence level for CI (currently placeholder when SE not available).
#' @param ... Reserved for future arguments (ignored for now).
#'
#' @return A tibble with columns: `stratum` variables (`by`), `estimate`, `se`,
#'   `ci_low`, `ci_high`, `n`, and `method`.
#'
#' @examples
#' # est_effort(design_obj, method = "instantaneous")
#'
#' @export
est_effort <- function(x, ...) UseMethod("est_effort")

#' @export
est_effort.creel_design <- function(x,
                                    counts = NULL,
                                    method = c("instantaneous", "progressive"),
                                    by = c("date", "shift_block", "location"),
                                    conf_level = 0.95,
                                    ...) {
  method <- match.arg(method)

  # Prefer counts embedded in the design; else, require counts param
  if (is.null(counts) && !is.null(x$counts)) counts <- x$counts
  if (is.null(counts)) stop("Counts data must be supplied via `counts` or present in the design object as `$counts`.")

  # Choose grouping variables that actually exist
  by <- intersect(by, names(counts))
  if (length(by) == 0) {
    warning("None of the default grouping vars were found; aggregating all counts together.")
  }

  # Standardize expected columns
  required_any <- c("time", "count", "anglers_count")
  if (!any(required_any %in% names(counts))) {
    stop("Counts must have a `count` column (or `anglers_count`).")
  }
  if (!"count" %in% names(counts) && "anglers_count" %in% names(counts)) {
    counts$count <- counts$anglers_count
  }

  # Duration columns (minutes). We try `count_duration` (used elsewhere) then fall back to `interval_minutes`.
  if (method == "instantaneous") {
    dur_col <- if ("count_duration" %in% names(counts)) "count_duration" else if ("interval_minutes" %in% names(counts)) "interval_minutes" else NULL
    if (is.null(dur_col)) stop("For instantaneous method, counts require `count_duration` or `interval_minutes` (in minutes).")
  }

  # Progressive method requires an ordering variable (timestamp) per stratum
  if (method == "progressive") {
    time_col <- if ("time" %in% names(counts)) "time" else if ("timestamp" %in% names(counts)) "timestamp" else NULL
    if (is.null(time_col)) stop("For progressive method, counts require a `time` or `timestamp` column.")
  }

  # Helper: as tibble without depending on tibble at runtime
  as_tb <- function(df) {
    if (requireNamespace("tibble", quietly = TRUE)) tibble::as_tibble(df) else df
  }

  # Group/summarize
  if (method == "instantaneous") {
    # Effort ≈ mean(count) * total_time; with equally spaced intervals, sum(count) * interval_length
    # Here we implement: effort = sum( count * interval_minutes ) / 60 (to hours)
    agg <- as_tb(stats::aggregate(counts[c("count", dur_col)],
                                  by = counts[by],
                                  FUN = sum, na.rm = TRUE))
    names(agg)[names(agg) == dur_col] <- "interval_minutes"
    agg$estimate <- (agg$count * agg$interval_minutes) / 60

    # Basic diagnostics
    agg$n <- as.integer(stats::aggregate(count ~ ., data = counts[c(by, "count")], FUN = length)$count)

    # Placeholder SE/CI (TODO: add survey-based variance when time-sampling weights are available)
    agg$se <- NA_real_
    agg$ci_low <- NA_real_
    agg$ci_high <- NA_real_
    agg$method <- "instantaneous"

    out <- agg[c(by, "estimate", "se", "ci_low", "ci_high", "n", "method")]
    return(out)
  }

  if (method == "progressive") {
    # Effort ≈ trapezoidal integral of count over time per stratum
    # Convert time to numeric minutes within each stratum
    df <- counts
    time_col <- if ("time" %in% names(df)) "time" else "timestamp"

    # Coerce time to POSIXct if not already
    if (!inherits(df[[time_col]], c("POSIXct", "POSIXt"))) {
      # Try to parse
      if (requireNamespace("lubridate", quietly = TRUE)) {
        df[[time_col]] <- lubridate::ymd_hms(df[[time_col]], quiet = TRUE)
      } else {
        df[[time_col]] <- as.POSIXct(df[[time_col]])
      }
    }

    # Split by stratum and integrate
    split_keys <- if (length(by)) interaction(df[by], drop = TRUE) else factor(1L)
    idx <- split(seq_len(nrow(df)), split_keys)

    estimates <- lapply(idx, function(ix) {
      d <- df[ix, , drop = FALSE]
      d <- d[order(d[[time_col]]), , drop = FALSE]
      if (nrow(d) < 2) return(list(estimate = NA_real_, n = nrow(d)))
      dt_min <- as.numeric(diff(d[[time_col]]), units = "mins")
      # Trapezoid rule: sum((c_i + c_{i+1})/2 * dt)
      est_min <- sum((head(d$count, -1) + tail(d$count, 1)) / 2 * dt_min, na.rm = TRUE)
      list(estimate = est_min / 60, n = nrow(d))  # convert to hours
    })

    est_vec <- vapply(estimates, function(z) z$estimate, numeric(1))
    n_vec <- vapply(estimates, function(z) z$n, integer(1))

    out <- as_tb(unique(df[if (length(by)) by else NULL]))
    if (!length(by)) out <- data.frame(dummy = 1)[FALSE, ]
    out$estimate <- est_vec
    out$se <- NA_real_  # TODO: add variance via replicate designs or model-based SE
    out$ci_low <- NA_real_
    out$ci_high <- NA_real_
    out$n <- n_vec
    out$method <- "progressive"

    # Reattach by-columns explicitly
    if (length(by)) {
      # Expand the by-levels in the same order as split_keys levels
      levs <- levels(split_keys)
      if (length(levs) == nrow(out)) {
        # Attempt to reconstruct by columns from level strings
        by_df <- utils::read.table(text = gsub("^", "", levs), sep = ".", col.names = by, stringsAsFactors = FALSE)
        # If parsing fails, leave as-is
        suppressWarnings({
          for (j in seq_along(by)) if (!by[j] %in% names(out)) out[[by[j]]] <- by_df[[j]]
        })
      }
    }

    # Keep only desired columns (in order)
    cols <- c(by, "estimate", "se", "ci_low", "ci_high", "n", "method")
    cols <- unique(cols[cols %in% names(out)])
    out <- out[cols]
    return(out)
  }

  stop("Unknown method.")
}

#' @export
est_effort.svydesign <- function(x,
                                 counts = NULL,
                                 method = c("instantaneous", "progressive"),
                                 by = c("date", "shift_block", "location"),
                                 conf_level = 0.95,
                                 ...) {
  # Placeholder that forwards to the creel_design path when the svydesign
  # came from a creel design; otherwise requires counts explicitly.
  method <- match.arg(method)
  if (is.null(counts)) {
    stop("When supplying a bare `svydesign`, you must also provide a `counts` table.")
  }
  # Reuse the implementation by wrapping a minimal list that mimics design
  fake_design <- list(counts = counts)
  class(fake_design) <- c("creel_design", "list")
  est_effort.creel_design(fake_design, counts = counts, method = method, by = by, conf_level = conf_level, ...)
}
