# Example camera counts dataset (counter mode)

A dataset of daily ingress counts from a remote camera at a boat launch.
Contains 10 rows covering non-consecutive sampling days in June 2024.
Includes one row with `camera_status = "battery_failure"` and
`ingress_count = NA` demonstrating informative gap handling.

## Usage

``` r
example_camera_counts
```

## Format

A data frame with 10 rows and 4 variables:

- date:

  Survey date (Date class), non-consecutive days in June 2024.

- day_type:

  Day type stratum: `"weekday"` or `"weekend"`.

- ingress_count:

  Daily ingress angler count (integer). `NA` when the camera was not
  operational.

- camera_status:

  Camera operational status. One of `"operational"`,
  `"battery_failure"`, `"memory_full"`, or `"occlusion"`.

## Source

Simulated for package documentation.

## See also

[example_camera_timestamps](https://chrischizinski.github.io/tidycreel/reference/example_camera_timestamps.md),
[example_camera_interviews](https://chrischizinski.github.io/tidycreel/reference/example_camera_interviews.md),
[`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md),
[`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)

Other "Example Datasets":
[`creel_counts_toy`](https://chrischizinski.github.io/tidycreel/reference/creel_counts_toy.md),
[`creel_interviews_toy`](https://chrischizinski.github.io/tidycreel/reference/creel_interviews_toy.md),
[`example_aerial_counts`](https://chrischizinski.github.io/tidycreel/reference/example_aerial_counts.md),
[`example_aerial_glmm_counts`](https://chrischizinski.github.io/tidycreel/reference/example_aerial_glmm_counts.md),
[`example_aerial_interviews`](https://chrischizinski.github.io/tidycreel/reference/example_aerial_interviews.md),
[`example_calendar`](https://chrischizinski.github.io/tidycreel/reference/example_calendar.md),
[`example_camera_interviews`](https://chrischizinski.github.io/tidycreel/reference/example_camera_interviews.md),
[`example_camera_timestamps`](https://chrischizinski.github.io/tidycreel/reference/example_camera_timestamps.md),
[`example_catch`](https://chrischizinski.github.io/tidycreel/reference/example_catch.md),
[`example_counts`](https://chrischizinski.github.io/tidycreel/reference/example_counts.md),
[`example_ice_interviews`](https://chrischizinski.github.io/tidycreel/reference/example_ice_interviews.md),
[`example_ice_sampling_frame`](https://chrischizinski.github.io/tidycreel/reference/example_ice_sampling_frame.md),
[`example_interviews`](https://chrischizinski.github.io/tidycreel/reference/example_interviews.md),
[`example_lengths`](https://chrischizinski.github.io/tidycreel/reference/example_lengths.md),
[`example_sections_calendar`](https://chrischizinski.github.io/tidycreel/reference/example_sections_calendar.md),
[`example_sections_counts`](https://chrischizinski.github.io/tidycreel/reference/example_sections_counts.md),
[`example_sections_interviews`](https://chrischizinski.github.io/tidycreel/reference/example_sections_interviews.md)

## Examples

``` r
data(example_camera_counts)
head(example_camera_counts)
#>         date day_type ingress_count camera_status
#> 1 2024-06-03  weekday            48   operational
#> 2 2024-06-04  weekday            55   operational
#> 3 2024-06-05  weekday            43   operational
#> 4 2024-06-07  weekend            91   operational
#> 5 2024-06-08  weekend            85   operational
#> 6 2024-06-10  weekday            50   operational

# Filter to operational rows before adding to a camera design
data(example_calendar)
design <- creel_design(
  example_calendar,
  date = date, strata = day_type,
  survey_type = "camera",
  camera_mode = "counter"
)
counts_clean <- subset(example_camera_counts, camera_status == "operational")
design <- suppressWarnings(add_counts(design, counts_clean))
```
