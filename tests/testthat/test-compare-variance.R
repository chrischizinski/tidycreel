# Helper to create a minimal design with attached interviews ----

make_cv_design <- function(n = 40, grouped = FALSE) {
  cal <- data.frame(
    date     = as.Date(c(
      "2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04"
    )),
    day_type = rep(c("weekday", "weekend"), each = 2),
    stringsAsFactors = FALSE
  )
  design <- suppressMessages(
    creel_design(cal, date = date, strata = day_type)
  )

  base_cols <- list(
    date          = as.Date(rep(
      c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04"),
      each = n / 4
    )),
    catch_total   = sample(3:8, n, replace = TRUE),
    hours_fished  = rep(3.0, n),
    trip_status   = rep("complete", n),
    trip_duration = rep(3.0, n)
  )

  if (grouped) {
    base_cols$day_type <- rep(
      c("weekday", "weekday", "weekend", "weekend"),
      each = n / 4
    )
  }

  interviews <- as.data.frame(base_cols, stringsAsFactors = FALSE)

  suppressMessages(suppressWarnings(
    add_interviews(design, interviews,
                   catch         = catch_total,
                   effort        = hours_fished,
                   trip_status   = trip_status,
                   trip_duration = trip_duration)
  ))
}

# Basic structure tests ----

test_that("CV-01: compare_variance returns creel_variance_comparison", {
  set.seed(1)
  design <- make_cv_design()
  est    <- suppressWarnings(estimate_catch_rate(design))
  cmp    <- suppressWarnings(compare_variance(est))
  expect_s3_class(cmp, "creel_variance_comparison")
})

test_that("CV-02: compare_variance has required columns", {
  set.seed(1)
  design <- make_cv_design()
  est    <- suppressWarnings(estimate_catch_rate(design))
  cmp    <- suppressWarnings(compare_variance(est))
  expect_true("se_taylor"        %in% names(cmp))
  expect_true("se_replicate"     %in% names(cmp))
  expect_true("divergence_ratio" %in% names(cmp))
  expect_true("diverges_flag"    %in% names(cmp))
})

test_that("CV-03: se_taylor and se_replicate are non-negative numerics", {
  set.seed(1)
  design <- make_cv_design()
  est    <- suppressWarnings(estimate_catch_rate(design))
  cmp    <- suppressWarnings(compare_variance(est))
  expect_type(cmp$se_taylor,    "double")
  expect_type(cmp$se_replicate, "double")
  expect_true(all(cmp$se_taylor    >= 0, na.rm = TRUE))
  expect_true(all(cmp$se_replicate >= 0, na.rm = TRUE))
})

test_that("CV-04: diverges_flag is logical", {
  set.seed(1)
  design <- make_cv_design()
  est    <- suppressWarnings(estimate_catch_rate(design))
  cmp    <- suppressWarnings(compare_variance(est))
  expect_type(cmp$diverges_flag, "logical")
})

test_that("CV-05: diverges_flag = FALSE on uniform toy data", {
  # Highly uniform data (same catch/effort for everyone) ->
  # Taylor and bootstrap SEs should both be near 0
  cal <- data.frame(
    date     = as.Date(c("2024-06-01", "2024-06-02",
                         "2024-06-03", "2024-06-04")),
    day_type = rep(c("weekday", "weekend"), each = 2),
    stringsAsFactors = FALSE
  )
  design  <- suppressMessages(creel_design(cal, date = date, strata = day_type))
  interviews <- data.frame(
    date          = as.Date(rep(c("2024-06-01", "2024-06-02",
                                  "2024-06-03", "2024-06-04"),
                                each = 10)),
    catch_total   = rep(5L, 40),
    hours_fished  = rep(2.0, 40),
    trip_status   = rep("complete", 40),
    trip_duration = rep(2.0, 40),
    stringsAsFactors = FALSE
  )
  design <- suppressMessages(suppressWarnings(
    add_interviews(design, interviews,
                   catch         = catch_total,
                   effort        = hours_fished,
                   trip_status   = trip_status,
                   trip_duration = trip_duration)
  ))
  est <- suppressWarnings(estimate_catch_rate(design))
  cmp <- suppressWarnings(compare_variance(est))
  # Both SEs are ~0 for constant data; diverges_flag should be FALSE
  # (either via FALSE or NA when se_taylor == 0)
  expect_true(all(!cmp$diverges_flag | is.na(cmp$diverges_flag)))
})

test_that("CV-06: print.creel_variance_comparison works without error", {
  set.seed(1)
  design <- make_cv_design()
  est    <- suppressWarnings(estimate_catch_rate(design))
  cmp    <- suppressWarnings(compare_variance(est))
  expect_output(print(cmp))
})

test_that("CV-07: as.data.frame.creel_variance_comparison returns data.frame", {
  set.seed(1)
  design <- make_cv_design()
  est    <- suppressWarnings(estimate_catch_rate(design))
  cmp    <- suppressWarnings(compare_variance(est))
  df     <- as.data.frame(cmp)
  expect_s3_class(df, "data.frame")
  expect_false(inherits(df, "tbl_df"))
})

test_that("CV-08: compare_variance errors on non-creel_estimates input", {
  expect_error(
    compare_variance(list(a = 1)),
    regexp = "creel_estimates"
  )
  expect_error(
    compare_variance("not an estimate"),
    regexp = "creel_estimates"
  )
})

test_that("CV-09: jackknife replicate_method works", {
  set.seed(1)
  design <- make_cv_design()
  est    <- suppressWarnings(estimate_catch_rate(design))
  cmp    <- suppressWarnings(compare_variance(est, replicate_method = "jackknife"))
  expect_s3_class(cmp, "creel_variance_comparison")
  expect_true(all(cmp$se_replicate >= 0, na.rm = TRUE))
})

test_that("CV-10: compare_variance returns 1 row for ungrouped estimate", {
  set.seed(1)
  design <- make_cv_design()
  est    <- suppressWarnings(estimate_catch_rate(design))
  cmp    <- suppressWarnings(compare_variance(est))
  expect_equal(nrow(cmp), 1L)
})

test_that("CV-11: compare_variance divergence_threshold attribute stored", {
  set.seed(1)
  design <- make_cv_design()
  est    <- suppressWarnings(estimate_catch_rate(design))
  cmp    <- suppressWarnings(compare_variance(est, divergence_threshold = 0.05))
  expect_equal(attr(cmp, "divergence_threshold"), 0.05)
})

test_that("CV-12: compare_variance errors on invalid divergence_threshold", {
  set.seed(1)
  design <- make_cv_design()
  est    <- suppressWarnings(estimate_catch_rate(design))
  expect_error(
    compare_variance(est, divergence_threshold = -0.1),
    regexp = "positive"
  )
  expect_error(
    compare_variance(est, divergence_threshold = "bad"),
    regexp = "positive"
  )
})
