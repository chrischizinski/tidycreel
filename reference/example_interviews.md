# Example interview data for creel survey

Sample angler interview data demonstrating the structure required for
[`add_interviews()`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md).
Contains 22 interviews from June 1-14, 2024, matching the
[example_calendar](https://chrischizinski.github.io/tidycreel/reference/example_calendar.md)
date range. Each row represents one angler interview with catch,
harvest, effort, trip metadata, and extended interview attributes added
in v0.5.0.

## Usage

``` r
example_interviews
```

## Format

A data frame with 22 rows and 12 columns:

- date:

  Interview date (Date class), matching
  [example_calendar](https://chrischizinski.github.io/tidycreel/reference/example_calendar.md)
  dates

- hours_fished:

  Numeric fishing effort in hours

- catch_total:

  Integer total fish caught (kept + released)

- catch_kept:

  Integer fish kept (harvest), always \<= catch_total

- trip_status:

  Character trip completion status ("complete" or "incomplete")

- trip_duration:

  Numeric trip duration in hours

- interview_id:

  Integer interview identifier (1 to 22), primary join key for
  [`add_catch()`](https://chrischizinski.github.io/tidycreel/reference/add_catch.md)
  and future species-level data functions

- angler_type:

  Angler party type: `"bank"` or `"boat"`

- angler_method:

  Fishing method: `"bait"`, `"artificial"`, or `"fly"`

- species_sought:

  Primary target species: `"walleye"`, `"bass"`, or `"panfish"`

- n_anglers:

  Integer number of anglers in party (1 to 4)

- refused:

  Logical flag indicating a refused interview (`FALSE` for all 22
  accepted interviews)

## Source

Simulated data for package examples

## See also

[example_calendar](https://chrischizinski.github.io/tidycreel/reference/example_calendar.md)
for matching calendar data,
[example_catch](https://chrischizinski.github.io/tidycreel/reference/example_catch.md)
for species-level catch data,
[`prep_interviews_trips()`](https://chrischizinski.github.io/tidycreel/reference/prep_interviews_trips.md)
to standardize interview rows,
[`add_interviews()`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md)
to attach interviews to a design

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
[`example_lengths`](https://chrischizinski.github.io/tidycreel/reference/example_lengths.md),
[`example_sections_calendar`](https://chrischizinski.github.io/tidycreel/reference/example_sections_calendar.md),
[`example_sections_counts`](https://chrischizinski.github.io/tidycreel/reference/example_sections_counts.md),
[`example_sections_interviews`](https://chrischizinski.github.io/tidycreel/reference/example_sections_interviews.md)

## Examples

``` r
# Load and use with a creel design
data(example_calendar)
data(example_interviews)

design <- creel_design(example_calendar, date = date, strata = day_type)

interviews_ready <- prep_interviews_trips(
  example_interviews,
  date = date,
  interview_uid = interview_id,
  effort_hours = hours_fished,
  trip_status = trip_status,
  trip_duration = trip_duration,
  catch_total = catch_total,
  harvest_total = catch_kept,
  angler_type = angler_type,
  angler_method = angler_method,
  species_sought = species_sought,
  n_anglers = n_anglers,
  refused = refused
)

design <- add_interviews(design, interviews_ready,
  catch = catch_total,
  effort = effort_hours,
  harvest = harvest_total,
  trip_status = trip_status,
  trip_duration = trip_duration,
  angler_type = angler_type,
  angler_method = angler_method,
  species_sought = species_sought,
  n_anglers = n_anglers,
  refused = refused
)
#> ℹ Added 22 interviews: 17 complete (77%), 5 incomplete (23%)
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
#> Effort: effort_hours
#> Harvest: harvest_total
#> Trip status: 17 complete, 5 incomplete
#> Angler type: angler_type
#> Angler method: angler_method
#> Species sought: species_sought
#> Party size: n_anglers
#> Refused: refused
#> Survey: <survey.design2> (constructed)
#> Sections: "none"
```
