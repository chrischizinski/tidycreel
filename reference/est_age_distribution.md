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

`percent` and `cumulative_percent` are shares of the group's estimated
total, rounded to one decimal for display; `cumulative_percent`
accumulates the unrounded shares, so it reaches 100 rather than
drifting. The exception is a group whose estimated total is zero, where
there are no shares to take and both columns are `0` rather than
reaching 100.

`n` is the number of **interviews** contributing at least one aged fish
to the group. It is therefore constant across every age class of a
group, and is neither a per-class sample size nor a count of fish.

## Two-phase estimation onto the reported catch

Ages are read from a **subsample** of the catch, exactly as lengths are,
so the age-class totals are scaled onto the design-estimated reported
total rather than reporting the subsample: \\\hat{N}\_a = \hat{p}\_a
\hat{T}\\. See
[`est_length_distribution()`](https://chrischizinski.github.io/tidycreel/reference/est_length_distribution.md)
for the estimator, its variance, and where \\\hat{T}\\ comes from.
`percent` and `cumulative_percent` are unaffected. The call warns when
it rescales and aborts when no total is available (GH \#310).

## See also

Other "Estimation":
[`compare_cpue_estimators()`](https://chrischizinski.github.io/tidycreel/reference/compare_cpue_estimators.md),
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
[`estimate_total_harvest()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_harvest.md),
[`estimate_total_release()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_release.md)

## Examples

``` r
data(example_calendar)
data(example_interviews)
data(example_ages)
data(example_catch)


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
# Species catch is required to group by species: the totals are scaled onto
# the reported catch, and only this table records it per species.
design <- add_catch(design, example_catch,
  catch_uid = interview_id,
  interview_uid = interview_id,
  species = species,
  count = count,
  catch_type = catch_type
)
design <- add_ages(design, example_ages,
  age_uid = interview_id,
  interview_uid = interview_id,
  species = species,
  age = age,
  age_type = age_type
)

est_age_distribution(design, by = species)
#> Warning: ! Age totals were rescaled onto the reported catch.
#> ℹ Measured fish (weighted): 18; reported: 93 -- a factor of 5.17.
#> ℹ estimate, se and the confidence bounds describe the REPORTED catch, estimated
#>   from the measured subsample. Shares (percent) are unaffected.
#>   species age estimate       se   ci_lower  ci_upper percent cumulative_percent
#> 1    bass   2 10.00000 4.233202  1.7030763 18.296924    40.0               40.0
#> 2    bass   3 15.00000 6.524569  2.2120798 27.787920    60.0              100.0
#> 3 panfish   0  3.25000 1.899150 -0.4722657  6.972266    25.0               25.0
#> 4 panfish   1  6.50000 4.023369 -1.3856588 14.385659    50.0               75.0
#> 5 panfish   2  3.25000 3.991201 -4.5726107 11.072611    25.0              100.0
#> 6 walleye   3 12.22222 4.069220  4.2466972 20.197747    22.2               22.2
#> 7 walleye   4 18.33333 6.136191  6.3066208 30.360046    33.3               55.6
#> 8 walleye   5 12.22222 4.069220  4.2466972 20.197747    22.2               77.8
#> 9 walleye   6 12.22222 8.491868 -4.4215332 28.865978    22.2              100.0
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
