test_that("schema_test_runner works with valid data", {
  calendar <- tibble::tibble(
    date = as.Date("2024-01-01"),
    stratum_id = "2024-01-01-weekday-morning",
    day_type = "weekday",
    season = "winter",
    month = "January",
    weekend = FALSE,
    holiday = FALSE,
    shift_block = "morning",
    target_sample = 10L,
    actual_sample = 8L
  )
  interviews <- tibble::tibble(
    interview_id = "INT001",
    date = as.Date("2024-01-01"),
    time_start = as.POSIXct("2024-01-01 08:00:00"),
    time_end = as.POSIXct("2024-01-01 08:15:00"),
    location = "Lake_A",
    mode = "boat",
    party_size = 2L,
    hours_fished = 4.5,
    target_species = "walleye",
    catch_total = 5L,
    catch_kept = 3L,
    catch_released = 2L,
    weight_total = 2.5,
    trip_complete = TRUE,
    effort_expansion = 1.0
  )
  counts <- tibble::tibble(
    count_id = "CNT001",
    date = as.Date("2024-01-01"),
    time = as.POSIXct("2024-01-01 09:00:00"),
    location = "Lake_A",
    mode = "boat",
    anglers_count = 15L,
    parties_count = 8L,
    weather_code = "clear",
    temperature = 22.5,
    wind_speed = 5.2,
    visibility = "good",
    count_duration = 15
  )
  auxiliary <- tibble::tibble(
    date = as.Date("2024-01-01"),
    sunrise = as.POSIXct("2024-01-01 06:00:00"),
    sunset = as.POSIXct("2024-01-01 18:00:00"),
    holiday = FALSE
  )
  reference <- tibble::tibble(
    code = "SPC001",
    description = "Walleye"
  )
  data_list <- list(
    calendar = calendar,
    interviews = interviews,
    counts = counts,
    auxiliary = auxiliary,
    reference = reference
  )
  expect_silent(schema_test_runner(data_list))
})
test_that("validate_calendar works with valid data", {
  calendar <- tibble::tibble(
    date = as.Date("2024-01-01"),
    stratum_id = "2024-01-01-weekday-morning",
    day_type = "weekday",
    season = "winter",
    month = "January",
    weekend = FALSE,
    holiday = FALSE,
    shift_block = "morning",
    target_sample = 10L,
    actual_sample = 8L
  )

  expect_silent(validate_calendar(calendar))
})

test_that("validate_calendar fails with missing columns", {
  calendar <- tibble::tibble(
    date = as.Date("2024-01-01"),
    stratum_id = "2024-01-01-weekday-morning"
  )

  expect_error(validate_calendar(calendar))
})

test_that("validate_interviews works with valid data", {
  interviews <- tibble::tibble(
    interview_id = "INT001",
    date = as.Date("2024-01-01"),
    time_start = as.POSIXct("2024-01-01 08:00:00"),
    time_end = as.POSIXct("2024-01-01 08:15:00"),
    location = "Lake_A",
    mode = "boat",
    shift_block = "morning",
    day_type = "weekday",
    party_size = 2L,
    hours_fished = 4.5,
    target_species = "walleye",
    catch_total = 5L,
    catch_kept = 3L,
    catch_released = 2L,
    weight_total = 2.5,
    trip_complete = TRUE,
    effort_expansion = 1.0
  )

  expect_silent(validate_interviews(interviews))
})

test_that("validate_counts works with valid data", {
  counts <- tibble::tibble(
    count_id = "CNT001",
    date = as.Date("2024-01-01"),
    time = as.POSIXct("2024-01-01 09:00:00"),
    location = "Lake_A",
    mode = "boat",
    anglers_count = 15L,
    parties_count = 8L,
    weather_code = "clear",
    temperature = 22.5,
    wind_speed = 5.2,
    visibility = "good",
    count_duration = 15
  )

  expect_silent(validate_counts(counts))
})