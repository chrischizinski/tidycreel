# Aerial Survey Analysis with tidycreel

## Introduction

Aerial creel surveys estimate total angler effort by conducting an
instantaneous count of anglers on the water from a low-flying aircraft.
Because the aircraft captures a snapshot of angler activity at a single
moment, the count must be expanded to a day’s effort using the hours the
fishery is open (`h_open`). The basic estimator for a day is:

``` math
\hat{E} = N_{obs} \times h_{open} \times \frac{a}{v}
```

where $`N_{obs}`$ is the observed (instantaneous) count, $`h_{open}`$ is
the number of hours the fishery is open per day, $`a`$ is the angler
ratio (the proportion of people counted who are anglers; 1 when every
person counted is fishing), and $`v`$ is the **detection probability** —
the proportion of anglers present that are detected from the aircraft.
Effort comes from the counts alone; ground interviews supply the catch
rate.

When not all anglers are visible from the air — for example, anglers
fishing under tree cover or in enclosed shelters — a **visibility
correction** adjusts the count upward. If observers detect only 85% of
anglers present, the corrected effort estimate is scaled by
$`1 / 0.85 \approx 1.18`$, yielding a higher and more accurate total.
The `visibility_correction` argument to
[`creel_design()`](https://chrischizinski.com/tidycreel/dev/reference/creel_design.md)
carries $`v`$, and is required for an aerial design: pass `"none"` to
state explicitly that no correction applies.

### $`v`$ is the reciprocal of the published ratio

Field studies do not report $`v`$ directly. The standard ground-truthing
method reports the ratio

``` math
r = \frac{\text{ground count}}{\text{aerial count}}
```

which is **greater than 1** whenever the aircraft undercounts — Smucker
et al. (2010) report $`r = 2.69`$ for shore anglers. Because
`visibility_correction` is a probability, convert before supplying it:

``` math
v = 1 / r \qquad\text{so}\qquad r = 2.69 \;\longrightarrow\; v = 0.372
```

Passing $`r`$ directly is rejected by the `(0, 1]` check rather than
silently accepted, because the two parameterisations differ by a factor
of $`r^2`$ in the effort estimate.

### The correction is estimated, so it carries uncertainty

$`v`$ is estimated from paired air–ground counts, and the standard field
method reports its standard error as routine output. Supply it as
`visibility_se` — on the same probability scale — and that uncertainty
is propagated into the effort SE. For an SE published on the ratio
scale, convert with $`SE(v) = SE(r) / r^2`$.

Because one estimate of $`v`$ divides every scaled count, it is a
*shared* multiplier: its contribution enters once at the total and does
not shrink as more flights are flown. Omitting `visibility_se` reports
the component as absent rather than as zero — a zero would be
indistinguishable from never having propagated it at all.

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
#>   bass_catch bass_kept n_anglers
#> 1          0         0         2
#> 2          0         0         2
#> 3          0         0         2
#> 4          1         0         2
#> 5          0         0         1
#> 6          1         1         3
```

`example_aerial_counts` contains 16 sampling days (one overflight per
day), each recording an instantaneous count of anglers on the water.
Weekday counts range from 15 to 40 anglers; weekend counts range from 40
to 80. The `example_aerial_interviews` dataset contains 48 angler
interviews (3 per sampling day) with trip duration in `hours_fished` and
catch by species.

## Design Construction

Build an aerial survey design with
[`creel_design()`](https://chrischizinski.com/tidycreel/dev/reference/creel_design.md).
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
  visibility_correction = "none",
  angler_ratio = 1,
  angler_ratio_se = 0,
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
#> Visibility correction: "none" (declared; SE is "NA")
#> Angler-to-people ratio: 1
#> Angler ratio SE: 0
```

The printed design confirms the survey type, `h_open`, and the number of
sampling days in each stratum.

## Adding Count Data and Estimating Effort

Attach the aerial count data with
[`add_counts()`](https://chrischizinski.com/tidycreel/dev/reference/add_counts.md).
The `n_anglers` column is auto-detected as the count variable.

``` r

design <- add_counts(design, example_aerial_counts)
```

Aerial effort comes from the counts alone: each day’s count times
`h_open`, scaled by the angler ratio and the visibility correction.
Interviews are not needed for effort; they supply the catch rate later
on. They are attached here so the same design serves both. Each row is a
party, so `n_anglers` gives its size and the catch rate comes out per
angler-hour, the unit of aerial effort.

``` r

design <- add_interviews(
  design,
  example_aerial_interviews,
  catch       = walleye_catch,
  effort      = hours_fished,
  trip_status = trip_status,
  n_anglers   = n_anglers
)
#> ℹ 15 interviews have zero catch.
#>   Zero catch is usual; check it is not missing data recorded as 0.
#> ℹ Added 48 interviews: 48 complete (100%), 0 incomplete (0%)
```

``` r

effort <- estimate_effort(design)
print(effort)
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

The `estimate` column is the total angler-hours over the calendar given
to
[`creel_design()`](https://chrischizinski.com/tidycreel/dev/reference/creel_design.md),
and `se_between` quantifies between-day variability in the instantaneous
counts. This calendar holds only the 16 flown days, so the total covers
those days. If your calendar lists every day of the season, flown or
not, ask for the season total with `target = "period_total"`; the
default, `"sampled_days"`, totals only the days flown (see
[`vignette("tidycreel")`](https://chrischizinski.com/tidycreel/dev/articles/tidycreel.md)).

`se`, `ci_lower` and `ci_upper` are `NA`, and that is the correct output
for this design rather than a gap in it.
[`creel_design()`](https://chrischizinski.com/tidycreel/dev/reference/creel_design.md)
above was given `visibility_correction = "none"`, which declares that no
detection study was done. The between-day component is known, but a
component of the total’s uncertainty is not, and a standard error that
silently omitted it would describe a survey more precise than this one.
`NA` says the uncertainty was never propagated; `0` would say it was
measured and found to be nothing. The next section supplies a correction
*and* its standard error, and the interval appears.

## Visibility Correction

When aerial observers cannot detect all anglers on the water, the raw
count underestimates true effort. Supply a `visibility_correction` to
[`creel_design()`](https://chrischizinski.com/tidycreel/dev/reference/creel_design.md)
to account for this. A value of 0.85 means observers detected 85% of the
anglers actually present; the effort estimate is scaled up by
$`1 / 0.85`$.

Here the correction is accompanied by `visibility_se`, so the reported
effort SE includes the uncertainty in the correction itself rather than
treating 0.85 as exactly known.

``` r

design_corr <- creel_design(
  aerial_cal,
  date = date,
  strata = day_type,
  survey_type = "aerial",
  h_open = 14,
  visibility_correction = 0.85,
  angler_ratio = 1,
  angler_ratio_se = 0,
  visibility_se = 0.04
)

design_corr <- add_counts(design_corr, example_aerial_counts)
design_corr <- add_interviews(
  design_corr,
  example_aerial_interviews,
  catch       = walleye_catch,
  effort      = hours_fished,
  trip_status = trip_status,
  n_anglers   = n_anglers
)
#> ℹ 15 interviews have zero catch.
#>   Zero catch is usual; check it is not missing data recorded as 0.
#> ℹ Added 48 interviews: 48 complete (100%), 0 incomplete (0%)

effort_corr <- estimate_effort(design_corr)
print(effort_corr)
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

catch_rate <- estimate_catch_rate(design)
#> ℹ Using complete trips for CPUE estimation
#>   (n=48, 100% of 48 interviews) [default]
print(catch_rate)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Ratio-of-Means CPUE
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Unit: fish/angler-hour
#> 
#> # A tibble: 1 × 5
#>   estimate     se ci_lower ci_upper     n
#>      <dbl>  <dbl>    <dbl>    <dbl> <int>
#> 1    0.217 0.0339    0.151    0.284    48
```

[`estimate_total_catch()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_total_catch.md)
multiplies the CPUE estimate by the total effort estimate to project
total walleye catch over the survey period.

``` r

total_catch <- estimate_total_catch(design)
print(total_catch)
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
#> 1    1838.    NA       NA       NA    48
```

The delta-method standard error on total catch accounts for variance in
both the effort estimate and the CPUE estimate, and for the visibility
correction and angler ratio, which scale every stratum’s effort and so
enter the total once. This design declares
`visibility_correction = "none"`, so detection uncertainty is unknown
and the SE prints as `NA`, as the effort SE does; the `design_corr`
design above, with `visibility_se`, gives a finite one.

## Results as Data

Each estimate converts to a tibble with its method, variance method and
unit as columns, and plots with its confidence interval:

``` r

tibble::as_tibble(total_catch)
#> # A tibble: 1 × 11
#>   estimate    se ci_lower ci_upper     n method        estimator variance_method
#>      <dbl> <dbl>    <dbl>    <dbl> <int> <chr>         <chr>     <chr>          
#> 1    1838.    NA       NA       NA    48 product-tota… ratio-of… taylor         
#> # ℹ 3 more variables: conf_level <dbl>, effort_target <chr>, unit <chr>

ggplot2::autoplot(effort_corr)
```

![Visibility-corrected aerial effort estimate with its 95 percent
confidence interval.](aerial-surveys_files/figure-html/results-1.png)

## Summary

The complete aerial survey workflow in `tidycreel` consists of four
steps:

1.  `creel_design(..., survey_type = "aerial", visibility_correction = v, h_open = N)`
    — define the survey with the required `h_open` expansion factor and
    the required `visibility_correction` (a detection probability, or
    `"none"` to declare that no correction applies). Add `visibility_se`
    to propagate the correction’s own uncertainty.
2.  `add_counts(design, counts)` — attach the instantaneous angler count
    data from each overflight.
3.  `add_interviews(design, interviews, catch = ..., effort = hours_fished, ...)`
    — attach ground interview data for catch rate estimation.
4.  [`estimate_effort()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_effort.md),
    [`estimate_catch_rate()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_catch_rate.md),
    [`estimate_total_catch()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_total_catch.md)
    — run the estimators.

All estimators return `creel_estimates` objects with point estimates,
standard errors, and 95% confidence intervals. Use
[`print()`](https://rdrr.io/r/base/print.html) to display results.

## References

- Jones, C. M., & Pollock, K. H. (2012). Recreational angler survey
  methods: estimation of effort, harvest, and released catch. Chapter 19
  in *Fisheries Techniques* (3rd ed.), pp. 883-919. American Fisheries
  Society.

- Malvestuto, S. P. (1996). Sampling the recreational creel. Chapter 20
  in *Fisheries Techniques* (2nd ed.), pp. 591-623. American Fisheries
  Society.

- Pollock, K. H., Jones, C. M., & Brown, T. L. (1994). *Angler Survey
  Methods and Their Applications in Fisheries Management*. American
  Fisheries Society Special Publication 25. Chapter 12: Aerial counts.
