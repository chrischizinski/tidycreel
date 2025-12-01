# CPUE Estimator (REBUILT with Native Survey Integration)

Design-based estimation of catch per unit effort (CPUE) using the
`survey` package with NATIVE support for advanced variance methods.

## Usage

``` r
est_cpue(
  design,
  by = NULL,
  response = c("catch_total", "catch_kept", "weight_total"),
  effort_col = "hours_fished",
  mode = c("auto", "ratio_of_means", "mean_of_ratios"),
  min_trip_hours = 0.5,
  conf_level = 0.95,
  variance_method = "survey",
  decompose_variance = FALSE,
  design_diagnostics = FALSE,
  n_replicates = 1000
)
```

## Arguments

- design:

  A `svydesign`/`svrepdesign` built on interview data, or a
  `creel_design` containing `interviews`. If a `creel_design` is
  supplied, a minimal equal-weight design is constructed (warns).

- by:

  Character vector of grouping variables present in the interview data
  (e.g., `c("target_species","location")`). Missing columns are ignored
  with a warning.

- response:

  One of `"catch_total"`, `"catch_kept"`, or `"weight_total"`.
  Determines the CPUE numerator.

- effort_col:

  Interview effort column for the denominator (default
  `"hours_fished"`).

- mode:

  Estimation mode: `"auto"` (default), `"ratio_of_means"`, or
  `"mean_of_ratios"`.

- min_trip_hours:

  Minimum trip duration for incomplete trips (default 0.5).

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

Tibble with grouping columns, `estimate`, `se`, `ci_low`, `ci_high`,
`deff` (design effect), `n`, `method`, `diagnostics` list-column, and
`variance_info` list-column.

## Details

**NEW**: Native support for multiple variance methods, variance
decomposition, and design diagnostics without requiring wrapper
functions.

- **Auto mode**: Examines `trip_complete` field to determine appropriate
  estimator.

- **Ratio-of-means**: Robust for incomplete trips

- **Mean-of-ratios**: Preferred for complete trips

- **For roving surveys**: Use [`est_cpue_roving()`](est_cpue_roving.md)
  for Pollock correction

## See also

[`est_cpue_roving()`](est_cpue_roving.md),
[`survey::svyratio()`](https://rdrr.io/pkg/survey/man/svyratio.html),
[`survey::svymean()`](https://rdrr.io/pkg/survey/man/surveysummary.html)

## Examples

``` r
if (FALSE) { # \dontrun{
# BACKWARD COMPATIBLE
result <- est_cpue(design, response = "catch_kept")

# NEW: Advanced features
result <- est_cpue(
  design,
  response = "catch_kept",
  variance_method = "bootstrap",
  decompose_variance = TRUE,
  design_diagnostics = TRUE
)
} # }
```
