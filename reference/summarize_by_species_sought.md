# Tabulate interviews by species sought and month

Counts the number of interviews for each species sought within each
calendar month. Species sought is taken from the column set via
`add_interviews(species_sought = ...)`.

## Usage

``` r
summarize_by_species_sought(design)
```

## Arguments

- design:

  A `creel_design` object with interviews attached and `species_sought`
  column set via `add_interviews(species_sought = ...)`.

## Value

A `data.frame` with class
`c("creel_summary_species_sought", "data.frame")` and columns: `month`,
`species`, `N`, `percent`.

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
d <- creel_design(example_calendar, date = date, strata = day_type)
d <- add_interviews(d, example_interviews,
  catch = catch_total, effort = hours_fished, harvest = catch_kept,
  trip_status = trip_status, species_sought = species_sought
)
#> ℹ No `n_anglers` provided — assuming 1 angler per interview.
#> ℹ Pass `n_anglers = <column>` to use actual party sizes for angler-hour
#>   normalization.
#> ℹ Added 22 interviews: 17 complete (77%), 5 incomplete (23%)
summarize_by_species_sought(d)
#>   month species  N percent
#> 1  June    bass  6    27.3
#> 2  June panfish  5    22.7
#> 3  June walleye 11    50.0
```
