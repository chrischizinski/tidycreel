# Example season interviews for a creel survey

Access-point interviews from the 36 sampled days in
[example_season_calendar](https://chrischizinski.com/tidycreel/dev/reference/example_season_calendar.md),
one row per angling party. Most parties had finished fishing (complete
trips); about a quarter were still fishing when interviewed (incomplete
trips). Most parties caught nothing, as on most real fisheries.

## Usage

``` r
example_season_interviews
```

## Format

A data frame with 231 rows and 8 columns:

- date:

  Interview date (Date class), a sampled day in the calendar

- day_type:

  Day type stratum: "weekday" or "weekend"

- interview_id:

  Integer interview identifier, 1 to 231

- trip_status:

  "complete" or "incomplete"

- hours_fished:

  Hours the party had fished when interviewed: the whole trip if
  complete, the time so far if incomplete

- n_anglers:

  Integer number of anglers in the party

- catch_total:

  Integer fish caught by the party, kept and released

- catch_kept:

  Integer fish kept (harvest), never more than `catch_total`

## Source

Simulated with
[`simulate_creel_data()`](https://chrischizinski.com/tidycreel/dev/reference/simulate_creel_data.md)
and a fixed seed; see `data-raw/example_season.R` in the package source.

## See also

[example_season_calendar](https://chrischizinski.com/tidycreel/dev/reference/example_season_calendar.md),
[example_season_counts](https://chrischizinski.com/tidycreel/dev/reference/example_season_counts.md)

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
[`example_season_counts`](https://chrischizinski.com/tidycreel/dev/reference/example_season_counts.md),
[`example_sections_calendar`](https://chrischizinski.com/tidycreel/dev/reference/example_sections_calendar.md),
[`example_sections_counts`](https://chrischizinski.com/tidycreel/dev/reference/example_sections_counts.md),
[`example_sections_interviews`](https://chrischizinski.com/tidycreel/dev/reference/example_sections_interviews.md)

## Examples

``` r
data(example_season_calendar)
data(example_season_counts)
data(example_season_interviews)

design <- creel_design(example_season_calendar, date = date, strata = day_type)
design <- add_counts(design, example_season_counts,
  count_col = total_anglers, period_length_col = daylight_hours
)
design <- add_interviews(design, example_season_interviews,
  catch = catch_total, harvest = catch_kept, effort = hours_fished,
  trip_status = trip_status, n_anglers = n_anglers
)
#> ℹ 153 interviews have zero catch.
#>   Zero catch is usual; check it is not missing data recorded as 0.
#> ℹ Added 231 interviews: 172 complete (74%), 59 incomplete (26%)
estimate_total_catch(design, target = "period_total")
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Total Catch (Effort × CPUE)
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Effort target: period_total
#> Unit: fish
#> 
#> # A tibble: 1 × 5
#>   estimate    se ci_lower ci_upper     n
#>      <dbl> <dbl>    <dbl>    <dbl> <int>
#> 1    2230.  482.    1278.    3183.   172
```
