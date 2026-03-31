# Tabulate interviews by angler type and month

Counts the number of interviews for each angler type within each
calendar month. Angler type is taken from the column set via
`add_interviews(angler_type = ...)`.

## Usage

``` r
summarize_by_angler_type(design)
```

## Arguments

- design:

  A `creel_design` object with interviews attached and `angler_type`
  column set via `add_interviews(angler_type = ...)`.

## Value

A `data.frame` with class `c("creel_summary_angler_type", "data.frame")`
and columns: `month`, `angler_type`, `N`, `percent`.

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
  trip_status = trip_status, angler_type = angler_type
)
#> ℹ No `n_anglers` provided — assuming 1 angler per interview.
#> ℹ Pass `n_anglers = <column>` to use actual party sizes for angler-hour
#>   normalization.
#> ℹ Added 22 interviews: 17 complete (77%), 5 incomplete (23%)
summarize_by_angler_type(d)
#>   month angler_type  N percent
#> 1  June        bank 13    59.1
#> 2  June        boat  9    40.9
```
