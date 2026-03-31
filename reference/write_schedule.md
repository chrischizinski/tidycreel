# Write a creel schedule to a CSV or xlsx file

Exports a `creel_schedule` object to disk. The default format is CSV
using base R (no extra dependencies). The `"xlsx"` format requires the
writexl package; an informative error is raised if it is not installed.

## Usage

``` r
write_schedule(schedule, path, format = c("csv", "xlsx"))
```

## Arguments

- schedule:

  A `creel_schedule` object (or plain data frame) to export.

- path:

  File path for the output file.

- format:

  One of `"csv"` (default) or `"xlsx"`. When `"csv"`, the file is
  written with
  [`utils::write.csv()`](https://rdrr.io/r/utils/write.table.html) (no
  row names). When `"xlsx"`,
  [`writexl::write_xlsx()`](https://docs.ropensci.org/writexl//reference/write_xlsx.html)
  is used behind an
  [`rlang::check_installed()`](https://rlang.r-lib.org/reference/is_installed.html)
  guard.

## Value

`path`, returned invisibly.

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
```
