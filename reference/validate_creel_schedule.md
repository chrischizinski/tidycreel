# Validate a creel_schedule object

Checks that a `creel_schedule` (or plain data frame intended for use
with
[`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md))
has the required columns, correct types, and sensible values. Called by
[`read_schedule()`](https://chrischizinski.github.io/tidycreel/reference/read_schedule.md)
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
[`attach_count_times()`](https://chrischizinski.github.io/tidycreel/reference/attach_count_times.md),
[`generate_bus_schedule()`](https://chrischizinski.github.io/tidycreel/reference/generate_bus_schedule.md),
[`generate_count_times()`](https://chrischizinski.github.io/tidycreel/reference/generate_count_times.md),
[`generate_schedule()`](https://chrischizinski.github.io/tidycreel/reference/generate_schedule.md),
[`new_creel_schedule()`](https://chrischizinski.github.io/tidycreel/reference/new_creel_schedule.md),
[`read_schedule()`](https://chrischizinski.github.io/tidycreel/reference/read_schedule.md),
[`write_schedule()`](https://chrischizinski.github.io/tidycreel/reference/write_schedule.md)
