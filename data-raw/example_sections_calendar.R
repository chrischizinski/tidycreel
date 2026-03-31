## Script to create example_sections_calendar dataset
## A 12-day survey calendar for the spatially stratified sections workflow.
## Uses the canonical 3-section fixture dates to ensure compatibility with
## example_sections_counts and example_sections_interviews.

example_sections_calendar <- data.frame(
  date = as.Date(c(
    "2024-06-03", "2024-06-04", "2024-06-05", "2024-06-06",
    "2024-06-07", "2024-06-10",
    "2024-06-08", "2024-06-09", "2024-06-14", "2024-06-15",
    "2024-06-16", "2024-06-21"
  )),
  day_type = c(
    "weekday", "weekday", "weekday", "weekday", "weekday", "weekday",
    "weekend", "weekend", "weekend", "weekend", "weekend", "weekend"
  ),
  stringsAsFactors = FALSE
)

stopifnot(nrow(example_sections_calendar) == 12L)
stopifnot(all(example_sections_calendar$day_type %in% c("weekday", "weekend")))

usethis::use_data(example_sections_calendar, overwrite = TRUE)
