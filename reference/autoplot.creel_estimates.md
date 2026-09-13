# Plot creel survey estimates with ggplot2

`autoplot.creel_estimates()` produces a point-and-errorbar plot from a
`creel_estimates` object. For ungrouped estimates a single point with
confidence interval is shown. For grouped estimates (when `by` was
supplied to the estimation function) each group level gets its own
point, colour-coded and positioned along the x-axis.

Returns a **ggplot2** object, which the package imports, so nothing
extra needs installing.

## Usage

``` r
# S3 method for class 'creel_estimates'
autoplot(object, title = NULL, theme = c("default", "creel"), ...)
```

## Arguments

- object:

  A `creel_estimates` object.

- title:

  Optional character string for the plot title. Defaults to a
  human-readable description of the estimation method.

- theme:

  Character string selecting the plot theme. Use `"default"` (default)
  for
  [`ggplot2::theme_bw()`](https://ggplot2.tidyverse.org/reference/ggtheme.html),
  or `"creel"` for
  [`theme_creel()`](https://chrischizinski.com/tidycreel/reference/theme_creel.md)
  and package-standard colours. Neither inherits a theme set with
  [`ggplot2::theme_set()`](https://ggplot2.tidyverse.org/reference/get_theme.html);
  add your own with `+` if you need it.

- ...:

  Additional arguments (currently unused).

## Value

A `ggplot` object.

## See also

[`estimate_effort()`](https://chrischizinski.com/tidycreel/reference/estimate_effort.md),
[`estimate_catch_rate()`](https://chrischizinski.com/tidycreel/reference/estimate_catch_rate.md),
[`summary.creel_estimates()`](https://chrischizinski.com/tidycreel/reference/summary.creel_estimates.md)

Other "Visualisation":
[`autoplot.creel_length_distribution()`](https://chrischizinski.com/tidycreel/reference/autoplot.creel_length_distribution.md),
[`autoplot.creel_schedule()`](https://chrischizinski.com/tidycreel/reference/autoplot.creel_schedule.md),
[`creel_palette()`](https://chrischizinski.com/tidycreel/reference/creel_palette.md),
[`plot_design()`](https://chrischizinski.com/tidycreel/reference/plot_design.md),
[`theme_creel()`](https://chrischizinski.com/tidycreel/reference/theme_creel.md)

## Examples

``` r
data(example_calendar)
data(example_counts)
data(example_interviews)

design <- creel_design(example_calendar, date = date, strata = day_type)
design <- add_counts(design, example_counts)
#> Warning: No weights or probabilities supplied, assuming equal probability
design <- add_interviews(design, example_interviews,
  catch = catch_total, effort = hours_fished, harvest = catch_kept,
  trip_status = trip_status
)
#> Warning: ! No `n_anglers` provided — assuming 1 angler per interview.
#> ℹ Pass `n_anglers = <column>` to use actual party sizes for angler-hour
#>   normalization.
#> ℹ If the interviews really are one angler each, pass `n_anglers = 1` to state
#>   that and silence this warning.
#> ℹ Added 22 interviews: 17 complete (77%), 5 incomplete (23%)

est <- estimate_effort(design)
#> Warning: Instantaneous counts were expanded without a period length.
#> ℹ No `period_length_col` was supplied to `add_counts()`, so the estimate is the
#>   count column summed over days.
#> ! If that column holds an instantaneous angler count, the result is in
#>   angler-days, not angler-hours.
#> ℹ Supply the period each count was randomised within: `add_counts(design,
#>   counts, period_length_col = <col>)`.
#> This warning is displayed once per session.
ggplot2::autoplot(est)


est_grp <- estimate_effort(design, by = day_type)
ggplot2::autoplot(est_grp)

```
