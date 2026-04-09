# Attach count time windows to a daily sampling schedule

Cross-joins a daily schedule produced by
[`generate_schedule()`](https://chrischizinski.github.io/tidycreel/reference/generate_schedule.md)
with a count-time template produced by
[`generate_count_times()`](https://chrischizinski.github.io/tidycreel/reference/generate_count_times.md),
returning a `creel_schedule` with one row per (date x period x
count_window).

## Usage

``` r
attach_count_times(schedule, count_times)
```

## Arguments

- schedule:

  A `creel_schedule` from
  [`generate_schedule()`](https://chrischizinski.github.io/tidycreel/reference/generate_schedule.md).
  Must have a `date` column.

- count_times:

  A `creel_schedule` from
  [`generate_count_times()`](https://chrischizinski.github.io/tidycreel/reference/generate_count_times.md).
  Must have `start_time`, `end_time`, and `window_id` columns.

## Value

A `creel_schedule` data frame with all columns from `schedule` plus
`start_time`, `end_time`, and `window_id` from `count_times`. Row count
equals `nrow(schedule) * nrow(count_times)`.

## Examples

``` r
sched <- generate_schedule(
  start_date = "2024-06-01", end_date = "2024-06-07",
  n_periods = 2, sampling_rate = 0.5, seed = 1
)
ct <- generate_count_times(
  start_time = "06:00", end_time = "14:00",
  strategy = "systematic", n_windows = 3,
  window_size = 30, min_gap = 10, seed = 1
)
attach_count_times(sched, ct)
#> # A creel_schedule: 18 rows x 6 cols (3 days, 2 periods)
#> June 2024
#> | Sun      | Mon      | Tue      | Wed      | Thu      | Fri      | Sat      |
#> |----------|----------|----------|----------|----------|----------|----------|
#> |          |          |          |          |          |          | WEEKE    |
#> | 02       | 03       | 04       | WEEKD    | WEEKD    | 07       | 08       |
#> | 09       | 10       | 11       | 12       | 13       | 14       | 15       |
#> | 16       | 17       | 18       | 19       | 20       | 21       | 22       |
#> | 23       | 24       | 25       | 26       | 27       | 28       | 29       |
#> | 30       |          |          |          |          |          |          |
```
