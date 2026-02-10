# Generate example interview data matching example_calendar dates
# example_calendar has 14 days: June 1-14, 2024, weekday/weekend strata

example_interviews <- data.frame(
  date = as.Date(c(
    "2024-06-01", "2024-06-01", "2024-06-02", "2024-06-02",
    "2024-06-03", "2024-06-03", "2024-06-04",
    "2024-06-05", "2024-06-05", "2024-06-06",
    "2024-06-08", "2024-06-08", "2024-06-08",
    "2024-06-09", "2024-06-09",
    "2024-06-10", "2024-06-10",
    "2024-06-11", "2024-06-12",
    "2024-06-13", "2024-06-13", "2024-06-14"
  )),
  hours_fished = c(
    2.0, 3.5, 1.5, 2.0,
    2.5, 4.0, 1.0,
    3.0, 2.5, 2.0,
    4.0, 3.0, 2.5,
    3.5, 2.0,
    1.5, 3.0,
    2.0, 2.5,
    3.0, 1.5, 4.0
  ),
  catch_total = c(
    5, 8, 2, 3,
    6, 12, 1,
    7, 4, 3,
    10, 8, 6,
    9, 5,
    2, 6,
    4, 5,
    7, 3, 11
  ),
  catch_kept = c(
    2, 5, 1, 2,
    3, 8, 0,
    4, 2, 1,
    7, 5, 4,
    6, 3,
    1, 4,
    2, 3,
    5, 1, 8
  ),
  stringsAsFactors = FALSE
)

# Verify data quality
stopifnot(all(example_interviews$catch_kept <= example_interviews$catch_total))
stopifnot(all(example_interviews$hours_fished > 0))
stopifnot(nrow(example_interviews) == 22)

# Save the dataset
usethis::use_data(example_interviews, overwrite = TRUE)
