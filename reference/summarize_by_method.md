# Tabulate interviews by fishing method and month

Counts the number of interviews for each fishing method within each
calendar month. Method is taken from the column set via
`add_interviews(angler_method = ...)`.

## Usage

``` r
summarize_by_method(design)
```

## Arguments

- design:

  A `creel_design` object with interviews attached and `angler_method`
  column set via `add_interviews(angler_method = ...)`.

## Value

A `data.frame` with class `c("creel_summary_method", "data.frame")` and
columns: `month`, `method`, `N`, `percent`.

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
  trip_status = trip_status, angler_method = angler_method
)
#> ℹ No `n_anglers` provided — assuming 1 angler per interview.
#> ℹ Pass `n_anglers = <column>` to use actual party sizes for angler-hour
#>   normalization.
#> ℹ Added 22 interviews: 17 complete (77%), 5 incomplete (23%)
summarize_by_method(d)
#>   month     method  N percent
#> 1  June artificial  7    31.8
#> 2  June       bait 10    45.5
#> 3  June        fly  5    22.7
```
