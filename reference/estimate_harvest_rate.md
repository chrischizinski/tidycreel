# Estimate harvest (HPUE: Harvest Per Unit Effort) from a creel survey design

Computes HPUE estimates with standard errors and confidence intervals
from a creel survey design with attached interview data. Uses
ratio-of-means estimation via survey::svyratio() to properly account for
ratio variance. HPUE measures the rate of kept fish (harvest) per unit
effort, distinguished from total catch rate (CPUE which includes both
kept and released fish).

## Usage

``` r
estimate_harvest_rate(
  design,
  by = NULL,
  variance = "taylor",
  conf_level = 0.95,
  verbose = FALSE,
  use_trips = NULL,
  missing_sections = "warn"
)
```

## Arguments

- design:

  A creel_design object with interviews attached via
  [`add_interviews`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md).
  The design must have an interview survey object constructed with
  harvest, catch, and effort columns.

- by:

  Optional tidy selector for grouping variables. Accepts bare column
  names (e.g., `by = day_type`), multiple columns (e.g.,
  `by = c(day_type, location)`), or tidyselect helpers (e.g.,
  `by = starts_with("day")`). When NULL (default), computes a single
  HPUE estimate across all interviews.

- variance:

  Character string specifying variance estimation method. Options:
  `"taylor"` (default, Taylor linearization), `"bootstrap"` (bootstrap
  resampling with 500 replicates), or `"jackknife"` (jackknife
  resampling, automatic JKn/JK1 selection).

- conf_level:

  Numeric confidence level for confidence intervals (default: 0.95 for
  95% confidence intervals). Must be between 0 and 1.

- verbose:

  Logical. If TRUE, prints an informational message identifying which
  estimator path was used. Default FALSE.

- use_trips:

  Character string specifying which interviews to include. For standard
  (non-bus-route) designs: `"complete"` (default) restricts to completed
  trips only; `"all"` uses all interviews including incomplete trips.
  `"complete"` is the statistically preferred default because
  incomplete-trip HPUE underestimates harvest when anglers keep
  additional fish after the interview (Hansen & Van Kirk 2010). Fish
  already in the livewell are directly observable, so `"all"` remains
  available for analyses that prefer the larger interview set. For
  bus-route designs: `"complete"` (default), `"incomplete"`, or
  `"diagnostic"`. When `trip_status` was not provided to
  [`add_interviews`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md),
  this argument has no effect for standard designs.

- missing_sections:

  Character string controlling behavior when a registered section has no
  interview observations. `"warn"` (default) emits a `cli_warn()` and
  inserts an NA row with `data_available = FALSE`. `"error"` aborts with
  `cli_abort()`. Ignored for non-sectioned designs.

## Value

A creel_estimates S3 object (list) with components: estimates (tibble
with estimate, se, ci_lower, ci_upper, n columns, plus grouping columns
if `by` is specified), method (character: "ratio-of-means-hpue", with
"-per-angler" suffix when normalized), variance_method (character:
reflects the variance parameter value used), design (reference to source
creel_design), conf_level (numeric), and by_vars (character vector of
grouping variable names or NULL). For bus-route designs, a
"site_contributions" attribute is also present.

## Details

HPUE is estimated as the ratio of total harvest (kept fish) to total
effort (ratio-of-means estimator). This is the appropriate estimator for
average harvest rates when trip lengths (effort) vary. The function uses
survey::svyratio() internally, which correctly accounts for the
correlation between harvest and effort in variance estimation.

HPUE will always be less than or equal to CPUE for the same data, since
harvest (kept fish) is a subset of total catch.

The function performs sample size validation before estimation: errors
if n \< 10 (ungrouped or any group), warns if 10 \<= n \< 30. This
follows best practices for ratio estimation stability.

When grouped estimation is used (`by` is not NULL), survey::svyby() with
svyratio correctly accounts for domain estimation variance.

**Variance estimation methods:**

- `"taylor"` (default): Taylor linearization, computationally efficient
  and appropriate for smooth statistics like ratios.

- `"bootstrap"`: Bootstrap resampling with 500 replicates. Appropriate
  for verifying Taylor assumptions.

- `"jackknife"`: Jackknife resampling (automatic JKn or JK1 selection
  based on design). Alternative resampling method.

## Note

When called on a sectioned design, no `.lake_total` row is produced.
Harvest rates (fish per angler-hour) are not additive across sections.
Lake-wide harvest rate requires a separate unsectioned call.

This function defaults to using **completed-trip** interviews only for
HPUE estimation (`use_trips = "complete"`). Incomplete-trip HPUE
underestimates harvest when anglers continue fishing and keep additional
fish after being interviewed (Hansen & Van Kirk 2010), so restricting to
completed trips is the statistically preferred default. Fish already in
the livewell at interview time are directly observable, so
`use_trips = "all"` remains available to include incomplete-trip
interviews.

## See also

[`estimate_catch_rate`](https://chrischizinski.github.io/tidycreel/reference/estimate_catch_rate.md)
for total catch rate estimation

Other "Estimation":
[`compare_cpue_estimators()`](https://chrischizinski.github.io/tidycreel/reference/compare_cpue_estimators.md),
[`est_biomass()`](https://chrischizinski.github.io/tidycreel/reference/est_biomass.md),
[`est_compliance()`](https://chrischizinski.github.io/tidycreel/reference/est_compliance.md),
[`est_length_distribution()`](https://chrischizinski.github.io/tidycreel/reference/est_length_distribution.md),
[`est_mean_length()`](https://chrischizinski.github.io/tidycreel/reference/est_mean_length.md),
[`estimate_catch_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_catch_rate.md),
[`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md),
[`estimate_effort_aerial_glmm()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort_aerial_glmm.md),
[`estimate_release_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_release_rate.md),
[`estimate_total_catch()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_catch.md),
[`estimate_total_harvest()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_harvest.md),
[`estimate_total_release()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_release.md)

## Examples

``` r
# Basic ungrouped HPUE
calendar <- data.frame(
  date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
  day_type = c("weekday", "weekday", "weekend", "weekend")
)
design <- creel_design(calendar, date = date, strata = day_type)

set.seed(123)
interviews <- data.frame(
  date = as.Date(rep(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04"), each = 10)),
  catch_total = rpois(40, lambda = 3),
  hours_fished = runif(40, min = 1, max = 6),
  trip_status = rep(c("complete", "incomplete"), each = 20),
  trip_duration = runif(40, min = 1, max = 6)
)
# Harvest is subset of catch (kept fish)
interviews$catch_kept <- pmax(0, interviews$catch_total - rbinom(40, size = 2, prob = 0.3))

design_with_interviews <- add_interviews(design, interviews,
  catch = catch_total,
  harvest = catch_kept,
  effort = hours_fished,
  trip_status = trip_status,
  trip_duration = trip_duration
)
#> ℹ No `n_anglers` provided — assuming 1 angler per interview.
#> ℹ Pass `n_anglers = <column>` to use actual party sizes for angler-hour
#>   normalization.
#> Warning: 3 interviews have zero catch.
#> ℹ Zero catch may be valid (skunked) or indicate missing data.
#> ℹ Added 40 interviews: 20 complete (50%), 20 incomplete (50%)
result <- estimate_harvest_rate(design_with_interviews)
#> ℹ Filtering to complete trips for HPUE estimation
#>   (n=20, 50% of 40 interviews) [default]
#> Warning: Small sample size for harvest estimation.
#> ! Sample size is 20. Ratio estimates are more stable with n >= 30.
#> ℹ Variance estimates may be unstable with n < 30.
print(result)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Ratio-of-Means HPUE
#> Variance: Taylor linearization
#> Confidence level: 95%
#> 
#> # A tibble: 1 × 5
#>   estimate    se ci_lower ci_upper     n
#>      <dbl> <dbl>    <dbl>    <dbl> <int>
#> 1    0.917 0.202    0.521     1.31    20

# Grouped by day_type
result_grouped <- estimate_harvest_rate(design_with_interviews, by = day_type)
#> ℹ Filtering to complete trips for HPUE estimation
#>   (n=20, 50% of 40 interviews) [default]
#> Warning: Small sample size in 1 group:
#> • Group day_type=weekday: n=20
#> ! Ratio estimates are more stable with n >= 30 per group.
#> ℹ Variance estimates may be unstable with n < 30.
print(result_grouped)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Ratio-of-Means HPUE
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Grouped by: day_type
#> 
#> # A tibble: 1 × 6
#>   day_type estimate    se ci_lower ci_upper     n
#>   <chr>       <dbl> <dbl>    <dbl>    <dbl> <dbl>
#> 1 weekday     0.917 0.202    0.521     1.31    20

# Custom confidence level
result_90 <- estimate_harvest_rate(design_with_interviews, conf_level = 0.90)
#> ℹ Filtering to complete trips for HPUE estimation
#>   (n=20, 50% of 40 interviews) [default]
#> Warning: Small sample size for harvest estimation.
#> ! Sample size is 20. Ratio estimates are more stable with n >= 30.
#> ℹ Variance estimates may be unstable with n < 30.

# Bootstrap variance estimation
result_boot <- estimate_harvest_rate(design_with_interviews, variance = "bootstrap")
#> ℹ Filtering to complete trips for HPUE estimation
#>   (n=20, 50% of 40 interviews) [default]
#> Warning: Small sample size for harvest estimation.
#> ! Sample size is 20. Ratio estimates are more stable with n >= 30.
#> ℹ Variance estimates may be unstable with n < 30.

# Verbose dispatch message (shows which estimator was used for bus-route designs)
# result_verbose <- estimate_harvest_rate(design, verbose = TRUE)
```
