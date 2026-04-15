# Test helpers ----

#' Create bus-route design with known harvest data for HT total-harvest tests
#'
#' Three sites A, B, C in circuit c1.
#' p_site: A=0.2, B=0.5, C=0.3; p_period=0.8 => pi_i: A=0.16, B=0.40, C=0.24
#' n_counted / n_interviewed => expansion: A=3, B=1, C=1
#' fish_kept per interview: A=2, 4; B=1, 0; C=3, 2
#' h_i = fish_kept * expansion: A=6,12; B=1,0; C=3,2
#' H_hat = sum(h_i/pi_i) = 6/0.16 + 12/0.16 + 1/0.40 + 0/0.40 + 3/0.24 + 2/0.24 = 135.833...
make_br_th_design <- function() {
  sf <- data.frame(
    site = c("A", "B", "C"),
    circuit = "c1",
    p_site = c(0.2, 0.5, 0.3),
    p_period = 0.8,
    stringsAsFactors = FALSE
  )
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
    day_type = "weekday",
    stringsAsFactors = FALSE
  )
  creel_design( # nolint: object_usage_linter
    calendar = cal,
    date = date, # nolint: object_usage_linter
    strata = day_type, # nolint: object_usage_linter
    survey_type = "bus_route",
    sampling_frame = sf,
    site = site, # nolint: object_usage_linter
    circuit = circuit, # nolint: object_usage_linter
    p_site = p_site, # nolint: object_usage_linter
    p_period = p_period # nolint: object_usage_linter
  )
}

make_br_th_interviews <- function(design) {
  interviews_df <- data.frame(
    date = as.Date(c(
      "2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04",
      "2024-06-01", "2024-06-02"
    )),
    site = c("A", "A", "B", "B", "C", "C"),
    circuit = "c1",
    n_counted = c(6L, 6L, 1L, 1L, 3L, 3L),
    n_interviewed = c(2L, 2L, 1L, 1L, 3L, 3L),
    hours_fished = c(2.0, 3.0, 1.5, 0.5, 2.0, 1.5),
    fish_kept = c(2L, 4L, 1L, 0L, 3L, 2L),
    fish_caught = c(3L, 5L, 2L, 1L, 4L, 3L),
    trip_status = rep("complete", 6),
    stringsAsFactors = FALSE
  )
  suppressWarnings(add_interviews( # nolint: object_usage_linter
    design,
    interviews_df,
    effort = hours_fished, # nolint: object_usage_linter
    catch = fish_caught, # nolint: object_usage_linter
    harvest = fish_kept, # nolint: object_usage_linter
    n_counted = n_counted, # nolint: object_usage_linter
    n_interviewed = n_interviewed, # nolint: object_usage_linter
    trip_status = trip_status # nolint: object_usage_linter
  ))
}

#' Create ice design with known harvest data
#'
#' 4 survey days; p_period=0.5; expansion = n_counted/n_interviewed
#' h_i = fish_kept * expansion: [0*5/3, 1*8/4, 0*10/5, 2*7/4]
#'                             = [0, 2, 0, 3.5]
#' pi_i = p_period = 0.5 for all rows
#' H_hat = sum(h_i/pi_i) = 0/0.5 + 2/0.5 + 0/0.5 + 3.5/0.5 = 11
make_ice_th_design <- function() {
  cal <- data.frame(
    date = as.Date(c("2024-01-10", "2024-01-11", "2024-01-12", "2024-01-13")),
    day_type = c("weekday", "weekday", "weekend", "weekend"),
    stringsAsFactors = FALSE
  )
  creel_design( # nolint: object_usage_linter
    cal,
    date = date, # nolint: object_usage_linter
    strata = day_type, # nolint: object_usage_linter
    survey_type = "ice",
    effort_type = "time_on_ice",
    p_period = 0.5
  )
}

make_ice_th_interviews <- function(design) {
  iw <- data.frame(
    date = as.Date(c("2024-01-10", "2024-01-11", "2024-01-12", "2024-01-13")),
    day_type = c("weekday", "weekday", "weekend", "weekend"),
    hours_fished = c(2.0, 1.5, 3.0, 2.5),
    catch_total = c(1L, 2L, 0L, 3L),
    fish_kept = c(0L, 1L, 0L, 2L),
    trip_status = rep("complete", 4),
    n_counted = c(5L, 8L, 10L, 7L),
    n_interviewed = c(3L, 4L, 5L, 4L),
    stringsAsFactors = FALSE
  )
  suppressWarnings(add_interviews( # nolint: object_usage_linter
    design,
    iw,
    effort = hours_fished, # nolint: object_usage_linter
    catch = catch_total, # nolint: object_usage_linter
    harvest = fish_kept, # nolint: object_usage_linter
    n_counted = n_counted, # nolint: object_usage_linter
    n_interviewed = n_interviewed, # nolint: object_usage_linter
    trip_status = trip_status # nolint: object_usage_linter
  ))
}

# Bus-route total harvest tests ----

test_that("estimate_total_harvest() dispatches bus_route to HT estimator", {
  d <- make_br_th_interviews(make_br_th_design())
  result <- estimate_total_harvest(d)
  expect_s3_class(result, "creel_estimates")
})

test_that("estimate_total_harvest() Eq. 19.5: H_hat = sum(h_i/pi_i) matches hand-computed value", {
  d <- make_br_th_interviews(make_br_th_design())
  result <- estimate_total_harvest(d)
  # H_hat = 6/0.16 + 12/0.16 + 1/0.40 + 0/0.40 + 3/0.24 + 2/0.24
  expected <- 6 / 0.16 + 12 / 0.16 + 1 / 0.40 + 0 / 0.40 + 3 / 0.24 + 2 / 0.24
  expect_equal(result$estimates$estimate, expected, tolerance = 1e-6)
})

test_that("estimate_total_harvest() bus_route result is finite and positive", {
  d <- make_br_th_interviews(make_br_th_design())
  result <- estimate_total_harvest(d)
  expect_true(is.finite(result$estimates$estimate))
  expect_true(result$estimates$estimate > 0)
  expect_true(is.finite(result$estimates$se))
  expect_true(result$estimates$se >= 0)
})

test_that("estimate_total_harvest() bus_route returns site_contributions attribute", {
  d <- make_br_th_interviews(make_br_th_design())
  result <- estimate_total_harvest(d)
  sc <- attr(result, "site_contributions")
  expect_false(is.null(sc))
  expect_true("h_i" %in% names(sc))
  expect_true("pi_i" %in% names(sc))
  expect_true("h_i_over_pi_i" %in% names(sc))
})

test_that("estimate_total_harvest() bus_route grouped by site: proportion column present", {
  d <- make_br_th_interviews(make_br_th_design())
  result <- suppressWarnings(estimate_total_harvest(d, by = site)) # nolint: object_usage_linter
  expect_true("proportion" %in% names(result$estimates))
  expect_equal(nrow(result$estimates), 3L)
})

test_that("estimate_total_harvest() bus_route grouped by circuit: proportions sum to 1", {
  d <- make_br_th_interviews(make_br_th_design())
  result <- estimate_total_harvest(d, by = circuit) # nolint: object_usage_linter
  expect_equal(sum(result$estimates$proportion), 1.0, tolerance = 1e-6)
})

# Ice total harvest tests ----

test_that("estimate_total_harvest() dispatches ice to HT estimator", {
  d <- make_ice_th_interviews(make_ice_th_design())
  result <- estimate_total_harvest(d)
  expect_s3_class(result, "creel_estimates")
})

test_that("estimate_total_harvest() ice: H_hat = sum(h_i/pi_i) matches hand-computed value", {
  d <- make_ice_th_interviews(make_ice_th_design())
  result <- estimate_total_harvest(d)
  # h_i = fish_kept * (n_counted/n_interviewed): 0*(5/3), 1*(8/4), 0*(10/5), 2*(7/4)
  # pi_i = 0.5 for all rows
  h_i <- c(0 * (5 / 3), 1 * (8 / 4), 0 * (10 / 5), 2 * (7 / 4))
  expected <- sum(h_i / 0.5)
  expect_equal(result$estimates$estimate, expected, tolerance = 1e-6)
})

test_that("estimate_total_harvest() ice result is finite and non-negative", {
  d <- make_ice_th_interviews(make_ice_th_design())
  result <- estimate_total_harvest(d)
  expect_true(is.finite(result$estimates$estimate))
  expect_true(result$estimates$estimate >= 0)
})
