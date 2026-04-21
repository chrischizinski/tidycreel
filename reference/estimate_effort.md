# Estimate total effort from a creel survey design

Computes total effort estimates with standard errors and confidence
intervals from a creel survey design with attached count data. Wraps
survey::svytotal() (ungrouped) or survey::svyby() (grouped) with Tier 2
validation and domain-specific output formatting.

## Usage

``` r
estimate_effort(
  design,
  by = NULL,
  variance = "taylor",
  conf_level = 0.95,
  target = c("sampled_days", "stratum_total", "period_total"),
  verbose = FALSE,
  aggregate_sections = TRUE,
  method = "correlated",
  missing_sections = "warn"
)
```

## Arguments

- design:

  A creel_design object with counts attached via
  [`add_counts`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md).
  The design must have a survey object constructed.

- by:

  Optional tidy selector for grouping variables. Accepts bare column
  names (e.g., `by = day_type`), multiple columns (e.g.,
  `by = c(day_type, location)`), or tidyselect helpers (e.g.,
  `by = starts_with("day")`). When NULL (default), computes a single
  total estimate across all observations.

- variance:

  Character string specifying variance estimation method. Options:
  `"taylor"` (default, Taylor linearization), `"bootstrap"` (bootstrap
  resampling with 500 replicates), or `"jackknife"` (jackknife
  resampling, automatic JKn/JK1 selection).

- conf_level:

  Numeric confidence level for confidence intervals (default: 0.95 for
  95% confidence intervals). Must be between 0 and 1.

- target:

  Character string specifying the temporal effort target. Options:
  `"sampled_days"` (default, current behavior: total across sampled PSU
  rows only), `"stratum_total"` (expand sampled-day means within
  calendar strata before combining), or `"period_total"` (full
  calendar-period total after stratum expansion). For standard
  stratified count designs, `"stratum_total"` and `"period_total"` use
  the same weighted expansion engine; the distinction is semantic and is
  recorded on the returned object as `effort_target`. Expanded targets
  are currently limited to the standard count-design path and are not
  yet supported for bus-route, ice, aerial, or sectioned designs.

- verbose:

  Logical. If TRUE, prints an informational message identifying which
  estimator path was used. Default FALSE for transparent dispatch.

- aggregate_sections:

  Logical. If TRUE (default), a `.lake_total` row is appended
  aggregating across all sections. Ignored for non-sectioned designs.

- method:

  Character string specifying how the lake-wide total SE is computed
  when `aggregate_sections = TRUE`. `"correlated"` (default) uses
  `svyby(covmat=TRUE)` +
  [`svycontrast()`](https://rdrr.io/pkg/survey/man/svycontrast.html) for
  covariance-aware aggregation (recommended for shared-calendar NGPC
  designs). `"independent"` uses Cochran 5.2 `sqrt(sum(SE_h^2))` as a
  documented approximation for genuinely independent section designs.
  Ignored for non-sectioned designs.

- missing_sections:

  Character string controlling behavior when a registered section has no
  count observations. `"warn"` (default) emits a `cli_warn()` and
  inserts an NA row with `data_available = FALSE`. `"error"` aborts with
  `cli_abort()`. Ignored for non-sectioned designs.

## Value

A creel_estimates S3 object (list) with components: estimates (tibble
with estimate, se, se_between, se_within, ci_lower, ci_upper, n columns,
plus grouping columns if `by` is specified), method (character:
"total"), variance_method (character: reflects the variance parameter
value used), design (reference to source creel_design), conf_level
(numeric), and by_vars (character vector of grouping variable names or
NULL). `se_between` is the between-day standard error from
[`survey::svytotal()`](https://rdrr.io/pkg/survey/man/surveysummary.html)
(equals `se` when a single count is recorded per PSU). `se_within` is
the within-day standard error from the Rasmussen two-stage formula; it
is zero when a single count is recorded per PSU and nonzero when
`count_time_col` is supplied to
[`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md).
For bus-route designs, a "site_contributions" attribute is also present
containing per-site e_i, pi_i, and e_i_over_pi_i columns.

## Details

The function performs Tier 2 validation before estimation, issuing
warnings (not errors) for: zero values in count variables, negative
values in count variables, and sparse strata (\< 3 observations). When
grouped estimation is used (`by` is not NULL), additional warnings are
issued for sparse groups (\< 3 observations per group level).

Grouped estimation uses
[`survey::svyby()`](https://rdrr.io/pkg/survey/man/svyby.html)
internally, which correctly accounts for domain estimation variance.
This is different from naive subsetting, which would underestimate
variance.

**Variance estimation methods:**

- `"taylor"` (default): Taylor linearization, computationally efficient
  and appropriate for most smooth statistics. This is the recommended
  default.

- `"bootstrap"`: Bootstrap resampling with 500 replicates. Appropriate
  for non-smooth statistics or verifying Taylor assumptions. More
  computationally intensive than Taylor.

- `"jackknife"`: Jackknife resampling (automatic JKn or JK1 selection
  based on design). Alternative resampling method, deterministic unlike
  bootstrap.

## See also

Other "Estimation":
[`est_length_distribution()`](https://chrischizinski.github.io/tidycreel/reference/est_length_distribution.md),
[`estimate_catch_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_catch_rate.md),
[`estimate_effort_aerial_glmm()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort_aerial_glmm.md),
[`estimate_harvest_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_harvest_rate.md),
[`estimate_release_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_release_rate.md),
[`estimate_total_catch()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_catch.md),
[`estimate_total_harvest()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_harvest.md),
[`estimate_total_release()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_release.md)

## Examples

``` r
# Basic ungrouped usage
calendar <- data.frame(
  date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
  day_type = c("weekday", "weekday", "weekend", "weekend")
)
design <- creel_design(calendar, date = date, strata = day_type)

counts <- data.frame(
  date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
  day_type = c("weekday", "weekday", "weekend", "weekend"),
  effort_hours = c(15, 23, 45, 52)
)

design_with_counts <- add_counts(design, counts)
#> Warning: No weights or probabilities supplied, assuming equal probability
result <- estimate_effort(design_with_counts)
#> Warning: 2 strata have fewer than 3 observations:
#> • Stratum weekday: 2 observations
#> • Stratum weekend: 2 observations
#> ! Sparse strata produce unstable variance estimates.
#> ℹ Consider combining sparse strata or collecting more data.
print(result)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Total
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Effort target: sampled_days
#> 
#> # A tibble: 1 × 7
#>   estimate    se se_between se_within ci_lower ci_upper     n
#>      <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int>
#> 1      135  10.6       10.6         0     89.3     181.     4

# Grouped by day_type
result_grouped <- estimate_effort(design_with_counts, by = day_type)
#> Warning: 2 strata have fewer than 3 observations:
#> • Stratum weekday: 2 observations
#> • Stratum weekend: 2 observations
#> ! Sparse strata produce unstable variance estimates.
#> ℹ Consider combining sparse strata or collecting more data.
#> Warning: 2 groups have fewer than 3 observations:
#> • Group day_type=weekday: 2 observations
#> • Group day_type=weekend: 2 observations
#> ! Sparse groups produce unstable variance estimates.
#> ℹ Consider combining sparse groups or collecting more data.
print(result_grouped)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Total
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Grouped by: day_type
#> Effort target: sampled_days
#> 
#> # A tibble: 2 × 8
#>   day_type estimate    se se_between se_within ci_lower ci_upper     n
#>   <chr>       <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <dbl>
#> 1 weekday        38     8          8         0     3.58     72.4     2
#> 2 weekend        97     7          7         0    66.9     127.      2

# Note: Multiple grouping variables are supported if present in the data
# For example: by = c(day_type, location)

# Custom confidence level
result_90 <- estimate_effort(design_with_counts, conf_level = 0.90)
#> Warning: 2 strata have fewer than 3 observations:
#> • Stratum weekday: 2 observations
#> • Stratum weekend: 2 observations
#> ! Sparse strata produce unstable variance estimates.
#> ℹ Consider combining sparse strata or collecting more data.

# Bootstrap variance estimation
result_boot <- estimate_effort(design_with_counts, variance = "bootstrap")
#> Warning: 2 strata have fewer than 3 observations:
#> • Stratum weekday: 2 observations
#> • Stratum weekend: 2 observations
#> ! Sparse strata produce unstable variance estimates.
#> ℹ Consider combining sparse strata or collecting more data.
print(result_boot)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Total
#> Variance: Bootstrap
#> Confidence level: 95%
#> Effort target: sampled_days
#> 
#> # A tibble: 1 × 7
#>   estimate    se se_between se_within ci_lower ci_upper     n
#>      <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int>
#> 1      135  9.86       9.86         0     92.6     177.     4

# Jackknife variance estimation
result_jk <- estimate_effort(design_with_counts, variance = "jackknife")
#> Warning: 2 strata have fewer than 3 observations:
#> • Stratum weekday: 2 observations
#> • Stratum weekend: 2 observations
#> ! Sparse strata produce unstable variance estimates.
#> ℹ Consider combining sparse strata or collecting more data.
print(result_jk)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Total
#> Variance: Jackknife
#> Confidence level: 95%
#> Effort target: sampled_days
#> 
#> # A tibble: 1 × 7
#>   estimate    se se_between se_within ci_lower ci_upper     n
#>      <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int>
#> 1      135  10.6       10.6         0     89.3     181.     4

# Grouped estimation with bootstrap variance
result_grouped_boot <- estimate_effort(design_with_counts, by = day_type, variance = "bootstrap")
#> Warning: 2 strata have fewer than 3 observations:
#> • Stratum weekday: 2 observations
#> • Stratum weekend: 2 observations
#> ! Sparse strata produce unstable variance estimates.
#> ℹ Consider combining sparse strata or collecting more data.
#> Warning: 2 groups have fewer than 3 observations:
#> • Group day_type=weekday: 2 observations
#> • Group day_type=weekend: 2 observations
#> ! Sparse groups produce unstable variance estimates.
#> ℹ Consider combining sparse groups or collecting more data.

# Verbose dispatch message (shows which estimator was used for bus-route designs)
result_verbose <- estimate_effort(design_with_counts, verbose = TRUE)
#> Warning: 2 strata have fewer than 3 observations:
#> • Stratum weekday: 2 observations
#> • Stratum weekend: 2 observations
#> ! Sparse strata produce unstable variance estimates.
#> ℹ Consider combining sparse strata or collecting more data.
```
