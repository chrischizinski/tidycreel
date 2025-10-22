# Generate Realistic Creel Survey Data for tidycreel Package
# Lake Clearwater Summer 2024 Survey
# Author: tidycreel development team
# Date: 2025-10-13

library(dplyr)
library(lubridate)

set.seed(20240601)  # Reproducible data

# Survey parameters
start_date <- as.Date("2024-06-01")
end_date <- as.Date("2024-07-31")
dates <- seq(start_date, end_date, by = "day")
locations <- c("North Ramp", "South Ramp", "East Pier")
shifts <- c("morning", "afternoon")

# Location-specific parameters
location_effort <- c("North Ramp" = 0.40, "South Ramp" = 0.35, "East Pier" = 0.25)
location_catch_rate <- c("North Ramp" = 1.5, "South Ramp" = 1.2, "East Pier" = 0.8)

# Species parameters
species_list <- c("Bass", "Walleye", "Panfish", "Catfish")
species_prob <- c(0.30, 0.25, 0.30, 0.15)
species_catch_rate <- c("Bass" = 1.2, "Walleye" = 0.8, "Panfish" = 2.0, "Catfish" = 0.6)

# =============================================================================
# 1. CALENDAR - Sampling design
# =============================================================================

calendar <- expand.grid(
  date = dates,
  location = locations,
  shift_block = shifts,
  stringsAsFactors = FALSE
) %>%
  mutate(
    day_type = ifelse(wday(date) %in% c(1, 7), "weekend", "weekday"),
    month = month(date, label = TRUE, abbr = TRUE),
    season = "summer",
    weekend = day_type == "weekend",
    # Target sampling: 40% of weekdays, 80% of weekends
    target_sample = ifelse(day_type == "weekend",
                          rbinom(n(), 1, 0.8),
                          rbinom(n(), 1, 0.4)),
    # Actual sampling: 90% success rate when targeted
    actual_sample = ifelse(target_sample == 1,
                          rbinom(n(), 1, 0.90),
                          0)
  ) %>%
  arrange(date, location, shift_block)

# Finalize calendar
calendar <- calendar %>%
  arrange(date, location, shift_block)

# =============================================================================
# 2. INTERVIEWS - Access point surveys
# =============================================================================

# Sample interviews from days with actual_sample = 1
sampled_days <- calendar %>%
  filter(actual_sample == 1)

# Generate interviews with realistic distributions
interviews <- sampled_days %>%
  # Number of interviews per shift: more on weekends, varies by location
  mutate(
    base_interviews = case_when(
      day_type == "weekend" ~ 6,
      TRUE ~ 3
    ),
    location_mult = case_when(
      location == "North Ramp" ~ 1.3,
      location == "South Ramp" ~ 1.0,
      location == "East Pier" ~ 0.7
    ),
    n_interviews = rpois(n(), base_interviews * location_mult)
  ) %>%
  # Expand to individual interviews
  slice(rep(1:n(), times = n_interviews)) %>%
  group_by(date, location, shift_block) %>%
  mutate(interview_id = paste0(date, "_", location, "_", shift_block, "_", row_number())) %>%
  ungroup() %>%
  # Add interview details
  mutate(
    # Time within shift
    time_start = case_when(
      shift_block == "morning" ~ as.POSIXct(paste(date, "06:00:00"), tz = "UTC") +
        runif(n(), 0, 4 * 3600),
      shift_block == "afternoon" ~ as.POSIXct(paste(date, "14:00:00"), tz = "UTC") +
        runif(n(), 0, 6 * 3600)
    ),
    # Trip duration (Gamma distribution, mean ~4 hours)
    hours_fished = pmax(1, rgamma(n(), shape = 4, scale = 1)),
    time_end = time_start + hours_fished * 3600,
    # Party size (1-4, weighted toward 2)
    party_size = sample(1:4, n(), replace = TRUE, prob = c(0.2, 0.5, 0.2, 0.1)),
    anglers = party_size
  ) %>%
  # Target species (varies by location) - do separately by location
  group_by(location) %>%
  mutate(
    target_species = case_when(
      location == "North Ramp" ~ sample(species_list, n(), replace = TRUE,
                                       prob = c(0.4, 0.3, 0.2, 0.1)),
      location == "South Ramp" ~ sample(species_list, n(), replace = TRUE,
                                        prob = c(0.3, 0.3, 0.3, 0.1)),
      location == "East Pier" ~ sample(species_list, n(), replace = TRUE,
                                       prob = c(0.1, 0.1, 0.5, 0.3))
    )
  ) %>%
  ungroup() %>%
  mutate(
    # Catch (Poisson with location and species effects)
    catch_rate = case_when(
      target_species == "Bass" ~ 1.2,
      target_species == "Walleye" ~ 0.8,
      target_species == "Panfish" ~ 2.0,
      target_species == "Catfish" ~ 0.6
    ) * location_catch_rate[location],
    catch_total = rpois(n(), catch_rate * hours_fished),
    # Harvest rate varies by species (catch-and-release for bass, higher for others)
    harvest_rate = case_when(
      target_species == "Bass" ~ 0.2,
      target_species == "Walleye" ~ 0.6,
      target_species == "Panfish" ~ 0.8,
      target_species == "Catfish" ~ 0.5
    ),
    catch_kept = rbinom(n(), catch_total, harvest_rate),
    catch_released = catch_total - catch_kept,
    # Interview metadata
    interview_complete = TRUE,
    trip_complete = runif(n()) < 0.85,  # 85% complete trips
    refused = FALSE
  ) %>%
  select(
    interview_id, date, location, shift_block, day_type, month,
    time_start, time_end, hours_fished,
    party_size, anglers, target_species,
    catch_total, catch_kept, catch_released,
    trip_complete, interview_complete, refused
  )

# =============================================================================
# 3. INSTANTANEOUS COUNTS - Snapshot observations
# =============================================================================

# Generate counts for sampled days (2-3 counts per day per location)
counts_instantaneous <- sampled_days %>%
  slice(rep(1:n(), times = sample(2:3, n(), replace = TRUE))) %>%
  group_by(date, location, shift_block) %>%
  mutate(
    count_id = paste0(date, "_", location, "_", shift_block, "_", row_number()),
    # Count time within shift
    time = case_when(
      shift_block == "morning" ~ as.POSIXct(paste(date, "07:00:00"), tz = "UTC") +
        (row_number() - 1) * 2 * 3600,  # Every 2 hours
      shift_block == "afternoon" ~ as.POSIXct(paste(date, "15:00:00"), tz = "UTC") +
        (row_number() - 1) * 2 * 3600
    ),
    # Angler counts (Poisson with location and day_type effects)
    base_count = case_when(
      day_type == "weekend" ~ 15,
      TRUE ~ 8
    ),
    location_mult = case_when(
      location == "North Ramp" ~ 1.4,
      location == "South Ramp" ~ 1.0,
      location == "East Pier" ~ 0.6
    ),
    count = rpois(n(), base_count * location_mult),
    # Count duration (how long the count took, in minutes)
    interval_minutes = sample(5:15, n(), replace = TRUE),
    # Total minutes in the shift that counts represent
    total_day_minutes = 240  # 4-hour shift blocks
  ) %>%
  ungroup() %>%
  select(count_id, date, location, shift_block, time, count,
         interval_minutes, total_day_minutes)

# =============================================================================
# 4. PROGRESSIVE COUNTS - Roving with passes
# =============================================================================

# Generate progressive counts (circuit patrols with multiple passes)
counts_progressive <- sampled_days %>%
  # 1-2 circuits per sampled shift
  slice(rep(1:n(), times = sample(1:2, n(), replace = TRUE))) %>%
  group_by(date, location, shift_block) %>%
  mutate(circuit_num = row_number()) %>%
  ungroup() %>%
  # Each circuit has 2-3 passes
  slice(rep(1:n(), times = sample(2:3, n(), replace = TRUE))) %>%
  group_by(date, location, shift_block, circuit_num) %>%
  mutate(
    pass_num = row_number(),
    count_id = paste0(date, "_", location, "_C", circuit_num, "_P", pass_num),
    pass_id = paste0("C", circuit_num, "P", pass_num),
    # Pass start time
    time = case_when(
      shift_block == "morning" ~ as.POSIXct(paste(date, "06:30:00"), tz = "UTC") +
        (circuit_num - 1) * 2 * 3600 + (pass_num - 1) * 45 * 60,
      shift_block == "afternoon" ~ as.POSIXct(paste(date, "14:30:00"), tz = "UTC") +
        (circuit_num - 1) * 2 * 3600 + (pass_num - 1) * 45 * 60
    ),
    # Route duration varies slightly
    route_minutes = 30 + rnorm(n(), 0, 5),
    route_minutes = pmax(20, route_minutes),  # At least 20 minutes
    # Angler counts along route
    base_count = case_when(
      day_type == "weekend" ~ 12,
      TRUE ~ 6
    ),
    location_mult = case_when(
      location == "North Ramp" ~ 1.3,
      location == "South Ramp" ~ 1.0,
      location == "East Pier" ~ 0.7
    ),
    count = rpois(n(), base_count * location_mult * 0.8)  # Slightly lower than instantaneous
  ) %>%
  ungroup() %>%
  select(count_id, date, location, shift_block, pass_id, time,
         count, route_minutes)

# =============================================================================
# Save datasets
# =============================================================================

write.csv(calendar, "inst/extdata/example_calendar.csv", row.names = FALSE)
write.csv(interviews, "inst/extdata/example_interviews.csv", row.names = FALSE)
write.csv(counts_instantaneous, "inst/extdata/example_counts_instantaneous.csv", row.names = FALSE)
write.csv(counts_progressive, "inst/extdata/example_counts_progressive.csv", row.names = FALSE)

# =============================================================================
# Print summary statistics
# =============================================================================

cat("=== Lake Clearwater Summer 2024 Creel Survey ===\n\n")
cat("Survey Period:", as.character(start_date), "to", as.character(end_date), "\n")
cat("Total Days:", length(dates), "\n\n")

cat("CALENDAR:\n")
cat("  Total shift×location combinations:", nrow(calendar), "\n")
cat("  Target samples:", sum(calendar$target_sample), "\n")
cat("  Actual samples:", sum(calendar$actual_sample), "\n")
cat("  Success rate:", round(sum(calendar$actual_sample) / sum(calendar$target_sample) * 100, 1), "%\n\n")

cat("INTERVIEWS:\n")
cat("  Total interviews:", nrow(interviews), "\n")
cat("  By location:\n")
print(table(interviews$location))
cat("  By day type:\n")
print(table(interviews$day_type))
cat("  Mean hours fished:", round(mean(interviews$hours_fished), 2), "\n")
cat("  Mean catch per interview:", round(mean(interviews$catch_total), 2), "\n\n")

cat("INSTANTANEOUS COUNTS:\n")
cat("  Total counts:", nrow(counts_instantaneous), "\n")
cat("  Mean anglers per count:", round(mean(counts_instantaneous$count), 2), "\n\n")

cat("PROGRESSIVE COUNTS:\n")
cat("  Total counts:", nrow(counts_progressive), "\n")
cat("  Unique circuits:", length(unique(paste(counts_progressive$date, counts_progressive$circuit_num))), "\n")
cat("  Mean anglers per pass:", round(mean(counts_progressive$count), 2), "\n\n")

cat("Data saved to inst/extdata/\n")
