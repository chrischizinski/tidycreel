# Plot survey design structure

Visualize survey design by date, shift, location, stratum, or other
grouping variables. Supports bar plots, faceted plots, and interactive
plots (via plotly if available).

## Usage

``` r
plot_design(
  design,
  by = c("date", "shift_block", "location", "stratum"),
  type = c("bar", "facet", "interactive"),
  ...
)
```

## Arguments

- design:

  A creel_design object or data frame with survey structure.

- by:

  Character vector of grouping variables (e.g., date, shift_block,
  location, stratum).

- type:

  Plot type: "bar", "facet", "interactive".

- ...:

  Additional arguments passed to ggplot2 or plotly.

## Value

A ggplot or plotly object.

## Details

Visualizes survey design structure and effort estimates. Supports bar,
facet, and interactive plots. See vignettes for usage examples.

## References

Wickham, H. (2016). ggplot2: Elegant Graphics for Data Analysis.
Springer-Verlag New York.

## Examples

``` r
if (FALSE) { # \dontrun{
# Create a design first
design <- design_access(interviews, calendar)

# Plot survey design structure
plot_design(design, by = c("date", "shift_block"), type = "bar")
} # }
```
