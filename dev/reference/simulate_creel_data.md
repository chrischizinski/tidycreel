# Simulate a complete creel survey dataset

Generates realistic synthetic creel data using a five-level hierarchical
generative model (day → trip → count → interview → catch). Caller
supplies distributional parameters via `params`; no default data are
bundled with the package.

The generative model follows Su & Clapp (2013) for the day and trip
levels; the roving-clerk step follows Greene et al. (1995). Only the
sampling step is taken from the latter: its own simulated anglers are
deterministic – evenly spaced around the shoreline, all starting one
hour into an eight-hour day, with trip lengths alternating between 3 and
6 hours – whereas the levels below draw from distributions.

1.  **Day level**: Every day of the season draws the number of angler
    trips from a Negative Binomial distribution; `n_sampled_days` of
    them are sampled. Unsampled days are simulated too, so the season's
    true totals are known.

2.  **Trip level**: Each trip draws its length (hr) from a Gamma
    distribution, capped at the fishing day's length \\T\\, a start time
    uniform in \\\[0, T - L\]\\, and its party size from a Poisson (at
    least 1).

3.  **Count level**: On a sampled day, each count is taken at a
    uniformly random moment of the fishing day and is the number of
    anglers fishing then. Count times \\T\\ is unbiased for the day's
    angler-hours (Hoenig et al. 1993).

4.  **Interview level**, set by `interview_type`: `"access"` – the clerk
    meets parties as they leave, every party with the same chance (70\\
    trip; `"roving"` – the clerk meets parties while they fish, each
    with a chance proportional to its trip length (0.25 times its length
    over the day's mean length, capped at 1, so slightly under a quarter
    of the day's parties), at a uniformly random point in the trip, and
    records the time fished so far (at least 0.1 h). This is the
    sampling difference Pollock et al. (1997) base the choice of
    catch-rate estimator on.

5.  **Catch level**: Catch accrues over the time fished. A party catches
    nothing with probability `p_zero_catch`; otherwise its whole-trip
    catch is Negative Binomial with mean
    `catch_rate$mean * n_anglers * trip_length / (1 - p_zero_catch)`, so
    the population catch rate (total catch over total angler-hours) is
    exactly `catch_rate$mean`. Harvest is Binomial given catch. A roving
    interview's catch so far is the part of that trip's catch caught in
    the time fished so far (each fish with probability
    `hours_fished / trip_length`).

Because catch accrues, the ratio of means on access interviews and the
(truncated) mean of ratios on roving interviews both target
`truth$catch_rate`. Before tidycreel 9.0.0 each party drew one
whole-trip catch regardless of time fished, so an incomplete trip
carried the whole trip's catch over the hours fished so far and inflated
any roving catch rate (GH \#494).

Counts and interviews come from the same simulated trips, so the true
effort, catch and harvest are known (GH \#646): `truth` reports them
over the sampled days and over the season. Before tidycreel 9.0.0 the
counts were drawn independently of the trips and only the rates were
known.

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

  Numeric. Mean number of angler parties fishing on each day of the
  season (sampled or not). Overrides `params$counts$mean_total_anglers`
  when specified. Default `NULL` (use params).

- start_date:

  Date. First day of the simulated season. Default
  [`Sys.Date()`](https://rdrr.io/r/base/Sys.time.html).

- n_counts_per_day:

  Integer. Number of instantaneous count observations per sampled day.
  Default `3`.

- lat:

  Numeric latitude in decimal degrees, positive north. The daily fishing
  period \\T\\ is computed per date with
  [`day_length`](https://chrischizinski.com/tidycreel/dev/reference/day_length.md).
  Supply `lat` or `daylight_hours`, not both.

- daylight_hours:

  Numeric. Length of the daily fishing period \\T\\, in hours, used to
  convert instantaneous counts to angler-hours. Accepts a single value
  applied to every day, or a named length-12 vector of monthly values
  (names `"1"`…`"12"`, or `month.abb`) which is matched on the month of
  each count date. Use this when \\T\\ is set by regulation or field
  protocol rather than by daylight. Supply `daylight_hours` or `lat`,
  not both.

  One of them is required: trips start within the fishing day and counts
  are taken at moments in it, so the day needs a length, and there is no
  honest default (GH \#646).

- seed:

  Integer or `NULL`. Random seed for reproducibility. Default `NULL`.

## Value

A named list with four data frames and the true values:

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
  `count_time` (integer index 1…`n_counts_per_day`, in time order),
  `total_anglers` (anglers fishing at the moment of the count),
  `daylight_hours` (\\T\\ for that day) and `angler_hours`
  (`total_anglers * daylight_hours`). Pass `count_time_col = count_time`
  to
  [`add_counts`](https://chrischizinski.com/tidycreel/dev/reference/add_counts.md)
  when `n_counts_per_day > 1`.

- `catch`:

  Long-format catch table. Columns: `interview_id`, `species`, `count`,
  `catch_type` (`"caught"`, `"harvested"`, `"released"`). For each
  interview the rows of each type sum to its `catch_total`, `catch_kept`
  and `catch_total - catch_kept`.

- `truth`:

  A list of the population values estimators should recover:
  `catch_rate` and `harvest_rate` (per angler-hour), and the realised
  `effort_*` (angler-hours), `catch_*` and `harvest_*` (fish) of every
  simulated trip, each over the `_sampled_days` and over the `_season`;
  and `days`, one row per season day with its `parties`, `anglers`,
  `effort`, `catch` and `harvest`.

The population of trips is simulated before anything about the survey,
so a seed fixes the population: runs that differ only in
`interview_type`, `n_sampled_days` or `n_counts_per_day` sample the same
trips and report the same season truth.

**Pass `angler_hours`, not `total_anglers`, to
[`add_counts`](https://chrischizinski.com/tidycreel/dev/reference/add_counts.md).**
An instantaneous count estimates the mean number of anglers present, not
effort; effort is that count multiplied by the length of the period the
count was randomised within (Hoenig et al. 1993).
[`estimate_effort()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_effort.md)
expands whatever numeric column it is given and cannot tell the two
apart, so handing it `total_anglers` yields a sum of head counts
silently mislabelled as angler-hours. The counts table carries three
numeric columns and
[`add_counts`](https://chrischizinski.com/tidycreel/dev/reference/add_counts.md)
will not guess between them: name the one you mean with
`add_counts(design, sim$counts, count_col = angler_hours)`, or pass
`count_col = total_anglers, period_length_col = daylight_hours`.

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
  species_weights = c(0.6, 0.4),
  daylight_hours = 12
)
head(sim$schedule)
#>         date day_type sampled
#> 1 2026-11-21      all    TRUE
#> 2 2026-11-22      all    TRUE
#> 3 2026-11-23      all   FALSE
#> 4 2026-11-24      all   FALSE
#> 5 2026-11-25      all   FALSE
#> 6 2026-11-26      all   FALSE
head(sim$interviews)
#>         date day_type interview_id trip_status hours_fished trip_duration
#> 1 2026-11-21      all            3    complete        0.565         0.565
#> 2 2026-11-21      all            6    complete        1.716         1.716
#> 3 2026-11-21      all            7    complete        1.004         1.004
#> 4 2026-11-21      all           10    complete        6.238         6.238
#> 5 2026-11-21      all            1    complete        0.581         0.581
#> 6 2026-11-21      all            5    complete        0.352         0.352
#>   true_trip_length n_anglers catch_total catch_kept species_sought
#> 1            0.565         2           2          0  northern_pike
#> 2            1.716         2           8          1        walleye
#> 3            1.004         3           1          0  northern_pike
#> 4            6.238         1           1          1        walleye
#> 5            0.581         3           0          0        walleye
#> 6            0.352         2           0          0        walleye
head(sim$counts)
#>         date day_type count_time total_anglers daylight_hours angler_hours
#> 1 2026-11-21      all          1             1             12           12
#> 2 2026-11-21      all          2            10             12          120
#> 3 2026-11-21      all          3             0             12            0
#> 4 2026-11-22      all          1             4             12           48
#> 5 2026-11-22      all          2             4             12           48
#> 6 2026-11-22      all          3             0             12            0
head(sim$catch)
#>   interview_id species count catch_type
#> 1            3 walleye     2     caught
#> 2            3 walleye     0  harvested
#> 3            3 walleye     2   released
#> 4            6 walleye     6     caught
#> 5            6 walleye     1  harvested
#> 6            6 walleye     5   released
sim$truth$catch_rate
#> [1] 0.25
sim$truth$effort_season
#> [1] 3886.976

# Multi-stratum simulation with day_types (named numeric vector).
# `lat` derives the daily fishing period from day_length(), so T, and with
# it sim2$counts$daylight_hours, follows the season.
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
#> ℹ 47 interviews have zero catch.
#>   Zero catch is usual; check it is not missing data recorded as 0.
#> ℹ Added 67 interviews: 0 complete (0%), 67 incomplete (100%)
```
