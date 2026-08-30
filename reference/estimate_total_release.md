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

A creel_estimates S3 object with method = "product-total-release".
Estimates tibble has columns: estimate, se, ci_lower, ci_upper, n (plus
any grouping columns). For bus-route and ice designs, returns a
bus-route HT estimate with method = "ht-total-release" and a
"site_contributions" attribute.

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
#> 1     103.  19.1     63.4     143.    22

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
#> 1 bass        32.4 12.3      6.71     58.2    22
#> 2 panfish     14.5  8.01     0        31.2    22
#> 3 walleye     56.3 15.8     23.3      89.3    22
```
