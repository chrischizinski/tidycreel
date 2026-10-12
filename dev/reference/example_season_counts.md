# Example season counts for a creel survey

One instantaneous angler count on each of the 36 sampled days in
[example_season_calendar](https://chrischizinski.com/tidycreel/dev/reference/example_season_calendar.md).
Each count stands for the whole 14-hour fishing day, so `daylight_hours`
is the length of the period it represents. Pass it to
[`add_counts()`](https://chrischizinski.com/tidycreel/dev/reference/add_counts.md)
as `period_length_col`: effort is then the count times the period
length, in angler-hours.

## Usage

``` r
example_season_counts
```

## Format

A data frame with 36 rows and 4 columns:

- date:

  Survey date (Date class), a sampled day in the calendar

- day_type:

  Day type stratum: "weekday" or "weekend"

- total_anglers:

  Integer number of anglers counted

- daylight_hours:

  Hours in the fishing day the count represents (14)

## Source

Simulated with
[`simulate_creel_data()`](https://chrischizinski.com/tidycreel/dev/reference/simulate_creel_data.md)
and a fixed seed; see `data-raw/example_season.R` in the package source.

## See also

[example_season_calendar](https://chrischizinski.com/tidycreel/dev/reference/example_season_calendar.md),
[example_season_interviews](https://chrischizinski.com/tidycreel/dev/reference/example_season_interviews.md)

Other "Example Datasets":
[`creel_counts_toy`](https://chrischizinski.com/tidycreel/dev/reference/creel_counts_toy.md),
[`creel_interviews_toy`](https://chrischizinski.com/tidycreel/dev/reference/creel_interviews_toy.md),
[`example_aerial_counts`](https://chrischizinski.com/tidycreel/dev/reference/example_aerial_counts.md),
[`example_aerial_glmm_counts`](https://chrischizinski.com/tidycreel/dev/reference/example_aerial_glmm_counts.md),
[`example_aerial_interviews`](https://chrischizinski.com/tidycreel/dev/reference/example_aerial_interviews.md),
[`example_ages`](https://chrischizinski.com/tidycreel/dev/reference/example_ages.md),
[`example_calendar`](https://chrischizinski.com/tidycreel/dev/reference/example_calendar.md),
[`example_camera_counts`](https://chrischizinski.com/tidycreel/dev/reference/example_camera_counts.md),
[`example_camera_interviews`](https://chrischizinski.com/tidycreel/dev/reference/example_camera_interviews.md),
[`example_camera_timestamps`](https://chrischizinski.com/tidycreel/dev/reference/example_camera_timestamps.md),
[`example_catch`](https://chrischizinski.com/tidycreel/dev/reference/example_catch.md),
[`example_counts`](https://chrischizinski.com/tidycreel/dev/reference/example_counts.md),
[`example_ice_interviews`](https://chrischizinski.com/tidycreel/dev/reference/example_ice_interviews.md),
[`example_ice_sampling_frame`](https://chrischizinski.com/tidycreel/dev/reference/example_ice_sampling_frame.md),
[`example_interviews`](https://chrischizinski.com/tidycreel/dev/reference/example_interviews.md),
[`example_lengths`](https://chrischizinski.com/tidycreel/dev/reference/example_lengths.md),
[`example_season_calendar`](https://chrischizinski.com/tidycreel/dev/reference/example_season_calendar.md),
[`example_season_interviews`](https://chrischizinski.com/tidycreel/dev/reference/example_season_interviews.md),
[`example_sections_calendar`](https://chrischizinski.com/tidycreel/dev/reference/example_sections_calendar.md),
[`example_sections_counts`](https://chrischizinski.com/tidycreel/dev/reference/example_sections_counts.md),
[`example_sections_interviews`](https://chrischizinski.com/tidycreel/dev/reference/example_sections_interviews.md)

## Examples

``` r
data(example_season_calendar)
data(example_season_counts)

design <- creel_design(example_season_calendar, date = date, strata = day_type)
design <- add_counts(design, example_season_counts,
  count_col = total_anglers, period_length_col = daylight_hours
)
estimate_effort(design, target = "period_total")
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Total
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Effort target: period_total
#> Unit: angler-hours
#> 
#> # A tibble: 1 × 7
#>   estimate    se se_between se_within ci_lower ci_upper     n
#>      <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int>
#> 1    9994. 1079.      1079.         0    7803.   12186.    36
```
