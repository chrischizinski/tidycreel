# Estimate a weighted length distribution from creel interview data

`est_length_distribution()` estimates a pressure-weighted
length-frequency distribution from fish length data attached via
[`add_lengths()`](https://chrischizinski.github.io/tidycreel/reference/add_lengths.md).
Unlike
[`summarize_length_freq()`](https://chrischizinski.github.io/tidycreel/reference/summarize_length_freq.md),
which reports raw sample frequencies, `est_length_distribution()`
aggregates interview-level bin counts through the internal interview
survey design so the result reflects the survey design rather than only
the observed sample.

The estimator returns one row per occupied length bin, with weighted
totals, standard errors, confidence intervals, and within-group
percentages.

Lengths are measured on a **subsample** of the catch, so the bin totals
are scaled onto the design-estimated reported catch rather than
reporting the subsample itself. See the section below; the call warns
whenever it rescales, and aborts when the design carries no total to
scale to.

## Usage

``` r
est_length_distribution(
  design,
  type = "catch",
  by = NULL,
  bin_width = 1,
  length_col = NULL,
  variance = "taylor",
  conf_level = 0.95
)
```

## Arguments

- design:

  A `creel_design` object with interviews and lengths attached.

- type:

  Character string indicating which fish to include. One of `"catch"`
  (default), `"harvest"`, or `"release"`.

- by:

  Optional tidy selector evaluated against `design$lengths`. Common
  choices include `by = species`.

- bin_width:

  Positive numeric bin width in the same units as the attached length
  data. Default `1`.

- length_col:

  Optional character column name in `design$lengths` to use for the
  length values. Defaults to the column registered by
  [`add_lengths()`](https://chrischizinski.github.io/tidycreel/reference/add_lengths.md).

- variance:

  Character string specifying variance estimation method. One of
  `"taylor"` (default), `"bootstrap"`, or `"jackknife"`.

- conf_level:

  Numeric confidence level for confidence intervals. Default `0.95`.

## Value

A `data.frame` with class `c("creel_length_distribution", "data.frame")`
and columns: grouping columns (if any), `length_bin` (ordered factor),
`bin_lower`, `bin_upper`, `estimate`, `se`, `ci_lower`, `ci_upper`,
`percent`, `cumulative_percent`, and `n`.

`percent` and `cumulative_percent` are shares of the group's estimated
total, rounded to one decimal for display; `cumulative_percent`
accumulates the unrounded shares, so it reaches 100 rather than
drifting. The exception is a group whose estimated total is zero, where
there are no shares to take and both columns are `0` rather than
reaching 100.

`n` is the number of **interviews** contributing at least one measured
fish to the group. It is therefore constant across every bin of a group,
and is neither a per-bin sample size nor a count of fish.

## Two-phase estimation onto the reported catch

Lengths are a second-phase sample: interviews report how many fish were
caught, and some subset of those fish get measured. Expanding the
measured fish through the interview design alone estimates *the total
number of fish that happened to be measured*, which is not the catch —
on this package's example data it returns 14 against a reported harvest
of 77. Because
[`est_biomass()`](https://chrischizinski.github.io/tidycreel/reference/est_biomass.md)
multiplies these counts by weight-at-length and calls the result total
biomass, the error propagated to a headline number (GH \#310).

The estimator is therefore two-phase (double sampling, Cochran 1977
§12.9 — the same structure used for the camera calibration ratio). For
bin \\h\\: \$\$\hat{p}\_h = \hat{N}\_h^{\text{meas}} / \sum_j
\hat{N}\_j^{\text{meas}}, \qquad \hat{N}\_h = \hat{p}\_h \hat{T}\$\$
where \\\hat{T}\\ is the design-estimated reported total for the group.
Both parts come from a single
[`svytotal()`](https://rdrr.io/pkg/survey/man/surveysummary.html) call,
so the covariance between a bin and the reported total is estimated
rather than assumed away, and the standard error is the delta method
over that joint covariance.

What this changes: `estimate`, `se` and the confidence bounds now
describe the reported catch. `percent` and `cumulative_percent` are
unchanged — a share is invariant to the subsample size, which is why the
*shape* of the distribution was always correct and only its *level* was
not.

Where \\\hat{T}\\ comes from depends on the grouping. A species group
can only be scaled by that species' own total, which lives in the table
attached by
[`add_catch()`](https://chrischizinski.github.io/tidycreel/reference/add_catch.md);
grouping by species without it is refused rather than scaled by the
all-species total. Any other grouping uses the interview-level column
(`catch` or `harvest` from
[`add_interviews()`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md)),
with release implied as caught − harvested so that harvest and release
sum back to catch.

## See also

Other "Estimation":
[`compare_cpue_estimators()`](https://chrischizinski.github.io/tidycreel/reference/compare_cpue_estimators.md),
[`est_age_distribution()`](https://chrischizinski.github.io/tidycreel/reference/est_age_distribution.md),
[`est_biomass()`](https://chrischizinski.github.io/tidycreel/reference/est_biomass.md),
[`est_compliance()`](https://chrischizinski.github.io/tidycreel/reference/est_compliance.md),
[`est_effort_camera_mi()`](https://chrischizinski.github.io/tidycreel/reference/est_effort_camera_mi.md),
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
design <- add_lengths(design, example_lengths,
  length_uid = interview_id,
  interview_uid = interview_id,
  species = species,
  length = length,
  length_type = length_type,
  count = count,
  release_format = "binned"
)

est_length_distribution(design, by = species, bin_width = 25)
#> Warning: ! Length totals were rescaled onto the reported catch.
#> ℹ Measured fish (weighted): 37; reported: 50 -- a factor of 1.35.
#> ℹ estimate, se and the confidence bounds describe the REPORTED catch, estimated
#>   from the measured subsample. Shares (percent) are unaffected.
#>    species length_bin bin_lower bin_upper   estimate       se  ci_lower
#> 1     bass  [225,250)       225       250  0.7692308 1.039230 -1.267622
#> 2     bass  [250,275)       250       275  0.7692308 1.039230 -1.267622
#> 3     bass  [275,300)       275       300  4.6153846 3.142368 -1.543544
#> 4     bass  [325,350)       325       350  3.8461538 2.834555 -1.709472
#> 5  panfish  [150,175)       150       175  1.2727273 2.615490 -3.853540
#> 6  panfish  [175,200)       175       200  3.8181818 3.143192 -2.342360
#> 7  panfish  [225,250)       225       250  1.9090909 1.571596 -1.171180
#> 8  walleye  [375,400)       375       400 10.1538462 3.979343  2.354477
#> 9  walleye  [400,425)       400       425  7.6153846 6.193515 -4.523683
#> 10 walleye  [425,450)       425       450  7.6153846 5.424938 -3.017299
#> 11 walleye  [475,500)       475       500  2.5384615 1.808313 -1.005766
#> 12 walleye  [500,525)       500       525  5.0769231 3.616626 -2.011533
#>     ci_upper percent cumulative_percent n
#> 1   2.806084     7.7                7.7 3
#> 2   2.806084     7.7               15.4 3
#> 3  10.774314    46.2               61.5 3
#> 4   9.401780    38.5              100.0 3
#> 5   6.398994    18.2               18.2 2
#> 6   9.978724    54.5               72.7 2
#> 7   4.989362    27.3              100.0 2
#> 8  17.953215    30.8               30.8 3
#> 9  19.754452    23.1               53.8 3
#> 10 18.248069    23.1               76.9 3
#> 11  6.082690     7.7               84.6 3
#> 12 12.165379    15.4              100.0 3
```
