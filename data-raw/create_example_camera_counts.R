# Create example_camera_counts dataset
# Counter-mode daily ingress counts from a remote camera at a boat launch
# 10 rows: 9 operational days + 1 battery_failure gap row
# Dates: non-consecutive summer sampling days, June 2024

example_camera_counts <- data.frame(
  date = as.Date(c(
    "2024-06-03", "2024-06-04", "2024-06-05",
    "2024-06-07", "2024-06-08", "2024-06-10",
    "2024-06-11", "2024-06-12", "2024-06-14",
    "2024-06-15"
  )),
  day_type = c(
    "weekday", "weekday", "weekday",
    "weekend", "weekend", "weekday",
    "weekday", "weekday", "weekend",
    "weekend"
  ),
  ingress_count = c(
    48L, 55L, 43L,
    91L, 85L, 50L,
    NA_integer_, 61L, 98L,
    82L
  ),
  camera_status = c(
    "operational", "operational", "operational",
    "operational", "operational", "operational",
    "battery_failure", "operational", "operational",
    "operational"
  ),
  stringsAsFactors = FALSE
)

# Data quality assertions
stopifnot(
  all(example_camera_counts$camera_status %in%
    c("operational", "battery_failure", "memory_full", "occlusion"))
)
stopifnot(nrow(example_camera_counts) == 10L)
stopifnot(any(example_camera_counts$camera_status == "battery_failure"))
stopifnot(any(is.na(example_camera_counts$ingress_count)))
# Gap rows must have NA counts
stopifnot(all(
  is.na(example_camera_counts$ingress_count[
    example_camera_counts$camera_status != "operational"
  ])
))

usethis::use_data(example_camera_counts, overwrite = TRUE)
