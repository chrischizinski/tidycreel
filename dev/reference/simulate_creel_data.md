# Simulate a complete creel survey dataset

Generates realistic synthetic creel data using a four-level hierarchical
generative model (day → trip → interview → catch). Caller supplies
distributional parameters via `params`; no default data are bundled with
the package.

The generative model follows Su & Clapp (2013) for the day and trip
levels; the roving-clerk step follows Greene et al. (1995). Only the
sampling step is taken from the latter: its own simulated anglers are
deterministic – evenly spaced around the shoreline, all starting one
hour into an eight-hour day, with trip lengths alternating between 3 and
6 hours – whereas the levels below draw from distributions.

1.  **Day level**: Sample `n_sampled_days` days from the season. Each
    sampled day draws the number of angler trips arriving from a
    Negative Binomial distribution.

2.  **Trip level**: Each trip draws its length (hr) from a Gamma
    distribution and its party size from a Poisson (at least 1).

3.  **Interview level**, set by `interview_type`: `"access"` – the clerk
    meets parties as they leave, every party with the same chance (70\\
    trip; `"roving"` – the clerk meets parties while they fish, each
    with a chance proportional to its trip length (0.25 times its length
    over the day's mean length, capped at 1, so slightly under a quarter
    of the day's parties), at a uniformly random point in the trip, and
    records the time fished so far (at least 0.1 h). This is the
    sampling difference Pollock et al. (1997) base the choice of
    catch-rate estimator on.

4.  **Catch level**: Catch accrues over the time fished. A party catches
    nothing with probability `p_zero_catch`; otherwise its catch so far
    is Negative Binomial with mean
    `catch_rate$mean * n_anglers * hours_fished / (1 - p_zero_catch)`,
    so the population catch rate (total catch over total angler-hours)
    is exactly `catch_rate$mean`. Harvest is Binomial given catch.

Because catch accrues, the ratio of means on access interviews and the
(truncated) mean of ratios on roving interviews both target
`truth$catch_rate`. Before tidycreel 9.0.0 each party drew one
whole-trip catch regardless of time fished, so an incomplete trip
carried the whole trip's catch over the hours fished so far and inflated
any roving catch rate (GH \#494).

The instantaneous counts are drawn independently of the simulated trips,
so the function reports no true total effort or catch, only the true
rates.

## Usage

``` r
simulate_creel_data(
  params,
  season_days = 100L,
  n_sampled_days = 30L,
  day_types = NULL,
  species = "walleye",
  species_weights = NULL,
  interview_type = c("access", "roving"),
  p_complete = NULL,
  p_zero_catch = 0.4,
  n_anglers_per_day = NULL,
  start_date = Sys.Date(),
  n_counts_per_day = 3L,
  lat = NULL,
  daylight_hours = NULL,
  seed = NULL
)
```

## Arguments

- params:

  Named list of distributional parameters. Required. Must include named
  sub-lists: `effort` (with `gamma_shape`, `gamma_rate` for
  [`rgamma()`](https://rdrr.io/r/stats/GammaDist.html)); `party` (with
  `mean` party size for
  [`rpois()`](https://rdrr.io/r/stats/Poisson.html)); `catch_rate` (with
  `mean`, the catch per angler-hour, and `nb_size` for
  [`rnbinom()`](https://rdrr.io/r/stats/NegBinomial.html), default `0.5`
  when `NULL` or `NA`); `harvest` (with `mean_pct` as a percentage, e.g.
  `35` for 35%, default `35` when `NULL` or `NA`); `counts` (with
  `mean_total_anglers`, used when `n_anglers_per_day = NULL`).

- season_days:

  Integer. Total days in the season. Default 100.

- n_sampled_days:

  Integer. Number of days actually surveyed. Must be `<= season_days`.
  Default 30.

- day_types:

  Named **numeric** vector of stratum proportions, e.g.
  `c(weekday = 5/7, weekend = 2/7)`. Names become the `day_type` values
  in the output. When the names are exactly `weekday` and `weekend`,
  each day's label comes from its date (Saturday and Sunday are
  weekends) and the proportions are ignored; any other names are
  assigned to days at random in the stated proportions. When `NULL`
  (default), uses a single stratum `"all"`. **Note:** passing a
  character vector (e.g. `c("weekday", "weekend")`) will error — the
  vector must be numeric with named elements.

- species:

  Character vector. Species names for the catch table. Default
  `"walleye"`. Catch is split proportionally across species using
  `species_weights`.

- species_weights:

  Numeric vector. Relative catch weight per species. Must be same length
  as `species`. Default equal weights.

- interview_type:

  `"access"` (default) or `"roving"`: how the clerk meets parties, and
  so whether trips are complete or incomplete. See Details. Simulate
  twice for a survey that collects both.

- p_complete:

  Removed in tidycreel 9.0.0; supplying it is an error. `interview_type`
  now decides trip status. The old argument mixed complete and
  incomplete trips in one length-biased draw (GH \#494).

- p_zero_catch:

  Numeric in \[0, 1). Probability a trip has zero total catch
  (zero-inflation). Default `0.40`. **Note:** this cannot be derived
  from a survey inventory (API artifact); the default is an empirical
  estimate from the creel literature.

- n_anglers_per_day:

  Numeric. Mean number of angler parties arriving per sampled day.
  Overrides `params$counts$mean_total_anglers` when specified. Default
  `NULL` (use params).

- start_date:

  Date. First day of the simulated season. Default
  [`Sys.Date()`](https://rdrr.io/r/base/Sys.time.html).

- n_counts_per_day:

  Integer. Number of instantaneous count observations per sampled day.
  Default `3`.

- lat:

  Numeric latitude in decimal degrees, positive north. When given, the
  daily fishing period \\T\\ is computed per date with
  [`day_length`](https://chrischizinski.com/tidycreel/dev/reference/day_length.md)
  and the counts table gains `daylight_hours` and `angler_hours`
  columns. Default `NULL`. Mutually exclusive with `daylight_hours`.

- daylight_hours:

  Numeric. Length of the daily fishing period \\T\\, in hours, used to
  convert instantaneous counts to angler-hours. Accepts a single value
  applied to every day, or a named length-12 vector of monthly values
  (names `"1"`…`"12"`, or `month.abb`) which is matched on the month of
  each count date. Use this when \\T\\ is set by regulation or field
  protocol rather than by daylight. Default `NULL`. Mutually exclusive
  with `lat`.

  Supplying neither leaves `daylight_hours` and `angler_hours` off the
  counts table, rather than substituting a latitude the caller never
  gave.

- seed:

  Integer or `NULL`. Random seed for reproducibility. Default `NULL`.

## Value

A named list with four data frames and the true rates:

- `schedule`:

  Full-season calendar, one row per day. Columns: `date`, `day_type`,
  `sampled` (logical). Pass directly to
  [`creel_design`](https://chrischizinski.com/tidycreel/dev/reference/creel_design.md)
  as the `calendar` argument. Day types follow `day_types` as described
  there.

- `interviews`:

  One row per intercepted angler party. Columns: `date`, `day_type`,
  `interview_id`, `trip_status` (`"complete"` for access, `"incomplete"`
  for roving), `hours_fished` and `trip_duration` (both the time fished
  at the interview, as a clerk records it), `true_trip_length` (the
  whole simulated trip; simulation truth no clerk observes on a roving
  interview – do not pass it to
  [`add_interviews`](https://chrischizinski.com/tidycreel/dev/reference/add_interviews.md)),
  `n_anglers`, `catch_total` and `catch_kept` (both so far),
  `species_sought`.

- `counts`:

  One row per instantaneous count. Columns: `date`, `day_type`,
  `count_time` (integer index 1…`n_counts_per_day`) and `total_anglers`,
  plus `daylight_hours` (\\T\\ for that day) and `angler_hours`
  (`total_anglers * daylight_hours`) when `lat` or `daylight_hours` was
  supplied. Pass `count_time_col = count_time` to
  [`add_counts`](https://chrischizinski.com/tidycreel/dev/reference/add_counts.md)
  when `n_counts_per_day > 1`.

- `catch`:

  Long-format catch table. Columns: `interview_id`, `species`, `count`,
  `catch_type` (`"caught"`, `"harvested"`, `"released"`).

- `truth`:

  A list of the population values estimators should recover:
  `catch_rate` and `harvest_rate`, per angler-hour.

**Pass `angler_hours`, not `total_anglers`, to
[`add_counts`](https://chrischizinski.com/tidycreel/dev/reference/add_counts.md).**
An instantaneous count estimates the mean number of anglers present, not
effort; effort is that count multiplied by the length of the period the
count was randomised within (Hoenig et al. 1993).
[`estimate_effort()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_effort.md)
expands whatever numeric column it is given and cannot tell the two
apart, so handing it `total_anglers` yields a sum of head counts
silently mislabelled as angler-hours. When `lat` or `daylight_hours` is
supplied the counts table carries three numeric columns and
[`add_counts`](https://chrischizinski.com/tidycreel/dev/reference/add_counts.md)
will not guess between them: name the one you mean with
`add_counts(design, sim$counts, count_col = angler_hours)`.

When `n_counts_per_day > 1` you must also **drop the measures you are
not using** before attaching. `total_anglers` differs between the counts
taken within one day, so aggregation has no single value to carry
forward and would otherwise keep whichever came first.
[`add_counts()`](https://chrischizinski.com/tidycreel/dev/reference/add_counts.md)
aborts rather than do that (GH \#162); select the columns you need, as
the second example below does. `daylight_hours` is constant within a day
and can stay.

Note that
[`day_length`](https://chrischizinski.com/tidycreel/dev/reference/day_length.md)
gives astronomical daylight. Where the fishing day is fixed by
regulation or access hours instead, pass that period as
`daylight_hours`.

The `schedule` output can be passed directly to
[`creel_design`](https://chrischizinski.com/tidycreel/dev/reference/creel_design.md)
as the `calendar` argument. The `interviews` and `counts` outputs are
then passed to
[`add_interviews`](https://chrischizinski.com/tidycreel/dev/reference/add_interviews.md)
and
[`add_counts`](https://chrischizinski.com/tidycreel/dev/reference/add_counts.md).

## References

Su, Z. & Clapp, D.F. (2013). Evaluation of sample design and estimation
methods for Great Lakes angler surveys. Trans. Am. Fish. Soc. 142:
234–246.
[doi:10.1080/00028487.2012.728167](https://doi.org/10.1080/00028487.2012.728167)

Greene, C.J., Hoenig, J.M., Barrowman, N.J. & Pollock, K.H. (1995).
Programs to simulate catch rate estimation in a roving creel survey of
anglers. DFO Atlantic Fisheries Research Document 95/99. Department of
Fisheries and Oceans, St. John's, NL.

Pollock, K.H., Hoenig, J.M., Jones, C.M., Robson, D.S. & Greene, C.J.
(1997). Catch rate estimation for roving and access point surveys. N.
Am. J. Fish. Manage. 17: 11–19.
[doi:10.1577/1548-8675(1997)017\<0011:CREFRA\>2.3.CO;2](https://doi.org/10.1577/1548-8675%281997%29017%3C0011%3ACREFRA%3E2.3.CO%3B2)

Petrere, M. Jr., Giacomini, H.C. & De Marco, P. Jr. (2010).
Catch-per-unit-effort: which estimator is best? Braz. J. Biol. 70:
483–491.
[doi:10.1590/S1519-69842010005000010](https://doi.org/10.1590/S1519-69842010005000010)

## See also

[`simulate_creel_catch`](https://chrischizinski.com/tidycreel/dev/reference/simulate_creel_catch.md)

Other "Simulation":
[`day_length()`](https://chrischizinski.com/tidycreel/dev/reference/day_length.md),
[`simulate_creel_catch()`](https://chrischizinski.com/tidycreel/dev/reference/simulate_creel_catch.md)

## Examples

``` r
my_params <- list(
  effort         = list(gamma_shape = 2.0, gamma_rate = 0.8),
  party          = list(mean = 1.5),
  catch_rate     = list(mean = 0.25, nb_size = 0.5), # fish per angler-hour
  harvest        = list(mean_pct = 35),
  counts         = list(mean_total_anglers = 10)
)

# Basic simulation (single stratum)
set.seed(42)
sim <- simulate_creel_data(
  params         = my_params,
  season_days    = 90,
  n_sampled_days = 20,
  species        = c("walleye", "northern_pike"),
  species_weights = c(0.6, 0.4)
)
head(sim$schedule)
#>         date day_type sampled
#> 1 2026-11-15      all   FALSE
#> 2 2026-11-16      all   FALSE
#> 3 2026-11-17      all    TRUE
#> 4 2026-11-18      all   FALSE
#> 5 2026-11-19      all    TRUE
#> 6 2026-11-20      all   FALSE
head(sim$interviews)
#>         date day_type interview_id trip_status hours_fished trip_duration
#> 1 2026-11-17      all            8    complete        2.298         2.298
#> 2 2026-11-17      all            3    complete        4.957         4.957
#> 3 2026-11-17      all            1    complete        0.482         0.482
#> 4 2026-11-17      all            5    complete        3.516         3.516
#> 5 2026-11-17      all           10    complete        5.114         5.114
#> 6 2026-11-17      all            7    complete        0.620         0.620
#>   true_trip_length n_anglers catch_total catch_kept species_sought
#> 1            2.298         1           0          0        walleye
#> 2            4.957         2           0          0        walleye
#> 3            0.482         1           0          0        walleye
#> 4            3.516         1           0          0  northern_pike
#> 5            5.114         3           0          0        walleye
#> 6            0.620         2           0          0        walleye
head(sim$counts)
#>         date day_type count_time total_anglers
#> 1 2026-11-17      all          1             6
#> 2 2026-11-17      all          2             1
#> 3 2026-11-17      all          3             2
#> 4 2026-11-19      all          1             3
#> 5 2026-11-19      all          2             0
#> 6 2026-11-19      all          3            11
head(sim$catch)
#>   interview_id       species count catch_type
#> 1           22 northern_pike     1     caught
#> 2           22 northern_pike     1  harvested
#> 3           22 northern_pike     0   released
#> 4           12       walleye     1     caught
#> 5           12       walleye     0  harvested
#> 6           12       walleye     1   released
sim$truth$catch_rate
#> [1] 0.25

# Multi-stratum simulation with day_types (named numeric vector).
# `lat` derives the daily fishing period from day_length(), which adds the
# daylight_hours and angler_hours columns to sim2$counts.
set.seed(1)
sim2 <- simulate_creel_data(
  params         = my_params,
  season_days    = 90,
  n_sampled_days = 20,
  day_types      = c(weekday = 5/7, weekend = 2/7),
  interview_type = "roving",
  lat            = 40.699
)

# Round-trip: simulate → creel_design → add_counts → add_interviews
# total_anglers is dropped: it varies between the counts taken within a day,
# so aggregation cannot carry it forward (see the note above).
counts2 <- sim2$counts[, c("date", "day_type", "count_time", "angler_hours")]

design <- creel_design(sim2$schedule, date = date, strata = day_type) |>
  add_counts(
    counts2,
    count_col = angler_hours, # a head count alone is not effort
    count_time_col = count_time
  ) |>
  add_interviews(
    sim2$interviews,
    catch          = "catch_total",
    effort         = "hours_fished",
    harvest        = "catch_kept",
    trip_status    = "trip_status",
    trip_duration  = "trip_duration",
    n_anglers      = "n_anglers",
    interview_type = "roving"
  )
#> ℹ 54 interviews have zero catch.
#>   Zero catch is usual; check it is not missing data recorded as 0.
#> ℹ Added 70 interviews: 0 complete (0%), 70 incomplete (100%)
```
