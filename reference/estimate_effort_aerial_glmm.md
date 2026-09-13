# GLMM-based aerial effort estimation with diurnal correction

Estimates total angler effort from aerial creel surveys using a
generalized linear mixed model (GLMM), following the approach of Askey
et al. (2018). When flights occur at non-random times of day, simple
scaling of instantaneous counts can over- or under-estimate daily
effort. This function fits a negative-binomial GLMM (or user-specified
family) to model how angler counts change through the day, then
integrates the fitted diurnal curve over the fishing day to obtain a
bias-corrected effort estimate.

The default model is the quadratic temporal model from Askey (2018):
`count ~ poly(time_col, 2) + (1 | date)`, fitted via
[`lme4::glmer.nb()`](https://rdrr.io/pkg/lme4/man/glmer.nb.html).
Variance is propagated via the delta method (default) or parametric
bootstrap
([`lme4::bootMer()`](https://rdrr.io/pkg/lme4/man/bootMer.html)).

## Usage

``` r
estimate_effort_aerial_glmm(
  design,
  time_col,
  formula = NULL,
  family = NULL,
  boot = FALSE,
  nboot = 500L,
  conf_level = 0.95
)
```

## Arguments

- design:

  A
  [`creel_design()`](https://chrischizinski.com/tidycreel/reference/creel_design.md)
  object with `design_type == "aerial"` and counts attached via
  [`add_counts()`](https://chrischizinski.com/tidycreel/reference/add_counts.md).
  The counts data must contain the time-of-flight column specified by
  `time_col`.

- time_col:

  Unquoted name of the numeric column in `design$counts` recording the
  hour of each aerial overflight (e.g., `time_of_flight`).

- formula:

  Optional. A formula for the GLMM, passed directly to
  [`lme4::glmer.nb()`](https://rdrr.io/pkg/lme4/man/glmer.nb.html) or
  [`lme4::glmer()`](https://rdrr.io/pkg/lme4/man/glmer.html). If `NULL`
  (default), the Askey (2018) quadratic formula is used:
  `count ~ poly(time_col, 2) + (1 | date)`.

- family:

  Optional. A family object or character string specifying the GLM
  family. If `NULL` or `"negbin"` (default),
  [`lme4::glmer.nb()`](https://rdrr.io/pkg/lme4/man/glmer.nb.html) is
  used. Otherwise,
  [`lme4::glmer()`](https://rdrr.io/pkg/lme4/man/glmer.html) is called
  with the specified family.

- boot:

  Logical. If `TRUE`, use
  [`lme4::bootMer()`](https://rdrr.io/pkg/lme4/man/bootMer.html) for
  parametric bootstrap confidence intervals instead of the delta method.
  Default `FALSE`.

- nboot:

  Integer. Number of bootstrap replicates when `boot = TRUE`. Default
  `500L`.

- conf_level:

  Numeric confidence level for the CI. Default `0.95`.

## Value

A `creel_estimates` object with:

- `estimate`: total angler effort integrated over the fishing day

- `se`: standard error (delta method or bootstrap SD)

- `se_between`: same as `se` (fixed-effect SE component)

- `se_within`: always `NA_real_` — no Rasmussen within-day decomposition
  is performed for GLMM estimates

- `ci_lower`, `ci_upper`: confidence interval bounds

- `n`: number of count observations used to fit the model

- `method`: `"aerial_glmm_total"`

## Details

**\[experimental\]**

## References

Askey, P.J., Ward, H., Godin, T., Boucher, M., and Northrup, S. (2018).
Angler effort estimates from instantaneous aerial counts: use of
high-frequency time-lapse camera data to inform model-based estimators.
North American Journal of Fisheries Management, 38, 194-209.
[doi:10.1002/nafm.10010](https://doi.org/10.1002/nafm.10010)

## See also

Other "Estimation":
[`compare_cpue_estimators()`](https://chrischizinski.com/tidycreel/reference/compare_cpue_estimators.md),
[`est_age_distribution()`](https://chrischizinski.com/tidycreel/reference/est_age_distribution.md),
[`est_biomass()`](https://chrischizinski.com/tidycreel/reference/est_biomass.md),
[`est_compliance()`](https://chrischizinski.com/tidycreel/reference/est_compliance.md),
[`est_effort_camera_mi()`](https://chrischizinski.com/tidycreel/reference/est_effort_camera_mi.md),
[`est_length_distribution()`](https://chrischizinski.com/tidycreel/reference/est_length_distribution.md),
[`est_mean_age()`](https://chrischizinski.com/tidycreel/reference/est_mean_age.md),
[`est_mean_length()`](https://chrischizinski.com/tidycreel/reference/est_mean_length.md),
[`estimate_catch_rate()`](https://chrischizinski.com/tidycreel/reference/estimate_catch_rate.md),
[`estimate_effort()`](https://chrischizinski.com/tidycreel/reference/estimate_effort.md),
[`estimate_harvest_rate()`](https://chrischizinski.com/tidycreel/reference/estimate_harvest_rate.md),
[`estimate_release_rate()`](https://chrischizinski.com/tidycreel/reference/estimate_release_rate.md),
[`estimate_total_catch()`](https://chrischizinski.com/tidycreel/reference/estimate_total_catch.md),
[`estimate_total_harvest()`](https://chrischizinski.com/tidycreel/reference/estimate_total_harvest.md),
[`estimate_total_release()`](https://chrischizinski.com/tidycreel/reference/estimate_total_release.md)

## Examples

``` r
data(example_aerial_glmm_counts)

aerial_cal <- unique(example_aerial_glmm_counts[, c("date", "day_type")])
aerial_cal <- aerial_cal[order(aerial_cal$date), ]
design <- creel_design(
  aerial_cal,
  date = date,
  strata = day_type,
  survey_type = "aerial",
  visibility_correction = "none",
  angler_ratio = 1,
  angler_ratio_se = 0,
  h_open = 14
)
design <- add_counts(design, example_aerial_glmm_counts, count_col = n_anglers)
#> Warning: `counts` has 36 repeated sampling units, with no count time to tell them apart.
#> ℹ The repeated rows are keyed on date and day_type.
#> ℹ Estimators that sum these rows refuse them; supply `count_time_col` if they
#>   are repeat counts, or `unit_cols` if they are distinct units.
#> Warning: No weights or probabilities supplied, assuming equal probability

# Default Askey quadratic model with delta-method SE
result <- estimate_effort_aerial_glmm(design, time_col = time_of_flight)
#> Warning: iteration limit reached
#> ℹ Integration window start derived from data: 6.5 h (earliest flight - 0.5 h).
#>   Specify `open_start` in `creel_design()` for a fixed fishery opening time.
print(result)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: aerial_glmm_total
#> Variance: delta
#> Confidence level: 95%
#> model: 32.98 (known, but se is `NA`)
#> visibility: NA (unknown, so se is `NA`)
#> angler_ratio: 0 (known, but se is `NA`)
#> 
#> # A tibble: 1 × 7
#>   estimate    se se_between se_within ci_lower ci_upper     n
#>      <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int>
#> 1     379.    NA         NA        NA       NA       NA    48

# Bootstrap CIs (slower)
result_boot <- estimate_effort_aerial_glmm(
  design,
  time_col = time_of_flight,
  boot = TRUE,
  nboot = 100L
)
#> Warning: iteration limit reached
#> ℹ Integration window start derived from data: 6.5 h (earliest flight - 0.5 h).
#>   Specify `open_start` in `creel_design()` for a fixed fishery opening time.
#> Running 100 bootstrap replicates via lme4::bootMer...
#> Warning: ! Bootstrap SE ignores design strata ("day_type").
#> ℹ The default GLMM formula has no stratum term; bootstrap resamples from a
#>   single pooled model. Include strata in `formula` for stratified inference.
print(result_boot)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: aerial_glmm_total
#> Variance: Bootstrap
#> Confidence level: 95%
#> model: NA (unknown, so se is `NA`)
#> 
#> # A tibble: 1 × 7
#>   estimate    se se_between se_within ci_lower ci_upper     n
#>      <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int>
#> 1     379.    NA         NA        NA     303.     442.    48
```
