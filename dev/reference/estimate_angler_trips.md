# Estimate angler trips from extrapolated effort

Computes estimated trips by dividing extrapolated effort by the mean
trip length per stratum, with Delta Method variance propagation (Powell
2007). This is a composable estimator: the effort object must be
pre-computed via
[`estimate_effort`](https://chrischizinski.com/tidycreel/dev/reference/estimate_effort.md)
before calling this function.

The divisor is hours per trip, so the result comes back in whichever
actor the effort was measured in: angler-hours give angler trips,
party-hours give party trips. The returned `unit` field records which,
and is `NA` when the effort's own unit was unknown. The method string is
`"angler-trips"` in every case and so is not a guide to the actor.

## Usage

``` r
estimate_angler_trips(effort, design, conf_level = 0.95, ...)
```

## Arguments

- effort:

  A `creel_estimates` object returned by
  [`estimate_effort`](https://chrischizinski.com/tidycreel/dev/reference/estimate_effort.md).
  Must have a numeric `estimate` column and a `se` column in
  `effort$estimates`.

- design:

  A `creel_design` object with interview data containing a trip duration
  column (set via `add_interviews(trip_duration = ...)`). Used to
  compute per-stratum mean trip length.

- conf_level:

  Confidence level for confidence intervals. Default 0.95.

- ...:

  Reserved for future arguments.

## Value

A `creel_estimates` object with `method = "angler-trips"` and
`variance_method = "delta"`. The `estimates` tibble contains:

- by_vars columns:

  Any grouping columns from the effort object (if grouped).

- estimate:

  Estimated trips per stratum (effort / mean trip length), in the actor
  the effort was measured in.

- se:

  Standard error via Delta Method variance propagation.

- ci_lower:

  Lower confidence interval bound.

- ci_upper:

  Upper confidence interval bound.

- n:

  Number of interviews contributing to mean trip length per stratum.

For grouped effort, an `.overall` row is appended with
`estimate = sum(stratum trips)`. Its `se` adds the stratum variances in
quadrature when the effort rows are independent (ground counts). Aerial
effort rows share the visibility correction and angler-to-people ratio,
and GLMM rows also share model coefficients, so for those the covariance
of the effort rows is used and each shared term enters the total once.

Grouping columns that are not character (numeric, factor, `Date`) are
returned as character, so the `.overall` marker can share them.

## Trip length

Trips are effort divided by mean trip length (Pollock et al. 1994, p.
175). That divisor has to be the mean length of *completed* trips,
sampled without regard to how long they were, so:

- Only complete trips (`trip_status == "complete"`) enter it. An
  incomplete trip records the time fished so far, not a trip length.

- Roving designs (`interview_type = "roving"`) are refused. A roving
  clerk meets anglers in proportion to how long they fish
  (length-of-stay bias; Pollock et al. 1994, sec. 11.4; Robson 1961),
  and the time fished at interview cannot be inverted into a trip count
  (Hoenig et al. 1997). Pollock et al. (1994, p. 175): "an unbiased
  estimate of mean trip length cannot be obtained from a roving survey
  ... and must be achieved by other means."

- Angler-hours are divided by hours per angler trip: every angler in a
  party of \\n\\ makes one trip, so each trip length is weighted by its
  party size. Party-hours are divided by hours per party trip,
  unweighted. When the effort's unit is unknown and party sizes vary,
  the two divisors differ and nothing says which applies, so the call is
  refused; give
  [`add_counts()`](https://chrischizinski.com/tidycreel/dev/reference/add_counts.md)
  a period length to make the effort angler-hours.

- Bus-route and ice interviews are weighted by their inclusion weights
  (`.expansion / .pi_i`; Jones and Pollock 2012), as their effort is.

On a design with more than one stratum, `effort` must be grouped by
every stratum column, and the total across strata is the `.overall` row:
\\\sum_h \hat{E}\_h / \hat{L}\_h\\, built stratum by stratum as Pollock
et al. (1994, sec. 15.3.3.6) build season catch. One trip length pooled
across strata weights each stratum by its share of the *interviewed*
trips, not of all trips. Sampling weekends more heavily than weekdays,
or taking a fixed number of interviews per day however busy it is, then
biases the total. On a simulated season it was off by -16% and +8% (GH
\#691). Ungrouped effort carries no per-stratum effort to weight by, so
it is refused.

The mean is a ratio estimator on the interview survey design, so
interviews on the same day are not treated as independent, and the
confidence interval uses that design's degrees of freedom (days less
strata) rather than the number of interviews.

## References

Hoenig, J. M., Jones, C. M., Pollock, K. H., Robson, D. S., and Wade, D.
L. (1997). Calculation of catch rate and total catch in roving surveys
of anglers. *Biometrics*, 53(1), 306-317.

Jones, C. M., and Pollock, K. H. (2012). Recreational angler survey
methods: estimation of effort, harvest, and released catch. In A. V.
Zale, D. L. Parrish, and T. M. Sutton (eds.), *Fisheries Techniques*
(3rd ed., pp. 883-919). American Fisheries Society.

Pollock, K. H., Jones, C. M., and Brown, T. L. (1994). *Angler Survey
Methods and Their Applications in Fisheries Management*. American
Fisheries Society Special Publication 25. Chapters 11 and 15.

Powell, L. A. (2007). Approximating variance of demographic parameters
using the delta method. *Journal of Wildlife Management*, 71(3),
1018-1024.

Robson, D. S. (1961). On the statistical theory of a roving creel census
of fishermen. *Biometrics*, 17(3), 415-437.

## See also

[`estimate_effort`](https://chrischizinski.com/tidycreel/dev/reference/estimate_effort.md),
[`estimate_exploitation_rate`](https://chrischizinski.com/tidycreel/dev/reference/estimate_exploitation_rate.md)

## Examples

``` r
data(example_calendar)
data(example_counts)
data(example_interviews)
design <- creel_design(example_calendar, date = date, strata = day_type)
design <- add_counts(design, example_counts)
design <- add_interviews(design, example_interviews,
  catch = catch_total, effort = hours_fished, harvest = catch_kept,
  trip_status = trip_status, trip_duration = trip_duration
)
#> Warning: ! No `n_anglers` provided — assuming 1 angler per interview.
#> ℹ Pass `n_anglers = <column>` to use actual party sizes for angler-hour
#>   normalization.
#> ℹ If the interviews really are one angler each, pass `n_anglers = 1` to state
#>   that and silence this warning.
#> ℹ Added 22 interviews: 17 complete (77%), 5 incomplete (23%)
# Effort by stratum: the `.overall` row is the total across strata.
effort <- estimate_effort(design, by = day_type)
#> Warning: Instantaneous counts were expanded without a period length.
#> ℹ No `period_length_col` was supplied to `add_counts()`, so the estimate is the
#>   count column summed over days.
#> ! If that column holds an instantaneous angler count, the result is the anglers
#>   present at the counted moments, not angler-hours: a count becomes effort only
#>   when multiplied by its period length. The package cannot tell which unit the
#>   column is in.
#> ℹ Supply the period each count was randomised within: `add_counts(design,
#>   counts, period_length_col = <col>)`.
#> ℹ Repeats on this design are recorded, not printed: see `get_warnings()`.
estimate_angler_trips(effort, design)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: angler-trips
#> Variance: delta
#> Confidence level: 95%
#> Grouped by: day_type
#> Effort target: period_total
#> 
#> # A tibble: 3 × 6
#>   day_type estimate    se ci_lower ci_upper     n
#>   <chr>       <dbl> <dbl>    <dbl>    <dbl> <int>
#> 1 weekday      129.  15.6     94.5     163.    10
#> 2 weekend      186.  20.1    142.      230.     7
#> 3 .overall     315.  25.4    259.      371.    17
```
