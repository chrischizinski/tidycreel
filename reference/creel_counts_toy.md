# Toy count data for data validation examples

A small creel count data frame designed for demonstrating
[`validate_creel_data()`](https://chrischizinski.github.io/tidycreel/reference/validate_creel_data.md)
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

[creel_interviews_toy](https://chrischizinski.github.io/tidycreel/reference/creel_interviews_toy.md)

## Examples

``` r
data(creel_counts_toy)
if (FALSE) { # \dontrun{
validate_creel_data(counts = creel_counts_toy)
} # }
```
