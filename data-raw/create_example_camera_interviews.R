# Create example_camera_interviews dataset
# Angler interviews for a camera-monitored boat launch survey
# 40 rows: 5 interviews per day, 8 sampling days (summer fishery — walleye + bass)

set.seed(46)

n_days <- 8L
n_per_day <- 5L
n_total <- n_days * n_per_day # 40

dates_pool <- as.Date(c(
  "2024-06-03", "2024-06-04",
  "2024-06-07", "2024-06-08",
  "2024-06-10", "2024-06-11",
  "2024-06-14", "2024-06-15"
))
day_types_pool <- c(
  "weekday", "weekday",
  "weekend", "weekend",
  "weekday", "weekday",
  "weekend", "weekend"
)

dates_vec <- rep(dates_pool, each = n_per_day)
day_types_vec <- rep(day_types_pool, each = n_per_day)

# Generate walleye/bass counts with kept <= total constraint
set.seed(46)
walleye_raw <- rpois(n_total, lambda = 1.2)
set.seed(47)
bass_raw <- rpois(n_total, lambda = 0.8)

# Kept is a random fraction of total (0 to total)
set.seed(48)
walleye_kept_raw <- vapply(
  walleye_raw,
  function(x) if (x == 0L) 0L else sample(0L:x, 1L),
  integer(1L)
)
set.seed(49)
bass_kept_raw <- vapply(
  bass_raw,
  function(x) if (x == 0L) 0L else sample(0L:x, 1L),
  integer(1L)
)

set.seed(50)
hours_fished_raw <- round(runif(n_total, min = 0.5, max = 5.0), 1)

example_camera_interviews <- data.frame(
  date = dates_vec,
  day_type = day_types_vec,
  trip_status = rep("complete", n_total),
  hours_fished = hours_fished_raw,
  walleye = walleye_raw,
  walleye_kept = walleye_kept_raw,
  bass = bass_raw,
  bass_kept = bass_kept_raw,
  stringsAsFactors = FALSE
)

# Data quality assertions
iv <- example_camera_interviews
stopifnot(nrow(iv) == 40L)
stopifnot(all(iv$walleye_kept <= iv$walleye))
stopifnot(all(iv$bass_kept <= iv$bass))
stopifnot(all(iv$hours_fished > 0))
stopifnot(all(iv$trip_status == "complete"))
stopifnot(all(iv$day_type %in% c("weekday", "weekend")))

usethis::use_data(example_camera_interviews, overwrite = TRUE)
