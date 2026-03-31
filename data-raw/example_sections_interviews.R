## Script to create example_sections_interviews dataset
## 27-row interview data: 9 interviews per section (North, Central, South).
## Catch rates vary materially by section (design intent for vignette contrast):
##   North: ~1 fish/hr (low), Central: ~1.5 fish/hr (mid), South: ~2.5 fish/hr (high)
## catch_kept included for estimate_total_harvest() compatibility.

example_sections_interviews <- data.frame(
  date = as.Date(c(
    # North (9 interviews)
    "2024-06-03", "2024-06-04", "2024-06-05",
    "2024-06-07", "2024-06-10", "2024-06-07",
    "2024-06-08", "2024-06-09", "2024-06-14",
    # Central (9 interviews)
    "2024-06-03", "2024-06-04", "2024-06-05",
    "2024-06-06", "2024-06-10", "2024-06-10",
    "2024-06-08", "2024-06-09", "2024-06-21",
    # South (9 interviews)
    "2024-06-03", "2024-06-04", "2024-06-05",
    "2024-06-06", "2024-06-07", "2024-06-07",
    "2024-06-08", "2024-06-09", "2024-06-14"
  )),
  day_type = c(
    "weekday", "weekday", "weekday", "weekday", "weekday", "weekday",
    "weekend", "weekend", "weekend",
    "weekday", "weekday", "weekday", "weekday", "weekday", "weekday",
    "weekend", "weekend", "weekend",
    "weekday", "weekday", "weekday", "weekday", "weekday", "weekday",
    "weekend", "weekend", "weekend"
  ),
  section = rep(c("North", "Central", "South"), each = 9L),
  catch_total = c(
    # North: ~1 fish/hr (low)
    2L, 3L, 2L, 4L, 3L, 2L, 3L, 4L, 3L,
    # Central: ~1.5 fish/hr (mid)
    5L, 6L, 5L, 7L, 6L, 5L, 7L, 8L, 6L,
    # South: ~2.5 fish/hr (high)
    10L, 12L, 9L, 11L, 10L, 12L, 13L, 11L, 10L
  ),
  catch_kept = c(
    # North: ~60% harvest rate
    1L, 2L, 1L, 2L, 2L, 1L, 2L, 2L, 2L,
    # Central: ~65% harvest rate
    3L, 4L, 3L, 5L, 4L, 3L, 5L, 5L, 4L,
    # South: ~70% harvest rate
    7L, 8L, 6L, 8L, 7L, 8L, 9L, 8L, 7L
  ),
  hours_fished = c(
    # North: 2-3 hrs
    2.0, 3.0, 2.5, 3.0, 2.0, 2.5, 3.0, 3.5, 3.0,
    # Central: 3-4 hrs
    3.5, 4.0, 3.5, 4.5, 4.0, 3.5, 4.5, 5.0, 4.0,
    # South: 4-5 hrs
    4.0, 5.0, 4.0, 4.5, 4.0, 5.0, 5.0, 4.5, 4.0
  ),
  trip_status = rep("complete", 27L),
  trip_duration = c(
    # North
    2.0, 3.0, 2.5, 3.0, 2.0, 2.5, 3.0, 3.5, 3.0,
    # Central
    3.5, 4.0, 3.5, 4.5, 4.0, 3.5, 4.5, 5.0, 4.0,
    # South
    4.0, 5.0, 4.0, 4.5, 4.0, 5.0, 5.0, 4.5, 4.0
  ),
  interview_id = 1L:27L,
  stringsAsFactors = FALSE
)

# Quality checks
stopifnot(nrow(example_sections_interviews) == 27L)
stopifnot(all(example_sections_interviews$catch_kept <= example_sections_interviews$catch_total))
stopifnot(all(example_sections_interviews$hours_fished > 0))
stopifnot(all(example_sections_interviews$trip_status == "complete"))
stopifnot(all(example_sections_interviews$trip_duration > 0))
stopifnot(all(example_sections_interviews$interview_id == 1L:27L))

# Verify material variation
north_mean <- mean(
  example_sections_interviews$catch_total[example_sections_interviews$section == "North"]
)
south_mean <- mean(
  example_sections_interviews$catch_total[example_sections_interviews$section == "South"]
)
stopifnot(south_mean > 2 * north_mean)

usethis::use_data(example_sections_interviews, overwrite = TRUE)
