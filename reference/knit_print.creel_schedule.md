# Render a creel_schedule as a pandoc pipe-table in R Markdown / Quarto

Called automatically by knitr when a `creel_schedule` object is the last
expression in a code chunk. Produces one `### Month YYYY` heading and
one pandoc pipe-table per calendar month. Bus-route schedule cells use
HTML `<br>` to separate the day-type abbreviation from the circuit
assignment.

## Usage

``` r
knit_print.creel_schedule(x, ...)
```

## Arguments

- x:

  A `creel_schedule` object.

- ...:

  Additional arguments (currently unused).

## Value

A
[`knitr::asis_output()`](https://rdrr.io/pkg/knitr/man/asis_output.html)
object containing raw markdown.

## Examples

``` r
sched <- generate_schedule(
  start_date = "2024-06-01",
  end_date = "2024-07-31",
  n_periods = 1,
  sampling_rate = c(weekday = 0.3, weekend = 0.6),
  seed = 42
)
# In an R Markdown chunk, just print the object:
sched
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
