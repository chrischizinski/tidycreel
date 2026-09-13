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
  [`creel_design()`](https://chrischizinski.com/tidycreel/reference/creel_design.md).

- title:

  Optional character title. Defaults to `"Creel Design Summary"` (no
  counts) or `"Count Distribution by Stratum"` (with counts).

- ...:

  Additional arguments (currently ignored).

## Value

A `ggplot` object.

## See also

[`creel_design()`](https://chrischizinski.com/tidycreel/reference/creel_design.md),
[`autoplot.creel_schedule()`](https://chrischizinski.com/tidycreel/reference/autoplot.creel_schedule.md)

Other "Visualisation":
[`autoplot.creel_estimates()`](https://chrischizinski.com/tidycreel/reference/autoplot.creel_estimates.md),
[`autoplot.creel_length_distribution()`](https://chrischizinski.com/tidycreel/reference/autoplot.creel_length_distribution.md),
[`autoplot.creel_schedule()`](https://chrischizinski.com/tidycreel/reference/autoplot.creel_schedule.md),
[`creel_palette()`](https://chrischizinski.com/tidycreel/reference/creel_palette.md),
[`theme_creel()`](https://chrischizinski.com/tidycreel/reference/theme_creel.md)

## Examples

``` r
data(example_calendar)
data(example_counts)

# Without counts — stratum sample sizes
design <- creel_design(example_calendar, date = date, strata = day_type)
plot_design(design)


# With counts — count distribution per stratum
design_with_counts <- add_counts(design, example_counts)
#> Warning: No weights or probabilities supplied, assuming equal probability
plot_design(design_with_counts)
#> Warning: Computation failed in `stat_summary()`.
#> Caused by error in `fun.data()`:
#> ! The package "Hmisc" is required.

```
