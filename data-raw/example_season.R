## Script to create the example_season_* datasets
##
## NOT REPRODUCIBLE AS WRITTEN since GH #646 changed simulate_creel_data():
## counts are now the anglers present at random moments of the simulated
## trips, so this script no longer recreates the committed .rda files. They
## are regenerated in the follow-up to #646.
## One simulated 120-day season (May 1 - August 28, 2024) with weekday/weekend
## strata, 36 sampled days, one instantaneous count per sampled day, and
## interviews. Used by the Getting Started vignette to show a complete season:
## design -> counts -> effort -> interviews -> rates -> totals.
##
## Generated with simulate_creel_data() (catch accruing over hours fished,
## GH #494) and a fixed seed:
## - An access run gives the calendar, the counts and the complete-trip
##   interviews: every finishing party has the same chance of being met.
## - A roving run with the SAME seed gives the incomplete-trip interviews.
##   The seed draws the sampled days before anything else, so both runs share
##   one calendar (checked below). Its catch is the catch so far. The tutorial
##   shows add_interviews() finding these trips and setting them aside.
## - catch_rate 0.22 fish per angler-hour, the rate example_roving_interviews
##   was simulated with, so the two example sets share one true rate.
## Seed 2056 (the first from 2031 up): no sampled day has a zero count, so the
## tutorial runs without the zero-count advisory (checked below).
## true_trip_length is simulation truth no clerk observes; it is dropped, as
## is trip_duration (equal to hours_fished here).

devtools::load_all()

params <- list(
  effort = list(gamma_shape = 2.0, gamma_rate = 0.8),
  party = list(mean = 1.5),
  catch_rate = list(mean = 0.22, nb_size = 0.5),
  harvest = list(mean_pct = 35),
  counts = list(mean_total_anglers = 10)
)

simulate_season <- function(interview_type) {
  simulate_creel_data(
    params,
    season_days = 120,
    n_sampled_days = 36,
    day_types = c(weekday = 5 / 7, weekend = 2 / 7),
    interview_type = interview_type,
    start_date = as.Date("2024-05-01"),
    daylight_hours = 14,
    n_counts_per_day = 1,
    seed = 2056
  )
}
access <- simulate_season("access")
roving <- simulate_season("roving")
stopifnot(identical(access$schedule, roving$schedule))

example_season_calendar <- access$schedule[, c("date", "day_type", "sampled")]

example_season_counts <- access$counts[, c("date", "day_type", "total_anglers", "daylight_hours")]
example_season_counts$total_anglers <- as.integer(example_season_counts$total_anglers)

interviews <- rbind(access$interviews, roving$interviews)
interviews <- interviews[order(interviews$date, interviews$trip_status, interviews$interview_id), ]
example_season_interviews <- data.frame(
  date = interviews$date,
  day_type = interviews$day_type,
  interview_id = seq_len(nrow(interviews)),
  trip_status = interviews$trip_status,
  hours_fished = round(interviews$hours_fished, 2),
  n_anglers = as.integer(interviews$n_anglers),
  catch_total = as.integer(interviews$catch_total),
  catch_kept = as.integer(interviews$catch_kept),
  stringsAsFactors = FALSE
)
rownames(example_season_calendar) <- NULL
rownames(example_season_counts) <- NULL

stopifnot(
  nrow(example_season_calendar) == 120,
  sum(example_season_calendar$sampled) == 36,
  all(example_season_counts$total_anglers > 0),
  all(example_season_interviews$catch_kept <= example_season_interviews$catch_total),
  all(example_season_interviews$hours_fished > 0),
  all(example_season_interviews$date %in% example_season_counts$date)
)

usethis::use_data(example_season_calendar, overwrite = TRUE)
usethis::use_data(example_season_counts, overwrite = TRUE)
usethis::use_data(example_season_interviews, overwrite = TRUE)
