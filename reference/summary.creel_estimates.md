# Summarise creel survey estimates as a formatted table

`summary.creel_estimates()` converts a `creel_estimates` object into a
`creel_summary` table with human-readable column names, suitable for
display or export.

## Usage

``` r
# S3 method for class 'creel_estimates'
summary(object, digits = 4L, ...)
```

## Arguments

- object:

  A `creel_estimates` object returned by
  [`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md),
  [`estimate_catch_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_catch_rate.md),
  [`estimate_harvest_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_harvest_rate.md),
  [`estimate_total_catch()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_catch.md),
  or
  [`estimate_total_harvest()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_harvest.md).

- digits:

  Integer number of significant digits for numeric columns (default: 4).

- ...:

  Additional arguments (currently ignored).

## Value

A `creel_summary` S3 object (a list) with components:

- table:

  A `data.frame` with columns: any grouping variables, `Estimate`, `SE`,
  `CI Lower`, `CI Upper`, `N`.

- method:

  Character string — the estimation method.

- variance_method:

  Character string — the variance method.

- conf_level:

  Numeric confidence level (e.g. 0.95).

## See also

[`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md),
[`estimate_catch_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_catch_rate.md),
[`estimate_harvest_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_harvest_rate.md)

## Examples

``` r
if (FALSE) { # \dontrun{
est <- estimate_effort(design)
summary(est)
as.data.frame(summary(est))
} # }
```
