# Example season calendar for a creel survey

The calendar of one simulated 120-day open-water season, May 1 to August
28, 2024, used by
[`vignette("tidycreel")`](https://chrischizinski.com/tidycreel/dev/articles/tidycreel.md).
Days are stratified into weekdays and weekends by the real day of the
week. The clerk sampled 36 of the 120 days, so estimates of the season
total expand the sampled days to every day in the calendar.

## Usage

``` r
example_season_calendar
```

## Format

A data frame with 120 rows and 3 columns:

- date:

  Calendar date (Date class)

- day_type:

  Day type stratum: "weekday" or "weekend"

- sampled:

  Logical: `TRUE` on the 36 days with counts and interviews

## Source

Simulated with
[`simulate_creel_data()`](https://chrischizinski.com/tidycreel/dev/reference/simulate_creel_data.md)
and a fixed seed; see `data-raw/example_season.R` in the package source.

## See also

[example_season_counts](https://chrischizinski.com/tidycreel/dev/reference/example_season_counts.md),
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
[`example_roving_interviews`](https://chrischizinski.com/tidycreel/dev/reference/example_roving_interviews.md),
[`example_season_counts`](https://chrischizinski.com/tidycreel/dev/reference/example_season_counts.md),
[`example_season_interviews`](https://chrischizinski.com/tidycreel/dev/reference/example_season_interviews.md),
[`example_sections_calendar`](https://chrischizinski.com/tidycreel/dev/reference/example_sections_calendar.md),
[`example_sections_counts`](https://chrischizinski.com/tidycreel/dev/reference/example_sections_counts.md),
[`example_sections_interviews`](https://chrischizinski.com/tidycreel/dev/reference/example_sections_interviews.md)

## Examples

``` r
data(example_season_calendar)
table(example_season_calendar$day_type, example_season_calendar$sampled)
#>          
#>           FALSE TRUE
#>   weekday    58   28
#>   weekend    26    8

design <- creel_design(example_season_calendar, date = date, strata = day_type)
design
#> 
#> ── Creel Survey Design ─────────────────────────────────────────────────────────
#> Type: "instantaneous"
#> Date column: date
#> Strata: day_type
#> Calendar: 120 days (2024-05-01 to 2024-08-28)
#> day_type: 2 levels
#> Counts: "none"
#> Interviews: "none"
#> Sections: "none"
```
