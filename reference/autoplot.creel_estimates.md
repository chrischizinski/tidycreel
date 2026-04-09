# Plot creel survey estimates with ggplot2

`autoplot.creel_estimates()` produces a point-and-errorbar plot from a
`creel_estimates` object. For ungrouped estimates a single point with
confidence interval is shown. For grouped estimates (when `by` was
supplied to the estimation function) each group level gets its own
point, colour-coded and positioned along the x-axis.

Requires the **ggplot2** package (listed in `Suggests`). Install it with
`install.packages("ggplot2")` if needed.

## Usage

``` r
# S3 method for class 'creel_estimates'
autoplot(object, title = NULL, ...)
```

## Arguments

- object:

  A `creel_estimates` object.

- title:

  Optional character string for the plot title. Defaults to a
  human-readable description of the estimation method.

- ...:

  Additional arguments (currently unused).

## Value

A `ggplot` object.

## See also

[`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md),
[`estimate_catch_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_catch_rate.md),
[`summary.creel_estimates()`](https://chrischizinski.github.io/tidycreel/reference/summary.creel_estimates.md)

## Examples

``` r
if (FALSE) { # \dontrun{
est <- estimate_effort(design)
ggplot2::autoplot(est)

est_grp <- estimate_effort(design, by = day_type)
ggplot2::autoplot(est_grp)
} # }
```
