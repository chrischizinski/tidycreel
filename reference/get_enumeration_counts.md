# Get enumeration counts from a bus-route creel design with interviews

Returns the enumeration count data (observed and interviewed angler
counts, and the expansion factor) for each interview record in a
bus-route `creel_design` with interviews attached via
[`add_interviews`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md).

The expansion factor \\n\\counted / n\\interviewed\\ accounts for
anglers present at a site who were not interviewed. It is used during
bus-route effort and harvest estimation (Jones & Pollock (2012) Eq. 19.4
and 19.5).

## Usage

``` r
get_enumeration_counts(design)
```

## Arguments

- design:

  A `creel_design` object with `design_type = "bus_route"` and interview
  data attached via
  [`add_interviews`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md).

## Value

A data frame with the site identifier column, the circuit identifier
column, `n_counted` (resolved column name), `n_interviewed` (resolved
column name), and `.expansion` (n_counted / n_interviewed, NA when
n_interviewed = 0).

## References

Jones, C. M., & Pollock, K. H. (2012). Recreational survey methods:
estimating effort, harvest, and abundance. In A. V. Zale, D. L. Parrish,
& T. M. Sutton (Eds.), *Fisheries Techniques* (3rd ed., pp. 883–919).
American Fisheries Society. Enumeration expansion factor used in Eq.
19.4 and 19.5 for bus-route effort and harvest estimation.

## See also

[`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md),
[`add_interviews()`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md),
[`get_sampling_frame()`](https://chrischizinski.github.io/tidycreel/reference/get_sampling_frame.md),
[`get_inclusion_probs()`](https://chrischizinski.github.io/tidycreel/reference/get_inclusion_probs.md)

Other "Bus-Route Helpers":
[`get_inclusion_probs()`](https://chrischizinski.github.io/tidycreel/reference/get_inclusion_probs.md),
[`get_sampling_frame()`](https://chrischizinski.github.io/tidycreel/reference/get_sampling_frame.md),
[`get_site_contributions()`](https://chrischizinski.github.io/tidycreel/reference/get_site_contributions.md)

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
design2 <- add_interviews(
  design_br, interviews,
  catch = catch_total, effort = hours_fished,
  trip_status = trip_status, trip_duration = trip_duration,
  n_counted = n_counted, n_interviewed = n_interviewed
)
#> ℹ No `n_anglers` provided — assuming 1 angler per interview.
#> ℹ Pass `n_anglers = <column>` to use actual party sizes for angler-hour
#>   normalization.
#> Warning: 1 stratum has fewer than 3 interviews:
#> • Stratum weekday: 2 interviews
#> ! Sparse strata produce unstable variance estimates.
#> ℹ Consider combining sparse strata or collecting more data.
#> ℹ Added 2 interviews: 2 complete (100%), 0 incomplete (0%)
get_enumeration_counts(design2)
#>   site circuit n_counted n_interviewed .expansion
#> 1    A      am         5             3   1.666667
#> 2    B      am         4             2   2.000000
```
