# Estimate a weighted age distribution from creel interview data

`est_age_distribution()` estimates a pressure-weighted age-frequency
distribution from fish age data attached via
[`add_ages()`](https://chrischizinski.github.io/tidycreel/reference/add_ages.md).
Age records are aggregated through the internal interview survey design
so the result reflects the survey design rather than only the observed
sample.

Ages are discrete integers; each unique observed age is its own class.
The estimator returns one row per occupied integer age, with weighted
totals, standard errors, confidence intervals, and within-group
percentages.

## Usage

``` r
est_age_distribution(
  design,
  by = NULL,
  type = "catch",
  variance = "taylor",
  conf_level = 0.95
)
```

## Arguments

- design:

  A `creel_design` object with interviews and ages attached.

- by:

  Optional tidy selector evaluated against `design$ages`. Common choices
  include `by = species`.

- type:

  Character string indicating which fish to include. One of `"catch"`
  (default; both harvest and release), `"harvest"`, or `"release"`.

- variance:

  Character string specifying variance estimation method. One of
  `"taylor"` (default), `"bootstrap"`, or `"jackknife"`.

- conf_level:

  Numeric confidence level for confidence intervals. Default `0.95`.

## Value

A `data.frame` with class `c("creel_age_distribution", "data.frame")`
and columns: grouping columns (if any), `age` (integer), `estimate`,
`se`, `ci_lower`, `ci_upper`, `percent`, `cumulative_percent`, and `n`.

## See also

Other "Estimation":
[`compare_cpue_estimators()`](https://chrischizinski.github.io/tidycreel/reference/compare_cpue_estimators.md),
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

## Examples

``` r
data(example_calendar)
data(example_interviews)
data(example_ages)

design <- creel_design(example_calendar, date = date, strata = day_type)
design <- add_interviews(design, example_interviews,
  catch = catch_total, effort = hours_fished, harvest = catch_kept,
  trip_status = trip_status
)
#> ℹ No `n_anglers` provided — assuming 1 angler per interview.
#> ℹ Pass `n_anglers = <column>` to use actual party sizes for angler-hour
#>   normalization.
#> ℹ Added 22 interviews: 17 complete (77%), 5 incomplete (23%)
design <- add_ages(design, example_ages,
  age_uid = interview_id,
  interview_uid = interview_id,
  species = species,
  age = age,
  age_type = age_type
)

est_age_distribution(design, by = species)
#>   species age estimate       se   ci_lower ci_upper percent cumulative_percent
#> 1    bass   2        2 1.414214 -0.7718076 4.771808    40.0               40.0
#> 2    bass   3        3 1.658312 -0.2502326 6.250233    60.0              100.0
#> 3 panfish   0        1 1.000000 -0.9599640 2.959964    25.0               25.0
#> 4 panfish   1        2 1.354006 -0.6538038 4.653804    50.0               75.0
#> 5 panfish   2        1 1.000000 -0.9599640 2.959964    25.0              100.0
#> 6 walleye   3        2 1.414214 -0.7718076 4.771808    22.2               22.2
#> 7 walleye   4        3 1.683251 -0.2991110 6.299111    33.3               55.5
#> 8 walleye   5        2 1.414214 -0.7718076 4.771808    22.2               77.7
#> 9 walleye   6        2 2.000000 -1.9199280 5.919928    22.2               99.9
#>   n
#> 1 3
#> 2 3
#> 3 2
#> 4 2
#> 5 2
#> 6 3
#> 7 3
#> 8 3
#> 9 3
```
