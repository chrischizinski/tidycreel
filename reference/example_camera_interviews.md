# Example interview data for camera-monitored creel survey

Angler interview data for a summer creel survey at a camera-monitored
boat launch. Contains 40 interviews across 8 sampling days in June 2024,
targeting walleye and bass. All interviews are complete trips. Dates
match the date range in
[`example_camera_counts`](https://chrischizinski.github.io/tidycreel/reference/example_camera_counts.md).

## Usage

``` r
example_camera_interviews
```

## Format

A data frame with 40 rows and 8 variables:

- date:

  Interview date (Date class), June 2024.

- day_type:

  Day type stratum: `"weekday"` or `"weekend"`.

- trip_status:

  Trip completion status: `"complete"` for all 40 interviews.

- hours_fished:

  Numeric fishing effort in hours (range 0.5-5.0).

- walleye:

  Integer total walleye caught (kept + released).

- walleye_kept:

  Integer walleye harvested; always `<= walleye`.

- bass:

  Integer total bass caught (kept + released).

- bass_kept:

  Integer bass harvested; always `<= bass`.

## Source

Simulated for package documentation.

## See also

[example_camera_counts](https://chrischizinski.github.io/tidycreel/reference/example_camera_counts.md),
[example_camera_timestamps](https://chrischizinski.github.io/tidycreel/reference/example_camera_timestamps.md),
[`add_interviews()`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md),
[`estimate_catch_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_catch_rate.md),
[`estimate_total_catch()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_catch.md)

## Examples

``` r
data(example_camera_counts)
data(example_camera_interviews)

# Build a calendar that spans all camera dataset dates
cam_dates <- sort(unique(c(
  example_camera_counts$date,
  example_camera_interviews$date
)))
cam_cal <- data.frame(
  date = cam_dates,
  day_type = ifelse(
    weekdays(cam_dates) %in% c("Saturday", "Sunday"),
    "weekend", "weekday"
  ),
  stringsAsFactors = FALSE
)
design <- creel_design(
  cam_cal,
  date = date, strata = day_type,
  survey_type = "camera",
  camera_mode = "counter"
)
counts_clean <- subset(example_camera_counts, camera_status == "operational")
design <- suppressWarnings(add_counts(design, counts_clean))
design <- suppressWarnings(add_interviews(
  design, example_camera_interviews,
  catch = walleye, effort = hours_fished, trip_status = trip_status
))
#> ℹ No `n_anglers` provided — assuming 1 angler per interview.
#> ℹ Pass `n_anglers = <column>` to use actual party sizes for angler-hour
#>   normalization.
#> ℹ Added 40 interviews: 40 complete (100%), 0 incomplete (0%)
suppressWarnings(estimate_catch_rate(design))
#> ℹ Using complete trips for CPUE estimation
#>   (n=40, 100% of 40 interviews) [default]
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
