# Getting Started with tidycreel

## Introduction

The tidycreel package provides a tidy, pipe-friendly interface for creel
survey design and analysis. It allows fisheries biologists to work in
domain vocabulary (dates, strata, counts, effort) without needing to
understand the internals of the survey package. The workflow follows a
simple three-step pattern:

1.  **Design**: Define your survey calendar and stratification
2.  **Data**: Attach count observations to the design
3.  **Estimation**: Compute effort estimates with variance

## Survey Design

We start by loading the package and the example calendar dataset:

``` r

library(tidycreel)

# Load example calendar data
data(example_calendar)
head(example_calendar)
#>         date day_type
#> 1 2024-06-01  weekend
#> 2 2024-06-02  weekend
#> 3 2024-06-03  weekday
#> 4 2024-06-04  weekday
#> 5 2024-06-05  weekday
#> 6 2024-06-06  weekday

# Create a creel design with weekday/weekend strata
design <- creel_design(example_calendar, date = date, strata = day_type)
print(design)
#> 
#> ── Creel Survey Design ─────────────────────────────────────────────────────────
#> Type: "instantaneous"
#> Date column: date
#> Strata: day_type
#> Calendar: 14 days (2024-06-01 to 2024-06-14)
#> day_type: 2 levels
#> Counts: "none"
#> Interviews: "none"
#> Sections: "none"
```

The
[`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md)
function uses tidy selectors, so you can specify columns by name without
quotes. The design object captures the survey structure: 14 days with
weekday/weekend stratification.

## Adding Count Data

Next, we attach instantaneous count observations to the design:

``` r

# Load example count data
data(example_counts)
head(example_counts)
#>         date day_type effort_hours
#> 1 2024-06-01  weekend         45.2
#> 2 2024-06-02  weekend         52.8
#> 3 2024-06-03  weekday         12.5
#> 4 2024-06-04  weekday         18.3
#> 5 2024-06-05  weekday         15.7
#> 6 2024-06-06  weekday         22.1

# Attach counts to the design
design <- add_counts(design, example_counts)
#> Warning in svydesign.default(ids = psu_formula, strata = strata_formula, : No
#> weights or probabilities supplied, assuming equal probability
print(design)
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

The
[`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)
function validates that the count data matches the design structure,
then constructs the internal survey design object. Notice that the
design now shows count data attached with 14 observations.

## Estimating Total Effort

With count data attached, we can estimate total effort across the entire
survey period:

``` r

# Estimate total effort
result <- estimate_effort(design)
print(result)
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

The result shows the estimated total effort, standard error, and 95%
confidence interval. The estimate is approximately 358 angler-hours over
the 14-day period.

## Grouped Estimation

We can also compute estimates separately for each stratum or group using
the `by` parameter:

``` r

# Estimate effort by day_type
result_by_day <- estimate_effort(design, by = day_type)
print(result_by_day)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Total
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Grouped by: day_type
#> Effort target: sampled_days
#> 
#> # A tibble: 2 × 8
#>   day_type estimate    se se_between se_within ci_lower ci_upper     n
#>   <chr>       <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <dbl>
#> 1 weekday      171.  9.67       9.67         0     150.     192.    10
#> 2 weekend      202.  8.95       8.95         0     182.     221.     4
```

The grouped results show separate estimates for weekday and weekend
periods. Notice that weekend effort (approximately 250 hours) is much
higher than weekday effort (approximately 108 hours), reflecting typical
recreational fishing patterns.

The `by` parameter accepts tidy selectors, so you can group by multiple
columns or use tidyselect helpers like `starts_with()`.

## Variance Methods

By default,
[`estimate_effort()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md)
uses Taylor linearization for variance estimation. The package also
supports bootstrap and jackknife methods:

``` r

# Bootstrap variance estimation (500 replicates)
set.seed(123) # For reproducibility
result_boot <- estimate_effort(design, variance = "bootstrap")
print(result_boot)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Total
#> Variance: Bootstrap
#> Confidence level: 95%
#> Effort target: sampled_days
#> 
#> # A tibble: 1 × 7
#>   estimate    se se_between se_within ci_lower ci_upper     n
#>      <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int>
#> 1     372.  13.5       13.5         0     343.     402.    14

# Jackknife variance estimation
result_jk <- estimate_effort(design, variance = "jackknife")
print(result_jk)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Total
#> Variance: Jackknife
#> Confidence level: 95%
#> Effort target: sampled_days
#> 
#> # A tibble: 1 × 7
#>   estimate    se se_between se_within ci_lower ci_upper     n
#>      <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int>
#> 1     372.  13.2       13.2         0     344.     401.    14
```

**When to use each method:**

- **Taylor linearization** (default): Computationally efficient and
  appropriate for most smooth statistics. This is the recommended
  default.
- **Bootstrap**: Use when working with non-smooth statistics or when you
  want to verify Taylor linearization assumptions. More computationally
  intensive.
- **Jackknife**: Alternative resampling method that is deterministic
  (unlike bootstrap). Useful for verification or when bootstrap is too
  slow.

All three methods work with grouped estimation as well:

``` r

# Grouped estimation with bootstrap variance
set.seed(123)
result_grouped_boot <- estimate_effort(design, by = day_type, variance = "bootstrap")
print(result_grouped_boot)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Total
#> Variance: Bootstrap
#> Confidence level: 95%
#> Grouped by: day_type
#> Effort target: sampled_days
#> 
#> # A tibble: 2 × 8
#>   day_type estimate    se se_between se_within ci_lower ci_upper     n
#>   <chr>       <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <dbl>
#> 1 weekday      171. 10.3       10.3          0     148.     193.    10
#> 2 weekend      202.  8.78       8.78         0     183.     221.     4
```

## Schedule-Defined Special Strata

If your survey calendar includes prospective high-use or other special
periods, the same three-step workflow still applies. The difference is
that the schedule may carry a resolved `final_stratum` column from
`generate_schedule(..., special_periods = ...)`, and that resolved
stratum should drive the analysis design.

``` r

sched <- generate_schedule(
  start_date = "2027-07-24",
  end_date = "2027-08-04",
  n_periods = 1,
  sampling_rate = 0.5,
  include_all = TRUE,
  special_periods = opener_periods,
  seed = 42
)

calendar_for_design <- transform(
  sched[, c("date", "final_stratum")],
  analysis_stratum = ifelse(grepl("^high_use", final_stratum), final_stratum, "regular")
)[, c("date", "analysis_stratum")]

design_special <- creel_design(
  calendar_for_design,
  date = date,
  strata = analysis_stratum
)
```

Once counts and interviews are attached,
`estimate_effort(..., target = "period_total")` and the
total-catch/product estimators use the declared analysis strata
directly. If one of those strata is too sparse for variance estimation,
tidycreel names the sparse stratum in its diagnostic instead of failing
opaquely.

## Next Steps

This vignette covers the core tidycreel workflow for instantaneous count
surveys. For more details on specific functions, see their help pages:

- [`?creel_design`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md) -
  Define survey calendar and stratification
- [`?add_counts`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md) -
  Attach count data to a design
- [`?estimate_effort`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort.md) -
  Compute effort estimates with variance
- [`?as_survey_design`](https://chrischizinski.github.io/tidycreel/reference/as_survey_design.md) -
  Extract internal survey object for advanced use

For information on the example datasets:

- [`?example_calendar`](https://chrischizinski.github.io/tidycreel/reference/example_calendar.md) -
  Example survey calendar
- [`?example_counts`](https://chrischizinski.github.io/tidycreel/reference/example_counts.md) -
  Example count observations
