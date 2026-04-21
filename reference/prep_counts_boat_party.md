# Standardize boat-party sampled-day effort rows

Converts boat-count rows plus mean anglers-per-boat inputs into
canonical sampled-day effort rows for downstream use with
[`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md).
This helper is intentionally narrow: it handles the common boat-party
expansion (`boat_count * mean_party_size`) and leaves broader
source-specific reconstruction outside estimator internals.

The returned table always contains canonical columns: `date`, any
selected strata columns, `effort_type`, `daily_effort`, `psu`, and
`correction_factor`. Optional columns `n_counts`, `within_day_var`, and
`source_method` are included when supplied.

## Usage

``` r
prep_counts_boat_party(
  data,
  date,
  strata = NULL,
  boat_count,
  mean_party_size,
  effort_type = "boat",
  correction_factor = 1,
  psu = NULL,
  n_counts = NULL,
  within_day_var = NULL,
  source_method = "boat_count_x_mean_party_size"
)
```

## Arguments

- data:

  A data frame containing sampled-day boat-count rows.

- date:

  Tidy selector for the Date column.

- strata:

  Optional tidy selector for one or more strata columns.

- boat_count:

  Tidy selector for the numeric boat count column.

- mean_party_size:

  Tidy selector for the numeric mean anglers-per-boat column.

- effort_type:

  Effort-type values for output. Defaults to "boat". May be a scalar
  string/factor or an expression that evaluates to one value per row.

- correction_factor:

  Optional multiplicative correction applied after the boat-party
  expansion. May be a scalar (defaults to `1`) or an expression that
  evaluates to a numeric vector with one value per row. Values must be
  finite and strictly positive.

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

  Optional source-method values. Defaults to
  `"boat_count_x_mean_party_size"`. May be a scalar string/factor or an
  expression that evaluates to one value per row.

## Value

A tibble with canonical sampled-day effort columns. Required columns are
`date`, selected strata columns (if any), `effort_type`, `daily_effort`,
`psu`, and `correction_factor`. Optional columns are appended when
supplied.

## See also

[`prep_counts_daily_effort()`](https://chrischizinski.github.io/tidycreel/reference/prep_counts_daily_effort.md),
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
[`prep_counts_daily_effort()`](https://chrischizinski.github.io/tidycreel/reference/prep_counts_daily_effort.md),
[`prep_interview_catch()`](https://chrischizinski.github.io/tidycreel/reference/prep_interview_catch.md),
[`prep_interviews_trips()`](https://chrischizinski.github.io/tidycreel/reference/prep_interviews_trips.md),
[`validate_creel_schema()`](https://chrischizinski.github.io/tidycreel/reference/validate_creel_schema.md)
