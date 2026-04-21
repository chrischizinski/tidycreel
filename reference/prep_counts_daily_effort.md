# Standardize sampled-day effort rows for count-based workflows

Converts a data frame that already contains sampled-day effort estimates
into a canonical tibble for downstream use with
[`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md).
This helper is the preferred seam for count-based workflows where raw
within-day count schedules, section probabilities, boat-party-size
adjustments, camera multipliers, or similar count-side corrections have
already been resolved outside the core estimator.

The returned table always contains canonical columns: `date`, any
selected strata columns, `effort_type`, `daily_effort`, `psu`, and
`correction_factor`. Optional columns `n_counts`, `within_day_var`, and
`source_method` are included when supplied.

## Usage

``` r
prep_counts_daily_effort(
  data,
  date,
  strata = NULL,
  effort_type,
  daily_effort,
  correction_factor = 1,
  psu = NULL,
  n_counts = NULL,
  within_day_var = NULL,
  source_method = NULL
)
```

## Arguments

- data:

  A data frame containing sampled-day effort rows.

- date:

  Tidy selector for the Date column.

- strata:

  Optional tidy selector for one or more strata columns.

- effort_type:

  Tidy selector for the effort-type column. Common values are `"bank"`
  and `"boat"`.

- daily_effort:

  Tidy selector for the numeric sampled-day effort column.

- correction_factor:

  Optional multiplicative correction applied to `daily_effort`. May be a
  scalar (defaults to `1`) or an expression that evaluates to a numeric
  vector with one value per row, including a bare column name. Values
  must be finite and strictly positive.

- psu:

  Optional tidy selector for the PSU column. Defaults to the selected
  date column when omitted.

- n_counts:

  Optional tidy selector for the number of within-day counts used to
  compute the sampled-day estimate.

- within_day_var:

  Optional tidy selector for a within-day variance or sum of squares
  column associated with the sampled-day estimate.

- source_method:

  Optional tidy selector for a column describing how the sampled-day
  effort estimate was derived (e.g. `"direct_count"`,
  `"boat_count_x_mean_party_size"`,
  `"camera_count_x_detection_correction"`).

## Value

A tibble with canonical sampled-day effort columns. Required columns are
`date`, selected strata columns (if any), `effort_type`, `daily_effort`,
`psu`, and `correction_factor`. Optional columns are appended when
supplied.

## See also

[`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)

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
[`prep_interview_catch()`](https://chrischizinski.github.io/tidycreel/reference/prep_interview_catch.md),
[`prep_interviews_trips()`](https://chrischizinski.github.io/tidycreel/reference/prep_interviews_trips.md),
[`validate_creel_schema()`](https://chrischizinski.github.io/tidycreel/reference/validate_creel_schema.md)
