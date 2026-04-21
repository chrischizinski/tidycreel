# Compute length frequency distribution from creel interview data

Computes length frequency distributions (count, percent, cumulative
percent) from fish length data attached via
[`add_lengths`](https://chrischizinski.github.io/tidycreel/reference/add_lengths.md).
Supports all fish (`type = "catch"`), harvested fish
(`type = "harvest"`), and released fish (`type = "release"`).

## Usage

``` r
summarize_length_freq(design, type = "catch", by = NULL, bin_width = 1)
```

## Arguments

- design:

  A `creel_design` object with length data attached via
  [`add_lengths`](https://chrischizinski.github.io/tidycreel/reference/add_lengths.md).

- type:

  Character string specifying which fish to include. One of `"catch"`
  (all fish, harvest + release combined), `"harvest"` (kept fish only),
  or `"release"` (released fish only). Default `"catch"`.

- by:

  Optional tidy selector for grouping columns from `design$lengths`.
  Common choice: `by = species`. When `NULL`, returns a single overall
  distribution.

- bin_width:

  Positive numeric specifying the width of each length bin in the same
  units as the length data (typically mm). Default `1`.

## Value

A `data.frame` with class `c("creel_summary_length_freq", "data.frame")`
and columns: grouping columns (if any), `length_bin` (ordered factor),
`N` (integer, fish count per bin), `percent` (numeric, percent of group
total), `cumulative_percent` (numeric, within group). Only bins with N
\> 0 are returned. Percent values are rounded to 1 decimal place.

## Details

**Interview-based summary, not pressure-weighted.** This function
tabulates raw length measurements from sampled interviews without
applying survey weighting by sampling effort or effort stratum. For
pressure-weighted extrapolated estimates use
[`estimate_catch_rate`](https://chrischizinski.github.io/tidycreel/reference/estimate_catch_rate.md)
or
[`estimate_harvest_rate`](https://chrischizinski.github.io/tidycreel/reference/estimate_harvest_rate.md).

**Pre-binned release format:** When length data was attached with
`release_format = "binned"`, release rows have character bin labels
(e.g., `"350-400"`) and a count column. This function parses each bin
label into a numeric midpoint and expands by count before applying
`bin_width` binning. This allows a consistent `bin_width` to be applied
to both individual and pre-binned data.

## See also

[`add_lengths()`](https://chrischizinski.github.io/tidycreel/reference/add_lengths.md),
[`summarize_cws_rates()`](https://chrischizinski.github.io/tidycreel/reference/summarize_cws_rates.md),
[`summarize_hws_rates()`](https://chrischizinski.github.io/tidycreel/reference/summarize_hws_rates.md)

Other "Reporting & Diagnostics":
[`adjust_nonresponse()`](https://chrischizinski.github.io/tidycreel/reference/adjust_nonresponse.md),
[`check_completeness()`](https://chrischizinski.github.io/tidycreel/reference/check_completeness.md),
[`compare_variance()`](https://chrischizinski.github.io/tidycreel/reference/compare_variance.md),
[`flag_outliers()`](https://chrischizinski.github.io/tidycreel/reference/flag_outliers.md),
[`season_summary()`](https://chrischizinski.github.io/tidycreel/reference/season_summary.md),
[`standardize_species()`](https://chrischizinski.github.io/tidycreel/reference/standardize_species.md),
[`summarize_by_angler_type()`](https://chrischizinski.github.io/tidycreel/reference/summarize_by_angler_type.md),
[`summarize_by_day_type()`](https://chrischizinski.github.io/tidycreel/reference/summarize_by_day_type.md),
[`summarize_by_method()`](https://chrischizinski.github.io/tidycreel/reference/summarize_by_method.md),
[`summarize_by_species_sought()`](https://chrischizinski.github.io/tidycreel/reference/summarize_by_species_sought.md),
[`summarize_by_trip_length()`](https://chrischizinski.github.io/tidycreel/reference/summarize_by_trip_length.md),
[`summarize_cws_rates()`](https://chrischizinski.github.io/tidycreel/reference/summarize_cws_rates.md),
[`summarize_hws_rates()`](https://chrischizinski.github.io/tidycreel/reference/summarize_hws_rates.md),
[`summarize_refusals()`](https://chrischizinski.github.io/tidycreel/reference/summarize_refusals.md),
[`summarize_successful_parties()`](https://chrischizinski.github.io/tidycreel/reference/summarize_successful_parties.md),
[`summarize_trips()`](https://chrischizinski.github.io/tidycreel/reference/summarize_trips.md),
[`summary.creel_estimates()`](https://chrischizinski.github.io/tidycreel/reference/summary.creel_estimates.md),
[`validate_creel_data()`](https://chrischizinski.github.io/tidycreel/reference/validate_creel_data.md),
[`validate_design()`](https://chrischizinski.github.io/tidycreel/reference/validate_design.md),
[`validate_incomplete_trips()`](https://chrischizinski.github.io/tidycreel/reference/validate_incomplete_trips.md),
[`validation_report()`](https://chrischizinski.github.io/tidycreel/reference/validation_report.md),
[`write_estimates()`](https://chrischizinski.github.io/tidycreel/reference/write_estimates.md)

## Examples

``` r
data(example_calendar)
data(example_interviews)
data(example_lengths)
d <- creel_design(example_calendar, date = date, strata = day_type)
d <- add_interviews(d, example_interviews,
  catch = catch_total, effort = hours_fished, harvest = catch_kept,
  trip_status = trip_status
)
#> ℹ No `n_anglers` provided — assuming 1 angler per interview.
#> ℹ Pass `n_anglers = <column>` to use actual party sizes for angler-hour
#>   normalization.
#> ℹ Added 22 interviews: 17 complete (77%), 5 incomplete (23%)
d <- add_lengths(d, example_lengths,
  length_uid = interview_id, interview_uid = interview_id,
  species = species, length = length,
  length_type = length_type, count = count,
  release_format = "binned"
)
summarize_length_freq(d, type = "harvest", by = species, bin_width = 25)
#>   species length_bin N percent cumulative_percent
#> 1    bass  [225,250) 1    25.0               25.0
#> 2    bass  [250,275) 1    25.0               50.0
#> 3    bass  [275,300) 2    50.0              100.0
#> 4 panfish  [150,175) 2   100.0              100.0
#> 5 walleye  [375,400) 2    25.0               25.0
#> 6 walleye  [400,425) 3    37.5               62.5
#> 7 walleye  [475,500) 1    12.5               75.0
#> 8 walleye  [500,525) 2    25.0              100.0
summarize_length_freq(d, type = "release", by = species)
#>   species length_bin N percent cumulative_percent
#> 1    bass  [275,276) 4    44.4               44.4
#> 2    bass  [325,326) 5    55.6              100.0
#> 3 panfish  [175,176) 6    66.7               66.7
#> 4 panfish  [225,226) 3    33.3              100.0
#> 5 walleye  [375,376) 2    40.0               40.0
#> 6 walleye  [425,426) 3    60.0              100.0
summarize_length_freq(d, type = "catch")
#>    length_bin N percent cumulative_percent
#> 1   [155,156) 1     2.7                2.7
#> 2   [162,163) 1     2.7                5.4
#> 3   [175,176) 6    16.2               21.6
#> 4   [225,226) 3     8.1               29.7
#> 5   [245,246) 1     2.7               32.4
#> 6   [268,269) 1     2.7               35.1
#> 7   [275,276) 4    10.8               45.9
#> 8   [278,279) 1     2.7               48.6
#> 9   [283,284) 1     2.7               51.3
#> 10  [325,326) 5    13.5               64.8
#> 11  [375,376) 2     5.4               70.2
#> 12  [385,386) 1     2.7               72.9
#> 13  [390,391) 1     2.7               75.6
#> 14  [401,402) 1     2.7               78.3
#> 15  [415,416) 1     2.7               81.0
#> 16  [420,421) 1     2.7               83.7
#> 17  [425,426) 3     8.1               91.8
#> 18  [488,489) 1     2.7               94.5
#> 19  [501,502) 1     2.7               97.2
#> 20  [512,513) 1     2.7               99.9
```
