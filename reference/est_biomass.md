# Estimate total biomass from a creel length distribution

`est_biomass()` converts a pressure-weighted length-frequency
distribution produced by
[`est_length_distribution()`](https://chrischizinski.github.io/tidycreel/reference/est_length_distribution.md)
into a total biomass estimate using the allometric length-weight
equation \\W = a \cdot L^b\\.

Variance is propagated via the delta method, treating estimated fish
counts per length bin as uncorrelated and the length-weight parameters
`a` and `b` as known without error (see Details).

## Usage

``` r
est_biomass(
  ld,
  a,
  b,
  conf_level = NULL,
  alpha_se = NULL,
  b_se = NULL,
  L0 = NULL
)
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

- alpha_se:

  Optional standard error of the pivot coefficient \\\alpha = a \cdot
  L_0^b\\, i.e. the fitted intercept on the \\\log W = \log \alpha + b
  (\log L - \log L_0)\\ scale.

- b_se:

  Optional standard error of the exponent `b`.

- L0:

  Optional pivot length at which the regression was centred, in the same
  units as the bin boundaries. Use the geometric mean length of the
  length-weight calibration sample.

  These three are all-or-nothing: give all of them to propagate the
  length-weight regression error, or none to keep the current behaviour.
  There is no zero default — see Details.

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

By default `a` and `b` are treated as known constants, so `biomass_se`
carries no contribution from their estimation error. In practice they
are point estimates from a length-weight regression, often one fitted to
a different water body or year. Because \\a \cdot L_h^b\\ multiplies
every bin, that error is perfectly correlated across bins and does not
shrink as bins are added — unlike the cross-bin term above.

The omission is usually minor relative to count variance: on the example
below it adds roughly 2–11% to a coefficient of variation of 40–65%, for
regression standard errors spanning well- and poorly-determined fits. It
becomes material in two situations — a survey precise enough to bring
the count CV near 10%, and `a`/`b` borrowed from a system whose fish
differ in size from those measured here, since the contribution scales
with the distance between the two samples' mean log lengths.

## Propagating the length-weight regression error

Supply `alpha_se`, `b_se`, and `L0` together to carry that term. The
allometry is rewritten about a pivot length \\L_0\\: \$\$W = \alpha
\left(\frac{L}{L_0}\right)^b, \qquad \alpha = a L_0^b\$\$ and the delta
method is applied in \\(\alpha, b)\\: \$\$\widehat{\text{Var}}(B)
\approx \sum_h (a L_h^b)^2 \widehat{\text{SE}}\_h^2 +
\left(\frac{B}{\alpha}\right)^2 \text{Var}(\alpha) + \left(\sum_h B_h
\ln\frac{L_h}{L_0}\right)^2 \text{Var}(b)\$\$

The covariance term is absent by construction rather than by assumption.
Fitted on the raw \\(a, b)\\ scale the two parameters are almost
perfectly negatively correlated — typically \\\text{cor} \< -0.99\\ — so
dropping their covariance there would **overstate** the variance
severalfold, in some cases turning a 2–11% contribution into 5–49%.
Centring at \\L_0\\ makes them near-orthogonal, so the omitted term is
genuinely negligible. Take \\L_0\\ as the geometric mean length of the
calibration sample, and take `alpha_se` from the intercept of a
regression centred there — not the standard error of `a` itself.

The contribution grows with \\\ln(L_h / L_0)\\, so borrowing parameters
from a system whose fish differ in size from these is penalised
automatically, which is the intended behaviour.

There is deliberately no zero default for these arguments. A zero
standard error would produce a `biomass_se` identical to an unpropagated
one while appearing to have been propagated — worse than the documented
omission it would replace. When they are absent,
`attr(x, "biomass_se_params")` is `NULL` rather than `0`, and
`biomass_se` should be read as a lower bound.

Length and weight units are determined by the user: if lengths are in mm
and `a` is calibrated for mm input, weights are returned in the
corresponding unit (e.g., grams).

## See also

Other "Estimation":
[`compare_cpue_estimators()`](https://chrischizinski.github.io/tidycreel/reference/compare_cpue_estimators.md),
[`est_age_distribution()`](https://chrischizinski.github.io/tidycreel/reference/est_age_distribution.md),
[`est_compliance()`](https://chrischizinski.github.io/tidycreel/reference/est_compliance.md),
[`est_effort_camera_mi()`](https://chrischizinski.github.io/tidycreel/reference/est_effort_camera_mi.md),
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
#> Warning: ! No `n_anglers` provided — assuming 1 angler per interview.
#> ℹ Pass `n_anglers = <column>` to use actual party sizes for angler-hour
#>   normalization.
#> ℹ If the interviews really are one angler each, pass `n_anglers = 1` to state
#>   that and silence this warning.
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
