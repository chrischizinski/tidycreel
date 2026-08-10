# Unit propagation across the effort/catch spine
#
# The durable fix for this audit's whole class of defect is to make the
# dimension non-silent. The rule these tests encode is that tidycreel asserts a
# unit ONLY where it performed the arithmetic that produces it, and reports
# "unknown" otherwise. A guessed unit is worse than no unit: it makes a wrong
# claim machine-readable, and every consumer downstream then repeats it.

make_unit_calendar <- function() {
  data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
    day_type = c("weekday", "weekday", "weekend", "weekend"),
    stringsAsFactors = FALSE
  )
}

make_unit_counts <- function() {
  data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
    day_type = c("weekday", "weekday", "weekend", "weekend"),
    n_anglers = c(10, 20, 50, 60),
    shift_hours = c(8, 8, 14, 14),
    stringsAsFactors = FALSE
  )
}

# ---- Derivation: assert a unit only where we did the arithmetic ----

test_that("effort is angler-hours exactly when add_counts() applied T_d", {
  design <- creel_design(make_unit_calendar(), date = date, strata = day_type)
  cnt <- make_unit_counts()

  with_td <- suppressWarnings(
    add_counts(design, cnt, period_length_col = shift_hours) # nolint: object_usage_linter
  )
  expect_identical(with_td$effort_unit, "angler-hours")
})

test_that("effort unit is unknown, not angler-days, when no T_d was applied", {
  # example_counts$effort_hours is ALREADY angler-hours. A bare numeric column
  # may be a head count or pre-expanded effort, and nothing here can tell them
  # apart, so labelling this "angler-days" would be a confident wrong claim on
  # half the inputs. NA means unknown and is the only honest answer.
  design <- creel_design(make_unit_calendar(), date = date, strata = day_type)
  cnt <- make_unit_counts()[, c("date", "day_type", "n_anglers")]

  no_td <- suppressWarnings(add_counts(design, cnt))

  expect_true(is.na(no_td$effort_unit))
  expect_false(identical(no_td$effort_unit, "angler-days"))
})

test_that("the interview denominator distinguishes angler-hours from party-hours", {
  data(example_counts, envir = environment())
  data(example_interviews, envir = environment())
  data(example_calendar, envir = environment())

  base <- suppressWarnings(add_counts(
    creel_design(example_calendar, date = date, strata = day_type),
    example_counts
  ))

  normalised <- suppressWarnings(suppressMessages(add_interviews(
    base, example_interviews,
    catch = catch_total, effort = hours_fished,
    n_anglers = n_anglers, trip_status = trip_status
  )))
  bare <- suppressWarnings(suppressMessages(add_interviews(
    base, example_interviews,
    catch = catch_total, effort = hours_fished, trip_status = trip_status
  )))

  expect_identical(interview_effort_unit(normalised), "angler-hours")
  expect_identical(interview_effort_unit(bare), "party-hours")
  expect_identical(rate_unit(normalised), "fish/angler-hour")
  expect_identical(rate_unit(bare), "fish/party-hour")
})

# ---- Propagation onto the returned object ----

test_that("estimate_effort() carries the derived unit onto the estimates", {
  design <- creel_design(make_unit_calendar(), date = date, strata = day_type)
  d <- suppressWarnings(
    add_counts(design, make_unit_counts(), period_length_col = shift_hours) # nolint: object_usage_linter
  )

  expect_identical(suppressWarnings(estimate_effort(d))$unit, "angler-hours")
  expect_identical(
    suppressWarnings(estimate_effort(d, by = day_type))$unit,
    "angler-hours"
  )
})

test_that("CPUE carries fish per denominator unit, and totals carry fish", {
  data(example_counts, envir = environment())
  data(example_interviews, envir = environment())
  data(example_calendar, envir = environment())

  d <- suppressWarnings(add_counts(
    creel_design(example_calendar, date = date, strata = day_type),
    example_counts
  ))
  d <- suppressWarnings(suppressMessages(add_interviews(
    d, example_interviews,
    catch = catch_total, effort = hours_fished,
    n_anglers = n_anglers, trip_status = trip_status
  )))

  expect_identical(
    suppressWarnings(suppressMessages(estimate_catch_rate(d)))$unit,
    "fish/angler-hour"
  )
  expect_identical(
    suppressWarnings(suppressMessages(estimate_total_catch(d)))$unit,
    "fish"
  )
})

test_that("print shows the unit only when it is known", {
  design <- creel_design(make_unit_calendar(), date = date, strata = day_type)
  cnt <- make_unit_counts()

  known <- suppressWarnings(
    add_counts(design, cnt, period_length_col = shift_hours) # nolint: object_usage_linter
  )
  unknown <- suppressWarnings(
    add_counts(design, cnt[, c("date", "day_type", "n_anglers")])
  )

  known_out <- format(suppressWarnings(estimate_effort(known)))
  unknown_out <- format(suppressWarnings(estimate_effort(unknown)))

  expect_true(any(grepl("Unit: angler-hours", known_out, fixed = TRUE)))
  # Absent, not "Unit: unknown" -- silence is the claim that we do not know
  expect_false(any(grepl("Unit:", unknown_out, fixed = TRUE)))
})

test_that("write_estimates() records a known unit in the CSV header", {
  design <- creel_design(make_unit_calendar(), date = date, strata = day_type)
  d <- suppressWarnings(
    add_counts(design, make_unit_counts(), period_length_col = shift_hours) # nolint: object_usage_linter
  )
  est <- suppressWarnings(estimate_effort(d))

  path <- withr::local_tempfile(fileext = ".csv")
  write_estimates(est, path)

  expect_true(any(grepl("^# Unit: angler-hours$", readLines(path))))
})

# ---- The check at the multiplication point ----

test_that("a known unit mismatch aborts the product", {
  # This is the guard the audit asks for: effort x rate is only a catch when the
  # rate's denominator is the quantity the effort is measured in.
  data(example_counts, envir = environment())
  data(example_interviews, envir = environment())
  data(example_calendar, envir = environment())

  d <- suppressWarnings(add_counts(
    creel_design(example_calendar, date = date, strata = day_type),
    example_counts
  ))
  d <- suppressWarnings(suppressMessages(add_interviews(
    d, example_interviews,
    catch = catch_total, effort = hours_fished,
    n_anglers = n_anglers, trip_status = trip_status
  )))
  d$effort_unit <- "angler-trips"

  expect_error(
    suppressMessages(estimate_total_catch(d)),
    class = "creel_error_unit_mismatch"
  )
})

test_that("matching units pass the product check silently", {
  data(example_counts, envir = environment())
  data(example_interviews, envir = environment())
  data(example_calendar, envir = environment())

  d <- suppressWarnings(add_counts(
    creel_design(example_calendar, date = date, strata = day_type),
    example_counts
  ))
  d <- suppressWarnings(suppressMessages(add_interviews(
    d, example_interviews,
    catch = catch_total, effort = hours_fished,
    n_anglers = n_anglers, trip_status = trip_status
  )))
  d$effort_unit <- "angler-hours"

  expect_no_warning(
    suppressMessages(estimate_total_catch(d)),
    message = "could not be verified"
  )
})

test_that("the party-hours product keeps its own warning and is not double-reported", {
  # warn_party_hours_product() (finding 7) already names this seam with a better
  # message. check_product_units() must stay silent so the caller gets one
  # diagnosis, not two competing ones.
  data(example_counts, envir = environment())
  data(example_interviews, envir = environment())
  data(example_calendar, envir = environment())

  d <- suppressWarnings(add_counts(
    creel_design(example_calendar, date = date, strata = day_type),
    example_counts
  ))
  d <- suppressWarnings(suppressMessages(add_interviews(
    d, example_interviews,
    catch = catch_total, effort = hours_fished, trip_status = trip_status
  )))

  msgs <- character()
  withCallingHandlers(
    suppressMessages(estimate_total_catch(d)),
    warning = function(w) {
      msgs <<- c(msgs, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )

  expect_true(any(grepl("different units", msgs)))
  expect_false(any(grepl("could not be verified", msgs)))
})

# ---- The prep seam is effort already, so it must not be nagged ----

test_that("prep_counts_daily_effort() output does not trip the T_d warning", {
  # This is the documented preferred workflow: counts are resolved into
  # sampled-day effort before add_counts() sees them, so there is no
  # instantaneous count left to expand and no T_d to ask for.
  withr::local_options(rlib_warning_verbosity = "verbose")

  raw <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
    day_type = c("weekday", "weekday", "weekend", "weekend"),
    gear = rep("bank", 4),
    eff = c(80, 160, 700, 840),
    stringsAsFactors = FALSE
  )
  prepped <- prep_counts_daily_effort(
    raw,
    date = date, strata = day_type,
    effort_type = gear, daily_effort = eff
  )
  expect_true(counts_are_effort(prepped))

  design <- creel_design(make_unit_calendar(), date = date, strata = day_type)
  d <- suppressWarnings(add_counts(design, prepped))

  expect_true(d$counts_are_effort)
  expect_no_warning(estimate_effort(d), message = "angler-days")
})

# ---- Scale invariance: the property a fixed-number test cannot check ----
#
# Multiply an input by k and the outputs must move by the exponent their
# dimension implies. A dimension error breaks these; an example test pinned to
# one number does not notice, because the wrong quantity is still a number.

test_that("scaling the count column scales effort by k and its variance by k^2", {
  design <- creel_design(make_unit_calendar(), date = date, strata = day_type)
  cnt <- make_unit_counts()
  k <- 3

  base <- suppressWarnings(estimate_effort(suppressWarnings(
    add_counts(design, cnt, period_length_col = shift_hours) # nolint: object_usage_linter
  )))
  scaled_cnt <- cnt
  scaled_cnt$n_anglers <- scaled_cnt$n_anglers * k
  scaled <- suppressWarnings(estimate_effort(suppressWarnings(
    add_counts(design, scaled_cnt, period_length_col = shift_hours) # nolint: object_usage_linter
  )))

  expect_equal(scaled$estimates$estimate, k * base$estimates$estimate)
  expect_equal(scaled$estimates$se, k * base$estimates$se)
  expect_equal(scaled$estimates$se^2, k^2 * base$estimates$se^2)
})

test_that("scaling T_d scales effort by k, so T_d enters linearly", {
  design <- creel_design(make_unit_calendar(), date = date, strata = day_type)
  cnt <- make_unit_counts()
  k <- 2.5

  base <- suppressWarnings(estimate_effort(suppressWarnings(
    add_counts(design, cnt, period_length_col = shift_hours) # nolint: object_usage_linter
  )))
  scaled_cnt <- cnt
  scaled_cnt$shift_hours <- scaled_cnt$shift_hours * k
  scaled <- suppressWarnings(estimate_effort(suppressWarnings(
    add_counts(design, scaled_cnt, period_length_col = shift_hours) # nolint: object_usage_linter
  )))

  expect_equal(scaled$estimates$estimate, k * base$estimates$estimate)
})

test_that("scaling interview effort scales CPUE by 1/k", {
  data(example_counts, envir = environment())
  data(example_interviews, envir = environment())
  data(example_calendar, envir = environment())
  k <- 4

  build <- function(ivw) {
    d <- suppressWarnings(add_counts(
      creel_design(example_calendar, date = date, strata = day_type),
      example_counts
    ))
    suppressWarnings(suppressMessages(add_interviews(
      d, ivw,
      catch = catch_total, effort = hours_fished,
      n_anglers = n_anglers, trip_status = trip_status
    )))
  }

  scaled_ivw <- example_interviews
  scaled_ivw$hours_fished <- scaled_ivw$hours_fished * k

  base <- suppressWarnings(suppressMessages(
    estimate_catch_rate(build(example_interviews))
  ))$estimates$estimate
  scaled <- suppressWarnings(suppressMessages(
    estimate_catch_rate(build(scaled_ivw))
  ))$estimates$estimate

  expect_equal(scaled, base / k)
})

test_that("scaling the count column scales total catch by k", {
  data(example_counts, envir = environment())
  data(example_interviews, envir = environment())
  data(example_calendar, envir = environment())
  k <- 3

  build <- function(cnts) {
    d <- suppressWarnings(add_counts(
      creel_design(example_calendar, date = date, strata = day_type),
      cnts
    ))
    suppressWarnings(suppressMessages(add_interviews(
      d, example_interviews,
      catch = catch_total, effort = hours_fished,
      n_anglers = n_anglers, trip_status = trip_status
    )))
  }

  scaled_counts <- example_counts
  scaled_counts$effort_hours <- scaled_counts$effort_hours * k

  base <- suppressWarnings(suppressMessages(
    estimate_total_catch(build(example_counts))
  ))$estimates$estimate
  scaled <- suppressWarnings(suppressMessages(
    estimate_total_catch(build(scaled_counts))
  ))$estimates$estimate

  expect_equal(scaled, k * base)
})

test_that("angler-hours effort against a party-hour rate warns and does not abort", {
  # The load-bearing case for the party-hours carve-out. Once T_d is applied the
  # effort unit is KNOWN to be angler-hours, so a per-party-hour rate is a
  # genuine known-unit mismatch and the generic check would abort on it.
  # Escalating this seam from finding 7's warning to an error would break every
  # caller who omits n_anglers, which is what the bundled examples do -- so the
  # carve-out must hold. A fixture whose effort unit is unknown cannot test this:
  # the check returns early and the carve-out is never reached.
  data(example_calendar, envir = environment())
  data(example_interviews, envir = environment())

  counts <- data.frame(
    date = example_calendar$date,
    day_type = example_calendar$day_type,
    n_anglers = rep(c(12, 30), length.out = nrow(example_calendar)),
    shift_hours = rep(c(9, 13), length.out = nrow(example_calendar)),
    stringsAsFactors = FALSE
  )

  d <- suppressWarnings(add_counts(
    creel_design(example_calendar, date = date, strata = day_type),
    counts,
    period_length_col = shift_hours # nolint: object_usage_linter
  ))
  # n_anglers deliberately omitted: .angler_effort is party-hours
  d <- suppressWarnings(suppressMessages(add_interviews(
    d, example_interviews,
    catch = catch_total, effort = hours_fished, trip_status = trip_status
  )))

  expect_identical(d$effort_unit, "angler-hours")
  expect_identical(interview_effort_unit(d), "party-hours")

  msgs <- character()
  expect_no_error(
    withCallingHandlers(
      suppressMessages(estimate_total_catch(d)),
      warning = function(w) {
        msgs <<- c(msgs, conditionMessage(w))
        invokeRestart("muffleWarning")
      }
    )
  )
  # finding 7 still names it, and it stays a warning
  expect_true(any(grepl("different units", msgs)))
})
