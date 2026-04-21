# Get inclusion probabilities from a bus-route design

Returns the computed inclusion probabilities (\\\pi_i = p\_{\text{site}}
\times p\_{\text{period}}\\) for each site-circuit combination in a
bus-route creel design. The inclusion probability represents the
two-stage sampling probability: the probability that a particular site
is visited during a particular sampling period, combining both the site
selection probability within the circuit and the circuit (period)
selection probability.

## Usage

``` r
get_inclusion_probs(design)
```

## Arguments

- design:

  A
  [`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md)
  object created with `survey_type = "bus_route"`.

## Value

A data frame with three columns: the site identifier column, the circuit
identifier column, and `.pi_i` (the computed inclusion probability
\\\pi_i = p\_{\text{site}} \times p\_{\text{period}}\\ for each
site-circuit unit). Column names for site and circuit match the resolved
column names from the original sampling frame (or `.circuit` for designs
without an explicit circuit column).

## References

Jones, C. M., & Pollock, K. H. (2012). Recreational survey methods:
estimating effort, harvest, and abundance. In A. V. Zale, D. L. Parrish,
& T. M. Sutton (Eds.), *Fisheries Techniques* (3rd ed., pp. 883–919).
American Fisheries Society. Definition of \\\pi_i\\ for two-stage
bus-route sampling, used in Eq. 19.4 and 19.5.

## See also

[`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md),
[`get_sampling_frame()`](https://chrischizinski.github.io/tidycreel/reference/get_sampling_frame.md)

Other "Bus-Route Helpers":
[`get_enumeration_counts()`](https://chrischizinski.github.io/tidycreel/reference/get_enumeration_counts.md),
[`get_sampling_frame()`](https://chrischizinski.github.io/tidycreel/reference/get_sampling_frame.md),
[`get_site_contributions()`](https://chrischizinski.github.io/tidycreel/reference/get_site_contributions.md)

## Examples

``` r
sf <- data.frame(
  site = c("A", "B", "C"),
  p_site = c(0.3, 0.4, 0.3),
  p_period = rep(0.5, 3),
  stringsAsFactors = FALSE
)
cal <- data.frame(
  date = as.Date("2024-06-01"),
  day_type = "weekday",
  stringsAsFactors = FALSE
)
design <- creel_design(cal,
  date = date, strata = day_type,
  survey_type = "bus_route", sampling_frame = sf,
  site = site, p_site = p_site, p_period = p_period
)
get_inclusion_probs(design)
#>   site .circuit .pi_i
#> 1    A .default  0.15
#> 2    B .default  0.20
#> 3    C .default  0.15
```
