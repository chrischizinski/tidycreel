## Script to create the example_roving_interviews dataset
## Roving interviews for the 36 sampled days of example_season_calendar, used
## by the instantaneous-count How-to vignette alongside example_season_counts.
##
## Written instead of using simulate_creel_data() because that function gives
## an incomplete trip the whole trip's catch over the hours fished so far
## (GH #494), which inflates any roving (mean-of-ratios) catch rate.
##
## How the data are generated:
## - A roving clerk meets parties while they fish, so a party's chance of
##   being met is proportional to its trip length. Trip lengths are drawn
##   length-biased: Gamma(shape 3, rate 0.8), the length-biased form of the
##   Gamma(shape 2, rate 0.8) trip lengths used for example_season.
## - The clerk meets a party at a uniformly random point in its trip, so the
##   hours fished so far are Uniform(0, trip length).
## - Field rule: the clerk does not interview a party that has fished for less
##   than 15 minutes; those parties are not recorded.
## - Catch accrues over time: catch so far is Poisson with mean
##   TRUE_RATE * n_anglers * hours fished so far. TRUE_RATE (0.22 fish per
##   angler-hour) is close to the access-interview rate the Getting Started
##   tutorial reports for example_season.
## - Every trip is incomplete: a roving clerk meets parties still fishing.
## - Harvest keeps each fish with probability 0.35.

devtools::load_all()

TRUE_RATE <- 0.22

set.seed(4801)
sampled <- example_season_calendar[example_season_calendar$sampled, ]

day_rows <- lapply(seq_len(nrow(sampled)), function(i) {
  n_met <- rpois(1, 6.5)
  if (n_met == 0) {
    return(NULL)
  }
  trip_length <- rgamma(n_met, shape = 3, rate = 0.8)
  so_far <- round(runif(n_met, 0, trip_length), 2)
  keep <- so_far >= 0.25
  n_kept <- sum(keep)
  if (n_kept == 0) {
    return(NULL)
  }
  so_far <- so_far[keep]
  n_anglers <- pmax(1L, rpois(n_kept, 1.5))
  catch_total <- rpois(n_kept, TRUE_RATE * n_anglers * so_far)
  data.frame(
    date = sampled$date[i],
    day_type = sampled$day_type[i],
    trip_status = "incomplete",
    hours_fished = so_far,
    n_anglers = n_anglers,
    catch_total = catch_total,
    catch_kept = rbinom(n_kept, catch_total, 0.35)
  )
})

example_roving_interviews <- do.call(rbind, day_rows)
example_roving_interviews <- data.frame(
  date = example_roving_interviews$date,
  day_type = example_roving_interviews$day_type,
  interview_id = seq_len(nrow(example_roving_interviews)),
  example_roving_interviews[, c(
    "trip_status", "hours_fished", "n_anglers", "catch_total", "catch_kept"
  )]
)

usethis::use_data(example_roving_interviews, overwrite = TRUE)
