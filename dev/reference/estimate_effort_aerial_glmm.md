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
  conf_level = 0.95,
  target = c("sampled_days", "mean_day"),
  by = NULL
)
```

## Arguments

- design:

  A
  [`creel_design()`](https://chrischizinski.com/tidycreel/dev/reference/creel_design.md)
  object with `design_type == "aerial"` and counts attached via
  [`add_counts()`](https://chrischizinski.com/tidycreel/dev/reference/add_counts.md).
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

- target:

  Character string giving the temporal basis of the returned estimate.
  `"sampled_days"` (default) expands the fitted day to every day the
  design sampled, matching what
  [`estimate_effort()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_effort.md)
  returns for the same design so the two are comparable. `"mean_day"`
  reports a single average day, the basis this function reported before
  tidycreel 8.0.0. It is not identical to the old value: it now carries
  the retransformation factor the old code omitted, so it is higher by
  `exp(sigma^2 / 2)`.

  Both are expectations, so both carry the retransformation factor
  described under Details. Neither expands beyond the sampled days:
  expanded targets are not supported for aerial designs by
  [`estimate_effort()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_effort.md)
  either.

- by:

  Optional tidy selection of columns in `design$counts` to estimate
  within, typically the design strata (for example `by = day_type`). The
  strata enter the default model as additive fixed effects in ONE model
  – `count ~ poly(time_col, 2) + day_type + (1 | date)` – so they share
  the diurnal curve's shape and differ in its level; see Details. Each
  stratum expands by its own sampled days. A count with a missing value
  in a `by` column belongs to an unknown stratum, which is its own level
  in the model and its own row (`NA`), so the rows account for every
  count. Stratum columns keep their source type. Supported on the delta
  path only (`boot = FALSE`). When `formula` is supplied it is used as
  given, and it must contain every `by` column as a fixed effect;
  otherwise every stratum would get the same curve, so the call is
  refused. A `by` column with only one observed level is left out of the
  model (its level is the intercept) and still reported as a row.

## Value

A `creel_estimates` object with:

- `estimate`: total angler effort integrated over the fishing day

- `se`: standard error (delta method or bootstrap SD)

- `se_between`: same as `se` (fixed-effect SE component)

- `se_within`: always `NA_real_` — no Rasmussen within-day decomposition
  is performed for GLMM estimates

- `ci_lower`, `ci_upper`: confidence interval bounds, and `NA_real_`
  whenever `se` is, on both the delta and bootstrap paths. If the
  visibility correction or the angler-to-people ratio was declared
  unknown, the total's uncertainty was never fully propagated, so no
  unconditional interval exists to report. Reporting the remaining
  spread would be an interval conditional on the unknown multiplier
  being exact – indistinguishable from declaring it known with zero
  uncertainty, which is precisely the confusion `NA` exists to prevent.

- `n`: number of count observations used to fit the model (with `by`,
  the observations in that stratum)

- `method`: `"aerial_glmm_total"`

With `by`, there is one row per stratum, headed by the `by` columns, and
the object carries `strata_vcov`: the covariance matrix of the stratum
estimates, rows and columns in the order of the estimate rows. Its
diagonal is `se^2`. The off-diagonal is not zero: every stratum is
predicted from the same fixed effects, and the visibility correction and
angler-to-people ratio are single estimates that multiply every stratum.
Combine strata with it – `sqrt(sum(strata_vcov))` is the SE of the
summed total – and never by adding the rows' SEs in quadrature, which
understates it.

## Details

**\[experimental\]**

The fitted curve is a fixed-effects prediction: the day whose random
intercept is zero. On a log link that is the *median* day rather than
the mean one, so summing it across days would understate the total. Both
targets therefore carry a factor of `exp(sigma^2 / 2)`, where `sigma^2`
is the day-level intercept variance — 4% on the package's own fixture,
and larger where days vary more.

That factor treats `sigma^2` as known. The reported standard error
scales with the expansion but does not carry the uncertainty in the
variance component itself, so it is mildly optimistic; quantifying that
would need a variance method neither the delta nor the bootstrap path
offers today.

### Estimating within strata

With `by`, the strata are additive: they shift the level of one shared
diurnal curve and do not change its shape. That follows Askey et al.
(2018), where day type is additive in every model structure compared;
the one interaction they tested (month x hour) was preferred by AIC,
rejected by BIC, and bought no predictive gain in cross-validation. A
single model also shares strength across strata, which matters when a
stratum has few flights.

The assumption can fail. Smucker et al. (2010, Table 1) report weekday
and weekend diurnal effort that differ in shape, most clearly for shore
anglers. So the default grouped fit also fits the time x stratum
interaction and reports the BIC difference as a message. A negative
difference favours separate shapes; fit one by passing `formula`, for
example `n_anglers ~ poly(time_of_flight, 2) * day_type + (1 | date)`.
The estimate is never switched automatically, because a choice made from
the data is not reflected in the reported standard error.

Askey et al. also found that with many randomly timed counts (about 60
or more) a model-based estimator offered no advantage over expanding the
mean count, which was the only unbiased estimator in their comparison.
The GLMM earns its place when flights are few or their timing is not
random.

## References

Askey, P.J., Ward, H., Godin, T., Boucher, M., and Northrup, S. (2018).
Angler effort estimates from instantaneous aerial counts: use of
high-frequency time-lapse camera data to inform model-based estimators.
North American Journal of Fisheries Management, 38, 194-209.
[doi:10.1002/nafm.10010](https://doi.org/10.1002/nafm.10010)

Smucker, B.J., Lorantas, R.M., and Rosenberger, J.L. (2010). Correcting
bias introduced by aerial counts in angler effort estimation. North
American Journal of Fisheries Management, 30, 1051-1061.
[doi:10.1577/M09-193.1](https://doi.org/10.1577/M09-193.1)

## See also

Other "Estimation":
[`compare_cpue_estimators()`](https://chrischizinski.com/tidycreel/dev/reference/compare_cpue_estimators.md),
[`est_age_distribution()`](https://chrischizinski.com/tidycreel/dev/reference/est_age_distribution.md),
[`est_biomass()`](https://chrischizinski.com/tidycreel/dev/reference/est_biomass.md),
[`est_compliance()`](https://chrischizinski.com/tidycreel/dev/reference/est_compliance.md),
[`est_effort_camera_mi()`](https://chrischizinski.com/tidycreel/dev/reference/est_effort_camera_mi.md),
[`est_length_distribution()`](https://chrischizinski.com/tidycreel/dev/reference/est_length_distribution.md),
[`est_mean_age()`](https://chrischizinski.com/tidycreel/dev/reference/est_mean_age.md),
[`est_mean_length()`](https://chrischizinski.com/tidycreel/dev/reference/est_mean_length.md),
[`estimate_catch_rate()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_catch_rate.md),
[`estimate_effort()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_effort.md),
[`estimate_harvest_rate()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_harvest_rate.md),
[`estimate_release_rate()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_release_rate.md),
[`estimate_total_catch()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_total_catch.md),
[`estimate_total_harvest()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_total_harvest.md),
[`estimate_total_release()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_total_release.md)

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
#> Effort target: sampled_days
#> model: 412 (known, but se is `NA`)
#> visibility: NA (unknown, so se is `NA`)
#> angler_ratio: 0 (known, but se is `NA`)
#> 
#> # A tibble: 1 × 7
#>   estimate    se se_between se_within ci_lower ci_upper     n
#>      <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int>
#> 1    4729.    NA         NA        NA       NA       NA    48

# One row per day type, from one model with day type as an additive term.
# `visibility_correction = "none"` above leaves the SEs unknown (NA), so this
# design declares a measured detection probability and its SE.
design_v <- creel_design(
  aerial_cal,
  date = date,
  strata = day_type,
  survey_type = "aerial",
  visibility_correction = 0.85,
  visibility_se = 0.05,
  angler_ratio = 1,
  angler_ratio_se = 0,
  h_open = 14
)
design_v <- add_counts(design_v, example_aerial_glmm_counts, count_col = n_anglers)
#> Warning: `counts` has 36 repeated sampling units, with no count time to tell them apart.
#> ℹ The repeated rows are keyed on date and day_type.
#> ℹ Estimators that sum these rows refuse them; supply `count_time_col` if they
#>   are repeat counts, or `unit_cols` if they are distinct units.
#> Warning: No weights or probabilities supplied, assuming equal probability
by_day <- estimate_effort_aerial_glmm(design_v, time_col = time_of_flight, by = day_type)
#> Warning: iteration limit reached
#> ℹ BIC(interaction) - BIC(additive) = 5.9: favours the shared shape used for
#>   this estimate.
#>   The interaction fit raised 1 warning; treat the comparison with caution.
#> ℹ Integration window start derived from data: 6.5 h (earliest flight - 0.5 h).
#>   Specify `open_start` in `creel_design()` for a fixed fishery opening time.
print(by_day)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: aerial_glmm_total
#> Variance: delta
#> Confidence level: 95%
#> Grouped by: day_type
#> Effort target: sampled_days
#> model: 380.6 and 290.4 (included in se)
#> visibility: 212.0 and 115.3 (included in se)
#> angler_ratio: 0 and 0 (included in se)
#> 
#> # A tibble: 2 × 8
#>   day_type estimate    se se_between se_within ci_lower ci_upper     n
#>   <chr>       <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int>
#> 1 weekday     3603.  436.       436.        NA    2750.    4457.    32
#> 2 weekend     1960.  312.       312.        NA    1347.    2572.    16
# SE of the summed total: use the joint covariance, not quadrature
sqrt(sum(by_day$strata_vcov))
#> [1] 581.6951

# Bootstrap CIs. `nboot` is held low here so the example stays fast on a
# check machine; use at least 1000 replicates for real inference. The block
# is wrapped in \donttest{} for runtime alone -- it needs no resource the
# example cannot reach.
# \donttest{
result_boot <- estimate_effort_aerial_glmm(
  design,
  time_col = time_of_flight,
  boot = TRUE,
  nboot = 25L
)
#> Warning: iteration limit reached
#> ℹ Integration window start derived from data: 6.5 h (earliest flight - 0.5 h).
#>   Specify `open_start` in `creel_design()` for a fixed fishery opening time.
#> Running 25 bootstrap replicates via lme4::bootMer...
#> Warning: ! Bootstrap SE ignores design strata ("day_type").
#> ℹ The default GLMM formula has no stratum term; bootstrap resamples from a
#>   single pooled model. Include strata in `formula` for stratified inference.
print(result_boot)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: aerial_glmm_total
#> Variance: Bootstrap
#> Confidence level: 95%
#> Effort target: sampled_days
#> model: NA (unknown, so se is `NA`)
#> 
#> # A tibble: 1 × 7
#>   estimate    se se_between se_within ci_lower ci_upper     n
#>      <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int>
#> 1    4729.    NA         NA        NA       NA       NA    48
# }
```
