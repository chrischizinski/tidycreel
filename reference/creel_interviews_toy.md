# Toy interview data for data validation examples

A small creel interview data frame with intentional data quality issues
for demonstrating
[`validate_creel_data()`](https://chrischizinski.com/tidycreel/reference/validate_creel_data.md)
and
[`standardize_species()`](https://chrischizinski.com/tidycreel/reference/standardize_species.md).
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
  [`standardize_species()`](https://chrischizinski.com/tidycreel/reference/standardize_species.md)
  behaviour.

- fish_kept:

  Number of fish kept; one row is intentionally negative.

- trip_hours:

  Trip duration in hours; one row is intentionally `NA`.

## Source

Simulated data for package examples and vignettes.

## See also

[creel_counts_toy](https://chrischizinski.com/tidycreel/reference/creel_counts_toy.md)

Other "Example Datasets":
[`creel_counts_toy`](https://chrischizinski.com/tidycreel/reference/creel_counts_toy.md),
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
data(creel_interviews_toy)
validate_creel_data(interviews = creel_interviews_toy)
#> 
#> ── Creel Data Validation ───────────────────────────────────────────────────────
#> 12 pass | 2 warn | 1 fail
#> 
#> 
#> ── Table: interviews ──
#> 
#> ✔ date
#> ✔ type: class: Date
#> ✔ na_rate: 0 / 6 NA (0%)
#> ✔ date_range: all within 1970-01-01 - 2100-12-31
#> ✔ day_type
#> ✔ type: class: character
#> ✔ na_rate: 0 / 6 NA (0%)
#> ✔ empty_strings: none
#> ! species
#> ✔ type: class: character
#> ✔ na_rate: 0 / 6 NA (0%)
#> ⚠ empty_strings: 1 empty string(s)
#> ✖ fish_kept
#> ✔ type: class: integer
#> ✔ na_rate: 0 / 6 NA (0%)
#> ✖ negative_values: 1 negative value(s)
#> ! trip_hours
#> ✔ type: class: numeric
#> ⚠ na_rate: 1 / 6 NA (17%)
#> ✔ negative_values: none
#> 
standardize_species(creel_interviews_toy, species_col = "species")
#> Warning: 2 species value(s) could not be matched to an
#> AFS code and will be "NA":
#> • ""
#> • "UNKNOWN FISH"
#>         date day_type         species fish_kept trip_hours species_code
#> 1 2024-06-01  weekday         walleye         2        3.5          WAE
#> 2 2024-06-01  weekday Largemouth Bass         0        2.0          LMB
#> 3 2024-06-02  weekend                         1         NA         <NA>
#> 4 2024-06-03  weekday        bluegill        -1        4.0          BLG
#> 5 2024-06-08  weekend   northern pike         3        1.5          NOP
#> 6 2024-06-09  weekday    UNKNOWN FISH         0        6.0         <NA>
```
