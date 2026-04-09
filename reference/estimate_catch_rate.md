# Estimate CPUE (Catch Per Unit Effort) from a creel survey design

Computes CPUE estimates with standard errors and confidence intervals
from a creel survey design with attached interview data. Supports both
ratio-of-means (for complete trips) and mean-of-ratios (for incomplete
trips) estimation methods.

## Usage

``` r
estimate_catch_rate(
  design,
  by = NULL,
  variance = "taylor",
  conf_level = 0.95,
  estimator = "ratio-of-means",
  use_trips = NULL,
  truncate_at = 0.5,
  targeted = TRUE,
  missing_sections = "warn"
)
```

## Arguments

- design:

  A creel_design object with interviews attached via
  [`add_interviews`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md).
  The design must have an interview survey object constructed with catch
  and effort columns.

- by:

  Optional tidy selector for grouping variables. Accepts bare column
  names (e.g., `by = day_type`), multiple columns (e.g.,
  `by = c(day_type, location)`), or tidyselect helpers (e.g.,
  `by = starts_with("day")`). When NULL (default), computes a single
  CPUE estimate across all interviews.

- variance:

  Character string specifying variance estimation method. Options:
  `"taylor"` (default, Taylor linearization), `"bootstrap"` (bootstrap
  resampling with 500 replicates), or `"jackknife"` (jackknife
  resampling, automatic JKn/JK1 selection).

- conf_level:

  Numeric confidence level for confidence intervals (default: 0.95 for
  95% confidence intervals). Must be between 0 and 1.

- estimator:

  Character string specifying estimation method. Options:
  `"ratio-of-means"` (default, for complete trips), `"mor"`
  (mean-of-ratios, for incomplete trips), or `"mortr"` (truncated
  mean-of-ratios — same as `"mor"` but `truncate_at` is mandatory and
  defaults to 0.5 h). MOR and MORtr require the trip_status field and
  error if no incomplete trips are available. See Details.

- use_trips:

  Character string specifying which trip type to use when trip_status
  field is provided. Options: `"complete"` (default when NULL) uses only
  complete trips with ratio-of-means estimator, `"incomplete"` uses only
  incomplete trips with mean-of-ratios estimator, or `"diagnostic"`
  estimates CPUE using both trip types and returns a comparison table.
  Following Pollock et al. (1994), complete trips are scientifically
  preferred (no length-of-stay bias). Incomplete trip estimation is
  diagnostic/research mode requiring validation. Diagnostic mode
  requires both complete and incomplete trips to be present. Default is
  NULL which defaults to `"complete"`. Parameter is ignored when
  trip_status field is not provided (perfect backward compatibility).
  See Details.

- truncate_at:

  Numeric minimum trip duration (hours) for MOR estimation. Default is
  0.5 hours (30 minutes) per Hoenig et al. (1997) to prevent unstable
  variance from very short trips. Trips with duration \< truncate_at are
  excluded before MOR estimation. Set to NULL to disable truncation
  (research mode only). Ignored for ratio-of-means estimator.

- targeted:

  Logical. When `TRUE` (default), all trips are used. When `FALSE`,
  zero-effort trips are excluded before MOR/MORtr estimation —
  appropriate for non-targeted species where most trips have zero catch.
  A `cli_warn()` is emitted when more than 70\\ have zero catch and
  `targeted = TRUE` (possible mis-specification). Ignored for
  `ratio-of-means` estimator.

- missing_sections:

  Character string controlling behavior when a registered section has no
  interview observations. `"warn"` (default) emits a `cli_warn()` and
  inserts an NA row with `data_available = FALSE`. `"error"` aborts with
  `cli_abort()`. Ignored for non-sectioned designs.

## Value

A creel_estimates S3 object (list) with components: estimates (tibble
with estimate, se, ci_lower, ci_upper, n columns, plus grouping columns
if `by` is specified), method (character: "ratio-of-means-cpue" or
"mean-of-ratios-cpue", with "-per-angler" suffix when normalized),
variance_method (character: reflects the variance parameter value used),
design (reference to source creel_design), conf_level (numeric), and
by_vars (character vector of grouping variable names or NULL).

## Details

**Trip Type Selection (use_trips):** When trip_status is provided, the
`use_trips` parameter controls which trips are used for estimation. The
default `use_trips = "complete"` filters to complete trips only,
following roving-access design best practices (Pollock et al. 1994).
Complete trip interviews are taken at trip completion and avoid
length-of-stay bias. Setting `use_trips = "incomplete"` filters to
incomplete trips and automatically uses the MOR estimator. Incomplete
trip estimation is diagnostic/research mode and requires validation (see
Phase 19 validate_incomplete_trips). Setting `use_trips = "diagnostic"`
runs both complete and incomplete trip estimation and returns a
comparison object with difference metrics and interpretation guidance.
Diagnostic mode requires both trip types to be present in the data. When
trip_status is not provided, use_trips is ignored for perfect backward
compatibility with v0.2.0.

**Ratio-of-Means (default):** CPUE is estimated as the ratio of total
catch to total effort. This is the appropriate estimator for complete
trip interviews (interview at trip end). The function uses
survey::svyratio() internally, which correctly accounts for the
correlation between catch and effort in variance estimation.

**Mean-of-Ratios (MOR):** When `estimator = "mor"`, CPUE is estimated as
the mean of individual catch/effort ratios. This is the statistically
appropriate estimator for incomplete trip interviews (interview during
trip). MOR automatically filters to incomplete trips only and requires
the trip_status field. The function uses survey::svymean() on individual
ratios.

**Trip Truncation:** Very short incomplete trips can produce extreme
catch/effort ratios that dominate variance estimation. Following Hoenig
et al. (1997), the default `truncate_at = 0.5` hours (30 minutes)
excludes trips shorter than this threshold before MOR estimation. The
survey design is rebuilt with the truncated sample for correct variance
computation. Set `truncate_at = NULL` to disable truncation (research
mode only). Truncation only applies to MOR estimator; ratio-of-means
ignores this parameter.

The function performs sample size validation before estimation: errors
if n \< 10 (ungrouped or any group), warns if 10 \<= n \< 30. For MOR,
validation uses the post-truncation sample size. This follows best
practices for ratio estimation stability.

When grouped estimation is used (`by` is not NULL), survey::svyby()
correctly accounts for domain estimation variance.

**Variance estimation methods:**

- `"taylor"` (default): Taylor linearization, computationally efficient
  and appropriate for smooth statistics like ratios.

- `"bootstrap"`: Bootstrap resampling with 500 replicates. Appropriate
  for verifying Taylor assumptions.

- `"jackknife"`: Jackknife resampling (automatic JKn or JK1 selection
  based on design). Alternative resampling method.

## Note

When called on a sectioned design, no `.lake_total` row is produced.
Catch rates (fish per angler-hour) are not additive across sections.
Lake-wide catch rate requires a separate unsectioned call on the full
design. See
[`estimate_total_catch()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_catch.md)
for lake-wide total catch estimation.

## Package Options

**Complete Trip Percentage Threshold:** The package option
`tidycreel.min_complete_pct` controls the threshold for complete trip
percentage warnings (default: 0.10 = 10\\ percentage of complete trips
falls below this threshold, a warning is issued referencing Pollock et
al. roving-access design best practices. Users can set a custom
threshold for their session:

`options(tidycreel.min_complete_pct = 0.05)`

The default 10\\ scientifically valid estimation. Lowering the threshold
is appropriate only for special cases with documented justification.
Warnings help ensure data quality and guide users toward diagnostic
validation when complete trip samples are insufficient.

## Examples

``` r
# Basic ungrouped CPUE
calendar <- data.frame(
  date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
  day_type = c("weekday", "weekday", "weekend", "weekend")
)
design <- creel_design(calendar, date = date, strata = day_type)

interviews <- data.frame(
  date = as.Date(rep(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04"), each = 10)),
  catch_total = rpois(40, lambda = 3),
  hours_fished = runif(40, min = 1, max = 6),
  trip_status = rep(c("complete", "incomplete"), each = 20),
  trip_duration = runif(40, min = 1, max = 6)
)

design_with_interviews <- add_interviews(design, interviews,
  catch = catch_total,
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
result <- estimate_catch_rate(design_with_interviews)
#> ℹ Using complete trips for CPUE estimation
#>   (n=20, 50% of 40 interviews) [default]
#> Warning: Small sample size for CPUE estimation.
#> ! Sample size is 20. Ratio estimates are more stable with n >= 30.
#> ℹ Variance estimates may be unstable with n < 30.
print(result)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Ratio-of-Means CPUE
#> Variance: Taylor linearization
#> Confidence level: 95%
#> 
#> # A tibble: 1 × 5
#>   estimate    se ci_lower ci_upper     n
#>      <dbl> <dbl>    <dbl>    <dbl> <int>
#> 1     1.06 0.171    0.722     1.39    20

# Grouped by day_type
result_grouped <- estimate_catch_rate(design_with_interviews, by = day_type)
#> Warning: ! Only 0.0% of interviews are complete trips (threshold: 10%)
#> ℹ Pollock et al. recommends >=10% complete trips for valid estimation
#> ℹ Consider use_trips='diagnostic' to validate incomplete trip estimates
#> ℹ Using complete trips for CPUE estimation
#>   (n=20, 50% of 40 interviews) [default]
#> Warning: Small sample size in 1 group:
#> • Group day_type=weekday: n=20
#> ! Ratio estimates are more stable with n >= 30 per group.
#> ℹ Variance estimates may be unstable with n < 30.
print(result_grouped)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Ratio-of-Means CPUE
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Grouped by: day_type
#> 
#> # A tibble: 1 × 6
#>   day_type estimate    se ci_lower ci_upper     n
#>   <chr>       <dbl> <dbl>    <dbl>    <dbl> <dbl>
#> 1 weekday      1.06 0.171    0.722     1.39    20

# Custom confidence level
result_90 <- estimate_catch_rate(design_with_interviews, conf_level = 0.90)
#> ℹ Using complete trips for CPUE estimation
#>   (n=20, 50% of 40 interviews) [default]
#> Warning: Small sample size for CPUE estimation.
#> ! Sample size is 20. Ratio estimates are more stable with n >= 30.
#> ℹ Variance estimates may be unstable with n < 30.

# Bootstrap variance estimation
result_boot <- estimate_catch_rate(design_with_interviews, variance = "bootstrap")
#> ℹ Using complete trips for CPUE estimation
#>   (n=20, 50% of 40 interviews) [default]
#> Warning: Small sample size for CPUE estimation.
#> ! Sample size is 20. Ratio estimates are more stable with n >= 30.
#> ℹ Variance estimates may be unstable with n < 30.

# Mean-of-ratios for incomplete trips
result_mor <- estimate_catch_rate(design_with_interviews, estimator = "mor")
#> ℹ Using incomplete trips for CPUE estimation
#>   (n=20, 50% of 40 interviews)
#> Warning: ! MOR estimator for incomplete trips. Complete trips preferred.
#> ℹ Using MOR with n=20 incomplete of 20 total interviews.
#> ℹ Incomplete trips may have length-of-stay bias (Pollock et al.).
#> ℹ Validate incomplete estimates with `validate_incomplete_trips()` (Phase 19).
#> ℹ MOR truncation: 0 trips excluded (all >= 0.5 hours)
#> Warning: Small sample size for CPUE estimation.
#> ! Sample size is 20. Ratio estimates are more stable with n >= 30.
#> ℹ Variance estimates may be unstable with n < 30.

# Mean-of-ratios with custom truncation threshold
result_mor_1h <- estimate_catch_rate(design_with_interviews, estimator = "mor", truncate_at = 1.0)
#> ℹ Using incomplete trips for CPUE estimation
#>   (n=20, 50% of 40 interviews)
#> Warning: ! MOR estimator for incomplete trips. Complete trips preferred.
#> ℹ Using MOR with n=20 incomplete of 20 total interviews.
#> ℹ Incomplete trips may have length-of-stay bias (Pollock et al.).
#> ℹ Validate incomplete estimates with `validate_incomplete_trips()` (Phase 19).
#> ℹ MOR truncation: 0 trips excluded (all >= 1 hours)
#> Warning: Small sample size for CPUE estimation.
#> ! Sample size is 20. Ratio estimates are more stable with n >= 30.
#> ℹ Variance estimates may be unstable with n < 30.
```
