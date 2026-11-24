# Check whether the interviews can represent the fishing the counts measured

A catch total multiplies counted effort by a catch rate from interviews,
and the product is right only if the interviewed trips can represent the
fishing the counts measured. The estimators check that across strata: a
total refuses a stratum with counted effort and no rate, and a rate
pooled across strata refuses a stratum fished with no usable interviews.
Nothing in them looks *within* a stratum. A morning-only interview plan
on a lake with an evening bite passes every one of those checks, and the
rate it produces describes morning trips while the effort it multiplies
covers the whole day.

## Usage

``` r
check_interview_coverage(
  design,
  periods = NULL,
  fishing_hours = NULL,
  block = 60,
  use_trips = c("complete", "incomplete", "all")
)
```

## Arguments

- design:

  A `creel_design` with `survey_type = "instantaneous"`, counts and
  interviews attached. Bus-route and ice designs are refused: their
  interviews are the effort data. Aerial and camera designs are refused:
  the counts there have no link to interview times.

- periods:

  `NULL`, or a data frame of the periods clerks interview in, with
  `start_time` and `end_time` as `"HH:MM"`: the `periods` table given to
  [`generate_schedule()`](https://chrischizinski.com/tidycreel/dev/reference/generate_schedule.md),
  whose every period has a positive probability of being worked.
  `period_id` and `hours` columns are allowed and ignored. It may carry
  any of the design's strata columns to give each stratum its own
  periods; rows without them apply to every stratum. Any other column is
  refused, so a misspelt stratum cannot quietly apply a row to every
  stratum. Periods that vary by date (a `date` column, as from
  [`daylight_shifts()`](https://chrischizinski.com/tidycreel/dev/reference/daylight_shifts.md))
  are not supported yet.

- fishing_hours:

  `NULL`, a character vector `c(start, end)` as `"HH:MM"` applying to
  every stratum, or a data frame with `start_time`, `end_time` and
  optionally strata columns, as for `periods`.

- block:

  Block length in minutes. Default 60.

- use_trips:

  Which interviewed trips the data layer compares: `"complete"`
  (default, the trips
  [`estimate_catch_rate()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_catch_rate.md)
  uses by default), `"incomplete"`, or `"all"`. A block fished only by
  trips the rate does not use is not covered for that rate.

## Value

A `creel_coverage_report`, a list with:

- plan:

  One row per stratum and block: `block_start`, `block_end` (`"HH:MM"`
  on the survey-day clock), `in_fishing_day`, and `interviewable`
  (`TRUE`, `FALSE`, or `NA` without `periods` and `fishing_hours`).

- data:

  One row per stratum and block: `mean_count`, `n_count_obs`,
  `interviewed_hours`, `n_interviews`, `effort_share`,
  `interviewed_share` and `gap`.

- summary:

  One row per stratum: `n_interviews` (of the trips in `use_trips`),
  `n_no_clock_time`, `effort_share_in_data_gaps`,
  `fishing_hours_not_interviewable` (minutes inside the fishing day
  only) and `effort_share_not_interviewable`.

- block:

  The block length in minutes.

- use_trips:

  The trips the data layer compared.

## Details

`check_interview_coverage()` compares the two by time of day, within
each stratum, in blocks of `block` minutes. It changes no estimate and
raises no warning in the estimators; it returns a report.

## Two layers, and what each can show

**The plan layer** asks whether a trip in each block of the fishing day
had any chance of being interviewed. An access-point clerk interviews
trips as they end, so a trip ending while no clerk is scheduled cannot
enter the sample at all (Pollock et al. 1994; Robson and Jones 1989); a
roving clerk meets anglers only while present. A block of the fishing
day that no interview period overlaps has zero probability of selection,
and no weighting of the trips that were interviewed can stand in for it
(Lohr 2022, sec. 1.3.4). This layer can **establish** a gap. It needs
the sampling plan, which the design does not keep: `periods`, the table
of interview periods the schedule was drawn from, and `fishing_hours`,
the fishing day. Without them it reports `NA`, never "covered".

**The data layer** compares, block by block, the effort the counts saw
with the fishing the interviewed trips did. A count is the number of
anglers present at an instant, so the mean count in a block stands for
the block's effort; the interviewed fishing is the hours each
interviewed trip spent in the block, from `trip_start` to
`interview_time`. Time fished, not the number of interviews, is the
quantity compared, because a roving clerk meets an angler with
probability proportional to time fished (Hoenig et al. 1997). A block
with counted anglers and no interviewed fishing is a `gap`. This layer
can only **point to** a gap: in a small sample a block can be missed by
chance under a plan that covers it. Hartill et al. (2011) found about
15% of boats returning after interviewers had left, a gap of exactly
this kind.

## What is unknown, and why it is not reported as covered

- A block with no count in it has unknown effort: `mean_count` and `gap`
  are `NA`, not `0` and `FALSE`.

- Interviews need clock times:
  `add_interviews(trip_start = , interview_time = )`. Interviews given
  only a `trip_duration` carry no time of day. While any interview in a
  stratum lacks one, a block with no interviewed fishing there has
  `gap = NA`, since the untimed interviews may have fished it;
  `n_no_clock_time` in the summary counts them.

- Counts need clock times: `add_counts(count_time_col = )`, as `"HH:MM"`
  or date-times. Without them the data layer is `NA` throughout.

- When counts were attached with `period_length_col`, the stored counts
  are already expanded by each day's period length; effort shares across
  blocks are then comparable only when that expansion is similar across
  the days a block was counted on.

Times are read on the survey-day clock, so a night creel's blocks run
past midnight from its `day_start`.

## References

Hartill, B. W., Watson, T. G., and Bian, R. (2011). Refining and
applying a maximum-count aerial-access survey design to estimate the
harvest taken from New Zealand's largest recreational fishery. *North
American Journal of Fisheries Management*, 31, 1197-1210.

Hoenig, J. M., Jones, C. M., Pollock, K. H., Robson, D. S., and Wade, D.
L. (1997). Calculation of catch rate and total catch in roving surveys
of anglers. *Biometrics*, 53, 306-317.

Lohr, S. L. (2022). *Sampling: Design and Analysis* (3rd ed.). CRC
Press.

Pollock, K. H., Jones, C. M., and Brown, T. L. (1994). *Angler Survey
Methods and Their Applications in Fisheries Management*. American
Fisheries Society Special Publication 25.

Robson, D. S., and Jones, C. M. (1989). The theoretical basis of an
access site angler survey design. *Biometrics*, 45, 83-98.

## See also

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
[`summarize_rws_rates()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_rws_rates.md),
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
cal <- data.frame(date = as.Date("2024-06-03") + 0:9, day_type = "weekday")
sampled <- cal$date[c(1, 3, 6, 8)]
counts <- data.frame(
  date = rep(sampled, each = 3), day_type = "weekday",
  count_time = rep(c("08:00", "13:00", "19:00"), 4),
  anglers = c(10, 8, 20, 12, 9, 25, 9, 7, 18, 11, 10, 22)
)
# Interviews only in the morning
start <- as.POSIXct(paste(rep(sampled, each = 3), "06:30"), tz = "UTC")
interviews <- data.frame(
  date = rep(sampled, each = 3), day_type = "weekday",
  catch = c(2, 1, 3, 0, 2, 1, 4, 1, 2, 3, 1, 0),
  hours = 3, status = "complete",
  trip_start = start, interview_time = start + 3 * 3600
)
design <- creel_design(cal, date = date, strata = day_type)
design <- add_counts(design, counts, count_col = anglers, count_time_col = count_time)
design <- add_interviews(design, interviews,
  catch = catch, effort = hours, trip_status = status,
  trip_start = trip_start, interview_time = interview_time
)
#> Warning: ! No `n_anglers` provided — assuming 1 angler per interview.
#> ℹ Pass `n_anglers = <column>` to use actual party sizes for angler-hour
#>   normalization.
#> ℹ If the interviews really are one angler each, pass `n_anglers = 1` to state
#>   that and silence this warning.
#> ℹ 2 interviews have zero catch.
#>   Zero catch is usual; check it is not missing data recorded as 0.
#> ℹ Added 12 interviews: 12 complete (100%), 0 incomplete (0%)
check_interview_coverage(
  design,
  periods = data.frame(period_id = 1, start_time = "06:00", end_time = "12:00"),
  fishing_hours = c("06:00", "21:00")
)
#> ── Interview coverage by time of day ───────────────────────
#> Blocks of 60 minutes, per stratum; complete trips.
#> 
#> weekday (12 interviews):
#>   Plan: 9 h of the fishing day not interviewable (74% of counted effort)
#>   Data: 74% of counted effort in blocks with no interviewed fishing
#> 
#> The plan layer can establish a gap; the data layer can only point to one.
#> Unknown means the inputs to decide it are missing, never covered.
```
