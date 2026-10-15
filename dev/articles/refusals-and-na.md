# Refusals, NA, NULL and Zero

The most damaging error a creel estimate can carry is not a crash. It is
a believable number that quietly treats something unknown as zero: a
stratum nobody sampled counted as no effort, a standard error that was
never propagated shown as 0. This page explains the rules tidycreel
follows to keep those apart, and why it sometimes refuses to give an
answer at all.

Three rules:

    zero      a measurement: none was seen. It counts.
    NA        unknown: a value exists but was not measured. It is never read as zero.
    refusal   the data cannot support the estimate asked for. No number is returned.

``` r

library(tidycreel)
```

## Zero is a measurement

A party that fished and caught nothing has a catch of 0, and that 0
belongs in every rate. Dropping zero-catch trips would make the rate an
average over successful trips only, and too high. So tidycreel keeps
them, and says how many there are, in case a missing value was recorded
as 0:

``` r

design <- creel_design(example_season_calendar, date = date, strata = day_type)
design <- add_counts(design, example_season_counts,
  period_length_col = daylight_hours
)
design <- add_interviews(design, example_season_interviews,
  catch = catch_total, harvest = catch_kept, effort = hours_fished,
  trip_status = trip_status, n_anglers = n_anglers
)
#> ℹ 153 interviews have zero catch.
#>   Zero catch is usual; check it is not missing data recorded as 0.
#> ℹ Added 231 interviews: 172 complete (74%), 59 incomplete (26%)
```

The message is a prompt to check the data, not a sign that anything was
changed. A count of 0 anglers is also an observation, but of one moment:
no one was fishing when the count was made. It belongs in the estimate
as a 0, like any other count. On its own it does not say that nobody
fished that day; the expansion from counts to effort is what accounts
for the rest of the day.

## Unknown is not zero

A value that was never measured is a different thing, and the danger is
that arithmetic treats it as zero without saying so. Leaving a stratum
out of a sum is the same as adding 0 for it. tidycreel refuses at the
points where that would happen.

### A stratum with no sampled days

Here the weekend counts are removed, so no weekend day was counted:

``` r

weekday_counts <- example_season_counts[
  example_season_counts$day_type == "weekday",
]
weekday_only <- creel_design(example_season_calendar,
  date = date, strata = day_type
)
weekday_only <- add_counts(weekday_only, weekday_counts,
  period_length_col = daylight_hours
)

estimate_effort(weekday_only, target = "period_total")
#> Error in `refuse_unsampled_cells()`:
#> ! Expanded effort cannot be estimated: 1 calendar cell has no sampled
#>   day.
#> • day_type=weekend (34 days)
#> ✖ The days in an unsampled stratum would be left out of the total, reporting
#>   their unknown effort as zero.
#> ℹ Sample at least one day in every stratum, or merge the stratum into another
#>   before estimating.
```

A season total needs the weekend’s effort, and there is no information
about it. Summing the weekday strata alone would report the 34 weekend
days as zero effort. The default target asks a smaller question, the
effort on the days that were counted, and that one has an answer:

``` r

estimate_effort(weekday_only)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Total
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Effort target: sampled_days
#> Unit: angler-hours
#> 
#> # A tibble: 1 × 7
#>   estimate    se se_between se_within ci_lower ci_upper     n
#>      <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int>
#> 1     2576  346.       346.         0    1866.    3286.    28
```

### A stratum with no catch rate

A total multiplies each stratum’s effort by its rate. If one stratum has
effort but no interviews, its catch is unknown:

``` r

weekday_interviews <- example_season_interviews[
  example_season_interviews$day_type == "weekday",
]
no_weekend_rate <- creel_design(example_season_calendar,
  date = date, strata = day_type
)
no_weekend_rate <- add_counts(no_weekend_rate, example_season_counts,
  period_length_col = daylight_hours
)
no_weekend_rate <- add_interviews(no_weekend_rate, weekday_interviews,
  catch = catch_total, harvest = catch_kept, effort = hours_fished,
  trip_status = trip_status, n_anglers = n_anglers
)
#> ℹ 128 interviews have zero catch.
#>   Zero catch is usual; check it is not missing data recorded as 0.
#> ℹ Added 190 interviews: 138 complete (73%), 52 incomplete (27%)

estimate_total_catch(no_weekend_rate)
#> Error in `check_missing_rate_strata()`:
#> ! 1 effort cell has no rate in "estimate_total_catch".
#> ✖ No usable interviews for: day_type = weekend.
#> ✖ Their contribution to the total is unknown, not zero: 490 effort units, 16%
#>   of the effort being totalled.
#> ℹ Collect or attach interviews for that cell, or group more coarsely so it
#>   shares a rate.
#> ℹ `missing_rate = "exclude"` reports the total over the covered cells only, and
#>   records what it left out.
```

The refusal says how much effort has no rate, so you can judge whether
it matters. If a total over the covered strata is what you want, ask for
it. The result says what it left out, and keeps a record of it:

``` r

weekday_total <- estimate_total_catch(no_weekend_rate,
  missing_rate = "exclude"
)
#> Warning: 1 effort cell with no rate excluded from "estimate_total_catch".
#> ! Excluded: day_type = weekend (490 effort units, 16%).
#> ℹ The total covers the remaining cells only; see excluded_strata on the result.
weekday_total
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Total Catch (Effort × CPUE)
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Effort target: sampled_days
#> Unit: fish
#> 
#> # A tibble: 1 × 5
#>   estimate    se ci_lower ci_upper     n
#>      <dbl> <dbl>    <dbl>    <dbl> <int>
#> 1     536.  136.     267.     806.   138
#> 
#> Covers the cells with a rate only. Excluded (no rate), see $excluded_strata:
#>   day_type = weekend: 490 effort units
weekday_total$excluded_strata
#> # A tibble: 1 × 3
#>   day_type effort_excluded excluded_from       
#>   <chr>              <dbl> <chr>               
#> 1 weekend              490 estimate_total_catch
```

The warning is the point: this total is the weekday catch, not the
season’s, and nothing about the number says so except the warning and
the record.

### Other unknowns that are refused

- **A missing catch count.**
  [`add_catch()`](https://chrischizinski.com/tidycreel/dev/reference/add_catch.md)
  refuses a species row whose count is `NA`. Dropping the row is not
  neutral: a missing `"harvested"` row means 0 harvested, and a missing
  `"caught"` row changes how total catch is derived. You decide whether
  to fill the value or drop the row.
- **An ambiguous column.** Given two numeric columns and no `count_col`,
  [`add_counts()`](https://chrischizinski.com/tidycreel/dev/reference/add_counts.md)
  refuses rather than pick one, because expanding the wrong column into
  effort would give a confident wrong answer.
- **Units that cannot be told apart.** These are not refused: the
  estimate is returned with an unknown unit, `NA`.
  [`vignette("unit-rules")`](https://chrischizinski.com/tidycreel/dev/articles/unit-rules.md)
  explains why.

## NULL, NA and zero in a standard error

The standard error of an aerial effort estimate has parts: the variation
between sampled days, and the uncertainty in each correction applied to
the counts. Each part is recorded in `se_components`, and each can be in
one of three states:

| State | Meaning | Effect on `se` |
|----|----|----|
| absent | not propagated: it does not apply, or no standard error was supplied | `se` leaves it out |
| `NA` | applies, and is unknown | `se` is `NA` |
| `0` | known to be exactly zero | included, as zero |

The three are kept apart because a zero is otherwise indistinguishable
from a part nobody propagated. The aerial visibility correction shows
all three:

``` r

aerial_calendar <- unique(data.frame(
  date = example_aerial_counts$date,
  day_type = example_aerial_counts$day_type
))

aerial_effort <- function(...) {
  design <- creel_design(aerial_calendar,
    date = date, strata = day_type,
    survey_type = "aerial", h_open = 14, angler_ratio = 1,
    angler_ratio_se = 0, ...
  )
  estimate_effort(add_counts(design, example_aerial_counts))
}
```

A correction was measured, but its standard error was not supplied. The
visibility part is absent, and the standard error covers the count
sampling only:

``` r

aerial_effort(visibility_correction = 0.85)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: aerial_total
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Effort target: sampled_days
#> Unit: angler-hours
#> Count-sampling SE: 774.4 (included in se)
#> within_day: 0 (included in se)
#> angler_ratio: 0 (included in se)
#> 
#> # A tibble: 1 × 7
#>   estimate    se se_between se_within ci_lower ci_upper     n
#>      <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int>
#> 1   10492.  774.       774.         0    8831.   12153.    16
```

The correction’s standard error is supplied, so it is propagated:

``` r

aerial_effort(visibility_correction = 0.85, visibility_se = 0.04)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: aerial_total
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Effort target: sampled_days
#> Unit: angler-hours
#> Count-sampling SE: 774.4 (included in se)
#> within_day: 0 (included in se)
#> visibility: 493.7 (included in se)
#> angler_ratio: 0 (included in se)
#> 
#> # A tibble: 1 × 7
#>   estimate    se se_between se_within ci_lower ci_upper     n
#>      <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int>
#> 1   10492.  918.       774.         0    8522.   12462.    16
```

No correction was studied (`"none"`). The point estimate divides by 1,
but how many anglers the observer missed is unknown, so the standard
error is too:

``` r

aerial_effort(visibility_correction = "none")
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: aerial_total
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Effort target: sampled_days
#> Unit: angler-hours
#> Count-sampling SE: 658.3 (known, but se is `NA`)
#> within_day: 0 (known, but se is `NA`)
#> visibility: NA (unknown, so se is `NA`)
#> angler_ratio: 0 (known, but se is `NA`)
#> 
#> # A tibble: 1 × 7
#>   estimate    se se_between se_within ci_lower ci_upper     n
#>      <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int>
#> 1     8918    NA       658.         0       NA       NA    16
```

The same counts give a standard error of 774, then 918, then `NA`. In
the first, the visibility correction is a measured number whose
uncertainty was not supplied, so 774 understates the total uncertainty
by whatever that part would add (918 once it is supplied). In the third
there is no measurement at all, and no honest standard error. In all
three, `angler_ratio: 0` is the third state: `angler_ratio_se = 0`
states that every person counted is an angler, exactly. A correction
known exactly must be said to be:
`visibility_correction = 1, visibility_se = 0`, for example, where every
angler can be seen.

### One exception: `se_within` with one count per day

With one count per day,
[`estimate_effort()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_effort.md)
reports `se_within = 0`. It is not a measured zero: with a single count
the variation within a day cannot be separated from the variation
between days, and both are in `se_between`. So `se` is right, and only
the split is not identified.
[`vignette("effort-pipeline")`](https://chrischizinski.com/tidycreel/dev/articles/effort-pipeline.md)
explains this, and reporting it as `NA` instead is proposed for the next
major release (issue \#504).

## Kinds of refusal

| What is wrong | Example | What to do |
|----|----|----|
| a stratum or cell has no data | no sampled day in a stratum; effort with no rate; one sampled day in a stratum, so no variance | sample it, merge strata, or ask a narrower question |
| the input is ambiguous | two candidate count columns; repeated rows for one sampling unit | name the column; give the count time, or fix the rows |
| a required value is unknown | an `NA` catch count; an aerial design without `h_open` or `angler_ratio` | supply it, or state `"none"` where that is allowed |
| the estimator does not apply | [`estimate_effort()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_effort.md) on a camera design; a mean-of-ratios total on a bus route | use the function the message names |

A rate and an effort in different units are not on this list. A rate per
party-hour times effort in angler-hours returns a total with a warning
and unit `NA`, because the number may still be what you want if every
party is one angler;
[`vignette("unit-rules")`](https://chrischizinski.com/tidycreel/dev/articles/unit-rules.md)
shows it.

A refusal says what was wrong and, where there is a remedy, what to do.
Many also carry a condition class beginning `creel_error_`
(`creel_error_unsampled_cell`, `creel_error_missing_rate_strata`,
`creel_error_single_psu`, …), so that code can catch a particular
refusal by name. Warnings, which return an estimate but say something
about it, are listed in
[`?creel_warnings`](https://chrischizinski.com/tidycreel/dev/reference/creel_warnings.md).

## Why refuse rather than warn

A warning still returns a number, and a number travels: into a table, a
report, a management decision, long after the warning has scrolled away.
When the data cannot support the estimate, tidycreel does not return
one. When they can support a narrower one, the refusal says how to ask
for it, and that estimate is labelled as narrower.
