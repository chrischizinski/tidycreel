# Compare multiple survey design estimates side by side

Takes a named list of `creel_estimates` objects (from different survey
designs or methods), extracts key precision metrics from each, and
returns a tidy comparison tibble. An `autoplot()` method renders a
forest plot of point estimates with confidence intervals.

## Usage

``` r
compare_designs(designs, metric = "estimate")
```

## Arguments

- designs:

  Named list of `creel_estimates` objects. Names become the `design`
  column in the output. At least two elements are required.

- metric:

  Character scalar. Which estimate column to compare. Default
  `"estimate"`. Must be a column present in every `estimates` data
  frame.

## Value

A `creel_design_comparison` object – a data frame with columns:

- `design`:

  Design name (from `names(designs)`).

- `estimate`:

  Point estimate.

- `se`:

  Standard error.

- `rse`:

  Relative standard error (`se / |estimate|`).

- `ci_lower`:

  Lower confidence interval bound.

- `ci_upper`:

  Upper confidence interval bound.

- `ci_width`:

  Width of the confidence interval.

- `n`:

  Sample size (if present in the estimates frame).

Group columns are retained when all designs share the same by-variable
structure.

## See also

[`autoplot.creel_design_comparison()`](https://chrischizinski.github.io/tidycreel/reference/autoplot.creel_design_comparison.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Compare instantaneous vs bus-route effort estimates from two designs
est1 <- estimate_effort(design_a)
est2 <- estimate_effort(design_b)
compare_designs(list(instantaneous = est1, bus_route = est2))
} # }
```
