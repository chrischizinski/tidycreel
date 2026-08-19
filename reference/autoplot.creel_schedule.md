# Plot a creel schedule as a ggplot2 tile calendar

`autoplot.creel_schedule()` produces a monthly tile calendar showing
sampled dates coloured by day type (weekday / weekend) and unsampled
dates in grey. Multiple months are shown as faceted panels.

Requires the **ggplot2** package (listed in `Suggests`). Install it with
`install.packages("ggplot2")` if needed.

## Usage

``` r
# S3 method for class 'creel_schedule'
autoplot(object, title = "Creel Schedule", ...)
```

## Arguments

- object:

  A `creel_schedule` object from
  [`generate_schedule()`](https://chrischizinski.github.io/tidycreel/reference/generate_schedule.md)
  or
  [`generate_bus_schedule()`](https://chrischizinski.github.io/tidycreel/reference/generate_bus_schedule.md).

- title:

  Optional character string for the plot title. Defaults to
  `"Creel Schedule"`.

- ...:

  Additional arguments (currently unused).

## Value

A `ggplot` object.

## See also

[`generate_schedule()`](https://chrischizinski.github.io/tidycreel/reference/generate_schedule.md),
[`print.creel_schedule()`](https://chrischizinski.github.io/tidycreel/reference/print.creel_schedule.md),
[`write_schedule()`](https://chrischizinski.github.io/tidycreel/reference/write_schedule.md)

Other "Visualisation":
[`autoplot.creel_estimates()`](https://chrischizinski.github.io/tidycreel/reference/autoplot.creel_estimates.md),
[`autoplot.creel_length_distribution()`](https://chrischizinski.github.io/tidycreel/reference/autoplot.creel_length_distribution.md),
[`creel_palette()`](https://chrischizinski.github.io/tidycreel/reference/creel_palette.md),
[`plot_design()`](https://chrischizinski.github.io/tidycreel/reference/plot_design.md),
[`theme_creel()`](https://chrischizinski.github.io/tidycreel/reference/theme_creel.md)

## Examples

``` r
if (FALSE) { # \dontrun{
sched <- generate_schedule(
  start_date = "2024-06-01", end_date = "2024-07-31",
  n_periods = 1,
  sampling_rate = c(weekday = 0.3, weekend = 0.6),
  seed = 42
)
ggplot2::autoplot(sched)
} # }
```
