## Code to prepare `roving_survey` example dataset
## This simulates a roving creel survey with incomplete trip interviews

library(tibble)

set.seed(20251025)

# Simulate 50 roving interviews
n_interviews <- 50

roving_survey <- tibble(
  interview_id = 1:n_interviews,

  # Grouping variables
  location = sample(c("River", "Lake"), n_interviews, replace = TRUE, prob = c(0.6, 0.4)),
  target_species = sample(c("Trout", "Bass"), n_interviews, replace = TRUE, prob = c(0.7, 0.3)),

  # Catch data (Poisson with mean depending on location)
  catch_total = rpois(n_interviews, lambda = ifelse(location == "River", 3, 5)),

  # Observed effort at interview (incomplete trips)
  # Truncated normal around 2-4 hours
  hours_fished = pmax(0.5, pmin(8, rnorm(n_interviews, mean = 3, sd = 1.5))),

  # Total planned effort (always >= observed)
  # Most anglers plan 4-6 hours total
  total_hours_planned = pmax(
    hours_fished + 0.5,  # At least 0.5 hours more than observed
    rnorm(n_interviews, mean = 5, sd = 1.5)
  )
)

# Round to realistic precision
roving_survey$hours_fished <- round(roving_survey$hours_fished, 1)
roving_survey$total_hours_planned <- round(roving_survey$total_hours_planned, 1)

# Add catch_kept (90% of total on average)
roving_survey$catch_kept <- pmax(0, roving_survey$catch_total - rbinom(n_interviews, roving_survey$catch_total, 0.1))

# Ensure total_hours_planned >= hours_fished (fix any rounding issues)
roving_survey$total_hours_planned <- pmax(
  roving_survey$total_hours_planned,
  roving_survey$hours_fished + 0.5
)

# Reorder columns
roving_survey <- roving_survey[, c(
  "interview_id", "location", "target_species",
  "catch_total", "catch_kept", "hours_fished", "total_hours_planned"
)]

# Save as .rda
usethis::use_data(roving_survey, overwrite = TRUE)
