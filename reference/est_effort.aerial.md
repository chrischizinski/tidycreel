# Aerial Effort Estimator (REBUILT with Native Survey Integration)

Estimate angler-hours from aerial snapshot counts using a mean-count
expansion within groups, with optional visibility and calibration
adjustments, and design-based variance via the `survey` package with
NATIVE support for advanced variance methods.

## Usage

``` r
est_effort.aerial(
  counts,
  by = c("date", "location"),
  minutes_col = c("flight_minutes", "interval_minutes", "count_duration"),
  total_minutes_col = c("total_minutes", "total_day_minutes", "block_total_minutes"),
  day_id = "date",
  covariates = NULL,
  visibility_col = NULL,
  calibration_col = NULL,
  svy = NULL,
  post_strata_var = NULL,
  post_strata = NULL,
  calibrate_formula = NULL,
  calibrate_population = NULL,
  calfun = c("linear", "raking", "logit"),
  conf_level = 0.95,
  variance_method = "survey",
  decompose_variance = FALSE,
  design_diagnostics = FALSE,
  n_replicates = 1000
)
```

## Arguments

- counts:

  Data frame/tibble of aerial counts with at least `count` and a minutes
  column (e.g., `flight_minutes`, `interval_minutes`, or
  `count_duration`).

- by:

  Character vector of grouping variables present in `counts` (e.g.,
  `date`, `location`). Missing columns are ignored with a warning.

- minutes_col:

  Candidate column names for minutes represented by each count. The
  first present is used.

- total_minutes_col:

  Optional column giving the total minutes represented for the whole day
  x group (e.g., full day length or block coverage). If absent, the
  estimator falls back to the sum of per-count minutes within the day x
  group (warns).

- day_id:

  Day identifier (PSU), typically `date`, used to join to the survey
  design.

- covariates:

  Optional character vector of additional grouping variables for aerial
  conditions (e.g., `cloud`, `glare`, `observer`, `altitude`).

- visibility_col:

  Optional name of a column with visibility proportion (0-1). Counts are
  divided by this value (guarded to avoid division by very small
  numbers).

- calibration_col:

  Optional name of a column with multiplicative calibration factors to
  apply after visibility correction.

- svy:

  Optional `svydesign`/`svrepdesign` encoding the day sampling design
  (must include `day_id` in `svy$variables`). When provided, totals,
  SEs, and CIs are computed with `survey` functions.

- post_strata_var:

  Optional post-stratification variable name

- post_strata:

  Optional post-stratification population table

- calibrate_formula:

  Optional calibration formula

- calibrate_population:

  Optional calibration population totals

- calfun:

  Calibration function: "linear", "raking", or "logit"

- conf_level:

  Confidence level for Wald CIs (default 0.95).

- variance_method:

  **NEW** Variance estimation method (default "survey")

- decompose_variance:

  **NEW** Logical, decompose variance (default FALSE)

- design_diagnostics:

  **NEW** Logical, compute diagnostics (default FALSE)

- n_replicates:

  **NEW** Bootstrap/jackknife replicates (default 1000)

## Value

Tibble with grouping columns plus:

- estimate:

  Estimated total effort (angler-hours)

- se:

  Standard error

- ci_low, ci_high:

  Confidence interval limits

- deff:

  Design effect

- n:

  Sample size

- method:

  Estimation method ("aerial")

- variance_info:

  **NEW** List-column with comprehensive variance information

## Details

**NEW**: Native support for multiple variance methods, variance
decomposition, and design diagnostics without requiring wrapper
functions.

## Examples

``` r
if (FALSE) { # \dontrun{
# BACKWARD COMPATIBLE
result <- est_effort.aerial_rebuilt(counts, svy = design)

# NEW: Complete analysis
result_full <- est_effort.aerial_rebuilt(
  counts,
  svy = design,
  variance_method = "bootstrap",
  decompose_variance = TRUE,
  design_diagnostics = TRUE
)
} # }
```
