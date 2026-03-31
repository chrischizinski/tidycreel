# Summarize trip metadata for interview data

Provides a diagnostic summary of trip completion status and duration
statistics for interview data attached to a creel design. Useful for
inspecting data quality before estimation.

## Usage

``` r
summarize_trips(design)
```

## Arguments

- design:

  A creel_design object with interviews attached via
  [`add_interviews()`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md).

## Value

A list (class "creel_trip_summary") with components:

- n_total:

  Total number of interviews

- n_complete:

  Number of complete trip interviews

- n_incomplete:

  Number of incomplete trip interviews

- pct_complete:

  Percentage of complete trips

- pct_incomplete:

  Percentage of incomplete trips

- duration_stats:

  Data frame with duration statistics by trip status

## Examples

``` r
data(example_calendar)
data(example_interviews)

design <- creel_design(example_calendar, date = date, strata = day_type)
design <- add_interviews(design, example_interviews,
  catch = catch_total,
  effort = hours_fished,
  harvest = catch_kept,
  trip_status = trip_status,
  trip_duration = trip_duration
)
#> ℹ No `n_anglers` provided — assuming 1 angler per interview.
#> ℹ Pass `n_anglers = <column>` to use actual party sizes for angler-hour
#>   normalization.
#> ℹ Added 22 interviews: 17 complete (77%), 5 incomplete (23%)
summary <- summarize_trips(design)
print(summary)
#> Trip Status Summary
#> 
#> Total interviews: 22
#>   Complete:   17 (77.3%)
#>   Incomplete: 5 (22.7%)
#> 
#> Duration (hours) by status:
#>   complete: min=1, median=2.5, mean=2.68, max=4
#>   incomplete: min=0.5, median=1, mean=1.05, max=1.5
```
