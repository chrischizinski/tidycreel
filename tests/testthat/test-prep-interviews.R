test_that("prep_interviews_trips() returns canonical columns from direct effort input", {
  df <- tibble::tibble(
    survey_date = as.Date(c("2024-06-01", "2024-06-02")),
    month = factor(c("6", "6")),
    day_type = factor(c("weekend", "weekend")),
    iid = c("i1", "i2"),
    hours = c(2.5, 3.0),
    status = c("Complete", "incomplete"),
    duration = c(2.5, 3.0),
    total_catch = c(4, 1),
    kept = c(2, 0),
    party_type = c("bank", "boat"),
    method = c("bait", "spin"),
    target = c("walleye", "bass"),
    party_size = c(1L, 3L),
    refusal = c(FALSE, TRUE)
  )

  result <- prep_interviews_trips(
    df,
    date = survey_date,
    strata = c(month, day_type),
    interview_uid = iid,
    effort_hours = hours,
    trip_status = status,
    trip_duration = duration,
    catch_total = total_catch,
    harvest_total = kept,
    angler_type = party_type,
    angler_method = method,
    species_sought = target,
    n_anglers = party_size,
    refused = refusal
  )

  expect_s3_class(result, "tbl_df")
  expect_named(
    result,
    c(
      "date", "interview_uid", "effort_hours", "trip_status", "trip_duration",
      "n_anglers", "refused", "month", "day_type", "catch_total",
      "harvest_total", "angler_type", "angler_method", "species_sought"
    )
  )
  expect_equal(result$trip_status, c("complete", "incomplete"))
  expect_equal(result$effort_hours, c(2.5, 3.0))
  expect_equal(result$n_anglers, c(1L, 3L))
})

test_that("prep_interviews_trips() computes effort from timestamps when hours omitted", {
  df <- tibble::tibble(
    date = as.Date(c("2024-06-01", "2024-06-02")),
    interview_id = c("a", "b"),
    trip_status = c("complete", "complete"),
    trip_start = as.POSIXct(c("2024-06-01 08:00", "2024-06-02 09:15"), tz = "UTC"),
    interview_time = as.POSIXct(c("2024-06-01 10:30", "2024-06-02 12:15"), tz = "UTC")
  )

  result <- prep_interviews_trips(
    df,
    date = date,
    interview_uid = interview_id,
    trip_status = trip_status,
    trip_start = trip_start,
    interview_time = interview_time
  )

  expect_equal(result$effort_hours, c(2.5, 3.0), tolerance = 1e-10)
  expect_equal(result$trip_duration, c(2.5, 3.0), tolerance = 1e-10)
})

test_that("prep_interviews_trips() defaults n_anglers to 1 and refused to FALSE", {
  df <- tibble::tibble(
    date = as.Date(c("2024-06-01", "2024-06-02")),
    interview_id = c("a", "b"),
    hours = c(1.5, 2.0),
    trip_status = c("complete", "incomplete")
  )

  result <- prep_interviews_trips(
    df,
    date = date,
    interview_uid = interview_id,
    effort_hours = hours,
    trip_status = trip_status
  )

  expect_equal(result$n_anglers, c(1L, 1L))
  expect_equal(result$refused, c(FALSE, FALSE))
})

test_that("prep_interviews_trips() preserves selected strata columns", {
  df <- tibble::tibble(
    date = as.Date(c("2024-06-01", "2024-06-02")),
    month = factor(c("6", "6")),
    day_type = factor(c("weekend", "weekday")),
    interview_id = c("a", "b"),
    hours = c(1.5, 2.0),
    trip_status = c("complete", "incomplete")
  )

  result <- prep_interviews_trips(
    df,
    date = date,
    strata = c(month, day_type),
    interview_uid = interview_id,
    effort_hours = hours,
    trip_status = trip_status
  )

  expect_identical(result$month, df$month)
  expect_identical(result$day_type, df$day_type)
})

test_that("prep_interviews_trips() errors when date is not Date", {
  df <- tibble::tibble(
    date_chr = c("2024-06-01", "2024-06-02"),
    interview_id = c("a", "b"),
    hours = c(1.5, 2.0),
    trip_status = c("complete", "incomplete")
  )

  expect_error(
    prep_interviews_trips(
      df,
      date = date_chr,
      interview_uid = interview_id,
      effort_hours = hours,
      trip_status = trip_status
    ),
    "Date"
  )
})

test_that("prep_interviews_trips() errors when effort cannot be derived", {
  df <- tibble::tibble(
    date = as.Date(c("2024-06-01", "2024-06-02")),
    interview_id = c("a", "b"),
    trip_status = c("complete", "incomplete")
  )

  expect_error(
    prep_interviews_trips(
      df,
      date = date,
      interview_uid = interview_id,
      trip_status = trip_status
    ),
    "Provide either"
  )
})

test_that("prep_interviews_trips() errors on invalid trip_status values", {
  df <- tibble::tibble(
    date = as.Date(c("2024-06-01", "2024-06-02")),
    interview_id = c("a", "b"),
    hours = c(1.5, 2.0),
    trip_status = c("complete", "partial")
  )

  expect_error(
    prep_interviews_trips(
      df,
      date = date,
      interview_uid = interview_id,
      effort_hours = hours,
      trip_status = trip_status
    ),
    "invalid trip-status"
  )
})

test_that("prep_interview_catch() returns canonical long catch columns", {
  df <- tibble::tibble(
    iid = c("i1", "i1", "i2"),
    sp = c("walleye", "walleye", "bass"),
    n = c(5, 2, 1),
    fate = c("Caught", "HARVESTED", "released")
  )

  result <- prep_interview_catch(
    df,
    interview_uid = iid,
    species = sp,
    count = n,
    catch_type = fate
  )

  expect_s3_class(result, "tbl_df")
  expect_named(result, c("interview_uid", "species", "count", "catch_type"))
  expect_equal(result$species, c("walleye", "walleye", "bass"))
  expect_equal(result$count, c(5, 2, 1))
  expect_equal(result$catch_type, c("caught", "harvested", "released"))
})

test_that("prep_interview_catch() preserves long format row count", {
  df <- tibble::tibble(
    interview_id = c(1L, 1L, 2L, 2L),
    species = c("walleye", "bass", "bass", "bass"),
    count = c(2, 1, 3, 1),
    catch_type = c("caught", "released", "caught", "harvested")
  )

  result <- prep_interview_catch(
    df,
    interview_uid = interview_id,
    species = species,
    count = count,
    catch_type = catch_type
  )

  expect_equal(nrow(result), 4L)
})

test_that("prep_interview_catch() errors when count is not numeric", {
  df <- tibble::tibble(
    interview_id = c("i1", "i2"),
    species = c("walleye", "bass"),
    count = c("5", "1"),
    catch_type = c("caught", "released")
  )

  expect_error(
    prep_interview_catch(
      df,
      interview_uid = interview_id,
      species = species,
      count = count,
      catch_type = catch_type
    ),
    "must be numeric"
  )
})

test_that("prep_interview_catch() errors when species is not character or factor", {
  df <- tibble::tibble(
    interview_id = c("i1", "i2"),
    species = c(850, 851),
    count = c(5, 1),
    catch_type = c("caught", "released")
  )

  expect_error(
    prep_interview_catch(
      df,
      interview_uid = interview_id,
      species = species,
      count = count,
      catch_type = catch_type
    ),
    "character or factor"
  )
})
