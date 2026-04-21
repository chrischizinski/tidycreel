# Example species catch data for creel survey

Long-format species-level catch data linked to
[example_interviews](https://chrischizinski.github.io/tidycreel/reference/example_interviews.md).
Contains catch, harvest, and release counts per species per interview
for 12 of the 22 interviews. Interviews with zero total catch have no
rows in this dataset (zero-catch anglers are represented by absence).

## Usage

``` r
example_catch
```

## Format

A data frame with columns:

- interview_id:

  Integer, foreign key to
  [example_interviews](https://chrischizinski.github.io/tidycreel/reference/example_interviews.md)`$interview_id`

- species:

  Character species name: `"walleye"`, `"bass"`, or `"panfish"`

- count:

  Integer fish count for this species and catch type

- catch_type:

  Character catch disposition: `"caught"` (total observed),
  `"harvested"` (kept), or `"released"`

## Source

Simulated data for package examples

## See also

[example_interviews](https://chrischizinski.github.io/tidycreel/reference/example_interviews.md)
for the corresponding interview-level data,
[`prep_interview_catch()`](https://chrischizinski.github.io/tidycreel/reference/prep_interview_catch.md)
to standardize species catch, and
[`add_catch()`](https://chrischizinski.github.io/tidycreel/reference/add_catch.md)
to attach species catch to a design

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
data(example_catch)

design <- creel_design(example_calendar, date = date, strata = day_type)
interviews_ready <- prep_interviews_trips(
  example_interviews,
  date = date,
  interview_uid = interview_id,
  effort_hours = hours_fished,
  trip_status = trip_status,
  trip_duration = trip_duration,
  catch_total = catch_total,
  harvest_total = catch_kept
)
design <- add_interviews(design, interviews_ready,
  catch = catch_total,
  effort = effort_hours,
  harvest = harvest_total,
  trip_status = trip_status,
  trip_duration = trip_duration
)
#> ℹ No `n_anglers` provided — assuming 1 angler per interview.
#> ℹ Pass `n_anglers = <column>` to use actual party sizes for angler-hour
#>   normalization.
#> ℹ Added 22 interviews: 17 complete (77%), 5 incomplete (23%)

catch_ready <- prep_interview_catch(example_catch,
  interview_uid = interview_id,
  species = species,
  count = count,
  catch_type = catch_type
)
design <- add_catch(design, catch_ready,
  catch_uid = interview_uid,
  interview_uid = interview_uid,
  species = species,
  count = count,
  catch_type = catch_type
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
#> Effort: effort_hours
#> Harvest: harvest_total
#> Trip status: 17 complete, 5 incomplete
#> Survey: <survey.design2> (constructed)
#> Catch Data: 42 rows, 3 species
#> caught: 8, harvested: 17, released: 17
#> Sections: "none"
```
