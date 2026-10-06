# Attach count time windows to a daily sampling schedule

Gives each sampled day (and each worked shift) its count windows. Two
ways:

## Usage

``` r
attach_count_times(
  schedule,
  count_times = NULL,
  n_windows = NULL,
  window_size = NULL,
  min_gap = NULL,
  strategy = c("random", "systematic", "fixed"),
  fixed_windows = NULL,
  start_time = NULL,
  end_time = NULL,
  seed = NULL
)
```

## Arguments

- schedule:

  A `creel_schedule` from
  [`generate_schedule()`](https://chrischizinski.com/tidycreel/dev/reference/generate_schedule.md)
  or
  [`read_schedule()`](https://chrischizinski.com/tidycreel/dev/reference/read_schedule.md).
  Must have a `date` column.

- count_times:

  Optional `creel_schedule` from
  [`generate_count_times()`](https://chrischizinski.com/tidycreel/dev/reference/generate_count_times.md)
  with `start_time`, `end_time` and `window_id`, copied to every row.
  Give this or the drawing arguments, not both.

- n_windows, window_size, min_gap:

  Number of windows per day (or shift), window length and minimum gap
  between windows, in minutes. Required to draw windows. The span (shift
  or `start_time`–`end_time`) must divide evenly by `n_windows`, and
  each of the equal strata must hold `window_size + min_gap`. `min_gap`
  is guaranteed between windows only with `"systematic"` (see
  `strategy`).

- strategy:

  `"random"` (default; one window placed uniformly where it fits in each
  equal stratum – neighbouring windows can be closer than `min_gap`),
  `"systematic"` (a random start in the first stratum, then every
  stratum length, so gaps are at least `min_gap`; a fresh start each
  day, as in Pollock et al. 1994), or `"fixed"` (the clock times in
  `fixed_windows`).

- fixed_windows:

  For `strategy = "fixed"`: a data frame of `start_time` and `end_time`
  (`"HH:MM"`). With shift times in the schedule it must also carry
  `period_id`, giving each shift its own windows, and every window must
  fall inside its shift.

- start_time, end_time:

  The day's counting span (`"HH:MM"`), used to draw windows when the
  schedule has no shift times. Not allowed when it does: the shift is
  the span.

- seed:

  Optional integer seed. The same seed gives the same windows.

## Value

A `creel_schedule` with all columns from `schedule` plus `start_time`,
`end_time` and `window_id`, one row per (schedule row x count window).
Unsampled rows of a schedule made with `include_all = TRUE` keep one row
with missing windows when windows are drawn.

## Details

- **Draw new windows for each day** (pass `n_windows`, `window_size`,
  `min_gap`): every day gets its own random placement, inside that day's
  shift when the schedule carries shift times (from
  [`generate_schedule()`](https://chrischizinski.com/tidycreel/dev/reference/generate_schedule.md)`(periods = )`),
  otherwise inside `start_time` – `end_time`. Instantaneous-count effort
  assumes the count times are random on *each* sampled day; the same
  clock times every day sample any time-of-day pattern in pressure the
  same way, which never averages out and understates the within-day
  variance (#385).

- **Copy one template to every day** (pass `count_times` from
  [`generate_count_times()`](https://chrischizinski.com/tidycreel/dev/reference/generate_count_times.md)):
  the same windows on every day, for fixed-time protocols. With shift
  times in the schedule, every window must fall inside each day's shift.

## See also

Other "Scheduling":
[`generate_bus_schedule()`](https://chrischizinski.com/tidycreel/dev/reference/generate_bus_schedule.md),
[`generate_count_times()`](https://chrischizinski.com/tidycreel/dev/reference/generate_count_times.md),
[`generate_progressive_start()`](https://chrischizinski.com/tidycreel/dev/reference/generate_progressive_start.md),
[`generate_schedule()`](https://chrischizinski.com/tidycreel/dev/reference/generate_schedule.md),
[`new_creel_schedule()`](https://chrischizinski.com/tidycreel/dev/reference/new_creel_schedule.md),
[`read_schedule()`](https://chrischizinski.com/tidycreel/dev/reference/read_schedule.md),
[`validate_creel_schedule()`](https://chrischizinski.com/tidycreel/dev/reference/validate_creel_schedule.md),
[`write_schedule()`](https://chrischizinski.com/tidycreel/dev/reference/write_schedule.md)

## Examples

``` r
# Per-day windows inside each day's drawn shift
sched <- generate_schedule(
  start_date = "2024-06-01", end_date = "2024-06-07",
  n_periods = 2, sampling_rate = 0.5, seed = 1,
  periods_per_day = 1,
  periods = data.frame(
    period_id = 1:2, start_time = c("06:00", "13:00"), end_time = c("13:00", "20:00")
  )
)
attach_count_times(sched, n_windows = 2, window_size = 30, min_gap = 60, seed = 1)
#> # A creel_schedule: 6 rows x 9 cols (3 days, 2 periods)
#> June 2024
#> | Sun      | Mon      | Tue      | Wed      | Thu      | Fri      | Sat      |
#> |----------|----------|----------|----------|----------|----------|----------|
#> |          |          |          |          |          |          | WEEKE    |
#> | 02       | 03       | 04       | WEEKD    | WEEKD    | 07       | 08       |
#> | 09       | 10       | 11       | 12       | 13       | 14       | 15       |
#> | 16       | 17       | 18       | 19       | 20       | 21       | 22       |
#> | 23       | 24       | 25       | 26       | 27       | 28       | 29       |
#> | 30       |          |          |          |          |          |          |

# The same template on every day (a fixed-time protocol)
sched2 <- generate_schedule(
  start_date = "2024-06-01", end_date = "2024-06-07",
  n_periods = 2, sampling_rate = 0.5, seed = 1
)
ct <- generate_count_times(
  start_time = "06:00", end_time = "14:00",
  strategy = "systematic", n_windows = 3,
  window_size = 30, min_gap = 10, seed = 1
)
attach_count_times(sched2, ct)
#> # A creel_schedule: 18 rows x 7 cols (3 days, 2 periods)
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
