## Script to create example_counts dataset
## Instantaneous count observations matching example_calendar
## Contains effort_hours as the count variable

example_counts <- data.frame(
  date = as.Date(c(
    "2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04",
    "2024-06-05", "2024-06-06", "2024-06-07", "2024-06-08",
    "2024-06-09", "2024-06-10", "2024-06-11", "2024-06-12",
    "2024-06-13", "2024-06-14"
  )),
  day_type = c(
    "weekend", "weekend", "weekday", "weekday",
    "weekday", "weekday", "weekday", "weekend",
    "weekend", "weekday", "weekday", "weekday",
    "weekday", "weekday"
  ),
  effort_hours = c(
    45.2, 52.8, 12.5, 18.3,
    15.7, 22.1, 14.9, 48.6,
    55.3, 16.8, 19.4, 13.2,
    17.6, 20.1
  ),
  stringsAsFactors = FALSE
)

usethis::use_data(example_counts, overwrite = TRUE)
