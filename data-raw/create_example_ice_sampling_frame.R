# Create example_ice_sampling_frame dataset
# A minimal sampling frame for a Nebraska ice fishing creel survey
# Lake McConaughy — 12 sampling days across January-February
# Single access point (boat ramp / ice access area); p_site = 1.0 for all rows

example_ice_sampling_frame <- data.frame(
  date = as.Date(c(
    "2024-01-06", "2024-01-07",
    "2024-01-13", "2024-01-14",
    "2024-01-20", "2024-01-21",
    "2024-01-27", "2024-01-28",
    "2024-02-03", "2024-02-04",
    "2024-02-10", "2024-02-11"
  )),
  day_type = c(
    "weekend", "weekend",
    "weekend", "weekend",
    "weekend", "weekend",
    "weekend", "weekend",
    "weekend", "weekend",
    "weekend", "weekend"
  ),
  p_period = c(
    0.50, 0.50,
    0.50, 0.50,
    0.55, 0.55,
    0.60, 0.60,
    0.45, 0.45,
    0.55, 0.55
  ),
  stringsAsFactors = FALSE
)

# Data quality assertions
sf <- example_ice_sampling_frame
stopifnot(all(sf$p_period > 0 & sf$p_period <= 1))
stopifnot(all(sf$day_type %in% c("weekday", "weekend")))
stopifnot(nrow(sf) == 12L)

# Save the dataset
usethis::use_data(example_ice_sampling_frame, overwrite = TRUE)
