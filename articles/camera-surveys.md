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

In both modes, use the `camera_status` column to identify failures.
Unlike random missed observations (modeled via `missing_sections`), a
camera failure leaves an **informative gap**: the number of anglers that
passed during the outage is unknown and cannot be estimated from nearby
observations. Remove these rows before calling
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

Camera effort is estimated by
[`est_effort_camera()`](https://chrischizinski.github.io/tidycreel/reference/est_effort_camera.md),
not by the generic
[`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md).
The distinction matters and is not cosmetic: a camera count is a daily
total of **arrivals**, not an instantaneous count of anglers present, so
summing it over days gives arrivals rather than effort. The generic
estimator refuses a camera design for that reason:

``` r

design_counter <- add_counts(design_counter, counts_clean)
#> Warning in svydesign.default(ids = psu_formula, strata = strata_formula, : No
#> weights or probabilities supplied, assuming equal probability
estimate_effort(design_counter)
#> Error in `estimate_effort()`:
#> ! `estimate_effort()` does not estimate camera designs.
#> ✖ A camera count is a daily ingress total -- a count of arrivals -- not an
#>   instantaneous count of anglers present, so summing it over days gives
#>   arrivals rather than effort.
#> ℹ Use `est_effort_camera()`, which calibrates the counts against interview
#>   effort and propagates the calibration's uncertainty.
#> ℹ To expand the raw counts uncalibrated, pass `calibration = "none"` and
#>   `h_open` to that function. The reported standard error is `NA`, because the
#>   assumption of one angler-hour per count per hour open is unmeasured.
```

[`est_effort_camera()`](https://chrischizinski.github.io/tidycreel/reference/est_effort_camera.md)
converts counts to effort by calibrating them against interview data:
for each stratum it estimates `rho`, the hours of effort per camera
count, from the days that carry both a count and interviews, then
applies it to that stratum’s total counts (Hartill et al. 2020).

`example_camera_interviews` records one row per angler, so
`n_anglers = 1` states that `hours_fished` is already an individual
angler’s hours. Supplying it is what earns the result its `angler-hours`
label — without it the ratio inherits whatever unit the effort column
holds, which the package cannot identify, and the unit is reported as
unknown.

``` r

effort_counter <- suppressWarnings(est_effort_camera(
  design_counter,
  interviews = example_camera_interviews,
  n_anglers  = 1
))
print(effort_counter)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: camera_ratio
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Unit: angler-hours
#> Count-sampling SE: 4.277 (included in se)
#> Calibration SE: 11.71 (included in se)
#> 
#> # A tibble: 1 × 7
#>   estimate    se se_between se_within ci_lower ci_upper     n
#>      <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int>
#> 1     111.  12.5       12.5         0     81.4     140.     9
```

The `estimate` column is total angler-hours across the survey period.
The standard error carries two named components, which `se_components`
reports separately:

``` r

effort_counter$se_components
#> $count_sampling
#> [1] 4.277261
#> 
#> $calibration
#> [1] 11.70725
```

`count_sampling` is the sampling variance of the camera counts
themselves; `calibration` is the variance of the estimated `rho`.
Splitting them shows which half of the uncertainty dominates — here the
calibration ratio does, so more interview days would buy more precision
than more camera days would.

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
```

Ingress-egress counts are already in hours, so the calibration ratio
here is close to dimensionless: it corrects camera-measured hours to
interview-measured angler-hours rather than converting a count into a
duration. The estimator is the same one.

``` r

ie_interviews <- example_camera_interviews[
  example_camera_interviews$date %in% daily_effort$date,
]

effort_ie <- suppressWarnings(est_effort_camera(
  design_ie,
  interviews = ie_interviews,
  n_anglers  = 1
))
print(effort_ie)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: camera_ratio
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Unit: angler-hours
#> Count-sampling SE: 5.41 (known, but se is `NA`)
#> Calibration SE: NA (unknown, so se is `NA`)
#> 
#> # A tibble: 1 × 7
#>   estimate    se se_between se_within ci_lower ci_upper     n
#>      <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int>
#> 1     43.6    NA         NA         0       NA       NA     4
```

The standard error is `NA` here, and that is the estimator working
rather than failing. These four sampling days give the `weekend` stratum
only one day carrying both a count and interviews, and a single paired
day gives the calibration ratio no measurable spread. Reporting `0` for
that variance would present the most uncertain calibration as the most
precise one, so the package carries it as `NA` and says which stratum is
responsible. A second matched interview day in that stratum recovers a
standard error.

## Catch Estimation

Camera designs estimate **effort only**.
[`estimate_catch_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_catch_rate.md)
still works — a catch rate comes from the interviews and does not
involve the camera at all:

``` r

design_catch <- suppressMessages(add_interviews(
  design_counter,
  example_camera_interviews,
  catch       = walleye,
  effort      = hours_fished,
  trip_status = trip_status,
  n_anglers   = 1
))
#> Warning: 14 interviews have zero catch.
#> ℹ Zero catch may be valid (skunked) or indicate missing data.
catch_rate <- suppressWarnings(estimate_catch_rate(design_catch))
#> ℹ Using complete trips for CPUE estimation
#>   (n=40, 100% of 40 interviews) [default]
print(catch_rate)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Ratio-of-Means CPUE
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Unit: fish/angler-hour
#> 
#> # A tibble: 1 × 5
#>   estimate     se ci_lower ci_upper     n
#>      <dbl>  <dbl>    <dbl>    <dbl> <int>
#> 1    0.453 0.0755    0.305    0.601    40
```

A **total** catch is a different matter, and
[`estimate_total_catch()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_catch.md)
refuses a camera design:

``` r

estimate_total_catch(design_catch)
#> Error in `estimate_total_catch()`:
#> ! `estimate_total_catch()` does not estimate camera designs.
#> ✖ A camera count is a daily ingress total -- a count of arrivals -- not an
#>   instantaneous count of anglers present, so summing it over days gives
#>   arrivals rather than effort.
#> ℹ Camera designs estimate effort only. `est_effort_camera()` returns
#>   angler-hours; there is no camera catch estimator to multiply them by.
#> ℹ A total from this function would multiply a rate per angler-hour by a count
#>   of arrivals and report the product as fish.
```

A total is the product of a rate and an effort, and this function builds
its own effort by the generic route — the one that sums arrivals. It
would therefore multiply a rate per angler-hour by a count of arrivals
and report the product as fish. The number looked entirely plausible,
which is why this is refused rather than warned about.

There is no camera catch estimator to reach for instead.
[`est_effort_camera()`](https://chrischizinski.github.io/tidycreel/reference/est_effort_camera.md)
gives calibrated angler-hours, and multiplying those by the catch rate
above is arithmetic a reader can do deliberately — but the package will
not do it silently, because the standard error of that product needs the
calibration variance and the rate variance combined, and nothing here
does that yet.

[`estimate_total_harvest()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_harvest.md)
and
[`estimate_total_release()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_release.md)
refuse camera designs for the same reason.

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

Both sub-modes are estimated by the same function,
[`est_effort_camera()`](https://chrischizinski.github.io/tidycreel/reference/est_effort_camera.md),
so no changes to downstream code are required when switching between
them. Neither sub-mode goes through
[`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md),
which refuses camera designs, nor through
[`estimate_total_catch()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_catch.md),
[`estimate_total_harvest()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_harvest.md)
or
[`estimate_total_release()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_release.md),
which refuse them for the same reason.

## References

- Jones, C. M., & Pollock, K. H. (2012). Recreational survey methods:
  estimation of effort, harvest, and abundance. Chapter 19 in *Fisheries
  Techniques* (3rd ed.), pp. 883-919. American Fisheries Society.

- Malvestuto, S. P. (1996). Sampling the recreational angler. Chapter 20
  in *Fisheries Techniques* (2nd ed.), pp. 591-623. American Fisheries
  Society.
