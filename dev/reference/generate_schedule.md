# Generate a creel survey sampling schedule

Generates a stratified random sampling calendar for a creel survey
season. The season is divided into `weekday` and `weekend` strata, and
days are randomly selected within each stratum. Output is a
`creel_schedule` tibble ready to pass to
[`creel_design()`](https://chrischizinski.com/tidycreel/dev/reference/creel_design.md).

## Usage

``` r
generate_schedule(
  start_date,
  end_date,
  n_periods,
  n_days = NULL,
  sampling_rate = NULL,
  period_labels = NULL,
  expand_periods = TRUE,
  include_all = FALSE,
  ordered_periods = FALSE,
  period_intensity = NULL,
  seed,
  special_periods = NULL,
  periods_per_day = NULL,
  period_allocation = c("balanced", "random"),
  periods = NULL,
  day_start = "00:00",
  weekend_days = NULL
)
```

## Arguments

- start_date:

  Character or Date. First day of the survey season (ISO 8601
  "YYYY-MM-DD").

- end_date:

  Character or Date. Last day of the survey season (ISO 8601
  "YYYY-MM-DD").

- n_periods:

  Integer. Number of sampling periods per day.

- n_days:

  Named integer vector of days to sample per stratum (e.g.,
  `c(weekday = 20, weekend = 10)`), or a scalar applied uniformly to all
  strata. Mutually exclusive with `sampling_rate`.

- sampling_rate:

  Named numeric vector of sampling fractions per stratum (e.g.,
  `c(weekday = 0.3, weekend = 0.6)`), or a scalar applied uniformly to
  all strata. Mutually exclusive with `n_days`.

- period_labels:

  Optional character vector of length `n_periods` with human-readable
  period names. When supplied, `period_id` is character (or ordered
  factor if `ordered_periods = TRUE`).

- expand_periods:

  Logical (default `TRUE`). If `TRUE`, output has one row per sampled
  day x period (nrow = sampled_days \* n_periods). If `FALSE`, output
  has one row per sampled day and `period_id` is omitted.

- include_all:

  Logical (default `FALSE`). If `TRUE`, all season dates are returned
  with a `sampled` logical column. If `FALSE`, only sampled dates are
  returned.

- ordered_periods:

  Logical (default `FALSE`). If `TRUE` and `period_labels` is supplied,
  `period_id` is an ordered factor preserving label order.

- period_intensity:

  Not yet implemented. Must be `NULL`.

- seed:

  Integer seed for reproducible random day selection. Uses
  [`withr::with_seed()`](https://withr.r-lib.org/reference/with_seed.html)
  to avoid mutating global RNG state.

- special_periods:

  Optional data frame declaring calendar-defined special periods. Must
  contain `start_date`, `end_date`, and `label` columns, with optional
  `reason`. Periods are expanded to day-level assignments before
  sampling so boundary-crossing periods are split by civil date.

- periods_per_day:

  Integer. How many of the `n_periods` periods (shifts) are worked on
  each sampled day. `NULL` (default) means all of them, as before. With
  fewer, the worked periods are drawn at random for each sampled day and
  each row records its selection probability in `p_period`
  (`periods_per_day / n_periods`), e.g. one of two shifts gives
  `p_period = 0.5`. Needs `expand_periods = TRUE`.

- period_allocation:

  How the worked periods are drawn when `periods_per_day < n_periods`.
  `"balanced"` (default): within each stratum the periods are dealt to
  the sampled days in random order, so the number of days per period
  differs by at most one (e.g. 5 morning + 5 evening over 10 weekdays).
  `"random"`: an independent draw for each day. Under both, every period
  has the same chance, `p_period`, of being worked on any sampled day.
  The variance estimators treat the draws as independent, which is
  conservative for `"balanced"`.

- periods:

  Optional data frame of shift times: `period_id` (one row per period,
  matching `period_labels`, or 1 to `n_periods`), `start_time` and
  `end_time` as `"HH:MM"`. Adds `shift_start` and `shift_end` to every
  row. With a `date` column the times vary by day – one row per date and
  period, covering every worked date – as returned by
  [`daylight_shifts()`](https://chrischizinski.com/tidycreel/dev/reference/daylight_shifts.md)
  for shifts bounded by sunrise and sunset. Times are read on the
  survey-day clock that starts at `day_start`, and each shift must fall
  inside one survey day. An optional `hours` column (as
  [`daylight_shifts()`](https://chrischizinski.com/tidycreel/dev/reference/daylight_shifts.md)
  returns) gives each shift's real elapsed length and is kept as
  `shift_hours`; it differs from the clock length only across a
  daylight-saving change.

- day_start:

  Clock time (`"HH:MM"`) at which a survey day begins. The default
  `"00:00"` is the calendar day, as before. For night creels whose
  shifts cross midnight, choose a time no shift spans, e.g. `"12:00"`:
  then 19:30-00:30 and 00:30-06:00 are the two halves of one night,
  dated by the date the night starts. A shift time earlier than
  `day_start` is on the next calendar day. The schedule records it in a
  `day_start` column. Mapping counts and interviews to night survey days
  is not available yet (#407), so
  [`creel_design()`](https://chrischizinski.com/tidycreel/dev/reference/creel_design.md)
  refuses such a schedule as its calendar for now.

- weekend_days:

  Day names (full or three-letter English, any case) whose survey days
  form the `weekend` stratum. `NULL` (default) means Saturday and
  Sunday, and is only allowed when `day_start = "00:00"`: a night is
  dated by the day it starts, so with that default a Friday night would
  be a weekday, and agencies differ on which nights are the weekend
  (e.g. `c("Friday", "Saturday")`).

## Value

A `creel_schedule` data frame with columns:

- `date` (Date): Sampled (or all) dates.

- `day_type` (character): Baseline "weekday" or "weekend"
  classification.

- `final_stratum` (character): Present when `special_periods` is
  supplied; gives the final stratum used for day selection.

- `special_period_reason` (character): Present when `special_periods` is
  supplied; gives the optional reason for the special-period assignment.

- `period_id` (integer, character, or ordered factor): Period within
  day. Absent when `expand_periods = FALSE`.

- `p_period` (numeric): Probability that the period was the one worked
  that day: `1` when every period is worked,
  `periods_per_day / n_periods` when they are drawn, `NA` on unsampled
  days. Absent when `expand_periods = FALSE`.

- `shift_start`, `shift_end` (character, "HH:MM"): Present when
  `periods` is supplied.

- `shift_hours` (numeric): Present when `periods` has an `hours` column.

- `day_start` (character, "HH:MM"): Present when `day_start` is not
  `"00:00"`.

- `sampled` (logical): Present only when `include_all = TRUE`.

## See also

Other "Scheduling":
[`attach_count_times()`](https://chrischizinski.com/tidycreel/dev/reference/attach_count_times.md),
[`daylight_shifts()`](https://chrischizinski.com/tidycreel/dev/reference/daylight_shifts.md),
[`generate_bus_schedule()`](https://chrischizinski.com/tidycreel/dev/reference/generate_bus_schedule.md),
[`generate_count_times()`](https://chrischizinski.com/tidycreel/dev/reference/generate_count_times.md),
[`generate_progressive_start()`](https://chrischizinski.com/tidycreel/dev/reference/generate_progressive_start.md),
[`new_creel_schedule()`](https://chrischizinski.com/tidycreel/dev/reference/new_creel_schedule.md),
[`read_schedule()`](https://chrischizinski.com/tidycreel/dev/reference/read_schedule.md),
[`validate_creel_schedule()`](https://chrischizinski.com/tidycreel/dev/reference/validate_creel_schedule.md),
[`write_schedule()`](https://chrischizinski.com/tidycreel/dev/reference/write_schedule.md)

## Examples

``` r
# Basic schedule with stratified sampling rates
sched <- generate_schedule(
  start_date = "2024-06-01",
  end_date = "2024-08-31",
  n_periods = 2,
  sampling_rate = c(weekday = 0.3, weekend = 0.6),
  seed = 42
)

# Use result with creel_design()
creel_design(sched, date = date, strata = day_type)

# One of two shifts worked on each sampled day, drawn at random
shifts <- generate_schedule(
  start_date = "2024-06-01",
  end_date = "2024-08-31",
  n_periods = 2,
  period_labels = c("AM", "PM"),
  sampling_rate = c(weekday = 0.3, weekend = 0.6),
  periods_per_day = 1,
  periods = data.frame(
    period_id = c("AM", "PM"),
    start_time = c("06:00", "13:00"),
    end_time = c("13:00", "20:00")
  ),
  seed = 42
)
head(shifts)
#> # A creel_schedule: 6 rows x 6 cols (6 days, 2 periods)
#> June 2024
#> | Sun      | Mon      | Tue      | Wed      | Thu      | Fri      | Sat      |
#> |----------|----------|----------|----------|----------|----------|----------|
#> |          |          |          |          |          |          | WEEKE    |
#> | WEEKE    | 03       | 04       | WEEKD    | 06       | WEEKD    | WEEKE    |
#> | WEEKE    | 10       | 11       | 12       | 13       | 14       | 15       |
#> | 16       | 17       | 18       | 19       | 20       | 21       | 22       |
#> | 23       | 24       | 25       | 26       | 27       | 28       | 29       |
#> | 30       |          |          |          |          |          |          |
```
