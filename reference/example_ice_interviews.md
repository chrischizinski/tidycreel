# Example interview data for ice fishing creel survey

Angler interview data for an ice fishing creel survey at Lake
McConaughy, Nebraska. Contains 72 interviews across 12 sampling days in
January-February 2024. Anglers fish from both open-air setups and
enclosed dark-house shelters, targeting walleye and yellow perch. Dates
match
[example_ice_sampling_frame](https://chrischizinski.github.io/tidycreel/reference/example_ice_sampling_frame.md).

## Usage

``` r
example_ice_interviews
```

## Format

A data frame with 72 rows and 10 columns:

- date:

  Interview date (Date class), matching
  [example_ice_sampling_frame](https://chrischizinski.github.io/tidycreel/reference/example_ice_sampling_frame.md)

- n_counted:

  Integer total number of angler parties counted at the access point
  during the sampling period

- n_interviewed:

  Integer number of parties actually interviewed; always `<= n_counted`

- hours_on_ice:

  Numeric hours the angler party was physically on the ice (total
  time-on-ice effort)

- active_fishing_hours:

  Numeric hours spent actively fishing, excluding travel, setup, and
  breaks; always `<= hours_on_ice`

- walleye_catch:

  Integer total walleye caught (kept + released)

- perch_catch:

  Integer total yellow perch caught (kept + released)

- walleye_kept:

  Integer walleye harvested; always `<= walleye_catch`

- perch_kept:

  Integer yellow perch harvested; always `<= perch_catch`

- trip_status:

  Character trip completion status: `"complete"` or `"incomplete"`

- shelter_mode:

  Character shelter type used by the angler party: `"open"` (no shelter)
  or `"dark_house"` (enclosed shelter). Used to stratify effort
  estimates by shelter type.

## Source

Simulated data based on Nebraska ice fishing survey protocols.

## See also

[example_ice_sampling_frame](https://chrischizinski.github.io/tidycreel/reference/example_ice_sampling_frame.md)
for the matching sampling frame,
[`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md),
[`add_interviews()`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md),
[`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md)

Other "Example Datasets":
[`creel_counts_toy`](https://chrischizinski.github.io/tidycreel/reference/creel_counts_toy.md),
[`creel_interviews_toy`](https://chrischizinski.github.io/tidycreel/reference/creel_interviews_toy.md),
[`example_aerial_counts`](https://chrischizinski.github.io/tidycreel/reference/example_aerial_counts.md),
[`example_aerial_glmm_counts`](https://chrischizinski.github.io/tidycreel/reference/example_aerial_glmm_counts.md),
[`example_aerial_interviews`](https://chrischizinski.github.io/tidycreel/reference/example_aerial_interviews.md),
[`example_calendar`](https://chrischizinski.github.io/tidycreel/reference/example_calendar.md),
[`example_camera_counts`](https://chrischizinski.github.io/tidycreel/reference/example_camera_counts.md),
[`example_camera_interviews`](https://chrischizinski.github.io/tidycreel/reference/example_camera_interviews.md),
[`example_camera_timestamps`](https://chrischizinski.github.io/tidycreel/reference/example_camera_timestamps.md),
[`example_catch`](https://chrischizinski.github.io/tidycreel/reference/example_catch.md),
[`example_counts`](https://chrischizinski.github.io/tidycreel/reference/example_counts.md),
[`example_ice_sampling_frame`](https://chrischizinski.github.io/tidycreel/reference/example_ice_sampling_frame.md),
[`example_interviews`](https://chrischizinski.github.io/tidycreel/reference/example_interviews.md),
[`example_lengths`](https://chrischizinski.github.io/tidycreel/reference/example_lengths.md),
[`example_sections_calendar`](https://chrischizinski.github.io/tidycreel/reference/example_sections_calendar.md),
[`example_sections_counts`](https://chrischizinski.github.io/tidycreel/reference/example_sections_counts.md),
[`example_sections_interviews`](https://chrischizinski.github.io/tidycreel/reference/example_sections_interviews.md)

## Examples

``` r
data(example_ice_sampling_frame)
data(example_ice_interviews)

# Build an ice fishing design with scalar period sampling probability
design <- creel_design(
  example_ice_sampling_frame,
  date = date,
  strata = day_type,
  survey_type = "ice",
  effort_type = "time_on_ice",
  p_period = 0.5
)

design <- suppressMessages(add_interviews(
  design,
  example_ice_interviews,
  catch = walleye_catch,
  effort = hours_on_ice,
  harvest = walleye_kept,
  trip_status = trip_status,
  n_counted = n_counted,
  n_interviewed = n_interviewed
))
#> Warning: 23 interviews have zero catch.
#> ℹ Zero catch may be valid (skunked) or indicate missing data.
suppressWarnings(estimate_effort(design))
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Total
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Effort target: sampled_days
#> 
#> # A tibble: 1 × 5
#>   total_effort_hr_on_ice    se ci_lower ci_upper     n
#>                    <dbl> <dbl>    <dbl>    <dbl> <int>
#> 1                  2406.  107.    2196.    2615.    72
```
