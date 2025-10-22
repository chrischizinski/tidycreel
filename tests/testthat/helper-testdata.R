# Helper functions for test data generation
library(tibble)

create_test_interviews <- function() {
  tibble::tibble(
    interview_id = paste0("INT", sprintf("%03d", 1:20)),
    date = rep(as.Date("2024-01-01") + 0:3, each = 5),
    shift_block = rep(c("morning", "afternoon", "evening", "morning"), each = 5, length.out = 20),
    day_type = rep(c("weekday", "weekend"), length.out = 20),
    time_start = as.POSIXct("2024-01-01 08:00:00") + (1:20) * 3600,
    time_end = as.POSIXct("2024-01-01 08:15:00") + (1:20) * 3600,
    location = rep(c("Lake_A", "Lake_B"), 10),
    mode = rep(c("boat", "bank"), 10),
    party_size = sample(1:4, 20, replace = TRUE),
    hours_fished = runif(20, 1, 8),
    target_species = rep(c("walleye", "bass", "perch"), length.out = 20),
    catch_total = sample(0:10, 20, replace = TRUE),
    catch_kept = sample(0:8, 20, replace = TRUE),
    catch_released = catch_total - catch_kept,
    weight_total = runif(20, 0, 5),
    trip_complete = sample(c(TRUE, FALSE), 20, replace = TRUE),
    effort_expansion = rep(1.0, 20)
  )
}

create_test_counts <- function() {
  tibble::tibble(
    count_id = paste0("CNT", sprintf("%03d", 1:16)),
    date = rep(as.Date("2024-01-01") + 0:3, each = 4),
    shift_block = rep(c("morning", "afternoon", "evening", "morning"), each = 4, length.out = 16),
    day_type = rep(c("weekday", "weekend"), length.out = 16),
    time = as.POSIXct("2024-01-01 09:00:00") + (1:16) * 1800,
    location = rep(c("Lake_A", "Lake_B"), 8),
    mode = rep(c("boat", "bank"), 8),
    anglers_count = sample(5:25, 16, replace = TRUE),
    parties_count = sample(3:12, 16, replace = TRUE),
    weather_code = rep(c("clear", "cloudy", "rain"), length.out = 16),
    temperature = runif(16, 15, 25),
    wind_speed = runif(16, 0, 15),
    visibility = rep(c("good", "fair", "poor"), length.out = 16),
    count_duration = rep(15, 16)
  )
}

create_test_calendar <- function() {
  dates <- rep(as.Date("2024-01-01") + 0:3, each = 3)
  shift_blocks <- rep(c("morning", "afternoon", "evening"), 4)

  tibble::tibble(
    date = dates,
    stratum_id = paste0(format(dates, "%Y-%m-%d"), "-", shift_blocks),
    day_type = rep(c("weekday", "weekend"), length.out = 12),
    season = rep("winter", 12),
    month = format(dates, "%B"),
    weekend = (weekdays(dates) %in% c("Saturday", "Sunday")),
    holiday = rep(FALSE, 12),
    shift_block = shift_blocks,
    target_sample = rep(10L, 12),
    actual_sample = sample(8:12, 12, replace = TRUE)
  )
}
