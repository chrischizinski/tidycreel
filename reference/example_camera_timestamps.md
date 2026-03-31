# Example camera timestamps dataset (ingress-egress mode)

A dataset of raw ingress and egress timestamps recorded by a remote
camera at a boat launch. Contains 14 rows spanning 4 sampling days in
June 2024 (3-4 anglers per day). Suitable for use with
[`preprocess_camera_timestamps`](https://chrischizinski.github.io/tidycreel/reference/preprocess_camera_timestamps.md).
One row has a trip duration greater than 8 hours (an unusually long
fishing day); all other durations are between 1.5 and 5.5 hours.

## Usage

``` r
example_camera_timestamps
```

## Format

A data frame with 14 rows and 4 variables:

- date:

  Survey date (Date class), June 2024.

- day_type:

  Day type stratum: `"weekday"` or `"weekend"`.

- ingress_time:

  Angler arrival time (POSIXct, America/Chicago timezone).

- egress_time:

  Angler departure time (POSIXct, America/Chicago timezone). Always
  later than `ingress_time`.

## Source

Simulated for package documentation.

## See also

[example_camera_counts](https://chrischizinski.github.io/tidycreel/reference/example_camera_counts.md),
[example_camera_interviews](https://chrischizinski.github.io/tidycreel/reference/example_camera_interviews.md),
[`preprocess_camera_timestamps()`](https://chrischizinski.github.io/tidycreel/reference/preprocess_camera_timestamps.md)

## Examples

``` r
data(example_camera_timestamps)
head(example_camera_timestamps)
#>         date day_type        ingress_time         egress_time
#> 1 2024-06-03  weekday 2024-06-03 06:30:00 2024-06-03 09:45:00
#> 2 2024-06-03  weekday 2024-06-03 07:15:00 2024-06-03 12:15:00
#> 3 2024-06-03  weekday 2024-06-03 08:00:00 2024-06-03 10:45:00
#> 4 2024-06-04  weekday 2024-06-04 05:45:00 2024-06-04 10:00:00
#> 5 2024-06-04  weekday 2024-06-04 06:30:00 2024-06-04 10:00:00
#> 6 2024-06-04  weekday 2024-06-04 07:00:00 2024-06-04 12:30:00

# Preprocess to daily effort hours
daily_effort <- preprocess_camera_timestamps(
  example_camera_timestamps,
  date_col = date,
  ingress_col = ingress_time,
  egress_col = egress_time
)
head(daily_effort)
#>         date daily_effort_hours
#> 1 2024-06-03              11.00
#> 2 2024-06-04              14.75
#> 3 2024-06-08              19.50
#> 4 2024-06-09              12.75
```
