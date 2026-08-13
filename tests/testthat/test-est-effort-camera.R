# Tests for est_effort_camera() ----

# Helpers ---------------------------------------------------------------------
make_camera_design <- function() {
  cal <- data.frame(
    date = as.Date(c(
      "2024-06-03",
      "2024-06-04",
      "2024-06-05",
      "2024-06-08",
      "2024-06-09"
    )),
    day_type = c("weekday", "weekday", "weekday", "weekend", "weekend"),
    stringsAsFactors = FALSE
  )
  suppressWarnings(
    creel_design(
      cal,
      date = date,
      strata = day_type, # nolint
      survey_type = "camera",
      camera_mode = "counter"
    )
  )
}

make_camera_counts <- function() {
  data.frame(
    date = as.Date(c(
      "2024-06-03",
      "2024-06-04",
      "2024-06-05",
      "2024-06-08",
      "2024-06-09"
    )),
    day_type = c("weekday", "weekday", "weekday", "weekend", "weekend"),
    ingress_count = c(48L, 55L, 43L, 80L, 75L),
    camera_status = rep("operational", 5L),
    stringsAsFactors = FALSE
  )
}

make_interviews <- function() {
  data.frame(
    date = as.Date(c(
      "2024-06-03",
      "2024-06-03",
      "2024-06-04",
      "2024-06-08",
      "2024-06-09"
    )),
    day_type = c("weekday", "weekday", "weekday", "weekend", "weekend"),
    hours_fished = c(3.5, 2.0, 4.0, 2.5, 3.0),
    stringsAsFactors = FALSE
  )
}

make_design_with_counts <- function() {
  d <- make_camera_design()
  suppressWarnings(add_counts(d, make_camera_counts()))
}

# Input validation ------------------------------------------------------------

test_that("CEST-01: errors when design is not creel_design", {
  expect_error(
    est_effort_camera(list()),
    class = "rlang_error"
  )
})

test_that("CEST-02: errors when conf_level out of range", {
  d <- make_design_with_counts()
  expect_error(
    est_effort_camera(d, h_open = 14, conf_level = 1.5),
    class = "rlang_error"
  )
})

test_that("CEST-02b: conf_level of length != 1 reaches the package's own error", {
  # A bare `conf_level <= 0` comparison on a length-2 input makes `||` raise
  # base R's "'length = 2' in coercion to 'logical(1)'", which is a simpleError:
  # the caller never sees which argument was wrong. The guard must reject the
  # length itself so the cli_abort naming `conf_level` is what actually fires.
  d <- make_design_with_counts()
  expect_error(
    est_effort_camera(d, h_open = 14, conf_level = c(0.90, 0.95)),
    class = "rlang_error"
  )
  expect_error(
    est_effort_camera(d, h_open = 14, conf_level = numeric(0)),
    class = "rlang_error"
  )
})

test_that("CEST-03: errors when no counts attached", {
  d <- make_camera_design()
  expect_error(
    est_effort_camera(d, h_open = 14),
    class = "rlang_error"
  )
})

test_that("CEST-04: errors in raw mode when h_open is NULL", {
  d <- make_design_with_counts()
  expect_error(
    est_effort_camera(d, interviews = NULL, h_open = NULL),
    class = "rlang_error"
  )
})

test_that("CEST-05: errors in raw mode when h_open <= 0", {
  d <- make_design_with_counts()
  expect_error(
    est_effort_camera(d, h_open = 0),
    class = "rlang_error"
  )
})

test_that("CEST-06: errors in ratio mode when effort_col missing", {
  d <- make_design_with_counts()
  int <- make_interviews()
  expect_error(
    est_effort_camera(d, interviews = int, effort_col = "nonexistent"),
    class = "rlang_error"
  )
})

# Return structure ------------------------------------------------------------

test_that("CEST-07: raw mode returns creel_estimates", {
  d <- make_design_with_counts()
  res <- suppressWarnings(est_effort_camera(d, h_open = 14))
  expect_s3_class(res, "creel_estimates")
})

test_that("CEST-08: raw mode has expected columns", {
  d <- make_design_with_counts()
  res <- suppressWarnings(est_effort_camera(d, h_open = 14))
  expect_true(all(
    c("estimate", "se", "ci_lower", "ci_upper", "n") %in%
      names(res$estimates)
  ))
})

test_that("CEST-09: ratio mode returns creel_estimates", {
  d <- make_design_with_counts()
  res <- suppressWarnings(
    est_effort_camera(d, interviews = make_interviews())
  )
  expect_s3_class(res, "creel_estimates")
})

test_that("CEST-10: ratio mode has expected columns", {
  d <- make_design_with_counts()
  res <- suppressWarnings(
    est_effort_camera(d, interviews = make_interviews())
  )
  expect_true(all(
    c("estimate", "se", "ci_lower", "ci_upper", "n") %in%
      names(res$estimates)
  ))
})

# Numeric correctness ---------------------------------------------------------

test_that("CEST-11: raw mode estimate = svytotal * h_open (positive)", {
  d <- make_design_with_counts()
  res <- suppressWarnings(est_effort_camera(d, h_open = 14))
  expect_gt(res$estimates$estimate, 0)
})

test_that("CEST-12: ratio mode estimate is positive", {
  d <- make_design_with_counts()
  res <- suppressWarnings(
    est_effort_camera(d, interviews = make_interviews())
  )
  expect_gt(res$estimates$estimate, 0)
})

test_that("CEST-13: larger h_open gives proportionally larger raw estimate", {
  d <- make_design_with_counts()
  r1 <- suppressWarnings(est_effort_camera(d, h_open = 7))$estimates$estimate
  r2 <- suppressWarnings(est_effort_camera(d, h_open = 14))$estimates$estimate
  expect_equal(r2 / r1, 2, tolerance = 1e-6)
})

test_that("CEST-14: se is non-negative", {
  d <- make_design_with_counts()
  res <- suppressWarnings(est_effort_camera(d, h_open = 14))
  expect_gte(res$estimates$se, 0)
})

test_that("CEST-15: ci_lower < estimate < ci_upper", {
  d <- make_design_with_counts()
  res <- suppressWarnings(est_effort_camera(d, h_open = 14))
  e <- res$estimates
  expect_lt(e$ci_lower, e$estimate)
  expect_lt(e$estimate, e$ci_upper)
})

# Method label ----------------------------------------------------------------

test_that("CEST-16: raw mode method is camera_raw", {
  d <- make_design_with_counts()
  res <- suppressWarnings(est_effort_camera(d, h_open = 14))
  expect_equal(res$method, "camera_raw")
})

test_that("CEST-17: ratio mode method is camera_ratio", {
  d <- make_design_with_counts()
  res <- suppressWarnings(
    est_effort_camera(d, interviews = make_interviews())
  )
  expect_equal(res$method, "camera_ratio")
})

# conf_level ------------------------------------------------------------------

test_that("CEST-18: higher conf_level gives wider CI", {
  d <- make_design_with_counts()
  r1 <- suppressWarnings(est_effort_camera(d, h_open = 14, conf_level = 0.90))
  r2 <- suppressWarnings(est_effort_camera(d, h_open = 14, conf_level = 0.99))
  w1 <- r1$estimates$ci_upper - r1$estimates$ci_lower
  w2 <- r2$estimates$ci_upper - r2$estimates$ci_lower
  expect_lt(w1, w2)
})

# non-camera design warning ---------------------------------------------------

test_that("CEST-19: non-camera design type produces a cli warning", {
  cal <- data.frame(
    date = as.Date(c(
      "2024-06-01",
      "2024-06-02",
      "2024-06-03",
      "2024-06-08",
      "2024-06-09"
    )),
    day_type = c("weekday", "weekday", "weekday", "weekend", "weekend")
  )
  d <- suppressWarnings(creel_design(cal, date = date, strata = day_type)) # nolint
  counts <- data.frame(
    date = as.Date(c(
      "2024-06-01",
      "2024-06-02",
      "2024-06-03",
      "2024-06-08",
      "2024-06-09"
    )),
    day_type = c("weekday", "weekday", "weekday", "weekend", "weekend"),
    count = c(10L, 12L, 14L, 20L, 22L)
  )
  d <- suppressWarnings(add_counts(d, counts))
  # The cli_warn for non-camera design type should fire
  expect_warning(
    est_effort_camera(d, h_open = 8),
    regexp = "design_type"
  )
})

# Finding 21: h_open must not apply time a second time -------------------------
#
# The raw-count branch expands a count by h_open. Once add_counts() gained the
# ability to apply T_d to any count type (finding 13), a design carrying both
# produced count x T_d x h_open -- angler-hour-hours, roughly double the truth,
# with nothing in the result saying so. These tests fail if that branch ever
# stops checking, which is what makes the number wrong rather than merely
# unlabelled.

make_camera_counts_with_td <- function() {
  counts <- make_camera_counts()
  counts$shift_hours <- rep(2, nrow(counts))
  counts
}

test_that("F21: raw-count branch refuses counts that already carry T_d", {
  d <- suppressWarnings(add_counts(
    make_camera_design(),
    make_camera_counts_with_td(),
    period_length_col = shift_hours # nolint: object_usage_linter
  ))

  # h_open would be the second time multiplier, so the product is not effort.
  expect_error(
    est_effort_camera(d, h_open = 14),
    class = "creel_error_camera_period_length"
  )
})

test_that("F21: raw-count branch is unaffected when no T_d was applied", {
  d <- make_design_with_counts()

  res <- suppressWarnings(est_effort_camera(d, h_open = 14))

  # sum(ingress) = 301 over 5 sampled days expanded to a 5-day calendar,
  # scaled by h_open = 14. Guards against the check firing on the normal path.
  expect_equal(res$estimates$estimate, 301 * 14)
})

test_that("F21: ratio-calibration branch accepts T_d, because it cancels", {
  d_td <- suppressWarnings(add_counts(
    make_camera_design(),
    make_camera_counts_with_td(),
    period_length_col = shift_hours # nolint: object_usage_linter
  ))
  d_raw <- make_design_with_counts()

  # The ratio path divides by mean(count) before multiplying by count, so a
  # constant T_d cancels out of the estimate entirely. Scoping the guard to the
  # raw branch is only correct if that is true -- assert it rather than assume.
  with_td <- suppressWarnings(
    est_effort_camera(d_td, interviews = make_interviews())
  )
  without_td <- suppressWarnings(
    est_effort_camera(d_raw, interviews = make_interviews())
  )

  expect_equal(with_td$estimates$estimate, without_td$estimates$estimate)
  expect_equal(with_td$method, "camera_ratio")
})

# Finding 22: the calibration ratio is a ratio of sums, so the camera counts
# cancel and the estimate inherits whatever unit `effort_col` holds. Before
# `n_anglers` existed there was no way to tell angler-hours from party-hours on
# this path, and no way for a caller to supply the missing information.

test_that("CEST-22: ratio path warns when n_anglers is not supplied", {
  d <- make_design_with_counts()
  expect_warning(
    est_effort_camera(d, interviews = make_interviews()),
    regexp = "angler-hours from party-hours"
  )
})

test_that("CEST-22: unit is unknown when n_anglers is not supplied", {
  # NA is the claim that tidycreel does not know, which is what the warning
  # above says out loud.
  d <- make_design_with_counts()
  res <- suppressWarnings(est_effort_camera(d, interviews = make_interviews()))
  expect_true(is.na(res$unit))
})

test_that("CEST-22: supplying n_anglers as a column earns the angler-hours label", {
  d <- make_design_with_counts()
  ints <- make_interviews()
  ints$party <- c(2, 2, 1, 3, 1)
  res <- est_effort_camera(d, interviews = ints, n_anglers = "party")
  expect_equal(res$unit, "angler-hours")
})

test_that("CEST-22: n_anglers changes the estimate, not just the label", {
  # The label is only honest if the function did the arithmetic that produces
  # it. A constant party size of 2 must double the estimate; if it does not,
  # the multiplication never reached the calibration and the label is a
  # declaration.
  d <- make_design_with_counts()
  ints <- make_interviews()
  base <- suppressWarnings(est_effort_camera(d, interviews = ints))
  doubled <- est_effort_camera(d, interviews = ints, n_anglers = 2)
  expect_equal(doubled$estimates$estimate, 2 * base$estimates$estimate)
  expect_equal(doubled$unit, "angler-hours")
})

test_that("CEST-22: no ambiguity warning once n_anglers is supplied", {
  d <- make_design_with_counts()
  expect_no_warning(
    est_effort_camera(d, interviews = make_interviews(), n_anglers = 1)
  )
})

test_that("CEST-22: n_anglers goes through the shared party-size rule", {
  # Reuses validate_party_size() rather than reimplementing it, so a party of
  # zero is refused here for the same reason it is in add_interviews().
  d <- make_design_with_counts()
  expect_error(
    est_effort_camera(d, interviews = make_interviews(), n_anglers = 0),
    regexp = "positive party size"
  )
})
