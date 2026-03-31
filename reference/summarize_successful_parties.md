# Tabulate successful parties by angler type and species sought

A party is "successful" if any row in the attached catch data has
`catch_type == "caught"` and `count > 0` for the species the party was
seeking (`species_sought`). Returns counts of successful and total
parties for each angler type x species sought combination.

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
`angler_type`, `species_sought`, `N_successful` (integer), `N_total`
(integer), `percent` (numeric, 1 decimal).

## Details

**Interview-based summary, not pressure-weighted.** This function
tabulates raw interview records without applying survey weighting by
sampling effort or effort stratum. For pressure-weighted extrapolated
estimates, use
[`estimate_catch_rate`](https://chrischizinski.github.io/tidycreel/reference/estimate_catch_rate.md)
or
[`estimate_harvest_rate`](https://chrischizinski.github.io/tidycreel/reference/estimate_harvest_rate.md).

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
#> ℹ No `n_anglers` provided — assuming 1 angler per interview.
#> ℹ Pass `n_anglers = <column>` to use actual party sizes for angler-hour
#>   normalization.
#> ℹ Added 22 interviews: 17 complete (77%), 5 incomplete (23%)
d <- add_catch(d, example_catch,
  catch_uid = interview_id, interview_uid = interview_id,
  species = species, count = count, catch_type = catch_type
)
summarize_successful_parties(d)
#>   angler_type species_sought N_total N_successful percent
#> 1        bank           bass       5            0     0.0
#> 2        bank        panfish       3            1    33.3
#> 3        bank        walleye       5            3    60.0
#> 4        boat           bass       1            1   100.0
#> 5        boat        panfish       2            0     0.0
#> 6        boat        walleye       6            1    16.7
```
