# Estimate design-weighted mean length from a creel length distribution

`est_mean_length()` computes the pressure-weighted mean fish length from
a
[`est_length_distribution()`](https://chrischizinski.github.io/tidycreel/reference/est_length_distribution.md)
object using the ratio estimator \\\bar{L} = \sum_h L_h \hat{N}\_h /
\sum_h \hat{N}\_h\\, with delta-method standard error.

## Usage

``` r
est_mean_length(ld, conf_level = NULL)
```

## Arguments

- ld:

  A `creel_length_distribution` object from
  [`est_length_distribution()`](https://chrischizinski.github.io/tidycreel/reference/est_length_distribution.md).

- conf_level:

  Numeric confidence level for confidence intervals. Defaults to the
  level stored in `ld` (usually `0.95`).

## Value

A `data.frame` with class `c("creel_mean_length", "data.frame")` and
columns: grouping columns (if any), `mean_length`, `mean_length_se`,
`mean_length_ci_lower`, `mean_length_ci_upper`. Rows where the total
estimated fish is zero or negative return `NA` for all numeric columns
with a warning.

## Details

Bin midpoints \\L_h = (\text{bin\\lower} + \text{bin\\upper}) / 2\\
serve as representative lengths. Mean length is the ratio of total
length-weighted count to total count: \$\$\bar{L} = \frac{\sum_h L_h
\hat{N}\_h}{\hat{N}}\$\$

Variance is propagated via the delta method for a ratio estimator,
treating cross-bin covariances as zero:
\$\$\widehat{\text{Var}}(\bar{L}) \approx \frac{1}{\hat{N}^2} \sum_h
(L_h - \bar{L})^2 \\ \widehat{\text{SE}}\_h^2\$\$

## See also

Other "Estimation":
[`compare_cpue_estimators()`](https://chrischizinski.github.io/tidycreel/reference/compare_cpue_estimators.md),
[`est_age_distribution()`](https://chrischizinski.github.io/tidycreel/reference/est_age_distribution.md),
[`est_biomass()`](https://chrischizinski.github.io/tidycreel/reference/est_biomass.md),
[`est_compliance()`](https://chrischizinski.github.io/tidycreel/reference/est_compliance.md),
[`est_length_distribution()`](https://chrischizinski.github.io/tidycreel/reference/est_length_distribution.md),
[`est_mean_age()`](https://chrischizinski.github.io/tidycreel/reference/est_mean_age.md),
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
data(example_lengths)

design <- creel_design(example_calendar, date = date, strata = day_type)
design <- add_interviews(design, example_interviews,
  catch = catch_total, effort = hours_fished, harvest = catch_kept,
  trip_status = trip_status
)
#> ℹ No `n_anglers` provided — assuming 1 angler per interview.
#> ℹ Pass `n_anglers = <column>` to use actual party sizes for angler-hour
#>   normalization.
#> ℹ Added 22 interviews: 17 complete (77%), 5 incomplete (23%)
design <- add_lengths(design, example_lengths,
  length_uid = interview_id,
  interview_uid = interview_id,
  species = species,
  length = length,
  length_type = length_type,
  count = count,
  release_format = "binned"
)

ld <- est_length_distribution(design, by = species, bin_width = 25)
est_mean_length(ld)
#>   species mean_length mean_length_se mean_length_ci_lower mean_length_ci_upper
#> 1    bass    300.9615       15.78323             270.0270             331.8961
#> 2 panfish    196.5909       13.69260             169.7539             223.4279
#> 3 walleye    431.7308       15.84683             400.6716             462.7900
```
