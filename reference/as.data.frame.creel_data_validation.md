# Coerce a creel_data_validation to a plain data frame

Strips the `creel_data_validation` class, returning the underlying data
frame of check results.

## Usage

``` r
# S3 method for class 'creel_data_validation'
as.data.frame(x, ...)
```

## Arguments

- x:

  A `creel_data_validation` object.

- ...:

  Ignored.

## Value

A plain `data.frame`.
