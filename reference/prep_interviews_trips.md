# Standardize trip/interview rows for interview-based workflows

Converts raw-ish interview records into a canonical tibble for
downstream use with
[`add_interviews()`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md).
This helper standardizes the trip/interview unit, computes effort from
timestamps when needed, normalizes `trip_status`, and emits stable
columns for effort, trip duration, angler party size, and optional
interview attributes.

The returned table always contains canonical columns: `date`,
`interview_uid`, `effort_hours`, `trip_status`, `trip_duration`,
`n_anglers`, and `refused`. Optional columns such as `catch_total`,
`harvest_total`, `angler_type`, `angler_method`, `species_sought`, and
any selected strata are appended when supplied.

## Usage

``` r
prep_interviews_trips(
  data,
  date,
  interview_uid,
  effort_hours = NULL,
  trip_status,
  trip_duration = NULL,
  trip_start = NULL,
  interview_time = NULL,
  catch_total = NULL,
  harvest_total = NULL,
  angler_type = NULL,
  angler_method = NULL,
  species_sought = NULL,
  n_anglers = NULL,
  refused = NULL,
  strata = NULL
)
```

## Arguments

- data:

  A data frame containing interview records.

- date:

  Tidy selector for the Date column.

- interview_uid:

  Tidy selector for the unique interview identifier.

- effort_hours:

  Optional tidy selector for an effort-in-hours column. Supply this when
  hours are already available directly.

- trip_status:

  Tidy selector for the trip-status column. Values are normalized to
  lowercase and must resolve to `"complete"` or `"incomplete"`.

- trip_duration:

  Optional tidy selector for a trip duration column in hours. When
  omitted, the helper uses `effort_hours` if present or computes
  duration from `trip_start` and `interview_time`.

- trip_start:

  Optional tidy selector for trip start timestamps.

- interview_time:

  Optional tidy selector for interview timestamps. When `effort_hours`
  is omitted, `trip_start` and `interview_time` are used to compute
  effort in hours.

- catch_total:

  Optional tidy selector for total catch per trip.

- harvest_total:

  Optional tidy selector for total harvest per trip.

- angler_type:

  Optional tidy selector for angler type (e.g. `"bank"`, `"boat"`).

- angler_method:

  Optional tidy selector for fishing method.

- species_sought:

  Optional tidy selector for the target species field.

- n_anglers:

  Optional tidy selector for party size. Defaults to `1L` when omitted.

- refused:

  Optional tidy selector for the refused interview flag. Defaults to
  `FALSE` when omitted.

- strata:

  Optional tidy selector for one or more strata columns to carry forward
  into the standardized output.

## Value

A tibble with canonical trip/interview columns ready for
[`add_interviews()`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md).

## See also

[`compute_effort()`](https://chrischizinski.github.io/tidycreel/reference/compute_effort.md),
[`add_interviews()`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md)

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
[`creel_schema()`](https://chrischizinski.github.io/tidycreel/reference/creel_schema.md),
[`est_effort_camera()`](https://chrischizinski.github.io/tidycreel/reference/est_effort_camera.md),
[`prep_counts_boat_party()`](https://chrischizinski.github.io/tidycreel/reference/prep_counts_boat_party.md),
[`prep_counts_daily_effort()`](https://chrischizinski.github.io/tidycreel/reference/prep_counts_daily_effort.md),
[`prep_interview_catch()`](https://chrischizinski.github.io/tidycreel/reference/prep_interview_catch.md),
[`validate_creel_schema()`](https://chrischizinski.github.io/tidycreel/reference/validate_creel_schema.md)
