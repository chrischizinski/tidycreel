# Print a creel_schedule as a monthly calendar grid

Prints a formatted ASCII monthly calendar to the console. Sampled dates
show day-type abbreviations; bus-route schedules additionally show
circuit assignments.

## Usage

``` r
# S3 method for class 'creel_schedule'
print(x, ...)
```

## Arguments

- x:

  A `creel_schedule` object.

- ...:

  Additional arguments passed to
  [`format.creel_schedule()`](https://chrischizinski.github.io/tidycreel/reference/format.creel_schedule.md).

## Value

Invisibly returns `x`.

## Examples

``` r
sched <- generate_schedule(
  start_date = "2024-06-01",
  end_date = "2024-07-31",
  n_periods = 1,
  sampling_rate = c(weekday = 0.3, weekend = 0.6),
  seed = 42
)
print(sched)
#> # A creel_schedule: 24 rows x 3 cols (24 days, 1 periods)
#> June 2024
#> | Sun      | Mon      | Tue      | Wed      | Thu      | Fri      | Sat      |
#> |----------|----------|----------|----------|----------|----------|----------|
#> |          |          |          |          |          |          | WEEKE    |
#> | WEEKE    | 03       | WEEKD    | WEEKD    | 06       | WEEKD    | 08       |
#> | WEEKE    | 10       | 11       | 12       | 13       | 14       | WEEKE    |
#> | 16       | 17       | 18       | 19       | 20       | 21       | WEEKE    |
#> | WEEKE    | 24       | 25       | 26       | 27       | WEEKD    | WEEKE    |
#> | WEEKE    |          |          |          |          |          |          |
#> 
#> July 2024
#> | Sun      | Mon      | Tue      | Wed      | Thu      | Fri      | Sat      |
#> |----------|----------|----------|----------|----------|----------|----------|
#> |          | 01       | 02       | 03       | 04       | WEEKD    | 06       |
#> | 07       | WEEKD    | WEEKD    | WEEKD    | 11       | 12       | 13       |
#> | WEEKE    | WEEKD    | 16       | 17       | 18       | 19       | 20       |
#> | WEEKE    | WEEKD    | WEEKD    | 24       | 25       | WEEKD    | WEEKE    |
#> | 28       | 29       | WEEKD    | 31       |          |          |          |
```
