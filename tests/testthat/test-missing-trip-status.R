# GH #561: an interview with no trip status fits neither the complete- nor the
# incomplete-trip estimator. add_interviews() refused the whole table, so every
# analysis filtered the rows by hand and counted them for the report by hand.
# The default still refuses; missing_trip_status = "exclude" is the explicit,
# counted way through.

mts_design <- function() {
  d <- creel_design(example_calendar, date = date, strata = day_type)
  suppressWarnings(add_counts(d, example_counts))
}

mts_attach <- function(iv, ...) {
  suppressWarnings(suppressMessages(add_interviews(
    mts_design(), iv,
    catch = catch_total, effort = hours_fished, harvest = catch_kept,
    trip_status = trip_status, n_anglers = n_anglers, ...
  )))
}

with_na_status <- function(rows = 1:3) {
  iv <- example_interviews
  iv$trip_status[rows] <- NA
  iv
}

test_that("NA trip status is still refused by default, and the message names the way through", {
  expect_error(mts_attach(with_na_status()), "missing_trip_status")
})

test_that("excluding gives exactly the estimate of removing the rows by hand", {
  iv <- with_na_status()
  q <- function(x) suppressWarnings(suppressMessages(x))
  ex <- q(estimate_catch_rate(mts_attach(iv, missing_trip_status = "exclude")))$estimates
  hand <- q(estimate_catch_rate(mts_attach(iv[-(1:3), ])))$estimates
  expect_equal(ex$estimate, hand$estimate)
  expect_equal(ex$se, hand$se)
  expect_equal(ex$n, hand$n)
})

test_that("excluded interviews are counted and kept on the design", {
  iv <- with_na_status()
  d <- creel_design(example_calendar, date = date, strata = day_type)
  d <- suppressWarnings(add_counts(d, example_counts))
  expect_message(
    d2 <- suppressWarnings(add_interviews(d, iv,
      catch = catch_total, effort = hours_fished, trip_status = trip_status,
      n_anglers = n_anglers, missing_trip_status = "exclude"
    )),
    "Excluded 3 interviews of 22",
    class = "creel_message_no_trip_status_excluded"
  )
  expect_equal(nrow(d2$excluded_interviews), 3)
  expect_equal(nrow(d2$interviews), 19)
})

test_that("catch rows of excluded interviews are dropped with a count", {
  iv <- with_na_status(1:2)
  d <- mts_attach(iv, missing_trip_status = "exclude")
  expect_message(
    d2 <- add_catch(d, example_catch,
      catch_uid = interview_id, interview_uid = interview_id,
      species = species, count = count, catch_type = catch_type
    ),
    "with no trip status"
  )
  expect_false(any(as.character(d2$catch$interview_id) %in% as.character(iv$interview_id[1:2])))
})

test_that("refused and status-less interviews are set aside together", {
  iv <- with_na_status(1:2)
  iv$refused <- FALSE
  iv$refused[3] <- TRUE
  d <- mts_attach(iv, refused = refused, missing_trip_status = "exclude")
  expect_equal(nrow(d$refused_interviews), 1)
  expect_equal(nrow(d$excluded_interviews), 2)
  expect_equal(nrow(d$interviews), 19)
})

test_that("a saved design excludes the same interviews when read back", {
  q <- function(x) suppressWarnings(suppressMessages(x))
  d <- mts_attach(with_na_status(), missing_trip_status = "exclude")
  p <- file.path(withr::local_tempdir(), "mts")
  write_design(d, p)
  r <- q(read_design(p))
  expect_equal(nrow(r$excluded_interviews), 3)
  expect_equal(q(estimate_catch_rate(r))$estimates$estimate, q(estimate_catch_rate(d))$estimates$estimate)
})

test_that("with no NA status, exclude changes nothing", {
  q <- function(x) suppressWarnings(suppressMessages(x))
  a <- mts_attach(example_interviews, missing_trip_status = "exclude")
  b <- mts_attach(example_interviews)
  expect_null(a$excluded_interviews)
  expect_equal(q(estimate_catch_rate(a))$estimates$estimate, q(estimate_catch_rate(b))$estimates$estimate)
})

test_that("an ice design refuses to set status-less interviews aside", {
  # Ice designs are degenerate bus routes and carry design$bus_route, so the
  # same guard covers them: a row there can carry the site's count.
  d <- creel_design(example_ice_sampling_frame,
    date = date, strata = day_type, survey_type = "ice",
    effort_type = "time_on_ice", p_period = 0.5
  )
  iv <- example_ice_interviews
  iv$trip_status[1] <- NA
  expect_error(
    suppressMessages(add_interviews(d, iv,
      catch = walleye_catch, effort = hours_on_ice, harvest = walleye_kept,
      trip_status = trip_status, n_counted = n_counted,
      n_interviewed = n_interviewed, n_anglers = n_anglers,
      missing_trip_status = "exclude"
    )),
    class = "creel_error_no_trip_status_bus_route"
  )
})

test_that("the dropped-rows message reads correctly for several excluded interviews", {
  d <- mts_attach(with_na_status(1:2), missing_trip_status = "exclude")
  expect_message(
    add_catch(d, example_catch,
      catch_uid = interview_id, interview_uid = interview_id,
      species = species, count = count, catch_type = catch_type
    ),
    "interviews with no trip status",
    class = "creel_message_no_trip_status_records_dropped"
  )
})
