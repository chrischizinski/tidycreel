# Tests for compare_designs() ----

# Helpers: minimal creel_estimates objects ------------------------------------
make_est <- function(estimate, se, label = "test") {
  est_df <- data.frame(
    estimate = estimate,
    se       = se,
    ci_lower = estimate - 1.96 * se,
    ci_upper = estimate + 1.96 * se,
    n        = 10L,
    stringsAsFactors = FALSE
  )
  structure(
    list(
      estimates       = est_df,
      method          = label,
      variance_method = "taylor",
      design          = NULL,
      conf_level      = 0.95,
      by_vars         = NULL
    ),
    class = "creel_estimates"
  )
}

make_est_grouped <- function() {
  est_df <- data.frame(
    day_type = c("weekday", "weekend"),
    estimate = c(100, 200),
    se       = c(10, 20),
    ci_lower = c(80, 161),
    ci_upper = c(120, 239),
    n        = c(5L, 5L),
    stringsAsFactors = FALSE
  )
  structure(
    list(
      estimates       = est_df,
      method          = "grouped",
      variance_method = "taylor",
      design          = NULL,
      conf_level      = 0.95,
      by_vars         = "day_type"
    ),
    class = "creel_estimates"
  )
}

# Input validation ------------------------------------------------------------

test_that("CMPD-01: errors when designs is not a list", {
  est <- make_est(100, 10)
  expect_error(compare_designs(est), class = "rlang_error")
})

test_that("CMPD-02: errors when fewer than two designs", {
  expect_error(
    compare_designs(list(a = make_est(100, 10))),
    class = "rlang_error"
  )
})

test_that("CMPD-03: errors when list is unnamed", {
  expect_error(
    compare_designs(list(make_est(100, 10), make_est(200, 20))),
    class = "rlang_error"
  )
})

test_that("CMPD-04: errors when element is not creel_estimates", {
  expect_error(
    compare_designs(list(a = make_est(100, 10), b = list(x = 1))),
    class = "rlang_error"
  )
})

test_that("CMPD-05: errors when metric column missing in one design", {
  expect_error(
    compare_designs(
      list(a = make_est(100, 10), b = make_est(200, 20)),
      metric = "nonexistent"
    ),
    class = "rlang_error"
  )
})

# Return structure ------------------------------------------------------------

test_that("CMPD-06: returns creel_design_comparison", {
  res <- compare_designs(list(
    design_a = make_est(100, 10),
    design_b = make_est(200, 20)
  ))
  expect_s3_class(res, "creel_design_comparison")
  expect_s3_class(res, "data.frame")
})

test_that("CMPD-07: has expected core columns", {
  res <- compare_designs(list(
    a = make_est(100, 10),
    b = make_est(200, 20)
  ))
  expect_true(all(c("design", "estimate", "se", "rse",
    "ci_lower", "ci_upper", "ci_width", "n") %in% names(res)))
})

test_that("CMPD-08: design column matches input names", {
  res <- compare_designs(list(
    instant  = make_est(100, 10),
    busroute = make_est(200, 20)
  ))
  expect_setequal(res$design, c("instant", "busroute"))
})

test_that("CMPD-09: correct number of rows (one per design x strata)", {
  res <- compare_designs(list(
    a = make_est(100, 10),
    b = make_est(200, 20)
  ))
  expect_equal(nrow(res), 2L)
})

# Numeric correctness ---------------------------------------------------------

test_that("CMPD-10: estimate column matches input", {
  res <- compare_designs(list(
    a = make_est(150, 15),
    b = make_est(300, 30)
  ))
  expect_equal(sort(res$estimate), c(150, 300))
})

test_that("CMPD-11: rse = se / |estimate|", {
  res <- compare_designs(list(
    a = make_est(100, 10),
    b = make_est(200, 20)
  ))
  expect_equal(res$rse[res$design == "a"], 10 / 100, tolerance = 1e-6)
  expect_equal(res$rse[res$design == "b"], 20 / 200, tolerance = 1e-6)
})

test_that("CMPD-12: ci_width = ci_upper - ci_lower", {
  res <- compare_designs(list(
    a = make_est(100, 10),
    b = make_est(200, 20)
  ))
  expect_equal(
    res$ci_width,
    res$ci_upper - res$ci_lower,
    tolerance = 1e-9
  )
})

# Grouped estimates -----------------------------------------------------------

test_that("CMPD-13: grouped estimates expand correctly", {
  res <- compare_designs(list(
    grouped = make_est_grouped(),
    single  = make_est(150, 15)
  ))
  # grouped has 2 rows, single has 1 -> total 3
  expect_equal(nrow(res), 3L)
})

test_that("CMPD-14: group columns retained", {
  res <- compare_designs(list(
    grp = make_est_grouped(),
    b   = make_est(150, 15)
  ))
  expect_true("day_type" %in% names(res))
})

# autoplot --------------------------------------------------------------------

test_that("CMPD-15: autoplot returns ggplot", {
  res <- compare_designs(list(
    a = make_est(100, 10),
    b = make_est(200, 20)
  ))
  p <- autoplot(res)
  expect_s3_class(p, "ggplot")
})

test_that("CMPD-16: autoplot title arg overrides default", {
  res <- compare_designs(list(
    a = make_est(100, 10),
    b = make_est(200, 20)
  ))
  p <- autoplot(res, title = "My Plot")
  expect_equal(p$labels$title, "My Plot")
})

test_that("CMPD-17: autoplot includes error bars when CI present", {
  res <- compare_designs(list(
    a = make_est(100, 10),
    b = make_est(200, 20)
  ))
  p <- autoplot(res)
  layer_classes <- vapply(p$layers, function(l) {
    class(l$geom)[1]
  }, character(1))
  expect_true(any(grepl("errorbar", layer_classes, ignore.case = TRUE)))
})

# print and as.data.frame -----------------------------------------------------

test_that("CMPD-18: print returns x invisibly", {
  res <- compare_designs(list(
    a = make_est(100, 10),
    b = make_est(200, 20)
  ))
  returned <- suppressMessages(print(res))
  expect_identical(returned, res)
})

test_that("CMPD-19: as.data.frame strips class", {
  res   <- compare_designs(list(a = make_est(100, 10), b = make_est(200, 20)))
  plain <- as.data.frame(res)
  expect_false(inherits(plain, "creel_design_comparison"))
  expect_s3_class(plain, "data.frame")
})

# Edge case: estimates with no SE ---------------------------------------------

test_that("CMPD-20: handles missing SE gracefully (NA rse)", {
  est_no_se <- structure(
    list(
      estimates = data.frame(estimate = 100, stringsAsFactors = FALSE),
      method = "test", variance_method = "none",
      design = NULL, conf_level = 0.95, by_vars = NULL
    ),
    class = "creel_estimates"
  )
  res <- compare_designs(list(a = est_no_se, b = est_no_se))
  expect_true(all(is.na(res$se)))
  expect_true(all(is.na(res$rse)))
})
