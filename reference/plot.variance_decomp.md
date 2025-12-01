# Plot Method for Variance Decomposition Results

Creates visualizations of variance components, design effects, and
optimal allocation recommendations.

## Usage

``` r
# S3 method for class 'variance_decomp'
plot(x, type = "components", ...)
```

## Arguments

- x:

  A variance_decomp object from
  [`decompose_variance`](decompose_variance.md)

- type:

  Type of plot to create. Options:

  "components"

  :   Bar plot of variance components (default)

  "proportions"

  :   Pie chart of variance proportions

  "design_effects"

  :   Plot of design effects by clustering level

  "icc"

  :   Plot of intraclass correlations

  "all"

  :   Multiple plots in a grid

- ...:

  Additional arguments passed to ggplot2 functions

## Value

A ggplot2 object or list of ggplot2 objects (if type = "all")

## Examples

``` r
if (FALSE) { # \dontrun{
# Create variance decomposition
var_decomp <- decompose_variance(design, ~anglers_count)

# Plot variance components
plot(var_decomp, type = "components")

# Plot proportions
plot(var_decomp, type = "proportions")

# All plots
plots <- plot(var_decomp, type = "all")
} # }
```
