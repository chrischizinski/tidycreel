# Standardize sampled-day effort rows for count-based workflows

Converts a data frame that already contains sampled-day effort estimates
into a canonical tibble for downstream use with
[`add_counts()`](https://chrischizinski.com/tidycreel/reference/add_counts.md).
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

  Supply it on the raw `daily_effort` values you pass in; it is rescaled
  into `daily_effort` squared units on output, multiplied by
  `correction_factor^2`.
  [`add_counts()`](https://chrischizinski.com/tidycreel/reference/add_counts.md)
  reads the emitted `within_day_var` and `n_counts` columns into the
  design, so the reported SE carries a within-day component. Before
  tidycreel 2.6.0 both columns were written here and never read, and the
  SE omitted that component entirely. Do not combine with
  `add_counts(count_time_col = )`, which derives the same quantity from
  raw counts; supplying both is an error.

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

[`add_counts()`](https://chrischizinski.com/tidycreel/reference/add_counts.md)

Other "Survey Design":
[`add_catch()`](https://chrischizinski.com/tidycreel/reference/add_catch.md),
[`add_counts()`](https://chrischizinski.com/tidycreel/reference/add_counts.md),
[`add_interviews()`](https://chrischizinski.com/tidycreel/reference/add_interviews.md),
[`add_lengths()`](https://chrischizinski.com/tidycreel/reference/add_lengths.md),
[`add_sections()`](https://chrischizinski.com/tidycreel/reference/add_sections.md),
[`as_creel_svydesign()`](https://chrischizinski.com/tidycreel/reference/as_creel_svydesign.md),
[`as_hybrid_svydesign()`](https://chrischizinski.com/tidycreel/reference/as_hybrid_svydesign.md),
[`compute_angler_effort()`](https://chrischizinski.com/tidycreel/reference/compute_angler_effort.md),
[`compute_effort()`](https://chrischizinski.com/tidycreel/reference/compute_effort.md),
[`creel_design()`](https://chrischizinski.com/tidycreel/reference/creel_design.md),
[`creel_schema()`](https://chrischizinski.com/tidycreel/reference/creel_schema.md),
[`creel_vocabulary()`](https://chrischizinski.com/tidycreel/reference/creel_vocabulary.md),
[`derive_angler_count()`](https://chrischizinski.com/tidycreel/reference/derive_angler_count.md),
[`est_effort_camera()`](https://chrischizinski.com/tidycreel/reference/est_effort_camera.md),
[`impute_camera_counts()`](https://chrischizinski.com/tidycreel/reference/impute_camera_counts.md),
[`mean_party_size()`](https://chrischizinski.com/tidycreel/reference/mean_party_size.md),
[`prep_counts_boat_party()`](https://chrischizinski.com/tidycreel/reference/prep_counts_boat_party.md),
[`prep_interview_catch()`](https://chrischizinski.com/tidycreel/reference/prep_interview_catch.md),
[`prep_interviews_trips()`](https://chrischizinski.com/tidycreel/reference/prep_interviews_trips.md),
[`validate_creel_schema()`](https://chrischizinski.com/tidycreel/reference/validate_creel_schema.md)

## Examples

``` r
raw_counts <- data.frame(
  sample_date  = as.Date(c("2024-06-01", "2024-06-02", "2024-06-08", "2024-06-09")),
  day_type     = c("weekday", "weekday", "weekend", "weekend"),
  effort_kind  = c("bank", "bank", "bank", "bank"),
  effort_value = c(15, 23, 45, 52)
)
prep_counts_daily_effort(raw_counts, date = sample_date, strata = day_type,
                         effort_type = effort_kind, daily_effort = effort_value)
#> # A tibble: 4 × 6
#>   date       day_type effort_type daily_effort psu        correction_factor
#>   <date>     <chr>    <chr>              <dbl> <date>                 <dbl>
#> 1 2024-06-01 weekday  bank                  15 2024-06-01                 1
#> 2 2024-06-02 weekday  bank                  23 2024-06-02                 1
#> 3 2024-06-08 weekend  bank                  45 2024-06-08                 1
#> 4 2024-06-09 weekend  bank                  52 2024-06-09                 1
```
