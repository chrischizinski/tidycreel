# Tabulate interviews by zip code of origin

Counts and computes the percent of interviews by angler zip code of
origin. NA zip codes appear as an explicit "Unknown" row. Percent
denominator is total interviews including NA rows.

## Usage

``` r
summarize_by_zip(design)
```

## Arguments

- design:

  A `creel_design` object with interviews attached via
  [`add_interviews`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md).
  Interviews must include the `ii_ZipCode` field.

## Value

A `data.frame` with class `c("creel_summary_zip", "data.frame")` and
columns: `zip_code` (character), `n` (integer), `pct` (numeric, 1
decimal). NA zip codes appear as `"Unknown"`. Percent denominator is
total interviews including NA.

## Details

Interview-based summary, not pressure-weighted. NA zip codes appear as
an explicit "Unknown" row for data quality visibility. Sort order:
"Unknown" last; remaining rows sorted by `n` descending.

## See also

Other "Reporting & Diagnostics":
[`adjust_nonresponse()`](https://chrischizinski.github.io/tidycreel/reference/adjust_nonresponse.md),
[`check_completeness()`](https://chrischizinski.github.io/tidycreel/reference/check_completeness.md),
[`compare_variance()`](https://chrischizinski.github.io/tidycreel/reference/compare_variance.md),
[`flag_outliers()`](https://chrischizinski.github.io/tidycreel/reference/flag_outliers.md),
[`season_summary()`](https://chrischizinski.github.io/tidycreel/reference/season_summary.md),
[`standardize_species()`](https://chrischizinski.github.io/tidycreel/reference/standardize_species.md),
[`summarize_boat_composition()`](https://chrischizinski.github.io/tidycreel/reference/summarize_boat_composition.md),
[`summarize_by_angler_type()`](https://chrischizinski.github.io/tidycreel/reference/summarize_by_angler_type.md),
[`summarize_by_county()`](https://chrischizinski.github.io/tidycreel/reference/summarize_by_county.md),
[`summarize_by_day_type()`](https://chrischizinski.github.io/tidycreel/reference/summarize_by_day_type.md),
[`summarize_by_method()`](https://chrischizinski.github.io/tidycreel/reference/summarize_by_method.md),
[`summarize_by_species_sought()`](https://chrischizinski.github.io/tidycreel/reference/summarize_by_species_sought.md),
[`summarize_by_trip_length()`](https://chrischizinski.github.io/tidycreel/reference/summarize_by_trip_length.md),
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
data(example_calendar, package = "tidycreel")
data(example_interviews, package = "tidycreel")
example_interviews$ii_ZipCode <- rep_len(
  c("68502", "68502", NA, "68508", NA),
  nrow(example_interviews)
)
d <- suppressWarnings(
  creel_design(example_calendar, date = date, strata = day_type)
)
d <- suppressWarnings(
  add_interviews(d, example_interviews,
    catch = catch_total, effort = hours_fished, harvest = catch_kept,
    trip_status = trip_status, trip_duration = trip_duration,
    angler_type = angler_type, angler_method = angler_method,
    species_sought = species_sought, n_anglers = n_anglers, refused = refused
  )
)
#> ℹ Added 22 interviews: 17 complete (77%), 5 incomplete (23%)
summarize_by_zip(d)
#>   zip_code  n  pct
#> 1    68502 10 45.5
#> 2    68508  4 18.2
#> 3  Unknown  8 36.4
```
