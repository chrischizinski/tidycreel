# Tabulate refused vs accepted interviews by month

Counts the number of refused and accepted interviews in each calendar
month. Refusals are recorded as `TRUE` in the refused column set via
[`add_interviews`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md).

## Usage

``` r
summarize_refusals(design)
```

## Arguments

- design:

  A `creel_design` object with interviews attached and `refused` column
  set via `add_interviews(refused = ...)`.

## Value

A `data.frame` with class `c("creel_summary_refusals", "data.frame")`
and columns: `month` (full month name), `participation` ("accepted" or
"refused"), `N` (integer count), `percent` (numeric, rounded to 1
decimal, percent within month).

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
  trip_status = trip_status, refused = refused
)
#> ℹ No `n_anglers` provided — assuming 1 angler per interview.
#> ℹ Pass `n_anglers = <column>` to use actual party sizes for angler-hour
#>   normalization.
#> ℹ Added 22 interviews: 17 complete (77%), 5 incomplete (23%)
summarize_refusals(d)
#>   month participation  N percent
#> 1  June      accepted 22     100
```
