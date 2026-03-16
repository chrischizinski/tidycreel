# Test helpers ----

#' Create test design with BOTH counts and interviews (for total catch)
make_total_catch_design <- function() {
  # Use example data
  data("example_calendar", package = "tidycreel")
  data("example_counts", package = "tidycreel")
  data("example_interviews", package = "tidycreel")

  # Create design with both data sources
  design <- creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  design <- add_counts(design, example_counts) # nolint: object_usage_linter
  design <- add_interviews(design, example_interviews, # nolint: object_usage_linter
    catch = catch_total, # nolint: object_usage_linter
    effort = hours_fished, # nolint: object_usage_linter
    trip_status = trip_status, # nolint: object_usage_linter
    trip_duration = trip_duration # nolint: object_usage_linter
  )

  design
}

#' Create test design with counts only (no interviews)
make_counts_only_design <- function() {
  data("example_calendar", package = "tidycreel")
  data("example_counts", package = "tidycreel")

  design <- creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  design <- add_counts(design, example_counts) # nolint: object_usage_linter

  design
}

#' Create test design with interviews only (no counts)
make_interviews_only_design <- function() {
  data("example_calendar", package = "tidycreel")
  data("example_interviews", package = "tidycreel")

  design <- creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  design <- add_interviews(design, example_interviews, # nolint: object_usage_linter
    catch = catch_total, # nolint: object_usage_linter
    effort = hours_fished, # nolint: object_usage_linter
    trip_status = trip_status, # nolint: object_usage_linter
    trip_duration = trip_duration # nolint: object_usage_linter
  )

  design
}

# Basic behavior tests ----

test_that("estimate_total_catch returns creel_estimates class object", {
  design <- make_total_catch_design()

  result <- estimate_total_catch(design) # nolint: object_usage_linter

  expect_s3_class(result, "creel_estimates")
})

test_that("estimate_total_catch result has estimates tibble with correct columns", {
  design <- make_total_catch_design()

  result <- estimate_total_catch(design) # nolint: object_usage_linter

  expect_true(!is.null(result$estimates))
  expect_true(is.data.frame(result$estimates))
  expect_true("estimate" %in% names(result$estimates))
  expect_true("se" %in% names(result$estimates))
  expect_true("ci_lower" %in% names(result$estimates))
  expect_true("ci_upper" %in% names(result$estimates))
  expect_true("n" %in% names(result$estimates))
})

test_that("estimate_total_catch result method is 'product-total-catch'", {
  design <- make_total_catch_design()

  result <- estimate_total_catch(design) # nolint: object_usage_linter

  expect_equal(result$method, "product-total-catch")
})

test_that("estimate_total_catch result variance_method is 'taylor' by default", {
  design <- make_total_catch_design()

  result <- estimate_total_catch(design) # nolint: object_usage_linter

  expect_equal(result$variance_method, "taylor")
})

test_that("estimate_total_catch result conf_level is 0.95 by default", {
  design <- make_total_catch_design()

  result <- estimate_total_catch(design) # nolint: object_usage_linter

  expect_equal(result$conf_level, 0.95)
})

test_that("estimate_total_catch estimate is a positive numeric value", {
  design <- make_total_catch_design()

  result <- estimate_total_catch(design) # nolint: object_usage_linter

  expect_true(is.numeric(result$estimates$estimate))
  expect_true(result$estimates$estimate >= 0)
})

# Input validation tests ----

test_that("estimate_total_catch errors when design is not creel_design", {
  fake_design <- "not a design"

  expect_error(
    estimate_total_catch(fake_design), # nolint: object_usage_linter
    "creel_design"
  )
})

test_that("estimate_total_catch errors when design has no counts", {
  design <- make_interviews_only_design()

  expect_error(
    estimate_total_catch(design), # nolint: object_usage_linter
    "add_counts"
  )
})

test_that("estimate_total_catch errors when design has no interviews", {
  design <- make_counts_only_design()

  expect_error(
    estimate_total_catch(design), # nolint: object_usage_linter
    "add_interviews"
  )
})

test_that("estimate_total_catch errors for invalid variance method", {
  design <- make_total_catch_design()

  expect_error(
    estimate_total_catch(design, variance = "invalid_method"), # nolint: object_usage_linter
    "Invalid variance method"
  )
})

# Delta method correctness - Reference tests ----

test_that("total catch estimate equals effort * cpue exactly", {
  design <- make_total_catch_design()

  # Get total catch estimate
  result <- estimate_total_catch(design) # nolint: object_usage_linter

  # Get component estimates
  effort <- estimate_effort(design) # nolint: object_usage_linter
  cpue <- estimate_catch_rate(design) # nolint: object_usage_linter

  # Product should match exactly
  expected <- effort$estimates$estimate * cpue$estimates$estimate

  expect_equal(result$estimates$estimate, expected, tolerance = 1e-10)
})

test_that("total catch SE matches manual delta method formula", {
  design <- make_total_catch_design()

  # Get total catch estimate
  result <- estimate_total_catch(design) # nolint: object_usage_linter

  # Get component estimates
  effort <- estimate_effort(design) # nolint: object_usage_linter
  cpue <- estimate_catch_rate(design) # nolint: object_usage_linter

  # Extract components
  effort_est <- effort$estimates$estimate # nolint: object_name_linter
  cpue_est <- cpue$estimates$estimate # nolint: object_name_linter
  var_effort <- effort$estimates$se^2 # nolint: object_name_linter
  var_cpue <- cpue$estimates$se^2 # nolint: object_name_linter

  # Manual delta method (first-order approximation)
  manual_variance <- (effort_est^2 * var_cpue) + (cpue_est^2 * var_effort)
  manual_se <- sqrt(manual_variance)

  # Allow slightly looser tolerance for SE since svycontrast may include second-order term
  expect_equal(result$estimates$se, manual_se, tolerance = 1e-6)
})

test_that("total catch CI is finite and contains estimate", {
  design <- make_total_catch_design()

  result <- estimate_total_catch(design) # nolint: object_usage_linter

  expect_true(is.finite(result$estimates$ci_lower))
  expect_true(is.finite(result$estimates$ci_upper))
  expect_true(result$estimates$ci_lower < result$estimates$estimate)
  expect_true(result$estimates$estimate < result$estimates$ci_upper)
})

# Grouped estimation tests ----

# Create synthetic data helper with larger sample sizes for grouped testing
make_grouped_test_design <- function() {
  # Create synthetic calendar with balanced groups (30 days each)
  dates <- seq.Date(as.Date("2024-01-01"), by = "day", length.out = 60)
  calendar <- data.frame(
    date = dates,
    day_type = rep(c("weekday", "weekend"), each = 30)
  )

  # Create synthetic counts (2 per day = 120 total) with day_type
  counts <- data.frame(
    date = rep(dates, each = 2),
    day_type = rep(rep(c("weekday", "weekend"), each = 30), each = 2),
    time = rep(c("AM", "PM"), 60),
    count = rpois(120, lambda = 15)
  )

  # Create synthetic interviews with adequate samples per group
  # Need >=10 COMPLETE trips per group (new default behavior filters to complete)
  # Create 40 interviews total: 20 per group, with 10 complete + 10 incomplete each
  interviews <- data.frame(
    date = c(
      sample(dates[1:30], 20, replace = TRUE), # weekday
      sample(dates[31:60], 20, replace = TRUE) # weekend
    ),
    day_type = rep(c("weekday", "weekend"), each = 20),
    catch_total = rpois(40, lambda = 3),
    hours_fished = runif(40, min = 1, max = 8),
    trip_status = rep(c("complete", "incomplete"), 20), # 10 complete, 10 incomplete per group
    trip_duration = runif(40, min = 1, max = 8)
  )

  # Create design
  design <- creel_design(calendar, date = date, strata = day_type) # nolint: object_usage_linter
  design <- add_counts(design, counts) # nolint: object_usage_linter
  design <- add_interviews(design, interviews, # nolint: object_usage_linter
    catch = catch_total, # nolint: object_usage_linter
    effort = hours_fished, # nolint: object_usage_linter
    trip_status = trip_status, # nolint: object_usage_linter
    trip_duration = trip_duration # nolint: object_usage_linter
  )

  design
}

test_that("estimate_total_catch grouped by day_type returns creel_estimates with by_vars set", {
  design <- make_grouped_test_design()

  result <- suppressWarnings(estimate_total_catch(design, by = day_type)) # nolint: object_usage_linter

  expect_s3_class(result, "creel_estimates")
  expect_true(!is.null(result$by_vars))
  expect_equal(result$by_vars, "day_type")
})

test_that("estimate_total_catch grouped result has day_type column", {
  design <- make_grouped_test_design()

  result <- suppressWarnings(estimate_total_catch(design, by = day_type)) # nolint: object_usage_linter

  expect_true("day_type" %in% names(result$estimates))
})

test_that("estimate_total_catch grouped result has one row per group level", {
  design <- make_grouped_test_design()

  result <- suppressWarnings(estimate_total_catch(design, by = day_type)) # nolint: object_usage_linter

  # Should have weekday and weekend
  expect_equal(nrow(result$estimates), 2)
  expect_true("weekday" %in% result$estimates$day_type)
  expect_true("weekend" %in% result$estimates$day_type)
})

test_that("estimate_total_catch grouped result n reflects per-group interview sample sizes", {
  design <- make_grouped_test_design()

  result <- suppressWarnings(estimate_total_catch(design, by = day_type)) # nolint: object_usage_linter

  expect_true("n" %in% names(result$estimates))
  # After Phase 17, defaults to complete trips only
  n_complete <- sum(design$interviews$trip_status == "complete")
  expect_equal(sum(result$estimates$n), n_complete)
  expect_true(all(result$estimates$n > 0))
})

# Grouping validation tests ----

test_that("estimate_total_catch errors when grouping variable missing from count data", {
  design <- make_total_catch_design()

  # Add a column to interviews that doesn't exist in counts
  design$interviews$species <- rep("bass", nrow(design$interviews))

  expect_error(
    estimate_total_catch(design, by = species), # nolint: object_usage_linter
    "species"
  )
})

test_that("estimate_total_catch errors when grouping variable missing from interview data", {
  design <- make_total_catch_design()

  # Add a column to counts that doesn't exist in interviews
  design$counts$location <- rep("north", nrow(design$counts))

  expect_error(
    estimate_total_catch(design, by = location), # nolint: object_usage_linter
    "location"
  )
})

# Custom confidence level test ----

test_that("estimate_total_catch with conf_level = 0.90 produces narrower CI than 0.95", {
  design <- make_total_catch_design()

  result_95 <- estimate_total_catch(design, conf_level = 0.95) # nolint: object_usage_linter
  result_90 <- estimate_total_catch(design, conf_level = 0.90) # nolint: object_usage_linter

  # CI width should be narrower for 90% than 95%
  width_95 <- result_95$estimates$ci_upper - result_95$estimates$ci_lower
  width_90 <- result_90$estimates$ci_upper - result_90$estimates$ci_lower

  expect_true(width_90 < width_95)
  expect_equal(result_90$conf_level, 0.90)
})

# Variance method tests ----

test_that("estimate_total_catch with bootstrap variance returns correct method", {
  design <- make_total_catch_design()

  result <- estimate_total_catch(design, variance = "bootstrap") # nolint: object_usage_linter

  expect_equal(result$variance_method, "bootstrap")
  expect_true(is.finite(result$estimates$estimate))
  expect_true(result$estimates$estimate > 0)
  expect_true(is.finite(result$estimates$se))
  expect_true(result$estimates$se > 0)
})

test_that("estimate_total_catch with jackknife variance returns correct method", {
  design <- make_total_catch_design()

  result <- estimate_total_catch(design, variance = "jackknife") # nolint: object_usage_linter

  expect_equal(result$variance_method, "jackknife")
  expect_true(is.finite(result$estimates$estimate))
  expect_true(result$estimates$estimate > 0)
  expect_true(is.finite(result$estimates$se))
  expect_true(result$estimates$se > 0)
})

test_that("estimate_total_catch grouped with bootstrap works", {
  design <- make_grouped_test_design()

  result <- suppressWarnings(estimate_total_catch(design, by = day_type, variance = "bootstrap")) # nolint: object_usage_linter

  expect_s3_class(result, "creel_estimates")
  expect_equal(result$variance_method, "bootstrap")
  expect_true(!is.null(result$by_vars))
  expect_true(all(is.finite(result$estimates$estimate)))
  expect_true(all(result$estimates$estimate > 0))
  expect_true(all(is.finite(result$estimates$se)))
  expect_true(all(result$estimates$se > 0))
})

# Integration with example data ----

test_that("full workflow with example data produces valid result", {
  # Load example data
  data("example_calendar", package = "tidycreel")
  data("example_counts", package = "tidycreel")
  data("example_interviews", package = "tidycreel")

  # Create complete design
  design <- creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  design <- add_counts(design, example_counts) # nolint: object_usage_linter
  design <- add_interviews(design, example_interviews, # nolint: object_usage_linter
    catch = catch_total, # nolint: object_usage_linter
    effort = hours_fished, # nolint: object_usage_linter
    trip_status = trip_status, # nolint: object_usage_linter
    trip_duration = trip_duration # nolint: object_usage_linter
  )

  # Estimate total catch
  result <- estimate_total_catch(design) # nolint: object_usage_linter

  # Verify result structure and validity
  expect_s3_class(result, "creel_estimates")
  expect_true(is.numeric(result$estimates$estimate))
  expect_true(result$estimates$estimate > 0)
  expect_true(is.finite(result$estimates$estimate))
  expect_true(is.numeric(result$estimates$se))
  expect_true(result$estimates$se > 0)
  expect_true(is.finite(result$estimates$se))
})

test_that("total catch components are consistent", {
  design <- make_total_catch_design()

  # Estimate all components
  effort_est <- estimate_effort(design) # nolint: object_usage_linter
  cpue_est <- estimate_catch_rate(design) # nolint: object_usage_linter
  total_catch_est <- estimate_total_catch(design) # nolint: object_usage_linter

  # Verify estimate consistency (product of components)
  expected_estimate <- effort_est$estimates$estimate * cpue_est$estimates$estimate
  expect_equal(total_catch_est$estimates$estimate, expected_estimate, tolerance = 1e-10)

  # Verify variance was propagated (SE should not be zero)
  expect_true(total_catch_est$estimates$se > 0)
})

test_that("total harvest <= total catch for same design", {
  # Load example data
  data("example_calendar", package = "tidycreel")
  data("example_counts", package = "tidycreel")
  data("example_interviews", package = "tidycreel")

  # Create complete design including harvest
  design <- creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  design <- add_counts(design, example_counts) # nolint: object_usage_linter
  design <- add_interviews(design, example_interviews, # nolint: object_usage_linter
    catch = catch_total, # nolint: object_usage_linter
    harvest = catch_kept, # nolint: object_usage_linter
    effort = hours_fished, # nolint: object_usage_linter
    trip_status = trip_status, # nolint: object_usage_linter
    trip_duration = trip_duration # nolint: object_usage_linter
  )

  # Estimate both
  total_catch <- estimate_total_catch(design) # nolint: object_usage_linter
  total_harvest <- estimate_total_harvest(design) # nolint: object_usage_linter

  # Verify biological constraint
  expect_true(total_harvest$estimates$estimate <= total_catch$estimates$estimate)
})

# Bus-route total-catch estimation ----
# Helpers defined at section scope per Phase 21-02 / Phase 22-02 convention

make_br_catch_design <- function() {
  # Three sites A, B, C; one circuit c1 (same structure as harvest section)
  # p_site: A=0.2, B=0.5, C=0.3 (sums to 1.0)
  # p_period: 0.8 for all sites in circuit c1
  # pi_i = p_site * p_period: A=0.16, B=0.40, C=0.24
  sf <- data.frame(
    site = c("A", "B", "C"),
    circuit = "c1",
    p_site = c(0.2, 0.5, 0.3),
    p_period = 0.8
  )
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
    day_type = "weekday"
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

make_br_catch_interviews <- function(design) {
  # Site A: 2 interviews (dates 01, 02), n_counted=6, n_interviewed=2 — expansion=3
  # Site B: 2 interviews (dates 03, 04), n_counted=1, n_interviewed=1 — expansion=1
  # Site C: 2 interviews (dates 01, 02), n_counted=3, n_interviewed=3 — expansion=1
  # catch per interview: A=3, A=5, B=2, B=1, C=4, C=3
  # c_i (catch * expansion): A=9, A=15, B=2, B=1, C=4, C=3
  # pi_i: A=0.16, A=0.16, B=0.40, B=0.40, C=0.24, C=0.24
  # c_i/pi_i: A=56.25, A=93.75, B=5.0, B=2.5, C=16.67, C=12.5 — C_hat > 0
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
    fish_caught = c(3L, 5L, 2L, 1L, 4L, 3L),
    fish_kept = c(2L, 4L, 1L, 0L, 3L, 2L),
    trip_status = rep("complete", 6)
  )
  add_interviews( # nolint: object_usage_linter
    design,
    interviews_df,
    effort = hours_fished, # nolint: object_usage_linter
    catch = fish_caught, # nolint: object_usage_linter
    harvest = fish_kept, # nolint: object_usage_linter
    n_counted = n_counted, # nolint: object_usage_linter
    n_interviewed = n_interviewed, # nolint: object_usage_linter
    trip_status = trip_status # nolint: object_usage_linter
  )
}

test_that("estimate_total_catch() dispatches to bus-route estimator for bus_route designs", {
  d <- make_br_catch_interviews(make_br_catch_design())
  result <- estimate_total_catch(d)
  expect_s3_class(result, "creel_estimates")
})

test_that("estimate_total_catch() Eq. 19.5: C_hat = sum(c_i/pi_i) is positive for bus-route", {
  d <- make_br_catch_interviews(make_br_catch_design())
  result <- estimate_total_catch(d)
  expect_true(result$estimates$estimate > 0)
})

test_that("estimate_total_catch() site_contributions attribute present for bus-route", {
  d <- make_br_catch_interviews(make_br_catch_design())
  result <- estimate_total_catch(d)
  sc <- attr(result, "site_contributions")
  expect_false(is.null(sc))
})

test_that("get_site_contributions() works on bus-route total-catch result", {
  d <- make_br_catch_interviews(make_br_catch_design())
  result <- estimate_total_catch(d)
  sc <- get_site_contributions(result)
  expect_s3_class(sc, "tbl_df")
  expect_true("pi_i" %in% names(sc))
})

test_that("estimate_total_catch() verbose=TRUE prints bus-route dispatch message", {
  d <- make_br_catch_interviews(make_br_catch_design())
  expect_message(
    estimate_total_catch(d, verbose = TRUE),
    "bus-route estimator"
  )
})

test_that("estimate_total_catch() verbose=FALSE produces no dispatch message", {
  d <- make_br_catch_interviews(make_br_catch_design())
  expect_no_message(suppressWarnings(estimate_total_catch(d, verbose = FALSE)))
})

# Section dispatch fixtures and stubs (PROD-01, PROD-02) ----

#' Create 3-section creel_design for total catch section tests
#'
#' Produces a creel_design with sections "North", "Central", "South" and
#' both counts and interview data for all three sections. 12-date calendar,
#' 9 interviews per section. Fixture name is explicit about purpose
#' (total catch context). Data shape is identical to the Phase 40 fixture
#' make_3section_design_with_interviews().
make_3section_total_catch_design <- function() { # nolint: object_length_linter
  cal <- data.frame(
    date = as.Date(c(
      "2024-06-03", "2024-06-04", "2024-06-05", "2024-06-06",
      "2024-06-07", "2024-06-10",
      "2024-06-08", "2024-06-09", "2024-06-14", "2024-06-15",
      "2024-06-16", "2024-06-21"
    )),
    day_type = c(
      "weekday", "weekday", "weekday", "weekday", "weekday", "weekday",
      "weekend", "weekend", "weekend", "weekend", "weekend", "weekend"
    ),
    stringsAsFactors = FALSE
  )
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter

  sections_df <- data.frame(
    section = c("North", "Central", "South"),
    stringsAsFactors = FALSE
  )
  design <- add_sections(design, sections_df, section_col = section) # nolint: object_usage_linter

  # 36-row counts: each of the 12 dates repeated for each of 3 sections
  counts <- data.frame(
    date = rep(cal$date, times = 3),
    day_type = rep(cal$day_type, times = 3),
    section = rep(c("North", "Central", "South"), each = nrow(cal)),
    effort_hours = c(
      # North: weekday ~15-25, weekend ~20-28
      20, 22, 18, 25, 15, 24,
      21, 26, 23, 28, 20, 27,
      # Central: weekday ~30-45, weekend ~35-48
      35, 38, 32, 42, 30, 45,
      37, 44, 40, 48, 35, 46,
      # South: weekday ~5-12, weekend ~6-13
      8, 10, 5, 12, 6, 11,
      7, 9, 6, 13, 8, 10
    ),
    stringsAsFactors = FALSE
  )
  design <- suppressWarnings(add_counts(design, counts)) # nolint: object_usage_linter

  # 27 interviews: 9 per section, varying catch/effort across sections
  interviews <- data.frame(
    date = as.Date(c(
      # North (9 interviews)
      "2024-06-03", "2024-06-04", "2024-06-05",
      "2024-06-07", "2024-06-10", "2024-06-07",
      "2024-06-08", "2024-06-09", "2024-06-14",
      # Central (9 interviews)
      "2024-06-03", "2024-06-04", "2024-06-05",
      "2024-06-06", "2024-06-10", "2024-06-10",
      "2024-06-08", "2024-06-09", "2024-06-21",
      # South (9 interviews)
      "2024-06-03", "2024-06-04", "2024-06-05",
      "2024-06-06", "2024-06-07", "2024-06-07",
      "2024-06-08", "2024-06-09", "2024-06-14"
    )),
    day_type = c(
      "weekday", "weekday", "weekday", "weekday", "weekday", "weekday",
      "weekend", "weekend", "weekend",
      "weekday", "weekday", "weekday", "weekday", "weekday", "weekday",
      "weekend", "weekend", "weekend",
      "weekday", "weekday", "weekday", "weekday", "weekday", "weekday",
      "weekend", "weekend", "weekend"
    ),
    section = rep(c("North", "Central", "South"), each = 9),
    catch_total = c(
      # North: ~1 fish/hr
      2, 3, 2, 4, 3, 2, 3, 4, 3,
      # Central: ~1.5 fish/hr
      5, 6, 5, 7, 6, 5, 7, 8, 6,
      # South: ~2.5 fish/hr
      10, 12, 9, 11, 10, 12, 13, 11, 10
    ),
    hours_fished = c(
      # North: 2-3 hrs
      2.0, 3.0, 2.5, 3.0, 2.0, 2.5, 3.0, 3.5, 3.0,
      # Central: 3-4 hrs
      3.5, 4.0, 3.5, 4.5, 4.0, 3.5, 4.5, 5.0, 4.0,
      # South: 4-5 hrs
      4.0, 5.0, 4.0, 4.5, 4.0, 5.0, 5.0, 4.5, 4.0
    ),
    trip_status = rep("complete", 27),
    trip_duration = c(
      # North
      2.0, 3.0, 2.5, 3.0, 2.0, 2.5, 3.0, 3.5, 3.0,
      # Central
      3.5, 4.0, 3.5, 4.5, 4.0, 3.5, 4.5, 5.0, 4.0,
      # South
      4.0, 5.0, 4.0, 4.5, 4.0, 5.0, 5.0, 4.5, 4.0
    ),
    stringsAsFactors = FALSE
  )

  suppressWarnings(add_interviews( # nolint: object_usage_linter
    design, interviews,
    catch = catch_total, effort = hours_fished, # nolint: object_usage_linter
    trip_status = trip_status, trip_duration = trip_duration # nolint: object_usage_linter
  ))
}

#' Create 3-section design with "South" absent from interview/count data
#'
#' Registered sections: "North", "Central", "South".
#' Interview data contains only "North" and "Central" rows — "South" absent.
make_3section_catch_design_missing_south <- function() { # nolint: object_length_linter
  cal <- data.frame(
    date = as.Date(c(
      "2024-06-03", "2024-06-04", "2024-06-05", "2024-06-06",
      "2024-06-07", "2024-06-10",
      "2024-06-08", "2024-06-09", "2024-06-14", "2024-06-15",
      "2024-06-16", "2024-06-21"
    )),
    day_type = c(
      "weekday", "weekday", "weekday", "weekday", "weekday", "weekday",
      "weekend", "weekend", "weekend", "weekend", "weekend", "weekend"
    ),
    stringsAsFactors = FALSE
  )
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter

  sections_df <- data.frame(
    section = c("North", "Central", "South"),
    stringsAsFactors = FALSE
  )
  design <- add_sections(design, sections_df, section_col = section) # nolint: object_usage_linter

  counts <- data.frame(
    date = rep(cal$date, times = 3),
    day_type = rep(cal$day_type, times = 3),
    section = rep(c("North", "Central", "South"), each = nrow(cal)),
    effort_hours = c(
      20, 22, 18, 25, 15, 24, 21, 26, 23, 28, 20, 27,
      35, 38, 32, 42, 30, 45, 37, 44, 40, 48, 35, 46,
      8, 10, 5, 12, 6, 11, 7, 9, 6, 13, 8, 10
    ),
    stringsAsFactors = FALSE
  )
  design <- suppressWarnings(add_counts(design, counts)) # nolint: object_usage_linter

  # Only North and Central interviews — South absent
  interviews <- data.frame(
    date = as.Date(c(
      "2024-06-03", "2024-06-04", "2024-06-05",
      "2024-06-07", "2024-06-10", "2024-06-07",
      "2024-06-08", "2024-06-09", "2024-06-14",
      "2024-06-03", "2024-06-04", "2024-06-05",
      "2024-06-06", "2024-06-10", "2024-06-10",
      "2024-06-08", "2024-06-09", "2024-06-21"
    )),
    day_type = c(
      "weekday", "weekday", "weekday", "weekday", "weekday", "weekday",
      "weekend", "weekend", "weekend",
      "weekday", "weekday", "weekday", "weekday", "weekday", "weekday",
      "weekend", "weekend", "weekend"
    ),
    section = rep(c("North", "Central"), each = 9),
    catch_total = c(
      2, 3, 2, 4, 3, 2, 3, 4, 3,
      5, 6, 5, 7, 6, 5, 7, 8, 6
    ),
    hours_fished = c(
      2.0, 3.0, 2.5, 3.0, 2.0, 2.5, 3.0, 3.5, 3.0,
      3.5, 4.0, 3.5, 4.5, 4.0, 3.5, 4.5, 5.0, 4.0
    ),
    trip_status = rep("complete", 18),
    trip_duration = c(
      2.0, 3.0, 2.5, 3.0, 2.0, 2.5, 3.0, 3.5, 3.0,
      3.5, 4.0, 3.5, 4.5, 4.0, 3.5, 4.5, 5.0, 4.0
    ),
    stringsAsFactors = FALSE
  )

  suppressWarnings(add_interviews( # nolint: object_usage_linter
    design, interviews,
    catch = catch_total, effort = hours_fished, # nolint: object_usage_linter
    trip_status = trip_status, trip_duration = trip_duration # nolint: object_usage_linter
  ))
}

# PROD-01: Per-section rows for estimate_total_catch ----

test_that("PROD-01-catch: estimate_total_catch on 3-section design returns a tibble with a section column", {
  design <- make_3section_total_catch_design() # nolint: object_usage_linter
  result <- suppressWarnings(suppressMessages(
    estimate_total_catch(design) # nolint: object_usage_linter
  ))
  expect_true("section" %in% names(result$estimates))
})

test_that("PROD-01-catch-rows: estimate_total_catch on 3-section design returns 3 rows (aggregate_sections = FALSE)", {
  design <- make_3section_total_catch_design() # nolint: object_usage_linter
  result <- suppressWarnings(suppressMessages(
    estimate_total_catch(design, aggregate_sections = FALSE) # nolint: object_usage_linter
  ))
  expect_equal(nrow(result$estimates), 3L)
})

test_that("PROD-01-catch-missing: missing section inserts NA row with data_available=FALSE for estimate_total_catch", {
  design <- make_3section_catch_design_missing_south() # nolint: object_usage_linter
  warns <- character(0)
  result <- withCallingHandlers(
    estimate_total_catch(design, missing_sections = "warn"), # nolint: object_usage_linter
    warning = function(w) {
      warns <<- c(warns, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  south_row <- result$estimates[result$estimates$section == "South", ]
  expect_equal(nrow(south_row), 1L)
  expect_false(south_row$data_available)
  expect_true(is.na(south_row$estimate))
})

# PROD-02: Lake total row for estimate_total_catch ----

test_that("PROD-02-catch-lake: aggregate_sections=TRUE appends .lake_total row (4 rows total for 3-section design)", {
  design <- make_3section_total_catch_design() # nolint: object_usage_linter
  result <- suppressWarnings(suppressMessages(
    estimate_total_catch(design, aggregate_sections = TRUE) # nolint: object_usage_linter
  ))
  expect_equal(nrow(result$estimates), 4L)
  expect_true(".lake_total" %in% result$estimates$section)
})

test_that("PROD-02-catch-sum: .lake_total$estimate equals sum of per-section estimates", {
  design <- make_3section_total_catch_design() # nolint: object_usage_linter
  result <- suppressWarnings(suppressMessages(
    estimate_total_catch(design, aggregate_sections = TRUE) # nolint: object_usage_linter
  ))
  section_rows <- result$estimates[result$estimates$section != ".lake_total", ]
  lake_row <- result$estimates[result$estimates$section == ".lake_total", ]
  expect_equal(lake_row$estimate, sum(section_rows$estimate), tolerance = 1e-10)
})

test_that("PROD-02-catch-se: .lake_total$se equals sqrt(sum(se_i^2)) over present section rows", {
  design <- make_3section_total_catch_design() # nolint: object_usage_linter
  result <- suppressWarnings(suppressMessages(
    estimate_total_catch(design, aggregate_sections = TRUE) # nolint: object_usage_linter
  ))
  section_rows <- result$estimates[result$estimates$section != ".lake_total", ]
  lake_row <- result$estimates[result$estimates$section == ".lake_total", ]
  expected_se <- sqrt(sum(section_rows$se^2))
  expect_equal(lake_row$se, expected_se, tolerance = 1e-10)
})

test_that("PROD-02-catch-prop: prop_of_lake_total for present sections sums to 1.0", {
  design <- make_3section_total_catch_design() # nolint: object_usage_linter
  result <- suppressWarnings(suppressMessages(
    estimate_total_catch(design, aggregate_sections = FALSE) # nolint: object_usage_linter
  ))
  expect_true("prop_of_lake_total" %in% names(result$estimates))
  expect_equal(sum(result$estimates$prop_of_lake_total), 1.0, tolerance = 1e-10)
})

# PROD-02-catch-regression: Non-sectioned designs return identical results (regression guard) ----

test_that("PROD-02-catch-regression: non-sectioned design returns same result as pre-Phase-41", {
  design_no_sections <- make_total_catch_design() # nolint: object_usage_linter
  result <- estimate_total_catch(design_no_sections) # nolint: object_usage_linter
  expect_s3_class(result, "creel_estimates")
  expect_false("section" %in% names(result$estimates))
  expect_true(is.numeric(result$estimates$estimate))
  expect_true(result$estimates$estimate > 0)
})

# ICE-04: estimate_total_catch() ice compatibility ----

make_ice_total_catch_design <- function() {
  # Four days — 2 weekday, 2 weekend — ensures each stratum has >= 2 interviews
  cal <- data.frame(
    date = as.Date(c("2024-01-10", "2024-01-11", "2024-01-12", "2024-01-13")),
    day_type = c("weekday", "weekday", "weekend", "weekend"),
    stringsAsFactors = FALSE
  )
  design <- creel_design( # nolint: object_usage_linter
    cal,
    date = date, strata = day_type, # nolint: object_usage_linter
    survey_type = "ice",
    effort_type = "time_on_ice",
    p_period = 0.5
  )
  interviews_df <- data.frame(
    date = as.Date(c("2024-01-10", "2024-01-11", "2024-01-12", "2024-01-13")),
    n_counted = c(10L, 8L, 12L, 9L),
    n_interviewed = c(3L, 2L, 4L, 3L),
    hours_fished = c(2.0, 1.5, 3.0, 2.5),
    walleye_catch = c(1L, 0L, 2L, 1L),
    trip_status = rep("complete", 4L),
    stringsAsFactors = FALSE
  )
  suppressWarnings(add_interviews( # nolint: object_usage_linter
    design,
    interviews_df,
    catch = walleye_catch, # nolint: object_usage_linter
    effort = hours_fished, # nolint: object_usage_linter
    n_counted = n_counted, # nolint: object_usage_linter
    n_interviewed = n_interviewed, # nolint: object_usage_linter
    trip_status = trip_status # nolint: object_usage_linter
  ))
}

test_that("ICE-04: estimate_total_catch() on ice design returns valid estimates tibble", {
  design <- make_ice_total_catch_design() # nolint: object_usage_linter
  result <- estimate_total_catch(design) # nolint: object_usage_linter
  expect_s3_class(result, "creel_estimates")
  expect_true("estimate" %in% names(result$estimates))
  expect_true(is.numeric(result$estimates$estimate))
})

# Phase 46: Camera interview pipeline (CAM-04) — estimate_total_catch() ----

#' Build a camera design with counts and interviews for total catch estimation
make_camera_total_catch_design <- function() {
  data("example_calendar", package = "tidycreel")
  cal <- example_calendar # nolint: object_usage_linter
  dates <- unique(cal$date)[1:4]
  day_types <- cal$day_type[match(dates, cal$date)]

  design <- creel_design( # nolint: object_usage_linter
    cal,
    date = date, strata = day_type, # nolint: object_usage_linter
    survey_type = "camera",
    camera_mode = "counter"
  )
  counts <- data.frame(
    date = dates,
    day_type = day_types,
    n_counted = c(30L, 25L, 55L, 48L),
    stringsAsFactors = FALSE
  )
  design <- suppressWarnings(add_counts(design, counts)) # nolint: object_usage_linter

  interviews <- data.frame(
    date = rep(dates, each = 3),
    day_type = rep(day_types, each = 3),
    trip_status = rep("complete", 12),
    hours_fished = c(1.5, 2.0, 3.0, 1.0, 2.5, 1.5, 2.0, 3.5, 2.5, 1.5, 2.0, 3.0),
    walleye = c(1L, 2L, 0L, 0L, 3L, 1L, 2L, 1L, 3L, 0L, 2L, 1L),
    walleye_kept = c(1L, 1L, 0L, 0L, 2L, 0L, 1L, 0L, 2L, 0L, 1L, 1L),
    stringsAsFactors = FALSE
  )
  suppressWarnings(add_interviews( # nolint: object_usage_linter
    design, interviews,
    catch = walleye, # nolint: object_usage_linter
    effort = hours_fished, # nolint: object_usage_linter
    trip_status = trip_status # nolint: object_usage_linter
  ))
}

test_that("CAM-04: estimate_total_catch() on camera design returns valid creel_estimates", {
  design <- make_camera_total_catch_design() # nolint: object_usage_linter
  result <- suppressWarnings(estimate_total_catch(design)) # nolint: object_usage_linter
  expect_s3_class(result, "creel_estimates")
  expect_true("estimate" %in% names(result$estimates))
  expect_true("se" %in% names(result$estimates))
})

test_that("CAM-04: estimate_total_catch() on camera design returns finite positive estimate", {
  design <- make_camera_total_catch_design() # nolint: object_usage_linter
  result <- suppressWarnings(estimate_total_catch(design)) # nolint: object_usage_linter
  expect_true(is.numeric(result$estimates$estimate))
  expect_true(is.finite(result$estimates$estimate))
  expect_true(result$estimates$estimate > 0)
})

test_that("CAM-04: estimate_total_catch() on camera routes through standard (non-bus_route, non-ice) path", {
  design <- make_camera_total_catch_design() # nolint: object_usage_linter
  result <- suppressWarnings(estimate_total_catch(design)) # nolint: object_usage_linter
  # Standard path produces method = "product-total-catch" (not bus-route or HT path)
  expect_equal(result$method, "product-total-catch")
})
