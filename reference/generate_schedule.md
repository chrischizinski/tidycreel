# Generate a creel survey sampling schedule

Generates a stratified random sampling calendar for a creel survey
season. The season is divided into `weekday` and `weekend` strata, and
days are randomly selected within each stratum. Output is a
`creel_schedule` tibble ready to pass to
[`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md).

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
  seed
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

## Value

A `creel_schedule` data frame with columns:

- `date` (Date): Sampled (or all) dates.

- `day_type` (character): "weekday" or "weekend".

- `period_id` (integer, character, or ordered factor): Period within
  day. Absent when `expand_periods = FALSE`.

- `sampled` (logical): Present only when `include_all = TRUE`.

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
```
