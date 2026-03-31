# Create example_camera_timestamps dataset
# Ingress-egress mode: raw POSIXct arrival/departure pairs from camera
# 14 rows: 3-4 anglers per day across 4 sampling days (mix of weekday/weekend)
# One row has duration > 8 hours (long fishing day); all others 1.5-5.5 hours
# No negative durations — the example data is clean

example_camera_timestamps <- data.frame(
  date = as.Date(c(
    # 2024-06-03 (weekday) — 3 anglers
    "2024-06-03", "2024-06-03", "2024-06-03",
    # 2024-06-04 (weekday) — 4 anglers
    "2024-06-04", "2024-06-04", "2024-06-04", "2024-06-04",
    # 2024-06-08 (weekend) — 4 anglers (one long day)
    "2024-06-08", "2024-06-08", "2024-06-08", "2024-06-08",
    # 2024-06-09 (weekend) — 3 anglers
    "2024-06-09", "2024-06-09", "2024-06-09"
  )),
  day_type = c(
    "weekday", "weekday", "weekday",
    "weekday", "weekday", "weekday", "weekday",
    "weekend", "weekend", "weekend", "weekend",
    "weekend", "weekend", "weekend"
  ),
  ingress_time = as.POSIXct(c(
    # 2024-06-03
    "2024-06-03 06:30:00", "2024-06-03 07:15:00", "2024-06-03 08:00:00",
    # 2024-06-04
    "2024-06-04 05:45:00", "2024-06-04 06:30:00",
    "2024-06-04 07:00:00", "2024-06-04 08:30:00",
    # 2024-06-08
    "2024-06-08 05:30:00", "2024-06-08 06:00:00",
    "2024-06-08 06:30:00", "2024-06-08 07:00:00",
    # 2024-06-09
    "2024-06-09 06:15:00", "2024-06-09 07:00:00", "2024-06-09 07:30:00"
  ), tz = "America/Chicago"),
  egress_time = as.POSIXct(c(
    # 2024-06-03 — durations: 3.25h, 5.0h, 2.75h
    "2024-06-03 09:45:00", "2024-06-03 12:15:00", "2024-06-03 10:45:00",
    # 2024-06-04 — durations: 4.25h, 3.5h, 5.5h, 1.5h
    "2024-06-04 10:00:00", "2024-06-04 10:00:00",
    "2024-06-04 12:30:00", "2024-06-04 10:00:00",
    # 2024-06-08 — durations: 9.0h (long day), 4.5h, 3.5h, 2.5h
    "2024-06-08 14:30:00", "2024-06-08 10:30:00",
    "2024-06-08 10:00:00", "2024-06-08 09:30:00",
    # 2024-06-09 — durations: 5.25h, 4.0h, 3.5h
    "2024-06-09 11:30:00", "2024-06-09 11:00:00", "2024-06-09 11:00:00"
  ), tz = "America/Chicago"),
  stringsAsFactors = FALSE
)

# Data quality assertions
ts <- example_camera_timestamps
durations_hrs <- as.numeric(
  difftime(ts$egress_time, ts$ingress_time, units = "hours")
)
stopifnot(all(durations_hrs > 0)) # no negative durations
stopifnot(any(durations_hrs > 8)) # at least one long fishing day
stopifnot(nrow(ts) == 14L)
stopifnot(inherits(ts$ingress_time, "POSIXct"))
stopifnot(inherits(ts$egress_time, "POSIXct"))
stopifnot(all(ts$day_type %in% c("weekday", "weekend")))

usethis::use_data(example_camera_timestamps, overwrite = TRUE)
