# Estimate total biomass from a creel length distribution

`est_biomass()` converts a pressure-weighted length-frequency
distribution produced by
[`est_length_distribution()`](https://chrischizinski.github.io/tidycreel/reference/est_length_distribution.md)
into a total biomass estimate using the allometric length-weight
equation \\W = a \cdot L^b\\.

Variance is propagated via the delta method, treating estimated fish
counts per length bin as uncorrelated (see Details).

## Usage

``` r
est_biomass(ld, a, b, conf_level = NULL)
```

## Arguments

- ld:

  A `creel_length_distribution` object from
  [`est_length_distribution()`](https://chrischizinski.github.io/tidycreel/reference/est_length_distribution.md).

- a:

  Positive numeric allometric coefficient (the \\a\\ in \\W = a \cdot
  L^b\\).

- b:

  Numeric allometric exponent (the \\b\\ in \\W = a \cdot L^b\\).
  Typical values for fish are 2.5–3.5.

- conf_level:

  Numeric confidence level for confidence intervals. Defaults to the
  level stored in `ld` (usually `0.95`).

## Value

A `data.frame` with class `c("creel_biomass", "data.frame")` and
columns: grouping columns (if any), `biomass_estimate`, `biomass_se`,
`biomass_ci_lower`, `biomass_ci_upper`.

## Details

For each length bin h with midpoint \\L_h = (\text{bin\\lower} +
\text{bin\\upper}) / 2\\, per-bin biomass is \\B_h = a \cdot L_h^b \cdot
\hat{N}\_h\\, where \\\hat{N}\_h\\ is the survey-weighted estimated fish
count from
[`est_length_distribution()`](https://chrischizinski.github.io/tidycreel/reference/est_length_distribution.md).
Total biomass is \\B = \sum_h B_h\\.

Variance is approximated as \\\widehat{\text{Var}}(B) \approx \sum_h (a
\cdot L_h^b)^2 \cdot \widehat{\text{SE}}\_h^2\\, which ignores cross-bin
covariances. When positive covariances exist (likely in small surveys),
this under-estimates the true variance.

Length and weight units are determined by the user: if lengths are in mm
and `a` is calibrated for mm input, weights are returned in the
corresponding unit (e.g., grams).

## See also

Other "Estimation":
[`compare_cpue_estimators()`](https://chrischizinski.github.io/tidycreel/reference/compare_cpue_estimators.md),
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
est_biomass(ld, a = 0.0088, b = 3.1)
#>   species biomass_estimate biomass_se biomass_ci_lower biomass_ci_upper
#> 1    bass          5719272    3419579        -982979.4         12421524
#> 2 panfish          1324223     856948        -355364.4          3003810
#> 3 walleye         17476539    7133021        3496075.1         31457003
```
