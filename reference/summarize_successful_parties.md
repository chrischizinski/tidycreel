# Tabulate successful parties by angler type and species sought

A party is "successful" when its total catch of the species it was
seeking (`species_sought`) is greater than zero. That total follows the
model
[`add_catch`](https://chrischizinski.github.io/tidycreel/reference/add_catch.md)
documents: the pair's `"caught"` row when it has one, and otherwise
`harvested + released`, because a `"caught"` row is optional. Returns
counts of successful and total parties for each angler type x species
sought combination.

## Usage

``` r
summarize_successful_parties(design)
```

## Arguments

- design:

  A `creel_design` object with interviews attached (including
  `angler_type` and `species_sought` columns) and catch data attached
  via
  [`add_catch`](https://chrischizinski.github.io/tidycreel/reference/add_catch.md).

## Value

A `data.frame` with class
`c("creel_summary_successful_parties", "data.frame")` and columns:
`angler_type`, `species_sought`, `N_successful` (integer, `NA` where
success is not determinable), `N_total` (integer), `percent` (numeric, 1
decimal, `NA` likewise).

## Details

A pair that records its own `"caught"` row keeps it even when that row
is zero — a recorded catch of none is data, not an absence, and does not
fall back to the dispositions.

**Interview-based summary, not pressure-weighted.** This function
tabulates raw interview records without applying survey weighting by
sampling effort or effort stratum. For pressure-weighted extrapolated
estimates, use
[`estimate_catch_rate`](https://chrischizinski.github.io/tidycreel/reference/estimate_catch_rate.md)
or
[`estimate_harvest_rate`](https://chrischizinski.github.io/tidycreel/reference/estimate_harvest_rate.md).

## Unrecorded grouping values

An interview whose `angler_type` or `species_sought` was not recorded is
reported under `"Unknown"`, sorted last, rather than dropped, so
`sum(N_total)` always equals the number of interviews attached to the
design.

The two are not equivalent. A party is successful when it caught some of
the species it *sought*, so where the sought species is unrecorded there
is nothing to compare the catch against and success is **not
determinable**: those rows report `NA` for `N_successful` and `percent`,
never `0`, which would assert that the parties failed. An unrecorded
*angler type* leaves success perfectly determinable – only the reporting
group is unknown – so those rows carry real counts. So does a sought
species genuinely *recorded* as `"Unknown"`: that is a real answer, not
a missing one, and it keeps its own counts.

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
[`summarize_by_zip()`](https://chrischizinski.github.io/tidycreel/reference/summarize_by_zip.md),
[`summarize_cws_rates()`](https://chrischizinski.github.io/tidycreel/reference/summarize_cws_rates.md),
[`summarize_hws_rates()`](https://chrischizinski.github.io/tidycreel/reference/summarize_hws_rates.md),
[`summarize_length_freq()`](https://chrischizinski.github.io/tidycreel/reference/summarize_length_freq.md),
[`summarize_refusals()`](https://chrischizinski.github.io/tidycreel/reference/summarize_refusals.md),
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
data(example_calendar)
data(example_interviews)
data(example_catch)
d <- creel_design(example_calendar, date = date, strata = day_type)
d <- add_interviews(d, example_interviews,
  catch = catch_total, effort = hours_fished, harvest = catch_kept,
  trip_status = trip_status, angler_type = angler_type,
  species_sought = species_sought
)
#> Warning: ! No `n_anglers` provided — assuming 1 angler per interview.
#> ℹ Pass `n_anglers = <column>` to use actual party sizes for angler-hour
#>   normalization.
#> ℹ If the interviews really are one angler each, pass `n_anglers = 1` to state
#>   that and silence this warning.
#> ℹ Added 22 interviews: 17 complete (77%), 5 incomplete (23%)
d <- add_catch(d, example_catch,
  catch_uid = interview_id, interview_uid = interview_id,
  species = species, count = count, catch_type = catch_type
)
summarize_successful_parties(d)
#>   angler_type species_sought N_total N_successful percent
#> 1        bank           bass       5            1    20.0
#> 2        bank        panfish       3            1    33.3
#> 3        bank        walleye       5            4    80.0
#> 4        boat           bass       1            1   100.0
#> 5        boat        panfish       2            0     0.0
#> 6        boat        walleye       6            3    50.0
```
