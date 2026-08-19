# Tabulate interviews by county of origin

Maps angler zip codes to county using the zipcodeR package, then counts
and computes the percent of interviews by county. NA or unmappable zip
codes appear as an explicit "Unknown" row.

## Usage

``` r
summarize_by_county(design)
```

## Arguments

- design:

  A `creel_design` object with interviews attached via
  [`add_interviews`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md).
  Interviews must include the `ii_ZipCode` field.

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
[`adjust_nonresponse()`](https://chrischizinski.github.io/tidycreel/reference/adjust_nonresponse.md),
[`check_completeness()`](https://chrischizinski.github.io/tidycreel/reference/check_completeness.md),
[`compare_variance()`](https://chrischizinski.github.io/tidycreel/reference/compare_variance.md),
[`flag_outliers()`](https://chrischizinski.github.io/tidycreel/reference/flag_outliers.md),
[`season_summary()`](https://chrischizinski.github.io/tidycreel/reference/season_summary.md),
[`standardize_species()`](https://chrischizinski.github.io/tidycreel/reference/standardize_species.md),
[`summarize_boat_composition()`](https://chrischizinski.github.io/tidycreel/reference/summarize_boat_composition.md),
[`summarize_by_angler_type()`](https://chrischizinski.github.io/tidycreel/reference/summarize_by_angler_type.md),
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
if (FALSE) { # \dontrun{
# Requires zipcodeR — install with: install.packages("zipcodeR")
interviews_df <- data.frame(
  ii_InterviewNumber = 1:5,
  ii_ZipCode         = c("68502", "68502", NA, "68508", NA),
  stringsAsFactors   = FALSE
)
cal <- data.frame(
  date     = as.Date(c("2024-05-01", "2024-05-02")),
  day_type = c("weekday", "weekend")
)
d <- suppressWarnings(
  creel_design(cal, date = date, strata = day_type)
)
d <- suppressWarnings(
  add_interviews(d, interviews_df)
)
summarize_by_county(d)
} # }
```
