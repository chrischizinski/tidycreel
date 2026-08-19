# Plot a creel survey design

Produces a quick visual summary of a `creel_design` object:

- **Without counts attached** (`design$counts` is `NULL`): a bar chart
  showing the number of sampled days per stratum.

- **With counts attached**: a jitter + crossbar chart showing the
  distribution of count values per stratum.

Both variants colour bars/points by stratum for easy differentiation.

## Usage

``` r
plot_design(design, title = NULL, ...)
```

## Arguments

- design:

  A `creel_design` object created by
  [`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md).

- title:

  Optional character title. Defaults to `"Creel Design Summary"` (no
  counts) or `"Count Distribution by Stratum"` (with counts).

- ...:

  Additional arguments (currently ignored).

## Value

A `ggplot` object.

## See also

[`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md),
[`autoplot.creel_schedule()`](https://chrischizinski.github.io/tidycreel/reference/autoplot.creel_schedule.md)

Other "Visualisation":
[`autoplot.creel_estimates()`](https://chrischizinski.github.io/tidycreel/reference/autoplot.creel_estimates.md),
[`autoplot.creel_length_distribution()`](https://chrischizinski.github.io/tidycreel/reference/autoplot.creel_length_distribution.md),
[`autoplot.creel_schedule()`](https://chrischizinski.github.io/tidycreel/reference/autoplot.creel_schedule.md),
[`creel_palette()`](https://chrischizinski.github.io/tidycreel/reference/creel_palette.md),
[`theme_creel()`](https://chrischizinski.github.io/tidycreel/reference/theme_creel.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Without counts — stratum sample sizes
cal <- data.frame(
  date = as.Date(c(
    "2024-06-01", "2024-06-02", "2024-06-08", "2024-06-09"
  )),
  day_type = c("weekday", "weekday", "weekend", "weekend")
)
design <- creel_design(cal, date = date, strata = day_type)
plot_design(design)

# With counts — count distribution per stratum
design_with_counts <- add_counts(design, counts_df)
plot_design(design_with_counts)
} # }
```
