# Generate Additional Realistic Creel Survey Data for tidycreel Package
# Aerial and Bus-Route Survey Methods
# Author: tidycreel development team
# Date: 2025-10-13

library(dplyr)
library(lubridate)

set.seed(20240601)

# Survey parameters (same period as access-point survey)
start_date <- as.Date("2024-06-01")
end_date <- as.Date("2024-07-31")
dates <- seq(start_date, end_date, by = "day")

# =============================================================================
# 1. AERIAL SURVEY DATA
# =============================================================================
# Lake Clearwater aerial boat counts, 2-3 flights per week

# Generate flight schedule (stratified: 2 weekday, 1 weekend per week)
flight_dates <- dates[wday(dates) %in% c(3, 5)]  # Tuesdays and Thursdays
weekend_flights <- dates[wday(dates) %in% c(1, 7)]  # Weekends
flight_dates <- c(
  sample(flight_dates, length(flight_dates) * 0.8),  # 80% of weekday flights
  sample(weekend_flights, length(weekend_flights) * 0.3)  # 30% of weekend flights
) %>% sort()

# Generate aerial counts
aerial_counts <- tibble(
  date = flight_dates
) %>%
  # Multiple flights per day (morning and afternoon)
  slice(rep(1:n(), times = sample(1:2, n(), replace = TRUE, prob = c(0.7, 0.3)))) %>%
  group_by(date) %>%
  mutate(
    flight_num = row_number(),
    flight_id = paste0("F", format(date, "%Y%m%d"), "_", flight_num)
  ) %>%
  ungroup() %>%
  mutate(
    # Flight timing
    time_of_day = ifelse(flight_num == 1, "morning", "afternoon"),
    flight_time = case_when(
      time_of_day == "morning" ~ as.POSIXct(paste(date, "09:00:00"), tz = "UTC") +
        runif(n(), -30*60, 30*60),
      time_of_day == "afternoon" ~ as.POSIXct(paste(date, "15:00:00"), tz = "UTC") +
        runif(n(), -30*60, 30*60)
    ),
    # Flight parameters
    altitude_feet = round(runif(n(), 300, 500), 0),
    speed_mph = round(runif(n(), 80, 100), 0),
    flight_minutes = round(runif(n(), 20, 35), 1),

    # Weather conditions affecting visibility
    cloud_cover = sample(c("clear", "partly_cloudy", "overcast"),
                        n(), replace = TRUE, prob = c(0.5, 0.3, 0.2)),
    glare = case_when(
      time_of_day == "morning" & cloud_cover == "clear" ~ "high",
      time_of_day == "afternoon" & cloud_cover == "clear" ~ "high",
      cloud_cover == "overcast" ~ "none",
      TRUE ~ "moderate"
    ),
    wind_mph = round(rnorm(n(), 10, 5)),
    wind_mph = pmax(0, wind_mph),

    # Observer characteristics
    observer = sample(c("Observer_A", "Observer_B", "Observer_C"),
                     n(), replace = TRUE, prob = c(0.5, 0.3, 0.2)),
    observer_experience = case_when(
      observer == "Observer_A" ~ "veteran",
      observer == "Observer_B" ~ "experienced",
      observer == "Observer_C" ~ "novice"
    ),

    # Visibility correction factor (0-1, higher = better detection)
    visibility_base = case_when(
      cloud_cover == "clear" ~ 0.85,
      cloud_cover == "partly_cloudy" ~ 0.75,
      cloud_cover == "overcast" ~ 0.70
    ),
    glare_penalty = case_when(
      glare == "high" ~ 0.85,
      glare == "moderate" ~ 0.95,
      glare == "none" ~ 1.0
    ),
    observer_skill = case_when(
      observer_experience == "veteran" ~ 1.0,
      observer_experience == "experienced" ~ 0.95,
      observer_experience == "novice" ~ 0.85
    ),
    visibility_correction = visibility_base * glare_penalty * observer_skill,

    # Calibration factor (from ground-truth studies)
    # Veteran observers closer to 1.0, novices need more correction
    calibration_factor = case_when(
      observer_experience == "veteran" ~ rnorm(n(), 1.15, 0.05),
      observer_experience == "experienced" ~ rnorm(n(), 1.20, 0.08),
      observer_experience == "novice" ~ rnorm(n(), 1.30, 0.10)
    ),
    calibration_factor = pmax(1.0, calibration_factor),  # At least 1.0

    # True boat counts (what's actually on water)
    day_type = ifelse(wday(date) %in% c(1, 7), "weekend", "weekday"),
    true_boats_base = case_when(
      day_type == "weekend" & time_of_day == "morning" ~ 45,
      day_type == "weekend" & time_of_day == "afternoon" ~ 35,
      day_type == "weekday" & time_of_day == "morning" ~ 25,
      day_type == "weekday" & time_of_day == "afternoon" ~ 20
    ),
    true_boats = rpois(n(), true_boats_base),

    # Observed boats (affected by visibility)
    boats_observed = rbinom(n(), true_boats, visibility_correction),

    # Anglers per boat (1-3, mean ~2)
    mean_anglers_per_boat = 2.0,
    total_anglers_observed = rpois(n(), boats_observed * mean_anglers_per_boat),

    # Metadata
    month = month(date, label = TRUE, abbr = TRUE),
    season = "summer"
  ) %>%
  select(
    flight_id, date, month, season, day_type, time_of_day,
    flight_time, flight_minutes, altitude_feet, speed_mph,
    cloud_cover, glare, wind_mph,
    observer, observer_experience,
    visibility_correction, calibration_factor,
    boats_observed, total_anglers_observed
  )

# =============================================================================
# 2. BUS-ROUTE SURVEY DATA
# =============================================================================
# Highway 41 fishing access points with unequal probability sampling

# Define 8 fishing stops along route
route_stops <- tibble(
  stop_id = paste0("Stop_", LETTERS[1:8]),
  stop_name = c(
    "Bridge Access North", "Dam Tailwater", "County Park",
    "Marina Cove", "Rocky Point", "Quiet Bay",
    "Highway Pulloff", "Creek Confluence"
  ),
  # Distance from main road (km) - affects access probability
  road_distance_km = c(0.1, 0.2, 0.5, 0.3, 1.0, 0.8, 0.0, 0.4),
  # Parking capacity (spaces) - affects probability
  parking_spaces = c(10, 15, 30, 20, 5, 8, 3, 12),
  # Historical use (popularity 0-1) - affects probability
  popularity = c(0.9, 0.95, 0.85, 0.80, 0.50, 0.60, 0.70, 0.75),
  # Stop time (minutes to count anglers)
  stop_minutes = c(3, 4, 5, 4, 2, 3, 2, 3),
  # Frame size: estimated total angler-hours available per day
  frame_size_weekday = c(40, 50, 80, 60, 25, 30, 20, 45),
  frame_size_weekend = c(80, 90, 150, 110, 45, 55, 35, 80)
) %>%
  mutate(
    # Calculate inclusion probability (0-1)
    # Higher for: close to road, more parking, more popular
    prob_base = (1 / (1 + road_distance_km)) *
                (parking_spaces / max(parking_spaces)) *
                popularity,
    inclusion_prob = prob_base / max(prob_base) * 0.8  # Scale to max 0.8
  )

# Generate bus-route surveys (3-4 times per week)
route_dates <- dates[wday(dates) %in% c(2, 4, 6)]  # Mon, Wed, Fri
route_dates <- sample(route_dates, length(route_dates) * 0.75)  # 75% of possible days

busroute_counts <- expand.grid(
  date = route_dates,
  stop_id = route_stops$stop_id,
  stringsAsFactors = FALSE
) %>%
  left_join(route_stops, by = "stop_id") %>%
  mutate(
    # Route timing (starts at 10am, visits stops sequentially)
    route_start_time = as.POSIXct(paste(date, "10:00:00"), tz = "UTC"),
    stop_sequence = as.numeric(factor(stop_id, levels = route_stops$stop_id)),
    # Cumulative travel + stop time
    cumulative_time = (stop_sequence - 1) * 8,  # ~8 min per stop (5 drive + 3 count)
    arrival_time = route_start_time + cumulative_time * 60,
    departure_time = arrival_time + stop_minutes * 60,

    # Day type
    day_type = ifelse(wday(date) %in% c(1, 7), "weekend", "weekday"),

    # Frame size for this day
    frame_size = ifelse(day_type == "weekend",
                       frame_size_weekend,
                       frame_size_weekday),

    # Whether this stop was actually visited (based on inclusion probability)
    visited = rbinom(n(), 1, inclusion_prob),

    # Angler counts (only if visited)
    # Poisson rate = frame_size / (total_minutes_in_day / stop_minutes)
    expected_anglers = frame_size / (480 / stop_minutes) * 0.7,  # 480 min = 8 hrs
    anglers_count = ifelse(visited == 1,
                          rpois(n(), expected_anglers),
                          NA_integer_),

    # Metadata
    count_id = paste0(format(date, "%Y%m%d"), "_", stop_id),
    month = month(date, label = TRUE, abbr = TRUE),
    season = "summer",

    # Survey metadata
    surveyor = "Route_Team_1",
    weather = sample(c("clear", "cloudy", "light_rain"),
                    n(), replace = TRUE, prob = c(0.7, 0.2, 0.1))
  ) %>%
  # Only keep visited stops
  filter(visited == 1) %>%
  select(
    count_id, date, month, season, day_type,
    stop_id, stop_name, stop_sequence,
    arrival_time, departure_time, stop_minutes,
    inclusion_prob, frame_size,
    anglers_count, weather, surveyor
  )

# =============================================================================
# 3. BUS-ROUTE SCHEDULE (for design construction)
# =============================================================================
# This is the frame with inclusion probabilities

busroute_schedule <- route_stops %>%
  select(
    stop_id, stop_name,
    road_distance_km, parking_spaces, popularity,
    stop_minutes, inclusion_prob,
    frame_size_weekday, frame_size_weekend
  ) %>%
  mutate(
    # Sampling weight = 1 / inclusion_prob
    sampling_weight = 1 / inclusion_prob,
    # Notes
    accessibility = case_when(
      road_distance_km < 0.3 ~ "easy",
      road_distance_km < 0.7 ~ "moderate",
      TRUE ~ "difficult"
    )
  )

# =============================================================================
# Save datasets
# =============================================================================

write.csv(aerial_counts, "inst/extdata/example_aerial_counts.csv", row.names = FALSE)
write.csv(busroute_counts, "inst/extdata/example_busroute_counts.csv", row.names = FALSE)
write.csv(busroute_schedule, "inst/extdata/example_busroute_schedule.csv", row.names = FALSE)

# =============================================================================
# Print summary statistics
# =============================================================================

cat("\n=== ADDITIONAL CREEL SURVEY METHODS ===\n\n")

cat("AERIAL SURVEY:\n")
cat("  Survey period:", as.character(start_date), "to", as.character(end_date), "\n")
cat("  Total flights:", nrow(aerial_counts), "\n")
cat("  Flight days:", length(unique(aerial_counts$date)), "\n")
cat("  Flights per week: ~", round(nrow(aerial_counts) / 8, 1), "\n")
cat("  Mean boats observed:", round(mean(aerial_counts$boats_observed), 1), "\n")
cat("  Mean anglers per flight:", round(mean(aerial_counts$total_anglers_observed), 1), "\n")
cat("  Mean visibility correction:", round(mean(aerial_counts$visibility_correction), 3), "\n\n")

cat("  By cloud cover:\n")
print(table(aerial_counts$cloud_cover))
cat("\n  By observer experience:\n")
print(table(aerial_counts$observer_experience))
cat("\n")

cat("BUS-ROUTE SURVEY:\n")
cat("  Survey period:", as.character(start_date), "to", as.character(end_date), "\n")
cat("  Route stops:", nrow(route_stops), "\n")
cat("  Survey days:", length(unique(busroute_counts$date)), "\n")
cat("  Total stop visits:", nrow(busroute_counts), "\n")
cat("  Mean stops per route:", round(nrow(busroute_counts) / length(unique(busroute_counts$date)), 1), "\n")
cat("  Mean anglers per stop:", round(mean(busroute_counts$anglers_count), 1), "\n")
cat("  Inclusion probability range:",
    round(min(route_stops$inclusion_prob), 3), "to",
    round(max(route_stops$inclusion_prob), 3), "\n\n")

cat("  Stop accessibility:\n")
print(table(busroute_schedule$accessibility))
cat("\n")

cat("BUS-ROUTE SCHEDULE:\n")
cat("  Frame file with", nrow(busroute_schedule), "stops\n")
cat("  Mean weekday frame size:", round(mean(busroute_schedule$frame_size_weekday)), "angler-hours\n")
cat("  Mean weekend frame size:", round(mean(busroute_schedule$frame_size_weekend)), "angler-hours\n\n")

cat("Data saved to inst/extdata/\n")
cat("  - example_aerial_counts.csv\n")
cat("  - example_busroute_counts.csv\n")
cat("  - example_busroute_schedule.csv\n")
