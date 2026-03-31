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
