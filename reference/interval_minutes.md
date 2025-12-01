# Calculate interval in minutes between two time columns

Uses lubridate to compute the difference in minutes between two POSIXct
vectors.

## Usage

``` r
interval_minutes(start, end)
```

## Arguments

- start:

  POSIXct vector

- end:

  POSIXct vector

## Value

Numeric vector of interval lengths in minutes

## Examples

``` r
start_time <- as.POSIXct("2025-01-01 08:00:00")
end_time <- as.POSIXct("2025-01-01 12:30:00")
interval_minutes(start_time, end_time)
#> [1] 270
```
