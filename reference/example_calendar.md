# Example calendar data for creel survey

A sample survey calendar dataset demonstrating the structure required
for
[`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md).
Contains 14 days (June 1-14, 2024) with weekday/weekend strata,
representing a two-week survey period.

## Usage

``` r
example_calendar
```

## Format

A data frame with 14 rows and 2 columns:

- date:

  Survey date (Date class), June 1-14, 2024

- day_type:

  Day type stratum: "weekday" or "weekend"

## Source

Simulated data for package examples

## See also

[example_counts](https://chrischizinski.github.io/tidycreel/reference/example_counts.md)
for matching count data,
[`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md)
to create a design from calendar data

## Examples

``` r
# Load and inspect
data(example_calendar)
head(example_calendar)
#>         date day_type
#> 1 2024-06-01  weekend
#> 2 2024-06-02  weekend
#> 3 2024-06-03  weekday
#> 4 2024-06-04  weekday
#> 5 2024-06-05  weekday
#> 6 2024-06-06  weekday

# Create a creel design
design <- creel_design(example_calendar, date = date, strata = day_type)
print(design)
#> 
#> ── Creel Survey Design ─────────────────────────────────────────────────────────
#> Type: "instantaneous"
#> Date column: date
#> Strata: day_type
#> Calendar: 14 days (2024-06-01 to 2024-06-14)
#> day_type: 2 levels
#> Counts: "none"
#> Interviews: "none"
#> Sections: "none"
```
