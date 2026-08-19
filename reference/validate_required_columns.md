# Validate required columns in a data.frame

Checks that all required columns are present in the input data.frame or
tibble. Returns TRUE if all are present, otherwise returns a character
vector of missing columns.

## Usage

``` r
validate_required_columns(df, required)
```

## Arguments

- df:

  A data.frame or tibble

- required:

  Character vector of required column names

## Value

TRUE if all present, else character vector of missing columns

## Examples

``` r
df <- data.frame(date = "2025-01-01", count = 5)
validate_required_columns(df, c("date", "count"))
#> [1] TRUE
```
