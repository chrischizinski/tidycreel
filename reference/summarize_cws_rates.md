# Compute caught-while-sought (CWS) rates by group

Computes mean caught-while-sought rates (fish per angler-hour) for
anglers targeting each species. For each interview, the rate is:
`caught_count / angler_effort` where `caught_count` is the total number
of fish caught of the species the angler was seeking, and
`angler_effort` is angler-hours (effort x n_anglers, standardized at
design time by
[`add_interviews`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md)).

## Usage

``` r
summarize_cws_rates(design, by = NULL, conf_level = 0.95)
```

## Arguments

- design:

  A `creel_design` object with interviews attached via
  [`add_interviews`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md)
  (with `species_sought`) and species catch data attached via
  [`add_catch`](https://chrischizinski.github.io/tidycreel/reference/add_catch.md).

- by:

  Optional tidy selector for grouping columns from `design$interviews`.
  Common choices: `by = species_sought` (CWS-03),
  `by = c(month, species_sought)` (CWS-02),
  `by = c(month, angler_type, species_sought)` (CWS-01). When `NULL`,
  returns a single overall rate across all interviews.

- conf_level:

  Numeric confidence level for the t-interval. Default 0.95.

## Value

A `data.frame` with class `c("creel_summary_cws_rates", "data.frame")`
and columns: grouping columns (if any), `N` (integer, interviews per
group that produced a rate), `n_unknown_target` (integer, interviews
excluded because their sought species was not recorded),
`n_unknown_effort` (integer, interviews excluded because their effort
was not recorded), `n_nonpositive_effort` (integer, interviews excluded
because their effort was zero or negative), `mean_rate` (numeric, mean
fish/angler-hour, `NA` when `N` is 0), `se` (numeric, standard error),
`ci_lower`, `ci_upper`.

## Details

**Interview-based summary, not pressure-weighted.** This function
computes a simple arithmetic mean over sampled interviews. It does NOT
apply survey weighting by sampling effort or effort stratum. For
pressure-weighted extrapolated estimates use
[`estimate_catch_rate`](https://chrischizinski.github.io/tidycreel/reference/estimate_catch_rate.md).

The catch filter ensures only species the angler was targeting are
counted (i.e., rows in `design$catch` where `catch_type == "caught"` and
`species == species_sought`).

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
[`add_catch`](https://chrischizinski.github.io/tidycreel/reference/add_catch.md).

An interview whose **effort** was not recorded is treated the same way
and counted in `n_unknown_effort`. A rate needs an effort to divide by,
and one unrecorded effort used to turn the whole group's mean into `NA`
while `N` went on counting it. The two counts are mutually exclusive,
target first, so an interview missing both is counted once.

An effort that is not **positive** cannot produce a rate either, and
those interviews are counted in `n_nonpositive_effort`. A zero is a real
record – a party interviewed before it started fishing – and a negative
one is a data error that
[`add_interviews`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md)
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

[`summarize_hws_rates()`](https://chrischizinski.github.io/tidycreel/reference/summarize_hws_rates.md),
[`estimate_catch_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_catch_rate.md)

Other "Reporting & Diagnostics":
[`adjust_nonresponse()`](https://chrischizinski.github.io/tidycreel/reference/adjust_nonresponse.md),
[`check_completeness()`](https://chrischizinski.github.io/tidycreel/reference/check_completeness.md),
[`compare_variance()`](https://chrischizinski.github.io/tidycreel/reference/compare_variance.md),
[`flag_outliers()`](https://chrischizinski.github.io/tidycreel/reference/flag_outliers.md),
[`season_summary()`](https://chrischizinski.github.io/tidycreel/reference/season_summary.md),
[`standardize_species()`](https://chrischizinski.github.io/tidycreel/reference/standardize_species.md),
[`summarize_boat_composition()`](https://chrischizinski.github.io/tidycreel/reference/summarize_boat_composition.md),
[`summarize_by_angler_type()`](https://chrischizinski.github.io/tidycreel/reference/summarize_by_angler_type.md),
[`summarize_by_county()`](https://chrischizinski.github.io/tidycreel/reference/summarize_by_county.md),
[`summarize_by_day_type()`](https://chrischizinski.github.io/tidycreel/reference/summarize_by_day_type.md),
[`summarize_by_method()`](https://chrischizinski.github.io/tidycreel/reference/summarize_by_method.md),
[`summarize_by_species_sought()`](https://chrischizinski.github.io/tidycreel/reference/summarize_by_species_sought.md),
[`summarize_by_trip_length()`](https://chrischizinski.github.io/tidycreel/reference/summarize_by_trip_length.md),
[`summarize_by_zip()`](https://chrischizinski.github.io/tidycreel/reference/summarize_by_zip.md),
[`summarize_hws_rates()`](https://chrischizinski.github.io/tidycreel/reference/summarize_hws_rates.md),
[`summarize_length_freq()`](https://chrischizinski.github.io/tidycreel/reference/summarize_length_freq.md),
[`summarize_refusals()`](https://chrischizinski.github.io/tidycreel/reference/summarize_refusals.md),
[`summarize_successful_parties()`](https://chrischizinski.github.io/tidycreel/reference/summarize_successful_parties.md),
[`summarize_trips()`](https://chrischizinski.github.io/tidycreel/reference/summarize_trips.md),
[`summary.creel_estimates()`](https://chrischizinski.github.io/tidycreel/reference/summary.creel_estimates.md),
[`tidy.creel_estimates()`](https://chrischizinski.github.io/tidycreel/reference/tidy.creel_estimates.md),
[`validate_creel_data()`](https://chrischizinski.github.io/tidycreel/reference/validate_creel_data.md),
[`validate_design()`](https://chrischizinski.github.io/tidycreel/reference/validate_design.md),
[`validate_incomplete_trips()`](https://chrischizinski.github.io/tidycreel/reference/validate_incomplete_trips.md),
[`validation_report()`](https://chrischizinski.github.io/tidycreel/reference/validation_report.md),
[`write_estimates()`](https://chrischizinski.github.io/tidycreel/reference/write_estimates.md)

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
summarize_cws_rates(d, by = species_sought)
#>   species_sought  N n_unknown_target n_unknown_effort n_nonpositive_effort
#> 1           bass  6                0                0                    0
#> 2        panfish  5                0                0                    0
#> 3        walleye 11                0                0                    0
#>   mean_rate        se    ci_lower  ci_upper
#> 1 0.2083333 0.2083333 -0.32720455 0.7438712
#> 2 0.4666667 0.4666667 -0.82900772 1.7623410
#> 3 0.7835498 0.3359583  0.03498793 1.5321116
```
