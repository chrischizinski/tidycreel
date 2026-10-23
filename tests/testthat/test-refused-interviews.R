# GH #557: a refused interview's catch and effort are unknown, not zero.
# add_interviews(refused =) used to store the flag and nothing read it, so
# refused parties entered every rate as ordinary trips with whatever their catch
# column held -- usually 0 -- and dragged rates toward zero with n unchanged.

refused_fixture <- function(n_refused = 5) {
  iv <- example_interviews
  iv$refused <- FALSE
  k <- which(iv$trip_status == "complete")[seq_len(n_refused)]
  iv$refused[k] <- TRUE
  iv$catch_total[k] <- 0
  iv$catch_kept[k] <- 0
  list(iv = iv, k = k)
}

refused_design <- function(iv, ...) {
  d <- creel_design(example_calendar, date = date, strata = day_type)
  d <- suppressWarnings(add_counts(d, example_counts))
  suppressWarnings(suppressMessages(add_interviews(
    d, iv,
    catch = catch_total, effort = hours_fished, harvest = catch_kept,
    trip_status = trip_status, n_anglers = n_anglers, ...
  )))
}

quiet_rate <- function(d) suppressWarnings(suppressMessages(estimate_catch_rate(d)))$estimates

test_that("refused interviews do not enter the catch rate", {
  fx <- refused_fixture()
  flagged <- quiet_rate(refused_design(fx$iv, refused = refused))
  # The reference is the same data with the refusals removed by hand: setting
  # them aside must be exactly that, not a zero-catch trip.
  removed <- quiet_rate(refused_design(fx$iv[-fx$k, ]))
  expect_equal(flagged$estimate, removed$estimate)
  expect_equal(flagged$se, removed$se)
  expect_equal(flagged$n, removed$n)
  # and it is not what scoring them as zero gives
  as_zero <- quiet_rate(refused_design(fx$iv))
  expect_lt(as_zero$estimate, flagged$estimate)
})

test_that("setting refusals aside is announced with its count", {
  fx <- refused_fixture(3)
  d <- creel_design(example_calendar, date = date, strata = day_type)
  d <- suppressWarnings(add_counts(d, example_counts))
  expect_message(
    suppressWarnings(add_interviews(
      d, fx$iv,
      catch = catch_total, effort = hours_fished, trip_status = trip_status,
      n_anglers = n_anglers, refused = refused
    )),
    "Set aside 3 refused interviews of 22"
  )
})

test_that("summarize_refusals() still counts the interviews set aside", {
  fx <- refused_fixture(4)
  d <- refused_design(fx$iv, refused = refused)
  expect_equal(nrow(d$interviews), nrow(fx$iv) - 4)
  s <- summarize_refusals(d)
  expect_equal(sum(s$N[s$participation == "refused"]), 4)
  expect_equal(sum(s$N), nrow(fx$iv))
})

test_that("refused interviews with unknown catch (NA) attach without error", {
  # A refusal usually has no catch or effort recorded at all. Validation reads
  # catch and effort, so the refusals must be set aside before it runs.
  fx <- refused_fixture(2)
  fx$iv$catch_total[fx$k] <- NA
  fx$iv$catch_kept[fx$k] <- NA
  fx$iv$hours_fished[fx$k] <- NA
  d <- refused_design(fx$iv, refused = refused)
  expect_equal(nrow(d$interviews), nrow(fx$iv) - 2)
})

test_that("an NA refused flag is refused: whether the party refused is unknown", {
  fx <- refused_fixture(0)
  fx$iv$refused[1] <- NA
  d <- creel_design(example_calendar, date = date, strata = day_type)
  d <- suppressWarnings(add_counts(d, example_counts))
  expect_error(
    suppressWarnings(add_interviews(
      d, fx$iv,
      catch = catch_total, effort = hours_fished, trip_status = trip_status,
      n_anglers = n_anglers, refused = refused
    )),
    class = "creel_error_refused_na"
  )
})

test_that("a refused flag that is not TRUE/FALSE is refused, 0/1 codes are read", {
  fx <- refused_fixture(2)
  bad <- fx$iv
  bad$refused <- ifelse(bad$refused, "Y", "N")
  d <- creel_design(example_calendar, date = date, strata = day_type)
  d <- suppressWarnings(add_counts(d, example_counts))
  expect_error(
    suppressWarnings(add_interviews(
      d, bad,
      catch = catch_total, effort = hours_fished, trip_status = trip_status,
      n_anglers = n_anglers, refused = refused
    )),
    class = "creel_error_refused_not_logical"
  )
  coded <- fx$iv
  coded$refused <- as.integer(coded$refused)
  expect_equal(nrow(refused_design(coded, refused = refused)$interviews), nrow(coded) - 2)
  coded$refused <- as.character(coded$refused)
  expect_equal(nrow(refused_design(coded, refused = refused)$interviews), nrow(coded) - 2)
})

test_that("catch rows of refused interviews are dropped with a count, not refused as unmatched", {
  fx <- refused_fixture(2)
  d <- refused_design(fx$iv, refused = refused)
  catch <- data.frame(
    interview_id = c(fx$iv$interview_id[fx$k], fx$iv$interview_id[-fx$k][1]),
    species = "walleye", count = c(NA, 1, 2), catch_type = "harvested"
  )
  # the refused interviews' rows include an unknown count, which add_catch()
  # would otherwise refuse; they are dropped first
  expect_message(
    d2 <- add_catch(d, catch,
      catch_uid = interview_id, interview_uid = interview_id,
      species = species, count = count, catch_type = catch_type
    ),
    "Dropped 2 catch rows from 2 refused interviews"
  )
  expect_equal(nrow(d2$catch), 1)
})

test_that("every interview refused is refused", {
  iv <- example_interviews
  iv$refused <- TRUE
  d <- creel_design(example_calendar, date = date, strata = day_type)
  d <- suppressWarnings(add_counts(d, example_counts))
  expect_error(
    suppressWarnings(add_interviews(
      d, iv,
      catch = catch_total, effort = hours_fished, trip_status = trip_status,
      n_anglers = n_anglers, refused = refused
    )),
    class = "creel_error_all_refused"
  )
})

test_that("a saved design sets the refusals aside again when it is read back", {
  # read_design() replays add_interviews() on the original table; a bundle that
  # lost the split would put the refusals back into every rate.
  fx <- refused_fixture()
  d <- refused_design(fx$iv, refused = refused)
  p <- file.path(withr::local_tempdir(), "refused")
  write_design(d, p)
  r <- suppressWarnings(suppressMessages(read_design(p)))
  expect_equal(nrow(r$interviews), nrow(d$interviews))
  expect_equal(nrow(r$refused_interviews), 5)
  expect_equal(quiet_rate(r)$estimate, quiet_rate(d)$estimate)
})

test_that("a refused interview still needs a date in the calendar", {
  # Skipping the catch and effort checks must not skip the date: a refused row
  # with no date was set aside and then fell out of summarize_refusals().
  fx <- refused_fixture(1)
  fx$iv$date[fx$k] <- NA
  d <- creel_design(example_calendar, date = date, strata = day_type)
  d <- suppressWarnings(add_counts(d, example_counts))
  expect_error(suppressWarnings(suppressMessages(add_interviews(
    d, fx$iv,
    catch = catch_total, effort = hours_fished, trip_status = trip_status,
    n_anglers = n_anglers, refused = refused
  ))), class = "creel_error_refused_no_date")
})

test_that("a catch table holding only refused interviews' rows stops clearly", {
  fx <- refused_fixture(1)
  d <- refused_design(fx$iv, refused = refused)
  catch <- data.frame(
    interview_id = fx$iv$interview_id[fx$k], species = "walleye",
    count = 0, catch_type = "caught"
  )
  expect_error(
    suppressMessages(add_catch(d, catch,
      catch_uid = interview_id, interview_uid = interview_id,
      species = species, count = count, catch_type = catch_type
    )),
    class = "creel_error_all_records_refused"
  )
})
