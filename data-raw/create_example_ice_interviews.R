# Create example_ice_interviews dataset
# Interview data for an ice fishing creel survey at Lake McConaughy, Nebraska
# 72 interviews across 12 sampling days in January-February 2024
# Anglers ice fish from both open-air setups and dark-house shelters

example_ice_interviews <- data.frame(
  date = as.Date(c(
    # 2024-01-06 — 6 interviews
    "2024-01-06", "2024-01-06", "2024-01-06",
    "2024-01-06", "2024-01-06", "2024-01-06",
    # 2024-01-07 — 6 interviews
    "2024-01-07", "2024-01-07", "2024-01-07",
    "2024-01-07", "2024-01-07", "2024-01-07",
    # 2024-01-13 — 6 interviews
    "2024-01-13", "2024-01-13", "2024-01-13",
    "2024-01-13", "2024-01-13", "2024-01-13",
    # 2024-01-14 — 6 interviews
    "2024-01-14", "2024-01-14", "2024-01-14",
    "2024-01-14", "2024-01-14", "2024-01-14",
    # 2024-01-20 — 6 interviews
    "2024-01-20", "2024-01-20", "2024-01-20",
    "2024-01-20", "2024-01-20", "2024-01-20",
    # 2024-01-21 — 6 interviews
    "2024-01-21", "2024-01-21", "2024-01-21",
    "2024-01-21", "2024-01-21", "2024-01-21",
    # 2024-01-27 — 6 interviews
    "2024-01-27", "2024-01-27", "2024-01-27",
    "2024-01-27", "2024-01-27", "2024-01-27",
    # 2024-01-28 — 6 interviews
    "2024-01-28", "2024-01-28", "2024-01-28",
    "2024-01-28", "2024-01-28", "2024-01-28",
    # 2024-02-03 — 6 interviews
    "2024-02-03", "2024-02-03", "2024-02-03",
    "2024-02-03", "2024-02-03", "2024-02-03",
    # 2024-02-04 — 6 interviews
    "2024-02-04", "2024-02-04", "2024-02-04",
    "2024-02-04", "2024-02-04", "2024-02-04",
    # 2024-02-10 — 6 interviews
    "2024-02-10", "2024-02-10", "2024-02-10",
    "2024-02-10", "2024-02-10", "2024-02-10",
    # 2024-02-11 — 6 interviews
    "2024-02-11", "2024-02-11", "2024-02-11",
    "2024-02-11", "2024-02-11", "2024-02-11"
  )),
  n_counted = c(
    # 2024-01-06
    12L, 12L, 12L, 8L, 8L, 8L,
    # 2024-01-07
    10L, 10L, 10L, 6L, 6L, 6L,
    # 2024-01-13
    15L, 15L, 15L, 9L, 9L, 9L,
    # 2024-01-14
    11L, 11L, 11L, 7L, 7L, 7L,
    # 2024-01-20
    14L, 14L, 14L, 10L, 10L, 10L,
    # 2024-01-21
    13L, 13L, 13L, 8L, 8L, 8L,
    # 2024-01-27
    16L, 16L, 16L, 11L, 11L, 11L,
    # 2024-01-28
    12L, 12L, 12L, 9L, 9L, 9L,
    # 2024-02-03
    10L, 10L, 10L, 7L, 7L, 7L,
    # 2024-02-04
    13L, 13L, 13L, 8L, 8L, 8L,
    # 2024-02-10
    11L, 11L, 11L, 6L, 6L, 6L,
    # 2024-02-11
    14L, 14L, 14L, 9L, 9L, 9L
  ),
  n_interviewed = c(
    # 2024-01-06
    5L, 4L, 3L, 3L, 3L, 2L,
    # 2024-01-07
    4L, 3L, 3L, 2L, 2L, 2L,
    # 2024-01-13
    6L, 5L, 4L, 4L, 3L, 2L,
    # 2024-01-14
    5L, 4L, 2L, 3L, 2L, 2L,
    # 2024-01-20
    6L, 5L, 3L, 4L, 3L, 3L,
    # 2024-01-21
    5L, 4L, 4L, 3L, 3L, 2L,
    # 2024-01-27
    7L, 6L, 3L, 5L, 4L, 2L,
    # 2024-01-28
    5L, 4L, 3L, 4L, 3L, 2L,
    # 2024-02-03
    4L, 3L, 3L, 3L, 2L, 2L,
    # 2024-02-04
    5L, 4L, 4L, 3L, 3L, 2L,
    # 2024-02-10
    4L, 4L, 3L, 2L, 2L, 2L,
    # 2024-02-11
    6L, 5L, 3L, 4L, 3L, 2L
  ),
  hours_on_ice = c(
    # 2024-01-06
    5.0, 6.5, 4.0, 3.5, 5.0, 7.0,
    # 2024-01-07
    4.5, 5.0, 6.0, 3.0, 4.5, 5.5,
    # 2024-01-13
    6.0, 5.5, 4.5, 4.0, 5.5, 7.5,
    # 2024-01-14
    5.0, 6.0, 4.0, 3.5, 5.0, 6.5,
    # 2024-01-20
    6.5, 5.0, 4.5, 4.5, 5.5, 7.0,
    # 2024-01-21
    5.5, 6.0, 4.5, 3.5, 5.0, 6.5,
    # 2024-01-27
    7.0, 5.5, 4.5, 5.0, 6.0, 7.5,
    # 2024-01-28
    5.5, 6.5, 4.0, 4.0, 5.5, 7.0,
    # 2024-02-03
    5.0, 4.5, 4.0, 3.5, 5.0, 6.5,
    # 2024-02-04
    6.0, 5.5, 4.5, 4.0, 5.5, 7.0,
    # 2024-02-10
    5.0, 5.5, 4.0, 3.0, 4.5, 6.0,
    # 2024-02-11
    6.5, 5.0, 4.5, 4.5, 5.5, 7.0
  ),
  active_fishing_hours = c(
    # 2024-01-06
    4.0, 5.5, 3.5, 3.0, 4.0, 6.0,
    # 2024-01-07
    3.5, 4.0, 5.0, 2.5, 3.5, 4.5,
    # 2024-01-13
    5.0, 4.5, 3.5, 3.5, 4.5, 6.5,
    # 2024-01-14
    4.0, 5.0, 3.5, 3.0, 4.0, 5.5,
    # 2024-01-20
    5.5, 4.0, 3.5, 4.0, 4.5, 6.0,
    # 2024-01-21
    4.5, 5.0, 3.5, 3.0, 4.0, 5.5,
    # 2024-01-27
    6.0, 4.5, 3.5, 4.5, 5.0, 6.5,
    # 2024-01-28
    4.5, 5.5, 3.0, 3.5, 4.5, 6.0,
    # 2024-02-03
    4.0, 3.5, 3.0, 3.0, 4.0, 5.5,
    # 2024-02-04
    5.0, 4.5, 3.5, 3.5, 4.5, 6.0,
    # 2024-02-10
    4.0, 4.5, 3.0, 2.5, 3.5, 5.0,
    # 2024-02-11
    5.5, 4.0, 3.5, 4.0, 4.5, 6.0
  ),
  walleye_catch = c(
    # 2024-01-06
    2L, 0L, 1L, 3L, 1L, 0L,
    # 2024-01-07
    1L, 2L, 0L, 2L, 0L, 1L,
    # 2024-01-13
    3L, 1L, 0L, 2L, 2L, 0L,
    # 2024-01-14
    0L, 2L, 1L, 3L, 1L, 0L,
    # 2024-01-20
    2L, 0L, 1L, 2L, 0L, 1L,
    # 2024-01-21
    1L, 3L, 0L, 2L, 1L, 0L,
    # 2024-01-27
    2L, 1L, 0L, 3L, 2L, 1L,
    # 2024-01-28
    0L, 2L, 1L, 1L, 0L, 2L,
    # 2024-02-03
    1L, 0L, 2L, 2L, 1L, 0L,
    # 2024-02-04
    3L, 1L, 0L, 2L, 0L, 1L,
    # 2024-02-10
    1L, 2L, 0L, 2L, 1L, 0L,
    # 2024-02-11
    2L, 0L, 1L, 3L, 1L, 0L
  ),
  perch_catch = c(
    # 2024-01-06
    5L, 8L, 3L, 0L, 4L, 6L,
    # 2024-01-07
    4L, 3L, 7L, 5L, 2L, 4L,
    # 2024-01-13
    6L, 4L, 8L, 3L, 5L, 9L,
    # 2024-01-14
    7L, 3L, 5L, 2L, 6L, 4L,
    # 2024-01-20
    4L, 6L, 3L, 7L, 5L, 2L,
    # 2024-01-21
    5L, 4L, 8L, 3L, 6L, 5L,
    # 2024-01-27
    3L, 7L, 5L, 4L, 8L, 3L,
    # 2024-01-28
    6L, 4L, 3L, 7L, 5L, 4L,
    # 2024-02-03
    4L, 5L, 3L, 6L, 4L, 7L,
    # 2024-02-04
    5L, 3L, 7L, 4L, 6L, 5L,
    # 2024-02-10
    4L, 6L, 3L, 5L, 4L, 8L,
    # 2024-02-11
    6L, 4L, 5L, 3L, 7L, 4L
  ),
  walleye_kept = c(
    # 2024-01-06
    1L, 0L, 1L, 2L, 1L, 0L,
    # 2024-01-07
    1L, 1L, 0L, 1L, 0L, 0L,
    # 2024-01-13
    2L, 1L, 0L, 1L, 1L, 0L,
    # 2024-01-14
    0L, 1L, 1L, 2L, 0L, 0L,
    # 2024-01-20
    1L, 0L, 0L, 1L, 0L, 0L,
    # 2024-01-21
    1L, 2L, 0L, 1L, 1L, 0L,
    # 2024-01-27
    1L, 0L, 0L, 2L, 1L, 0L,
    # 2024-01-28
    0L, 1L, 1L, 0L, 0L, 1L,
    # 2024-02-03
    0L, 0L, 1L, 1L, 1L, 0L,
    # 2024-02-04
    2L, 1L, 0L, 1L, 0L, 0L,
    # 2024-02-10
    0L, 1L, 0L, 1L, 0L, 0L,
    # 2024-02-11
    1L, 0L, 1L, 2L, 0L, 0L
  ),
  perch_kept = c(
    # 2024-01-06
    3L, 5L, 2L, 0L, 3L, 4L,
    # 2024-01-07
    2L, 2L, 5L, 3L, 1L, 2L,
    # 2024-01-13
    4L, 3L, 5L, 2L, 3L, 6L,
    # 2024-01-14
    5L, 2L, 3L, 1L, 4L, 3L,
    # 2024-01-20
    3L, 4L, 2L, 5L, 3L, 1L,
    # 2024-01-21
    3L, 3L, 6L, 2L, 4L, 3L,
    # 2024-01-27
    2L, 5L, 3L, 3L, 6L, 2L,
    # 2024-01-28
    4L, 3L, 2L, 5L, 3L, 3L,
    # 2024-02-03
    3L, 3L, 2L, 4L, 2L, 5L,
    # 2024-02-04
    3L, 2L, 5L, 3L, 4L, 3L,
    # 2024-02-10
    3L, 4L, 2L, 3L, 2L, 5L,
    # 2024-02-11
    4L, 3L, 3L, 2L, 5L, 3L
  ),
  trip_status = c(
    # 2024-01-06
    "complete", "complete", "complete", "complete", "incomplete", "complete",
    # 2024-01-07
    "complete", "complete", "incomplete", "complete", "complete", "complete",
    # 2024-01-13
    "complete", "complete", "complete", "incomplete", "complete", "complete",
    # 2024-01-14
    "complete", "incomplete", "complete", "complete", "complete", "complete",
    # 2024-01-20
    "complete", "complete", "complete", "complete", "incomplete", "complete",
    # 2024-01-21
    "complete", "complete", "incomplete", "complete", "complete", "complete",
    # 2024-01-27
    "complete", "complete", "complete", "complete", "complete", "incomplete",
    # 2024-01-28
    "complete", "complete", "incomplete", "complete", "complete", "complete",
    # 2024-02-03
    "complete", "complete", "complete", "incomplete", "complete", "complete",
    # 2024-02-04
    "complete", "complete", "complete", "complete", "incomplete", "complete",
    # 2024-02-10
    "complete", "incomplete", "complete", "complete", "complete", "complete",
    # 2024-02-11
    "complete", "complete", "complete", "incomplete", "complete", "complete"
  ),
  shelter_mode = c(
    # 2024-01-06
    "open", "open", "open", "dark_house", "dark_house", "dark_house",
    # 2024-01-07
    "open", "open", "open", "dark_house", "dark_house", "dark_house",
    # 2024-01-13
    "open", "open", "open", "dark_house", "dark_house", "dark_house",
    # 2024-01-14
    "open", "open", "open", "dark_house", "dark_house", "dark_house",
    # 2024-01-20
    "open", "open", "open", "dark_house", "dark_house", "dark_house",
    # 2024-01-21
    "open", "open", "open", "dark_house", "dark_house", "dark_house",
    # 2024-01-27
    "open", "open", "open", "dark_house", "dark_house", "dark_house",
    # 2024-01-28
    "open", "open", "open", "dark_house", "dark_house", "dark_house",
    # 2024-02-03
    "open", "open", "open", "dark_house", "dark_house", "dark_house",
    # 2024-02-04
    "open", "open", "open", "dark_house", "dark_house", "dark_house",
    # 2024-02-10
    "open", "open", "open", "dark_house", "dark_house", "dark_house",
    # 2024-02-11
    "open", "open", "open", "dark_house", "dark_house", "dark_house"
  ),
  stringsAsFactors = FALSE
)

# Data quality assertions
iv <- example_ice_interviews
stopifnot(all(iv$n_interviewed <= iv$n_counted))
stopifnot(all(iv$active_fishing_hours <= iv$hours_on_ice))
stopifnot(all(iv$walleye_kept <= iv$walleye_catch))
stopifnot(all(iv$perch_kept <= iv$perch_catch))
stopifnot(all(iv$trip_status %in% c("complete", "incomplete")))
stopifnot(all(iv$shelter_mode %in% c("open", "dark_house")))
stopifnot(nrow(iv) == 72L)
stopifnot(sum(iv$walleye_kept) >= 5L)
stopifnot(sum(iv$perch_kept) >= 10L)

# Save the dataset
usethis::use_data(example_ice_interviews, overwrite = TRUE)
