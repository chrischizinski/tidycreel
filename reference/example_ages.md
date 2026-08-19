# Example fish age data for creel estimation

A small set of individual fish age records (one row per aged fish)
linked to
[`example_interviews`](https://chrischizinski.github.io/tidycreel/reference/example_interviews.md).
Suitable for use with
[`add_ages`](https://chrischizinski.github.io/tidycreel/reference/add_ages.md).

## Usage

``` r
example_ages
```

## Format

A data frame with 18 rows and 4 columns:

- interview_id:

  Integer interview identifier. Foreign key to
  `example_interviews$interview_id`.

- species:

  Character. Species name: `"walleye"`, `"bass"`, or `"panfish"`.

- age:

  Integer. Estimated age in years (0-6). Each row is a single aged fish.

- age_type:

  Character. Fish fate: `"harvest"` or `"release"`.

## Source

Simulated data for package examples.

## See also

[`example_interviews`](https://chrischizinski.github.io/tidycreel/reference/example_interviews.md),
[`example_lengths`](https://chrischizinski.github.io/tidycreel/reference/example_lengths.md),
[`add_ages`](https://chrischizinski.github.io/tidycreel/reference/add_ages.md)

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
[`example_sections_calendar`](https://chrischizinski.github.io/tidycreel/reference/example_sections_calendar.md),
[`example_sections_counts`](https://chrischizinski.github.io/tidycreel/reference/example_sections_counts.md),
[`example_sections_interviews`](https://chrischizinski.github.io/tidycreel/reference/example_sections_interviews.md)

## Examples

``` r
data(example_calendar)
data(example_interviews)
data(example_ages)

design <- creel_design(example_calendar, date = date, strata = day_type)
design <- add_interviews(design, example_interviews,
  catch = catch_total, effort = hours_fished, harvest = catch_kept,
  trip_status = trip_status, trip_duration = trip_duration
)
#> ℹ No `n_anglers` provided — assuming 1 angler per interview.
#> ℹ Pass `n_anglers = <column>` to use actual party sizes for angler-hour
#>   normalization.
#> ℹ Added 22 interviews: 17 complete (77%), 5 incomplete (23%)
design <- add_ages(design, example_ages,
  age_uid = interview_id,
  interview_uid = interview_id,
  species = species,
  age = age,
  age_type = age_type
)
print(design)
#> 
#> ── Creel Survey Design ─────────────────────────────────────────────────────────
#> Type: "instantaneous"
#> Date column: date
#> Strata: day_type
#> Calendar: 14 days (2024-06-01 to 2024-06-14)
#> day_type: 2 levels
#> Counts: "none"
#> Interviews: 22 observations
#> Type: "access"
#> Catch: catch_total
#> Effort: hours_fished
#> Harvest: catch_kept
#> Trip status: 17 complete, 5 incomplete
#> Survey: <survey.design2> (constructed)
#> Sections: "none"
```
