# Bus-Route Effort Estimation (REBUILT with Native Survey Integration)

Estimate fishing effort for bus-route designs using a
Horvitz–Thompson-style day×group total and compute design-based totals
and variance via the `survey` package with NATIVE support for advanced
variance methods.

## Usage

``` r
est_effort.busroute_design(
  x,
  counts = NULL,
  by = c("date", "location"),
  day_id = "date",
  inclusion_prob_col = "inclusion_prob",
  route_minutes_col = "route_minutes",
  contrib_hours_col = NULL,
  covariates = NULL,
  svy = NULL,
  conf_level = 0.95,
  variance_method = "survey",
  decompose_variance = FALSE,
  design_diagnostics = FALSE,
  n_replicates = 1000,
  ...
)
```

## Arguments

- x:

  A `busroute_design` object.

- counts:

  Optional tibble/data.frame of observation data. If `x` contains
  `$counts`, that will be used by default.

- by:

  Character vector of grouping variables to retain in output (e.g.,
  `date`, `location`). Missing columns are ignored with a warning.

- day_id:

  Day identifier (PSU), typically `date`.

- inclusion_prob_col:

  Column name with inclusion probability `pi` for each observed
  party/vehicle or count segment (default `inclusion_prob`).

- route_minutes_col:

  Per-visit route minutes column to translate counts to time (default
  `route_minutes`). Used if `contrib_hours_col` is not given.

- contrib_hours_col:

  Optional precomputed contribution in hours for each observed unit
  (e.g., observed overlap hours). If present, the HT contribution is
  `contrib_hours / pi`. Otherwise uses `count / pi * route_minutes/60`.

- covariates:

  Optional character vector of additional grouping variables.

- svy:

  Optional `svydesign`/`svrepdesign` encoding day-level sampling. If
  absent, a day-PSU design is constructed from `x$calendar` via
  [`as_day_svydesign()`](as_day_svydesign.md).

- conf_level:

  Confidence level for CI (default 0.95).

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

- ...:

  Reserved for future arguments.

## Value

A tibble with group columns, `estimate`, `se`, `ci_low`, `ci_high`,
`deff` (design effect), `n`, `method`, `diagnostics` list-column, and
`variance_info` list-column with comprehensive variance information.

## Details

**NEW**: Native support for multiple variance methods, variance
decomposition, and design diagnostics without requiring wrapper
functions.

Computes day × group totals using Horvitz–Thompson contributions and
uses a day-PSU survey design to compute totals/variance via the `survey`
package. Replicate-weight designs are supported by passing a
`svrepdesign`.

## References

Malvestuto, S.P. (1996). Sampling for creel survey data. In: Murphy,
B.R. & Willis, D.W. (eds) Fisheries Techniques, 2nd Edition. American
Fisheries Society.

## Examples

``` r
if (FALSE) { # \dontrun{
# BACKWARD COMPATIBLE
result <- est_effort(design, by = c("date", "location"))

# NEW: Advanced features
result <- est_effort(
  design,
  by = c("date", "location"),
  variance_method = "bootstrap",
  decompose_variance = TRUE,
  design_diagnostics = TRUE
)

# Access enhanced information
result$variance_info[[1]]$decomposition
result$variance_info[[1]]$diagnostics
} # }
```
