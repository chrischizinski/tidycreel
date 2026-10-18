# tidycreel and the survey Package: A Side-by-Side Guide

For a design with instantaneous counts and access interviews,
tidycreel’s effort, catch rate and total catch are built from `survey`
package calls:
[`svytotal()`](https://rdrr.io/pkg/survey/man/surveysummary.html) for
effort, [`svyratio()`](https://rdrr.io/pkg/survey/man/svyratio.html) for
the rate, and [`svyby()`](https://rdrr.io/pkg/survey/man/svyby.html) to
do each stratum separately. This page reproduces each of those three
numbers with `survey` directly, so the two can be read side by side.

It covers that one design. Other designs add steps of their own
(bus-route inclusion probabilities, aerial calibration, camera ratios),
described on their own pages; the reasoning behind each choice here is
in the Explanation pages
[`vignette("effort-pipeline")`](https://chrischizinski.com/tidycreel/dev/articles/effort-pipeline.md)
and
[`vignette("catch-pipeline")`](https://chrischizinski.com/tidycreel/dev/articles/catch-pipeline.md).

## The data

The season from
[`vignette("tidycreel")`](https://chrischizinski.com/tidycreel/dev/articles/tidycreel.md):
120 days in two strata, 36 of them sampled, one instantaneous count on
each sampled day, and access interviews.

``` r

library(tidycreel)
library(survey)

table(example_season_calendar$day_type) # days in the season, N_h
#> 
#> weekday weekend 
#>      86      34
table(example_season_counts$day_type) # days sampled, n_h
#> 
#> weekday weekend 
#>      28       8
head(example_season_counts, 3)
#>         date day_type total_anglers daylight_hours
#> 1 2024-05-06  weekday             5             14
#> 2 2024-05-07  weekday             5             14
#> 3 2024-05-09  weekday             9             14
head(example_season_interviews, 3)
#>         date day_type interview_id trip_status hours_fished n_anglers
#> 1 2024-05-06  weekday            1  incomplete         1.78         2
#> 2 2024-05-06  weekday            2  incomplete         1.82         1
#> 3 2024-05-06  weekday            3    complete         4.66         3
#>   catch_total catch_kept
#> 1           0          0
#> 2           3          1
#> 3           1          0
```

The tidycreel version, run once and used for comparison below:

``` r

design <- creel_design(example_season_calendar, date = date, strata = day_type)
design <- add_counts(design, example_season_counts,
  count_col = total_anglers,
  period_length_col = daylight_hours
)
design <- add_interviews(design, example_season_interviews,
  catch = catch_total,
  effort = hours_fished,
  trip_status = trip_status,
  n_anglers = n_anglers
)

effort <- estimate_effort(design, target = "period_total")
rate <- estimate_catch_rate(design)
total <- estimate_total_catch(design, target = "period_total")
```

## Effort: `svytotal()`

A day’s effort is its count times the length of the period the count was
randomised within: anglers present × hours open, in angler-hours. The
days are a stratified sample, and each sampled day stands for
$`N_h / n_h`$ days of its stratum:

``` r

counts <- example_season_counts
counts$angler_hours <- counts$total_anglers * counts$daylight_hours

N_h <- table(example_season_calendar$day_type)
n_h <- table(counts$day_type)
counts$w <- as.numeric(N_h[counts$day_type] / n_h[counts$day_type])

count_design <- svydesign(
  ids = ~1, strata = ~day_type, weights = ~w, data = counts
)
svytotal(~angler_hours, count_design)
#>               total     SE
#> angler_hours 9994.5 1286.3

effort$estimates
#> # A tibble: 1 × 7
#>   estimate    se se_between se_within ci_lower ci_upper     n
#>      <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int>
#> 1    9994. 1286.      1286.         0    7380.   12609.    36
effort$unit
#> [1] "angler-hours"
```

The estimate and standard error are the same. tidycreel’s confidence
interval uses a $`t`$ quantile on the design’s degrees of freedom, 36
days less 2 strata; [`confint()`](https://rdrr.io/r/stats/confint.html)
uses the normal quantile unless it is given them:

``` r

confint(svytotal(~angler_hours, count_design), df = degf(count_design))
#>                 2.5 %  97.5 %
#> angler_hours 7380.401 12608.6
```

### No finite-population correction

The design above has no finite-population correction (FPC). Survey texts
would usually add one, because days are drawn without replacement:

``` r

counts$fpc <- as.numeric(N_h[counts$day_type])
svytotal(~angler_hours, svydesign(
  ids = ~1, strata = ~day_type, fpc = ~fpc, data = counts
))
#>               total     SE
#> angler_hours 9994.5 1078.6
```

The standard error falls from about 1,286 to 1,079. tidycreel leaves the
correction out when a day has one count. The between-day variance then
also carries the variation from when in the day the count fell, and
sampling more days does not remove that part. With two or more counts on
every sampled day of a stratum, tidycreel estimates the within-day part
separately and applies the correction to the between-day part. The
reasoning is in
[`vignette("effort-pipeline")`](https://chrischizinski.com/tidycreel/dev/articles/effort-pipeline.md);
up to tidycreel 8.0.0 the correction was always applied (#505).

## Catch rate: `svyratio()`

The rate comes from complete trips. Its denominator is **angler**-hours,
each party’s hours times its number of anglers. The interviews are
stratified by day type and weighted equally:

``` r

trips <- subset(example_season_interviews, trip_status == "complete")
trips$angler_hours <- trips$hours_fished * trips$n_anglers

trip_design <- svydesign(
  ids = ~1, strata = ~day_type, weights = ~1, data = trips
)
svyratio(~catch_total, ~angler_hours, trip_design)
#> Ratio estimator: svyratio.survey.design2(~catch_total, ~angler_hours, trip_design)
#> Ratios=
#>             angler_hours
#> catch_total    0.2207121
#> SEs=
#>             angler_hours
#> catch_total   0.04148304

rate$estimates
#> # A tibble: 1 × 5
#>   estimate     se ci_lower ci_upper     n
#>      <dbl>  <dbl>    <dbl>    <dbl> <int>
#> 1    0.221 0.0415    0.139    0.302   172
rate$unit
#> [1] "fish/angler-hour"
```

This is the ratio of means (total catch over total effort), the
estimator for access interviews;
[`vignette("estimator-choice")`](https://chrischizinski.com/tidycreel/dev/articles/estimator-choice.md)
covers when tidycreel uses the mean of ratios instead. Without
`n_anglers`, the denominator would be party hours and the rate would be
per party-hour, about 0.37 here instead of 0.22. The two are different
quantities, and tidycreel reports which one it computed in `unit`.

## Total catch: `svyby()` and a product variance

The total is not season effort times the season rate. It is built
**within each stratum** and the strata are then added,
$`\hat{C} = \sum_h \hat{E}_h
\hat{R}_h`$, so that each stratum’s rate is weighted by that stratum’s
effort:

``` r

E <- svyby(~angler_hours, ~day_type, count_design, svytotal)
R <- svyby(~catch_total, ~day_type, trip_design, svyratio,
  denominator = ~angler_hours
)
E
#>         day_type angler_hours       se
#> weekday  weekday       7912.0 1062.602
#> weekend  weekend       2082.5  724.896
R
#>         day_type catch_total/angler_hours se.catch_total/angler_hours
#> weekday  weekday                0.2081839                  0.04530168
#> weekend  weekend                0.2801120                  0.10241615

e <- coef(E)
r <- coef(R)
se_e <- SE(E)
se_r <- SE(R)

sum(e * r)
#> [1] 2230.484
sqrt(sum(e^2 * se_r^2 + r^2 * se_e^2 - se_e^2 * se_r^2))
#> [1] 506.2577

total$estimates
#> # A tibble: 1 × 5
#>   estimate    se ci_lower ci_upper     n
#>      <dbl> <dbl>    <dbl>    <dbl> <int>
#> 1    2230.  506.    1231.    3230.   172
total$unit
#> [1] "fish"
```

The variance of each stratum’s product is Goodman’s unbiased estimator:
the two delta-method terms minus the product of the two variances. The
familiar two-term delta method is `product_variance = "first_order"`.
Both assume the effort and rate errors are independent;
[`vignette("catch-pipeline")`](https://chrischizinski.com/tidycreel/dev/articles/catch-pipeline.md)
derives the formula and discusses that assumption.

## Mapping table

| Step | survey package | tidycreel |
|----|----|----|
| Day’s effort | `count × period length` | `add_counts(count_col =, period_length_col =)` |
| Count design | `svydesign(ids = ~1, strata = ~day_type, weights = ~N_h/n_h)`, no `fpc` with one count a day | [`creel_design()`](https://chrischizinski.com/tidycreel/dev/reference/creel_design.md) + [`add_counts()`](https://chrischizinski.com/tidycreel/dev/reference/add_counts.md) |
| Effort | `svytotal(~angler_hours, ...)` | `estimate_effort(target = "period_total")` |
| Interview design | complete trips; `svydesign(ids = ~1, strata = ~day_type, weights = ~1)` | [`add_interviews()`](https://chrischizinski.com/tidycreel/dev/reference/add_interviews.md) |
| Catch rate | `svyratio(~catch, ~angler_hours, ...)` | [`estimate_catch_rate()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_catch_rate.md) |
| Total catch | [`svyby()`](https://rdrr.io/pkg/survey/man/svyby.html) per stratum; $`\sum_h \hat{E}_h \hat{R}_h`$; Goodman variance | `estimate_total_catch(target = "period_total")` |
| Confidence interval | effort and total catch: `confint(..., df = degf(design))`; catch rate: `confint(...)`, the normal interval | `ci_lower`, `ci_upper` |

What tidycreel adds on top of these calls is the bookkeeping: the unit
of each result, the strata a total must be built within, the refusals
when the data cannot support an estimate
([`vignette("refusals-and-na")`](https://chrischizinski.com/tidycreel/dev/articles/refusals-and-na.md)),
and the bootstrap and jackknife variance methods
([`vignette("replicate-designs")`](https://chrischizinski.com/tidycreel/dev/articles/replicate-designs.md)).

## The internal design object

[`as_creel_svydesign()`](https://chrischizinski.com/tidycreel/dev/reference/as_creel_svydesign.md)
returns the count design tidycreel built, for use with other `survey`
functions. It is the design over the **sampled days** with every weight
1, not the season design above, and its count column now holds each
day’s count × period in angler-hours, under the column’s original name:

``` r

internal <- as_creel_svydesign(design)
head(internal$variables[, c("date", "day_type", "total_anglers")], 3)
#>         date day_type total_anglers
#> 1 2024-05-06  weekday            70
#> 2 2024-05-07  weekday            70
#> 3 2024-05-09  weekday           126
svytotal(~total_anglers, internal)
#>               total     SE
#> total_anglers  3066 385.72
```

That total is effort over the 36 sampled days.
[`estimate_effort()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_effort.md)
expands it to the season, and is the way to get the season total.
