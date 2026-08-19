# Pool camera effort estimates across multiply imputed count data sets

Estimates camera effort once per completed data set produced by
[`impute_camera_counts()`](https://chrischizinski.github.io/tidycreel/reference/impute_camera_counts.md)
with `m > 1`, then combines the results with Rubin's (1987) rules.

This exists because a single completed data set structurally cannot
carry the uncertainty introduced by imputing. Inside
[`survey::svytotal()`](https://rdrr.io/pkg/survey/man/surveysummary.html)
a predicted count is indistinguishable from an observed one, so the
imputation model's own error is dropped; and predictions are smoother
than real counts, so the between-day component shrinks as well. The
reported SE is therefore biased downward twice over, and can fall
*below* the SE of the same design with the outage days simply deleted —
reporting more precision from less information (GH \#137).

## Usage

``` r
est_effort_camera_mi(design, imputations, ..., conf_level = 0.95)
```

## Arguments

- design:

  A
  [`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md)
  object of `design_type == "camera"` **without** counts attached.
  Counts come from `imputations`, one completed set at a time.

- imputations:

  A `camera_imputations` object from
  [`impute_camera_counts()`](https://chrischizinski.github.io/tidycreel/reference/impute_camera_counts.md)
  with `m > 1`.

- ...:

  Further arguments passed to
  [`est_effort_camera()`](https://chrischizinski.github.io/tidycreel/reference/est_effort_camera.md),
  such as `interviews`, `h_open`, or `calibration`.

- conf_level:

  Numeric confidence level. Default `0.95`.

## Value

A `creel_estimates` object with `method = "camera_mi"`. Its
`se_components` names the two halves of the pooled variance as
`within_imputation` and `between_imputation`, so a reader can see how
much of the uncertainty came from imputing. The per-imputation results
are attached as `attr(result, "imputations")`.

## Details

**\[experimental\]**

## The pooled variance

With \\M\\ completed data sets giving estimates \\Q_m\\ and variances
\\U_m = SE_m^2\\:

\$\$\bar{Q} = \frac{1}{M} \sum_m Q_m\$\$ \$\$\bar{U} = \frac{1}{M}
\sum_m U_m\$\$ \$\$B = \frac{M+1}{M(M-1)} \sum_m (Q_m - \bar{Q})^2\$\$
\$\$T = \bar{U} + B\$\$

\\\bar{U}\\ is the **within-imputation** variance — the average of what
each completed data set reports, and the only part single imputation can
produce. \\B\\ is the **between-imputation** term, and it is the one
that is structurally missing today: it measures how much the estimate
moves when the outage days are filled differently, which a single filled
data set cannot express at all.

This is the pooling in Afrifa-Yamoah et al. (2020) equation (5). Their
\\(M+1)/(M(M-1))\\ factor is the usual Rubin \\(1 + 1/M)\\ inflation
written over the raw sum of squares rather than the sample variance; the
two are the same quantity.

Degrees of freedom use Rubin's classic expression \\\nu = (M-1)(1 +
\bar{U}/B)^2\\, which is finite precisely because \\B \> 0\\.

## References

Afrifa-Yamoah, E., Taylor, S.M., Fisher, A., and Mueller, U. 2020.
Imputation of missing data from time-lapse cameras used in recreational
fishing surveys. ICES Journal of Marine Science 77(7-8):2984-2994.

Rubin, D.B. 1987. Multiple Imputation for Nonresponse in Surveys. Wiley.

## See also

Other "Estimation":
[`compare_cpue_estimators()`](https://chrischizinski.github.io/tidycreel/reference/compare_cpue_estimators.md),
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
