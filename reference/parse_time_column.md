# Parse time columns using lubridate

Attempts to parse a vector of time strings to POSIXct using lubridate.
Returns parsed times or original if already POSIXct.

## Usage

``` r
parse_time_column(x)
```

## Arguments

- x:

  Character vector or POSIXct

## Value

POSIXct vector

## Examples

``` r
parse_time_column(c("2025-08-20 08:00:00", "2025-08-20 12:00:00"))
#> [1] "2025-08-20 08:00:00 UTC" "2025-08-20 12:00:00 UTC"
```
