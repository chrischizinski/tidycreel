# Tabulate interviews by county of origin

Maps angler zip codes to a county and state, then counts and computes
the percent of interviews by county. NA or unmappable zip codes appear
as an explicit "Unknown" row.

## Usage

``` r
summarize_by_county(design, zip_col = "zip_code", lookup = NULL)
```

## Arguments

- design:

  A `creel_design` object with interviews attached via
  [`add_interviews`](https://chrischizinski.com/tidycreel/dev/reference/add_interviews.md).

- zip_col:

  Name of the interview column holding the angler zip code. Defaults to
  `"zip_code"`. Text or whole numbers; a number is read as a 5-digit
  code, so `2134` is `"02134"`.

- lookup:

  The zip-to-county table. `NULL` (the default) uses
  [`zip_county`](https://chrischizinski.com/tidycreel/dev/reference/zip_county.md),
  built from the Census Bureau's 2020 ZCTA-county relationship file.
  Otherwise a data frame with columns `zip`, `county` and `state`, one
  row per zip and no missing values, such as a USPS-based crosswalk or
  one that assigns PO-box zips your anglers use.

## Value

A `data.frame` with class `c("creel_summary_county", "data.frame")` and
columns: `county` (character), `state` (character), `n` (integer), `pct`
(numeric, 1 decimal). Counties are kept apart by state, so Washington
County, MN and Washington County, NE are two rows. NA or unmappable zip
codes appear as county `"Unknown"` with state `NA`.

## Details

Interview-based summary, not pressure-weighted. No state filter is
applied; out-of-state anglers receive their actual county and state.
Sort order: "Unknown" last; remaining rows sorted by `n` descending.

The default lookup has one county per ZIP Code Tabulation Area (ZCTA). A
ZCTA that crosses a county line goes to the county holding most of its
land area, which need not be where most of its people live; see
[`zip_county`](https://chrischizinski.com/tidycreel/dev/reference/zip_county.md).
ZCTAs are not USPS ZIP codes: PO-box-only and single-organisation ZIPs
have no ZCTA and are reported as "Unknown", with a message giving how
many interviews that affected. Pass `lookup` to map them.

## See also

Other "Reporting & Diagnostics":
[`adjust_nonresponse()`](https://chrischizinski.com/tidycreel/dev/reference/adjust_nonresponse.md),
[`as_tibble.creel_estimates()`](https://chrischizinski.com/tidycreel/dev/reference/as_tibble.creel_estimates.md),
[`check_completeness()`](https://chrischizinski.com/tidycreel/dev/reference/check_completeness.md),
[`check_interview_coverage()`](https://chrischizinski.com/tidycreel/dev/reference/check_interview_coverage.md),
[`compare_variance()`](https://chrischizinski.com/tidycreel/dev/reference/compare_variance.md),
[`flag_outliers()`](https://chrischizinski.com/tidycreel/dev/reference/flag_outliers.md),
[`season_summary()`](https://chrischizinski.com/tidycreel/dev/reference/season_summary.md),
[`standardize_species()`](https://chrischizinski.com/tidycreel/dev/reference/standardize_species.md),
[`summarize_boat_composition()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_boat_composition.md),
[`summarize_by_angler_type()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_by_angler_type.md),
[`summarize_by_day_type()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_by_day_type.md),
[`summarize_by_method()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_by_method.md),
[`summarize_by_species_sought()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_by_species_sought.md),
[`summarize_by_trip_length()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_by_trip_length.md),
[`summarize_by_zip()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_by_zip.md),
[`summarize_cws_rates()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_cws_rates.md),
[`summarize_hws_rates()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_hws_rates.md),
[`summarize_length_freq()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_length_freq.md),
[`summarize_refusals()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_refusals.md),
[`summarize_rws_rates()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_rws_rates.md),
[`summarize_successful_parties()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_successful_parties.md),
[`summarize_trips()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_trips.md),
[`summary.creel_estimates()`](https://chrischizinski.com/tidycreel/dev/reference/summary.creel_estimates.md),
[`tidy.creel_estimates()`](https://chrischizinski.com/tidycreel/dev/reference/tidy.creel_estimates.md),
[`validate_creel_data()`](https://chrischizinski.com/tidycreel/dev/reference/validate_creel_data.md),
[`validate_design()`](https://chrischizinski.com/tidycreel/dev/reference/validate_design.md),
[`validate_incomplete_trips()`](https://chrischizinski.com/tidycreel/dev/reference/validate_incomplete_trips.md),
[`validation_report()`](https://chrischizinski.com/tidycreel/dev/reference/validation_report.md),
[`write_estimates()`](https://chrischizinski.com/tidycreel/dev/reference/write_estimates.md)

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
#>             county state  n  pct
#> 1 Lancaster County    NE 15 68.2
#> 2          Unknown  <NA>  7 31.8

# Your own crosswalk, for example one that places a PO-box zip
my_lookup <- data.frame(
  zip = c("68502", "68508"),
  county = c("Lancaster County", "Lancaster County"),
  state = "NE"
)
summarize_by_county(design, lookup = my_lookup)
#>             county state  n  pct
#> 1 Lancaster County    NE 15 68.2
#> 2          Unknown  <NA>  7 31.8
```
