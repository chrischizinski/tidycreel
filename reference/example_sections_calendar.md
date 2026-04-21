# Example calendar for spatially stratified creel survey

A 12-day survey calendar used to demonstrate the spatially stratified
workflow with
[`add_sections()`](https://chrischizinski.github.io/tidycreel/reference/add_sections.md).
Contains 6 weekdays and 6 weekends from June 2024. Matches the date
range of
[example_sections_counts](https://chrischizinski.github.io/tidycreel/reference/example_sections_counts.md)
and
[example_sections_interviews](https://chrischizinski.github.io/tidycreel/reference/example_sections_interviews.md).

## Usage

``` r
example_sections_calendar
```

## Format

A data frame with 12 rows and 2 columns:

- date:

  Survey date (Date class), June 2024

- day_type:

  Day type stratum: `"weekday"` or `"weekend"`

## Source

Simulated data for package examples

## See also

[example_sections_counts](https://chrischizinski.github.io/tidycreel/reference/example_sections_counts.md),
[example_sections_interviews](https://chrischizinski.github.io/tidycreel/reference/example_sections_interviews.md),
[`add_sections()`](https://chrischizinski.github.io/tidycreel/reference/add_sections.md),
[`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md)

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
[`example_ice_interviews`](https://chrischizinski.github.io/tidycreel/reference/example_ice_interviews.md),
[`example_ice_sampling_frame`](https://chrischizinski.github.io/tidycreel/reference/example_ice_sampling_frame.md),
[`example_interviews`](https://chrischizinski.github.io/tidycreel/reference/example_interviews.md),
[`example_lengths`](https://chrischizinski.github.io/tidycreel/reference/example_lengths.md),
[`example_sections_counts`](https://chrischizinski.github.io/tidycreel/reference/example_sections_counts.md),
[`example_sections_interviews`](https://chrischizinski.github.io/tidycreel/reference/example_sections_interviews.md)

## Examples

``` r
data(example_sections_calendar)
head(example_sections_calendar)
#>         date day_type
#> 1 2024-06-03  weekday
#> 2 2024-06-04  weekday
#> 3 2024-06-05  weekday
#> 4 2024-06-06  weekday
#> 5 2024-06-07  weekday
#> 6 2024-06-10  weekday

design <- creel_design(example_sections_calendar, date = date, strata = day_type)
print(design)
#> 
#> ── Creel Survey Design ─────────────────────────────────────────────────────────
#> Type: "instantaneous"
#> Date column: date
#> Strata: day_type
#> Calendar: 12 days (2024-06-03 to 2024-06-21)
#> day_type: 2 levels
#> Counts: "none"
#> Interviews: "none"
#> Sections: "none"
```
