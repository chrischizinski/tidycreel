# Read a schedule file into a validated creel_schedule object

Reads a CSV or xlsx schedule file produced by
[`write_schedule()`](https://chrischizinski.github.io/tidycreel/reference/write_schedule.md)
(or hand-built in Excel) and returns a validated `creel_schedule` object
ready for use with
[`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md).

## Usage

``` r
read_schedule(path)
```

## Arguments

- path:

  Path to a CSV (`.csv`) or xlsx (`.xlsx`, `.xls`) schedule file. For
  xlsx files the readxl package must be installed.

## Value

A `creel_schedule` object with columns:

- `date` (Date)

- `day_type` (character)

- `period_id` (integer, if present)

- `sampled` (logical, if present)

## Details

The format is detected from the file extension. All columns are read as
text first, then `coerce_schedule_columns()` applies type coercion – the
same logic runs regardless of format so that Excel-reformatted dates and
serial numbers are handled consistently.

## Examples

``` r
sched <- generate_schedule(
  "2024-06-01", "2024-08-31",
  n_periods = 2,
  sampling_rate = c(weekday = 0.3, weekend = 0.6),
  seed = 42
)
tmp <- tempfile(fileext = ".csv")
write_schedule(sched, tmp)
sched2 <- read_schedule(tmp)
inherits(sched2, "creel_schedule")
#> [1] TRUE
```
