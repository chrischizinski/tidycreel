# Validate a creel_schedule object

Checks that a `creel_schedule` (or plain data frame intended for use
with
[`creel_design()`](https://chrischizinski.com/tidycreel/reference/creel_design.md))
has the required columns, correct types, and sensible values. Called by
[`read_schedule()`](https://chrischizinski.com/tidycreel/reference/read_schedule.md)
after coercion and available for users to validate hand-constructed
schedules.

## Usage

``` r
validate_creel_schedule(data)
```

## Arguments

- data:

  A data frame to validate.

## Value

Invisibly returns the input data frame on success. Aborts with an
informative error message on validation failure.

## See also

Other "Scheduling":
[`attach_count_times()`](https://chrischizinski.com/tidycreel/reference/attach_count_times.md),
[`generate_bus_schedule()`](https://chrischizinski.com/tidycreel/reference/generate_bus_schedule.md),
[`generate_count_times()`](https://chrischizinski.com/tidycreel/reference/generate_count_times.md),
[`generate_progressive_start()`](https://chrischizinski.com/tidycreel/reference/generate_progressive_start.md),
[`generate_schedule()`](https://chrischizinski.com/tidycreel/reference/generate_schedule.md),
[`new_creel_schedule()`](https://chrischizinski.com/tidycreel/reference/new_creel_schedule.md),
[`read_schedule()`](https://chrischizinski.com/tidycreel/reference/read_schedule.md),
[`write_schedule()`](https://chrischizinski.com/tidycreel/reference/write_schedule.md)

## Examples

``` r
sched <- generate_schedule(
  start_date    = "2024-06-01",
  end_date      = "2024-06-14",
  n_periods     = 1,
  sampling_rate = c(weekday = 0.3, weekend = 0.6),
  seed          = 42
)
validate_creel_schedule(sched)
```
