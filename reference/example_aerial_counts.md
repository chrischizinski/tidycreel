# Example aerial angler count dataset

A dataset of instantaneous angler counts from aerial overflights of a
Nebraska reservoir, used to demonstrate aerial survey effort estimation.
Contains 16 rows representing one overflight per sampling day across an
8-week summer season (June-July 2024). Weekday and weekend counts vary
realistically to produce non-trivial between-day variance in the effort
estimate.

## Usage

``` r
example_aerial_counts
```

## Format

A data frame with 16 rows and 3 variables:

- date:

  Survey date (Date class), June-July 2024.

- day_type:

  Day type stratum: `"weekday"` or `"weekend"`.

- n_anglers:

  Instantaneous angler count from one aerial overflight (integer).
  Weekday counts range 15-40; weekend counts range 40-80.

## Source

Simulated for package documentation.

## See also

[example_aerial_interviews](https://chrischizinski.github.io/tidycreel/reference/example_aerial_interviews.md)
for matching interview data,
[`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md),
[`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md),
[`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md)

## Examples

``` r
data(example_aerial_counts)
head(example_aerial_counts)
#>         date day_type n_anglers
#> 1 2024-06-03  weekday        39
#> 2 2024-06-05  weekday        32
#> 3 2024-06-07  weekday        29
#> 4 2024-06-08  weekend        45
#> 5 2024-06-09  weekend        51
#> 6 2024-06-10  weekday        34

# Build a calendar from count dates and construct an aerial design
aerial_cal <- data.frame(
  date = example_aerial_counts$date,
  day_type = example_aerial_counts$day_type,
  stringsAsFactors = FALSE
)
design <- creel_design(
  aerial_cal,
  date = date,
  strata = day_type,
  survey_type = "aerial",
  h_open = 14
)
print(design)
#> 
#> ── Creel Survey Design ─────────────────────────────────────────────────────────
#> Type: "aerial"
#> Date column: date
#> Strata: day_type
#> Calendar: 16 days (2024-06-03 to 2024-07-06)
#> day_type: 2 levels
#> Counts: "none"
#> Interviews: "none"
#> Sections: "none"
#> 
#> ── Aerial Survey Design ──
#> 
#> Hours open (h_open): 14
```
