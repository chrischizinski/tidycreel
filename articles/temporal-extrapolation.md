# Temporal Extrapolation: Monthly, Seasonal, and Annual Estimates

## Overview

Creel surveys sample a fraction of days in a season. Design-based
estimators in tidycreel automatically account for unsampled days through
survey weights — so when you call
[`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md)
or
[`estimate_total_catch()`](https://chrischizinski.github.io/tidycreel/reference/estimate_total_catch.md),
the result is already a season-total estimate, not just a sample-day
sum.

This vignette shows how to:

1.  Obtain a full-season total from a single design
2.  Break the season into monthly totals using separate monthly designs
3.  Combine monthly estimates to a season or annual total
4.  Assemble multi-estimate reports with
    [`season_summary()`](https://chrischizinski.github.io/tidycreel/reference/season_summary.md)

## How Design-Based Extrapolation Works

When you create a design with
[`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md),
the survey object assigns a **weight** to each sampled day. A day
sampled at rate $f$ receives weight $1/f$, so its observed angler-hours
represent $1/f$ days of that stratum type. The estimator then sums
weighted observations across strata to produce a population total for
the entire design period.

In practice this means:

- A season design covering May–September gives you a **season-total**
  estimate.
- A monthly design covering just June gives you a **June-total**
  estimate.
- You do not need to multiply results by any “expansion factor” — the
  weights already perform the extrapolation.

## Building a Season-Long Dataset

``` r
library(tidycreel)

set.seed(2024)

# Full season: May 1 – September 30 (184 days)
all_dates <- seq(as.Date("2024-05-01"), as.Date("2024-09-30"), by = "1 day")
day_types <- ifelse(
  as.integer(format(all_dates, "%u")) %in% c(6L, 7L), "weekend", "weekday"
)

season_calendar <- data.frame(
  date       = all_dates,
  day_type   = day_types,
  open_hours = 10
)

# Stratified random sample: 30% of weekdays, 50% of weekends
set.seed(2024)
sampled <- ave(
  seq_along(all_dates), day_types,
  FUN = function(i) {
    rate <- if (day_types[i[1]] == "weekend") 0.50 else 0.30
    as.integer(runif(length(i)) < rate)
  }
)
sampled_calendar <- season_calendar[as.logical(sampled), ]

# Generate plausible effort counts (angler-hours per count)
# Weekend counts higher than weekday
sampled_counts <- data.frame(
  date = sampled_calendar$date,
  day_type = sampled_calendar$day_type,
  n_anglers = ifelse(
    sampled_calendar$day_type == "weekend",
    round(rnorm(sum(sampled), mean = 55, sd = 18)),
    round(rnorm(sum(sampled), mean = 28, sd = 12))
  )
)
sampled_counts$n_anglers <- pmax(sampled_counts$n_anglers, 0L)

nrow(sampled_calendar) # Number of sampled days
#> [1] 58
```

## Season-Total Effort

Pass the sampled calendar to
[`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md),
attach the counts, and call
[`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md).
The result is the estimated total angler-hours for the entire
May–September season.

``` r
season_design <- creel_design(
  sampled_calendar,
  date = date, strata = day_type
)
season_design <- add_counts(season_design, sampled_counts)
#> Warning in svydesign.default(ids = psu_formula, strata = strata_formula, : No
#> weights or probabilities supplied, assuming equal probability

season_effort <- estimate_effort(season_design)
season_effort$estimates
#> # A tibble: 1 × 7
#>   estimate    se se_between se_within ci_lower ci_upper     n
#>      <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int>
#> 1     2004  121.       121.         0    1763.    2245.    58
```

The `estimate` column is the season-total angler-hours; `se` is the
standard error of that total.

## Monthly Effort Totals

To break the season into monthly totals, subset the calendar and counts
to each month, build a separate monthly design, and estimate. Monthly
designs are independent, so their variances can be combined later.

``` r
months <- 5:9
month_labels <- c("May", "June", "July", "August", "September")

monthly_effort <- lapply(seq_along(months), function(i) {
  m <- months[i]
  cal_m <- sampled_calendar[format(sampled_calendar$date, "%m") == sprintf("%02d", m), ]
  cnt_m <- sampled_counts[format(sampled_counts$date, "%m") == sprintf("%02d", m), ]

  if (nrow(cal_m) == 0) {
    return(NULL)
  }

  des_m <- creel_design(cal_m, date = date, strata = day_type)
  des_m <- add_counts(des_m, cnt_m)
  est <- estimate_effort(des_m)$estimates

  cbind(month = month_labels[i], est)
})
#> Warning in svydesign.default(ids = psu_formula, strata = strata_formula, : No
#> weights or probabilities supplied, assuming equal probability
#> Warning in svydesign.default(ids = psu_formula, strata = strata_formula, : No
#> weights or probabilities supplied, assuming equal probability
#> Warning in svydesign.default(ids = psu_formula, strata = strata_formula, : No
#> weights or probabilities supplied, assuming equal probability
#> Warning in svydesign.default(ids = psu_formula, strata = strata_formula, : No
#> weights or probabilities supplied, assuming equal probability
#> Warning in svydesign.default(ids = psu_formula, strata = strata_formula, : No
#> weights or probabilities supplied, assuming equal probability

do.call(rbind, monthly_effort)
#>       month estimate       se se_between se_within ci_lower ci_upper  n
#> 1       May      257 45.19735   45.19735         0 150.1253 363.8747  9
#> 2      June      461 73.10814   73.10814         0 300.0901 621.9099 13
#> 3      July      338 57.00058   57.00058         0 206.5564 469.4436 10
#> 4    August      491 55.13036   55.13036         0 369.6589 612.3411 13
#> 5 September      457 39.73244   39.73244         0 369.5495 544.4505 13
```

## Season Total from Monthly Estimates

Because monthly estimates are independent (non-overlapping time
windows), the season total is the sum of monthly estimates and the
season variance is the sum of monthly variances.

``` r
monthly_df <- do.call(rbind, monthly_effort)

season_from_months <- data.frame(
  stratum  = "Season total",
  estimate = sum(monthly_df$estimate),
  se       = sqrt(sum(monthly_df$se^2))
)

season_from_months
#>        stratum estimate       se
#> 1 Season total     2004 123.5099
```

This should be close to the single-design season total above (small
differences are due to independent stratification within each monthly
design).

## Monthly Catch Totals

Total catch estimation follows the same monthly pattern: estimate the
catch rate from interviews, then multiply by monthly effort. First,
generate synthetic interview data:

``` r
set.seed(2024)

# Three interviews per sampled day (ensures ≥10 complete trips per month)
n_per_day <- 3L
n_int <- nrow(sampled_calendar) * n_per_day
catch_total <- rpois(n_int, lambda = 1.8)
interviews <- data.frame(
  date         = rep(sampled_calendar$date, each = n_per_day),
  day_type     = rep(sampled_calendar$day_type, each = n_per_day),
  trip_status  = "complete",
  hours_fished = round(rnorm(n_int, mean = 3.5, sd = 1.2), 1),
  catch_total  = catch_total,
  catch_kept   = pmin(rpois(n_int, lambda = 0.6), catch_total)
)
interviews$hours_fished <- pmax(interviews$hours_fished, 0.5)
```

Then loop over months exactly as for effort:

``` r
monthly_catch <- lapply(seq_along(months), function(i) {
  m <- months[i]
  cal_m <- sampled_calendar[format(sampled_calendar$date, "%m") == sprintf("%02d", m), ]
  cnt_m <- sampled_counts[format(sampled_counts$date, "%m") == sprintf("%02d", m), ]
  int_m <- interviews[format(interviews$date, "%m") == sprintf("%02d", m), ]

  if (nrow(cal_m) == 0) {
    return(NULL)
  }

  des_m <- creel_design(cal_m, date = date, strata = day_type)
  des_m <- add_counts(des_m, cnt_m)
  des_m <- add_interviews(des_m, int_m,
    trip_status = trip_status,
    catch = catch_total,
    effort = hours_fished,
    harvest = catch_kept
  )

  effort_est <- estimate_effort(des_m)
  catch_est <- estimate_total_catch(des_m)

  cbind(month = month_labels[i], catch_est$estimates)
})
#> Warning in svydesign.default(ids = psu_formula, strata = strata_formula, : No
#> weights or probabilities supplied, assuming equal probability
#> Warning: 5 interviews have zero catch.
#> ℹ Zero catch may be valid (skunked) or indicate missing data.
#> Warning: Small sample size for CPUE estimation.
#> ! Sample size is 27. Ratio estimates are more stable with n >= 30.
#> ℹ Variance estimates may be unstable with n < 30.
#> Warning in svydesign.default(ids = psu_formula, strata = strata_formula, : No
#> weights or probabilities supplied, assuming equal probability
#> Warning: 7 interviews have zero catch.
#> ℹ Zero catch may be valid (skunked) or indicate missing data.
#> Warning in svydesign.default(ids = psu_formula, strata = strata_formula, : No
#> weights or probabilities supplied, assuming equal probability
#> Warning: 4 interviews have zero catch.
#> ℹ Zero catch may be valid (skunked) or indicate missing data.
#> Warning in svydesign.default(ids = psu_formula, strata = strata_formula, : No
#> weights or probabilities supplied, assuming equal probability
#> Warning: 9 interviews have zero catch.
#> ℹ Zero catch may be valid (skunked) or indicate missing data.
#> Warning in svydesign.default(ids = psu_formula, strata = strata_formula, : No
#> weights or probabilities supplied, assuming equal probability
#> Warning: 7 interviews have zero catch.
#> ℹ Zero catch may be valid (skunked) or indicate missing data.

do.call(rbind, monthly_catch)
#>       month estimate       se  ci_lower ci_upper  n
#> 1       May 132.4452 31.63473  70.44225 194.4481 27
#> 2      June 214.1074 47.03040 121.92952 306.2853 39
#> 3      July 146.3074 31.84911  83.88432 208.7305 30
#> 4    August 247.3898 44.49361 160.18390 334.5957 39
#> 5 September 214.4188 34.00801 147.76429 281.0732 39
```

## Season-Total Catch

Sum the monthly totals:

``` r
catch_df <- do.call(rbind, monthly_catch)
season_catch <- data.frame(
  stratum  = "Season total",
  estimate = sum(catch_df$estimate),
  se       = sqrt(sum(catch_df$se^2))
)
season_catch
#>        stratum estimate       se
#> 1 Season total 954.6685 85.80913
```

## Assembling a Summary Report

[`season_summary()`](https://chrischizinski.github.io/tidycreel/reference/season_summary.md)
assembles multiple `creel_estimates` objects into a single wide tibble
for reporting. For a monthly summary, build a list with named entries
and pass it to
[`season_summary()`](https://chrischizinski.github.io/tidycreel/reference/season_summary.md).

``` r
# Collect effort and catch estimates for each month into named lists
effort_list <- list()
catch_list <- list()

for (i in seq_along(months)) {
  m <- months[i]
  label <- month_labels[i]

  cal_m <- sampled_calendar[format(sampled_calendar$date, "%m") == sprintf("%02d", m), ]
  cnt_m <- sampled_counts[format(sampled_counts$date, "%m") == sprintf("%02d", m), ]
  int_m <- interviews[format(interviews$date, "%m") == sprintf("%02d", m), ]

  if (nrow(cal_m) == 0) next

  des_m <- creel_design(cal_m, date = date, strata = day_type)
  des_m <- add_counts(des_m, cnt_m)
  des_m <- add_interviews(des_m, int_m,
    trip_status = trip_status,
    catch = catch_total,
    effort = hours_fished,
    harvest = catch_kept
  )

  effort_list[[label]] <- estimate_effort(des_m)
  catch_list[[label]] <- estimate_total_catch(des_m)
}
#> Warning in svydesign.default(ids = psu_formula, strata = strata_formula, : No
#> weights or probabilities supplied, assuming equal probability
#> Warning: 5 interviews have zero catch.
#> ℹ Zero catch may be valid (skunked) or indicate missing data.
#> Warning: Small sample size for CPUE estimation.
#> ! Sample size is 27. Ratio estimates are more stable with n >= 30.
#> ℹ Variance estimates may be unstable with n < 30.
#> Warning in svydesign.default(ids = psu_formula, strata = strata_formula, : No
#> weights or probabilities supplied, assuming equal probability
#> Warning: 7 interviews have zero catch.
#> ℹ Zero catch may be valid (skunked) or indicate missing data.
#> Warning in svydesign.default(ids = psu_formula, strata = strata_formula, : No
#> weights or probabilities supplied, assuming equal probability
#> Warning: 4 interviews have zero catch.
#> ℹ Zero catch may be valid (skunked) or indicate missing data.
#> Warning in svydesign.default(ids = psu_formula, strata = strata_formula, : No
#> weights or probabilities supplied, assuming equal probability
#> Warning: 9 interviews have zero catch.
#> ℹ Zero catch may be valid (skunked) or indicate missing data.
#> Warning in svydesign.default(ids = psu_formula, strata = strata_formula, : No
#> weights or probabilities supplied, assuming equal probability
#> Warning: 7 interviews have zero catch.
#> ℹ Zero catch may be valid (skunked) or indicate missing data.

# Assemble effort report
effort_summary <- season_summary(effort_list)
effort_summary$table
#> # A tibble: 1 × 35
#>   May_estimate May_se May_se_between May_se_within May_ci_lower May_ci_upper
#>          <dbl>  <dbl>          <dbl>         <dbl>        <dbl>        <dbl>
#> 1          257   45.2           45.2             0         150.         364.
#> # ℹ 29 more variables: May_n <int>, June_estimate <dbl>, June_se <dbl>,
#> #   June_se_between <dbl>, June_se_within <dbl>, June_ci_lower <dbl>,
#> #   June_ci_upper <dbl>, June_n <int>, July_estimate <dbl>, July_se <dbl>,
#> #   July_se_between <dbl>, July_se_within <dbl>, July_ci_lower <dbl>,
#> #   July_ci_upper <dbl>, July_n <int>, August_estimate <dbl>, August_se <dbl>,
#> #   August_se_between <dbl>, August_se_within <dbl>, August_ci_lower <dbl>,
#> #   August_ci_upper <dbl>, August_n <int>, September_estimate <dbl>, …
```

``` r
catch_summary <- season_summary(catch_list)
catch_summary$table
#> # A tibble: 1 × 25
#>   May_estimate May_se May_ci_lower May_ci_upper May_n June_estimate June_se
#>          <dbl>  <dbl>        <dbl>        <dbl> <int>         <dbl>   <dbl>
#> 1         132.   31.6         70.4         194.    27          214.    47.0
#> # ℹ 18 more variables: June_ci_lower <dbl>, June_ci_upper <dbl>, June_n <int>,
#> #   July_estimate <dbl>, July_se <dbl>, July_ci_lower <dbl>,
#> #   July_ci_upper <dbl>, July_n <int>, August_estimate <dbl>, August_se <dbl>,
#> #   August_ci_lower <dbl>, August_ci_upper <dbl>, August_n <int>,
#> #   September_estimate <dbl>, September_se <dbl>, September_ci_lower <dbl>,
#> #   September_ci_upper <dbl>, September_n <int>
```

## Annual Totals Across Multiple Seasons

When survey data span multiple calendar years, apply the same pattern at
the year level: build one design per year, run estimators, then sum
totals and combine variances.

``` r
# Conceptual pattern — replace with actual data per year
year_effort <- list()

for (yr in c(2022, 2023, 2024)) {
  cal_yr <- subset(full_calendar, format(date, "%Y") == yr)
  cnt_yr <- subset(full_counts, format(date, "%Y") == yr)

  des_yr <- creel_design(cal_yr, date = date, strata = day_type)
  des_yr <- add_counts(des_yr, cnt_yr)

  year_effort[[as.character(yr)]] <- estimate_effort(des_yr)
}

# Multi-year report table
season_summary(year_effort)$table
```

## Exporting Results

[`write_schedule()`](https://chrischizinski.github.io/tidycreel/reference/write_schedule.md)
accepts any data frame, so you can export the assembled summary table
directly:

``` r
write_schedule(effort_summary$table, "effort_by_month_2024.csv")
write_schedule(effort_summary$table, "effort_by_month_2024.xlsx")
```

## Key Principles

| Goal                     | Approach                                                                                                                                     |
|--------------------------|----------------------------------------------------------------------------------------------------------------------------------------------|
| Season total             | Single design covering full season; call [`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md) once |
| Monthly totals           | Separate monthly designs; loop over months                                                                                                   |
| Season total from months | Sum monthly estimates; sum monthly variances                                                                                                 |
| Annual comparison        | Separate annual designs; use [`season_summary()`](https://chrischizinski.github.io/tidycreel/reference/season_summary.md)                    |
| Report table             | `season_summary(named_list_of_estimates)$table`                                                                                              |

## References

- Cochran, W. G. (1977). *Sampling Techniques*, 3rd ed. Wiley, New York.

- Pollock, K. H., Jones, C. M., and Brown, T. L. (1994). *Angler Survey
  Methods and Their Applications in Fisheries Management*. American
  Fisheries Society, Bethesda, MD.

- Su, Y.-S., and Liu, P. (2025). Flexible creel survey estimators.
  *Canadian Journal of Fisheries and Aquatic Sciences*, 82, 1–27.
