# Simulate a complete creel survey dataset

Generates realistic synthetic creel data using a three-level
hierarchical generative model (day → trip → catch). Caller supplies
distributional parameters via `params`; no default data are bundled with
the package.

The generative model follows Su & Clapp (2013) and Greene (1995):

1.  **Day level**: Sample `n_sampled_days` days from the season. Each
    sampled day draws the number of angler trips arriving from a
    Negative Binomial distribution.

2.  **Trip level**: Each trip draws effort (hr) from a Gamma
    distribution, party size from a zero-truncated Poisson, and trip
    completion from a Bernoulli draw.

3.  **Catch level**: Each complete or incomplete trip draws total catch
    from a Negative Binomial; harvest is Binomial given total catch.

4.  **Roving clerk**: Interview probability is proportional to trip
    length (length-biased sampling). Incomplete trips contribute elapsed
    effort, not total effort.

## Usage

``` r
simulate_creel_data(
  params,
  season_days = 100L,
  n_sampled_days = 30L,
  day_types = NULL,
  species = "walleye",
  species_weights = NULL,
  p_complete = 0.75,
  p_zero_catch = 0.4,
  n_anglers_per_day = NULL,
  start_date = Sys.Date(),
  n_counts_per_day = 3L,
  seed = NULL
)
```

## Arguments

- params:

  Named list of distributional parameters. Required. Must include named
  sub-lists: `effort` (with `gamma_shape`, `gamma_rate` for
  [`rgamma()`](https://rdrr.io/r/stats/GammaDist.html)); `party` (with
  `mean` party size for
  [`rpois()`](https://rdrr.io/r/stats/Poisson.html)); `catch_per_trip`
  (with `mean` and `nb_size` for
  [`rnbinom()`](https://rdrr.io/r/stats/NegBinomial.html)); `harvest`
  (with `mean_pct` as a percentage, e.g. `35` for 35%); `counts` (with
  `mean_total_anglers`, used when `n_anglers_per_day = NULL`).

- season_days:

  Integer. Total days in the season. Default 100.

- n_sampled_days:

  Integer. Number of days actually surveyed. Must be `<= season_days`.
  Default 30.

- day_types:

  Named numeric vector. Proportion of days per stratum, e.g.
  `c(weekday = 5/7, weekend = 2/7)`. When `NULL` (default), uses a
  single stratum `"all"`.

- species:

  Character vector. Species names for the catch table. Default
  `"walleye"`. Catch is split proportionally across species using
  `species_weights`.

- species_weights:

  Numeric vector. Relative catch weight per species. Must be same length
  as `species`. Default equal weights.

- p_complete:

  Numeric in (0, 1\]. Probability a trip is complete (intercepted at
  trip end). Default `0.75`.

- p_zero_catch:

  Numeric in \[0, 1). Probability a trip has zero total catch
  (zero-inflation). Default `0.40`. **Note:** this cannot be derived
  from the NGPC inventory (API artifact); the default is an empirical
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

- seed:

  Integer or `NULL`. Random seed for reproducibility. Default `NULL`.

## Value

A named list with three data frames:

- `interviews`:

  One row per intercepted angler party. Columns: `date`, `day_type`,
  `interview_id`, `trip_status` (`"complete"` or `"incomplete"`),
  `hours_fished`, `trip_duration` (total trip length; equals
  `hours_fished` for complete trips), `n_anglers`, `catch_total`,
  `catch_kept`, `species_sought`.

- `counts`:

  One row per instantaneous count. Columns: `date`, `day_type`,
  `total_anglers`.

- `catch`:

  Long-format catch table. Columns: `interview_id`, `species`, `count`,
  `catch_type` (`"caught"`, `"harvested"`, `"released"`).

The `interviews` and `counts` outputs can be passed directly to
[`add_interviews`](https://chrischizinski.github.io/tidycreel/reference/add_interviews.md)
and
[`add_counts`](https://chrischizinski.github.io/tidycreel/reference/add_counts.md)
after constructing a calendar with
[`creel_design`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md).

## References

Su, B.C. & Clapp, D.F. (2013). Simulation-based evaluation of creel
survey designs. N. Am. J. Fish. Manage. 33: 895–909.

Greene, B.T. (1995). The ANGLER simulation model. N. Am. J. Fish.
Manage. 15: 743–750.

Petrere, M. et al. (2010). Catch-per-unit-effort: which estimator is
best? Fish. Res. 106: 325–333.

## See also

[`simulate_creel_catch`](https://chrischizinski.github.io/tidycreel/reference/simulate_creel_catch.md)

Other "Simulation":
[`simulate_creel_catch()`](https://chrischizinski.github.io/tidycreel/reference/simulate_creel_catch.md)

## Examples

``` r
my_params <- list(
  effort         = list(gamma_shape = 2.0, gamma_rate = 0.8),
  party          = list(mean = 1.5),
  catch_per_trip = list(mean = 1.8, nb_size = 0.5),
  harvest        = list(mean_pct = 35),
  counts         = list(mean_total_anglers = 10)
)
set.seed(42)
sim <- simulate_creel_data(
  params         = my_params,
  season_days    = 90,
  n_sampled_days = 20,
  species        = c("walleye", "northern_pike"),
  species_weights = c(0.6, 0.4)
)
head(sim$interviews)
#>         date day_type interview_id trip_status hours_fished trip_duration
#> 1 2026-06-02      all            2    complete        2.637         2.637
#> 2 2026-06-02      all            1    complete        3.109         3.109
#> 3 2026-06-02      all            6    complete        3.794         3.794
#> 4 2026-06-02      all            3    complete        1.059         1.059
#> 5 2026-06-02      all            4  incomplete        1.584         2.870
#> 6 2026-06-02      all            5    complete        1.421         1.421
#>   n_anglers catch_total catch_kept species_sought
#> 1         2           0          0  northern_pike
#> 2         1           1          0        walleye
#> 3         1           0          0        walleye
#> 4         2           0          0        walleye
#> 5         1           0          0  northern_pike
#> 6         1           4          2  northern_pike
head(sim$counts)
#>         date day_type total_anglers
#> 1 2026-06-02      all             9
#> 2 2026-06-02      all             9
#> 3 2026-06-02      all             3
#> 4 2026-06-04      all             1
#> 5 2026-06-04      all            11
#> 6 2026-06-04      all            10
head(sim$catch)
#>   interview_id       species count catch_type
#> 1            1 northern_pike     1     caught
#> 2            1 northern_pike     0  harvested
#> 3            1 northern_pike     1   released
#> 4            5       walleye     2     caught
#> 5            5       walleye     1  harvested
#> 6            5       walleye     1   released
```
