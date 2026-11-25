# Getting Started with tidycreel

## Introduction

tidycreel gives fisheries biologists a tidy, pipe-friendly way to design
and analyse creel surveys. You work with the terms used in the field
(dates, strata, counts, interviews) without handling the internals of
the survey package.

This tutorial analyses one complete season, start to finish. A clerk
worked a lake for 120 days, from May 1 to August 28. On 36 of those days
the clerk made an instantaneous count of anglers and interviewed angling
parties, both those that had finished fishing and some still fishing.
The questions are the usual ones: how much fishing happened over the
season, how many fish were caught, and how many were kept.

Each answer is built from the one before:

    calendar -> design
    counts             -> effort        (angler-hours)
    interviews         -> catch rate    (fish per angler-hour)
    effort x rate      -> total catch   (fish)

## The season

``` r

library(tidycreel)

data(example_season_calendar)
data(example_season_counts)
data(example_season_interviews)

head(example_season_calendar)
#>         date day_type sampled
#> 1 2024-05-01  weekday   FALSE
#> 2 2024-05-02  weekday   FALSE
#> 3 2024-05-03  weekday    TRUE
#> 4 2024-05-04  weekend   FALSE
#> 5 2024-05-05  weekend   FALSE
#> 6 2024-05-06  weekday    TRUE
table(example_season_calendar$day_type, example_season_calendar$sampled)
#>          
#>           FALSE TRUE
#>   weekday    59   27
#>   weekend    25    9
```

The calendar lists every day of the season, not only the sampled ones,
and splits them into weekdays and weekends. The clerk sampled 27 of the
86 weekdays and 9 of the 34 weekend days. That list of every day is what
lets tidycreel expand from the days that were sampled to the whole
season.

## Survey design

``` r

design <- creel_design(example_season_calendar, date = date, strata = day_type)
design
#> 
#> ── Creel Survey Design ─────────────────────────────────────────────────────────
#> Type: "instantaneous"
#> Date column: date
#> Strata: day_type
#> Calendar: 120 days (2024-05-01 to 2024-08-28)
#> day_type: 2 levels
#> Counts: "none"
#> Interviews: "none"
#> Sections: "none"
```

[`creel_design()`](https://chrischizinski.com/tidycreel/dev/reference/creel_design.md)
uses tidy selectors, so you name columns without quotes. The design
records the 120-day calendar and its two strata.

## Counts

``` r

head(example_season_counts)
#>         date day_type total_anglers daylight_hours
#> 1 2024-05-03  weekday             3             14
#> 2 2024-05-06  weekday             2             14
#> 3 2024-05-09  weekday             0             14
#> 4 2024-05-13  weekday            11             14
#> 5 2024-05-14  weekday             1             14
#> 6 2024-05-15  weekday             0             14

design <- add_counts(design, example_season_counts,
  count_col = total_anglers,
  period_length_col = daylight_hours
)
```

Each row is one instantaneous count: the number of anglers fishing at
the moment the clerk looked. A count is a number of anglers, not an
amount of effort. To turn it into effort, tidycreel needs to know how
much time the count stands for. Here the single count on each day
represents the whole 14-hour fishing day, so `daylight_hours` is the
period length. Effort for a day is the count times that length, in
angler-hours.

On 13 of the 36 days the clerk counted no one. tidycreel notes the zeros
when it estimates effort, in case a missing count was entered as 0. Here
they are real: an empty lake at the moment of the count is an
observation, and it belongs in the estimate, just as a party that caught
nothing belongs in the catch rate.

Leaving out `period_length_col` still gives an estimate, but its unit is
unknown, and
[`estimate_effort()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_effort.md)
warns that no period length was supplied. tidycreel derives units from
what you give it and never assumes one.

## Effort

There are two different questions you can ask of these counts.

``` r

estimate_effort(design)
#> Count variable total_anglers contains 13 zero values.
#> ℹ Zero values may indicate days with no fishing activity or data collection
#>   issues.
#> ℹ Consider whether zeros are true zeros or missing data.
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Total
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Effort target: period_total
#> Unit: angler-hours
#> 
#> # A tibble: 1 × 8
#>   estimate    se se_between se_within ci_lower ci_upper     n se_basis          
#>      <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int> <chr>             
#> 1    4079. 1014.      1014.        NA    2018.    6139.    36 between_day_upper…
estimate_effort(design, target = "sampled_days")
#> Count variable total_anglers contains 13 zero values.
#> ℹ Zero values may indicate days with no fishing activity or data collection
#>   issues.
#> ℹ Consider whether zeros are true zeros or missing data.
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Total
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Effort target: sampled_days
#> Unit: angler-hours
#> 
#> # A tibble: 1 × 8
#>   estimate    se se_between se_within ci_lower ci_upper     n se_basis          
#>      <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int> <chr>             
#> 1     1218  288.       288.        NA     633.    1803.    36 between_day_upper…
```

The first estimate, the default (`target = "period_total"`), is the
effort **over the whole 120-day season**, about 4,079 angler-hours.
(These data are simulated, so the true season effort is known: 4,932
angler-hours, inside the 95% confidence interval.) That season total is
the number usually reported. Each stratum’s mean daily effort is
multiplied by the number of days in that stratum, then the strata are
added. The second is the effort **on the 36 days that were sampled**:
1,218 angler-hours. Ask for it with `target = "sampled_days"`.

The standard error comes from the day-to-day variation among the sampled
days within each stratum. With one count per day the within-day
variation (when in the day each count happened to fall) is inside that
day-to-day variation but cannot be estimated separately, so `se_within`
is `NA`; `se` and `se_between`, which hold it, are complete. It becomes
a number when every day has several counts. With one count per day the
standard error also leaves out the finite-population correction, so it
is slightly conservative;
[`vignette("effort-pipeline")`](https://chrischizinski.com/tidycreel/dev/articles/effort-pipeline.md)
explains why.

Estimates can be broken down by any column in the design with `by`:

``` r

estimate_effort(design, by = day_type, target = "period_total")
#> Count variable total_anglers contains 13 zero values.
#> ℹ Zero values may indicate days with no fishing activity or data collection
#>   issues.
#> ℹ Consider whether zeros are true zeros or missing data.
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Total
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Grouped by: day_type
#> Effort target: period_total
#> Unit: angler-hours
#> 
#> # A tibble: 2 × 9
#>   day_type estimate    se se_between se_within ci_lower ci_upper     n se_basis 
#>   <chr>       <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int> <chr>    
#> 1 weekday     2809.  616.       616.        NA    1542.    4076.    27 between_…
#> 2 weekend     1269.  805.       805.        NA    -587.    3126.     9 between_…
```

The 86 weekdays account for most of the season’s effort, about 2,809
angler-hours to the weekends’ 1,269, but only because there are more of
them. Per day, an average weekend day saw slightly more: about 37
angler-hours, against 33 on an average weekday. With only 9 weekend days
sampled, the weekend estimate is imprecise, and its symmetric confidence
interval reaches below zero.

## Interviews

``` r

head(example_season_interviews)
#>         date day_type interview_id trip_status hours_fished n_anglers
#> 1 2024-05-03  weekday            1    complete         1.96         2
#> 2 2024-05-03  weekday            2    complete         0.84         1
#> 3 2024-05-03  weekday            3    complete         2.87         1
#> 4 2024-05-03  weekday            4    complete         2.10         1
#> 5 2024-05-03  weekday            5    complete         0.41         2
#> 6 2024-05-03  weekday            6    complete         3.12         2
#>   catch_total catch_kept
#> 1           0          0
#> 2           0          0
#> 3           0          0
#> 4           1          1
#> 5           0          0
#> 6           4          1

design <- add_interviews(design, example_season_interviews,
  catch = catch_total,
  harvest = catch_kept,
  effort = hours_fished,
  trip_status = trip_status,
  n_anglers = n_anglers
)
#> ℹ 238 interviews have zero catch.
#>   Zero catch is usual; check it is not missing data recorded as 0.
#> ℹ Added 298 interviews: 222 complete (74%), 76 incomplete (26%)
```

Each row is one party.
[`add_interviews()`](https://chrischizinski.com/tidycreel/dev/reference/add_interviews.md)
checks the interviews as it attaches them and reports what it found: 222
complete trips, 76 incomplete, and 238 parties that caught nothing. Most
anglers on most fisheries go home without a fish, and those zeros belong
in the catch rate. The count is shown because, on a real data sheet, a
column of zeros can also mean a catch that was never recorded. If your
zeros are real, as these are, there is nothing to fix.

`n_anglers` matters. `hours_fished` is how long the party fished, so it
is in party-hours. A party of three fishing two hours put in six
angler-hours, and `n_anglers` lets tidycreel make that conversion. The
catch rate is then in fish per angler-hour, the same footing as the
counts. Without it the rate would be per party-hour, which cannot be
multiplied by effort in angler-hours.

## Catch rates

``` r

estimate_catch_rate(design)
#> ℹ Using complete trips for CPUE estimation
#>   (n=222, 74.5% of 298 interviews) [default]
#> Count variable total_anglers contains 13 zero values.
#> ℹ Zero values may indicate days with no fishing activity or data collection
#>   issues.
#> ℹ Consider whether zeros are true zeros or missing data.
estimate_harvest_rate(design)
#> ℹ Filtering to complete trips for HPUE estimation
#>   (n=222, 74.5% of 298 interviews) [default]
#> Count variable total_anglers contains 13 zero values.
#> ℹ Zero values may indicate days with no fishing activity or data collection
#>   issues.
#> ℹ Consider whether zeros are true zeros or missing data.
```

The catch rate is about 0.18 fish per angler-hour, and the harvest rate
about 0.06. Both are ratio-of-means estimates, total catch divided by
total effort across the interviews. These data were simulated with a
true catch rate of 0.22, inside the estimate’s confidence interval. By
default the rates use only the 222 complete trips. A party interviewed
while still fishing is more likely to be met the longer it stays, so
incomplete trips over-represent long trips (length-of-stay bias) and
give a biased catch rate unless the rate is steady through a trip.
[`vignette("incomplete-trips")`](https://chrischizinski.com/tidycreel/dev/articles/incomplete-trips.md)
covers when and how incomplete trips can be used.

## Total catch and harvest

``` r

estimate_total_catch(design, target = "period_total")
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Total Catch (Effort × CPUE)
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Effort target: period_total
#> Unit: fish
#> 
#> # A tibble: 1 × 5
#>   estimate    se ci_lower ci_upper     n
#>      <dbl> <dbl>    <dbl>    <dbl> <int>
#> 1     736.  219.     306.    1167.   222
estimate_total_harvest(design, target = "period_total")
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Total Harvest (Effort × HPUE)
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Effort target: period_total
#> Unit: fish
#> 
#> # A tibble: 1 × 5
#>   estimate    se ci_lower ci_upper     n
#>      <dbl> <dbl>    <dbl>    <dbl> <int>
#> 1     243.  83.7     78.0     408.   222
```

A total is effort times rate, with the uncertainty of both carried into
its standard error. The unit follows: angler-hours times fish per
angler-hour is fish. About 740 fish were caught over the season, and
about 240 were kept. These totals take `target` too, and need
`target = "period_total"` for the season, just as effort does.

Totals break down the same way as effort:

``` r

estimate_total_catch(design, by = day_type, target = "period_total")
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Total Catch (Effort × CPUE)
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Grouped by: day_type
#> Effort target: period_total
#> Unit: fish
#> 
#> # A tibble: 2 × 6
#>   day_type estimate    se ci_lower ci_upper     n
#>   <chr>       <dbl> <dbl>    <dbl>    <dbl> <int>
#> 1 weekday      542.  176.     194.     891.   152
#> 2 weekend      194.  129.       0      452.    70
```

Released fish come from species-level catch records, attached with
[`add_catch()`](https://chrischizinski.com/tidycreel/dev/reference/add_catch.md),
rather than from the interview totals; see
[`?estimate_total_release`](https://chrischizinski.com/tidycreel/dev/reference/estimate_total_release.md).

## Using results as data

An estimate prints with its method, variance method and unit. It is not
itself a data frame, so dplyr verbs do not work on it directly. Convert
it first. `as_tibble()` returns one row per estimate, with the metadata
copied into columns so it stays attached to every row:

``` r

catch_by_day <- estimate_total_catch(design, by = day_type, target = "period_total")
catch_tbl <- tibble::as_tibble(catch_by_day)
catch_tbl
#> # A tibble: 2 × 12
#>   day_type estimate    se ci_lower ci_upper     n method              estimator 
#>   <chr>       <dbl> <dbl>    <dbl>    <dbl> <int> <chr>               <chr>     
#> 1 weekday      542.  176.     194.     891.   152 product-total-catch ratio-of-…
#> 2 weekend      194.  129.       0      452.    70 product-total-catch ratio-of-…
#> # ℹ 4 more variables: variance_method <chr>, conf_level <dbl>,
#> #   effort_target <chr>, unit <chr>

catch_tbl[catch_tbl$day_type == "weekend", c("day_type", "estimate", "se", "unit")]
#> # A tibble: 1 × 4
#>   day_type estimate    se unit 
#>   <chr>       <dbl> <dbl> <chr>
#> 1 weekend      194.  129. fish
```

[`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html) does the
same for base R. Use `metadata = FALSE` for the estimates table alone.

## Plotting

Estimates have an `autoplot()` method that draws each estimate with its
confidence interval:

``` r

ggplot2::autoplot(catch_by_day)
```

![Point estimates of total catch on weekdays and weekends, with 95
percent confidence intervals.](tidycreel_files/figure-html/plot-1.png)

[`vignette("visualisation")`](https://chrischizinski.com/tidycreel/dev/articles/visualisation.md)
covers the other plots.

## Variance methods

Standard errors use Taylor linearization by default. Bootstrap and
jackknife replicates are also available, for effort and for every
estimate built on it:

``` r

set.seed(123)
estimate_effort(design, target = "period_total", variance = "bootstrap")
#> Count variable total_anglers contains 13 zero values.
#> ℹ Zero values may indicate days with no fishing activity or data collection
#>   issues.
#> ℹ Consider whether zeros are true zeros or missing data.
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Total
#> Variance: Bootstrap
#> Confidence level: 95%
#> Effort target: period_total
#> Unit: angler-hours
#> 
#> # A tibble: 1 × 8
#>   estimate    se se_between se_within ci_lower ci_upper     n se_basis          
#>      <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int> <chr>             
#> 1    4079.  978.       978.        NA    2090.    6067.    36 between_day_upper…
estimate_effort(design, target = "period_total", variance = "jackknife")
#> Count variable total_anglers contains 13 zero values.
#> ℹ Zero values may indicate days with no fishing activity or data collection
#>   issues.
#> ℹ Consider whether zeros are true zeros or missing data.
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Total
#> Variance: Jackknife
#> Confidence level: 95%
#> Effort target: period_total
#> Unit: angler-hours
#> 
#> # A tibble: 1 × 8
#>   estimate    se se_between se_within ci_lower ci_upper     n se_basis          
#>      <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int> <chr>             
#> 1    4079. 1014.      1014.        NA    2018.    6139.    36 between_day_upper…
```

- **Taylor linearization** (default) is fast and appropriate for most
  estimates.
- **Bootstrap** resamples sampled days. Use it to check the
  linearization or for statistics that are not smooth.
- **Jackknife** is deterministic, so it gives the same answer on every
  run.

[`vignette("replicate-designs")`](https://chrischizinski.com/tidycreel/dev/articles/replicate-designs.md)
compares them.

## Next steps

This tutorial used the most common design: instantaneous counts and
access interviews, with weekday and weekend strata. From here:

- [`vignette("survey-scheduling")`](https://chrischizinski.com/tidycreel/dev/articles/survey-scheduling.md)
  builds the sampling calendar before the season, including high-use
  periods such as openers.
- [`vignette("interview-estimation")`](https://chrischizinski.com/tidycreel/dev/articles/interview-estimation.md)
  and
  [`vignette("incomplete-trips")`](https://chrischizinski.com/tidycreel/dev/articles/incomplete-trips.md)
  cover catch-rate estimators in depth.
- [`vignette("section-estimation")`](https://chrischizinski.com/tidycreel/dev/articles/section-estimation.md)
  handles lakes split into sections.
- The **Survey Types** articles cover bus-route, ice, camera, aerial and
  mark-recapture designs.
- [`vignette("glossary")`](https://chrischizinski.com/tidycreel/dev/articles/glossary.md)
  defines the terms used throughout.

To hear about new releases, join the
[tidycreel-announce](https://groups.google.com/g/tidycreel-announce)
mailing list, or send an email to
<tidycreel-announce+subscribe@googlegroups.com>.
