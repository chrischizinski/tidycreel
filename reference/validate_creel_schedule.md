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
