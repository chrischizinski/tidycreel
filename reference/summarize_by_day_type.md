# Tabulate interviews by day type and month

Counts the number of interviews in each day type stratum (e.g., weekday,
weekend) within each calendar month. Day type is taken from the first
strata column (`design$strata_cols[1]`), which is always present after
[`creel_design`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md)
is called.

## Usage

``` r
summarize_by_day_type(design)
```

## Arguments

- design:

  A `creel_design` object with interviews attached.

## Value

A `data.frame` with class `c("creel_summary_day_type", "data.frame")`
and columns: `month`, `day_type`, `N`, `percent`.

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
  trip_status = trip_status
)
#> ℹ No `n_anglers` provided — assuming 1 angler per interview.
#> ℹ Pass `n_anglers = <column>` to use actual party sizes for angler-hour
#>   normalization.
#> ℹ Added 22 interviews: 17 complete (77%), 5 incomplete (23%)
summarize_by_day_type(d)
#>   month day_type  N percent
#> 1  June  weekday 13    59.1
#> 2  June  weekend  9    40.9
```
