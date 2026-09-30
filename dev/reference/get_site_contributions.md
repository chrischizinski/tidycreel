# Extract per-site effort contributions from a bus-route estimate

Returns the per-site calculation table (\\e_i\\, \\\pi_i\\,
\\e_i/\pi_i\\) stored as an attribute on effort estimate objects
returned by
[`estimate_effort()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_effort.md)
for bus-route survey designs. This table enables traceability of the
Horvitz-Thompson estimator (Jones & Pollock 2012, Eq. 19.4) and supports
validation against published examples (Malvestuto 1996, Box 20.6).

## Usage

``` r
get_site_contributions(x)
```

## Arguments

- x:

  A creel_estimates object returned by
  [`estimate_effort()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_effort.md)
  for a bus-route design.

## Value

A tibble with columns:

- site:

  Site identifier (from sampling frame)

- circuit:

  Circuit identifier (from sampling frame)

- e_i:

  Enumeration-expanded effort at site i (effort \* expansion)

- pi_i:

  Inclusion probability for site i (p_site \* p_period)

- e_i_over_pi_i:

  Site contribution to Horvitz-Thompson estimate

## References

Jones, C. M., & Pollock, K. H. (2012). Recreational survey methods:
estimating effort, harvest, and abundance. In A. V. Zale, D. L. Parrish,
& T. M. Sutton (Eds.), *Fisheries Techniques* (3rd ed., pp. 883-919).
American Fisheries Society.

## See also

[`estimate_effort()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_effort.md),
[`get_sampling_frame()`](https://chrischizinski.com/tidycreel/dev/reference/get_sampling_frame.md),
[`get_inclusion_probs()`](https://chrischizinski.com/tidycreel/dev/reference/get_inclusion_probs.md),
[`get_enumeration_counts()`](https://chrischizinski.com/tidycreel/dev/reference/get_enumeration_counts.md)

Other "Bus-Route Helpers":
[`get_enumeration_counts()`](https://chrischizinski.com/tidycreel/dev/reference/get_enumeration_counts.md),
[`get_inclusion_probs()`](https://chrischizinski.com/tidycreel/dev/reference/get_inclusion_probs.md),
[`get_sampling_frame()`](https://chrischizinski.com/tidycreel/dev/reference/get_sampling_frame.md)

## Examples

``` r
cal <- data.frame(
  date = as.Date(c("2024-06-03", "2024-06-04", "2024-06-05", "2024-06-06")),
  day_type = "weekday"
)
sf <- data.frame(
  site = c("A", "B"),
  circuit = c("am", "am"),
  p_site = c(0.6, 0.4),
  p_period = rep(0.5, 2)
)
design_br <- creel_design(
  cal,
  date = date, strata = day_type,
  survey_type = "bus_route", sampling_frame = sf,
  site = site, circuit = circuit,
  p_site = p_site, p_period = p_period
)
interviews <- data.frame(
  date = as.Date(c("2024-06-03", "2024-06-04")),
  site = c("A", "B"), circuit = c("am", "am"),
  catch_total = c(3L, 2L), hours_fished = c(2.0, 1.5),
  trip_status = c("complete", "complete"),
  trip_duration = c(2.0, 1.5),
  n_counted = c(5L, 4L), n_interviewed = c(3L, 2L)
)
design_br <- add_interviews(
  design_br, interviews,
  catch = catch_total, effort = hours_fished,
  trip_status = trip_status, trip_duration = trip_duration,
  n_counted = n_counted, n_interviewed = n_interviewed
)
#> Warning: ! No `n_anglers` provided — assuming 1 angler per interview.
#> ℹ Pass `n_anglers = <column>` to use actual party sizes for angler-hour
#>   normalization.
#> ℹ If the interviews really are one angler each, pass `n_anglers = 1` to state
#>   that and silence this warning.
#> Warning: 1 stratum has fewer than 3 interviews:
#> • Stratum weekday: 2 interviews
#> ! Sparse strata produce unstable variance estimates.
#> ℹ Consider combining sparse strata or collecting more data.
#> ℹ Added 2 interviews: 2 complete (100%), 0 incomplete (0%)
result <- estimate_effort(design_br)
get_site_contributions(result)
#> # A tibble: 2 × 5
#>   site  circuit   e_i  pi_i e_i_over_pi_i
#>   <chr> <chr>   <dbl> <dbl>         <dbl>
#> 1 A     am       3.33   0.3          11.1
#> 2 B     am       3      0.2          15  
```
