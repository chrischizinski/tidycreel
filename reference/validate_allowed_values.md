# Validate values in a column

Checks that all values in a column are within a set of allowed values.
Returns TRUE if all are valid, otherwise returns a vector of invalid
values.

## Usage

``` r
validate_allowed_values(x, allowed)
```

## Arguments

- x:

  Vector of values

- allowed:

  Allowed values

## Value

TRUE if all valid, else vector of invalid values

## Examples

``` r
shifts <- c("AM", "PM", "AM")
validate_allowed_values(shifts, c("AM", "PM", "EVE"))
#> [1] TRUE
```
