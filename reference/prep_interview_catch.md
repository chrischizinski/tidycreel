# Standardize long catch-table rows for interview-based workflows

Converts a long-format catch table into a canonical tibble for
downstream use with
[`add_catch()`](https://chrischizinski.github.io/tidycreel/reference/add_catch.md).
The helper standardizes the interview linkage field, species field,
numeric catch counts, and normalized catch-type values while keeping the
data in long form.

The returned table always contains canonical columns: `interview_uid`,
`species`, `count`, and `catch_type`.

## Usage

``` r
prep_interview_catch(data, interview_uid, species, count, catch_type)
```

## Arguments

- data:

  A data frame in long format: one row per interview/species/catch-type
  combination.

- interview_uid:

  Tidy selector for the interview linkage column.

- species:

  Tidy selector for the species code or name column.

- count:

  Tidy selector for the numeric catch count column.

- catch_type:

  Tidy selector for the catch fate column. Values are normalized to
  lowercase.

## Value

A tibble with canonical columns `interview_uid`, `species`, `count`, and
`catch_type`.

## See also

[`add_catch()`](https://chrischizinski.github.io/tidycreel/reference/add_catch.md)

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
[`prep_interviews_trips()`](https://chrischizinski.github.io/tidycreel/reference/prep_interviews_trips.md),
[`validate_creel_schema()`](https://chrischizinski.github.io/tidycreel/reference/validate_creel_schema.md)
