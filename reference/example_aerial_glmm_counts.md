# Example multi-flight aerial count data for GLMM effort estimation

Simulated instantaneous angler counts from aerial overflights of a
Nebraska reservoir, designed to demonstrate GLMM-based effort estimation
following Askey (2018). Contains 48 rows: 12 survey days with 4
overflights per day at fixed hours (07:00, 10:00, 13:00, 16:00). Counts
follow a diurnal curve (low at dawn, peak mid-morning, lower in
afternoon) with day-level Poisson variability and a day random
intercept.

## Usage

``` r
example_aerial_glmm_counts
```

## Format

A data frame with 48 rows and 4 columns:

- date:

  Survey date (Date class), 12 days spaced 3 days apart starting
  2024-06-03.

- day_type:

  Day type stratum: `"weekday"` or `"weekend"`, derived from the
  calendar date.

- n_anglers:

  Instantaneous angler count from one aerial overflight (integer).
  Follows a diurnal curve with day-level random effects.

- time_of_flight:

  Hour of the aerial overflight (numeric). One of `7.0`, `10.0`, `13.0`,
  or `16.0`.

## Source

Simulated data following Askey (2018) NAJFM doi:10.1002/nafm.10010.

## References

Askey, P.J., et al. (2018). Correcting for non-random flight timing in
aerial creel surveys using a generalized linear mixed model. North
American Journal of Fisheries Management, 38, 1204-1215.
[doi:10.1002/nafm.10010](https://doi.org/10.1002/nafm.10010)

## See also

[example_aerial_counts](https://chrischizinski.github.io/tidycreel/reference/example_aerial_counts.md)
for the simple single-flight dataset,
[`estimate_effort_aerial_glmm()`](https://chrischizinski.github.io/tidycreel/reference/estimate_effort_aerial_glmm.md)
for the GLMM-based estimator,
[`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md),
[`add_counts()`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)

## Examples

``` r
data(example_aerial_glmm_counts)
head(example_aerial_glmm_counts)
#>         date day_type n_anglers time_of_flight
#> 1 2024-06-03  weekday         3              7
#> 2 2024-06-03  weekday        30             10
#> 3 2024-06-03  weekday        65             13
#> 4 2024-06-03  weekday        50             16
#> 5 2024-06-06  weekday         5              7
#> 6 2024-06-06  weekday        15             10

if (FALSE) { # \dontrun{
# Build an aerial design and estimate effort with GLMM correction
aerial_cal <- data.frame(
  date = unique(example_aerial_glmm_counts$date),
  day_type = unique(example_aerial_glmm_counts[, c("date", "day_type")])[["day_type"]],
  stringsAsFactors = FALSE
)
design <- creel_design(
  aerial_cal,
  date = date,
  strata = day_type,
  survey_type = "aerial",
  h_open = 14
)
design <- add_counts(design, example_aerial_glmm_counts)
result <- estimate_effort_aerial_glmm(design, time_col = time_of_flight)
print(result)
} # }
```
