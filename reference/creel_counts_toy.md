# Toy count data for data validation examples

A small creel count data frame designed for demonstrating
[`validate_creel_data()`](https://chrischizinski.com/tidycreel/reference/validate_creel_data.md)
and related data-cleaning functions. Contains an intentional `NA` in the
`count` column to trigger the NA-rate check.

## Usage

``` r
creel_counts_toy
```

## Format

A data frame with 6 rows and 4 columns:

- date:

  Survey date (Date class).

- day_type:

  Day type stratum: `"weekday"` or `"weekend"`.

- section:

  Survey section: `"A"` or `"B"`.

- count:

  Instantaneous angler count; one row is intentionally `NA`.

## Source

Simulated data for package examples and vignettes.

## See also

[creel_interviews_toy](https://chrischizinski.com/tidycreel/reference/creel_interviews_toy.md)

Other "Example Datasets":
[`creel_interviews_toy`](https://chrischizinski.com/tidycreel/reference/creel_interviews_toy.md),
[`example_aerial_counts`](https://chrischizinski.com/tidycreel/reference/example_aerial_counts.md),
[`example_aerial_glmm_counts`](https://chrischizinski.com/tidycreel/reference/example_aerial_glmm_counts.md),
[`example_aerial_interviews`](https://chrischizinski.com/tidycreel/reference/example_aerial_interviews.md),
[`example_ages`](https://chrischizinski.com/tidycreel/reference/example_ages.md),
[`example_calendar`](https://chrischizinski.com/tidycreel/reference/example_calendar.md),
[`example_camera_counts`](https://chrischizinski.com/tidycreel/reference/example_camera_counts.md),
[`example_camera_interviews`](https://chrischizinski.com/tidycreel/reference/example_camera_interviews.md),
[`example_camera_timestamps`](https://chrischizinski.com/tidycreel/reference/example_camera_timestamps.md),
[`example_catch`](https://chrischizinski.com/tidycreel/reference/example_catch.md),
[`example_counts`](https://chrischizinski.com/tidycreel/reference/example_counts.md),
[`example_ice_interviews`](https://chrischizinski.com/tidycreel/reference/example_ice_interviews.md),
[`example_ice_sampling_frame`](https://chrischizinski.com/tidycreel/reference/example_ice_sampling_frame.md),
[`example_interviews`](https://chrischizinski.com/tidycreel/reference/example_interviews.md),
[`example_lengths`](https://chrischizinski.com/tidycreel/reference/example_lengths.md),
[`example_sections_calendar`](https://chrischizinski.com/tidycreel/reference/example_sections_calendar.md),
[`example_sections_counts`](https://chrischizinski.com/tidycreel/reference/example_sections_counts.md),
[`example_sections_interviews`](https://chrischizinski.com/tidycreel/reference/example_sections_interviews.md)

## Examples

``` r
data(creel_counts_toy)
validate_creel_data(counts = creel_counts_toy)
#> 
#> ── Creel Data Validation ───────────────────────────────────────────────────────
#> 11 pass | 1 warn | 0 fail
#> 
#> 
#> ── Table: counts ──
#> 
#> ✔ date
#> ✔ type: class: Date
#> ✔ na_rate: 0 / 6 NA (0%)
#> ✔ date_range: all within 1970-01-01 - 2100-12-31
#> ✔ day_type
#> ✔ type: class: character
#> ✔ na_rate: 0 / 6 NA (0%)
#> ✔ empty_strings: none
#> ✔ section
#> ✔ type: class: character
#> ✔ na_rate: 0 / 6 NA (0%)
#> ✔ empty_strings: none
#> ! count
#> ✔ type: class: integer
#> ⚠ na_rate: 1 / 6 NA (17%)
#> ✔ negative_values: none
#> 
```
