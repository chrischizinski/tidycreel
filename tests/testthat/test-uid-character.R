# A uid is a label, and it is character everywhere — GH #345 follow-up.
#
# The CSV reader infers a bare integer id column as numeric while a JSON API
# serves the same ids as strings, so the same survey reached a design with a
# numeric uid from one backend and a character uid from the other. A join key
# whose type depends on where the data came from does not reliably join.

uid_design <- function(uids) {
  data(example_calendar, package = "tidycreel")
  interviews <- data.frame(
    interview_uid = uids,
    date          = as.Date("2024-06-01") + rep(0:1, length.out = length(uids)),
    catch_total   = seq_along(uids),
    hours_fished  = 2,
    catch_kept    = 1,
    trip_status   = "complete",
    stringsAsFactors = FALSE
  )
  cal <- data.frame(
    date     = as.Date(c("2024-06-01", "2024-06-02")),
    day_type = c("weekday", "weekday"),
    stringsAsFactors = FALSE
  )
  suppressWarnings(suppressMessages({
    d <- creel_design(cal, date = date, strata = day_type)
    add_interviews(d, interviews,
      catch = catch_total, effort = hours_fished, harvest = catch_kept,
      trip_status = trip_status
    )
  }))
}

uid_catch <- function(uids) {
  data.frame(
    catch_uid     = uids,
    species       = "walleye",
    count         = 1,
    catch_type    = "harvested",
    stringsAsFactors = FALSE
  )
}

# --- the corruption a naive coercion would cause — UID-01 ---------------------

test_that("a large numeric uid is not rewritten in scientific notation (UID-01)", {
  # `as.character(100000)` is "1e+05". A naive coercion therefore rewrites every
  # id at or above 1e5 -- silently, and in the join key, which is the one column
  # where a corrupted value cannot be noticed by looking at a total. This is the
  # assertion that makes the sprintf() in as_uid_character() load-bearing.
  uids <- c(1, 42, 100000, 1000000, 123456789)
  d <- uid_design(uids)
  d <- suppressWarnings(suppressMessages(add_catch(
    d, uid_catch(uids),
    catch_uid = catch_uid, interview_uid = interview_uid,
    species = species, count = count, catch_type = catch_type
  )))

  got <- d$interviews[[d$catch_interview_uid_col]]
  expect_type(got, "character")
  expect_equal(got, c("1", "42", "100000", "1000000", "123456789"))
  expect_false(any(grepl("e\\+", got)))
})

test_that("a whole-number uid keeps no decimal tail (UID-02)", {
  # `format(x, scientific = FALSE)` renders 42 as "42.0", which joins against
  # nothing. The ids must come out exactly as they went in.
  d <- uid_design(c(7, 8))
  d <- suppressWarnings(suppressMessages(add_catch(
    d, uid_catch(c(7, 8)),
    catch_uid = catch_uid, interview_uid = interview_uid,
    species = species, count = count, catch_type = catch_type
  )))
  expect_equal(d[["catch"]][[d$catch_uid_col]], c("7", "8"))
})

# --- the join the type difference used to break — UID-03 ---------------------

test_that("a numeric-uid design joins catch carrying character uids (UID-03)", {
  # The cross-backend case: interviews loaded from CSV (numeric ids) and catch
  # fetched from an API (string ids). Both sides are normalised at the join, so
  # this composes instead of reporting every id as unmatched.
  d <- uid_design(c(1, 2, 3))
  expect_no_error(suppressWarnings(suppressMessages(add_catch(
    d, uid_catch(c("1", "2", "3")),
    catch_uid = catch_uid, interview_uid = interview_uid,
    species = species, count = count, catch_type = catch_type
  ))))
})

test_that("a genuinely unmatched uid is still refused (UID-04)", {
  # The control. Normalising both sides must not make everything match -- an id
  # that is absent is still absent, and CATCH-02 must still fire.
  d <- uid_design(c(1, 2, 3))
  expect_error(
    suppressWarnings(suppressMessages(add_catch(
      d, uid_catch(c("1", "999")),
      catch_uid = catch_uid, interview_uid = interview_uid,
      species = species, count = count, catch_type = catch_type
    ))),
    "not found in design interviews"
  )
})

# --- the helper itself — UID-05 ----------------------------------------------

test_that("as_uid_character() leaves character and factor alone (UID-05)", {
  f <- tidycreel:::as_uid_character
  expect_identical(f(c("a", "1", NA)), c("a", "1", NA))
  expect_identical(f(factor(c("b", "a"))), c("b", "a"))
  # An NA id stays missing rather than becoming the string "NA", which would
  # join against other missing ids and invent a match.
  expect_identical(f(c(1, NA, 3)), c("1", NA, "3"))
  # A non-whole value is not an id anyone intended; it is not truncated into
  # one, because that would silently merge 1.4 and 1.6 into "1".
  expect_identical(f(c(1.5, 2.5)), c("1.5", "2.5"))
})
