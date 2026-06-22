# Estimate design-weighted mean age from a creel age distribution

`est_mean_age()` computes the pressure-weighted mean fish age from a
[`est_age_distribution()`](https://chrischizinski.github.io/tidycreel/reference/est_age_distribution.md)
object using the ratio estimator \\\bar{A} = \sum_a a \hat{N}\_a /
\sum_a \hat{N}\_a\\, with delta-method standard error.

## Usage

``` r
est_mean_age(ad, conf_level = NULL)
```

## Arguments

- ad:

  A `creel_age_distribution` object from
  [`est_age_distribution()`](https://chrischizinski.github.io/tidycreel/reference/est_age_distribution.md).

- conf_level:

  Numeric confidence level for confidence intervals. Defaults to the
  level stored in `ad` (usually `0.95`).

## Value

A `data.frame` with class `c("creel_mean_age", "data.frame")` and
columns: grouping columns (if any), `mean_age`, `mean_age_se`,
`mean_age_ci_lower`, `mean_age_ci_upper`.

## Details

Each integer age \\a\\ contributes its survey-weighted count
\\\hat{N}\_a\\. Mean age is the ratio of total age-weighted count to
total count: \$\$\bar{A} = \frac{\sum_a a \hat{N}\_a}{\hat{N}}\$\$

Variance is propagated via the delta method for a ratio estimator,
treating cross-class covariances as zero:
\$\$\widehat{\text{Var}}(\bar{A}) \approx \frac{1}{\hat{N}^2} \sum_a
(a - \bar{A})^2 \\ \widehat{\text{SE}}\_a^2\$\$

## See also

Other "Estimation":
[`compare_cpue_estimators()`](https://chrischizinski.github.io/tidycreel/reference/compare_cpue_estimators.md),
[`est_age_distribution()`](https://chrischizinski.github.io/tidycreel/reference/est_age_distribution.md),
[`est_biomass()`](https://chrischizinski.github.io/tidycreel/reference/est_biomass.md),
[`est_compliance()`](https://chrischizinski.github.io/tidycreel/reference/est_compliance.md),
[`est_length_distribution()`](https://chrischizinski.github.io/tidycreel/reference/est_length_distribution.md),
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
data(example_calendar)
data(example_interviews)
data(example_ages)

design <- creel_design(example_calendar, date = date, strata = day_type)
design <- add_interviews(design, example_interviews,
  catch = catch_total, effort = hours_fished, harvest = catch_kept,
  trip_status = trip_status
)
#> ℹ No `n_anglers` provided — assuming 1 angler per interview.
#> ℹ Pass `n_anglers = <column>` to use actual party sizes for angler-hour
#>   normalization.
#> ℹ Added 22 interviews: 17 complete (77%), 5 incomplete (23%)
design <- add_ages(design, example_ages,
  age_uid = interview_id,
  interview_uid = interview_id,
  species = species,
  age = age,
  age_type = age_type
)

ad <- est_age_distribution(design, by = species)
est_mean_age(ad)
#>   species mean_age mean_age_se mean_age_ci_lower mean_age_ci_upper
#> 1    bass 2.600000   0.2154066         2.1778108          3.022189
#> 2 panfish 1.000000   0.3535534         0.3070481          1.692952
#> 3 walleye 4.444444   0.4307445         3.6002007          5.288688
```
