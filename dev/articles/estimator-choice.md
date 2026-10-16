# How tidycreel Chooses an Estimator

[`estimate_effort()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_effort.md),
[`estimate_catch_rate()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_catch_rate.md)
and
[`estimate_total_catch()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_total_catch.md)
are each one function, but behind each is more than one estimator. This
page explains which one runs, what decides it, and how to see afterwards
which one was used.

Two things decide it, both fixed when the design is built:

    survey_type    (creel_design)    -> how effort is estimated, and how totals are built
    interview_type (add_interviews)  -> how the catch rate is estimated

Neither is chosen by looking at the data. The estimator follows from how
the data were collected, which the design records, so the same data
attached to the same design always get the same estimator.

``` r

library(tidycreel)
```

## The map

| `survey_type` | Effort | Catch rate | Total catch |
|----|----|----|----|
| `"instantaneous"` | counts × period length, summed over the sampled days, or expanded to every day of the stratum with `target` | by `interview_type` (below) | per stratum, effort × rate, summed over strata |
| `"aerial"` | counts × hours open × angler ratio ÷ visibility | by `interview_type` | per stratum, effort × rate, summed over strata |
| `"bus_route"` | Horvitz-Thompson: each interviewed trip’s effort over its inclusion probability | ratio of the Horvitz-Thompson catch and effort totals | Horvitz-Thompson catch total |
| `"ice"` | as bus route, with every site’s `p_site` = 1 | as bus route | as bus route |
| `"camera"` | not [`estimate_effort()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_effort.md): [`est_effort_camera()`](https://chrischizinski.com/tidycreel/dev/reference/est_effort_camera.md) calibrates counts against interview effort | by `interview_type` | refused |

Sectioned instantaneous designs
([`add_sections()`](https://chrischizinski.com/tidycreel/dev/reference/add_sections.md))
estimate each section separately and add a lake total.

Whether the effort covers only the days counted or every day in the
season is a separate choice, `target`, not a different estimator. The
default, `"sampled_days"`, is the effort on the days counted;
`"period_total"` expands each stratum to all its days. On the season
data used below, that is 3,066 angler-hours against about 9,994. Totals
follow the effort they are given, so a catch total on the default target
is the catch on the sampled days.
[`vignette("effort-pipeline")`](https://chrischizinski.com/tidycreel/dev/articles/effort-pipeline.md)
explains the expansion, and the expanded targets are not yet available
for bus-route, ice, aerial or sectioned designs.

The pages that explain each estimator in full:

- instantaneous-count effort and its two-stage variance:
  [`vignette("effort-pipeline")`](https://chrischizinski.com/tidycreel/dev/articles/effort-pipeline.md);
- rates and totals from interviews:
  [`vignette("catch-pipeline")`](https://chrischizinski.com/tidycreel/dev/articles/catch-pipeline.md);
- bus-route and ice:
  [`vignette("bus-route-surveys")`](https://chrischizinski.com/tidycreel/dev/articles/bus-route-surveys.md),
  [`vignette("ice-fishing")`](https://chrischizinski.com/tidycreel/dev/articles/ice-fishing.md),
  and the equations in
  [`vignette("bus-route-equations")`](https://chrischizinski.com/tidycreel/dev/articles/bus-route-equations.md);
- aerial:
  [`vignette("aerial-surveys")`](https://chrischizinski.com/tidycreel/dev/articles/aerial-surveys.md),
  and the model-based alternative,
  [`estimate_effort_aerial_glmm()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_effort_aerial_glmm.md),
  in
  [`vignette("aerial-glmm")`](https://chrischizinski.com/tidycreel/dev/articles/aerial-glmm.md);
- camera:
  [`vignette("camera-surveys")`](https://chrischizinski.com/tidycreel/dev/articles/camera-surveys.md).

## Effort follows the survey type

The survey type says what a count is, and so what turns it into effort.

- An **instantaneous count** is the number of anglers present at one
  moment. Multiplied by the length of the period it was taken in, it
  estimates that period’s effort. With an expanded `target`, the sampled
  days are then expanded to every day of the stratum.
- An **aerial count** is an instantaneous count from the air, covering
  the whole water. It becomes effort through the hours open, the ratio
  of anglers to people seen, and the share of anglers the observer can
  see.
- A **bus-route** survey does not count anglers at all. The clerk meets
  every trip that ends at a site while waiting there, and each trip is
  weighted by the probability that the schedule put the clerk at that
  site at that time (Jones and Pollock 2012, eq. 19.4). An **ice**
  survey is the same design with every site visited whenever its day is
  sampled (`p_site` = 1).
- A **camera count** is a daily total of arrivals, not a count of
  anglers present. Summing it over days gives arrivals, not effort.
  [`estimate_effort()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_effort.md)
  refuses a camera design for that reason and names
  [`est_effort_camera()`](https://chrischizinski.com/tidycreel/dev/reference/est_effort_camera.md),
  which converts counts to effort with a ratio taken from days that have
  both counts and interviews.

## The catch rate follows the interview type

An access interview meets a party as it leaves, so the trip is complete.
A roving interview meets a party while it is still fishing. The two
sample trips differently, and so they need different estimators (Pollock
et al. 1997):

- **Access:** the ratio of means, total catch over total effort, on
  complete trips. Every trip has the same chance of being met whatever
  its length, so this estimates total catch over total effort, the
  quantity a total needs.
- **Roving:** the mean of the individual catch rates, on all trips. A
  roving clerk meets a party in proportion to how long it fishes, and
  under that selection it is the mean of ratios that estimates total
  catch over total effort (Hoenig et al. 1997). That result is derived
  for individual anglers, and an interview is a party: meeting a party
  meets all its anglers. So each party’s rate per angler-hour counts
  once per angler in it (`n_anglers`). Without a party size the rate is
  per party-hour, and each party counts once. Trips shorter than half an
  hour are left out by default: their rates are mostly noise and inflate
  the variance.

Why each of these is right, and when, is the subject of
[`vignette("catch-pipeline")`](https://chrischizinski.com/tidycreel/dev/articles/catch-pipeline.md).

Bus-route and ice designs have their own rate: catch over effort, each a
Horvitz-Thompson total. `interview_type` does not change it.

## Totals follow from the two

A total is a rate times an effort, built stratum by stratum and summed,
with the standard error from Goodman’s (1960) exact variance of a
product. Bus-route and ice totals are different: the catch is weighted
by its inclusion probability directly (Jones and Pollock 2012, eq.
19.5), with no product.

Camera designs have no total. Their counts are arrivals, so a rate per
angler-hour times a camera count would not be a catch, and
[`estimate_total_catch()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_total_catch.md)
refuses rather than report one.

## Seeing which estimator ran

Every estimate records how it was made. `method` names the estimator
and, for rates and the totals built from them, `estimator` names the
rate estimator underneath. On the season data, with access and then
roving interviews:

``` r

design <- creel_design(example_season_calendar, date = date, strata = day_type)
design <- add_counts(design, example_season_counts,
  period_length_col = daylight_hours
)

access <- add_interviews(design, example_season_interviews,
  catch = catch_total, harvest = catch_kept, effort = hours_fished,
  trip_status = trip_status, n_anglers = n_anglers
)
#> ℹ 153 interviews have zero catch.
#>   Zero catch is usual; check it is not missing data recorded as 0.
#> ℹ Added 231 interviews: 172 complete (74%), 59 incomplete (26%)
roving <- add_interviews(design, example_roving_interviews,
  catch = catch_total, harvest = catch_kept, effort = hours_fished,
  trip_status = trip_status, trip_duration = hours_fished,
  n_anglers = n_anglers, interview_type = "roving"
)
#> ℹ 133 interviews have zero catch.
#>   Zero catch is usual; check it is not missing data recorded as 0.
#> ℹ Added 212 interviews: 0 complete (0%), 212 incomplete (100%)

access_rate <- estimate_catch_rate(access)
#> ℹ Using complete trips for CPUE estimation
#>   (n=172, 74.5% of 231 interviews) [default]
roving_rate <- estimate_catch_rate(roving)
#> ℹ Roving design: using all 212 interviews for CPUE via MOR [auto]
#>   (0 complete, 212 incomplete)
#>   Override with `use_trips = 'complete'` for access-point estimation.
#> Warning: ! MOR truncation: 29 trips excluded (13.7%)
#> ℹ Trips < 0.5 hours excluded to prevent unstable variance
#> ! High truncation rate may indicate data quality issues
#> ℹ Consider reviewing trip duration data for errors
#> ℹ Repeats on this design are recorded, not printed: see `get_warnings()`.

c(access = access_rate$method, roving = roving_rate$method)
#>                access                roving 
#> "ratio-of-means-cpue" "mean-of-ratios-cpue"
c(access = access_rate$estimator, roving = roving_rate$estimator)
#>           access           roving 
#> "ratio-of-means"            "mor"
```

The two messages say the same thing as it happens: complete trips for
the access design, and all trips by mean of ratios for the roving one,
marked `[auto]` because the interview type chose it. The roving rate
also warns that 29 trips under half an hour were left out. That is
expected here: a roving clerk meets many parties early in their trips,
and the warning fires whenever 10% or more are removed, so that a data
error that shortens trips is noticed.

## Overriding the choice

The defaults follow the design, but the rate estimator can be named:

- `estimator`: `"ratio-of-means"`, `"mor"` (mean of ratios), or
  `"mortr"` (mean of ratios with trips under `truncate_at` hours
  removed);
- `use_trips`: `"complete"` or `"all"`; the rate functions also take
  `"incomplete"`, and `"diagnostic"`, which estimates from complete and
  incomplete trips separately and compares them. A total accepts only
  `"complete"` and `"all"`;
- `truncate_at`: the shortest trip, in hours, a mean of ratios keeps.

Naming either `estimator` or `use_trips` turns off the roving default,
so the roving design then gets what was asked for. Some combinations are
refused because they are not an estimator: a ratio of means on
incomplete trips, which the length bias of incomplete trips makes wrong,
and a mean-of-ratios total on a bus-route or ice design, which has no
such form.

The variance method (`variance = "taylor"`, `"bootstrap"` or
`"jackknife"`) and the product variance of a total
(`product_variance = "goodman"` or `"first_order"`) are separate
choices. They change the standard error, not the estimator;
[`vignette("replicate-designs")`](https://chrischizinski.com/tidycreel/dev/articles/replicate-designs.md)
and
[`vignette("catch-pipeline")`](https://chrischizinski.com/tidycreel/dev/articles/catch-pipeline.md)
explain them.

## References

- Goodman, L. A. (1960). On the exact variance of products. *Journal of
  the American Statistical Association*, 55, 708–713.
- Hoenig, J. M., Jones, C. M., Pollock, K. H., Robson, D. S., and
  Wade, D. L. (1997). Calculation of catch rate and total catch in
  roving surveys of anglers. *Biometrics*, 53, 306–317.
- Jones, C. M., and Pollock, K. H. (2012). Recreational survey methods:
  estimation of effort, harvest, and abundance. Chapter 19 in *Fisheries
  Techniques* (3rd ed.), pp. 883–919. American Fisheries Society.
- Pollock, K. H., Hoenig, J. M., Jones, C. M., Robson, D. S., and
  Greene, C. J. (1997). Catch rate estimation for roving and access
  point surveys. *North American Journal of Fisheries Management*, 17,
  11–19.
