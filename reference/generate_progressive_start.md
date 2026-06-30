# Schedule progressive count circuit start times

Generates randomised start times for progressive count surveys following
Hoenig et al. (1993). Two scheduling strategies are supported:

## Usage

``` r
generate_progressive_start(
  open_start,
  open_end,
  circuit_time,
  strategy = c("discrete", "wraparound"),
  n = 1L,
  seed = NULL
)
```

## Arguments

- open_start:

  Character. Survey-day opening time in `"HH:MM"` format.

- open_end:

  Character. Survey-day closing time in `"HH:MM"` format. Must be later
  than `open_start`.

- circuit_time:

  Positive numeric. Duration of one circuit traversal \\\tau\\ in hours.
  Must be shorter than the survey period T.

- strategy:

  Character scalar. `"discrete"` (default) or `"wraparound"`. For
  `"discrete"`, T / `circuit_time` must be a whole number (within 0.001
  h tolerance).

- n:

  Positive integer. Number of survey days to schedule. Returns one row
  per day.

- seed:

  Optional integer. Passed to
  [`withr::with_seed()`](https://withr.r-lib.org/reference/with_seed.html)
  for reproducible scheduling. Has no effect when `NULL`.

## Value

A `creel_schedule` data frame with columns:

- `circuit_start` (character `"HH:MM"`): Scheduled circuit start time.

- `circuit_end` (character `"HH:MM"`): Scheduled circuit end time. For
  `"wraparound"` this may be earlier than `circuit_start` when the
  circuit crosses the end of the survey period.

- `is_wrapped` (logical): `TRUE` when circuit wraps around the end of
  the survey period. Always `FALSE` for `"discrete"`.

- `direction` (character): `"forward"` or `"reverse"`. Must be
  implemented in the field protocol for unbiased estimation.

## Details

- `"discrete"` (recommended): The survey period T must be an integer
  multiple of the circuit time \\\tau\\. A start time is drawn uniformly
  from \\\\0, \tau, 2\tau, \ldots, (k-1)\tau\\\\ where \\k = T/\tau\\.
  The starting *location* and *direction* of travel must both be
  randomised; direction is returned in the output and must be recorded
  in the field protocol.

- `"wraparound"`: A start time is drawn from \\U\[0, T)\\. If the
  circuit would extend past the end of the survey period it wraps to the
  beginning of the day (`is_wrapped = TRUE`). Starting location need not
  be randomised, though direction still must be.

## Common scheduling error

Drawing the start time from \\U\[0, T - \tau\]\\ is **biased** — it
makes the middle of the survey day over-represented, introducing bias
toward mid-day effort patterns. Both strategies here avoid this error.

## References

Hoenig, J. M., Robson, D. S., Jones, C. M., and Pollock, K. H. (1993).
Scheduling counts in the instantaneous and progressive count methods for
estimating sportfishing effort. *North American Journal of Fisheries
Management*, **13**, 723–736.

## See also

Other "Scheduling":
[`attach_count_times()`](https://chrischizinski.github.io/tidycreel/reference/attach_count_times.md),
[`generate_bus_schedule()`](https://chrischizinski.github.io/tidycreel/reference/generate_bus_schedule.md),
[`generate_count_times()`](https://chrischizinski.github.io/tidycreel/reference/generate_count_times.md),
[`generate_schedule()`](https://chrischizinski.github.io/tidycreel/reference/generate_schedule.md),
[`new_creel_schedule()`](https://chrischizinski.github.io/tidycreel/reference/new_creel_schedule.md),
[`read_schedule()`](https://chrischizinski.github.io/tidycreel/reference/read_schedule.md),
[`validate_creel_schedule()`](https://chrischizinski.github.io/tidycreel/reference/validate_creel_schedule.md),
[`write_schedule()`](https://chrischizinski.github.io/tidycreel/reference/write_schedule.md)

## Examples

``` r
# Discrete strategy: T = 10 h, tau = 2 h → k = 5 valid start times
generate_progressive_start(
  open_start = "06:00", open_end = "16:00",
  circuit_time = 2, strategy = "discrete", n = 5, seed = 42
)
#> # A creel_schedule: 5 rows x 4 cols (NA days, 1 periods)
#> (no date column to render calendar)

# Wraparound strategy: start drawn from U[0, T)
generate_progressive_start(
  open_start = "06:00", open_end = "16:00",
  circuit_time = 2, strategy = "wraparound", n = 5, seed = 42
)
#> # A creel_schedule: 5 rows x 4 cols (NA days, 1 periods)
#> (no date column to render calendar)
```
