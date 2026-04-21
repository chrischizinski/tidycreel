# Resolve fishing effort from timestamps or self-reported time

Computes fishing effort (hours) for each interview row using a
conditional rule: if the `time_fished` column is present and non-NA for
a row, use that value (angler self-reported hours, e.g. after a break);
otherwise compute from timestamps as
`difftime(interview_time, trip_start, units = "hours")`.

This function can be called standalone on raw data before entering the
[`add_interviews`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md)
workflow, or used to preprocess a column that will be passed as the
`effort` argument to
[`add_interviews()`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md).

## Usage

``` r
compute_effort(data, trip_start, interview_time, time_fished = NULL)
```

## Arguments

- data:

  A data frame containing the interview records.

- trip_start:

  Tidy selector for the trip start timestamp column (POSIXct).

- interview_time:

  Tidy selector for the interview timestamp column (POSIXct).

- time_fished:

  Optional tidy selector for a self-reported hours column. When a row
  has a non-NA value here, it overrides the timestamp calculation.
  Default is `NULL` (always compute from timestamps).

## Value

The input data frame with an added `.effort` column (numeric, hours).
Existing columns are preserved.

## See also

[`compute_angler_effort()`](https://chrischizinski.github.io/tidycreel/reference/compute_angler_effort.md),
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
[`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md),
[`creel_schema()`](https://chrischizinski.github.io/tidycreel/reference/creel_schema.md),
[`est_effort_camera()`](https://chrischizinski.github.io/tidycreel/reference/est_effort_camera.md),
[`prep_counts_boat_party()`](https://chrischizinski.github.io/tidycreel/reference/prep_counts_boat_party.md),
[`prep_counts_daily_effort()`](https://chrischizinski.github.io/tidycreel/reference/prep_counts_daily_effort.md),
[`prep_interview_catch()`](https://chrischizinski.github.io/tidycreel/reference/prep_interview_catch.md),
[`prep_interviews_trips()`](https://chrischizinski.github.io/tidycreel/reference/prep_interviews_trips.md),
[`validate_creel_schema()`](https://chrischizinski.github.io/tidycreel/reference/validate_creel_schema.md)
