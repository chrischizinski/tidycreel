# Validate incomplete trip estimates using TOST equivalence testing

Performs Two One-Sided Tests (TOST) to determine if incomplete trip CPUE
estimates are statistically equivalent to complete trip estimates within
a specified threshold. Returns validation results with recommendations
for whether incomplete trips are appropriate for estimation in the given
dataset.

## Usage

``` r
validate_incomplete_trips(
  design,
  catch,
  effort,
  by = NULL,
  variance = "taylor",
  conf_level = 0.95,
  truncate_at = 0.5
)
```

## Arguments

- design:

  A creel_design object with interviews attached via
  [`add_interviews`](https://chrischizinski.com/tidycreel/dev/reference/add_interviews.md).
  Must include trip_status field to distinguish complete from incomplete
  trips.

- catch:

  Bare column name: the design's catch column, as given to
  [`add_interviews()`](https://chrischizinski.com/tidycreel/dev/reference/add_interviews.md).
  The test always compares catch rates; any other column is an error (it
  was previously checked and then ignored).

- effort:

  Bare column name: the design's effort column, as given to
  [`add_interviews()`](https://chrischizinski.com/tidycreel/dev/reference/add_interviews.md).
  Rates use it as angler-hours (effort times `n_anglers`) when
  [`add_interviews()`](https://chrischizinski.com/tidycreel/dev/reference/add_interviews.md)
  was given a party size, and as recorded – party-hours, if that is what
  it holds – when it was not; any other column is an error.

- by:

  Optional tidy selector for grouping variables. When provided, performs
  TOST for each group independently. Overall validation passes only if
  overall test AND all group tests pass equivalence.

- variance:

  Character string specifying variance estimation method. Options:
  `"taylor"` (default), `"bootstrap"`, or `"jackknife"`. Passed to
  [`estimate_catch_rate`](https://chrischizinski.com/tidycreel/dev/reference/estimate_catch_rate.md).

- conf_level:

  Numeric confidence level for confidence intervals (default: 0.95).
  Passed to
  [`estimate_catch_rate`](https://chrischizinski.com/tidycreel/dev/reference/estimate_catch_rate.md).

- truncate_at:

  Numeric minimum trip duration (hours) for incomplete trip estimation.
  Default is 0.5 hours (30 minutes). Passed to
  [`estimate_catch_rate`](https://chrischizinski.com/tidycreel/dev/reference/estimate_catch_rate.md)
  for MOR estimator.

## Value

A creel_tost_validation S3 object (list) with components:

- `overall_test`: List with TOST results for overall comparison
  (p_lower, p_upper, equivalence_passed, diff_estimate,
  equivalence_bounds)

- `group_tests`: Data frame with per-group TOST results (only present
  for grouped estimation)

- `equivalence_threshold`: Numeric threshold used (e.g., 0.20 for ±20\\

- `passed`: Logical indicating if overall AND all groups (if applicable)
  passed equivalence

- `recommendation`: Character string with usage recommendation

- `metadata`: List with complete and incomplete trip estimates, standard
  errors, confidence intervals, and sample sizes

## Details

The function estimates CPUE separately for complete trips (using
ratio-of-means) and incomplete trips (using mean-of-ratios) via
[`estimate_catch_rate`](https://chrischizinski.com/tidycreel/dev/reference/estimate_catch_rate.md).
It then performs TOST to test equivalence within the specified
threshold.

Equivalence bounds are calculated as ±threshold \*
complete_trip_estimate. The difference variance is Var(complete) +
Var(incomplete) - 2 Cov(complete, incomplete). The two rates come from
different trips, but interview variance is clustered on the survey day,
so trips interviewed on the same days covary: when complete and
incomplete rates rise and fall together from day to day, their
difference is far more precise than either rate. Both rates are
estimated jointly, as domains of one survey of every interviewed day,
under the requested `variance` method, and the covariance comes from
that fit (GH \#664). The t tests use the design's degrees of freedom,
interviewed days minus strata over the strata a comparison draws on,
because that variance is between days (GH \#669). On bus-route and ice
designs the two rates' variances are still added: their rates are
clustered on the day as well, so this overstates the SE of the
difference, which makes the test conservative (GH \#671).

Sample size requirements: At least 10 complete trips AND 10 incomplete
trips are required for stable variance estimation and TOST. The function
errors if either sample size is insufficient.

## Package Options

The package option `tidycreel.equivalence_threshold` controls the
equivalence threshold (default: 0.20 = ±20\\ bounds for equivalence as
±threshold \* complete_trip_estimate. For example, with the default 20\\
equivalence bounds are 1.6 to 2.4 fish/hour. Users can set a custom
threshold:

`options(tidycreel.equivalence_threshold = 0.15)`

## TOST Equivalence Testing

TOST (Two One-Sided Tests) is the statistically appropriate method for
proving similarity between two estimates. Unlike traditional hypothesis
testing which tests for difference, TOST tests the null hypothesis that
estimates differ by MORE than the threshold. Equivalence is concluded
when both one-sided tests reject the null (both p-values \< 0.05).

The two tests are:

1.  H0: complete - incomplete \<= -threshold vs H1: complete -
    incomplete \> -threshold

2.  H0: complete - incomplete \>= threshold vs H1: complete - incomplete
    \< threshold

Both tests must reject (p \< 0.05) for equivalence. This ensures
estimates are "close enough" to be considered equivalent for practical
purposes.

## Grouped Validation

When `by` is provided, the function performs TOST for each group
independently AND for the overall (ungrouped) data. The validation
passes only if ALL tests pass equivalence. This conservative approach
prevents overlooking group-specific bias that could be masked by overall
equivalence.

## See also

Other "Reporting & Diagnostics":
[`adjust_nonresponse()`](https://chrischizinski.com/tidycreel/dev/reference/adjust_nonresponse.md),
[`as_tibble.creel_estimates()`](https://chrischizinski.com/tidycreel/dev/reference/as_tibble.creel_estimates.md),
[`check_completeness()`](https://chrischizinski.com/tidycreel/dev/reference/check_completeness.md),
[`compare_variance()`](https://chrischizinski.com/tidycreel/dev/reference/compare_variance.md),
[`flag_outliers()`](https://chrischizinski.com/tidycreel/dev/reference/flag_outliers.md),
[`season_summary()`](https://chrischizinski.com/tidycreel/dev/reference/season_summary.md),
[`standardize_species()`](https://chrischizinski.com/tidycreel/dev/reference/standardize_species.md),
[`summarize_boat_composition()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_boat_composition.md),
[`summarize_by_angler_type()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_by_angler_type.md),
[`summarize_by_county()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_by_county.md),
[`summarize_by_day_type()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_by_day_type.md),
[`summarize_by_method()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_by_method.md),
[`summarize_by_species_sought()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_by_species_sought.md),
[`summarize_by_trip_length()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_by_trip_length.md),
[`summarize_by_zip()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_by_zip.md),
[`summarize_cws_rates()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_cws_rates.md),
[`summarize_hws_rates()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_hws_rates.md),
[`summarize_length_freq()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_length_freq.md),
[`summarize_refusals()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_refusals.md),
[`summarize_rws_rates()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_rws_rates.md),
[`summarize_successful_parties()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_successful_parties.md),
[`summarize_trips()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_trips.md),
[`summary.creel_estimates()`](https://chrischizinski.com/tidycreel/dev/reference/summary.creel_estimates.md),
[`tidy.creel_estimates()`](https://chrischizinski.com/tidycreel/dev/reference/tidy.creel_estimates.md),
[`validate_creel_data()`](https://chrischizinski.com/tidycreel/dev/reference/validate_creel_data.md),
[`validate_design()`](https://chrischizinski.com/tidycreel/dev/reference/validate_design.md),
[`validation_report()`](https://chrischizinski.com/tidycreel/dev/reference/validation_report.md),
[`write_estimates()`](https://chrischizinski.com/tidycreel/dev/reference/write_estimates.md)

## Examples

``` r
# Create design with both complete and incomplete trips
calendar <- data.frame(
  date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
  day_type = rep(c("weekday", "weekend"), each = 2)
)
design <- creel_design(calendar, date = date, strata = day_type)

set.seed(123)
interviews <- data.frame(
  date = as.Date(rep(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04"), each = 25)),
  catch_total = rpois(100, lambda = 6),
  hours_fished = runif(100, min = 2, max = 4),
  trip_status = rep(c("complete", "incomplete"), times = 50),
  trip_duration = runif(100, min = 2, max = 4)
)

design_with_interviews <- add_interviews(design, interviews,
  catch = catch_total,
  effort = hours_fished,
  trip_status = trip_status,
  trip_duration = trip_duration
)
#> Warning: ! No `n_anglers` provided — assuming 1 angler per interview.
#> ℹ Pass `n_anglers = <column>` to use actual party sizes for angler-hour
#>   normalization.
#> ℹ If the interviews really are one angler each, pass `n_anglers = 1` to state
#>   that and silence this warning.
#> ℹ 1 interview has zero catch.
#>   Zero catch is usual; check it is not missing data recorded as 0.
#> ℹ Added 100 interviews: 50 complete (50%), 50 incomplete (50%)

# Validate incomplete trips
result <- validate_incomplete_trips(design_with_interviews,
  catch = catch_total,
  effort = hours_fished
)
print(result)
#> 
#> ── TOST Equivalence Validation Results ─────────────────────────────────────────
#> Threshold: ±20% of complete trip estimate
#> ✖ Validation FAILED
#> 
#> Recommendation: Validation failed: Use complete trips only (estimates not
#> statistically equivalent)
#> 
#> 
#> ── Overall Test ──
#> 
#> Complete trips: n = 50, CPUE = 1.964
#> Incomplete trips: n = 50, CPUE = 2.065
#> Difference: -0.101
#> Equivalence bounds: [-0.393, 0.393]
#> TOST p-values: p_lower = 0.0775, p_upper = 0.0316
#> ✖ Overall equivalence: FAILED
#> 


# Grouped validation
result_grouped <- validate_incomplete_trips(design_with_interviews,
  catch = catch_total,
  effort = hours_fished,
  by = day_type
)
#> Warning: Small sample size in 2 groups:
#> • Group day_type=weekday: n=25
#> • Group day_type=weekend: n=25
#> ! Ratio estimates are more stable with n >= 30 per group.
#> ℹ Variance estimates may be unstable with n < 30.
#> ℹ Repeats on this design are recorded, not printed: see `get_warnings()`.
print(result_grouped)
#> 
#> ── TOST Equivalence Validation Results ─────────────────────────────────────────
#> Threshold: ±20% of complete trip estimate
#> ✖ Validation FAILED
#> 
#> Recommendation: Validation failed: Use complete trips only. Groups failed
#> equivalence: day_type = weekday; day_type = weekend.
#> 
#> 
#> ── Overall Test ──
#> 
#> Complete trips: n = 50, CPUE = 1.964
#> Incomplete trips: n = 50, CPUE = 2.065
#> Difference: -0.101
#> Equivalence bounds: [-0.393, 0.393]
#> TOST p-values: p_lower = 0.0775, p_upper = 0.0316
#> ✖ Overall equivalence: FAILED
#> 
#> 
#> ── Per-Group Tests ──
#> 
#> 0/2 groups passed equivalence
#> 


# Custom equivalence threshold, restoring the previous option afterwards
old_opts <- options(tidycreel.equivalence_threshold = 0.15) # 15% threshold
result_custom <- validate_incomplete_trips(design_with_interviews,
  catch = catch_total,
  effort = hours_fished
)
options(old_opts)
```
