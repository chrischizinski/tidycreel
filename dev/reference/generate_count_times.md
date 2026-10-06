# Generate within-day count time windows

Generates count time windows for a creel survey day using one of three
strategies: random (stratified random placement within equal-width
strata), systematic (random start in first stratum with fixed spacing
thereafter, preferred per Pollock et al. 1994 and Colorado CPW 2012), or
fixed (user-supplied non-overlapping windows).

## Usage

``` r
generate_count_times(
  start_time = NULL,
  end_time = NULL,
  strategy,
  n_windows = NULL,
  window_size = NULL,
  min_gap = NULL,
  fixed_windows = NULL,
  seed = NULL
)
```

## Arguments

- start_time:

  Character. Survey-day start time in `"HH:MM"` format. Required for
  `strategy = "random"` and `"systematic"`.

- end_time:

  Character. Survey-day end time in `"HH:MM"` format. Required for
  `strategy = "random"` and `"systematic"`. Must be after `start_time`;
  for a night that crosses midnight, use
  [`attach_count_times()`](https://chrischizinski.com/tidycreel/dev/reference/attach_count_times.md)
  on a schedule built with `generate_schedule(day_start = )`.

- strategy:

  Character scalar. One of `"random"`, `"systematic"`, or `"fixed"`.

- n_windows:

  Positive integer. Number of count time windows. Required for
  `strategy = "random"` and `"systematic"`. The total span
  (`end_time - start_time` in minutes) must be evenly divisible by
  `n_windows`.

- window_size:

  Positive integer. Duration of each count window in minutes. Required
  for `strategy = "random"` and `"systematic"`.

- min_gap:

  Non-negative integer, minutes. Required for `strategy = "random"` and
  `"systematic"`. `window_size + min_gap` must not exceed the stratum
  width (`total_span / n_windows`). With `"systematic"` every gap is
  then at least `min_gap`. With `"random"` it is only this fit check:
  each count's start is drawn uniformly over its whole stratum, without
  holding back room for the gap (which would leave parts of the span no
  count could reach), so neighbouring counts can be closer than
  `min_gap` (but never so close that their slots overlap). Use
  `"systematic"` when spacing must be guaranteed.

- fixed_windows:

  A data frame with `start_time` and `end_time` columns (character
  `"HH:MM"`). Required for `strategy = "fixed"`. Windows must be
  non-overlapping.

- seed:

  Integer seed for reproducible window placement. Passed to
  [`withr::with_seed()`](https://withr.r-lib.org/reference/with_seed.html).
  Applies to `"random"` and `"systematic"` strategies. Has no effect for
  `"fixed"` strategy.

## Value

A `creel_schedule` data frame with columns:

- `start_time` (character `"HH:MM"`): Window start time.

- `end_time` (character `"HH:MM"`): Window end time.

- `window_id` (integer, 1-based, ordered by start time): Window index.

## Details

Output is a `creel_schedule` data frame compatible with
[`write_schedule()`](https://chrischizinski.com/tidycreel/dev/reference/write_schedule.md).

The start of each window is the count instant: crews count at the start
of the slot, and `window_size` is how long the count keeps them busy.
Starts are drawn over the whole of each stratum, so every minute of the
span is close to equally likely to be counted. One crew cannot run two
counts at once, so a random draw whose slots overlap is redrawn
(delaying the second count instead would move its instant and bias
effort); this makes instants just after a stratum boundary slightly less
likely than elsewhere. Systematic starts never overlap. A start late in
the last stratum makes the last slot end after the span, which is fine:
the count instant is inside it. Before \#432 starts were drawn only
where the whole slot fitted, so the last `window_size` minutes of each
stratum were never counted.

**Random strategy:** Each of the `n_windows` strata of equal length
`k = total_span / n_windows` receives one window with a uniformly random
start within `[stratum_start, stratum_start + k)`.

**Systematic strategy (recommended):** A single random start `t1` is
drawn from `[start_min, start_min + k)`; all subsequent windows begin at
`t1 + (i-1) * k` for `i = 1, ..., n_windows`. This is the design
described in Pollock et al. (1994) and recommended by Colorado CPW
(2012).

**Fixed strategy:** Windows are taken exactly as supplied after sorting
by start time. Overlapping windows trigger an error.

## See also

Other "Scheduling":
[`attach_count_times()`](https://chrischizinski.com/tidycreel/dev/reference/attach_count_times.md),
[`daylight_shifts()`](https://chrischizinski.com/tidycreel/dev/reference/daylight_shifts.md),
[`generate_bus_schedule()`](https://chrischizinski.com/tidycreel/dev/reference/generate_bus_schedule.md),
[`generate_progressive_start()`](https://chrischizinski.com/tidycreel/dev/reference/generate_progressive_start.md),
[`generate_schedule()`](https://chrischizinski.com/tidycreel/dev/reference/generate_schedule.md),
[`new_creel_schedule()`](https://chrischizinski.com/tidycreel/dev/reference/new_creel_schedule.md),
[`read_schedule()`](https://chrischizinski.com/tidycreel/dev/reference/read_schedule.md),
[`validate_creel_schedule()`](https://chrischizinski.com/tidycreel/dev/reference/validate_creel_schedule.md),
[`write_schedule()`](https://chrischizinski.com/tidycreel/dev/reference/write_schedule.md)

## Examples

``` r
# Random strategy
generate_count_times(
  start_time = "06:00", end_time = "14:00",
  strategy = "random", n_windows = 4, window_size = 30, min_gap = 10,
  seed = 42
)
#> # A creel_schedule: 4 rows x 3 cols (NA days, 1 periods)
#> (no date column to render calendar)

# Systematic strategy (preferred; Pollock et al. 1994)
generate_count_times(
  start_time = "06:00", end_time = "14:00",
  strategy = "systematic", n_windows = 4, window_size = 30, min_gap = 10,
  seed = 42
)
#> # A creel_schedule: 4 rows x 3 cols (NA days, 1 periods)
#> (no date column to render calendar)

# Fixed strategy
fw <- data.frame(
  start_time = c("07:00", "09:00", "11:00"),
  end_time = c("07:30", "09:30", "11:30"),
  stringsAsFactors = FALSE
)
generate_count_times(strategy = "fixed", fixed_windows = fw)
#> # A creel_schedule: 3 rows x 3 cols (NA days, 1 periods)
#> (no date column to render calendar)
```
