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
  `strategy = "random"` and `"systematic"`.

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

  Non-negative integer. Minimum gap (minutes) between windows. Required
  for `strategy = "random"` and `"systematic"`. `window_size + min_gap`
  must not exceed the stratum width (`total_span / n_windows`).

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
[`write_schedule()`](https://chrischizinski.github.io/tidycreel/reference/write_schedule.md).

**Random strategy:** Each of the `n_windows` strata of equal length
`k = total_span / n_windows` receives one window with a uniformly random
start within `[stratum_start, stratum_start + k - window_size]`.

**Systematic strategy (recommended):** A single random start `t1` is
drawn from `[start_min, start_min + k - window_size]`; all subsequent
windows begin at `t1 + (i-1) * k` for `i = 1, ..., n_windows`. This is
the design described in Pollock et al. (1994) and recommended by
Colorado CPW (2012).

**Fixed strategy:** Windows are taken exactly as supplied after sorting
by start time. Overlapping windows trigger an error.

## Examples

``` r
# Random strategy
generate_count_times(
  start_time = "06:00", end_time = "14:00",
  strategy = "random", n_windows = 4, window_size = 30, min_gap = 10,
  seed = 42
)
#> # A creel_schedule: 4 rows x 3 cols (NA days, 1 periods)
#>   start_time end_time window_id
#> 1      06:48    07:18         1
#> 2      09:04    09:34         2
#> 3      10:24    10:54         3
#> 4      13:13    13:43         4

# Systematic strategy (preferred; Pollock et al. 1994)
generate_count_times(
  start_time = "06:00", end_time = "14:00",
  strategy = "systematic", n_windows = 4, window_size = 30, min_gap = 10,
  seed = 42
)
#> # A creel_schedule: 4 rows x 3 cols (NA days, 1 periods)
#>   start_time end_time window_id
#> 1      06:48    07:18         1
#> 2      08:48    09:18         2
#> 3      10:48    11:18         3
#> 4      12:48    13:18         4

# Fixed strategy
fw <- data.frame(
  start_time = c("07:00", "09:00", "11:00"),
  end_time = c("07:30", "09:30", "11:30"),
  stringsAsFactors = FALSE
)
generate_count_times(strategy = "fixed", fixed_windows = fw)
#> # A creel_schedule: 3 rows x 3 cols (NA days, 1 periods)
#>   start_time end_time window_id
#> 1      07:00    07:30         1
#> 2      09:00    09:30         2
#> 3      11:00    11:30         3
```
