# Tabulate interviews by trip length bin

Bins trip durations (in hours) into 1-hour intervals from 0 to 10 hours,
with a final bin for trips 10+ hours. Returns counts and percentages for
each bin.

## Usage

``` r
summarize_by_trip_length(design)
```

## Arguments

- design:

  A `creel_design` object with interviews attached and `trip_duration`
  column set via `add_interviews(trip_duration = ...)`.

## Value

A `data.frame` with class `c("creel_summary_trip_length", "data.frame")`
and columns: `trip_length_bin` (ordered factor), `N` (integer),
`percent` (numeric, 1 decimal). Bins: "\[0,1)", "\[1,2)", ...,
"\[9,10)", "10+".

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
  trip_status = trip_status, trip_duration = trip_duration
)
#> ℹ No `n_anglers` provided — assuming 1 angler per interview.
#> ℹ Pass `n_anglers = <column>` to use actual party sizes for angler-hour
#>   normalization.
#> ℹ Added 22 interviews: 17 complete (77%), 5 incomplete (23%)
summarize_by_trip_length(d)
#>    trip_length_bin N percent
#> 1            [0,1) 2     9.1
#> 2            [1,2) 5    22.7
#> 3            [2,3) 8    36.4
#> 4            [3,4) 4    18.2
#> 5            [4,5) 3    13.6
#> 6            [5,6) 0     0.0
#> 7            [6,7) 0     0.0
#> 8            [7,8) 0     0.0
#> 9            [8,9) 0     0.0
#> 10          [9,10) 0     0.0
#> 11             10+ 0     0.0
```
