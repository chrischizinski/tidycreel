# Example roving interviews for a creel survey

Roving interviews from the 36 sampled days in
[example_season_calendar](https://chrischizinski.com/tidycreel/dev/reference/example_season_calendar.md),
one row per angling party. A roving clerk meets parties while they fish,
so every trip is incomplete: `hours_fished` and `catch_total` are the
hours fished and the fish caught so far. Pair with
[example_season_counts](https://chrischizinski.com/tidycreel/dev/reference/example_season_counts.md)
for effort.

## Usage

``` r
example_roving_interviews
```

## Format

A data frame with 212 rows and 8 columns:

- date:

  Interview date (Date class), a sampled day in the calendar

- day_type:

  Day type stratum: "weekday" or "weekend"

- interview_id:

  Integer interview identifier, 1 to 212

- trip_status:

  Always "incomplete"

- hours_fished:

  Hours the party had fished when interviewed

- n_anglers:

  Integer number of anglers in the party

- catch_total:

  Integer fish caught so far, kept and released

- catch_kept:

  Integer fish kept so far, never more than `catch_total`

## Source

Simulated with a fixed seed; see `data-raw/example_roving_interviews.R`
in the package source.

## Details

The parties were simulated so that the true catch rate is known: 0.22
fish per angler-hour. A party's chance of being met is proportional to
its trip length, it is met at a random point in its trip, and its catch
so far accrues at the true rate over the time fished so far. Parties
that had fished less than 15 minutes were not interviewed.

## See also

[example_season_interviews](https://chrischizinski.com/tidycreel/dev/reference/example_season_interviews.md)
for access interviews on the same days,
[`vignette("instantaneous-counts")`](https://chrischizinski.com/tidycreel/dev/articles/instantaneous-counts.md)

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
[`example_season_interviews`](https://chrischizinski.com/tidycreel/dev/reference/example_season_interviews.md),
[`example_sections_calendar`](https://chrischizinski.com/tidycreel/dev/reference/example_sections_calendar.md),
[`example_sections_counts`](https://chrischizinski.com/tidycreel/dev/reference/example_sections_counts.md),
[`example_sections_interviews`](https://chrischizinski.com/tidycreel/dev/reference/example_sections_interviews.md)

## Examples

``` r
data(example_season_calendar)
data(example_season_counts)
data(example_roving_interviews)

design <- creel_design(example_season_calendar, date = date, strata = day_type)
design <- add_counts(design, example_season_counts,
  count_col = total_anglers, period_length_col = daylight_hours
)
design <- add_interviews(design, example_roving_interviews,
  catch = catch_total, harvest = catch_kept, effort = hours_fished,
  trip_status = trip_status, trip_duration = hours_fished,
  n_anglers = n_anglers, interview_type = "roving"
)
#> ℹ 133 interviews have zero catch.
#>   Zero catch is usual; check it is not missing data recorded as 0.
#> ℹ Added 212 interviews: 0 complete (0%), 212 incomplete (100%)
estimate_catch_rate(design)
#> ℹ Roving design: using all 212 interviews for CPUE via MOR [auto]
#>   (0 complete, 212 incomplete)
#>   Override with `use_trips = 'complete'` for access-point estimation.
#> Warning: ! MOR truncation: 29 trips excluded (13.7%)
#> ℹ Trips < 0.5 hours excluded to prevent unstable variance
#> ! High truncation rate may indicate data quality issues
#> ℹ Consider reviewing trip duration data for errors
#> ℹ Repeats on this design are recorded, not printed: see `get_warnings()`.
#> ── MOR Estimator (All Trips) ───────────────────────────────────────────────────
#> Averages per-trip CPUE ratios over 183 interviews (183 incomplete).
#> Truncation: 29 trips excluded (< 0.5 hours)
#> 
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Mean-of-Ratios CPUE
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Unit: fish/angler-hour
#> 
#> # A tibble: 1 × 5
#>   estimate     se ci_lower ci_upper     n
#>      <dbl>  <dbl>    <dbl>    <dbl> <int>
#> 1    0.191 0.0193    0.154    0.229   183
```
