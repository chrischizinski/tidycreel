# Aerial Survey Analysis with tidycreel

## Introduction

Aerial creel surveys estimate total angler effort by conducting an
instantaneous count of anglers on the water from a low-flying aircraft.
Because the aircraft captures a snapshot of angler activity at a single
moment, the count must be expanded to total effort using the hours the
fishery is open (`h_open`) and the mean trip duration of anglers on the
water (`L_bar`). The basic estimator is:

$$\widehat{E} = N_{obs} \times \frac{h_{open}}{v}$$

where $N_{obs}$ is the observed (instantaneous) angler count, $h_{open}$
is the number of hours the fishery is open per day, and $v$ is the
visibility correction factor (defaulting to 1.0 when all anglers are
detectable from the air). The mean trip duration $\bar{L}$ is estimated
from ground interviews and enters the catch rate estimation step rather
than the effort expansion step.

When not all anglers are visible from the air — for example, anglers
fishing under tree cover or in enclosed shelters — a **visibility
correction** adjusts the count upward. If observers detect only 85% of
anglers present, the corrected effort estimate is scaled by
$1/0.85 \approx 1.18$, yielding a higher and more accurate total. The
`visibility_correction` argument to
[`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md)
captures this calibration constant.

## Example Data

This vignette uses two built-in datasets representing a hypothetical
summer walleye and bass fishery at a Nebraska reservoir in June-July
2024.

``` r
library(tidycreel)

data(example_aerial_counts)
data(example_aerial_interviews)

head(example_aerial_counts)
#>         date day_type n_anglers
#> 1 2024-06-03  weekday        39
#> 2 2024-06-05  weekday        32
#> 3 2024-06-07  weekday        29
#> 4 2024-06-08  weekend        45
#> 5 2024-06-09  weekend        51
#> 6 2024-06-10  weekday        34
head(example_aerial_interviews)
#>         date day_type trip_status hours_fished walleye_catch walleye_kept
#> 1 2024-06-03  weekday    complete          3.4             3            2
#> 2 2024-06-03  weekday    complete          3.2             0            0
#> 3 2024-06-03  weekday    complete          2.5             0            0
#> 4 2024-06-05  weekday    complete          4.9             1            0
#> 5 2024-06-05  weekday    complete          2.2             1            0
#> 6 2024-06-05  weekday    complete          2.3             1            0
#>   bass_catch bass_kept
#> 1          0         0
#> 2          0         0
#> 3          0         0
#> 4          1         0
#> 5          0         0
#> 6          1         1
```

`example_aerial_counts` contains 16 sampling days (one overflight per
day), each recording an instantaneous count of anglers on the water.
Weekday counts range from 15 to 40 anglers; weekend counts range from 40
to 80. The `example_aerial_interviews` dataset contains 48 angler
interviews (3 per sampling day) with trip duration in `hours_fished` and
catch by species.

## Design Construction

Build an aerial survey design with
[`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md).
The `h_open` argument is required for aerial surveys — it specifies the
number of hours the fishery is open each day, which sets the expansion
factor for the instantaneous count.

``` r
# Build the survey calendar from the unique count dates
aerial_cal <- data.frame(
  date = example_aerial_counts$date,
  day_type = example_aerial_counts$day_type,
  stringsAsFactors = FALSE
)

design <- creel_design(
  aerial_cal,
  date        = date,
  strata      = day_type,
  survey_type = "aerial",
  h_open      = 14
)

print(design)
#> 
#> ── Creel Survey Design ─────────────────────────────────────────────────────────
#> Type: "aerial"
#> Date column: date
#> Strata: day_type
#> Calendar: 16 days (2024-06-03 to 2024-07-06)
#> day_type: 2 levels
#> Counts: "none"
#> Interviews: "none"
#> Sections: "none"
#> 
#> ── Aerial Survey Design ──
#> 
#> Hours open (h_open): 14
```

The printed design confirms the survey type, `h_open`, and the number of
sampling days in each stratum.

## Adding Count Data and Estimating Effort

Attach the aerial count data with
[`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md).
The `n_anglers` column is auto-detected as the count variable.

``` r
design <- add_counts(design, example_aerial_counts)
#> Warning in svydesign.default(ids = psu_formula, strata = strata_formula, : No
#> weights or probabilities supplied, assuming equal probability
```

Aerial effort estimation requires interview data to be attached before
calling
[`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md),
because the estimator uses the mean trip duration ($\bar{L}$) from
ground interviews to confirm the expansion factor. Attach the interview
data with
[`add_interviews()`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md),
then estimate total effort.

``` r
design <- suppressWarnings(add_interviews(
  design,
  example_aerial_interviews,
  catch       = walleye_catch,
  effort      = hours_fished,
  trip_status = trip_status
))
#> ℹ No `n_anglers` provided — assuming 1 angler per interview.
#> ℹ Pass `n_anglers = <column>` to use actual party sizes for angler-hour
#>   normalization.
#> ℹ Added 48 interviews: 48 complete (100%), 0 incomplete (0%)
```

``` r
effort <- suppressWarnings(estimate_effort(design))
print(effort)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: aerial_total
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Effort target: sampled_days
#> 
#> # A tibble: 1 × 7
#>   estimate    se se_between se_within ci_lower ci_upper     n
#>      <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int>
#> 1     8918  658.       658.         0    7506.   10330.    16
```

The `estimate` column is the projected total angler-hours over the full
survey period. The `se` and `se_between` components quantify between-day
variability in the instantaneous counts, and `ci_lower` / `ci_upper`
give the 95% confidence interval.

## Visibility Correction

When aerial observers cannot detect all anglers on the water, the raw
count underestimates true effort. Supply a `visibility_correction` to
[`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md)
to account for this. A value of 0.85 means observers detected 85% of the
anglers actually present; the effort estimate is scaled up by $1/0.85$.

``` r
design_corr <- creel_design(
  aerial_cal,
  date = date,
  strata = day_type,
  survey_type = "aerial",
  h_open = 14,
  visibility_correction = 0.85
)

design_corr <- add_counts(design_corr, example_aerial_counts)
#> Warning in svydesign.default(ids = psu_formula, strata = strata_formula, : No
#> weights or probabilities supplied, assuming equal probability
design_corr <- suppressWarnings(add_interviews(
  design_corr,
  example_aerial_interviews,
  catch       = walleye_catch,
  effort      = hours_fished,
  trip_status = trip_status
))
#> ℹ No `n_anglers` provided — assuming 1 angler per interview.
#> ℹ Pass `n_anglers = <column>` to use actual party sizes for angler-hour
#>   normalization.
#> ℹ Added 48 interviews: 48 complete (100%), 0 incomplete (0%)

effort_corr <- suppressWarnings(estimate_effort(design_corr))
print(effort_corr)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: aerial_total
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Effort target: sampled_days
#> 
#> # A tibble: 1 × 7
#>   estimate    se se_between se_within ci_lower ci_upper     n
#>      <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int>
#> 1   10492.  774.       774.         0    8831.   12153.    16
```

Comparing the two estimates: the corrected effort is higher than the
uncorrected estimate because the visibility correction inflates the
count to account for undetected anglers.

``` r
cat(
  "Uncorrected effort:", round(effort$estimate[[1]], 0), "angler-hours\n",
  "Corrected effort (v=0.85):", round(effort_corr$estimate[[1]], 0), "angler-hours\n"
)
#> Uncorrected effort: 8918 angler-hours
#>  Corrected effort (v=0.85): 10492 angler-hours
```

## Interview-Based Catch Estimation

Aerial designs use the same interview workflow as other `tidycreel`
designs. The catch rate estimator computes CPUE (walleye per
angler-hour) from the complete-trip interviews already attached to the
design.

``` r
catch_rate <- suppressWarnings(estimate_catch_rate(design))
#> ℹ Using complete trips for CPUE estimation
#>   (n=48, 100% of 48 interviews) [default]
print(catch_rate)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Ratio-of-Means CPUE
#> Variance: Taylor linearization
#> Confidence level: 95%
#> 
#> # A tibble: 1 × 5
#>   estimate     se ci_lower ci_upper     n
#>      <dbl>  <dbl>    <dbl>    <dbl> <int>
#> 1    0.413 0.0601    0.295    0.531    48
```

[`estimate_total_catch()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_catch.md)
multiplies the CPUE estimate by the total effort estimate to project
total walleye catch over the survey period.

``` r
total_catch <- suppressWarnings(estimate_total_catch(design))
print(total_catch)
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
#> 1     251.  45.3     162.     339.    48
```

The delta-method standard error on total catch accounts for variance in
both the effort estimate and the CPUE estimate.

## Summary

The complete aerial survey workflow in `tidycreel` consists of four
steps:

1.  `creel_design(..., survey_type = "aerial", h_open = N)` — define the
    survey with the required `h_open` expansion factor and optional
    `visibility_correction`.
2.  `add_counts(design, counts)` — attach the instantaneous angler count
    data from each overflight.
3.  `add_interviews(design, interviews, catch = ..., effort = hours_fished, ...)`
    — attach ground interview data for catch rate estimation.
4.  [`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md),
    [`estimate_catch_rate()`](https://chrischizinski.github.io/tidycreel/reference/estimate_catch_rate.md),
    [`estimate_total_catch()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_catch.md)
    — run the estimators.

All estimators return `creel_estimates` objects with point estimates,
standard errors, and 95% confidence intervals. Use
[`print()`](https://rdrr.io/r/base/print.html) to display results.

## References

- Jones, C. M., & Pollock, K. H. (2012). Recreational survey methods:
  estimation of effort, harvest, and abundance. Chapter 19 in *Fisheries
  Techniques* (3rd ed.), pp. 883-919. American Fisheries Society.

- Malvestuto, S. P. (1996). Sampling the recreational angler. Chapter 20
  in *Fisheries Techniques* (2nd ed.), pp. 591-623. American Fisheries
  Society.

- Pollock, K. H., Jones, C. M., & Brown, T. L. (1994). *Angler Survey
  Methods and Their Applications in Fisheries Management*. American
  Fisheries Society Special Publication 25. Chapter 12: Aerial counts.
