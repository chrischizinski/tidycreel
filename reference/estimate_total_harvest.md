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
  aggregate_sections = TRUE,
  missing_sections = "warn"
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

A creel_estimates S3 object with method = "product-total-harvest"

## Details

Total harvest is computed as Effort × HPUE. Variance is propagated using
the delta method, which accounts for uncertainty in both estimates. The
formula for independent estimates is approximately:

\$\$Var(E \times H) \approx E^2 \cdot Var(H) + H^2 \cdot Var(E)\$\$

The function uses survey::svycontrast() to compute variance
automatically via symbolic differentiation and Taylor series
approximation.

**Sectioned designs:** When
[`add_sections`](https://chrischizinski.github.io/tidycreel/reference/add_sections.md)
has been called on the design, each section is estimated independently.
The lake-wide total is `sum(TH_i)`, not `E_total * HPUE_pooled`. The
lake-wide SE uses the zero-covariance assumption: `sqrt(sum(se_i^2))`.

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

## See also

[`estimate_effort`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md),
[`estimate_harvest_rate`](https://chrischizinski.github.io/tidycreel/reference/estimate_harvest_rate.md),
[`estimate_total_catch`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_catch.md)

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
  trip_status = trip_status, trip_duration = trip_duration
)
#> ℹ No `n_anglers` provided — assuming 1 angler per interview.
#> ℹ Pass `n_anglers = <column>` to use actual party sizes for angler-hour
#>   normalization.
#> ℹ Added 22 interviews: 17 complete (77%), 5 incomplete (23%)

# Estimate total harvest
total_harvest <- estimate_total_harvest(design)
#> Warning: Small sample size for harvest estimation.
#> ! Sample size is 22. Ratio estimates are more stable with n >= 30.
#> ℹ Variance estimates may be unstable with n < 30.
print(total_harvest)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Total Harvest (Effort × HPUE)
#> Variance: Taylor linearization
#> Confidence level: 95%
#> 
#> # A tibble: 1 × 5
#>   estimate    se ci_lower ci_upper     n
#>      <dbl> <dbl>    <dbl>    <dbl> <int>
#> 1     508.  41.8     426.     590.    22

# Compare components
effort_est <- estimate_effort(design)
hpue_est <- estimate_harvest_rate(design)
#> Warning: Small sample size for harvest estimation.
#> ! Sample size is 22. Ratio estimates are more stable with n >= 30.
#> ℹ Variance estimates may be unstable with n < 30.
# total_harvest$estimates$estimate approximately equals effort_est * hpue_est

# Note: Grouped estimation requires n >= 10 per group
# Check sample sizes before grouping:
# table(design$interviews$day_type)
# total_harvest_by_type <- estimate_total_harvest(design, by = day_type)
```
