# Tabulate interviews by county of origin

Maps angler zip codes to county using the zipcodeR package, then counts
and computes the percent of interviews by county. NA or unmappable zip
codes appear as an explicit "Unknown" row.

## Usage

``` r
summarize_by_county(design, zip_col = "zip_code")
```

## Arguments

- design:

  A `creel_design` object with interviews attached via
  [`add_interviews`](https://chrischizinski.com/tidycreel/reference/add_interviews.md).

- zip_col:

  Name of the interview column holding the angler zip code. Defaults to
  `"zip_code"`.

## Value

A `data.frame` with class `c("creel_summary_county", "data.frame")` and
columns: `county` (character), `n` (integer), `pct` (numeric, 1
decimal). NA or unmappable zip codes appear as `"Unknown"`.

## Details

Interview-based summary, not pressure-weighted. Requires the zipcodeR
package (listed in `Suggests`). No state filter is applied; out-of-state
anglers receive their actual county name. NA or unmappable zip codes
appear as "Unknown" for data quality visibility. Sort order: "Unknown"
last; remaining rows sorted by `n` descending.

## See also

Other "Reporting & Diagnostics":
[`adjust_nonresponse()`](https://chrischizinski.com/tidycreel/reference/adjust_nonresponse.md),
[`check_completeness()`](https://chrischizinski.com/tidycreel/reference/check_completeness.md),
[`compare_variance()`](https://chrischizinski.com/tidycreel/reference/compare_variance.md),
[`flag_outliers()`](https://chrischizinski.com/tidycreel/reference/flag_outliers.md),
[`season_summary()`](https://chrischizinski.com/tidycreel/reference/season_summary.md),
[`standardize_species()`](https://chrischizinski.com/tidycreel/reference/standardize_species.md),
[`summarize_boat_composition()`](https://chrischizinski.com/tidycreel/reference/summarize_boat_composition.md),
[`summarize_by_angler_type()`](https://chrischizinski.com/tidycreel/reference/summarize_by_angler_type.md),
[`summarize_by_day_type()`](https://chrischizinski.com/tidycreel/reference/summarize_by_day_type.md),
[`summarize_by_method()`](https://chrischizinski.com/tidycreel/reference/summarize_by_method.md),
[`summarize_by_species_sought()`](https://chrischizinski.com/tidycreel/reference/summarize_by_species_sought.md),
[`summarize_by_trip_length()`](https://chrischizinski.com/tidycreel/reference/summarize_by_trip_length.md),
[`summarize_by_zip()`](https://chrischizinski.com/tidycreel/reference/summarize_by_zip.md),
[`summarize_cws_rates()`](https://chrischizinski.com/tidycreel/reference/summarize_cws_rates.md),
[`summarize_hws_rates()`](https://chrischizinski.com/tidycreel/reference/summarize_hws_rates.md),
[`summarize_length_freq()`](https://chrischizinski.com/tidycreel/reference/summarize_length_freq.md),
[`summarize_refusals()`](https://chrischizinski.com/tidycreel/reference/summarize_refusals.md),
[`summarize_successful_parties()`](https://chrischizinski.com/tidycreel/reference/summarize_successful_parties.md),
[`summarize_trips()`](https://chrischizinski.com/tidycreel/reference/summarize_trips.md),
[`summary.creel_estimates()`](https://chrischizinski.com/tidycreel/reference/summary.creel_estimates.md),
[`tidy.creel_estimates()`](https://chrischizinski.com/tidycreel/reference/tidy.creel_estimates.md),
[`validate_creel_data()`](https://chrischizinski.com/tidycreel/reference/validate_creel_data.md),
[`validate_design()`](https://chrischizinski.com/tidycreel/reference/validate_design.md),
[`validate_incomplete_trips()`](https://chrischizinski.com/tidycreel/reference/validate_incomplete_trips.md),
[`validation_report()`](https://chrischizinski.com/tidycreel/reference/validation_report.md),
[`write_estimates()`](https://chrischizinski.com/tidycreel/reference/write_estimates.md)

## Examples

``` r
data(example_calendar)
data(example_interviews)

# The shipped interviews carry no zip code, so add one to demonstrate the
# mapping. Two NAs are left in on purpose: an unmappable zip is reported as
# "Unknown" rather than dropped.
interviews_zip <- example_interviews
interviews_zip$zip_code <- rep(
  c("68502", "68508", NA), length.out = nrow(interviews_zip)
)

design <- creel_design(example_calendar, date = date, strata = day_type)
design <- add_interviews(design, interviews_zip,
  catch = catch_total, effort = hours_fished, harvest = catch_kept,
  trip_status = trip_status
)
#> Warning: ! No `n_anglers` provided — assuming 1 angler per interview.
#> ℹ Pass `n_anglers = <column>` to use actual party sizes for angler-hour
#>   normalization.
#> ℹ If the interviews really are one angler each, pass `n_anglers = 1` to state
#>   that and silence this warning.
#> ℹ Added 22 interviews: 17 complete (77%), 5 incomplete (23%)

summarize_by_county(design)
#>             county  n  pct
#> 1 Lancaster County 15 68.2
#> 2          Unknown  7 31.8
```
