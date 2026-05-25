# Tabulate boat composition by month and day type

Computes the percentage of boats that are angler boats from raw count
data, grouped by calendar month and day type. Formula:
`mean(c_AnglerBoats / (c_AnglerBoats + c_NonAngBoats))` per group.

## Usage

``` r
summarize_boat_composition(design, schema)
```

## Arguments

- design:

  A `creel_design` object with counts attached via
  [`add_counts`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md).

- schema:

  A `creel_schema` object with `angler_boats_col` and
  `non_ang_boats_col` set.

## Value

A `data.frame` with class
`c("creel_summary_boat_composition", "data.frame")` and columns: `month`
(full month name), `day_type`, `n_events` (integer), `pct_angler_boats`
(numeric, 1 decimal).

## Details

Count-based summary, not interview-weighted. Rows where
`angler_boats + non_ang_boats == 0` are excluded from ratio computation.

## See also

Other "Reporting & Diagnostics":
[`adjust_nonresponse()`](https://chrischizinski.github.io/tidycreel/reference/adjust_nonresponse.md),
[`check_completeness()`](https://chrischizinski.github.io/tidycreel/reference/check_completeness.md),
[`compare_variance()`](https://chrischizinski.github.io/tidycreel/reference/compare_variance.md),
[`flag_outliers()`](https://chrischizinski.github.io/tidycreel/reference/flag_outliers.md),
[`season_summary()`](https://chrischizinski.github.io/tidycreel/reference/season_summary.md),
[`standardize_species()`](https://chrischizinski.github.io/tidycreel/reference/standardize_species.md),
[`summarize_by_angler_type()`](https://chrischizinski.github.io/tidycreel/reference/summarize_by_angler_type.md),
[`summarize_by_county()`](https://chrischizinski.github.io/tidycreel/reference/summarize_by_county.md),
[`summarize_by_day_type()`](https://chrischizinski.github.io/tidycreel/reference/summarize_by_day_type.md),
[`summarize_by_method()`](https://chrischizinski.github.io/tidycreel/reference/summarize_by_method.md),
[`summarize_by_species_sought()`](https://chrischizinski.github.io/tidycreel/reference/summarize_by_species_sought.md),
[`summarize_by_trip_length()`](https://chrischizinski.github.io/tidycreel/reference/summarize_by_trip_length.md),
[`summarize_by_zip()`](https://chrischizinski.github.io/tidycreel/reference/summarize_by_zip.md),
[`summarize_cws_rates()`](https://chrischizinski.github.io/tidycreel/reference/summarize_cws_rates.md),
[`summarize_hws_rates()`](https://chrischizinski.github.io/tidycreel/reference/summarize_hws_rates.md),
[`summarize_length_freq()`](https://chrischizinski.github.io/tidycreel/reference/summarize_length_freq.md),
[`summarize_refusals()`](https://chrischizinski.github.io/tidycreel/reference/summarize_refusals.md),
[`summarize_successful_parties()`](https://chrischizinski.github.io/tidycreel/reference/summarize_successful_parties.md),
[`summarize_trips()`](https://chrischizinski.github.io/tidycreel/reference/summarize_trips.md),
[`summary.creel_estimates()`](https://chrischizinski.github.io/tidycreel/reference/summary.creel_estimates.md),
[`tidy.creel_estimates()`](https://chrischizinski.github.io/tidycreel/reference/tidy.creel_estimates.md),
[`validate_creel_data()`](https://chrischizinski.github.io/tidycreel/reference/validate_creel_data.md),
[`validate_design()`](https://chrischizinski.github.io/tidycreel/reference/validate_design.md),
[`validate_incomplete_trips()`](https://chrischizinski.github.io/tidycreel/reference/validate_incomplete_trips.md),
[`validation_report()`](https://chrischizinski.github.io/tidycreel/reference/validation_report.md),
[`write_estimates()`](https://chrischizinski.github.io/tidycreel/reference/write_estimates.md)

## Examples

``` r
counts_df <- data.frame(
  date         = as.Date(c("2024-05-01", "2024-05-04",
                           "2024-06-01", "2024-06-08")),
  day_type     = c("weekday", "weekend", "weekday", "weekend"),
  angler_boats = c(3L, 2L, 4L, 1L),
  non_ang_boats = c(1L, 2L, 1L, 3L),
  count        = c(10L, 12L, 9L, 8L)
)
cal <- data.frame(
  date     = counts_df$date,
  day_type = counts_df$day_type
)
d <- suppressWarnings(
  creel_design(cal, date = date, strata = day_type)
)
d <- suppressWarnings(
  add_counts(d, counts_df)
)
s <- creel_schema(
  survey_type    = "instantaneous",
  angler_boats_col  = "angler_boats",
  non_ang_boats_col = "non_ang_boats"
)
summarize_boat_composition(d, s)
#>   month day_type n_events pct_angler_boats
#> 1   May  weekday        1               75
#> 2   May  weekend        1               50
#> 3  June  weekday        1               80
#> 4  June  weekend        1               25
```
