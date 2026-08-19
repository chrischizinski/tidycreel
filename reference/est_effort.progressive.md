# Progressive (Roving) Effort Estimator (REBUILT with Native Survey Integration)

Estimate angler-hours from progressive (roving) counts by summing
pass-level counts × route_minutes per day × group, then compute
design-based totals and variance via the `survey` package with NATIVE
support for advanced variance methods.

## Usage

``` r
est_effort.progressive(
  counts,
  by = c("date", "location"),
  route_minutes_col = c("route_minutes", "circuit_minutes"),
  pass_id = c("pass_id", "circuit_id"),
  day_id = "date",
  covariates = NULL,
  svy = NULL,
  conf_level = 0.95,
  variance_method = "survey",
  decompose_variance = FALSE,
  design_diagnostics = FALSE,
  n_replicates = 1000
)
```

## Arguments

- counts:

  Tibble/data.frame of progressive counts with columns: `count`,
  `route_minutes` (or candidate), grouping variables (e.g., `date`,
  `location`), and optional `pass_id`/`circuit_id`.

- by:

  Character vector of grouping variables (e.g., `date`, `location`).
  Missing columns are ignored with a warning.

- route_minutes_col:

  Name(s) of the per-pass route minutes column; the first present is
  used.

- pass_id:

  Optional column name identifying passes. If absent, rows are treated
  as pass records and summed within day × group.

- day_id:

  Day identifier (PSU), typically `date`, used to join with the survey
  design.

- covariates:

  Optional character vector of additional grouping variables.

- svy:

  Optional `svydesign`/`svrepdesign` for day-level sampling design.

- conf_level:

  Confidence level for Wald CIs (default 0.95).

- variance_method:

  **NEW** Variance estimation method:

  "survey"

  :   Standard survey package variance (default, backward compatible)

  "svyrecvar"

  :   survey:::svyrecvar internals for maximum accuracy

  "bootstrap"

  :   Bootstrap resampling variance

  "jackknife"

  :   Jackknife resampling variance

  "linearization"

  :   Taylor linearization (alias for "survey")

- decompose_variance:

  **NEW** Logical, whether to decompose variance into components. Adds
  variance decomposition to variance_info output. Default FALSE.

- design_diagnostics:

  **NEW** Logical, whether to compute design quality diagnostics. Adds
  diagnostic information to variance_info output. Default FALSE.

- n_replicates:

  **NEW** Number of bootstrap/jackknife replicates (default 1000)

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

  Estimation method ("progressive")

- variance_info:

  **NEW** List-column with comprehensive variance information

## Details

**NEW**: Native support for multiple variance methods, variance
decomposition, and design diagnostics without requiring wrapper
functions.

Sums pass-level contributions to day × group totals and uses the day-PSU
survey design to compute totals and variance via the `survey` package.

### NEW: Advanced Variance Methods

This rebuilt function provides NATIVE support for advanced variance
estimation. See [`tc_compute_variance()`](tc_compute_variance.md) for
details on variance methods.

### NEW: Variance Decomposition

Set `decompose_variance = TRUE` to decompose total variance into
components. Results available in the `variance_info` list-column.

### NEW: Design Diagnostics

Set `design_diagnostics = TRUE` to assess design quality with
recommendations.

## See also

[`as_day_svydesign()`](as_day_svydesign.md),
[`tc_compute_variance()`](tc_compute_variance.md),
[`tc_decompose_variance()`](tc_decompose_variance.md),
[`tc_design_diagnostics()`](tc_design_diagnostics.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# BACKWARD COMPATIBLE: Standard usage
result <- est_effort.progressive_rebuilt(counts, svy = design)

# NEW: Bootstrap variance
result_boot <- est_effort.progressive_rebuilt(
  counts,
  svy = design,
  variance_method = "bootstrap"
)

# NEW: Complete analysis
result_full <- est_effort.progressive_rebuilt(
  counts,
  svy = design,
  variance_method = "svyrecvar",
  decompose_variance = TRUE,
  design_diagnostics = TRUE
)
} # }
```
