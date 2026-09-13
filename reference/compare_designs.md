# Compare multiple survey design estimates side by side

**\[experimental\]**

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

## Details

Takes a named list of `creel_estimates` objects (from different survey
designs or methods), extracts key precision metrics from each, and
returns a tidy comparison tibble. An `autoplot()` method renders a
forest plot of point estimates with confidence intervals.

## See also

[`autoplot.creel_design_comparison()`](https://chrischizinski.com/tidycreel/reference/autoplot.creel_design_comparison.md)

Other "Planning & Sample Size":
[`audit_strata()`](https://chrischizinski.com/tidycreel/reference/audit_strata.md),
[`creel_n_camera()`](https://chrischizinski.com/tidycreel/reference/creel_n_camera.md),
[`creel_n_cpue()`](https://chrischizinski.com/tidycreel/reference/creel_n_cpue.md),
[`creel_n_effort()`](https://chrischizinski.com/tidycreel/reference/creel_n_effort.md),
[`creel_power()`](https://chrischizinski.com/tidycreel/reference/creel_power.md),
[`cv_from_n()`](https://chrischizinski.com/tidycreel/reference/cv_from_n.md),
[`optimal_n()`](https://chrischizinski.com/tidycreel/reference/optimal_n.md),
[`power_creel()`](https://chrischizinski.com/tidycreel/reference/power_creel.md),
[`reallocate_strata()`](https://chrischizinski.com/tidycreel/reference/reallocate_strata.md),
[`simulate_strata_collapse()`](https://chrischizinski.com/tidycreel/reference/simulate_strata_collapse.md)

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

# Two estimates from the same design: overall, and split by stratum. In
# practice these would come from designs built on different survey types.
est_all <- estimate_effort(design)
est_grp <- estimate_effort(design, by = day_type)

compare_designs(list(overall = est_all, by_day_type = est_grp))
#> 
#> ── Survey Design Comparison ────────────────────────────────────────────────────
#> 3 row(s), 2 design(s)
#> 
#>        design estimate    se    rse ci_lower ci_upper ci_width  n day_type
#> 1     overall      372 13.18 0.0354      344      401     57.4 14       NA
#> 2 by_day_type      171  9.67 0.0567      150      192     42.2 10  weekday
#> 3 by_day_type      202  8.95 0.0443      182      221     39.0  4  weekend
```
