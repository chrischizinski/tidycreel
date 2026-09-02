# Estimate total extrapolated release by combining effort and release rate

Computes total release estimates by multiplying effort x RPUE with
variance propagation via the delta method. Requires a creel design with
count data (for effort estimation), interview data (for effort), and
catch data (via
[`add_catch`](https://chrischizinski.github.io/tidycreel/reference/add_catch.md))
containing released records.

## Usage

``` r
estimate_total_release(
  design,
  by = NULL,
  variance = "taylor",
  conf_level = 0.95,
  target = c("sampled_days", "stratum_total", "period_total"),
  use_trips = NULL,
  estimator = NULL,
  truncate_at = 0.5,
  aggregate_sections = TRUE,
  missing_sections = "warn",
  product_variance = c("goodman", "first_order"),
  ci_type = c("symmetric", "log")
)
```

## Arguments

- design:

  A creel_design object with counts (via
  [`add_counts`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)),
  interviews (via
  [`add_interviews`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md)),
  and catch data (via
  [`add_catch`](https://chrischizinski.github.io/tidycreel/reference/add_catch.md))
  attached. Catch data must include records with
  `catch_type = "released"`.

- by:

  Optional tidy selector for grouping variables. Accepts bare column
  names (e.g., `by = day_type`, `by = species`), multiple columns, or
  tidyselect helpers.

- variance:

  Character string specifying variance estimation method: "taylor"
  (default), "bootstrap", or "jackknife". Applied to BOTH effort and
  release rate estimation, then combined via delta method.

- conf_level:

  Numeric confidence level (default: 0.95).

- target:

  Character string specifying the effort domain supplied to
  [`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md).
  Options are `"sampled_days"` (default), `"stratum_total"`, or
  `"period_total"`. This controls which effort domain is multiplied by
  release rate so total release stays aligned with the requested
  temporal target.

- use_trips:

  Character. Which interviews contribute to RPUE. `"complete"` uses only
  completed trips; `"all"` includes incomplete ones. Default `NULL`
  means "not specified", which resolves to `"complete"`. An interview
  taken mid-trip reports the releases so far against the effort so far,
  and the two do not scale together over the trip, so `"all"` gives a
  length-biased rate and a total built from it. Ignored when the design
  carries no trip status column.

  Since GH \#271 a roving design routes to all-trip mean-of-ratios here,
  as it does for
  [`estimate_total_catch()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_catch.md),
  because
  [`estimate_release_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_release_rate.md)
  gained the same estimator selection. Both resolve through the same
  rule, so the total always agrees with its own rate function.

- estimator:

  Character string selecting the rate estimator used for the RPUE
  component: `"ratio-of-means"`, `"mor"`, or `"mortr"`. Default `NULL`
  means "not specified"; see
  [`estimate_release_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_release_rate.md)
  for how the pair resolves and when the roving auto-route applies.
  Bus-route and ice designs accept only `"ratio-of-means"`, because
  their total is a ratio of Horvitz-Thompson totals with no
  mean-of-ratios form.

- truncate_at:

  Numeric minimum trip duration in hours for MOR, or `NULL` to disable
  truncation. Default 0.5 (30 minutes) per Hoenig et al. (1997).
  Truncation is not a tuning knob: the untruncated mean-of-ratios
  estimator has infinite variance. Ignored under ratio-of-means.

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

- product_variance:

  character. Variance formula for the product \\E \times R\\.
  `"goodman"` (default) uses Goodman's (1960) unbiased estimator \\E^2
  Var(R) + R^2 Var(E) - Var(E)Var(R)\\; `"first_order"` omits the
  cross-term, which is conservative. Both assume \\E\\ and \\R\\ are
  independently estimated. When both components are so imprecise that
  the subtraction would give a non-positive variance, the first-order
  value is used as a floor.

- ci_type:

  character. Shape of the confidence interval. `"symmetric"` (default)
  gives \\\hat\theta \pm z \cdot SE\\ clamped at zero. `"log"` applies a
  log-transform for a strictly positive CI.

## Value

A creel_estimates S3 object with method = "product-total-release". The
`estimator` component records the rate estimator this total is a product
of, as you asked for it: `method` names the product form and is the same
string whichever estimator produced it. Estimates tibble has columns:
estimate, se, ci_lower, ci_upper, n (plus any grouping columns). For
bus-route and ice designs, returns a bus-route HT estimate with method =
"ht-total-release" and a "site_contributions" attribute.

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

Total release is computed as Effort x RPUE. Variance is propagated using
the delta method: Var(E x R) = E^2 \* Var(R) + R^2 \* Var(E).

**Sectioned designs:** When
[`add_sections`](https://chrischizinski.github.io/tidycreel/reference/add_sections.md)
has been called on the design, each section is estimated independently.
The lake-wide total is `sum(TR_i)`, not `E_total * RPUE_pooled`. The
lake-wide SE uses the zero-covariance assumption: `sqrt(sum(se_i^2))`.

`by = <species>` is supported on a sectioned design: catch is
apportioned against each section's own whole effort, giving one row per
section per species. As with any other grouping, the sectioned result
then carries no `.lake_total` row and no `prop_of_lake_total`.

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

[`estimate_total_harvest`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_harvest.md),
[`estimate_release_rate`](https://chrischizinski.github.io/tidycreel/reference/estimate_release_rate.md),
[`add_catch`](https://chrischizinski.github.io/tidycreel/reference/add_catch.md)

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
[`estimate_total_harvest()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_harvest.md)

## Examples

``` r
library(tidycreel)
data(example_calendar)
data(example_counts)
data(example_interviews)
data(example_catch)

design <- creel_design(example_calendar, date = date, strata = day_type)
design <- add_counts(design, example_counts)
#> Warning: No weights or probabilities supplied, assuming equal probability
design <- add_interviews(design, example_interviews,
  catch = catch_total, effort = hours_fished, n_anglers = n_anglers,
  trip_status = trip_status, trip_duration = trip_duration
)
#> ℹ Added 22 interviews: 17 complete (77%), 5 incomplete (23%)
design <- add_catch(design, example_catch,
  catch_uid = interview_id, interview_uid = interview_id,
  species = species, count = count, catch_type = catch_type
)

# Total releases (all species combined)
total_rel <- estimate_total_release(design)
#> Warning: `estimate_total_release()` is pooling over domains the counts do not classify:
#> angler_type, angler_method, and species_sought.
#> ! The rate differs across their levels in these interviews (angler_type: bank
#>   0.222, boat 0.306, angler_method: artificial 0.333, bait 0.217, fly 0.276,
#>   and species_sought: bass 0.218, panfish 0, walleye 0.293), so the total
#>   depends on the interview sample's mix over those domains.
#> ℹ Without the domain in the counts the total is `E_total * rate_pooled`,
#>   weighted by the interview mix rather than the effort mix. Interview selection
#>   is not proportional to effort by construction (Malvestuto 1996).
#> ℹ This is a risk, not an error: the counts carry no composition to check
#>   against, so it cannot be verified from the data.
#> ℹ Classifying angler_type, angler_method, and species_sought in the count data
#>   removes the assumption -- the total becomes `sum(E_h * rate_h)`.
#> This warning is displayed once per session.
print(total_rel)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: product-total-release
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Effort target: sampled_days
#> 
#> # A tibble: 1 × 5
#>   estimate    se ci_lower ci_upper     n
#>      <dbl> <dbl>    <dbl>    <dbl> <int>
#> 1     101.  21.2     56.2     147.    17

# Total releases by species
total_rel_sp <- estimate_total_release(design, by = species)
print(total_rel_sp)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: product-total-release
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Grouped by: species
#> Effort target: sampled_days
#> 
#> # A tibble: 3 × 6
#>   species estimate    se ci_lower ci_upper     n
#>   <chr>      <dbl> <dbl>    <dbl>    <dbl> <int>
#> 1 bass       33.4  14.1      3.43     63.5    17
#> 2 panfish     9.07  3.46     1.70     16.4    17
#> 3 walleye    58.9  18.8     18.9      98.9    17
```
