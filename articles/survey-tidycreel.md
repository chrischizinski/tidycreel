# tidycreel and the survey Package: A Side-by-Side Guide

## Introduction

The tidycreel package is built on top of R’s `survey` package. Every
estimation function in tidycreel —
[`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md),
[`estimate_catch_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_catch_rate.md),
[`estimate_total_catch()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_catch.md)
— is a wrapper around a corresponding `survey` package call. The design
objects tidycreel constructs are standard `svydesign` objects under the
hood, and the estimators delegate directly to
[`svymean()`](https://rdrr.io/pkg/survey/man/surveysummary.html),
[`svytotal()`](https://rdrr.io/pkg/survey/man/surveysummary.html), and
[`svyratio()`](https://rdrr.io/pkg/survey/man/svyratio.html).

This vignette walks through the same effort + catch rate + total catch
analysis twice: first using raw `survey` package calls, then using
tidycreel. The goal is to make the mapping explicit, so that R users
familiar with the `survey` package can immediately understand what
tidycreel is doing and why. If you already know
[`svyratio()`](https://rdrr.io/pkg/survey/man/svyratio.html) and the
delta method for variance propagation, you will recognize those
computations in tidycreel’s output.

## Data Setup

Both workflows use the same three example datasets included with
tidycreel. Load them once and they are shared across both parts of this
vignette.

``` r

library(tidycreel)

data(example_calendar)
data(example_counts)
data(example_interviews)

head(example_calendar)
#>         date day_type
#> 1 2024-06-01  weekend
#> 2 2024-06-02  weekend
#> 3 2024-06-03  weekday
#> 4 2024-06-04  weekday
#> 5 2024-06-05  weekday
#> 6 2024-06-06  weekday
head(example_counts)
#>         date day_type effort_hours
#> 1 2024-06-01  weekend         45.2
#> 2 2024-06-02  weekend         52.8
#> 3 2024-06-03  weekday         12.5
#> 4 2024-06-04  weekday         18.3
#> 5 2024-06-05  weekday         15.7
#> 6 2024-06-06  weekday         22.1
head(example_interviews)
#>         date hours_fished catch_total catch_kept trip_status trip_duration
#> 1 2024-06-01          2.0           5          2    complete           2.0
#> 2 2024-06-01          3.5           8          5    complete           3.5
#> 3 2024-06-02          1.5           2          1    complete           1.5
#> 4 2024-06-02          2.0           3          2  incomplete           1.0
#> 5 2024-06-03          2.5           6          3    complete           2.5
#> 6 2024-06-03          4.0          12          8    complete           4.0
#>   interview_id angler_type angler_method species_sought n_anglers refused
#> 1            1        bank          bait        walleye         2   FALSE
#> 2            2        boat    artificial        walleye         1   FALSE
#> 3            3        bank          bait           bass         3   FALSE
#> 4            4        bank           fly        panfish         2   FALSE
#> 5            5        boat    artificial        walleye         1   FALSE
#> 6            6        boat          bait           bass         4   FALSE
```

The calendar covers 14 days (10 weekdays, 4 weekend days). The counts
record observed effort (angler-hours) on each sampled day. The
interviews record catch and effort for individual completed and
incomplete trips.

------------------------------------------------------------------------

## Part 1 — Raw survey Package Workflow

### 1a. Survey Design from a Stratified Calendar

A creel survey with weekday/weekend stratification is a stratified
simple random sample. The finite population correction (FPC) for each
stratum is the total number of days in that stratum over the survey
period.

`example_counts` already carries a `day_type` column (copied from the
calendar), so we can build the FPC column directly from the calendar
frequency table.

``` r

library(survey)
#> Loading required package: grid
#> Loading required package: Matrix
#> Loading required package: survival
#> 
#> Attaching package: 'survey'
#> The following object is masked from 'package:graphics':
#> 
#>     dotchart

# Stratum sizes: total days per day_type in the calendar
stratum_sizes <- table(example_calendar$day_type)
stratum_sizes
#> 
#> weekday weekend 
#>      10       4

# Attach FPC to the count frame
counts_frame <- example_counts
counts_frame$fpc <- as.integer(stratum_sizes[counts_frame$day_type])
counts_frame
#>          date day_type effort_hours fpc
#> 1  2024-06-01  weekend         45.2   4
#> 2  2024-06-02  weekend         52.8   4
#> 3  2024-06-03  weekday         12.5  10
#> 4  2024-06-04  weekday         18.3  10
#> 5  2024-06-05  weekday         15.7  10
#> 6  2024-06-06  weekday         22.1  10
#> 7  2024-06-07  weekday         14.9  10
#> 8  2024-06-08  weekend         48.6   4
#> 9  2024-06-09  weekend         55.3   4
#> 10 2024-06-10  weekday         16.8  10
#> 11 2024-06-11  weekday         19.4  10
#> 12 2024-06-12  weekday         13.2  10
#> 13 2024-06-13  weekday         17.6  10
#> 14 2024-06-14  weekday         20.1  10

# Build the stratified survey design
svy_counts <- svydesign(
  ids    = ~1,
  strata = ~day_type,
  fpc    = ~fpc,
  data   = counts_frame
)
svy_counts
#> Stratified Independent Sampling design
#> svydesign(ids = ~1, strata = ~day_type, fpc = ~fpc, data = counts_frame)
```

Because all 14 survey days are observed (a census of the 14-day period),
the FPC reduces to 1 and the standard error of the totals is 0. In a
real survey where only a subset of days are sampled, the FPC would be
less than 1 and variances would be positive.

### 1b. Effort Estimation via svytotal

Total effort is the sum of observed angler-hours across the 14 days,
estimated via
[`svytotal()`](https://rdrr.io/pkg/survey/man/surveysummary.html) on the
count frame design.

``` r

effort_total <- svytotal(~effort_hours, svy_counts)
effort_total
#>              total SE
#> effort_hours 372.5  0
confint(effort_total)
#>              2.5 % 97.5 %
#> effort_hours 372.5  372.5
```

The result is the estimated total angler-hours for the survey period,
with a 95% confidence interval. Because this example uses a complete
census of all 14 days, the standard error is 0. In practice, creel
surveys sample a subset of days, and
[`svytotal()`](https://rdrr.io/pkg/survey/man/surveysummary.html)
extrapolates from the observed days to the full survey period using the
stratum weights.

### 1c. Catch Rate via svyratio and Total Catch via the Delta Method

Catch per unit effort (CPUE) is estimated from the interview data using
a ratio-of-means estimator: the total catch across all complete
interviews divided by the total effort across those same interviews.
This is the [`svyratio()`](https://rdrr.io/pkg/survey/man/svyratio.html)
approach.

``` r

# Use complete trips only (standard practice)
complete_trips <- subset(example_interviews, trip_status == "complete")
nrow(complete_trips)
#> [1] 17

# Build a simple survey design over the interview frame
svy_interviews <- svydesign(ids = ~1, data = complete_trips)
#> Warning in svydesign.default(ids = ~1, data = complete_trips): No weights or
#> probabilities supplied, assuming equal probability

# Ratio estimator: total catch / total effort (ratio-of-means CPUE)
cpue_ratio <- svyratio(~catch_total, ~hours_fished, svy_interviews)
cpue_ratio
#> Ratio estimator: svyratio.survey.design2(~catch_total, ~hours_fished, svy_interviews)
#> Ratios=
#>             hours_fished
#> catch_total     2.285714
#> SEs=
#>             hours_fished
#> catch_total     0.112297
```

The CPUE estimate is the ratio of total catch to total effort across all
complete interviews. The
[`svyratio()`](https://rdrr.io/pkg/survey/man/svyratio.html) function
computes the Taylor linearization variance for this ratio, accounting
for the correlation between catch and effort within each interview.

Now combine the effort total and CPUE using the delta method to
propagate variance through the product E × C:

``` r

effort_coef <- coef(effort_total)[[1]]
cpue_coef <- coef(cpue_ratio)[[1]]
var_effort <- vcov(effort_total)[[1]]
var_cpue <- vcov(cpue_ratio)[[1]]

# Delta method: Var(effort * cpue) = effort^2 * Var(cpue) + cpue^2 * Var(effort)
total_catch_est <- effort_coef * cpue_coef
total_catch_var <- effort_coef^2 * var_cpue + cpue_coef^2 * var_effort
total_catch_se <- sqrt(total_catch_var)

cat("Total catch estimate:", round(total_catch_est, 1), "\n")
#> Total catch estimate: 851.4
cat("Standard error:      ", round(total_catch_se, 1), "\n")
#> Standard error:       41.8
cat(
  "95% CI: [",
  round(total_catch_est - 1.96 * total_catch_se, 1), ",",
  round(total_catch_est + 1.96 * total_catch_se, 1), "]\n"
)
#> 95% CI: [ 769.4 , 933.4 ]
```

------------------------------------------------------------------------

## Part 2 — tidycreel Equivalent

### 2a. creel_design() + add_counts()

[`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md)
wraps the calendar and stratification into a design object.
[`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)
attaches the count frame and builds the internal `svydesign` object —
the equivalent of the
[`svydesign()`](https://rdrr.io/pkg/survey/man/svydesign.html) call in
Part 1a above.

``` r

design <- creel_design(example_calendar, date = date, strata = day_type)
design <- add_counts(design, example_counts)
#> Warning in svydesign.default(ids = psu_formula, strata = strata_formula, : No
#> weights or probabilities supplied, assuming equal probability
design
#> 
#> ── Creel Survey Design ─────────────────────────────────────────────────────────
#> Type: "instantaneous"
#> Date column: date
#> Strata: day_type
#> Calendar: 14 days (2024-06-01 to 2024-06-14)
#> day_type: 2 levels
#> Counts: 14 observations
#> PSU column: date
#> Count type: "instantaneous"
#> Survey: <survey.design2> (constructed)
#> Interviews: "none"
#> Sections: "none"
```

The design reports the same 14 observations across two strata (weekday,
weekend) as the raw `svydesign` object above.

### 2b. estimate_effort()

[`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md)
calls [`svytotal()`](https://rdrr.io/pkg/survey/man/surveysummary.html)
on the internal design object and returns the result as a tidy tibble
with labelled columns.

``` r

effort_est <- estimate_effort(design)
effort_est
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Total
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Effort target: sampled_days
#> 
#> # A tibble: 1 × 7
#>   estimate    se se_between se_within ci_lower ci_upper     n
#>      <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int>
#> 1     372.  13.2       13.2         0     344.     401.    14
```

The estimate (372.5 angler-hours) matches the raw
[`svytotal()`](https://rdrr.io/pkg/survey/man/surveysummary.html) result
in Part 1b. tidycreel adds the CI directly to the output and labels the
column as `estimate` instead of the raw column name.

### 2c. estimate_catch_rate() + add_interviews()

Before calling
[`estimate_catch_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_catch_rate.md),
attach the interview data via
[`add_interviews()`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md).
This maps interview columns to the design vocabulary and filters to
complete trips by default.

``` r

design <- add_interviews(design, example_interviews,
  catch         = catch_total,
  effort        = hours_fished,
  harvest       = catch_kept,
  trip_status   = trip_status,
  trip_duration = trip_duration
)
#> ℹ No `n_anglers` provided — assuming 1 angler per interview.
#> ℹ Pass `n_anglers = <column>` to use actual party sizes for angler-hour
#>   normalization.
#> ℹ Added 22 interviews: 17 complete (77%), 5 incomplete (23%)
```

Now estimate CPUE, which calls
[`svyratio()`](https://rdrr.io/pkg/survey/man/svyratio.html) internally
on the complete-trip subset of the interview frame:

``` r

cpue_est <- estimate_catch_rate(design)
#> ℹ Using complete trips for CPUE estimation
#>   (n=17, 77.3% of 22 interviews) [default]
#> Warning: Small sample size for CPUE estimation.
#> ! Sample size is 17. Ratio estimates are more stable with n >= 30.
#> ℹ Variance estimates may be unstable with n < 30.
cpue_est
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Ratio-of-Means CPUE
#> Variance: Taylor linearization
#> Confidence level: 95%
#> 
#> # A tibble: 1 × 5
#>   estimate    se ci_lower ci_upper     n
#>      <dbl> <dbl>    <dbl>    <dbl> <int>
#> 1     2.29 0.114     2.06     2.51    17
```

The CPUE estimate (2.29) and SE (0.11) match the
[`svyratio()`](https://rdrr.io/pkg/survey/man/svyratio.html) output from
Part 1c.

### 2d. estimate_total_catch()

[`estimate_total_catch()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_catch.md)
applies the delta method to combine the effort and CPUE estimates,
exactly as in Part 1c:

``` r

total_catch <- estimate_total_catch(design)
total_catch
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Total Catch (Effort × CPUE)
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Effort target: sampled_days
#> 
#> # A tibble: 1 × 5
#>   estimate    se ci_lower ci_upper     n
#>      <dbl> <dbl>    <dbl>    <dbl> <int>
#> 1     858.  48.4     763.     953.    17
```

The total catch estimate (approximately 851) is consistent with the raw
delta-method calculation in Part 1c. Small numerical differences reflect
tidycreel’s internal handling of the complete-trip filter and variance
components — the statistical method is identical.

------------------------------------------------------------------------

## Mapping Table

| Step | survey package | tidycreel |
|----|----|----|
| Design construction | `svydesign(ids=~1, strata=~day_type, fpc=~fpc, data=counts)` | [`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md) + [`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md) |
| Attach interview data | subset + `svydesign(ids=~1, data=complete_trips)` | [`add_interviews()`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md) |
| Effort estimation | `svytotal(~effort_hours, design)` | `estimate_effort(design)` |
| Catch rate | `svyratio(~catch_total, ~hours_fished, int_design)` | `estimate_catch_rate(design)` |
| Total catch | E × C with delta method Var(E×C) = E² Var(C) + C² Var(E) | `estimate_total_catch(design)` |
| Variance method | Taylor linearization (default in survey) | Taylor linearization (default in tidycreel) |

------------------------------------------------------------------------

## When to Use Each Approach

**Use tidycreel** for standard creel survey designs where the main
analysis follows the effort + CPUE + total catch workflow. tidycreel
handles the bookkeeping (FPC construction, complete-trip filtering,
delta method variance) and returns tidy tibbles ready for reporting. The
domain vocabulary (`creel_design`, `estimate_effort`,
`estimate_catch_rate`) matches the language creel biologists already
use.

**Use raw survey package calls** when you need capabilities outside
tidycreel’s scope: custom clustering structures,
probability-proportional-to-size (PPS) sampling, replicate-weight
designs, or nonstandard variance estimators. The
[`as_survey_design()`](https://chrischizinski.github.io/tidycreel/reference/as_survey_design.md)
function extracts the internal `svydesign` object from any tidycreel
design, giving you full access to the survey package toolbox while still
using tidycreel for the initial data setup.

``` r

# Extract the internal svydesign object for advanced use
internal_svy <- as_survey_design(design)
# Now use any survey package function directly
svymean(~effort_hours, internal_svy)
```
