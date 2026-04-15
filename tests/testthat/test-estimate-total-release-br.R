# Test helpers ----

#' Create bus-route design with release data for HT total-release tests
#'
#' Three sites A, B, C in circuit c1.
#' p_site: A=0.2, B=0.5, C=0.3; p_period=0.8 => pi_i: A=0.16, B=0.40, C=0.24
#' expansion: A=3, B=1, C=1
#' .release_count per interview: A=1, 1; B=1, 0; C=1, 1
#' r_i = .release_count * expansion: A=3,3; B=1,0; C=1,1
#' R_hat = sum(r_i/pi_i) = 3/0.16 + 3/0.16 + 1/0.40 + 0/0.40 + 1/0.24 + 1/0.24
make_br_tr_design <- function() {
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

make_br_tr_with_catch <- function(design) {
  interviews_df <- data.frame(
    interview_id = 1:6,
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
  d <- suppressWarnings(add_interviews( # nolint: object_usage_linter
    design,
    interviews_df,
    effort = hours_fished, # nolint: object_usage_linter
    catch = fish_caught, # nolint: object_usage_linter
    harvest = fish_kept, # nolint: object_usage_linter
    n_counted = n_counted, # nolint: object_usage_linter
    n_interviewed = n_interviewed, # nolint: object_usage_linter
    trip_status = trip_status # nolint: object_usage_linter
  ))

  # Release records: interviews 1,2,3,5,6 each release 1 fish
  catch_df <- data.frame(
    interview_id = c(1L, 2L, 3L, 5L, 6L),
    species = "walleye",
    count = c(1L, 1L, 1L, 1L, 1L),
    catch_type = "released",
    stringsAsFactors = FALSE
  )
  suppressWarnings(add_catch( # nolint: object_usage_linter
    d,
    catch_df,
    catch_uid = interview_id, # nolint: object_usage_linter
    interview_uid = interview_id, # nolint: object_usage_linter
    species = species, # nolint: object_usage_linter
    count = count, # nolint: object_usage_linter
    catch_type = catch_type # nolint: object_usage_linter
  ))
}

#' Create ice design with release data
make_ice_tr_design <- function() {
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

make_ice_tr_with_catch <- function(design) {
  iw <- data.frame(
    interview_id = 1:4,
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
  d <- suppressWarnings(add_interviews( # nolint: object_usage_linter
    design,
    iw,
    effort = hours_fished, # nolint: object_usage_linter
    catch = catch_total, # nolint: object_usage_linter
    harvest = fish_kept, # nolint: object_usage_linter
    n_counted = n_counted, # nolint: object_usage_linter
    n_interviewed = n_interviewed, # nolint: object_usage_linter
    trip_status = trip_status # nolint: object_usage_linter
  ))

  # Release records: interviews 2 and 4 each release 1 fish
  catch_df <- data.frame(
    interview_id = c(2L, 4L),
    species = "walleye",
    count = c(1L, 1L),
    catch_type = "released",
    stringsAsFactors = FALSE
  )
  suppressWarnings(add_catch( # nolint: object_usage_linter
    d,
    catch_df,
    catch_uid = interview_id, # nolint: object_usage_linter
    interview_uid = interview_id, # nolint: object_usage_linter
    species = species, # nolint: object_usage_linter
    count = count, # nolint: object_usage_linter
    catch_type = catch_type # nolint: object_usage_linter
  ))
}

# Bus-route total release tests ----

test_that("estimate_total_release() dispatches bus_route to HT estimator", {
  d <- make_br_tr_with_catch(make_br_tr_design())
  result <- estimate_total_release(d)
  expect_s3_class(result, "creel_estimates")
})

test_that("estimate_total_release() bus_route: R_hat = sum(r_i/pi_i) matches hand-computed value", {
  d <- make_br_tr_with_catch(make_br_tr_design())
  result <- estimate_total_release(d)
  # .release_count: interviews 1,2,3,4,5,6 => counts 1,1,1,0,1,1
  # expansion: A=3,3; B=1,1; C=1,1
  # r_i = release_count * expansion: A=3,3; B=1,0; C=1,1
  # pi_i: A=0.16, B=0.40, C=0.24
  # R_hat = 3/0.16 + 3/0.16 + 1/0.40 + 0/0.40 + 1/0.24 + 1/0.24
  expected <- 3 / 0.16 + 3 / 0.16 + 1 / 0.40 + 0 / 0.40 + 1 / 0.24 + 1 / 0.24
  expect_equal(result$estimates$estimate, expected, tolerance = 1e-6)
})

test_that("estimate_total_release() bus_route result is finite and non-negative", {
  d <- make_br_tr_with_catch(make_br_tr_design())
  result <- estimate_total_release(d)
  expect_true(is.finite(result$estimates$estimate))
  expect_true(result$estimates$estimate >= 0)
  expect_true(is.finite(result$estimates$se))
  expect_true(result$estimates$se >= 0)
})

test_that("estimate_total_release() bus_route returns site_contributions attribute", {
  d <- make_br_tr_with_catch(make_br_tr_design())
  result <- estimate_total_release(d)
  sc <- attr(result, "site_contributions")
  expect_false(is.null(sc))
  expect_true("r_i" %in% names(sc))
  expect_true("pi_i" %in% names(sc))
  expect_true("r_i_over_pi_i" %in% names(sc))
})

test_that("estimate_total_release() bus_route grouped by circuit: proportions sum to 1", {
  d <- make_br_tr_with_catch(make_br_tr_design())
  result <- estimate_total_release(d, by = circuit) # nolint: object_usage_linter
  expect_equal(sum(result$estimates$proportion), 1.0, tolerance = 1e-6)
})

test_that("estimate_total_release() bus_route: zero releases when no catch data releases", {
  # Design with no released records
  d_base <- make_br_tr_design()
  interviews_df <- data.frame(
    interview_id = 1:6,
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
  d <- suppressWarnings(add_interviews(
    d_base, interviews_df,
    effort = hours_fished, # nolint: object_usage_linter
    catch = fish_caught, # nolint: object_usage_linter
    harvest = fish_kept, # nolint: object_usage_linter
    n_counted = n_counted, # nolint: object_usage_linter
    n_interviewed = n_interviewed, # nolint: object_usage_linter
    trip_status = trip_status # nolint: object_usage_linter
  ))
  # No releases in catch data — all records are harvested
  catch_df <- data.frame(
    interview_id = 1:6,
    species = "walleye",
    count = c(2L, 4L, 1L, 0L, 3L, 2L),
    catch_type = "harvested",
    stringsAsFactors = FALSE
  )
  d <- suppressWarnings(add_catch(
    d, catch_df,
    catch_uid = interview_id, # nolint: object_usage_linter
    interview_uid = interview_id, # nolint: object_usage_linter
    species = species, # nolint: object_usage_linter
    count = count, # nolint: object_usage_linter
    catch_type = catch_type # nolint: object_usage_linter
  ))
  result <- estimate_total_release(d)
  expect_equal(result$estimates$estimate, 0, tolerance = 1e-9)
})

# Ice total release tests ----

test_that("estimate_total_release() dispatches ice to HT estimator", {
  d <- make_ice_tr_with_catch(make_ice_tr_design())
  result <- estimate_total_release(d)
  expect_s3_class(result, "creel_estimates")
})

test_that("estimate_total_release() ice: R_hat = sum(r_i/pi_i) matches hand-computed value", {
  d <- make_ice_tr_with_catch(make_ice_tr_design())
  result <- estimate_total_release(d)
  # .release_count per interview: 0, 1, 0, 1
  # expansion = n_counted/n_interviewed: 5/3, 8/4=2, 10/5=2, 7/4=1.75
  # r_i = release_count * expansion: 0, 2, 0, 1.75
  # pi_i = 0.5
  # R_hat = 0/0.5 + 2/0.5 + 0/0.5 + 1.75/0.5
  r_i <- c(0, 1 * 2, 0, 1 * 1.75)
  expected <- sum(r_i / 0.5)
  expect_equal(result$estimates$estimate, expected, tolerance = 1e-6)
})

test_that("estimate_total_release() ice result is finite and non-negative", {
  d <- make_ice_tr_with_catch(make_ice_tr_design())
  result <- estimate_total_release(d)
  expect_true(is.finite(result$estimates$estimate))
  expect_true(result$estimates$estimate >= 0)
})
