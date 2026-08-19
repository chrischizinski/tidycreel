# Standardize time column names using stringr

Renames columns in a data.frame to standard time column names if common
variants are found.

## Usage

``` r
standardize_time_columns(df)
```

## Arguments

- df:

  Data.frame

## Value

Data.frame with standardized time column names

## Examples

``` r
df <- data.frame(timestamp = "2025-01-01 08:00", value = 1)
standardize_time_columns(df)
#>               time value
#> 1 2025-01-01 08:00     1
```
