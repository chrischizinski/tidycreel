## Script to create example_calendar dataset
## A 14-day survey calendar with weekday/weekend strata
## Designed to demonstrate creel_design() and provide realistic example data

example_calendar <- data.frame(
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
  stringsAsFactors = FALSE
)

usethis::use_data(example_calendar, overwrite = TRUE)
