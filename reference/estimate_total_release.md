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
  missing_sections = "warn"
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

## Value

A creel_estimates S3 object with method = "product-total-release".
Estimates tibble has columns: estimate, se, ci_lower, ci_upper, n (plus
any grouping columns).

## Details

Total release is computed as Effort x RPUE. Variance is propagated using
the delta method: Var(E x R) = E^2 \* Var(R) + R^2 \* Var(E).

**Sectioned designs:** When
[`add_sections`](https://chrischizinski.github.io/tidycreel/reference/add_sections.md)
has been called on the design, each section is estimated independently.
The lake-wide total is `sum(TR_i)`, not `E_total * RPUE_pooled`. The
lake-wide SE uses the zero-covariance assumption: `sqrt(sum(se_i^2))`.

## See also

[`estimate_total_harvest`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_harvest.md),
[`estimate_release_rate`](https://chrischizinski.github.io/tidycreel/reference/estimate_release_rate.md),
[`add_catch`](https://chrischizinski.github.io/tidycreel/reference/add_catch.md)

Other "Estimation":
[`est_length_distribution()`](https://chrischizinski.github.io/tidycreel/reference/est_length_distribution.md),
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
  catch = catch_total, effort = hours_fished,
  trip_status = trip_status, trip_duration = trip_duration
)
#> ℹ No `n_anglers` provided — assuming 1 angler per interview.
#> ℹ Pass `n_anglers = <column>` to use actual party sizes for angler-hour
#>   normalization.
#> ℹ Added 22 interviews: 17 complete (77%), 5 incomplete (23%)
design <- add_catch(design, example_catch,
  catch_uid = interview_id, interview_uid = interview_id,
  species = species, count = count, catch_type = catch_type
)

# Total releases (all species combined)
total_rel <- estimate_total_release(design)
#> Warning: Small sample size for CPUE estimation.
#> ! Sample size is 22. Ratio estimates are more stable with n >= 30.
#> ℹ Variance estimates may be unstable with n < 30.
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
#> 1     224.  36.5     153.     296.    22

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
#> 1 bass        72.5  26.4    20.7     124.     22
#> 2 panfish     32.6  18.5    -3.68     68.8    22
#> 3 walleye    127.   31.4    65.6     189.     22
```
