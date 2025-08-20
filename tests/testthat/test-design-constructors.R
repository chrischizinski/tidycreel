# Test plot_design for creel_design
test_that("plot_design returns ggplot object and visualizes coverage", {
  interviews <- create_test_interviews()
  calendar <- create_test_calendar()
  design <- design_access(interviews = interviews, calendar = calendar)
  p <- plot_design(design)
  expect_s3_class(p, "ggplot")
  expect_true("GeomBar" %in% sapply(p$layers, function(l) class(l$geom)[1]))
  expect_true(inherits(p$facet, "FacetWrap"))
})
# Test S3 print and summary methods for creel_design
test_that("print.creel_design outputs expected summary", {
  interviews <- create_test_interviews()
  calendar <- create_test_calendar()
  design <- design_access(interviews = interviews, calendar = calendar)
  expect_output(print(design), "<tidycreel survey design>")
  expect_output(print(design), "Design type: access_point")
  expect_output(print(design), "Strata variables:")
})

test_that("summary.creel_design returns expected list and print.summary.creel_design outputs summary", {
  interviews <- create_test_interviews()
  calendar <- create_test_calendar()
  design <- design_access(interviews = interviews, calendar = calendar)
  s <- summary(design)
  expect_s3_class(s, "summary.creel_design")
  expect_equal(s$design_type, "access_point")
  expect_equal(s$n_interviews, nrow(interviews))
  expect_output(print(s), "<Summary of tidycreel survey design>")
  expect_output(print(s), "Design type: access_point")
  expect_output(print(s), "Number of interviews:")
})
library(testthat)
library(tibble)

# Test data setup
create_test_interviews <- function() {
  tibble::tibble(
    interview_id = paste0("INT", sprintf("%03d", 1:20)),
    date = rep(as.Date("2024-01-01") + 0:3, each = 5),
    shift_block = rep(c("morning", "afternoon", "evening", "morning"), each = 5, length.out = 20),
    day_type = rep(c("weekday", "weekend"), length.out = 20),
    time_start = as.POSIXct("2024-01-01 08:00:00") + (1:20) * 3600,
    time_end = as.POSIXct("2024-01-01 08:15:00") + (1:20) * 3600,
    location = rep(c("Lake_A", "Lake_B"), 10),
    mode = rep(c("boat", "bank"), 10),
    party_size = sample(1:4, 20, replace = TRUE),
    hours_fished = runif(20, 1, 8),
    target_species = rep(c("walleye", "bass", "perch"), length.out = 20),
    catch_total = sample(0:10, 20, replace = TRUE),
    catch_kept = sample(0:8, 20, replace = TRUE),
    catch_released = catch_total - catch_kept,
    weight_total = runif(20, 0, 5),
    trip_complete = sample(c(TRUE, FALSE), 20, replace = TRUE),
    effort_expansion = rep(1.0, 20)
  )
}

create_test_counts <- function() {
  tibble::tibble(
    count_id = paste0("CNT", sprintf("%03d", 1:16)),
    date = rep(as.Date("2024-01-01") + 0:3, each = 4),
    shift_block = rep(c("morning", "afternoon", "evening", "morning"), each = 4, length.out = 16),
    day_type = rep(c("weekday", "weekend"), length.out = 16),
    time = as.POSIXct("2024-01-01 09:00:00") + (1:16) * 1800,
    location = rep(c("Lake_A", "Lake_B"), 8),
    mode = rep(c("boat", "bank"), 8),
    anglers_count = sample(5:25, 16, replace = TRUE),
    parties_count = sample(3:12, 16, replace = TRUE),
    weather_code = rep(c("clear", "cloudy", "rain"), length.out = 16),
    temperature = runif(16, 15, 25),
    wind_speed = runif(16, 0, 15),
    visibility = rep(c("good", "fair", "poor"), length.out = 16),
    count_duration = rep(15, 16)
  )
}

create_test_calendar <- function() {
  dates <- rep(as.Date("2024-01-01") + 0:3, each = 3)
  shift_blocks <- rep(c("morning", "afternoon", "evening"), 4)

  tibble::tibble(
    date = dates,
    stratum_id = paste0(format(date, "%Y-%m-%d"), "-", shift_blocks),
    day_type = rep(c("weekday", "weekend"), length.out = 12),
    season = rep("winter", 12),
    month = format(date, "%B"),
    weekend = (weekdays(date) %in% c("Saturday", "Sunday")),
    holiday = rep(FALSE, 12),
    shift_block = shift_blocks,
    target_sample = rep(10L, 12),
    actual_sample = sample(8:12, 12, replace = TRUE)
  )
}

# Test design_access()
test_that("design_access creates valid access design object", {
  interviews <- create_test_interviews()
  calendar <- create_test_calendar()

  design <- design_access(
    interviews = interviews,
    calendar = calendar,
    strata_vars = c("date", "shift_block")
  )

  expect_s3_class(design, "access_design")
  expect_s3_class(design, "creel_design")
  expect_equal(design$design_type, "access_point")
  expect_equal(length(design$design_weights), nrow(interviews))
  expect_true(all(design$design_weights > 0))
  expect_equal(names(design), c("design_type", "interviews", "calendar",
                                "locations", "strata_vars", "weight_method",
                                "design_weights", "svy_design", "metadata"))
})

test_that("design_access handles custom locations", {
  interviews <- create_test_interviews()
  calendar <- create_test_calendar()

  custom_locations <- c("Lake_A", "Lake_B", "Lake_C")
  design <- design_access(
    interviews = interviews,
    calendar = calendar,
    locations = custom_locations
  )

  expect_equal(design$locations, custom_locations)
})

test_that("design_access validates inputs", {
  interviews <- create_test_interviews()
  calendar <- create_test_calendar()

  # Test invalid weight method
  expect_error(
    design_access(interviews, calendar, weight_method = "invalid"),
    "should be one of"
  )

  # Test missing required columns
  bad_interviews <- interviews[, -1]
  expect_error(
    design_access(bad_interviews, calendar),
    "Missing required columns"
  )
})

# Test design_roving()
test_that("design_roving creates valid roving design object", {
  interviews <- create_test_interviews()
  counts <- create_test_counts()
  calendar <- create_test_calendar()

  design <- design_roving(
    interviews = interviews,
    counts = counts,
    calendar = calendar,
    strata_vars = c("date", "shift_block", "location")
  )

  expect_s3_class(design, "roving_design")
  expect_s3_class(design, "creel_design")
  expect_equal(design$design_type, "roving")
  expect_equal(length(design$design_weights), nrow(interviews))
  expect_true(all(design$design_weights > 0))
  expect_equal(nrow(design$effort_estimates),
               length(unique(interaction(interviews[c("date", "shift_block", "location")]))))
  expect_equal(names(design), c("design_type", "interviews", "counts", "calendar",
                                "locations", "strata_vars", "effort_method",
                                "coverage_correction", "design_weights",
                                "effort_estimates", "svy_design", "metadata"))
})

test_that("design_roving handles different effort methods", {
  interviews <- create_test_interviews()
  counts <- create_test_counts()
  calendar <- create_test_calendar()

  design_ratio <- design_roving(
    interviews = interviews,
    counts = counts,
    calendar = calendar,
    effort_method = "ratio"
  )

  design_calibrate <- design_roving(
    interviews = interviews,
    counts = counts,
    calendar = calendar,
    effort_method = "calibrate"
  )

  expect_s3_class(design_ratio, "roving_design")
  expect_s3_class(design_calibrate, "roving_design")
})

test_that("design_roving validates inputs", {
  interviews <- create_test_interviews()
  counts <- create_test_counts()
  calendar <- create_test_calendar()

  # Test invalid effort method
  expect_error(
    design_roving(interviews, counts, calendar, effort_method = "invalid"),
    "should be one of"
  )

  # Test missing count data columns
  bad_counts <- counts[, -1]
  expect_error(
    design_roving(interviews, bad_counts, calendar),
    "Missing required columns"
  )
})

# Test design_repweights()
test_that("design_repweights creates valid replicate weights design", {
  interviews <- create_test_interviews()
  calendar <- create_test_calendar()

  base_design <- design_access(
    interviews = interviews,
    calendar = calendar
  )

  rep_design <- design_repweights(
    base_design = base_design,
    replicates = 10,
    method = "bootstrap",
    seed = 12345
  )

  expect_s3_class(rep_design, "repweights_design")
  expect_s3_class(rep_design, "creel_design")
  expect_equal(ncol(rep_design$replicate_weights), 10)
  expect_equal(nrow(rep_design$replicate_weights), nrow(interviews))
  expect_equal(rep_design$replicate_method, "bootstrap")
  expect_equal(rep_design$replicates, 10)
  expect_equal(names(rep_design), c("base_design", "replicate_weights",
                                   "replicate_method", "replicates",
                                   "scale_factors", "svy_design", "metadata"))
})

test_that("design_repweights handles different methods", {
  interviews <- create_test_interviews()
  calendar <- create_test_calendar()

  base_design <- design_access(
    interviews = interviews,
    calendar = calendar
  )

  # Bootstrap
  boot_design <- design_repweights(
    base_design = base_design,
    method = "bootstrap",
    replicates = 5
  )

  # Jackknife
  jack_design <- design_repweights(
    base_design = base_design,
    method = "jackknife"
  )

  expect_s3_class(boot_design, "repweights_design")
  expect_s3_class(jack_design, "repweights_design")
  expect_equal(boot_design$replicates, 5)
  expect_equal(jack_design$replicates, nrow(interviews))
})

test_that("design_repweights validates base design", {
  expect_error(
    design_repweights(base_design = "not_a_design"),
    "must be a creel design object"
  )
})

test_that("design_repweights handles seed correctly", {
  interviews <- create_test_interviews()
  calendar <- create_test_calendar()

  base_design <- design_access(
    interviews = interviews,
    calendar = calendar
  )

  # With seed
  design1 <- design_repweights(
    base_design = base_design,
    replicates = 5,
    seed = 12345
  )

  design2 <- design_repweights(
    base_design = base_design,
    replicates = 5,
    seed = 12345
  )

  expect_equal(design1$replicate_weights, design2$replicate_weights)
})

# Test helper functions
test_that("calculate_access_weights produces valid weights", {
  interviews <- create_test_interviews()
  calendar <- create_test_calendar()

  weights <- calculate_access_weights(
    interviews = interviews,
    calendar = calendar,
    strata_vars = c("date", "shift_block"),
    weight_method = "standard"
  )

  expect_type(weights, "double")
  expect_length(weights, nrow(interviews))
  expect_true(all(weights > 0))
  expect_true(all(is.finite(weights)))
})

test_that("calculate_roving_effort produces valid estimates", {
  interviews <- create_test_interviews()
  counts <- create_test_counts()
  calendar <- create_test_calendar()

  effort <- calculate_roving_effort(
    interviews = interviews,
    counts = counts,
    calendar = calendar,
    strata_vars = c("date", "shift_block", "location"),
    effort_method = "ratio"
  )

  expect_s3_class(effort, "data.frame")
  expect_true(all(c("strata", "interview_effort", "count_effort", "effort_estimate") %in% names(effort)))
  expect_true(all(effort$effort_estimate > 0))
  expect_true(all(is.finite(effort$effort_estimate)))
})

test_that("calculate_roving_weights produces valid weights", {
  interviews <- create_test_interviews()
  counts <- create_test_counts()
  calendar <- create_test_calendar()

  effort_estimates <- calculate_roving_effort(
    interviews = interviews,
    counts = counts,
    calendar = calendar,
    strata_vars = c("date", "shift_block", "location"),
    effort_method = "ratio"
  )

  weights <- calculate_roving_weights(
    interviews = interviews,
    effort_estimates = effort_estimates,
    strata_vars = c("date", "shift_block", "location")
  )

  expect_type(weights, "double")
  expect_length(weights, nrow(interviews))
  expect_true(all(weights > 0))
  expect_true(all(is.finite(weights)))
})

test_that("create_replicate_weights produces valid matrix", {
  interviews <- create_test_interviews()
  calendar <- create_test_calendar()

  base_design <- design_access(
    interviews = interviews,
    calendar = calendar
  )

  rep_weights <- create_replicate_weights(
    base_design = base_design,
    replicates = 5,
    method = "bootstrap",
    strata_var = "date",
    cluster_var = "location"
  )

  expect_type(rep_weights, "double")
  expect_equal(dim(rep_weights), c(nrow(interviews), 5))
  expect_true(all(rep_weights >= 0))
  expect_true(all(is.finite(rep_weights)))
})

test_that("calculate_scale_factors produces valid factors", {
  factors <- calculate_scale_factors(
    method = "bootstrap",
    replicates = 100,
    base_design = NULL
  )

  expect_type(factors, "double")
  expect_length(factors, 1)
  expect_equal(factors, 0.01)
})

# Integration tests with real data
test_that("design constructors work with toy data", {
  # Skip if toy data not available
  skip_if_not(file.exists(system.file("extdata/toy_interviews.csv", package = "tidycreel")))

  interviews <- readr::read_csv(system.file("extdata/toy_interviews.csv", package = "tidycreel"))
  counts <- readr::read_csv(system.file("extdata/toy_counts.csv", package = "tidycreel"))
  calendar <- readr::read_csv(system.file("extdata/toy_calendar.csv", package = "tidycreel"))

  # Test access design
  access_design <- design_access(
    interviews = interviews,
    calendar = calendar
  )
  expect_s3_class(access_design, "access_design")

  # Test roving design
  roving_design <- design_roving(
    interviews = interviews,
    counts = counts,
    calendar = calendar
  )
  expect_s3_class(roving_design, "roving_design")

  # Test replicate weights
  rep_design <- design_repweights(
    base_design = access_design,
    replicates = 10
  )
  expect_s3_class(rep_design, "repweights_design")
})
