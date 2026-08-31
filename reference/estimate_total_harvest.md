# Estimate total harvest by combining effort and HPUE

Computes total harvest estimates by multiplying effort × HPUE with
variance propagation via the delta method. Requires a creel design with
both count data (for effort estimation) and interview data (for HPUE
estimation).

## Usage

``` r
estimate_total_harvest(
  design,
  by = NULL,
  variance = "taylor",
  conf_level = 0.95,
  target = c("sampled_days", "stratum_total", "period_total"),
  aggregate_sections = TRUE,
  missing_sections = "warn",
  ci_method = c("delta", "bootstrap"),
  product_variance = c("goodman", "first_order"),
  ci_type = c("symmetric", "log")
)
```

## Arguments

- design:

  A creel_design object with both counts (via
  [`add_counts`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md))
  and interviews (via
  [`add_interviews`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md))
  attached. Both count and interview survey objects must exist.
  Interview data must include harvest column (specified via harvest
  parameter in add_interviews).

- by:

  Optional tidy selector for grouping variables. When specified, must
  match across both effort and HPUE estimates (same calendar strata or
  interview variables). Accepts bare column names, multiple columns, or
  tidyselect helpers.

- variance:

  Character string specifying variance estimation method: "taylor"
  (default), "bootstrap", or "jackknife". Applied to BOTH effort and
  HPUE estimation, then combined via delta method.

- conf_level:

  Numeric confidence level (default: 0.95)

- target:

  Character string specifying the effort domain supplied to
  [`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md).
  Options are `"sampled_days"` (default), `"stratum_total"`, or
  `"period_total"`. This controls which effort domain is multiplied by
  HPUE so total harvest stays aligned with the requested temporal
  target.

- aggregate_sections:

  Logical. When the design was created with
  [`add_sections`](https://chrischizinski.github.io/tidycreel/reference/add_sections.md),
  should a `.lake_total` row be appended that sums the per-section
  estimates? Default `TRUE`. Set to `FALSE` to return only the
  per-section rows without the lake total.

- missing_sections:

  Character(1). Action when a registered section is absent from either
  count data or interview data: `"warn"` (default) inserts an NA row
  with `data_available = FALSE`, `"error"` raises a hard error.

- ci_method:

  character. `"delta"` (default) returns only delta-method CIs.
  `"bootstrap"` additionally returns `ci_lo_boot`/`ci_hi_boot` using
  survey bootstrap resampling. Only applies to bus-route/ice designs.

- product_variance:

  character. Variance formula for the product \\E \times H\\.
  `"goodman"` (default) uses Goodman's (1960) unbiased estimator \\E^2
  Var(H) + H^2 Var(E) - Var(E)Var(H)\\; `"first_order"` omits the
  cross-term, which is conservative. Both assume \\E\\ and \\H\\ are
  independently estimated. When both components are so imprecise that
  the subtraction would give a non-positive variance, the first-order
  value is used as a floor.

- ci_type:

  character. Shape of the confidence interval. `"symmetric"` (default)
  gives \\\hat\theta \pm z \cdot SE\\ clamped at zero. `"log"` applies a
  log-transform for a strictly positive CI.

## Value

A creel_estimates S3 object with method = "product-total-harvest". For
bus-route and ice designs, returns a bus-route HT estimate with method =
"ht-total-harvest" and a "site_contributions" attribute.

For sectioned designs the per-section rows carry `prop_of_lake_total`,
the section's share of the lake-wide total, and `se_prop_of_lake_total`,
its standard error. The share is a ratio whose numerator is one of its
own denominator's terms, and whose numerator and denominator are each
products of an effort and a rate estimated from different designs, so
the error is derived by delta method from the same section variances and
covariance the `.lake_total` row's own standard error is built from. The
`.lake_total` row reports `se_prop_of_lake_total = 0`: its share of
itself is exactly 1 by construction and was never estimated. A section
with no data reports `NA` for both. Neither column is produced on the
grouped path.

## Details

Total harvest is computed as Effort × HPUE. Variance is propagated using
the delta method, which accounts for uncertainty in both estimates. The
formula for independent estimates is approximately:

\$\$Var(E \times H) \approx E^2 \cdot Var(H) + H^2 \cdot Var(E)\$\$

Variance is computed via a stratified delta-method sum in
`compute_stratum_product_sum()`, not via
[`survey::svycontrast()`](https://rdrr.io/pkg/survey/man/svycontrast.html).

**Sectioned designs:** When
[`add_sections`](https://chrischizinski.github.io/tidycreel/reference/add_sections.md)
has been called on the design, each section is estimated independently.
The lake-wide total is `sum(TH_i)`, not `E_total * HPUE_pooled`. The
lake-wide SE uses the zero-covariance assumption: `sqrt(sum(se_i^2))`.

`by = <species>` is supported on a sectioned design: catch is
apportioned against each section's own whole effort, giving one row per
section per species. As with any other grouping, the sectioned result
then carries no `.lake_total` row and no `prop_of_lake_total`.

**Design compatibility requirements:**

- Count data must be attached via
  [`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)
  for effort estimation

- Interview data must be attached via
  [`add_interviews()`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md)
  for HPUE estimation

- Harvest column must be specified in add_interviews (harvest parameter)

- Grouped estimation requires identical grouping variables for both
  estimates

- Calendar stratification must be shared between counts and interviews

## What the pooled total assumes

Effort comes from the counts, so a total can only be broken down by an
attribute the counts classify. When a domain appears in the interviews
but not in the counts, the only available total is
`E_total * rate_pooled`, where the pooled rate is a ratio of means
weighted by the *interview sample's* composition over that domain. Had
the domain been classified in the counts it would be a stratum and the
total would be `sum(E_h * rate_h)`, which is unbiased whatever the
interview composition happens to be.

The two agree only when the interview sample's effort composition
matches the true effort composition, and interview selection is not
proportional to effort by construction of the standard designs. Access
interviews intercept completed trips, over-representing anglers who must
return to a fixed point: Malvestuto (1996) notes that it is “usually
impossible to sample all angler types proportional to their level of
effort”, a particular problem for bank anglers who may be “widely
dispersed along the shoreline and not associated with well-defined
access sites”. Roving interviews are length-biased toward longer trips.
So the mix differs by design rather than by accident, and where levels
differ in rate the pooled total inherits that difference.

None of this is verifiable from within the data, because the counts
carry no composition to compare against. Where it is detectable – the
interviews hold an unclassified categorical domain and the crude rate
differs materially across its levels – a warning of class
`creel_warning_pooled_domain_mix` is raised. It flags a risk, not a
defect. Classifying the domain in the count data is what removes the
assumption.

## Unit of the total

The reported `unit` is derived from the two factors, never declared. A
total is `"fish"` only when a per-angler-hour rate multiplies an effort
in angler-hours; anything else reports `NA_character_`, meaning unknown.

Two ways to fail to cancel:

- **The effort unit is unknown.** `design$effort_unit` is `NA` whenever
  [`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)
  received no `period_length_col`, because a bare count column may be an
  instantaneous head count or effort the caller already expanded, and
  nothing can tell the two apart. Unknown times known is unknown. Supply
  `period_length_col` to make the total's unit derivable.

- **The denominators disagree.** A rate per party-hour times an effort
  in angler-hours is not a count of fish. Pass `n_anglers` to
  [`add_interviews()`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md)
  so the rate is per angler-hour.

The estimate itself is unaffected in both cases – only the label
changes. Until version 5.2.0 the unit was the literal `"fish"`
regardless of either factor (GH \#213).

## See also

[`estimate_effort`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md),
[`estimate_harvest_rate`](https://chrischizinski.github.io/tidycreel/reference/estimate_harvest_rate.md),
[`estimate_total_catch`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_catch.md)

Other "Estimation":
[`compare_cpue_estimators()`](https://chrischizinski.github.io/tidycreel/reference/compare_cpue_estimators.md),
[`est_age_distribution()`](https://chrischizinski.github.io/tidycreel/reference/est_age_distribution.md),
[`est_biomass()`](https://chrischizinski.github.io/tidycreel/reference/est_biomass.md),
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
[`estimate_total_release()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_release.md)

## Examples

``` r
library(tidycreel)
data(example_calendar)
data(example_counts)
data(example_interviews)

# Create design with both counts and interviews including harvest
design <- creel_design(example_calendar, date = date, strata = day_type)
design <- add_counts(design, example_counts)
#> Warning: No weights or probabilities supplied, assuming equal probability
design <- add_interviews(design, example_interviews,
  catch = catch_total, harvest = catch_kept, effort = hours_fished,
  n_anglers = n_anglers,
  trip_status = trip_status, trip_duration = trip_duration
)
#> ℹ Added 22 interviews: 17 complete (77%), 5 incomplete (23%)

# Estimate total harvest
total_harvest <- estimate_total_harvest(design)
#> Warning: `estimate_total_harvest()` is pooling over a domain the counts do not classify:
#> angler_method.
#> ! The rate differs across its levels in these interviews (angler_method:
#>   artificial 0.667, bait 0.519, fly 0.776), so the total depends on the
#>   interview sample's mix over that domain.
#> ℹ Without the domain in the counts the total is `E_total * rate_pooled`,
#>   weighted by the interview mix rather than the effort mix. Interview selection
#>   is not proportional to effort by construction (Malvestuto 1996).
#> ℹ This is a risk, not an error: the counts carry no composition to check
#>   against, so it cannot be verified from the data.
#> ℹ Classifying angler_method in the count data removes the assumption -- the
#>   total becomes `sum(E_h * rate_h)`.
#> This warning is displayed once per session.
print(total_harvest)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Total Harvest (Effort × HPUE)
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Effort target: sampled_days
#> 
#> # A tibble: 1 × 5
#>   estimate    se ci_lower ci_upper     n
#>      <dbl> <dbl>    <dbl>    <dbl> <int>
#> 1     229.  24.3     178.     280.    22

# Compare components
effort_est <- estimate_effort(design)
hpue_est <- estimate_harvest_rate(design)
#> ℹ Filtering to complete trips for HPUE estimation
#>   (n=17, 77.3% of 22 interviews) [default]
#> Warning: Small sample size for harvest estimation.
#> ! Sample size is 17. Ratio estimates are more stable with n >= 30.
#> ℹ Variance estimates may be unstable with n < 30.
# total_harvest$estimates$estimate approximately equals effort_est * hpue_est

# Note: Grouped estimation requires n >= 10 per group
# Check sample sizes before grouping:
# table(design$interviews$day_type)
# total_harvest_by_type <- estimate_total_harvest(design, by = day_type)
```
