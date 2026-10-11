## Script to create the example_season_* datasets
## One simulated 120-day season (May 1 - August 28, 2024) with weekday/weekend
## strata, 36 sampled days, one instantaneous count per sampled day and access
## interviews. Used by the Getting Started vignette to show a complete season:
## design -> counts -> effort -> interviews -> rates -> totals.
##
## Generated once with simulate_creel_data() and a fixed seed. Seed 2031 was
## chosen because no sampled day has a zero count, so the tutorial runs
## without the zero-count advisory. simulate_creel_data() draws day_type at
## random from the stratum proportions and uses it only as a label, so it is
## replaced here with the real day of the week: a reader checking a date
## against a calendar should find a weekend on a Saturday or Sunday.

devtools::load_all()

params <- list(
  effort = list(gamma_shape = 2.0, gamma_rate = 0.8),
  party = list(mean = 1.5),
  catch_per_trip = list(mean = 1.8, nb_size = 0.5),
  harvest = list(mean_pct = 35),
  counts = list(mean_total_anglers = 10)
)

set.seed(2031)
sim <- simulate_creel_data(
  params,
  season_days = 120,
  n_sampled_days = 36,
  day_types = c(weekday = 5 / 7, weekend = 2 / 7),
  start_date = as.Date("2024-05-01"),
  daylight_hours = 14,
  n_counts_per_day = 1
)

day_type_of <- function(date) {
  ifelse(format(date, "%u") %in% c("6", "7"), "weekend", "weekday")
}
sim$schedule$day_type <- day_type_of(sim$schedule$date)
sim$counts$day_type <- day_type_of(sim$counts$date)
sim$interviews$day_type <- day_type_of(sim$interviews$date)

example_season_calendar <- sim$schedule[, c("date", "day_type", "sampled")]

example_season_counts <- sim$counts[, c("date", "day_type", "total_anglers", "daylight_hours")]
example_season_counts$total_anglers <- as.integer(example_season_counts$total_anglers)

interviews <- sim$interviews
interviews <- interviews[order(interviews$date, interviews$interview_id), ]
example_season_interviews <- data.frame(
  date = interviews$date,
  day_type = interviews$day_type,
  interview_id = seq_len(nrow(interviews)),
  trip_status = interviews$trip_status,
  hours_fished = round(interviews$hours_fished, 2),
  trip_duration = round(interviews$trip_duration, 2),
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
  all(example_season_interviews$date %in% example_season_counts$date)
)

usethis::use_data(example_season_calendar, overwrite = TRUE)
usethis::use_data(example_season_counts, overwrite = TRUE)
usethis::use_data(example_season_interviews, overwrite = TRUE)
