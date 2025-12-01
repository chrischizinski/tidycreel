# Getting Started with tidycreel

``` r
library(tidycreel)
library(survey)
#> Loading required package: grid
#> Loading required package: Matrix
#> Loading required package: survival
#> 
#> Attaching package: 'survey'
#> The following object is masked from 'package:graphics':
#> 
#>     dotchart
library(dplyr)
#> 
#> Attaching package: 'dplyr'
#> The following objects are masked from 'package:stats':
#> 
#>     filter, lag
#> The following objects are masked from 'package:base':
#> 
#>     intersect, setdiff, setequal, union
library(ggplot2)
library(lubridate)
#> 
#> Attaching package: 'lubridate'
#> The following objects are masked from 'package:base':
#> 
#>     date, intersect, setdiff, union
```

## Introduction

The `tidycreel` package provides a survey-first framework for creel
surveys, built on the `survey` package. Estimation uses day-level survey
designs (`svydesign`) created from the sampling calendar with
[`as_day_svydesign()`](../reference/as_day_svydesign.md), and
interview-level designs for CPUE and catch estimation.

## Survey Design Types

`tidycreel` supports three main data components:

1.  Interviews (access-point or roving) and count tables
    (instantaneous/progressive).
2.  Sampling calendar (days, strata, target vs actual samples).
3.  Estimators that operate with a day-PSU `svydesign` for variance.

## Loading Example Data

The package includes example datasets that we’ll use throughout this
vignette:

``` r
# Load example datasets
interviews <- readr::read_csv(
  system.file("extdata/toy_interviews.csv", package = "tidycreel")
)
#> Rows: 26 Columns: 17
#> ── Column specification ────────────────────────────────────────────────────────
#> Delimiter: ","
#> chr  (6): interview_id, location, mode, shift_block, day_type, target_species
#> dbl  (7): party_size, hours_fished, catch_total, catch_kept, catch_released,...
#> lgl  (1): trip_complete
#> dttm (2): time_start, time_end
#> date (1): date
#> 
#> ℹ Use `spec()` to retrieve the full column specification for this data.
#> ℹ Specify the column types or set `show_col_types = FALSE` to quiet this message.
counts <- readr::read_csv(
  system.file("extdata/toy_counts.csv", package = "tidycreel")
)
#> Rows: 24 Columns: 16
#> ── Column specification ────────────────────────────────────────────────────────
#> Delimiter: ","
#> chr  (8): count_id, location, mode, weather_code, visibility, count_category...
#> dbl  (6): anglers_count, parties_count, temperature, wind_speed, count_durat...
#> dttm (1): time
#> date (1): date
#> 
#> ℹ Use `spec()` to retrieve the full column specification for this data.
#> ℹ Specify the column types or set `show_col_types = FALSE` to quiet this message.
calendar <- readr::read_csv(
  system.file("extdata/toy_calendar.csv", package = "tidycreel")
)
#> Rows: 18 Columns: 11
#> ── Column specification ────────────────────────────────────────────────────────
#> Delimiter: ","
#> chr  (6): stratum_id, day_type, season, month, shift_block, location
#> dbl  (2): target_sample, actual_sample
#> lgl  (2): weekend, holiday
#> date (1): date
#> 
#> ℹ Use `spec()` to retrieve the full column specification for this data.
#> ℹ Specify the column types or set `show_col_types = FALSE` to quiet this message.

# Preview the data
head(interviews)
#> # A tibble: 6 × 17
#>   interview_id date       time_start          time_end            location mode 
#>   <chr>        <date>     <dttm>              <dttm>              <chr>    <chr>
#> 1 INT001       2024-01-01 2024-01-01 08:30:00 2024-01-01 08:45:00 Lake_A   boat 
#> 2 INT001B      2024-01-01 2024-01-01 08:30:00 2024-01-01 08:45:00 Lake_B   boat 
#> 3 INT002       2024-01-01 2024-01-01 09:15:00 2024-01-01 09:30:00 Lake_A   bank 
#> 4 INT002B      2024-01-01 2024-01-01 09:15:00 2024-01-01 09:30:00 Lake_B   bank 
#> 5 INT003       2024-01-01 2024-01-01 10:00:00 2024-01-01 10:20:00 Lake_A   boat 
#> 6 INT003B      2024-01-01 2024-01-01 10:00:00 2024-01-01 10:20:00 Lake_B   boat 
#> # ℹ 11 more variables: shift_block <chr>, day_type <chr>, party_size <dbl>,
#> #   hours_fished <dbl>, target_species <chr>, catch_total <dbl>,
#> #   catch_kept <dbl>, catch_released <dbl>, weight_total <dbl>,
#> #   trip_complete <lgl>, effort_expansion <dbl>
head(counts)
#> # A tibble: 6 × 16
#>   count_id date       time                location mode  anglers_count
#>   <chr>    <date>     <dttm>              <chr>    <chr>         <dbl>
#> 1 C001     2024-01-01 2024-01-01 08:30:00 Lake_A   boat             10
#> 2 C002     2024-01-01 2024-01-01 09:15:00 Lake_A   bank              8
#> 3 C003     2024-01-01 2024-01-01 14:30:00 Lake_A   boat              6
#> 4 C004     2024-01-01 2024-01-01 15:20:00 Lake_A   bank              4
#> 5 C005     2024-01-02 2024-01-02 07:45:00 Lake_A   boat             12
#> 6 C006     2024-01-02 2024-01-02 09:30:00 Lake_A   boat              9
#> # ℹ 10 more variables: parties_count <dbl>, weather_code <chr>,
#> #   temperature <dbl>, wind_speed <dbl>, visibility <chr>,
#> #   count_duration <dbl>, count_category <chr>, count_value <dbl>,
#> #   shift_block <chr>, day_type <chr>
head(calendar)
#> # A tibble: 6 × 11
#>   date       stratum_id        day_type season month weekend holiday shift_block
#>   <date>     <chr>             <chr>    <chr>  <chr> <lgl>   <lgl>   <chr>      
#> 1 2024-01-01 2024-01-01-weekd… weekday  winter Janu… FALSE   FALSE   morning    
#> 2 2024-01-01 2024-01-01-weekd… weekday  winter Janu… FALSE   FALSE   morning    
#> 3 2024-01-01 2024-01-01-weekd… weekday  winter Janu… FALSE   FALSE   afternoon  
#> 4 2024-01-01 2024-01-01-weekd… weekday  winter Janu… FALSE   FALSE   afternoon  
#> 5 2024-01-01 2024-01-01-weekd… weekday  winter Janu… FALSE   FALSE   evening    
#> 6 2024-01-01 2024-01-01-weekd… weekday  winter Janu… FALSE   FALSE   evening    
#> # ℹ 3 more variables: location <chr>, target_sample <dbl>, actual_sample <dbl>
```

## Creating Survey Designs

The survey-first approach uses the `survey` package directly. You create
a day-level survey design from your sampling calendar using
[`as_day_svydesign()`](../reference/as_day_svydesign.md).

``` r
# Create day-level survey design from calendar
svy_day <- as_day_svydesign(
  calendar,
  day_id = "date",
  strata_vars = c("day_type", "month")
)

# Examine the survey design
class(svy_day)
#> [1] "survey.design2" "survey.design"
summary(stats::weights(svy_day))
#>    Min. 1st Qu.  Median    Mean 3rd Qu.    Max. 
#>   1.027   1.027   1.064   1.052   1.064   1.064
```

## Interview-Level Survey Designs

For CPUE and catch estimation, you can create interview-level survey
designs directly with the `survey` package:

``` r
# Simple survey design from interviews (no stratification)
svy_interviews <- survey::svydesign(
  ids = ~1,
  weights = ~1,
  data = interviews
)

# Or with stratification if needed
# svy_interviews_strat <- survey::svydesign(
#   ids = ~1,
#   strata = ~location,
#   weights = ~1,
#   data = interviews
# )
```

## Replicate Variance (Optional)

You can convert day-level designs to replicate-weight designs for robust
standard errors:

``` r
# Bootstrap replicate design with 50 reps (keep small in examples)
svy_rep <- survey::as.svrepdesign(svy_day, type = "bootstrap", replicates = 50, mse = TRUE)
class(svy_rep)
#> [1] "svyrep.design"
```

## Estimating Effort (Survey-First)

Once you have a day-PSU design, estimate effort from counts using the
survey-first estimators.

``` r
# Example instantaneous counts (toy)
counts_inst <- tibble::tibble(
  date = as.Date(c("2024-01-01","2024-01-01","2024-01-02","2024-01-02")),
  location = c("A","B","A","B"),
  count = c(10,12,8,15),
  interval_minutes = 60,
  total_day_minutes = 600
)

est_effort(
  design = svy_day,
  counts = counts_inst,
  method = "instantaneous",
  by = c("location")
)
#> Warning: ! 2 group(s) have fewer than 3 observations
#> ℹ Variance estimates may be unstable for these groups
#> # A tibble: 2 × 9
#>   location estimate    se ci_low ci_high  deff     n method        variance_info
#>   <chr>       <dbl> <dbl>  <dbl>   <dbl> <dbl> <int> <chr>         <list>       
#> 1 A              90    10   70.4    110.    NA    NA instantaneous <named list> 
#> 2 B             135    15  106.     164.    NA    NA instantaneous <named list>
```

## Estimating CPUE and Catch (Survey-First)

CPUE is estimated design-based from interview data. Prefer the
ratio-of-means form for incomplete trips; use mean-of-ratios for
complete trips.

``` r
# CPUE/Catch use interview-level survey designs
# CPUE by species (ratio-of-means)
suppressWarnings({
  cpue_species <- est_cpue(svy_interviews, by = c("target_species"), response = "catch_total")
})
#> ✔ Auto: 100% complete trips (n=26). Using mean-of-ratios.
cpue_species
#> # A tibble: 4 × 10
#>   target_species estimate    se ci_low ci_high  deff     n method    diagnostics
#>   <chr>             <dbl> <dbl>  <dbl>   <dbl> <dbl> <int> <chr>     <list>     
#> 1 bass               1.16 0.110  0.941    1.37    NA    10 cpue_mea… <list [1]> 
#> 2 catfish            1    0      1        1       NA     4 cpue_mea… <list [1]> 
#> 3 panfish            1.83 0.425  1.00     2.67    NA     4 cpue_mea… <list [1]> 
#> 4 walleye            1.77 0.202  1.38     2.17    NA     8 cpue_mea… <list [1]> 
#> # ℹ 1 more variable: variance_info <list>

# CPUE (mean-of-ratios) — for complete trips
suppressWarnings({
  cpue_mor <- est_cpue(svy_interviews, by = c("target_species"), response = "catch_total", mode = "mean_of_ratios")
})
cpue_mor
#> # A tibble: 4 × 10
#>   target_species estimate    se ci_low ci_high  deff     n method    diagnostics
#>   <chr>             <dbl> <dbl>  <dbl>   <dbl> <dbl> <int> <chr>     <list>     
#> 1 bass               1.16 0.110  0.941    1.37    NA    10 cpue_mea… <list [1]> 
#> 2 catfish            1    0      1        1       NA     4 cpue_mea… <list [1]> 
#> 3 panfish            1.83 0.425  1.00     2.67    NA     4 cpue_mea… <list [1]> 
#> 4 walleye            1.77 0.202  1.38     2.17    NA     8 cpue_mea… <list [1]> 
#> # ℹ 1 more variable: variance_info <list>

# Harvest totals by species
suppressWarnings({
  harvest_species <- est_catch(svy_interviews, by = c("target_species"), response = "catch_kept")
})
harvest_species
#> # A tibble: 4 × 8
#>   target_species estimate    se ci_low ci_high     n method          diagnostics
#>   <chr>             <dbl> <dbl>  <dbl>   <dbl> <int> <chr>           <list>     
#> 1 bass                 22  6.4   9.46     34.5    10 catch_total:ca… <NULL>     
#> 2 catfish               6  2.99  0.133    11.9     4 catch_total:ca… <NULL>     
#> 3 panfish              10  5.6  -0.976    21.0     4 catch_total:ca… <NULL>     
#> 4 walleye              44 14.2  16.2      71.8     8 catch_total:ca… <NULL>
```

## Advanced Usage

### Custom Stratification

You can specify custom stratification variables when creating survey
designs:

``` r
## Diagnostics: check structure before design creation
str(calendar)
#> spc_tbl_ [18 × 11] (S3: spec_tbl_df/tbl_df/tbl/data.frame)
#>  $ date         : Date[1:18], format: "2024-01-01" "2024-01-01" ...
#>  $ stratum_id   : chr [1:18] "2024-01-01-weekday-morning" "2024-01-01-weekday-morning" "2024-01-01-weekday-afternoon" "2024-01-01-weekday-afternoon" ...
#>  $ day_type     : chr [1:18] "weekday" "weekday" "weekday" "weekday" ...
#>  $ season       : chr [1:18] "winter" "winter" "winter" "winter" ...
#>  $ month        : chr [1:18] "January" "January" "January" "January" ...
#>  $ weekend      : logi [1:18] FALSE FALSE FALSE FALSE FALSE FALSE ...
#>  $ holiday      : logi [1:18] FALSE FALSE FALSE FALSE FALSE FALSE ...
#>  $ shift_block  : chr [1:18] "morning" "morning" "afternoon" "afternoon" ...
#>  $ location     : chr [1:18] "Lake_A" "Lake_B" "Lake_A" "Lake_B" ...
#>  $ target_sample: num [1:18] 10 10 10 10 5 5 10 10 10 10 ...
#>  $ actual_sample: num [1:18] 8 8 12 12 3 3 10 10 9 9 ...
#>  - attr(*, "spec")=
#>   .. cols(
#>   ..   date = col_date(format = ""),
#>   ..   stratum_id = col_character(),
#>   ..   day_type = col_character(),
#>   ..   season = col_character(),
#>   ..   month = col_character(),
#>   ..   weekend = col_logical(),
#>   ..   holiday = col_logical(),
#>   ..   shift_block = col_character(),
#>   ..   location = col_character(),
#>   ..   target_sample = col_double(),
#>   ..   actual_sample = col_double()
#>   .. )
#>  - attr(*, "problems")=<externalptr>
str(interviews)
#> spc_tbl_ [26 × 17] (S3: spec_tbl_df/tbl_df/tbl/data.frame)
#>  $ interview_id    : chr [1:26] "INT001" "INT001B" "INT002" "INT002B" ...
#>  $ date            : Date[1:26], format: "2024-01-01" "2024-01-01" ...
#>  $ time_start      : POSIXct[1:26], format: "2024-01-01 08:30:00" "2024-01-01 08:30:00" ...
#>  $ time_end        : POSIXct[1:26], format: "2024-01-01 08:45:00" "2024-01-01 08:45:00" ...
#>  $ location        : chr [1:26] "Lake_A" "Lake_B" "Lake_A" "Lake_B" ...
#>  $ mode            : chr [1:26] "boat" "boat" "bank" "bank" ...
#>  $ shift_block     : chr [1:26] "morning" "morning" "morning" "morning" ...
#>  $ day_type        : chr [1:26] "weekday" "weekday" "weekday" "weekday" ...
#>  $ party_size      : num [1:26] 2 2 1 1 3 3 2 2 1 1 ...
#>  $ hours_fished    : num [1:26] 4.5 4.5 3 3 6 6 2.5 2.5 1.5 1.5 ...
#>  $ target_species  : chr [1:26] "walleye" "walleye" "bass" "bass" ...
#>  $ catch_total     : num [1:26] 5 5 2 2 8 8 3 3 4 4 ...
#>  $ catch_kept      : num [1:26] 3 3 1 1 5 5 2 2 4 4 ...
#>  $ catch_released  : num [1:26] 2 2 1 1 3 3 1 1 0 0 ...
#>  $ weight_total    : num [1:26] 2.5 2.5 1.2 1.2 4.1 4.1 1.8 1.8 0.8 0.8 ...
#>  $ trip_complete   : logi [1:26] TRUE TRUE TRUE TRUE TRUE TRUE ...
#>  $ effort_expansion: num [1:26] 1 1 1 1 1 1 1 1 1 1 ...
#>  - attr(*, "spec")=
#>   .. cols(
#>   ..   interview_id = col_character(),
#>   ..   date = col_date(format = ""),
#>   ..   time_start = col_datetime(format = ""),
#>   ..   time_end = col_datetime(format = ""),
#>   ..   location = col_character(),
#>   ..   mode = col_character(),
#>   ..   shift_block = col_character(),
#>   ..   day_type = col_character(),
#>   ..   party_size = col_double(),
#>   ..   hours_fished = col_double(),
#>   ..   target_species = col_character(),
#>   ..   catch_total = col_double(),
#>   ..   catch_kept = col_double(),
#>   ..   catch_released = col_double(),
#>   ..   weight_total = col_double(),
#>   ..   trip_complete = col_logical(),
#>   ..   effort_expansion = col_double()
#>   .. )
#>  - attr(*, "problems")=<externalptr>

# Create day-level design with simpler stratification
svy_day_simple <- as_day_svydesign(
  calendar,
  day_id = "date",
  strata_vars = c("day_type")  # Single stratification variable
)

# Check stratification
summary(svy_day_simple)
#> Stratified 1 - level Cluster Sampling design (with replacement)
#> With (3) clusters.
#> survey::svydesign(ids = ids_formula, strata = strata_formula, 
#>     weights = ~.w, data = cal, nest = TRUE, lonely.psu = "adjust")
#> Probabilities:
#>    Min. 1st Qu.  Median    Mean 3rd Qu.    Max. 
#>  0.9400  0.9400  0.9400  0.9512  0.9737  0.9737 
#> Stratum Sizes: 
#>            weekday weekend
#> obs             12       6
#> design.PSU       2       1
#> actual.PSU       2       1
#> Data variables:
#>  [1] "date"          "stratum_id"    "day_type"      "season"       
#>  [5] "month"         "weekend"       "holiday"       "shift_block"  
#>  [9] "location"      "target_sample" "actual_sample" ".target"      
#> [13] ".actual"       ".w"
table(calendar$day_type)
#> 
#> weekday weekend 
#>      12       6
```

### Handling Missing Data

The validation functions will catch missing required columns:

``` r
# This will produce an error due to missing columns
tryCatch({
  bad_calendar <- calendar[, -1]  # Remove first column
  as_day_svydesign(bad_calendar, day_id = "date", strata_vars = c("day_type"))
}, error = function(e) {
  message("Validation error: ", e$message)
})
#> Validation error: Missing required columns in as_day_svydesign.
```

## Next Steps

Now that you have survey designs from the `survey` package, you can:

1.  **Estimate effort** from counts using day-level designs
    ([`est_effort()`](../reference/est_effort.md))
2.  **Estimate CPUE and catch** from interviews using interview-level
    designs ([`est_cpue()`](../reference/est_cpue.md),
    [`est_catch()`](../reference/est_catch.md))
3.  **Use replicate designs** for robust variance estimation
4.  **Perform hypothesis tests** comparing different groups or time
    periods
5.  **Generate reports** with confidence intervals and uncertainty
    bounds

See the package vignettes for more advanced features: -
`vignette("effort-survey-first")` for detailed effort estimation -
[`vignette("aerial")`](../articles/aerial.md) for aerial survey
methods - `vignette("cpue-catch")` for CPUE and catch estimation (coming
soon)

## References

- Pollock, K. H., Jones, C. M., & Brown, T. L. (1994). *Angler survey
  methods and their applications in fisheries management*. American
  Fisheries Society.
- Malvestuto, S. P. (1996). *Sampling the recreational creel*. In
  Murphy, B. R. & Willis, D. W. (Eds.), *Fisheries techniques* (2nd ed.,
  pp. 591-623). American Fisheries Society.
