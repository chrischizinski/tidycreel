# Example effort counts for spatially stratified creel survey

Instantaneous count observations for a 3-section lake (North, Central,
South) covering 12 survey dates. Each section has one count row per date
(36 rows total). Effort varies materially by section: Central has the
highest angler traffic, South the lowest. Use with
[`add_sections()`](https://chrischizinski.github.io/tidycreel/reference/add_sections.md)
and
[`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md).

## Usage

``` r
example_sections_counts
```

## Format

A data frame with 36 rows and 4 columns:

- date:

  Survey date (Date class), matching
  [example_sections_calendar](https://chrischizinski.github.io/tidycreel/reference/example_sections_calendar.md)

- day_type:

  Day type stratum: `"weekday"` or `"weekend"`

- section:

  Section identifier: `"North"`, `"Central"`, or `"South"`

- effort_hours:

  Numeric instantaneous count of angler-hours observed

## Source

Simulated data for package examples

## See also

[example_sections_calendar](https://chrischizinski.github.io/tidycreel/reference/example_sections_calendar.md),
[example_sections_interviews](https://chrischizinski.github.io/tidycreel/reference/example_sections_interviews.md),
[`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md),
[`add_sections()`](https://chrischizinski.github.io/tidycreel/reference/add_sections.md),
[`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md)

Other "Example Datasets":
[`creel_counts_toy`](https://chrischizinski.github.io/tidycreel/reference/creel_counts_toy.md),
[`creel_interviews_toy`](https://chrischizinski.github.io/tidycreel/reference/creel_interviews_toy.md),
[`example_aerial_counts`](https://chrischizinski.github.io/tidycreel/reference/example_aerial_counts.md),
[`example_aerial_glmm_counts`](https://chrischizinski.github.io/tidycreel/reference/example_aerial_glmm_counts.md),
[`example_aerial_interviews`](https://chrischizinski.github.io/tidycreel/reference/example_aerial_interviews.md),
[`example_calendar`](https://chrischizinski.github.io/tidycreel/reference/example_calendar.md),
[`example_camera_counts`](https://chrischizinski.github.io/tidycreel/reference/example_camera_counts.md),
[`example_camera_interviews`](https://chrischizinski.github.io/tidycreel/reference/example_camera_interviews.md),
[`example_camera_timestamps`](https://chrischizinski.github.io/tidycreel/reference/example_camera_timestamps.md),
[`example_catch`](https://chrischizinski.github.io/tidycreel/reference/example_catch.md),
[`example_counts`](https://chrischizinski.github.io/tidycreel/reference/example_counts.md),
[`example_ice_interviews`](https://chrischizinski.github.io/tidycreel/reference/example_ice_interviews.md),
[`example_ice_sampling_frame`](https://chrischizinski.github.io/tidycreel/reference/example_ice_sampling_frame.md),
[`example_interviews`](https://chrischizinski.github.io/tidycreel/reference/example_interviews.md),
[`example_lengths`](https://chrischizinski.github.io/tidycreel/reference/example_lengths.md),
[`example_sections_calendar`](https://chrischizinski.github.io/tidycreel/reference/example_sections_calendar.md),
[`example_sections_interviews`](https://chrischizinski.github.io/tidycreel/reference/example_sections_interviews.md)

## Examples

``` r
data(example_sections_calendar)
data(example_sections_counts)

sections_df <- data.frame(
  section = c("North", "Central", "South"),
  stringsAsFactors = FALSE
)
design <- creel_design(example_sections_calendar, date = date, strata = day_type)
design <- add_sections(design, sections_df, section_col = section)
design <- suppressWarnings(add_counts(design, example_sections_counts))
estimate_effort(design)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: total-sections
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Effort target: sampled_days
#> 
#> # A tibble: 4 × 10
#>   section     estimate    se se_between se_within ci_lower ci_upper     n
#>   <chr>          <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int>
#> 1 North            269 12.3       12.3          0    242.      296.    12
#> 2 Central          472 19.0       19.0          0    430.      514.    12
#> 3 South            105  9.18       9.18         0     84.6     125.    12
#> 4 .lake_total      846 39.4       NA           NA    758.      934.    36
#> # ℹ 2 more variables: prop_of_lake_total <dbl>, data_available <lgl>
```
