## Script to create example_sections_counts dataset
## 36-row effort counts: 12 dates x 3 sections (North, Central, South).
## Effort values match the canonical make_3section_total_catch_design() fixture
## used in the test suite so vignette numbers are consistent.

cal_dates <- as.Date(c(
  "2024-06-03", "2024-06-04", "2024-06-05", "2024-06-06",
  "2024-06-07", "2024-06-10",
  "2024-06-08", "2024-06-09", "2024-06-14", "2024-06-15",
  "2024-06-16", "2024-06-21"
))

cal_day_type <- c(
  "weekday", "weekday", "weekday", "weekday", "weekday", "weekday",
  "weekend", "weekend", "weekend", "weekend", "weekend", "weekend"
)

example_sections_counts <- data.frame(
  date = rep(cal_dates, times = 3),
  day_type = rep(cal_day_type, times = 3),
  section = rep(c("North", "Central", "South"), each = 12L),
  effort_hours = c(
    # North: weekday ~15-25, weekend ~20-28
    20, 22, 18, 25, 15, 24,
    21, 26, 23, 28, 20, 27,
    # Central: weekday ~30-45, weekend ~35-48
    35, 38, 32, 42, 30, 45,
    37, 44, 40, 48, 35, 46,
    # South: weekday ~5-12, weekend ~6-13
    8, 10, 5, 12, 6, 11,
    7, 9, 6, 13, 8, 10
  ),
  stringsAsFactors = FALSE
)

stopifnot(nrow(example_sections_counts) == 36L)
stopifnot(all(example_sections_counts$effort_hours > 0))
stopifnot(length(unique(example_sections_counts$section)) == 3L)

usethis::use_data(example_sections_counts, overwrite = TRUE)
