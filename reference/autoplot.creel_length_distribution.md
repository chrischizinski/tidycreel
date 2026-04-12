# Plot a weighted length distribution with ggplot2

`autoplot.creel_length_distribution()` renders weighted length-frequency
estimates as a histogram-style bar chart. Ungrouped results are shown as
a single distribution; grouped results are faceted by the grouping
variables.

## Usage

``` r
# S3 method for class 'creel_length_distribution'
autoplot(object, title = NULL, theme = c("default", "creel"), ...)
```

## Arguments

- object:

  A `creel_length_distribution` object returned by
  [`est_length_distribution()`](https://chrischizinski.github.io/tidycreel/reference/est_length_distribution.md).

- title:

  Optional plot title. Defaults to a title derived from the estimated
  fish type (`catch`, `harvest`, or `release`).

- theme:

  Character string selecting the plot theme. Use `"default"` (default)
  to preserve the current ggplot styling or `"creel"` to apply
  [`theme_creel()`](https://chrischizinski.github.io/tidycreel/reference/theme_creel.md)
  and package-standard colours.

- ...:

  Additional arguments (currently unused).

## Value

A `ggplot` object.

## See also

[`est_length_distribution()`](https://chrischizinski.github.io/tidycreel/reference/est_length_distribution.md)

## Examples

``` r
if (FALSE) { # \dontrun{
ld <- est_length_distribution(design, by = species, bin_width = 25)
ggplot2::autoplot(ld)
} # }
```
