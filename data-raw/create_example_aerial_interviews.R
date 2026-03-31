# Create example_aerial_interviews dataset
# Angler interviews for aerial creel survey — standard roving-access interview structure
# 48 rows: 3 interviews per sampling day, same 16 sampling days as example_aerial_counts

set.seed(147)

sampling_dates <- as.Date(c(
  "2024-06-03", "2024-06-05", "2024-06-07",
  "2024-06-08", "2024-06-09", "2024-06-10",
  "2024-06-12", "2024-06-14", "2024-06-15",
  "2024-06-17", "2024-06-19", "2024-06-22",
  "2024-06-23", "2024-06-26", "2024-07-05",
  "2024-07-06"
))

day_types_pool <- ifelse(
  weekdays(sampling_dates) %in% c("Saturday", "Sunday"),
  "weekend", "weekday"
)

n_per_day <- 3L
n_total <- length(sampling_dates) * n_per_day # 48

dates_vec <- rep(sampling_dates, each = n_per_day)
day_type_vec <- rep(day_types_pool, each = n_per_day)

# hours_fished: trip duration in hours (1.0-5.0) — feeds L_bar in estimate_effort_aerial()
hours_fished_raw <- round(runif(n_total, min = 1.0, max = 5.0), 1)

# walleye catch counts
walleye_raw <- rpois(n_total, lambda = 1.0)

# walleye kept <= walleye caught
set.seed(247)
walleye_kept_raw <- vapply(
  walleye_raw,
  function(x) if (x == 0L) 0L else sample(0L:x, 1L),
  integer(1L)
)

# bass catch counts
set.seed(347)
bass_raw <- rpois(n_total, lambda = 0.6)

# bass kept <= bass caught
set.seed(447)
bass_kept_raw <- vapply(
  bass_raw,
  function(x) if (x == 0L) 0L else sample(0L:x, 1L),
  integer(1L)
)

example_aerial_interviews <- data.frame(
  date = dates_vec,
  day_type = day_type_vec,
  trip_status = rep("complete", n_total),
  hours_fished = hours_fished_raw,
  walleye_catch = as.integer(walleye_raw),
  walleye_kept = walleye_kept_raw,
  bass_catch = as.integer(bass_raw),
  bass_kept = bass_kept_raw,
  stringsAsFactors = FALSE
)

# Data quality assertions
iv <- example_aerial_interviews
stopifnot(nrow(iv) == 48L)
stopifnot(all(iv$walleye_kept <= iv$walleye_catch))
stopifnot(all(iv$bass_kept <= iv$bass_catch))
stopifnot(all(iv$hours_fished > 0))
stopifnot(all(iv$trip_status == "complete"))
stopifnot(all(iv$day_type %in% c("weekday", "weekend")))

usethis::use_data(example_aerial_interviews, overwrite = TRUE)
