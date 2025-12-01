# Plot effort estimates

Visualize effort estimates by stratum, date, location, or other grouping
variables. Supports line, bar, and interactive plots.

## Usage

``` r
plot_effort(
  effort_df,
  by = c("date", "location", "stratum"),
  type = c("line", "bar", "interactive"),
  ...
)
```

## Arguments

- effort_df:

  Data frame/tibble of effort estimates (output from est_effort or
  similar).

- by:

  Character vector of grouping variables.

- type:

  Plot type: "line", "bar", "interactive".

- ...:

  Additional arguments passed to ggplot2 or plotly.

## Value

A ggplot or plotly object.

## Details

Visualizes effort estimates by stratum, date, location, or other
grouping variables. Supports line, bar, and interactive plots. See
vignettes for usage examples.

## References

Wickham, H. (2016). ggplot2: Elegant Graphics for Data Analysis.
Springer-Verlag New York.

## Examples

``` r
if (FALSE) { # \dontrun{
# First estimate effort
effort_est <- est_effort(design, counts, by = c("date", "location"))

# Plot effort estimates
plot_effort(effort_est, by = c("date", "location"), type = "line")
} # }
```
