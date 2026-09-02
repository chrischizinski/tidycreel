# Estimate release rate (RPUE: Released fish Per Unit Effort) from a creel survey design

Computes release rate estimates with standard errors and confidence
intervals from a creel survey design with attached interview and catch
data. Uses ratio-of-means estimation via survey::svyratio(). RPUE
measures the rate of released fish per unit effort, analogous to HPUE
for harvested fish.

## Usage

``` r
estimate_release_rate(
  design,
  by = NULL,
  variance = "taylor",
  conf_level = 0.95,
  use_trips = NULL,
  estimator = NULL,
  truncate_at = 0.5,
  missing_sections = "warn"
)
```

## Arguments

- design:

  A creel_design object with interviews (via
  [`add_interviews`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md))
  and catch data (via
  [`add_catch`](https://chrischizinski.github.io/tidycreel/reference/add_catch.md))
  attached. The catch data must include records with
  `catch_type = "released"`.

- by:

  Optional tidy selector for grouping variables. Accepts bare column
  names (e.g., `by = day_type`, `by = species`), multiple columns, or
  tidyselect helpers. When species grouping is used, per-species release
  rates are estimated.

- variance:

  Character string specifying variance estimation method. Options:
  `"taylor"` (default), `"bootstrap"`, or `"jackknife"`.

- conf_level:

  Numeric confidence level (default: 0.95).

- use_trips:

  Character string specifying which interviews to include. `"complete"`
  (default) restricts to completed trips only; `"all"` uses all
  interviews including incomplete trips. `"complete"` is the
  statistically preferred default because incomplete-trip RPUE
  underestimates releases when anglers release additional fish after the
  interview (Hansen & Van Kirk 2010). `"all"` remains available for
  analyses that prefer the larger interview set. When `trip_status` was
  not provided to
  [`add_interviews`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md),
  this argument has no effect. For bus-route designs: `"complete"`
  (default), `"incomplete"`, or `"diagnostic"`, matching
  [`estimate_harvest_rate`](https://chrischizinski.github.io/tidycreel/reference/estimate_harvest_rate.md);
  `"all"` is not an estimator there, and unrecognised values are an
  error rather than a silent fall-through to the complete-trip path.

- estimator:

  Character string selecting the rate estimator: `"ratio-of-means"` (a
  ratio of totals), `"mor"` (the mean of per-interview ratios), or
  `"mortr"` (`"mor"` with truncation made mandatory). Default `NULL`
  means "not specified". When `use_trips` and `estimator` are *both*
  unspecified and the design was built with
  `add_interviews(interview_type = "roving")`, the pair resolves to
  all-trip truncated MOR; otherwise it resolves to complete-trip
  ratio-of-means. Specifying either one suppresses the automatic
  routing.

  Hoenig et al. (1997) recommend the truncated mean of ratios for a
  roving survey because the clerk intercepts trips mid-stream. That
  argument is about the interview rather than about which fish are
  counted, so it applies to this rate exactly as it applies to the catch
  rate. Bus-route and ice designs return before this resolution and are
  unaffected.

- truncate_at:

  Numeric minimum trip duration in hours for the mean-of-ratios
  estimator (default `0.5`, i.e. 30 minutes). Trips shorter than this
  are discarded before the mean of ratios is taken. Hoenig et al. (1997)
  recommend the 30-minute threshold because the untruncated
  mean-of-ratios estimator has infinite asymptotic variance: `1/L` has
  infinite expectation as trip length approaches zero. The threshold
  applies to elapsed trip duration, not to angler-hours. Set to `NULL`
  to disable; the bus-route path warns when it is disabled there, the
  standard mean-of-ratios path treats it as a documented opt-out and is
  silent, matching
  [`estimate_catch_rate`](https://chrischizinski.github.io/tidycreel/reference/estimate_catch_rate.md).
  Ignored under `"ratio-of-means"`. An interview whose duration is
  missing cannot be shown to meet the threshold, so it is excluded and
  reported separately from the trips excluded as too short.

- missing_sections:

  Character string controlling behavior when a registered section has no
  interview observations. `"warn"` (default) emits a `cli_warn()` and
  inserts an NA row with `data_available = FALSE`. `"error"` aborts with
  `cli_abort()`. Ignored for non-sectioned designs.

## Value

A creel_estimates S3 object with method = "ratio-of-means-rpue".
Estimates tibble has columns: estimate, se, ci_lower, ci_upper, n (plus
any grouping columns). The `estimator` component records the estimator
as you asked for it, `"mortr"` included, which `method` cannot: it
reports mandatory truncation and the default threshold with the same
string.

## Details

RPUE is estimated as the ratio of total released fish to total effort
(ratio-of-means). Release data comes from
[`add_catch()`](https://chrischizinski.github.io/tidycreel/reference/add_catch.md)
records with `catch_type = "released"`. Interviews with no releases
contribute 0 to the numerator (zero-fill), ensuring the effort
denominator is correct.

## Note

Bus-route designs use a different estimator for each trip type, matching
[`estimate_harvest_rate`](https://chrischizinski.github.io/tidycreel/reference/estimate_harvest_rate.md).
`use_trips = "complete"` returns the ratio of the two Horvitz-Thompson
totals (Jones & Pollock 2012, Eq. 19.5 / Eq. 19.4) and reports
`method = "ratio-of-means-rpue"`; `use_trips = "incomplete"` returns the
truncated, Hajek-weighted mean of per-angler rates (Hoenig et al. 1997)
and reports `method = "mean-of-ratios-rpue"`. Both are releases per
angler-hour.

When called on a sectioned design, no `.lake_total` row is produced.
Release rates (fish per angler-hour) are not additive across sections.
Lake-wide release rate requires a separate unsectioned call.

This function defaults to using **completed-trip** interviews only for
RPUE estimation (`use_trips = "complete"`). Incomplete-trip RPUE may
underestimate releases if anglers release additional fish after the
interview (Hansen & Van Kirk 2010), so restricting to completed trips is
the statistically preferred default. Released fish counted at interview
time are directly observable, so `use_trips = "all"` remains available
to include incomplete-trip interviews.

## See also

[`estimate_harvest_rate`](https://chrischizinski.github.io/tidycreel/reference/estimate_harvest_rate.md)
for harvest rate,
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
[`estimate_total_catch()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_catch.md),
[`estimate_total_harvest()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_harvest.md),
[`estimate_total_release()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_release.md)

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
#> Warning: ! No `n_anglers` provided — assuming 1 angler per interview.
#> ℹ Pass `n_anglers = <column>` to use actual party sizes for angler-hour
#>   normalization.
#> ℹ If the interviews really are one angler each, pass `n_anglers = 1` to state
#>   that and silence this warning.
#> ℹ Added 22 interviews: 17 complete (77%), 5 incomplete (23%)
design <- add_catch(design, example_catch,
  catch_uid = interview_id,
  interview_uid = interview_id,
  species = species,
  count = count,
  catch_type = catch_type
)

# Overall release rate (all species combined)
rpue <- estimate_release_rate(design)
#> ℹ Filtering to complete trips for RPUE estimation
#>   (n=17, 77.3% of 22 interviews) [default]
#> Warning: Small sample size for CPUE estimation.
#> ! Sample size is 17. Ratio estimates are more stable with n >= 30.
#> ℹ Variance estimates may be unstable with n < 30.
print(rpue)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: ratio-of-means-rpue
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Unit: fish/party-hour
#> 
#> # A tibble: 1 × 5
#>   estimate    se ci_lower ci_upper     n
#>      <dbl> <dbl>    <dbl>    <dbl> <int>
#> 1    0.615 0.105    0.409    0.822    17

# Per-species release rates
rpue_by_species <- estimate_release_rate(design, by = species)
#> ℹ Filtering to complete trips for RPUE estimation
#>   (n=17, 77.3% of 22 interviews) [default]
#> Warning: Small sample size for CPUE estimation.
#> ! Sample size is 17. Ratio estimates are more stable with n >= 30.
#> ℹ Variance estimates may be unstable with n < 30.
#> Warning: Small sample size for CPUE estimation.
#> ! Sample size is 17. Ratio estimates are more stable with n >= 30.
#> ℹ Variance estimates may be unstable with n < 30.
#> Warning: Small sample size for CPUE estimation.
#> ! Sample size is 17. Ratio estimates are more stable with n >= 30.
#> ℹ Variance estimates may be unstable with n < 30.
print(rpue_by_species)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: ratio-of-means-rpue
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Grouped by: species
#> Unit: fish/party-hour
#> 
#> # A tibble: 3 × 6
#>   species estimate     se ci_lower ci_upper     n
#>   <chr>      <dbl>  <dbl>    <dbl>    <dbl> <int>
#> 1 bass      0.242  0.0904  0.0645    0.419     17
#> 2 panfish   0.0440 0.0268 -0.00849   0.0964    17
#> 3 walleye   0.330  0.0870  0.159     0.500     17
```
