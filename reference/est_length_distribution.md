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

## See also

Other "Estimation":
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

design <- creel_design(example_calendar, date = date, strata = day_type)
design <- add_interviews(design, example_interviews,
  catch = catch_total, effort = hours_fished, harvest = catch_kept,
  trip_status = trip_status
)
#> ℹ No `n_anglers` provided — assuming 1 angler per interview.
#> ℹ Pass `n_anglers = <column>` to use actual party sizes for angler-hour
#>   normalization.
#> ℹ Added 22 interviews: 17 complete (77%), 5 incomplete (23%)
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
#>    species length_bin bin_lower bin_upper estimate       se   ci_lower
#> 1     bass  [225,250)       225       250        1 1.000000 -0.9599640
#> 2     bass  [250,275)       250       275        1 1.000000 -0.9599640
#> 3     bass  [275,300)       275       300        6 4.213075 -2.2574750
#> 4     bass  [325,350)       325       350        5 5.000000 -4.7998199
#> 5  panfish  [150,175)       150       175        2 2.000000 -1.9199280
#> 6  panfish  [175,200)       175       200        6 6.000000 -5.7597839
#> 7  panfish  [225,250)       225       250        3 3.000000 -2.8798920
#> 8  walleye  [375,400)       375       400        4 2.380476 -0.6656475
#> 9  walleye  [400,425)       400       425        3 2.236068 -1.3826127
#> 10 walleye  [425,450)       425       450        3 3.000000 -2.8798920
#> 11 walleye  [475,500)       475       500        1 1.000000 -0.9599640
#> 12 walleye  [500,525)       500       525        2 2.000000 -1.9199280
#>     ci_upper percent cumulative_percent  n
#> 1   2.959964     7.7                7.7 22
#> 2   2.959964     7.7               15.4 22
#> 3  14.257475    46.2               61.6 22
#> 4  14.799820    38.5              100.1 22
#> 5   5.919928    18.2               18.2 22
#> 6  17.759784    54.5               72.7 22
#> 7   8.879892    27.3              100.0 22
#> 8   8.665648    30.8               30.8 22
#> 9   7.382613    23.1               53.9 22
#> 10  8.879892    23.1               77.0 22
#> 11  2.959964     7.7               84.7 22
#> 12  5.919928    15.4              100.1 22
```
