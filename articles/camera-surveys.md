# Camera Survey Analysis with tidycreel

## Overview

Remote cameras mounted at boat launches or trail heads record angler
arrivals with no observer present. This enables 24-hour coverage of
access points that would otherwise require continuous staffing. The
`tidycreel` package supports two camera-based sub-modes:

- **Counter mode** — the camera records a single daily total of incoming
  anglers (e.g., a passive infrared counter). The data arrive as one row
  per sampling day with a numeric ingress count.
- **Ingress-egress mode** — the camera records individual arrival and
  departure timestamps for each angler or party. The raw data are paired
  POSIXct timestamps that are preprocessed with
  [`preprocess_camera_timestamps()`](https://chrischizinski.github.io/tidycreel/reference/preprocess_camera_timestamps.md)
  before entering the standard effort estimation workflow.

Both modes share a key concept: the `camera_status` column. Unlike
random missed observations (modeled via `missing_sections`), a camera
failure is an **informative gap** — the number of anglers that passed
during the outage is unknown and cannot be estimated from the
surrounding data. These rows must be removed before calling
[`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md).

## Example Data

This vignette uses three built-in datasets representing a hypothetical
summer creel survey at a Nebraska reservoir boat launch in June 2024.

``` r

library(tidycreel)

data(example_camera_counts)
data(example_camera_timestamps)
data(example_camera_interviews)

head(example_camera_counts)
#>         date day_type ingress_count camera_status
#> 1 2024-06-03  weekday            48   operational
#> 2 2024-06-04  weekday            55   operational
#> 3 2024-06-05  weekday            43   operational
#> 4 2024-06-07  weekend            91   operational
#> 5 2024-06-08  weekend            85   operational
#> 6 2024-06-10  weekday            50   operational
head(example_camera_timestamps)
#>         date day_type        ingress_time         egress_time
#> 1 2024-06-03  weekday 2024-06-03 06:30:00 2024-06-03 09:45:00
#> 2 2024-06-03  weekday 2024-06-03 07:15:00 2024-06-03 12:15:00
#> 3 2024-06-03  weekday 2024-06-03 08:00:00 2024-06-03 10:45:00
#> 4 2024-06-04  weekday 2024-06-04 05:45:00 2024-06-04 10:00:00
#> 5 2024-06-04  weekday 2024-06-04 06:30:00 2024-06-04 10:00:00
#> 6 2024-06-04  weekday 2024-06-04 07:00:00 2024-06-04 12:30:00
head(example_camera_interviews)
#>         date day_type trip_status hours_fished walleye walleye_kept bass
#> 1 2024-06-03  weekday    complete          3.7       0            0    3
#> 2 2024-06-03  weekday    complete          2.5       0            0    0
#> 3 2024-06-03  weekday    complete          1.4       1            0    1
#> 4 2024-06-03  weekday    complete          4.0       1            1    2
#> 5 2024-06-03  weekday    complete          2.8       0            0    1
#> 6 2024-06-04  weekday    complete          0.7       1            0    1
#>   bass_kept
#> 1         2
#> 2         0
#> 3         0
#> 4         2
#> 5         0
#> 6         0
```

The `example_camera_counts` dataset contains 10 rows: nine operational
days plus one battery failure gap. The `example_camera_timestamps`
dataset has 14 raw arrival/departure pairs across four sampling days.
The `example_camera_interviews` dataset has 40 complete angler
interviews targeting walleye and bass across eight sampling days.

## Counter Mode

### Build a Survey Calendar

Counter-mode surveys require a calendar that covers the sampling frame.
Here we build one from the unique dates in the counts and interview
data.

``` r

# Collect all unique sampling dates across datasets
all_dates <- sort(unique(c(
  example_camera_counts$date,
  example_camera_interviews$date
)))

# Assign day type for each date (weekday = Mon-Fri, weekend = Sat-Sun)
cam_calendar <- data.frame(
  date = all_dates,
  day_type = ifelse(
    weekdays(all_dates) %in% c("Saturday", "Sunday"),
    "weekend", "weekday"
  ),
  stringsAsFactors = FALSE
)

head(cam_calendar)
#>         date day_type
#> 1 2024-06-03  weekday
#> 2 2024-06-04  weekday
#> 3 2024-06-05  weekday
#> 4 2024-06-07  weekday
#> 5 2024-06-08  weekend
#> 6 2024-06-10  weekday
```

### Design Construction

Build a camera design using
[`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md)
with `survey_type = "camera"`. The `camera_mode` argument is required.
Omitting it produces an informative error:

``` r

creel_design(
  cam_calendar,
  date = date, strata = day_type,
  survey_type = "camera"
)
#> Error in `creel_design()`:
#> ! `camera_mode` is required for "camera" survey designs.
#> ✖ No `camera_mode` supplied.
#> ℹ Valid values: "counter" and "ingress_egress".
```

Build the correct design with `camera_mode = "counter"`:

``` r

design_counter <- creel_design(
  cam_calendar,
  date        = date,
  strata      = day_type,
  survey_type = "camera",
  camera_mode = "counter"
)
print(design_counter)
#> 
#> ── Creel Survey Design ─────────────────────────────────────────────────────────
#> Type: "camera"
#> Date column: date
#> Strata: day_type
#> Calendar: 10 days (2024-06-03 to 2024-06-15)
#> day_type: 2 levels
#> Counts: "none"
#> Interviews: "none"
#> Sections: "none"
#> 
#> ── Camera Survey Design ──
#> 
#> Camera mode: "counter"
```

## Handling Informative Gaps

The battery failure row on 2024-06-11 has `ingress_count = NA`. This is
not a random unsampled day — the camera was physically unable to record.
Including it in
[`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)
would silently propagate a missing value into the Horvitz-Thompson
estimator.

``` r

# The gap row
subset(example_camera_counts, camera_status != "operational")
#>         date day_type ingress_count   camera_status
#> 7 2024-06-11  weekday            NA battery_failure
```

The correct approach is to **filter to operational rows** before calling
[`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md).
This is fundamentally different from `missing_sections`, which models
probabilistic non-coverage within a sampled period. A camera failure
means no data exist — the effort during that period is unknown.

``` r

# Keep only days when the camera was working
counts_clean <- subset(example_camera_counts, camera_status == "operational")
nrow(counts_clean) # 9 operational rows
#> [1] 9
```

### Effort Estimation

``` r

design_counter <- add_counts(design_counter, counts_clean)
#> Warning in svydesign.default(ids = psu_formula, strata = strata_formula, : No
#> weights or probabilities supplied, assuming equal probability
effort_counter <- suppressWarnings(estimate_effort(design_counter))
print(effort_counter)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Total
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Effort target: sampled_days
#> 
#> # A tibble: 1 × 7
#>   estimate    se se_between se_within ci_lower ci_upper     n
#>      <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int>
#> 1      613  20.9       20.9         0     564.     662.     9
```

The `estimate` column is the Horvitz-Thompson estimate of total ingress
angler visits across the full survey period, with a 95% confidence
interval.

## Ingress-Egress Mode

When the camera records individual arrival and departure timestamps, use
[`preprocess_camera_timestamps()`](https://chrischizinski.github.io/tidycreel/reference/preprocess_camera_timestamps.md)
to aggregate the raw pairs into daily effort hours before calling
[`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md).

### Preprocess Timestamps

``` r

daily_effort <- preprocess_camera_timestamps(
  example_camera_timestamps,
  date_col    = date,
  ingress_col = ingress_time,
  egress_col  = egress_time
)
print(daily_effort)
#>         date daily_effort_hours
#> 1 2024-06-03              11.00
#> 2 2024-06-04              14.75
#> 3 2024-06-08              19.50
#> 4 2024-06-09              12.75
```

[`preprocess_camera_timestamps()`](https://chrischizinski.github.io/tidycreel/reference/preprocess_camera_timestamps.md)
sums all valid trip durations within each day and returns a data frame
with `date` and `daily_effort_hours`. A warning is issued for any rows
where `egress_time < ingress_time` (negative durations); those rows are
set to `NA` and excluded from the daily sum.

Because
[`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)
requires all design strata columns, merge the day type back in from the
raw timestamps:

``` r

day_type_key <- unique(example_camera_timestamps[, c("date", "day_type")])
daily_effort <- merge(daily_effort, day_type_key, by = "date")
print(daily_effort)
#>         date daily_effort_hours day_type
#> 1 2024-06-03              11.00  weekday
#> 2 2024-06-04              14.75  weekday
#> 3 2024-06-08              19.50  weekend
#> 4 2024-06-09              12.75  weekend
```

### Build the Design and Estimate Effort

``` r

ie_calendar <- data.frame(
  date = daily_effort$date,
  day_type = daily_effort$day_type,
  stringsAsFactors = FALSE
)

design_ie <- creel_design(
  ie_calendar,
  date        = date,
  strata      = day_type,
  survey_type = "camera",
  camera_mode = "ingress_egress"
)

design_ie <- add_counts(design_ie, daily_effort)
#> Warning in svydesign.default(ids = psu_formula, strata = strata_formula, : No
#> weights or probabilities supplied, assuming equal probability
effort_ie <- suppressWarnings(estimate_effort(design_ie))
print(effort_ie)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Total
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Effort target: sampled_days
#> 
#> # A tibble: 1 × 7
#>   estimate    se se_between se_within ci_lower ci_upper     n
#>      <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int>
#> 1       58  7.72       7.72         0     24.8     91.2     4
```

## Interview-Based Catch Estimation

Camera designs support the same interview workflow as standard
instantaneous designs. Use the counter-mode design (which spans all
eight interview dates) and attach the interview data with
[`add_interviews()`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md).

``` r

design_catch <- add_interviews(
  design_counter,
  example_camera_interviews,
  catch       = walleye,
  effort      = hours_fished,
  trip_status = trip_status
)
#> ℹ No `n_anglers` provided — assuming 1 angler per interview.
#> ℹ Pass `n_anglers = <column>` to use actual party sizes for angler-hour
#>   normalization.
#> Warning: 14 interviews have zero catch.
#> ℹ Zero catch may be valid (skunked) or indicate missing data.
#> ℹ Added 40 interviews: 40 complete (100%), 0 incomplete (0%)
```

### Catch Rate

[`estimate_catch_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_catch_rate.md)
computes the ratio-of-means CPUE (walleye per angler-hour) using only
complete trips.

``` r

catch_rate <- suppressWarnings(estimate_catch_rate(design_catch))
#> ℹ Using complete trips for CPUE estimation
#>   (n=40, 100% of 40 interviews) [default]
print(catch_rate)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Ratio-of-Means CPUE
#> Variance: Taylor linearization
#> Confidence level: 95%
#> 
#> # A tibble: 1 × 5
#>   estimate     se ci_lower ci_upper     n
#>      <dbl>  <dbl>    <dbl>    <dbl> <int>
#> 1    0.453 0.0755    0.305    0.601    40
```

### Total Catch

[`estimate_total_catch()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_catch.md)
multiplies the CPUE estimate by the total effort estimate to produce a
projected total walleye catch over the survey period.

``` r

total_catch <- suppressWarnings(estimate_total_catch(design_catch))
print(total_catch)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Total Catch (Effort × CPUE)
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Effort target: sampled_days
#> 
#> # A tibble: 1 × 5
#>   estimate    se ci_lower ci_upper     n
#>      <dbl> <dbl>    <dbl>    <dbl> <int>
#> 1     283.  46.0     192.     373.    40
```

## Summary

The table below contrasts the two camera sub-modes:

| Feature | Counter mode | Ingress-egress mode |
|:---|:---|:---|
| Input data | One count per day | POSIXct arrival/departure pairs |
| Preprocessing step | None (counts used directly) | preprocess_camera_timestamps() |
| Effort unit | Daily ingress count | Daily effort-hours |
| Gap handling | Exclude camera_status != ‘operational’ rows | Negative durations warned and excluded |
| camera_mode value | “counter” | “ingress_egress” |

Comparison of camera survey sub-modes in tidycreel {.table}

Both sub-modes feed into the same
[`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md),
[`add_interviews()`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md),
[`estimate_catch_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_catch_rate.md),
and
[`estimate_total_catch()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_catch.md)
pipeline — no changes to downstream code are required when switching
modes.

## References

- Jones, C. M., & Pollock, K. H. (2012). Recreational survey methods:
  estimation of effort, harvest, and abundance. Chapter 19 in *Fisheries
  Techniques* (3rd ed.), pp. 883-919. American Fisheries Society.

- Malvestuto, S. P. (1996). Sampling the recreational angler. Chapter 20
  in *Fisheries Techniques* (2nd ed.), pp. 591-623. American Fisheries
  Society.
