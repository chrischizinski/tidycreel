# Toy interview data for data validation examples

A small creel interview data frame with intentional data quality issues
for demonstrating
[`validate_creel_data()`](https://chrischizinski.github.io/tidycreel/reference/validate_creel_data.md)
and
[`standardize_species()`](https://chrischizinski.github.io/tidycreel/reference/standardize_species.md).
Includes an empty species string, a negative `fish_kept` value, and a
missing `trip_hours` value.

## Usage

``` r
creel_interviews_toy
```

## Format

A data frame with 6 rows and 5 columns:

- date:

  Interview date (Date class).

- day_type:

  Day type stratum: `"weekday"` or `"weekend"`.

- species:

  Free-text species name; includes empty string and unrecognised value
  to demonstrate
  [`standardize_species()`](https://chrischizinski.github.io/tidycreel/reference/standardize_species.md)
  behaviour.

- fish_kept:

  Number of fish kept; one row is intentionally negative.

- trip_hours:

  Trip duration in hours; one row is intentionally `NA`.

## Source

Simulated data for package examples and vignettes.

## See also

[creel_counts_toy](https://chrischizinski.github.io/tidycreel/reference/creel_counts_toy.md)

Other "Example Datasets":
[`creel_counts_toy`](https://chrischizinski.github.io/tidycreel/reference/creel_counts_toy.md),
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
[`example_sections_counts`](https://chrischizinski.github.io/tidycreel/reference/example_sections_counts.md),
[`example_sections_interviews`](https://chrischizinski.github.io/tidycreel/reference/example_sections_interviews.md)

## Examples

``` r
data(creel_interviews_toy)
if (FALSE) { # \dontrun{
validate_creel_data(interviews = creel_interviews_toy)
standardize_species(creel_interviews_toy, species_col = "species")
} # }
```
