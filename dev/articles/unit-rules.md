# Where Units Come From

Every estimate tidycreel returns carries a `unit`. This page explains
where that unit comes from, why it is sometimes `NA`, and what happens
when a rate and an effort are in different units.

The rule is short: **a unit is derived, never declared.** tidycreel
states a unit only where it did the arithmetic that produces it.
Everywhere else the unit is `NA`, meaning unknown.

    count side:     count x period length (add_counts, period_length_col)  -> angler-hours
                    anything else                                           -> NA
    interview side: trip hours x party size (add_interviews, n_anglers)    -> angler-hours
                    trip hours alone                                        -> party-hours
    rate:           fish / (interview-side unit)
    total:          rate x effort -> fish, only when the two units cancel; otherwise NA

``` r

library(tidycreel)
```

## Why there is no default unit

A count column arrives as a column of numbers. It may hold instantaneous
head counts (how many anglers were present at one moment) or effort the
caller has already expanded to the day. The two look identical.
`example_counts`, used in several examples, is the second kind: its
`effort_hours` column is daily effort, not a head count.

If tidycreel assumed one of them, it would print a confident unit on a
number that may be in the other. A wrong label is worse than none,
because nothing downstream would question it. So the package asserts a
unit only where it can see why the unit is true.

## The count side

An instantaneous count becomes effort when it is multiplied by the
length of the period it was randomised within, $`T_d`$ (the fishing day,
or the shift). A count of 12 anglers on a 14-hour day is
$`12 \times 14 = 168`$ angler-hours.
[`add_counts()`](https://chrischizinski.com/tidycreel/dev/reference/add_counts.md)
does that multiplication when it is given `period_length_col`, and only
then does the design record its effort as angler-hours.

`example_season_counts` holds one instantaneous count per sampled day
and the day’s length:

``` r

head(example_season_counts, 3)
#>         date day_type total_anglers daylight_hours
#> 1 2024-05-06  weekday             5             14
#> 2 2024-05-07  weekday             5             14
#> 3 2024-05-09  weekday             9             14
```

``` r

design <- creel_design(example_season_calendar, date = date, strata = day_type)
with_td <- add_counts(design, example_season_counts,
  period_length_col = daylight_hours
)
estimate_effort(with_td)
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Total
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Effort target: sampled_days
#> Unit: angler-hours
#> 
#> # A tibble: 1 × 7
#>   estimate    se se_between se_within ci_lower ci_upper     n
#>      <dbl> <dbl>      <dbl>     <dbl>    <dbl>    <dbl> <int>
#> 1     3066  386.       386.         0    2282.    3850.    36
```

The effort is in angler-hours because the package multiplied each count
by its `daylight_hours`.

Leave the period length out, and the same counts are summed as they
stand:

``` r

without_td <- add_counts(design, example_season_counts,
  count_col = total_anglers
)
effort_no_td <- estimate_effort(without_td)
#> Warning: Instantaneous counts were expanded without a period length.
#> ℹ No `period_length_col` was supplied to `add_counts()`, so the estimate is the
#>   count column summed over days.
#> ! If that column holds an instantaneous angler count, the result is in
#>   angler-days, not angler-hours.
#> ℹ Supply the period each count was randomised within: `add_counts(design,
#>   counts, period_length_col = <col>)`.
#> ℹ Repeats on this design are recorded, not printed: see `get_warnings()`.
effort_no_td
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
#> 1      219  27.6       27.6         0     163.     275.    36
effort_no_td$unit
#> [1] NA
```

The printout has no `Unit:` line, because the unit is `NA`, and the
estimate is 219 rather than 3,066. Every day in these data is 14 hours
long, so the two differ by exactly that factor. The warning says what
happened: the counts were expanded without a period length. The package
does not know whether `total_anglers` was a head count (in which case
the answer is missing its $`T_d`$) or effort already expanded (in which
case 219 is right in some unit it cannot see). It reports the number and
leaves the unit unknown.

Two other routes:

- **Daily effort from
  [`prep_counts_daily_effort()`](https://chrischizinski.com/tidycreel/dev/reference/prep_counts_daily_effort.md).**
  That helper hands
  [`add_counts()`](https://chrischizinski.com/tidycreel/dev/reference/add_counts.md)
  effort the caller has already worked out for each day. There is no
  instantaneous count left to expand, so the period-length warning does
  not fire, but the unit is still `NA`: the caller chose the input
  column, and the package did not see the multiplication that made it.
- **Aerial designs.**
  [`creel_design()`](https://chrischizinski.com/tidycreel/dev/reference/creel_design.md)
  requires `h_open` for an aerial survey, and
  [`estimate_effort()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_effort.md)
  multiplies the count by it, so aerial effort from
  [`estimate_effort()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_effort.md)
  is angler-hours.
  [`estimate_effort_aerial_glmm()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_effort_aerial_glmm.md)
  still reports an unknown unit; that is a known defect, open as issue
  \#492.

## The interview side

A rate’s denominator is the effort in the interviews. An interview
records how long a party fished. That is party-hours. To make it
angler-hours,
[`add_interviews()`](https://chrischizinski.com/tidycreel/dev/reference/add_interviews.md)
multiplies trip hours by party size, which it does when it is given
`n_anglers`.

``` r

with_party <- add_interviews(with_td, example_season_interviews,
  catch = catch_total, effort = hours_fished, harvest = catch_kept,
  trip_status = trip_status, n_anglers = n_anglers
)
#> ℹ 153 interviews have zero catch.
#>   Zero catch is usual; check it is not missing data recorded as 0.
#> ℹ Added 231 interviews: 172 complete (74%), 59 incomplete (26%)
estimate_catch_rate(with_party)
#> ℹ Using complete trips for CPUE estimation
#>   (n=172, 74.5% of 231 interviews) [default]
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
#> 1    0.221 0.0415    0.139    0.302   172
```

Without `n_anglers`, the same interviews give a rate per party-hour, and
[`add_interviews()`](https://chrischizinski.com/tidycreel/dev/reference/add_interviews.md)
warns that it has no party size:

``` r

without_party <- add_interviews(with_td, example_season_interviews,
  catch = catch_total, effort = hours_fished, harvest = catch_kept,
  trip_status = trip_status
)
#> Warning: ! No `n_anglers` provided — assuming 1 angler per interview.
#> ℹ Pass `n_anglers = <column>` to use actual party sizes for angler-hour
#>   normalization.
#> ℹ If the interviews really are one angler each, pass `n_anglers = 1` to state
#>   that and silence this warning.
#> ℹ 153 interviews have zero catch.
#>   Zero catch is usual; check it is not missing data recorded as 0.
#> ℹ Added 231 interviews: 172 complete (74%), 59 incomplete (26%)
estimate_catch_rate(without_party)
#> ℹ Using complete trips for CPUE estimation
#>   (n=172, 74.5% of 231 interviews) [default]
#> 
#> ── Creel Survey Estimates ──────────────────────────────────────────────────────
#> Method: Ratio-of-Means CPUE
#> Variance: Taylor linearization
#> Confidence level: 95%
#> Unit: fish/party-hour
#> 
#> # A tibble: 1 × 5
#>   estimate     se ci_lower ci_upper     n
#>      <dbl>  <dbl>    <dbl>    <dbl> <int>
#> 1    0.372 0.0652    0.244    0.500   172
```

The two rates are not interchangeable. The party-hour rate is the
angler-hour rate times the effort-weighted mean party size of the
complete trips, 1.69 in these data.

Bus-route and ice estimators build effort from the interviews themselves
(a sum of each trip’s effort over its inclusion probability), so their
effort unit also comes from this side: party-hours without `n_anglers`.
Pope et al. (Chapter 17, unpublished draft) define the bus-route effort
estimate the same way, as “estimated total party-hours of effort”.

## How units combine

A total is a rate times an effort. Its unit is the product of their
units:

``` math
\frac{\text{fish}}{\text{angler-hour}} \times \text{angler-hours} = \text{fish}
```

That cancels only when the rate’s denominator is the effort’s unit.
tidycreel composes the unit from its two inputs rather than writing
`"fish"` on every total, so any other combination comes out `NA`:

| Effort unit  | Rate unit        | Total unit |
|--------------|------------------|------------|
| angler-hours | fish/angler-hour | fish       |
| party-hours  | fish/party-hour  | fish       |
| angler-hours | fish/party-hour  | `NA`       |
| `NA`         | fish/angler-hour | `NA`       |
| `NA`         | fish/party-hour  | `NA`       |

The first two are catches. The second is the bus-route or ice case
without `n_anglers`: effort and rate both come from the interviews, both
in party-hours, and the party-hours cancel. Here is the first:

``` r

estimate_total_catch(with_party)
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
#> 1     674.  152.     374.     973.   172
```

With the rate per party-hour, the product warns and has no unit:

``` r

total_party <- estimate_total_catch(without_party)
#> Warning in estimate_total_catch(without_party): Rate and effort may be in different units.
#> ✖ `n_anglers` was not supplied, so the rate is per party-hour while
#>   count-derived effort is per angler.
#> ℹ The product is correct only if every party is one angler. Pass
#>   `add_interviews(n_anglers = <col>)` to normalise.
total_party
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
#> 1    1134.  245.     650.    1618.   172
total_party$unit
#> [1] NA
```

The total is 1,134 instead of 674. Multiplying a rate per party-hour by
angler-hours inflates the catch by about the mean party size, which is
the error the `NA` and the warning exist to stop. The 1.68 ratio is
close to the rate ratio of 1.69 but not equal to it, because the total
is built stratum by stratum.

The same derivation runs wherever a unit is built from another:

- **Trips** are effort divided by mean trip length, so they inherit the
  effort’s actor: angler-hours give angler-trips, party-hours give
  party-trips, and an unknown effort unit gives an unknown trip unit.
- **Effort per acre**
  ([`estimate_effort_per_acre()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_effort_per_acre.md))
  appends “/acre” to whatever the effort’s unit is, so an unknown unit
  stays unknown.

## What to do with an `NA` unit

An `NA` unit is not an error. The number is still the estimate of
*something*; the package cannot say what. To get a unit:

- give
  [`add_counts()`](https://chrischizinski.com/tidycreel/dev/reference/add_counts.md)
  the period each count was randomised within, with `period_length_col`;
- give
  [`add_interviews()`](https://chrischizinski.com/tidycreel/dev/reference/add_interviews.md)
  the party size, with `n_anglers`.

If your count column already holds angler-hours, the number is right and
only the label is missing. The package has no way to be told that, on
purpose: a typed unit would be exactly as trustworthy as an axis label,
a second place to write the wrong thing.

## References

- Pope, K. L., et al. Creel surveys. Chapter 17 (unpublished draft).
