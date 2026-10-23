# Compute released-while-sought (RWS) rates by group

Computes mean released-while-sought rates (fish per angler-hour) for
anglers targeting each species. For each interview, the rate is
`released_count / angler_effort`, where `released_count` is the number
of fish released of the species the angler was seeking and
`angler_effort` is angler-hours (effort x n_anglers, standardized at
design time by
[`add_interviews`](https://chrischizinski.com/tidycreel/dev/reference/add_interviews.md)).
It completes the while-sought trio with
[`summarize_cws_rates()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_cws_rates.md)
and
[`summarize_hws_rates()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_hws_rates.md).

## Usage

``` r
summarize_rws_rates(design, by = NULL, conf_level = 0.95)
```

## Arguments

- design:

  A `creel_design` object with interviews attached via
  [`add_interviews`](https://chrischizinski.com/tidycreel/dev/reference/add_interviews.md)
  (with `species_sought`) and species catch data attached via
  [`add_catch`](https://chrischizinski.com/tidycreel/dev/reference/add_catch.md).

- by:

  Optional tidy selector for grouping columns from `design$interviews`,
  e.g. `by = species_sought` or
  `by = c(month, angler_type, species_sought)`. When `NULL`, returns a
  single overall rate across all interviews.

- conf_level:

  Numeric confidence level for the t-interval. Default 0.95.

## Value

A `data.frame` with class `c("creel_summary_rws_rates", "data.frame")`
and the same columns as
[`summarize_hws_rates()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_hws_rates.md).

## Details

**Interview-based summary, not pressure-weighted.** This function
computes a simple arithmetic mean over sampled interviews. It does NOT
apply survey weighting by sampling effort or effort stratum. For
pressure-weighted extrapolated estimates use
[`estimate_release_rate`](https://chrischizinski.com/tidycreel/dev/reference/estimate_release_rate.md).

Released fish are read from `"released"` rows in `design$catch`, exactly
as
[`estimate_release_rate()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_release_rate.md)
reads them: a pair with no released row released none of that species.
Where every pair records its catch as harvested + released (the
`"caught"` row left to be inferred), each party's RWS rate is its CWS
rate minus its HWS rate, and so are the group means, since all three use
the same interviews and exclusions.

## Unrecorded grouping values

An interview whose value for a `by` column was not recorded is reported
under `"Unknown"`, sorted last, rather than dropped. Dropping it removed
the interview from the result entirely, so the remaining groups lost
their own members and their rates were computed on the survivors – on
the shipped example data that moved one group's mean rate from 0.393 to
0.762 while the table still looked complete.

A group with no interview left to rate – which happens when every one of
its members had an unrecorded target, see below – reports `NA` for
`mean_rate`, `se` and the interval, and keeps its row rather than
disappearing.

## Interviews with an unrecorded sought species

These are **excluded** from the rate and counted in `n_unknown_target`.

The numerator counts fish of the species the party was targeting. With
no target recorded nothing in the catch table can match, so such an
interview falls through the join exactly as a party that caught none of
its target does, and it used to be scored the same way – as a zero. That
asserted these parties caught none of something nobody recorded, and it
dragged down every group they belonged to: on the shipped example data,
blanking the sought species on 7 of 22 interviews took the boat group's
mean rate from `0.393` to `0.254` with `N` unchanged at 9.

Excluding them makes the estimand **the rate among parties with a known
target**. That equals the rate among all parties only if the target went
unrecorded independently of what was caught, which is an assumption
about the data rather than about the code – so `n_unknown_target` is
reported beside every rate and a reader can judge it. A party that
genuinely caught none of a *recorded* target is a real zero and still
counts, per
[`add_catch`](https://chrischizinski.com/tidycreel/dev/reference/add_catch.md).

An interview whose **effort** was not recorded is treated the same way
and counted in `n_unknown_effort`. A rate needs an effort to divide by,
and one unrecorded effort used to turn the whole group's mean into `NA`
while `N` went on counting it. The two counts are mutually exclusive,
target first, so an interview missing both is counted once.

An effort that is not **positive** cannot produce a rate either, and
those interviews are counted in `n_nonpositive_effort`. A zero is a real
record – a party interviewed before it started fishing – and a negative
one is a data error that
[`add_interviews`](https://chrischizinski.com/tidycreel/dev/reference/add_interviews.md)
already warns about; neither yields a rate. They used to be dropped with
no trace at all, so a table could report 20 of 22 interviews with
nothing in it to say the other two existed.

`N` therefore counts the interviews that produced a rate, and the
accounting closes:

    N + n_unknown_target + n_unknown_effort + n_nonpositive_effort
      == interviews in the group

The three exclusion counts are mutually exclusive, in that precedence,
so an interview missing more than one thing is counted once.

A column holding both unrecorded values and the literal value
`"Unknown"` warns: the two are pooled into one row and cannot be told
apart in the output.

## See also

[`summarize_cws_rates()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_cws_rates.md),
[`summarize_hws_rates()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_hws_rates.md),
[`estimate_release_rate()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_release_rate.md)

Other "Reporting & Diagnostics":
[`adjust_nonresponse()`](https://chrischizinski.com/tidycreel/dev/reference/adjust_nonresponse.md),
[`as_tibble.creel_estimates()`](https://chrischizinski.com/tidycreel/dev/reference/as_tibble.creel_estimates.md),
[`check_completeness()`](https://chrischizinski.com/tidycreel/dev/reference/check_completeness.md),
[`compare_variance()`](https://chrischizinski.com/tidycreel/dev/reference/compare_variance.md),
[`flag_outliers()`](https://chrischizinski.com/tidycreel/dev/reference/flag_outliers.md),
[`season_summary()`](https://chrischizinski.com/tidycreel/dev/reference/season_summary.md),
[`standardize_species()`](https://chrischizinski.com/tidycreel/dev/reference/standardize_species.md),
[`summarize_boat_composition()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_boat_composition.md),
[`summarize_by_angler_type()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_by_angler_type.md),
[`summarize_by_county()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_by_county.md),
[`summarize_by_day_type()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_by_day_type.md),
[`summarize_by_method()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_by_method.md),
[`summarize_by_species_sought()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_by_species_sought.md),
[`summarize_by_trip_length()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_by_trip_length.md),
[`summarize_by_zip()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_by_zip.md),
[`summarize_cws_rates()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_cws_rates.md),
[`summarize_hws_rates()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_hws_rates.md),
[`summarize_length_freq()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_length_freq.md),
[`summarize_refusals()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_refusals.md),
[`summarize_successful_parties()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_successful_parties.md),
[`summarize_trips()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_trips.md),
[`summary.creel_estimates()`](https://chrischizinski.com/tidycreel/dev/reference/summary.creel_estimates.md),
[`tidy.creel_estimates()`](https://chrischizinski.com/tidycreel/dev/reference/tidy.creel_estimates.md),
[`validate_creel_data()`](https://chrischizinski.com/tidycreel/dev/reference/validate_creel_data.md),
[`validate_design()`](https://chrischizinski.com/tidycreel/dev/reference/validate_design.md),
[`validate_incomplete_trips()`](https://chrischizinski.com/tidycreel/dev/reference/validate_incomplete_trips.md),
[`validation_report()`](https://chrischizinski.com/tidycreel/dev/reference/validation_report.md),
[`write_estimates()`](https://chrischizinski.com/tidycreel/dev/reference/write_estimates.md)

## Examples

``` r
data(example_calendar)
data(example_interviews)
data(example_catch)
d <- creel_design(example_calendar, date = date, strata = day_type)
d <- add_interviews(d, example_interviews,
  catch = catch_total, effort = hours_fished, harvest = catch_kept,
  trip_status = trip_status, species_sought = species_sought
)
#> Warning: ! No `n_anglers` provided — assuming 1 angler per interview.
#> ℹ Pass `n_anglers = <column>` to use actual party sizes for angler-hour
#>   normalization.
#> ℹ If the interviews really are one angler each, pass `n_anglers = 1` to state
#>   that and silence this warning.
#> ℹ Added 22 interviews: 17 complete (77%), 5 incomplete (23%)
d <- add_catch(d, example_catch,
  catch_uid = interview_id, interview_uid = interview_id,
  species = species, count = count, catch_type = catch_type
)
summarize_rws_rates(d, by = species_sought)
#>   species_sought  N n_unknown_target n_unknown_effort n_nonpositive_effort
#> 1           bass  6                0                0                    0
#> 2        panfish  5                0                0                    0
#> 3        walleye 11                0                0                    0
#>   mean_rate        se  ci_lower  ci_upper
#> 1 0.2166667 0.1424001 0.0000000 0.5827177
#> 2 0.2000000 0.2000000 0.0000000 0.7552890
#> 3 0.4556277 0.1423520 0.1384476 0.7728078
```
