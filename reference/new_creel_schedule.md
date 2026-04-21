# Create a creel_schedule S3 object

Constructor for the `creel_schedule` S3 class. Wraps a data frame with
the `creel_schedule` class attribute following the tibble-subclass
pattern used throughout the package.

## Usage

``` r
new_creel_schedule(data)
```

## Arguments

- data:

  A data frame to wrap as a `creel_schedule`.

## Value

A data frame with class `c("creel_schedule", "data.frame")`.

## See also

Other "Scheduling":
[`attach_count_times()`](https://chrischizinski.github.io/tidycreel/reference/attach_count_times.md),
[`generate_bus_schedule()`](https://chrischizinski.github.io/tidycreel/reference/generate_bus_schedule.md),
[`generate_count_times()`](https://chrischizinski.github.io/tidycreel/reference/generate_count_times.md),
[`generate_schedule()`](https://chrischizinski.github.io/tidycreel/reference/generate_schedule.md),
[`read_schedule()`](https://chrischizinski.github.io/tidycreel/reference/read_schedule.md),
[`validate_creel_schedule()`](https://chrischizinski.github.io/tidycreel/reference/validate_creel_schedule.md),
[`write_schedule()`](https://chrischizinski.github.io/tidycreel/reference/write_schedule.md)
