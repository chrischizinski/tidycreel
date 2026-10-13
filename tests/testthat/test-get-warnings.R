# get_warnings(): every warning is also recorded on the object its call
# returns (GH #496). A warning that scrolls past is otherwise gone, and a user
# who cannot look back silences everything, including the warnings that mean
# an estimate may be wrong.

roving_design <- function(n_anglers = TRUE) {
  design <- creel_design(example_season_calendar, date = date, strata = day_type)
  design <- add_counts(design, example_season_counts,
    count_col = total_anglers, period_length_col = daylight_hours
  )
  args <- list(design, example_roving_interviews,
    catch = quote(catch_total), harvest = quote(catch_kept),
    effort = quote(hours_fished), trip_status = quote(trip_status),
    trip_duration = quote(hours_fished), interview_type = "roving"
  )
  if (n_anglers) args$n_anglers <- quote(n_anglers)
  suppressMessages(do.call(add_interviews, args))
}

# The creel_warning classes a call raises, with the value it returned.
raised <- function(expr) {
  seen <- character()
  value <- withCallingHandlers(
    suppressMessages(expr),
    creel_warning = function(w) {
      seen <<- c(seen, grep("^creel_warning_", class(w), value = TRUE)[1])
      invokeRestart("muffleWarning")
    }
  )
  list(value = value, classes = seen)
}

test_that("a warning raised by an estimator is on the estimate, with its tier", {
  design <- roving_design()
  out <- raised(estimate_catch_rate(design))
  w <- get_warnings(out$value)
  expect_identical(w$class, out$classes)
  expect_identical(w$class, "creel_warning_mor_truncation")
  # Truncation is a data-quality fact (tier 2), not a may-be-wrong one.
  expect_identical(w$tier, 2L)
  expect_identical(w$fn, "mor_truncation_message")
  expect_match(w$message, "MOR truncation: 29 trips excluded")
  # Plain text: the record is for reading back, not for the console.
  expect_false(grepl("\033[", w$message, fixed = TRUE))
})

test_that("a total records the warnings of the rate it computes internally", {
  # The truncation that printed came from inside the total; reading the total
  # back must show it, or the record disagrees with what the console showed.
  design <- roving_design()
  out <- raised(estimate_total_catch(design, target = "period_total"))
  expect_true("creel_warning_mor_truncation" %in% out$classes)
  expect_setequal(get_warnings(out$value)$class, out$classes)
})

test_that("a warning muffled for one call is still recorded", {
  # Per-call handling quietens the console; it must not erase the fact.
  design <- roving_design()
  rate <- withCallingHandlers(
    suppressMessages(estimate_catch_rate(design)),
    creel_warning_mor_truncation = function(w) invokeRestart("muffleWarning")
  )
  expect_identical(get_warnings(rate)$class, "creel_warning_mor_truncation")
})

test_that("an estimate holds only its own call's warnings", {
  # Records are keyed to the call. If they leaked, the second estimate would
  # carry the first one's truncation and report a problem it does not have.
  design <- roving_design()
  first <- raised(estimate_catch_rate(design))
  expect_gt(nrow(get_warnings(first$value)), 0)
  second <- raised(estimate_effort(design, target = "period_total"))
  expect_identical(second$classes, character())
  expect_identical(nrow(get_warnings(second$value)), 0L)
})

test_that("a design keeps the warnings of each step that built it", {
  design <- raised(roving_design(n_anglers = FALSE))
  w <- get_warnings(design$value)
  expect_identical(w$class, design$classes)
  expect_true("creel_warning_no_party_size" %in% w$class)
  # Units: an estimate from this design may be per party-hour.
  expect_identical(w$tier[w$class == "creel_warning_no_party_size"], 1L)
  # Named even though roving_design() reaches add_interviews() by do.call().
  expect_identical(w$fn[w$class == "creel_warning_no_party_size"], "add_interviews")
})

test_that("a later step adds to the design's record and keeps what was there", {
  design <- creel_design(example_calendar, date = date, strata = day_type)
  design <- add_counts(design, example_counts)
  design <- raised(add_interviews(design, example_interviews,
    catch = catch_total, effort = hours_fished, trip_status = trip_status
  ))$value
  before <- get_warnings(design)
  expect_true("creel_warning_no_party_size" %in% before$class)
  after <- add_catch(design, example_catch,
    catch_uid = interview_id, interview_uid = interview_id,
    species = species, count = count, catch_type = catch_type
  )
  expect_true(all(before$id %in% get_warnings(after)$id))
  # The record is the design's own; a step does not duplicate it.
  expect_false(anyDuplicated(get_warnings(after)$id) > 0)
})

test_that("nothing raised gives an empty table with the documented columns", {
  design <- creel_design(example_season_calendar, date = date, strata = day_type)
  w <- get_warnings(design)
  expect_identical(nrow(w), 0L)
  expect_named(w, c("id", "class", "tier", "fn", "message"))
})

test_that("get_warnings() refuses an object that keeps no record", {
  expect_error(get_warnings(data.frame()), class = "creel_error_get_warnings_class")
})

test_that("finished calls do not accumulate in the session log", {
  # The log only needs the calls in progress; a long season script must not
  # grow it without bound.
  design <- roving_design()
  for (i in 1:5) raised(estimate_catch_rate(design))
  expect_lte(length(tidycreel:::creel_warning_log$records), 1L)
})

test_that("a design saved in one session keeps new warnings in the next", {
  # Ids restart at 1 in every session. Matching on id, a design built in one
  # session and extended in the next dropped any new warning whose id it
  # already held, so get_warnings() disagreed with the console.
  design <- creel_design(example_calendar, date = date, strata = day_type)
  design <- add_counts(design, example_counts)
  design <- suppressWarnings(suppressMessages(add_interviews(design,
    example_interviews,
    catch = catch_total, effort = hours_fished, trip_status = trip_status
  )))
  held <- get_warnings(design)$id
  expect_length(held, 1L)
  # A new session: the next warning gets the id the design already holds.
  log <- tidycreel:::creel_warning_log
  withr::defer(log$seq <- max(log$seq, held))
  log$seq <- held - 1L
  rates <- data.frame(
    day_type = c("weekday", "weekend"), n_sampled = c(10, 10), n_responded = c(4, 9)
  )
  adjusted <- raised(adjust_nonresponse(design, rates, stratum_col = "day_type"))
  expect_true("creel_warning_low_response_rate" %in% adjusted$classes)
  w <- get_warnings(adjusted$value)
  expect_true("creel_warning_low_response_rate" %in% w$class)
  expect_true("creel_warning_no_party_size" %in% w$class)
})

test_that("adjust_nonresponse() keeps its warnings on the design it returns", {
  design <- creel_design(example_calendar, date = date, strata = day_type)
  design <- add_counts(design, example_counts)
  rates <- data.frame(
    day_type = c("weekday", "weekend"), n_sampled = c(10, 10), n_responded = c(4, 9)
  )
  out <- raised(adjust_nonresponse(design, rates, stratum_col = "day_type"))
  expect_setequal(get_warnings(out$value)$class, out$classes)
  expect_gt(length(out$classes), 0)
})

test_that("the log does not keep a finished call's frame alive", {
  # The frame holds the design and every intermediate table of the call;
  # keeping it reachable after the call returns would pin them in memory.
  design <- roving_design()
  raised(estimate_catch_rate(design))
  invisible(gc())
  frames <- lapply(tidycreel:::creel_warning_log$records, function(r) {
    rlang::wref_key(r$key)
  })
  expect_true(all(vapply(frames, is.null, logical(1))))
})

# Once per design (GH #496, step 3b) ---------------------------------------
# A season script calls the estimators dozens of times on one design. A data
# warning repeated on every call buries the warnings that mean an estimate may
# be wrong, and teaches users to silence everything. Tier-2 warnings therefore
# print the first time they are raised on a design and are recorded every time.

counts_design <- function() {
  design <- creel_design(example_calendar, date = date, strata = day_type)
  add_counts(design, example_counts)
}

test_that("a data warning prints once per design and is recorded every time", {
  design <- roving_design()
  first <- raised(estimate_catch_rate(design))
  second <- raised(estimate_catch_rate(design))
  expect_true("creel_warning_mor_truncation" %in% first$classes)
  expect_false("creel_warning_mor_truncation" %in% second$classes)
  # Not printed is not forgotten: the second estimate still carries it.
  expect_true("creel_warning_mor_truncation" %in% get_warnings(second$value)$class)
})

test_that("an estimate warning prints on every call", {
  # Tier 1 means this estimate may be wrong; it is never quietened.
  design <- suppressWarnings(suppressMessages(add_interviews(counts_design(),
    example_interviews,
    catch = catch_total, effort = hours_fished, trip_status = trip_status
  )))
  first <- raised(estimate_total_catch(design))
  second <- raised(estimate_total_catch(design))
  expect_true("creel_warning_unit_mismatch" %in% first$classes)
  expect_true("creel_warning_unit_mismatch" %in% second$classes)
  # The thin-cell warning in the same call is tier 2, and goes quiet.
  expect_true("creel_warning_thin_rate_cells" %in% first$classes)
  expect_false("creel_warning_thin_rate_cells" %in% second$classes)
})

test_that("the period-length warning prints once per design, not once per session", {
  # Once per session (the old .frequency = "once") hid it on every later
  # design, including one built from different counts.
  first <- counts_design()
  a <- raised(estimate_effort(first))
  b <- raised(estimate_effort(first))
  expect_true("creel_warning_no_period_length" %in% a$classes)
  expect_false("creel_warning_no_period_length" %in% b$classes)
  c <- raised(estimate_effort(counts_design()))
  expect_true("creel_warning_no_period_length" %in% c$classes)
})

test_that("attaching data gives a new design, which prints again", {
  design <- roving_design()
  raised(estimate_catch_rate(design))
  # The same steps run again: new data as far as anyone can tell.
  again <- roving_design()
  expect_false(identical(again$warning_id, design$warning_id))
  expect_true("creel_warning_mor_truncation" %in%
    raised(estimate_catch_rate(again))$classes)
})

test_that("adding different data to the same design prints its data warning again", {
  # Interactive work re-runs add_interviews() on one input after fixing the
  # data. Checked against the input design, the second, still-wrong table
  # would be silent.
  base <- counts_design()
  iv <- example_interviews
  iv$hours_fished[1] <- 0.05
  add <- function(data) {
    raised(add_interviews(base, data,
      catch = catch_total, effort = hours_fished, trip_status = trip_status,
      n_anglers = n_anglers
    ))
  }
  first <- add(iv)
  iv$hours_fished[2] <- 0.05
  second <- add(iv)
  expect_true("creel_warning_short_trips" %in% first$classes)
  expect_true("creel_warning_short_trips" %in% second$classes)
  expect_false(identical(first$value$warning_id, second$value$warning_id))
})

test_that("what a build step printed is not printed again by an estimate", {
  # The step has just shown the warning; the first estimate from the design
  # it returned must not repeat it.
  base <- counts_design()
  iv <- example_interviews
  iv$hours_fished[1] <- 0.05
  design <- raised(add_interviews(base, iv,
    catch = catch_total, effort = hours_fished, trip_status = trip_status,
    n_anglers = n_anglers
  ))$value
  key <- paste(design$warning_id, "creel_warning_short_trips")
  expect_true(exists(key, envir = tidycreel:::creel_warning_log$printed))
})

test_that("a design without an id drops repeats within one call only", {
  # A design saved before ids existed has none; it must still print on every
  # call rather than go silent for the session.
  design <- roving_design()
  design$warning_id <- NULL
  expect_true("creel_warning_mor_truncation" %in%
    raised(estimate_catch_rate(design))$classes)
  expect_true("creel_warning_mor_truncation" %in%
    raised(estimate_catch_rate(design))$classes)
})

test_that("design ids do not touch the random-number stream", {
  # A user's set.seed() must give the same draws whether or not a design was
  # built in between.
  set.seed(1)
  expected <- stats::runif(1)
  set.seed(1)
  counts_design()
  expect_identical(stats::runif(1), expected)
})

test_that("the design builders are exactly the functions that record a design", {
  # A builder missing from the list would check its warnings against the
  # input design and silence a warning about new data.
  ns <- asNamespace("tidycreel")
  calls_record <- function(x) {
    if (!is.call(x)) {
      return(FALSE)
    }
    if (identical(x[[1]], quote(record_step)) ||
      identical(x[[1]], quote(record_design_warnings))) {
      return(TRUE)
    }
    any(vapply(as.list(x)[-1], function(el) !missing(el) && calls_record(el), logical(1)))
  }
  helpers <- c("record_step", "record_design_warnings")
  found <- Filter(function(nm) {
    f <- get(nm, envir = ns)
    is.function(f) && !is.primitive(f) && !nm %in% helpers && calls_record(body(f))
  }, ls(ns, all.names = TRUE))
  expect_setequal(tidycreel:::creel_design_builders, found)
})

test_that("a once-per-design warning says its repeats are recorded", {
  # Without the line a reader has no way to know a later silence is a record,
  # not an absence.
  w <- tryCatch(estimate_catch_rate(roving_design()) |> suppressMessages(),
    creel_warning_mor_truncation = function(w) w
  )
  expect_match(conditionMessage(w), "get_warnings()", fixed = TRUE)
})

test_that("as_creel_svydesign() does not point at a record it does not keep", {
  # It returns a survey object, not a design or estimate: get_warnings() has
  # nothing to read, so the note must not send the reader there.
  w <- tryCatch(as_creel_svydesign(counts_design()),
    creel_warning_internal_svydesign = function(w) w
  )
  expect_false(grepl("get_warnings", conditionMessage(w), fixed = TRUE))
})

test_that("a first occurrence the caller muffles counts as its one print", {
  # Documented limitation: a calling handler cannot see whether a later
  # handler muffles the warning, so the first raise is the print. The record
  # still holds every occurrence.
  design <- roving_design()
  raised(estimate_catch_rate(design))
  second <- raised(estimate_catch_rate(design))
  expect_false("creel_warning_mor_truncation" %in% second$classes)
  expect_true("creel_warning_mor_truncation" %in% get_warnings(second$value)$class)
})
