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
  mean_party_size_se = NULL,
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

- mean_party_size_se:

  Optional standard error of `mean_party_size`. May be a scalar or an
  expression evaluating to one value per row. Supplying it emits the
  `expansion_*` carrier columns, which
  [`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)
  reads so the reported standard error includes the party-size sampling
  error.

  `NULL` (the default) leaves the component absent rather than zero. A
  zero would enter the variance as "the multiplier is known exactly" and
  be indistinguishable from never having propagated, so the two states
  are kept apart. `NA` is accepted and propagates as unknown.

  Before tidycreel 3.4.0 this argument did not exist, and the component
  was unreachable on this path: the same expansion through
  [`derive_angler_count()`](https://chrischizinski.github.io/tidycreel/reference/derive_angler_count.md)
  reported a larger, correct standard error while this one silently
  omitted the term (GH \#143).

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

  Optional tidy selector for the number of within-day counts each
  sampled-day estimate is built from (k_d). Required whenever
  `within_day_var` is supplied.

- within_day_var:

  Optional tidy selector for the within-day **sum of squares** of the
  counts behind each sampled-day estimate, that is
  `sum((x - mean(x))^2)` per PSU. This is not a variance: the divisor is
  applied downstream by the estimator, which forms
  `sum(ss_d) / (n_sampled * (k_bar - 1))`. Supplying a variance here
  understates the within-day component by a factor of `k_d - 1`. Must be
  `0` wherever `n_counts` is 1, and requires `n_counts`.

  Supply it on the raw `boat_count` values you pass in; it is rescaled
  into `daily_effort` squared units on output, multiplied by
  `(mean_party_size * correction_factor)^2`.
  [`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)
  reads the emitted `within_day_var` and `n_counts` columns into the
  design, so the reported SE carries a within-day component. Before
  tidycreel 2.6.0 both columns were written here and never read, and the
  SE omitted that component entirely. Do not combine with
  `add_counts(count_time_col = )`, which derives the same quantity from
  raw counts; supplying both is an error.

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
[`as_creel_svydesign()`](https://chrischizinski.github.io/tidycreel/reference/as_creel_svydesign.md),
[`as_hybrid_svydesign()`](https://chrischizinski.github.io/tidycreel/reference/as_hybrid_svydesign.md),
[`compute_angler_effort()`](https://chrischizinski.github.io/tidycreel/reference/compute_angler_effort.md),
[`compute_effort()`](https://chrischizinski.github.io/tidycreel/reference/compute_effort.md),
[`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md),
[`creel_schema()`](https://chrischizinski.github.io/tidycreel/reference/creel_schema.md),
[`creel_vocabulary()`](https://chrischizinski.github.io/tidycreel/reference/creel_vocabulary.md),
[`derive_angler_count()`](https://chrischizinski.github.io/tidycreel/reference/derive_angler_count.md),
[`est_effort_camera()`](https://chrischizinski.github.io/tidycreel/reference/est_effort_camera.md),
[`impute_camera_counts()`](https://chrischizinski.github.io/tidycreel/reference/impute_camera_counts.md),
[`mean_party_size()`](https://chrischizinski.github.io/tidycreel/reference/mean_party_size.md),
[`prep_counts_daily_effort()`](https://chrischizinski.github.io/tidycreel/reference/prep_counts_daily_effort.md),
[`prep_interview_catch()`](https://chrischizinski.github.io/tidycreel/reference/prep_interview_catch.md),
[`prep_interviews_trips()`](https://chrischizinski.github.io/tidycreel/reference/prep_interviews_trips.md),
[`validate_creel_schema()`](https://chrischizinski.github.io/tidycreel/reference/validate_creel_schema.md)
