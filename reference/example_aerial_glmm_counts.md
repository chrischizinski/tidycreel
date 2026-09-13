# Example multi-flight aerial count data for GLMM effort estimation

Simulated instantaneous angler counts from aerial overflights of a
Nebraska reservoir, designed to demonstrate GLMM-based effort estimation
following Askey (2018). Contains 48 rows: 12 survey days with 4
overflights per day at fixed hours (07:00, 10:00, 13:00, 16:00). Counts
follow a diurnal curve (low at dawn, peak mid-morning, lower in
afternoon) with day-level Poisson variability and a day random
intercept.

## Usage

``` r
example_aerial_glmm_counts
```

## Format

A data frame with 48 rows and 4 columns:

- date:

  Survey date (Date class), 12 days spaced 3 days apart starting
  2024-06-03.

- day_type:

  Day type stratum: `"weekday"` or `"weekend"`, derived from the
  calendar date.

- n_anglers:

  Instantaneous angler count from one aerial overflight (integer).
  Follows a diurnal curve with day-level random effects.

- time_of_flight:

  Hour of the aerial overflight (numeric). One of `7.0`, `10.0`, `13.0`,
  or `16.0`.

## Source

Simulated data following Askey (2018) NAJFM doi:10.1002/nafm.10010.

## References

Askey, P.J., Ward, H., Godin, T., Boucher, M., and Northrup, S. (2018).
Angler effort estimates from instantaneous aerial counts: use of
high-frequency time-lapse camera data to inform model-based estimators.
North American Journal of Fisheries Management, 38, 194-209.
[doi:10.1002/nafm.10010](https://doi.org/10.1002/nafm.10010)

## See also

[example_aerial_counts](https://chrischizinski.com/tidycreel/reference/example_aerial_counts.md)
for the simple single-flight dataset,
[`estimate_effort_aerial_glmm()`](https://chrischizinski.com/tidycreel/reference/estimate_effort_aerial_glmm.md)
for the GLMM-based estimator,
[`creel_design()`](https://chrischizinski.com/tidycreel/reference/creel_design.md),
[`add_counts()`](https://chrischizinski.com/tidycreel/reference/add_counts.md)

Other "Example Datasets":
[`creel_counts_toy`](https://chrischizinski.com/tidycreel/reference/creel_counts_toy.md),
[`creel_interviews_toy`](https://chrischizinski.com/tidycreel/reference/creel_interviews_toy.md),
[`example_aerial_counts`](https://chrischizinski.com/tidycreel/reference/example_aerial_counts.md),
[`example_aerial_interviews`](https://chrischizinski.com/tidycreel/reference/example_aerial_interviews.md),
[`example_ages`](https://chrischizinski.com/tidycreel/reference/example_ages.md),
[`example_calendar`](https://chrischizinski.com/tidycreel/reference/example_calendar.md),
[`example_camera_counts`](https://chrischizinski.com/tidycreel/reference/example_camera_counts.md),
[`example_camera_interviews`](https://chrischizinski.com/tidycreel/reference/example_camera_interviews.md),
[`example_camera_timestamps`](https://chrischizinski.com/tidycreel/reference/example_camera_timestamps.md),
[`example_catch`](https://chrischizinski.com/tidycreel/reference/example_catch.md),
[`example_counts`](https://chrischizinski.com/tidycreel/reference/example_counts.md),
[`example_ice_interviews`](https://chrischizinski.com/tidycreel/reference/example_ice_interviews.md),
[`example_ice_sampling_frame`](https://chrischizinski.com/tidycreel/reference/example_ice_sampling_frame.md),
[`example_interviews`](https://chrischizinski.com/tidycreel/reference/example_interviews.md),
[`example_lengths`](https://chrischizinski.com/tidycreel/reference/example_lengths.md),
[`example_sections_calendar`](https://chrischizinski.com/tidycreel/reference/example_sections_calendar.md),
[`example_sections_counts`](https://chrischizinski.com/tidycreel/reference/example_sections_counts.md),
[`example_sections_interviews`](https://chrischizinski.com/tidycreel/reference/example_sections_interviews.md)

## Examples

``` r
data(example_aerial_glmm_counts)
head(example_aerial_glmm_counts)
#>         date day_type n_anglers time_of_flight
#> 1 2024-06-03  weekday         3              7
#> 2 2024-06-03  weekday        30             10
#> 3 2024-06-03  weekday        65             13
#> 4 2024-06-03  weekday        50             16
#> 5 2024-06-06  weekday         5              7
#> 6 2024-06-06  weekday        15             10

# The workflow below fits a GLMM, so it needs lme4 (a Suggests).
if (rlang::is_installed("lme4")) {
# Build an aerial design and estimate effort with GLMM correction
aerial_cal <- data.frame(
  date = unique(example_aerial_glmm_counts$date),
  day_type = unique(example_aerial_glmm_counts[, c("date", "day_type")])[["day_type"]],
  stringsAsFactors = FALSE
)
design <- creel_design(
  aerial_cal,
  date = date,
  strata = day_type,
  survey_type = "aerial",
  visibility_correction = "none",
  angler_ratio = 1,
  angler_ratio_se = 0,
  h_open = 14
)
design <- add_counts(design, example_aerial_glmm_counts, count_col = n_anglers)
result <- estimate_effort_aerial_glmm(design, time_col = time_of_flight)
print(result)
}
#> Warning: `counts` has 36 repeated sampling units, with no count time to tell them apart.
#> ℹ The repeated rows are keyed on date and day_type.
#> ℹ Estimators that sum these rows refuse them; supply `count_time_col` if they
#>   are repeat counts, or `unit_cols` if they are distinct units.
#> Warning: No weights or probabilities supplied, assuming equal probability
#> Warning: iteration limit reached
#> ℹ Integration window start derived from data: 6.5 h (earliest flight - 0.5 h).
#>   Specify `open_start` in `creel_design()` for a fixed fishery opening time.
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: aerial_glmm_total
#> Variance: delta
#> Confidence level: 95%
#> model: 32.98 (known, but se is `NA`)
#> visibility: NA (unknown, so se is `NA`)
#> angler_ratio: 0 (known, but se is `NA`)
#> 
#> # A tibble: 1 × 7
#>   estimate    se se_between se_within ci_lower ci_upper     n
#>      <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int>
#> 1     379.    NA         NA        NA       NA       NA    48
```
