# Example count data for creel survey

Sample daily effort observations matching
[example_calendar](https://chrischizinski.com/tidycreel/dev/reference/example_calendar.md).
One row per survey date, suitable for use with
[`add_counts()`](https://chrischizinski.com/tidycreel/dev/reference/add_counts.md)
and
[`estimate_effort()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_effort.md).

## Usage

``` r
example_counts
```

## Format

A data frame with 14 rows and 3 columns:

- date:

  Survey date (Date class), matching
  [example_calendar](https://chrischizinski.com/tidycreel/dev/reference/example_calendar.md)
  dates

- day_type:

  Day type stratum: "weekday" or "weekend", matching calendar

- effort_hours:

  Numeric angler-hours observed on the survey date

## Source

Simulated data for package examples

## Details

The effort column holds angler-hours, not raw angler counts. Pass it
through
[`prep_counts_daily_effort()`](https://chrischizinski.com/tidycreel/dev/reference/prep_counts_daily_effort.md)
before
[`add_counts()`](https://chrischizinski.com/tidycreel/dev/reference/add_counts.md),
as in the example, so it is expanded as daily effort. Given to
[`add_counts()`](https://chrischizinski.com/tidycreel/dev/reference/add_counts.md)
directly it is treated as an instantaneous count, and
[`estimate_effort()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_effort.md)
warns that no count period length was supplied.

## See also

[example_calendar](https://chrischizinski.com/tidycreel/dev/reference/example_calendar.md)
for matching calendar data,
[`add_counts()`](https://chrischizinski.com/tidycreel/dev/reference/add_counts.md)
to attach counts to a design

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
[`example_ice_interviews`](https://chrischizinski.com/tidycreel/dev/reference/example_ice_interviews.md),
[`example_ice_sampling_frame`](https://chrischizinski.com/tidycreel/dev/reference/example_ice_sampling_frame.md),
[`example_interviews`](https://chrischizinski.com/tidycreel/dev/reference/example_interviews.md),
[`example_lengths`](https://chrischizinski.com/tidycreel/dev/reference/example_lengths.md),
[`example_season_calendar`](https://chrischizinski.com/tidycreel/dev/reference/example_season_calendar.md),
[`example_season_counts`](https://chrischizinski.com/tidycreel/dev/reference/example_season_counts.md),
[`example_season_interviews`](https://chrischizinski.com/tidycreel/dev/reference/example_season_interviews.md),
[`example_sections_calendar`](https://chrischizinski.com/tidycreel/dev/reference/example_sections_calendar.md),
[`example_sections_counts`](https://chrischizinski.com/tidycreel/dev/reference/example_sections_counts.md),
[`example_sections_interviews`](https://chrischizinski.com/tidycreel/dev/reference/example_sections_interviews.md)

## Examples

``` r
# Load and use with a creel design
data(example_calendar)
data(example_counts)

design <- creel_design(example_calendar, date = date, strata = day_type)
counts <- prep_counts_daily_effort(example_counts,
  date = date, strata = day_type, daily_effort = effort_hours
)
design <- add_counts(design, counts)
result <- estimate_effort(design)
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
#> 1     372.  13.2       13.2         0     344.     401.    14
```
