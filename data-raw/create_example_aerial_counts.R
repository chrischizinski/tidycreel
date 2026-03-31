# Create example_aerial_counts dataset
# Daily instantaneous angler counts from aerial overflights of a Nebraska reservoir
# 16 rows: one overflight per sampling day across an 8-week summer season (June-July 2024)
# Alternates weekday/weekend sampling based on actual calendar days

set.seed(47)

# Sampling dates: Mon/Wed/Fri weekdays plus Sat/Sun weekends
# June 3 - July 14, 2024
sampling_dates <- as.Date(c(
  "2024-06-03", # Mon
  "2024-06-05", # Wed
  "2024-06-07", # Fri
  "2024-06-08", # Sat
  "2024-06-09", # Sun
  "2024-06-10", # Mon
  "2024-06-12", # Wed
  "2024-06-14", # Fri
  "2024-06-15", # Sat
  "2024-06-17", # Mon
  "2024-06-19", # Wed
  "2024-06-22", # Sat
  "2024-06-23", # Sun
  "2024-06-26", # Wed
  "2024-07-05", # Fri
  "2024-07-06" # Sat
))

day_types_vec <- ifelse(
  weekdays(sampling_dates) %in% c("Saturday", "Sunday"),
  "weekend", "weekday"
)

# Generate realistic n_anglers with variability
# Weekdays: 15-40 anglers; Weekends: 40-80 anglers
n_weekday <- sum(day_types_vec == "weekday")
n_weekend <- sum(day_types_vec == "weekend")

anglers_weekday <- sample(15:40, n_weekday, replace = TRUE)
anglers_weekend <- sample(40:80, n_weekend, replace = TRUE)

n_anglers_vec <- integer(length(sampling_dates))
n_anglers_vec[day_types_vec == "weekday"] <- anglers_weekday
n_anglers_vec[day_types_vec == "weekend"] <- anglers_weekend

example_aerial_counts <- data.frame(
  date = sampling_dates,
  day_type = day_types_vec,
  n_anglers = as.integer(n_anglers_vec),
  stringsAsFactors = FALSE
)

# Data quality assertions
stopifnot(nrow(example_aerial_counts) == 16L)
stopifnot(all(example_aerial_counts$n_anglers > 0))
stopifnot(all(example_aerial_counts$day_type %in% c("weekday", "weekend")))
stopifnot(sd(example_aerial_counts$n_anglers) > 0)

usethis::use_data(example_aerial_counts, overwrite = TRUE)
