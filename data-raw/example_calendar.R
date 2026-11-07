## Script to create example_calendar dataset
## A 30-day survey calendar (June 2024) with weekday/weekend strata.
##
## example_counts and example_interviews cover the first 14 days only, so the
## toy example is a sample of the season, not a census of it: 14 of 30 days
## (4 of 10 weekend days, 10 of 20 weekdays) were counted. Up to tidycreel
## 8.0.0 the calendar held just those 14 days, which made every stratum a
## census and the season total equal to the sampled-day total (GH #584).

dates <- seq(as.Date("2024-06-01"), as.Date("2024-06-30"), by = "day")
example_calendar <- data.frame(
  date = dates,
  day_type = ifelse(format(dates, "%u") %in% c("6", "7"), "weekend", "weekday"),
  stringsAsFactors = FALSE
)

usethis::use_data(example_calendar, overwrite = TRUE)
