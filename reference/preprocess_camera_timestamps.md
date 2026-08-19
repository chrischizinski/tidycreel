# Preprocess camera ingress-egress timestamps

Converts paired ingress and egress POSIXct timestamps into a data frame
of daily angler-effort hours, suitable for passing to
[`add_counts`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md).
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
