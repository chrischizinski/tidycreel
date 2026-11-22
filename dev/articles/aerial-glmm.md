# GLMM Aerial Effort Estimation

## When to Use the GLMM Estimator

If your pilot always flies at the same time of day — say, 10 AM — your
instantaneous count systematically over- or under-represents total daily
effort. Early-morning flights catch fewer anglers than are present at
peak hours; late-afternoon flights may miss early starters entirely.
When flight timing is non-random, the simple expansion (count × h_open /
v) inherits this temporal bias.

The GLMM approach models how angler counts change through the day, then
integrates predicted counts across the full open-water window —
correcting for wherever in the curve the actual flight fell. It builds
on Askey et al. (2018), who fitted negative-binomial GLMMs to hourly
time-lapse camera counts, with time of day as a categorical hour and a
random intercept for the lake-year being scaled. tidycreel adapts that
to flights: a few fixed flight times cannot support one coefficient per
hour, and a categorical hour cannot predict the hours no flight saw, so
the default uses a smooth quadratic hour effect and a day-level random
intercept: `count ~ poly(hour, 2) + (1 | date)`. The quadratic is
tidycreel’s choice, not a model from Askey et al.

**When to use the GLMM estimator:**

1.  Flights always occur in the same part of the day (fixed morning or
    afternoon schedule).
2.  You have multiple overflights per day across several days (minimum
    8–10 survey days recommended for stable random-effect estimation).

**When to use the simple estimator:**

1.  Flight timing is randomly assigned across the open-water window.
2.  You have only one count per day.

For the basic aerial workflow without GLMM correction, see the [aerial
surveys
vignette](https://chrischizinski.com/tidycreel/dev/articles/aerial-surveys.md).

## Example Data

The `example_aerial_glmm_counts` dataset contains 12 survey days with 4
overflights per day at fixed hours (7, 10, 13, and 16 hours), producing
48 observations. Angler counts follow a diurnal curve with a day-level
random intercept and overdispersed (negative-binomial) count noise —
representative of a scenario where a fixed morning-to-afternoon flight
schedule is used throughout the season.

``` r

library(tidycreel)
data(example_aerial_glmm_counts)
head(example_aerial_glmm_counts)
#>         date day_type n_anglers time_of_flight
#> 1 2024-06-03  weekday         5              7
#> 2 2024-06-03  weekday        29             10
#> 3 2024-06-03  weekday        70             13
#> 4 2024-06-03  weekday        24             16
#> 5 2024-06-06  weekday         3              7
#> 6 2024-06-06  weekday        34             10
```

The four columns are `date`, `day_type`, `n_anglers` (instantaneous
count), and `time_of_flight` (decimal hour of each overflight).

## Building the Aerial Design

Build an aerial `creel_design` over the survey period and attach the
count data. The `h_open = 14` argument specifies the number of hours the
fishery is open each day; it sets the length of the window over which
the diurnal curve is integrated.

``` r

# The survey period, June 3 to July 6, 2024: the days the flights stand for.
# A calendar of the flight dates alone would make the design a census of
# those days (#584).
aerial_cal <- creel_calendar("2024-06-03", "2024-07-06", strata = "day_type")

design <- creel_design(
  aerial_cal,
  date        = date,
  strata      = day_type,
  survey_type = "aerial",
  visibility_correction = "none",
  angler_ratio = 1,
  angler_ratio_se = 0,
  h_open      = 14
)

design <- add_counts(design, example_aerial_glmm_counts,
  count_col      = n_anglers,
  count_time_col = time_of_flight
)
print(design)
#> 
#> ── Creel Survey Design ─────────────────────────────────────────────────────────
#> Type: "aerial"
#> Date column: date
#> Strata: day_type
#> Calendar: 34 days (2024-06-03 to 2024-07-06)
#> day_type: 2 levels
#> Counts: 12 observations
#> PSU column: date
#> Count column: n_anglers
#> Party-size term: not carried
#> Count time column: time_of_flight
#> Count type: "instantaneous"
#> Survey: <survey.design2> (constructed)
#> Interviews: "none"
#> Sections: "none"
#> 
#> ── Aerial Survey Design ──
#> 
#> Hours open (h_open): 14
#> Visibility correction: "none" (declared; SE is "NA")
#> Angler-to-people ratio: 1
#> Angler ratio SE: 0
```

The 48 rows are four flights on each of 12 days. `count_time_col` tells
[`add_counts()`](https://chrischizinski.com/tidycreel/dev/reference/add_counts.md)
which flight each row is, so it can tell repeat looks at a day apart
from separate sampling days. The simple estimator averages a day’s
flights into one count; the GLMM fits its curve to the flights
themselves, which
[`add_counts()`](https://chrischizinski.com/tidycreel/dev/reference/add_counts.md)
keeps alongside the daily means. One design serves both estimators, and
[`estimate_effort_aerial_glmm()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_effort_aerial_glmm.md)
takes the time column from it.

## GLMM Effort Estimation

Call
[`estimate_effort_aerial_glmm()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_effort_aerial_glmm.md)
with `time_col = time_of_flight`. The default model fits a
negative-binomial GLMM with a quadratic temporal effect and a day-level
random intercept:

``` r

glmm_result <- estimate_effort_aerial_glmm(design, time_col = time_of_flight)
#> ℹ Integration window start derived from data: 6.5 h (earliest flight - 0.5 h).
#>   Specify `open_start` in `creel_design()` for a fixed fishery opening time.
print(glmm_result)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: aerial_glmm_total
#> Variance: delta
#> Confidence level: 95%
#> Effort target: sampled_days
#> Unit: angler-hours
#> model: 364.6 (known, but se is `NA`)
#> visibility: NA (unknown, so se is `NA`)
#> angler_ratio: 0 (known, but se is `NA`)
#> 
#> # A tibble: 1 × 7
#>   estimate    se se_between se_within ci_lower ci_upper     n
#>      <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int>
#> 1    3740.    NA         NA        NA       NA       NA    48
```

The model fits the diurnal count curve over all 48 observations, then
numerically integrates the predicted mean count (trapezoid rule on a
100-point grid) over a window `h_open` hours long. The window starts at
`open_start` if
[`creel_design()`](https://chrischizinski.com/tidycreel/dev/reference/creel_design.md)
was given one, and otherwise 0.5 hours before the earliest flight. The
integral is already in people-hours, so it is scaled by the angler ratio
and the visibility correction (`angler_ratio / visibility_correction`)
and not by `h_open` again.

Check convergence on your own data.
[`lme4::glmer.nb()`](https://rdrr.io/pkg/lme4/man/glmer.nb.html) warns
`iteration limit reached` when the counts show little overdispersion, so
the negative-binomial dispersion cannot settle; a Poisson fit
(`family = poisson`) may then suit the data better.

## Variance and Confidence Intervals

Two variance methods are available.

**Delta method (default):** Propagates the fixed-effect covariance
matrix from `lme4::vcov()` to the derived integral via a gradient
vector. This is fast and analytic, and is the default when
`boot = FALSE`.

**Parametric bootstrap:**
[`lme4::bootMer()`](https://rdrr.io/pkg/lme4/man/bootMer.html) re-fits
the model under parametric resampling `nsim` times and uses the SD of
the resulting totals as the SE. This method can give more accurate CIs
for skewed count distributions. Use it for final production analyses;
the delta method is appropriate for exploratory work.

**Whichever method you choose, this vignette’s design reports no
interval at all.**
[`creel_design()`](https://chrischizinski.com/tidycreel/dev/reference/creel_design.md)
above sets `visibility_correction = "none"`, which declares that no
detection-probability study was done. That is a statement of ignorance,
not a value of one: the correction’s uncertainty is unknown, so it
cannot be propagated, and `se`, `ci_lower` and `ci_upper` all come back
`NA` rather than pretending the unknown component contributes zero.

To get an interval, say what the correction’s uncertainty is — pass a
numeric `visibility_correction` together with `visibility_se` to
[`creel_design()`](https://chrischizinski.com/tidycreel/dev/reference/creel_design.md).
Declaring it known and exactly certain (`visibility_se = 0`) is also a
valid claim and does produce an interval; it is simply a different claim
from having never measured it.

``` r

# Bootstrap CIs — use nboot = 500 for production analyses
glmm_boot <- estimate_effort_aerial_glmm(
  design,
  time_col = time_of_flight,
  boot = TRUE,
  nboot = 100L
)
print(glmm_boot)
```

## Downstream Estimation

[`estimate_effort_aerial_glmm()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_effort_aerial_glmm.md)
returns an effort estimate; it does not write that estimate back into
the design, and the total estimators do not take one as an argument —
[`estimate_total_catch()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_total_catch.md)
derives effort itself, from the counts attached to whatever design it is
given. So the GLMM figure is a standalone result to read, report, or
combine by hand, not an input the rest of the pipeline picks up
automatically.

What the downstream estimators need is a design carrying interviews. The
example below builds one from the complementary aerial interview data
and estimates catch rate and total catch from it. Note that this is a
*different* design object from the one fitted above: it uses
`example_aerial_counts`, and its effort comes from the standard aerial
path rather than from the GLMM.

``` r

# A complementary design over the same survey period
aerial_int_cal <- creel_calendar("2024-06-03", "2024-07-06", strata = "day_type")

design_int <- creel_design(
  aerial_int_cal,
  date        = date,
  strata      = day_type,
  survey_type = "aerial",
  visibility_correction = "none",
  angler_ratio = 1,
  angler_ratio_se = 0,
  h_open      = 14
)
design_int <- add_counts(design_int, example_aerial_counts)
design_int <- add_interviews(design_int, example_aerial_interviews,
  catch       = walleye_catch,
  effort      = hours_fished,
  trip_status = trip_status
)
#> Warning: ! No `n_anglers` provided — assuming 1 angler per interview.
#> ℹ Pass `n_anglers = <column>` to use actual party sizes for angler-hour
#>   normalization.
#> ℹ If the interviews really are one angler each, pass `n_anglers = 1` to state
#>   that and silence this warning.
#> ℹ 15 interviews have zero catch.
#>   Zero catch is usual; check it is not missing data recorded as 0.
#> ℹ Added 48 interviews: 48 complete (100%), 0 incomplete (0%)
catch_rate <- estimate_catch_rate(design_int)
#> ℹ Using complete trips for CPUE estimation
#>   (n=48, 100% of 48 interviews) [default]
print(catch_rate)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Ratio-of-Means CPUE
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Unit: fish/party-hour
#> 
#> # A tibble: 1 × 5
#>   estimate     se ci_lower ci_upper     n
#>      <dbl>  <dbl>    <dbl>    <dbl> <int>
#> 1    0.413 0.0520    0.311    0.515    48

total_catch <- estimate_total_catch(design_int)
#> Warning in estimate_total_catch(design_int): Rate and effort may be in different units.
#> ✖ `n_anglers` was not supplied, so the rate is per party-hour while
#>   count-derived effort is per angler.
#> ℹ The product is correct only if every party is one angler. Pass
#>   `add_interviews(n_anglers = <col>)` to normalise.
print(total_catch)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Total Catch (Effort × CPUE)
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Effort target: period_total
#> 
#> # A tibble: 1 × 5
#>   estimate    se ci_lower ci_upper     n
#>      <dbl> <dbl>    <dbl>    <dbl> <int>
#> 1    7178.    NA       NA       NA    48
```

This example leaves out on purpose the party size that
`example_aerial_interviews` carries (`n_anglers`), to show what happens
without it.
[`add_interviews()`](https://chrischizinski.com/tidycreel/dev/reference/add_interviews.md)
warns that it is assuming one angler per interview, and
[`estimate_total_catch()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_total_catch.md)
warns that the CPUE it multiplies is per *party*-hour while the
count-derived effort is angler-hours. Both warnings are correct and are
left visible: with one angler per party the total is right as printed,
and with larger parties it is **overstated**, roughly by the mean party
size, because a party-hour rate is multiplied by an effort that already
counts every angler. Here the total is 3507.6 with an unknown unit;
passing `n_anglers = n_anglers` gives 1838.4 fish, as in
[`vignette("aerial-surveys")`](https://chrischizinski.com/tidycreel/dev/articles/aerial-surveys.md).
Supply `n_anglers` from your own interview data, or state a constant
party size (`n_anglers = 1`) when every interview really is a single
angler.

The total’s standard error prints as `NA`. This design declares
`visibility_correction = "none"`: no detection study was done, so the
uncertainty of detection is unknown, and a total that leaves it out
would be a lower bound reported as an SE. The total effort’s SE is `NA`
for the same reason. Supply `visibility_correction` with `visibility_se`
from a detection study to get a finite SE (see
[`vignette("aerial-surveys")`](https://chrischizinski.com/tidycreel/dev/articles/aerial-surveys.md)).

## Comparison: Simple vs. GLMM Estimator

The two estimators use the counts at different grains, from the same
design.

The GLMM consumes each overflight individually — the flight times are
what it fits the diurnal curve against, so the four flights a day must
stay four rows.

The simple estimator does not model time. It treats each count as an
instantaneous estimate of the anglers present and expands by
`h_open / v`. Four flights on one day are therefore four looks at that
day, not four sampled days: they average to the day’s mean occupancy,
and the spread between them becomes the within-day variance component.
Naming `count_time_col` is what performs that aggregation. Without it
the four counts would be summed as separate sampling units and the
estimate would come back four times too large.

``` r

# Simple aerial estimator on the same design -- no diurnal correction. The
# flights are four looks at each day, so they average rather than accumulate.
simple_result <- estimate_effort(design, target = "sampled_days")

# GLMM result from above
# glmm_result already computed

# Side-by-side comparison. Both estimators report a total across the sampled
# days, so the two numbers answer the same question and the gap between them is
# the diurnal correction.
comparison <- data.frame(
  method = c("GLMM", "Simple"),
  estimate = c(
    glmm_result$estimates$estimate,
    simple_result$estimates$estimate
  ),
  target = c(
    glmm_result$effort_target,
    simple_result$effort_target
  ),
  stringsAsFactors = FALSE
)

print(comparison)
#>   method estimate       target
#> 1   GLMM 3740.386 sampled_days
#> 2 Simple 4270.000 sampled_days
```

The `target` column is worth checking rather than assuming. Both
estimators report `sampled_days`, so the two totals cover the same
twelve days and the gap between them is the diurnal correction and
nothing else. The GLMM corrects for the fact that all flights occurred
at fixed hours (7, 10, 13, 16); the simple estimator treats each count
as representative of the full open-water window, which inflates or
deflates the total depending on where the peak falls in the diurnal
curve. Here it inflates, so the corrected estimate is the lower of the
two.

Neither estimator reports a confidence interval here, for the reason
given under “Variance and Confidence Intervals” above: this design
declares `visibility_correction = "none"`.

## Estimating Within Strata

Pass `by` to get one row per stratum, typically the design strata. The
strata enter ONE model as additive fixed effects —
`n_anglers ~ poly(time_of_flight, 2) + day_type + (1 | date)` — so
weekdays and weekends share the diurnal curve’s shape and differ in its
level, and each stratum expands by its own sampled days. This follows
Askey et al. (2018), where day type is additive in every model structure
compared. Fitting one model rather than one per stratum shares strength
across strata, which matters when a stratum has few flights. The grouped
path uses the delta method only (`boot = FALSE`).

The design below declares a measured visibility correction, so the
grouped rows carry standard errors; with `"none"` they would be `NA`, as
explained above.

``` r

design_v <- creel_design(
  aerial_cal,
  date        = date,
  strata      = day_type,
  survey_type = "aerial",
  visibility_correction = 0.85,
  visibility_se = 0.05,
  angler_ratio = 1,
  angler_ratio_se = 0,
  h_open      = 14
)
design_v <- add_counts(design_v, example_aerial_glmm_counts,
  count_col      = n_anglers,
  count_time_col = time_of_flight
)

glmm_by_day <- estimate_effort_aerial_glmm(
  design_v,
  time_col = time_of_flight,
  by = day_type
)
#> ℹ BIC(interaction) - BIC(additive) = 7.6: favours the shared shape used for
#>   this estimate.
#> ℹ Integration window start derived from data: 6.5 h (earliest flight - 0.5 h).
#>   Specify `open_start` in `creel_design()` for a fixed fishery opening time.
print(glmm_by_day)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: aerial_glmm_total
#> Variance: delta
#> Confidence level: 95%
#> Grouped by: day_type
#> Effort target: sampled_days
#> Unit: angler-hours
#> model: 355.8 and 231.9 (included in se)
#> visibility: 176.8 and 82.0 (included in se)
#> angler_ratio: 0 and 0 (included in se)
#> 
#> # A tibble: 2 × 8
#>   day_type estimate    se se_between se_within ci_lower ci_upper     n
#>   <chr>       <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int>
#> 1 weekday     3006.  397.       397.        NA    2228.    3785.    32
#> 2 weekend     1394.  246.       246.        NA     912.    1876.    16
```

The shared-shape assumption can fail: Smucker et al. (2010) report
weekday and weekend diurnal effort that differ in shape. The grouped fit
therefore also fits the time × stratum interaction and reports the BIC
difference as a message. A negative difference favours separate shapes;
fit them by passing `formula`, for example
`n_anglers ~ poly(time_of_flight, 2) * day_type + (1 | date)`. The
estimate is never switched automatically, because a model chosen from
the data is not reflected in the reported standard error.

**Combining strata.** The stratum estimates are correlated: every
stratum is predicted from the same fixed effects, and the visibility
correction and angler-to-people ratio are single estimates that multiply
every stratum. The result carries their joint covariance as
`strata_vcov`. Use it for the SE of the summed total; adding the rows’
SEs in quadrature treats them as independent and understates it.

``` r

# SE of the summed total, from the joint covariance
sqrt(sum(glmm_by_day$strata_vcov))
#> [1] 501.285

# The quadrature sum, shown only to compare -- it understates the SE
sqrt(sum(glmm_by_day$estimates$se^2))
#> [1] 467.2771
```

## Results as Data

The per-stratum result converts to a tibble with its method and variance
method as columns, and plots. `design_v` declares a measured visibility
correction with its SE, so each stratum carries an interval and the plot
draws it; on a design with `visibility_correction = "none"` the
intervals are `NA` (see above) and the plot shows the point estimates
alone.

``` r

effort_tbl <- tibble::as_tibble(glmm_by_day)
effort_tbl
#> # A tibble: 2 × 13
#>   day_type estimate    se se_between se_within ci_lower ci_upper     n method   
#>   <chr>       <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int> <chr>    
#> 1 weekday     3006.  397.       397.        NA    2228.    3785.    32 aerial_g…
#> 2 weekend     1394.  246.       246.        NA     912.    1876.    16 aerial_g…
#> # ℹ 4 more variables: variance_method <chr>, conf_level <dbl>,
#> #   effort_target <chr>, unit <chr>
effort_tbl$unit
#> [1] "angler-hours" "angler-hours"

ggplot2::autoplot(glmm_by_day)
```

![GLMM effort estimates in angler-hours for weekdays and weekends, each
with its confidence
interval.](aerial-glmm_files/figure-html/results-1.png)

The effort is in angler-hours: the integral of a count over hours,
scaled by the angler ratio and the visibility correction, the same unit
[`estimate_effort()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_effort.md)
reports for an aerial design.

## Custom Formula

For surveys where a linear temporal term is sufficient — or where the
analyst prefers to control the model structure directly — pass a custom
`formula`. The formula must reference the actual count column
(`n_anglers`) and the time column by its exact name in the data.

``` r

glmm_linear <- estimate_effort_aerial_glmm(
  design,
  time_col = time_of_flight,
  formula  = n_anglers ~ time_of_flight + (1 | date)
)
#> boundary (singular) fit: see help('isSingular')
#> ℹ Integration window start derived from data: 6.5 h (earliest flight - 0.5 h).
#>   Specify `open_start` in `creel_design()` for a fixed fishery opening time.
print(glmm_linear)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: aerial_glmm_total
#> Variance: delta
#> Confidence level: 95%
#> Effort target: sampled_days
#> Unit: angler-hours
#> model: 945.1 (known, but se is `NA`)
#> visibility: NA (unknown, so se is `NA`)
#> angler_ratio: 0 (known, but se is `NA`)
#> 
#> # A tibble: 1 × 7
#>   estimate    se se_between se_within ci_lower ci_upper     n
#>      <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int>
#> 1    6166.    NA         NA        NA       NA       NA    48
```

A linear temporal term reduces flexibility but can improve stability
when only a few survey days are available. Use the default quadratic
formula when you have 8 or more survey days.

## References

- Askey, P. J., Ward, H., Godin, T., Boucher, M., & Northrup, S. (2018).
  Angler effort estimates from instantaneous aerial counts: use of
  high-frequency time-lapse camera data to inform model-based
  estimators. *North American Journal of Fisheries Management*, 38(1),
  194–209. <https://doi.org/10.1002/nafm.10010>

- Jones, C. M., & Pollock, K. H. (2012). Recreational angler survey
  methods: estimation of effort, harvest, and released catch. Chapter 19
  in *Fisheries Techniques* (3rd ed.), pp. 883–919. American Fisheries
  Society.

- Smucker, B. J., Lorantas, R. M., & Rosenberger, J. L. (2010).
  Correcting bias introduced by aerial counts in angler effort
  estimation. *North American Journal of Fisheries Management*, 30(4),
  1051–1061. <https://doi.org/10.1577/M09-193.1>
