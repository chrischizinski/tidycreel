## Script to create example_sections_calendar dataset
## A 19-day survey calendar (June 3-21, 2024) for the spatially stratified
## sections workflow; 12 of its days were sampled.
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

# The days between the sampled ones that were not counted (GH #584). Without
# them every stratum is a census and the season total is the sampled-day total.
# The sampled days keep their labels, which example_sections_counts carries
# (two of them, the Fridays 2024-06-14 and 2024-06-21, are labelled weekend).
unsampled <- as.Date(c(
  "2024-06-11", "2024-06-12", "2024-06-13",
  "2024-06-17", "2024-06-18", "2024-06-19", "2024-06-20"
))
example_sections_calendar <- rbind(
  example_sections_calendar,
  data.frame(date = unsampled, day_type = "weekday", stringsAsFactors = FALSE)
)
example_sections_calendar <- example_sections_calendar[order(example_sections_calendar$date), ]
rownames(example_sections_calendar) <- NULL

stopifnot(nrow(example_sections_calendar) == 19L)
stopifnot(all(example_sections_calendar$day_type %in% c("weekday", "weekend")))

usethis::use_data(example_sections_calendar, overwrite = TRUE)
