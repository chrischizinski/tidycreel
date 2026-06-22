# Compare CPUE estimators (ROM, MOR, Regression)

Runs all three CPUE estimators — Ratio-of-Means (ROM / CPUE\\\_2\\),
Mean-of-Ratios (MOR / CPUE\\\_1\\), and OLS regression slope with
jackknife SE (CPUE\\\_3\\) — on the same creel design and returns a
combined tibble with a `cpue_method` column for side-by-side comparison.

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
  [`estimate_catch_rate`](https://chrischizinski.github.io/tidycreel/reference/estimate_catch_rate.md)
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

  OLS slope \\\hat{\beta}\\ from \\C_i = \beta f_i + \varepsilon_i\\
  with leave-one-out jackknife SE. Most robust when proportionality is
  violated (non-zero intercept).

## References

Petrere, M. et al. (2010). Catch-per-unit-effort: which estimator is
best? *Fish. Res.* 106: 325–333.

## See also

[`estimate_catch_rate`](https://chrischizinski.github.io/tidycreel/reference/estimate_catch_rate.md)

Other "Estimation":
[`est_age_distribution()`](https://chrischizinski.github.io/tidycreel/reference/est_age_distribution.md),
[`est_biomass()`](https://chrischizinski.github.io/tidycreel/reference/est_biomass.md),
[`est_compliance()`](https://chrischizinski.github.io/tidycreel/reference/est_compliance.md),
[`est_length_distribution()`](https://chrischizinski.github.io/tidycreel/reference/est_length_distribution.md),
[`est_mean_age()`](https://chrischizinski.github.io/tidycreel/reference/est_mean_age.md),
[`est_mean_length()`](https://chrischizinski.github.io/tidycreel/reference/est_mean_length.md),
[`estimate_catch_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_catch_rate.md),
[`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md),
[`estimate_effort_aerial_glmm()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort_aerial_glmm.md),
[`estimate_harvest_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_harvest_rate.md),
[`estimate_release_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_release_rate.md),
[`estimate_total_catch()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_catch.md),
[`estimate_total_harvest()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_harvest.md),
[`estimate_total_release()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_release.md)

## Examples

``` r
if (FALSE) { # \dontrun{
design <- creel_design(calendar, date_col = date, strata_col = day_type) |>
  add_interviews(interviews, catch_col = catch_total,
                 effort_col = hours_fished, trip_status_col = trip_status)

compare_cpue_estimators(design)
compare_cpue_estimators(design, by = day_type)
} # }
```
