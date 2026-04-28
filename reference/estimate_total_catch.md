# Estimate total catch by combining effort and CPUE

Computes total catch estimates by multiplying effort × CPUE with
variance propagation via the delta method. Requires a creel design with
both count data (for effort estimation) and interview data (for CPUE
estimation).

## Usage

``` r
estimate_total_catch(
  design,
  by = NULL,
  variance = "taylor",
  conf_level = 0.95,
  target = c("sampled_days", "stratum_total", "period_total"),
  aggregate_sections = TRUE,
  missing_sections = "warn",
  verbose = FALSE
)
```

## Arguments

- design:

  A creel_design object with both counts (via
  [`add_counts`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md))
  and interviews (via
  [`add_interviews`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md))
  attached. Both count and interview survey objects must exist.

- by:

  Optional tidy selector for grouping variables. When specified, must
  match across both effort and CPUE estimates (same calendar strata or
  interview variables). Accepts bare column names, multiple columns, or
  tidyselect helpers.

- variance:

  Character string specifying variance estimation method: "taylor"
  (default), "bootstrap", or "jackknife". Applied to BOTH effort and
  CPUE estimation, then combined via delta method.

- conf_level:

  Numeric confidence level (default: 0.95)

- target:

  Character string specifying the effort domain supplied to
  [`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md).
  Options are `"sampled_days"` (default), `"stratum_total"`, or
  `"period_total"`. This controls which effort domain is multiplied by
  CPUE so total catch stays aligned with the requested temporal target.

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

- verbose:

  Logical. If TRUE, prints an informational message identifying which
  estimator path was used. Default FALSE.

## Value

A creel_estimates S3 object with method = "product-total-catch". For
bus-route designs, returns a bus-route HT estimate with method = "total"
and a "site_contributions" attribute. For sectioned designs, returns
per-section rows plus (by default) a `.lake_total` row. The lake-wide
total is computed as `sum(TC_i)` over sections, never as
`E_total * CPUE_pooled`.

## Details

Total catch is computed as Effort × CPUE. Variance is propagated using
the delta method, which accounts for uncertainty in both estimates. The
formula for independent estimates is approximately:

\$\$Var(E \times C) \approx E^2 \cdot Var(C) + C^2 \cdot Var(E)\$\$

The function uses survey::svycontrast() to compute variance
automatically via symbolic differentiation and Taylor series
approximation.

**Sectioned designs:** When
[`add_sections`](https://chrischizinski.github.io/tidycreel/reference/add_sections.md)
has been called on the design, each section is estimated independently
using its own count survey (via `rebuild_counts_survey`) and interview
survey (via `rebuild_interview_survey`). The lake-wide total is the
arithmetic sum `sum(TC_i)`, not `E_total * CPUE_pooled`. The lake-wide
SE uses the zero-covariance assumption: `sqrt(sum(se_i^2))`.
Cross-section covariance between count-based effort and interview-based
CPUE designs is not identified and is therefore assumed zero.

**Design compatibility requirements:**

- Count data must be attached via
  [`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)
  for effort estimation

- Interview data must be attached via
  [`add_interviews()`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md)
  for CPUE estimation

- Grouped estimation requires identical grouping variables for both
  estimates

- Calendar stratification must be shared between counts and interviews

## See also

[`estimate_effort`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md),
[`estimate_catch_rate`](https://chrischizinski.github.io/tidycreel/reference/estimate_catch_rate.md)

Other "Estimation":
[`est_length_distribution()`](https://chrischizinski.github.io/tidycreel/reference/est_length_distribution.md),
[`estimate_catch_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_catch_rate.md),
[`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md),
[`estimate_effort_aerial_glmm()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort_aerial_glmm.md),
[`estimate_harvest_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_harvest_rate.md),
[`estimate_release_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_release_rate.md),
[`estimate_total_harvest()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_harvest.md),
[`estimate_total_release()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_release.md)

## Examples

``` r
library(tidycreel)
data(example_calendar)
data(example_counts)
data(example_interviews)

# Create design with both counts and interviews
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

# Estimate total catch
total_catch <- estimate_total_catch(design)
print(total_catch)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Total Catch (Effort × CPUE)
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Effort target: sampled_days
#> 
#> # A tibble: 1 × 5
#>   estimate    se ci_lower ci_upper     n
#>      <dbl> <dbl>    <dbl>    <dbl> <int>
#> 1     858.  48.4     763.     953.    17

# Compare components
effort_est <- estimate_effort(design)
cpue_est <- estimate_catch_rate(design)
#> ℹ Using complete trips for CPUE estimation
#>   (n=17, 77.3% of 22 interviews) [default]
#> Warning: Small sample size for CPUE estimation.
#> ! Sample size is 17. Ratio estimates are more stable with n >= 30.
#> ℹ Variance estimates may be unstable with n < 30.
# total_catch$estimates$estimate approximately equals effort_est * cpue_est

# Note: Grouped estimation requires n >= 10 per group
# Check sample sizes before grouping:
# table(design$interviews$day_type)
# total_catch_by_type <- estimate_total_catch(design, by = day_type)

# Verbose dispatch message (shows which estimator was used for bus-route designs)
# result_verbose <- estimate_total_catch(design, verbose = TRUE)
```
