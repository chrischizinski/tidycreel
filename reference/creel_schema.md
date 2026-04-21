# Column-mapping contract for tidycreel data sources

`creel_schema()` constructs a `creel_schema` S3 object that maps
canonical tidycreel column names to actual column and table names in a
data source. The schema is the full connection contract consumed by
`creel_connect()` and `fetch_*()` functions in the tidycreel.connect
companion package.

Construction is permissive — all column arguments default to `NULL`. Use
[`validate_creel_schema()`](https://chrischizinski.github.io/tidycreel/reference/validate_creel_schema.md)
to check that required columns for the given survey type are mapped.

## Usage

``` r
creel_schema(
  survey_type = c("instantaneous", "bus_route", "ice", "camera", "aerial"),
  interviews_table = NULL,
  counts_table = NULL,
  catch_table = NULL,
  lengths_table = NULL,
  date_col = NULL,
  catch_col = NULL,
  effort_col = NULL,
  trip_status_col = NULL,
  count_col = NULL,
  catch_uid_col = NULL,
  interview_uid_col = NULL,
  species_col = NULL,
  catch_count_col = NULL,
  catch_type_col = NULL,
  length_uid_col = NULL,
  length_mm_col = NULL,
  length_type_col = NULL,
  harvest_col = NULL,
  trip_duration_col = NULL,
  trip_start_col = NULL,
  interview_time_col = NULL,
  n_anglers_col = NULL,
  n_counted_col = NULL,
  n_interviewed_col = NULL,
  angler_type_col = NULL,
  angler_method_col = NULL,
  species_sought_col = NULL,
  refused_col = NULL
)
```

## Arguments

- survey_type:

  Survey type. One of `"instantaneous"`, `"bus_route"`, `"ice"`,
  `"camera"`, or `"aerial"`. Validated at construction via
  [`match.arg()`](https://rdrr.io/r/base/match.arg.html).

- interviews_table:

  Name of the interviews table in the data source.

- counts_table:

  Name of the counts table in the data source.

- catch_table:

  Name of the catch table in the data source.

- lengths_table:

  Name of the lengths table in the data source.

- date_col:

  Column name for survey date.

- catch_col:

  Column name for catch count in interviews.

- effort_col:

  Column name for effort (hours) in interviews.

- trip_status_col:

  Column name for trip status in interviews.

- count_col:

  Column name for angler count in counts.

- catch_uid_col:

  Column name for catch unique identifier.

- interview_uid_col:

  Column name for interview unique identifier.

- species_col:

  Column name for species.

- catch_count_col:

  Column name for catch count in the catch table.

- catch_type_col:

  Column name for catch type (harvest/release).

- length_uid_col:

  Column name for length unique identifier.

- length_mm_col:

  Column name for fish length (mm).

- length_type_col:

  Column name for length type.

- harvest_col:

  Column name for harvest count.

- trip_duration_col:

  Column name for trip duration.

- trip_start_col:

  Column name for trip start time.

- interview_time_col:

  Column name for interview time.

- n_anglers_col:

  Column name for number of anglers.

- n_counted_col:

  Column name for number of anglers counted.

- n_interviewed_col:

  Column name for number of anglers interviewed.

- angler_type_col:

  Column name for angler type.

- angler_method_col:

  Column name for fishing method.

- species_sought_col:

  Column name for target species.

- refused_col:

  Column name for refused interviews indicator.

## Value

A `creel_schema` S3 object.

## See also

Other "Survey Design":
[`add_catch()`](https://chrischizinski.github.io/tidycreel/reference/add_catch.md),
[`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md),
[`add_interviews()`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md),
[`add_lengths()`](https://chrischizinski.github.io/tidycreel/reference/add_lengths.md),
[`add_sections()`](https://chrischizinski.github.io/tidycreel/reference/add_sections.md),
[`as_hybrid_svydesign()`](https://chrischizinski.github.io/tidycreel/reference/as_hybrid_svydesign.md),
[`as_survey_design()`](https://chrischizinski.github.io/tidycreel/reference/as_survey_design.md),
[`compute_angler_effort()`](https://chrischizinski.github.io/tidycreel/reference/compute_angler_effort.md),
[`compute_effort()`](https://chrischizinski.github.io/tidycreel/reference/compute_effort.md),
[`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md),
[`est_effort_camera()`](https://chrischizinski.github.io/tidycreel/reference/est_effort_camera.md),
[`prep_counts_boat_party()`](https://chrischizinski.github.io/tidycreel/reference/prep_counts_boat_party.md),
[`prep_counts_daily_effort()`](https://chrischizinski.github.io/tidycreel/reference/prep_counts_daily_effort.md),
[`prep_interview_catch()`](https://chrischizinski.github.io/tidycreel/reference/prep_interview_catch.md),
[`prep_interviews_trips()`](https://chrischizinski.github.io/tidycreel/reference/prep_interviews_trips.md),
[`validate_creel_schema()`](https://chrischizinski.github.io/tidycreel/reference/validate_creel_schema.md)

## Examples

``` r
s <- creel_schema(
  survey_type      = "instantaneous",
  interviews_table = "vwInterviews",
  counts_table     = "vwCounts",
  date_col         = "SurveyDate",
  catch_col        = "TotalCatch",
  effort_col       = "EffortHours",
  trip_status_col  = "TripStatus",
  count_col        = "AnglerCount"
)
print(s)
#> <creel_schema: instantaneous>
#> 
#> ── interviews: vwInterviews ──
#> 
#> date -> SurveyDate
#> catch -> TotalCatch
#> effort -> EffortHours
#> trip_status -> TripStatus
#> 
#> ── counts: vwCounts ──
#> 
#> count -> AnglerCount
```
