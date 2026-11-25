# Compare CPUE estimators (ROM, MOR, Regression)

Runs all three CPUE estimators — Ratio-of-Means (ROM / CPUE\\\_2\\),
Mean-of-Ratios (MOR / CPUE\\\_1\\), and the regression slope of catch on
effort (CPUE\\\_3\\) — on the same creel design, all with Taylor
(linearization) standard errors on the day-clustered interview survey,
and returns a combined tibble with a `cpue_method` column for
side-by-side comparison.

This implements the Petrere et al. (2010) Table 1 estimator comparison
workflow. When the three estimators yield materially different
estimates, the choice of estimator matters; `compare_cpue_estimators()`
makes divergence visible.

## Usage

``` r
compare_cpue_estimators(
  design,
  by = NULL,
  conf_level = 0.95,
  force_origin = TRUE,
  verbose = FALSE
)
```

## Arguments

- design:

  A creel_design object with interviews attached. Must have `catch_col`
  and `angler_effort_col` set.

- by:

  Optional tidy selector for grouping variables. Passed to each
  underlying
  [`estimate_catch_rate`](https://chrischizinski.com/tidycreel/dev/reference/estimate_catch_rate.md)
  call.

- conf_level:

  Numeric. Confidence level. Default 0.95.

- force_origin:

  Logical. Force regression through origin. Default `TRUE` (standard
  CPUE\\\_3\\ formulation).

- verbose:

  Logical. If `TRUE`, prints a brief message for each estimator run.
  Default `FALSE`.

## Value

A tibble with columns `cpue_method` (character: `"rom"`, `"mor"`,
`"regression"`), plus `estimate`, `se`, `ci_lower`, `ci_upper`, `n`, and
any grouping columns when `by` is specified. The tibble has class
`c("cpue_comparison", "tbl_df", "tbl", "data.frame")`.

## Details

Estimator definitions following Petrere et al. (2010):

- ROM (CPUE\\\_2\\):

  Ratio of means: total catch / total effort (survey::svyratio).
  Unbiased for complete trips.

- MOR (CPUE\\\_1\\):

  Mean of individual ratios: mean(catch\\\_i\\ / effort\\\_i\\)
  (survey::svymean). Preferred for incomplete trips.

- Regression (CPUE\\\_3\\):

  OLS slope \\\hat{\beta}\\ from \\C_i = \beta f_i + \varepsilon_i\\,
  its SE linearized on the day-clustered survey like the other two. Most
  robust when proportionality is violated (non-zero intercept).

## References

Petrere, M. Jr., Giacomini, H.C. & De Marco, P. Jr. (2010).
Catch-per-unit-effort: which estimator is best? *Braz. J. Biol.* 70:
483–491.
[doi:10.1590/S1519-69842010005000010](https://doi.org/10.1590/S1519-69842010005000010)

## See also

[`estimate_catch_rate`](https://chrischizinski.com/tidycreel/dev/reference/estimate_catch_rate.md)

Other "Estimation":
[`combine_estimates()`](https://chrischizinski.com/tidycreel/dev/reference/combine_estimates.md),
[`compare_estimates()`](https://chrischizinski.com/tidycreel/dev/reference/compare_estimates.md),
[`est_age_distribution()`](https://chrischizinski.com/tidycreel/dev/reference/est_age_distribution.md),
[`est_biomass()`](https://chrischizinski.com/tidycreel/dev/reference/est_biomass.md),
[`est_compliance()`](https://chrischizinski.com/tidycreel/dev/reference/est_compliance.md),
[`est_effort_camera_mi()`](https://chrischizinski.com/tidycreel/dev/reference/est_effort_camera_mi.md),
[`est_length_distribution()`](https://chrischizinski.com/tidycreel/dev/reference/est_length_distribution.md),
[`est_mean_age()`](https://chrischizinski.com/tidycreel/dev/reference/est_mean_age.md),
[`est_mean_length()`](https://chrischizinski.com/tidycreel/dev/reference/est_mean_length.md),
[`estimate_catch_rate()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_catch_rate.md),
[`estimate_effort()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_effort.md),
[`estimate_effort_aerial_glmm()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_effort_aerial_glmm.md),
[`estimate_harvest_rate()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_harvest_rate.md),
[`estimate_release_rate()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_release_rate.md),
[`estimate_total_catch()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_total_catch.md),
[`estimate_total_harvest()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_total_harvest.md),
[`estimate_total_release()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_total_release.md)

## Examples

``` r
# Counts too: each estimator weights the day types by their effort.
design <- creel_design(example_calendar, date = date, strata = day_type) |>
  add_counts(example_counts) |>
  add_interviews(example_interviews,
    catch = catch_total, effort = hours_fished,
    trip_status = trip_status, n_anglers = n_anglers
  )
#> ℹ Added 22 interviews: 17 complete (77%), 5 incomplete (23%)

compare_cpue_estimators(design)
#> ℹ Using complete trips for CPUE estimation
#>   (n=17, 77.3% of 22 interviews)
#> Warning: Small sample size for CPUE estimation.
#> ! Sample size is 17. Ratio estimates are more stable with n >= 30.
#> ℹ Variance estimates may be unstable with n < 30.
#> ℹ Repeats on this design are recorded, not printed: see `get_warnings()`.
#> Warning: Instantaneous counts were expanded without a period length.
#> ℹ No `period_length_col` was supplied to `add_counts()`, so the estimate is the
#>   count column summed over days.
#> ! If that column holds an instantaneous angler count, the result is the anglers
#>   present at the counted moments, not angler-hours: a count becomes effort only
#>   when multiplied by its period length. The package cannot tell which unit the
#>   column is in.
#> ℹ Supply the period each count was randomised within: `add_counts(design,
#>   counts, period_length_col = <col>)`.
#> ℹ Repeats on this design are recorded, not printed: see `get_warnings()`.
#> ℹ Using complete trips for CPUE estimation
#>   (n=17, 77.3% of 22 interviews)
#> Non-standard combination: use_trips='complete' with estimator='mor'
#> ℹ MOR typically used with incomplete trips
#> ℹ You are using MOR on 17 complete trips - consider `estimator =
#>   'ratio-of-means'` for standard complete trip estimation
#> MOR truncation skipped: no trip duration column in design.
#> ℹ Supply `trip_duration` in `add_interviews()` to enable truncation.
#> ℹ All 17 trips used without truncation.
#> ℹ Using complete trips for CPUE estimation
#>   (n=17, 77.3% of 22 interviews)
#> # A tibble: 3 × 6
#>   cpue_method estimate     se ci_lower ci_upper     n
#> * <chr>          <dbl>  <dbl>    <dbl>    <dbl> <int>
#> 1 rom            0.981 0.120     0.716     1.25    17
#> 2 mor            0.995 0.126     0.718     1.27    17
#> 3 regression     0.810 0.0704    0.606     1.02    17
```
