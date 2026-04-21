# Normalize fishing effort to angler-hours

Multiplies per-trip effort (hours) by party size (number of anglers) to
produce angler-hours. This converts party-level effort records to
individual-angler units, which are required for CPUE and harvest-rate
computations.

This function can be called standalone on a raw data frame or is called
internally by
[`add_interviews`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md)
when constructing the design object.

## Usage

``` r
compute_angler_effort(data, effort, n_anglers)
```

## Arguments

- data:

  A data frame containing the interview records.

- effort:

  Tidy selector for the effort column (numeric, hours per trip).

- n_anglers:

  Tidy selector for the number-of-anglers column (positive integer).

## Value

The input data frame with an added `.angler_effort` column (numeric,
angler-hours). Existing columns are preserved.

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
[`compute_effort()`](https://chrischizinski.github.io/tidycreel/reference/compute_effort.md),
[`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md),
[`creel_schema()`](https://chrischizinski.github.io/tidycreel/reference/creel_schema.md),
[`est_effort_camera()`](https://chrischizinski.github.io/tidycreel/reference/est_effort_camera.md),
[`prep_counts_boat_party()`](https://chrischizinski.github.io/tidycreel/reference/prep_counts_boat_party.md),
[`prep_counts_daily_effort()`](https://chrischizinski.github.io/tidycreel/reference/prep_counts_daily_effort.md),
[`prep_interview_catch()`](https://chrischizinski.github.io/tidycreel/reference/prep_interview_catch.md),
[`prep_interviews_trips()`](https://chrischizinski.github.io/tidycreel/reference/prep_interviews_trips.md),
[`validate_creel_schema()`](https://chrischizinski.github.io/tidycreel/reference/validate_creel_schema.md)
