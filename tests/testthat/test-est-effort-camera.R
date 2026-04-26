# Tests for est_effort_camera() ----

# Helpers ---------------------------------------------------------------------
make_camera_design <- function() {
  cal <- data.frame(
    date = as.Date(c(
      "2024-06-03", "2024-06-04", "2024-06-05",
      "2024-06-08", "2024-06-09"
    )),
    day_type = c("weekday", "weekday", "weekday", "weekend", "weekend"),
    stringsAsFactors = FALSE
  )
  suppressWarnings(
    creel_design(cal,
      date = date, strata = day_type, # nolint
      survey_type = "camera", camera_mode = "counter"
    )
  )
}

make_camera_counts <- function() {
  data.frame(
    date = as.Date(c(
      "2024-06-03", "2024-06-04", "2024-06-05",
      "2024-06-08", "2024-06-09"
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
      "2024-06-03", "2024-06-03", "2024-06-04",
      "2024-06-08", "2024-06-09"
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
  expect_true(all(c("estimate", "se", "ci_lower", "ci_upper", "n") %in%
    names(res$estimates)))
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
  expect_true(all(c("estimate", "se", "ci_lower", "ci_upper", "n") %in%
    names(res$estimates)))
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
      "2024-06-01", "2024-06-02",
      "2024-06-03", "2024-06-08", "2024-06-09"
    )),
    day_type = c("weekday", "weekday", "weekday", "weekend", "weekend")
  )
  d <- suppressWarnings(creel_design(cal, date = date, strata = day_type)) # nolint
  counts <- data.frame(
    date = as.Date(c(
      "2024-06-01", "2024-06-02",
      "2024-06-03", "2024-06-08", "2024-06-09"
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
