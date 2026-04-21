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
  [`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md)
  object with `design_type == "aerial"` and counts attached via
  [`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md).
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

Askey, P.J., et al. (2018). Correcting for non-random flight timing in
aerial creel surveys using a generalized linear mixed model. North
American Journal of Fisheries Management, 38, 1204-1215.
[doi:10.1002/nafm.10010](https://doi.org/10.1002/nafm.10010)

## See also

Other "Estimation":
[`est_length_distribution()`](https://chrischizinski.github.io/tidycreel/reference/est_length_distribution.md),
[`estimate_catch_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_catch_rate.md),
[`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md),
[`estimate_harvest_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_harvest_rate.md),
[`estimate_release_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_release_rate.md),
[`estimate_total_catch()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_catch.md),
[`estimate_total_harvest()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_harvest.md),
[`estimate_total_release()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_release.md)

## Examples

``` r
if (FALSE) { # \dontrun{
data(example_aerial_glmm_counts)

aerial_cal <- unique(example_aerial_glmm_counts[, c("date", "day_type")])
aerial_cal <- aerial_cal[order(aerial_cal$date), ]
design <- creel_design(
  aerial_cal,
  date = date,
  strata = day_type,
  survey_type = "aerial",
  h_open = 14
)
design <- add_counts(design, example_aerial_glmm_counts)

# Default Askey quadratic model with delta-method SE
result <- estimate_effort_aerial_glmm(design, time_col = time_of_flight)
print(result)

# Bootstrap CIs (slower)
result_boot <- estimate_effort_aerial_glmm(
  design,
  time_col = time_of_flight,
  boot = TRUE,
  nboot = 100L
)
print(result_boot)
} # }
```
