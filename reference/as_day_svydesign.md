# Construct a day-level survey design for aerial estimation

Builds a
[`survey::svydesign`](https://rdrr.io/pkg/survey/man/svydesign.html)
over sampled days (PSUs) using calendar information. Weights per sampled
day are computed from target vs actual sample counts within strata
(target_sample / actual_sample).

## Usage

``` r
as_day_svydesign(
  calendar,
  day_id = "date",
  strata_vars = c("day_type", "month", "season", "weekend")
)
```

## Arguments

- calendar:

  Tibble/data.frame with day-level sampling plan, including `day_id`,
  `target_sample`, `actual_sample`, and strata variables.

- day_id:

  Column name identifying the day PSU (default `date`).

- strata_vars:

  Character vector of calendar columns defining strata (e.g.,
  `c("day_type","month")`). Missing columns are ignored with a warning.

## Value

A [`survey::svydesign`](https://rdrr.io/pkg/survey/man/svydesign.html)
object with one row per sampled day.

## Examples

``` r
cal <- tibble::tibble(
  date = as.Date(c("2025-08-20","2025-08-21")),
  day_type = c("weekday","weekday"),
  month = c("August","August"),
  target_sample = c(4,4),
  actual_sample = c(2,2)
)
svy_day <- as_day_svydesign(cal, day_id = "date", strata_vars = c("day_type","month"))
```
