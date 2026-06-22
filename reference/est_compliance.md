# Estimate design-weighted size-limit compliance from a creel length distribution

`est_compliance()` estimates the proportion of fish meeting a minimum
size limit from a
[`est_length_distribution()`](https://chrischizinski.github.io/tidycreel/reference/est_length_distribution.md)
object. Fish in bins whose lower bound is at or above `min_length` are
classified as legal (conservative: bins straddling the limit are
classified as illegal).

## Usage

``` r
est_compliance(ld, min_length, conf_level = NULL)
```

## Arguments

- ld:

  A `creel_length_distribution` object from
  [`est_length_distribution()`](https://chrischizinski.github.io/tidycreel/reference/est_length_distribution.md).

- min_length:

  Positive numeric minimum legal length in the same units as the lengths
  used to build `ld`.

- conf_level:

  Numeric confidence level for confidence intervals. Defaults to the
  level stored in `ld` (usually `0.95`).

## Value

A `data.frame` with class `c("creel_compliance", "data.frame")` and
columns: grouping columns (if any), `min_length`, `n_legal_est`,
`n_total_est`, `compliance_prop`, `compliance_se`,
`compliance_ci_lower`, `compliance_ci_upper`.

## Details

A bin is legal when `bin_lower >= min_length`. The compliance proportion
and its variance use the ratio estimator: \$\$P = \frac{\sum_h I_h
\hat{N}\_h}{\hat{N}}\$\$ \$\$\widehat{\text{Var}}(P) \approx
\frac{1}{\hat{N}^2} \sum_h (I_h - P)^2 \\ \widehat{\text{SE}}\_h^2\$\$
where \\I_h = \mathbf{1}(\text{bin\\lower}\_h \geq
\text{min\\length})\\.

Confidence interval bounds are clamped to \\\[0, 1\]\\.

Choose `bin_width` in
[`est_length_distribution()`](https://chrischizinski.github.io/tidycreel/reference/est_length_distribution.md)
smaller than the typical variation near the legal limit to minimise
classification error for bins that straddle the threshold.

## See also

Other "Estimation":
[`compare_cpue_estimators()`](https://chrischizinski.github.io/tidycreel/reference/compare_cpue_estimators.md),
[`est_age_distribution()`](https://chrischizinski.github.io/tidycreel/reference/est_age_distribution.md),
[`est_biomass()`](https://chrischizinski.github.io/tidycreel/reference/est_biomass.md),
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
est_compliance(ld, min_length = 356)  # 14-inch limit in mm
#>   species min_length n_legal_est n_total_est compliance_prop compliance_se
#> 1    bass        356           0          13               0             0
#> 2 panfish        356           0          11               0             0
#> 3 walleye        356          13          13               1             0
#>   compliance_ci_lower compliance_ci_upper
#> 1                   0                   0
#> 2                   0                   0
#> 3                   1                   1
```
