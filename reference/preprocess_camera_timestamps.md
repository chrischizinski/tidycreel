# Preprocess camera ingress-egress timestamps

Converts paired ingress and egress POSIXct timestamps into a data frame
of daily angler-effort hours, suitable for passing to
[`add_counts`](https://chrischizinski.com/tidycreel/reference/add_counts.md).
Duration for each pair is computed as
`difftime(egress_col, ingress_col, units = "hours")`. Pairs where egress
precedes ingress (negative duration) are flagged with
[`cli_warn`](https://cli.r-lib.org/reference/cli_abort.html) and
excluded from the daily sum (set to `NA`).

## Usage

``` r
preprocess_camera_timestamps(timestamps, date_col, ingress_col, egress_col)
```

## Arguments

- timestamps:

  A data frame containing the ingress-egress records.

- date_col:

  Tidy selector for the date column (Date or POSIXct).

- ingress_col:

  Tidy selector for the ingress timestamp column (POSIXct).

- egress_col:

  Tidy selector for the egress timestamp column (POSIXct).

## Value

A data frame with columns `date` and `daily_effort_hours` (one row per
unique date, effort hours summed across all valid pairs for that date).

## Details

Preprocess camera ingress-egress timestamps to daily effort hours

## Examples

``` r
# Camera timestamps: one row per angler arrival/departure pair.
ts <- data.frame(
  survey_date  = rep(as.Date(c("2024-06-01", "2024-06-02")), each = 2L),
  ingress_time = as.POSIXct(
    c("2024-06-01 06:00:00", "2024-06-01 09:00:00",
      "2024-06-02 07:00:00", "2024-06-02 10:30:00"), tz = "UTC"
  ),
  egress_time = as.POSIXct(
    c("2024-06-01 08:00:00", "2024-06-01 11:00:00",
      "2024-06-02 09:00:00", "2024-06-02 13:00:00"), tz = "UTC"
  )
)
preprocess_camera_timestamps(ts, date_col = "survey_date",
                             ingress_col = "ingress_time",
                             egress_col = "egress_time")
#>         date daily_effort_hours
#> 1 2024-06-01                4.0
#> 2 2024-06-02                4.5
```
