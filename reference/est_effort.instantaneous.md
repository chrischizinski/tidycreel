# Instantaneous Effort Estimator (REBUILT with Native Survey Integration)

Estimate angler-hours from instantaneous (snapshot) counts using
mean-count expansion per day x group, then compute design-based totals
and variance via the `survey` package with NATIVE support for advanced
variance methods.

## Usage

``` r
est_effort.instantaneous(
  counts,
  by = c("date", "location"),
  minutes_col = c("interval_minutes", "count_duration", "flight_minutes"),
  total_minutes_col = c("total_minutes", "total_day_minutes", "block_total_minutes"),
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

  Tibble/data.frame of instantaneous counts with columns: `count`, a
  minutes column (one of `interval_minutes`, `count_duration`, or
  `flight_minutes`), grouping variables (e.g., `date`, `location`), and
  optionally `total_day_minutes` or `total_minutes` for day-level
  expansion.

- by:

  Character vector of grouping variables (e.g., `date`, `location`).
  Missing columns are ignored with a warning.

- minutes_col:

  Candidate name(s) for per-count minutes. The first present is used.

- total_minutes_col:

  Candidate name(s) for dayxgroup total minutes. If absent, falls back
  to the sum of per-count minutes within the dayxgroup (warns).

- day_id:

  Day identifier (PSU), typically `date`, used to join with the survey
  design.

- covariates:

  Optional character vector of additional grouping variables (e.g.,
  `shift_block`, `day_type`).

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

  **NEW** Logical, whether to decompose variance into components
  (among-day, within-day, etc.). Adds variance decomposition to the
  variance_info output. Default FALSE for backward compatibility.

- design_diagnostics:

  **NEW** Logical, whether to compute design quality diagnostics. Adds
  diagnostic information to variance_info output. Default FALSE for
  backward compatibility.

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

  Design effect (variance inflation due to design)

- n:

  Sample size

- method:

  Estimation method ("instantaneous")

- variance_info:

  **NEW** List-column with comprehensive variance information:

The `variance_info` list-column contains:

- `variance`: Variance estimate

- `method`: Variance method used

- `method_details`: Method-specific information

- `decomposition`: Variance components (if `decompose_variance = TRUE`)

- `diagnostics`: Design diagnostics (if `design_diagnostics = TRUE`)

## Details

**NEW**: This function now natively supports multiple variance
estimation methods, variance decomposition, and design diagnostics
without requiring wrapper functions.

### Survey-Based Estimation

Aggregates per-count observations to day x group totals and uses a
day-PSU survey design to compute totals/variance via the `survey`
package. When `svy` is not provided, a non-design fallback uses
within-group variability to approximate SE/CI; prefer a valid survey
design for defensible inference.

### NEW: Advanced Variance Methods

This rebuilt function provides NATIVE support for advanced variance
estimation:

- **Standard** (`variance_method = "survey"`): Uses survey package
  public API

- **Survey Internals** (`variance_method = "svyrecvar"`): Most accurate
  for complex designs

- **Bootstrap** (`variance_method = "bootstrap"`): Resampling-based
  variance

- **Jackknife** (`variance_method = "jackknife"`): Leave-one-out
  variance

These are built-in, not wrapper functions, ensuring optimal performance.

### NEW: Variance Decomposition

Set `decompose_variance = TRUE` to decompose total variance into
components:

- Among-day variance

- Within-day variance

- Stratum effects (if stratified design)

Results are available in the `variance_info` list-column.

### NEW: Design Diagnostics

Set `design_diagnostics = TRUE` to assess design quality:

- Singleton strata/clusters detection

- Weight distribution analysis

- Sample size adequacy checks

- Design improvement recommendations

## See also

[`as_day_svydesign()`](as_day_svydesign.md),
[`tc_compute_variance()`](tc_compute_variance.md),
[`tc_decompose_variance()`](tc_decompose_variance.md),
[`tc_design_diagnostics()`](tc_design_diagnostics.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# BACKWARD COMPATIBLE: Standard usage (no change from old version)
result <- est_effort.instantaneous_rebuilt(counts, svy = design)

# NEW: Bootstrap variance
result_boot <- est_effort.instantaneous_rebuilt(
  counts,
  svy = design,
  variance_method = "bootstrap",
  n_replicates = 2000
)

# NEW: With variance decomposition
result_decomp <- est_effort.instantaneous_rebuilt(
  counts,
  svy = design,
  variance_method = "survey",
  decompose_variance = TRUE
)

# View decomposition
result_decomp$variance_info[[1]]$decomposition

# NEW: Complete analysis with all features
result_full <- est_effort.instantaneous_rebuilt(
  counts,
  svy = design,
  variance_method = "svyrecvar",
  decompose_variance = TRUE,
  design_diagnostics = TRUE
)

# View diagnostics
result_full$variance_info[[1]]$diagnostics
} # }
```
