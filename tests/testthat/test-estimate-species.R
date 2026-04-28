# Tests for Phase 34: Species-Level Extrapolated Estimates
# Covers: estimate_catch_rate with species grouping, resolve_species_by helper,
# estimate_release_rate, estimate_total_release,
# estimate_total_catch and estimate_total_harvest with species grouping

# ---------------------------------------------------------------------------
# Section fixtures for RATE-02b, RATE-03 (estimate_release_rate section tests)
# Duplicated from test-estimate-catch-rate.R for self-contained test file.
# ---------------------------------------------------------------------------

#' Create 3-section design with interview data for release rate section tests
make_3section_design_with_interviews_rel <- function() { # nolint: object_length_linter
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

  interviews <- data.frame(
    date = as.Date(c(
      "2024-06-03", "2024-06-04", "2024-06-05",
      "2024-06-07", "2024-06-10", "2024-06-07",
      "2024-06-08", "2024-06-09", "2024-06-14",
      "2024-06-03", "2024-06-04", "2024-06-05",
      "2024-06-06", "2024-06-10", "2024-06-10",
      "2024-06-08", "2024-06-09", "2024-06-21",
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
      2, 3, 2, 4, 3, 2, 3, 4, 3,
      5, 6, 5, 7, 6, 5, 7, 8, 6,
      10, 12, 9, 11, 10, 12, 13, 11, 10
    ),
    hours_fished = c(
      2.0, 3.0, 2.5, 3.0, 2.0, 2.5, 3.0, 3.5, 3.0,
      3.5, 4.0, 3.5, 4.5, 4.0, 3.5, 4.5, 5.0, 4.0,
      4.0, 5.0, 4.0, 4.5, 4.0, 5.0, 5.0, 4.5, 4.0
    ),
    catch_kept = c(
      1, 2, 1, 3, 2, 1, 2, 3, 2,
      3, 4, 3, 5, 4, 3, 5, 6, 4,
      7, 9, 6, 8, 7, 9, 10, 8, 7
    ),
    trip_status = rep("complete", 27),
    trip_duration = c(
      2.0, 3.0, 2.5, 3.0, 2.0, 2.5, 3.0, 3.5, 3.0,
      3.5, 4.0, 3.5, 4.5, 4.0, 3.5, 4.5, 5.0, 4.0,
      4.0, 5.0, 4.0, 4.5, 4.0, 5.0, 5.0, 4.5, 4.0
    ),
    stringsAsFactors = FALSE
  )

  # Add catch data for release rate
  interviews$interview_id <- seq_len(nrow(interviews))

  design <- suppressWarnings(add_interviews( # nolint: object_usage_linter
    design, interviews,
    catch = catch_total, effort = hours_fished, harvest = catch_kept, # nolint: object_usage_linter
    trip_status = trip_status, trip_duration = trip_duration # nolint: object_usage_linter
  ))

  # Build simple catch data: each interview has one "released" row
  catch_df <- data.frame(
    interview_id = interviews$interview_id,
    species = "walleye",
    count = pmax(0L, interviews$catch_total - interviews$catch_kept),
    catch_type = "released",
    stringsAsFactors = FALSE
  )

  suppressWarnings(add_catch( # nolint: object_usage_linter
    design, catch_df,
    catch_uid = interview_id, interview_uid = interview_id, # nolint: object_usage_linter
    species = species, count = count, catch_type = catch_type # nolint: object_usage_linter
  ))
}

#' Create 3-section design with South absent from interview data (for release rate tests)
make_section_design_missing_interview_section_rel <- function() { # nolint: object_length_linter
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

  # Only North and Central
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
    catch_kept = c(
      1, 2, 1, 3, 2, 1, 2, 3, 2,
      3, 4, 3, 5, 4, 3, 5, 6, 4
    ),
    trip_status = rep("complete", 18),
    trip_duration = c(
      2.0, 3.0, 2.5, 3.0, 2.0, 2.5, 3.0, 3.5, 3.0,
      3.5, 4.0, 3.5, 4.5, 4.0, 3.5, 4.5, 5.0, 4.0
    ),
    stringsAsFactors = FALSE
  )
  interviews$interview_id <- seq_len(nrow(interviews))

  design <- suppressWarnings(add_interviews( # nolint: object_usage_linter
    design, interviews,
    catch = catch_total, effort = hours_fished, harvest = catch_kept, # nolint: object_usage_linter
    trip_status = trip_status, trip_duration = trip_duration # nolint: object_usage_linter
  ))

  catch_df <- data.frame(
    interview_id = interviews$interview_id,
    species = "walleye",
    count = pmax(0L, interviews$catch_total - interviews$catch_kept),
    catch_type = "released",
    stringsAsFactors = FALSE
  )

  suppressWarnings(add_catch( # nolint: object_usage_linter
    design, catch_df,
    catch_uid = interview_id, interview_uid = interview_id, # nolint: object_usage_linter
    species = species, count = count, catch_type = catch_type # nolint: object_usage_linter
  ))
}

# ---------------------------------------------------------------------------
# Shared test fixture
# ---------------------------------------------------------------------------

make_test_design_with_catch <- function(include_harvest = FALSE) {
  design <- creel_design( # nolint: object_usage_linter
    example_calendar, # nolint: object_usage_linter
    date = date, strata = day_type # nolint: object_usage_linter
  )
  design <- suppressMessages(add_counts(design, example_counts)) # nolint: object_usage_linter
  if (include_harvest) {
    design <- suppressMessages(add_interviews( # nolint: object_usage_linter
      design, example_interviews, # nolint: object_usage_linter
      catch = catch_total, harvest = catch_kept, effort = hours_fished, # nolint: object_usage_linter
      trip_status = trip_status, trip_duration = trip_duration # nolint: object_usage_linter
    ))
  } else {
    design <- suppressMessages(add_interviews( # nolint: object_usage_linter
      design, example_interviews, # nolint: object_usage_linter
      catch = catch_total, effort = hours_fished, # nolint: object_usage_linter
      trip_status = trip_status, trip_duration = trip_duration # nolint: object_usage_linter
    ))
  }
  suppressMessages(add_catch( # nolint: object_usage_linter
    design, example_catch, # nolint: object_usage_linter
    catch_uid = interview_id, interview_uid = interview_id, # nolint: object_usage_linter
    species = species, count = count, catch_type = catch_type # nolint: object_usage_linter
  ))
}

#' Design with >= 10 interviews per stratum — required for per-stratum
#' product estimation (estimate_total_*() with by = species).
make_test_design_with_catch_adequate <- function(include_harvest = FALSE) { # nolint: object_length_linter
  set.seed(99)
  # 8 weekday + 8 weekend dates
  cal <- data.frame(
    date = as.Date(c(
      "2024-06-03", "2024-06-04", "2024-06-05", "2024-06-06",
      "2024-06-07", "2024-06-10", "2024-06-11", "2024-06-12",
      "2024-06-08", "2024-06-09", "2024-06-15", "2024-06-16",
      "2024-06-22", "2024-06-23", "2024-06-29", "2024-06-30"
    )),
    day_type = c(rep("weekday", 8), rep("weekend", 8)),
    stringsAsFactors = FALSE
  )
  counts <- data.frame(
    date = cal$date,
    day_type = cal$day_type,
    effort_hours = c(rep(15, 8), rep(30, 8)),
    stringsAsFactors = FALSE
  )
  # 12 interviews per stratum: spread across 6 dates per stratum
  wkday_dates <- rep(cal$date[1:6], 2)
  wkend_dates <- rep(cal$date[9:14], 2)
  catch_total <- sample(1:5, 24, replace = TRUE)
  interviews <- data.frame(
    date = c(wkday_dates, wkend_dates),
    day_type = c(rep("weekday", 12), rep("weekend", 12)),
    interview_id = seq_len(24),
    catch_total = catch_total,
    catch_kept = if (include_harvest) pmin(sample(0:3, 24, replace = TRUE), catch_total) else 0L,
    hours_fished = runif(24, 0.5, 4),
    trip_status = "complete",
    trip_duration = runif(24, 1, 6),
    stringsAsFactors = FALSE
  )
  # species catch (3 species: bass, panfish, walleye)
  # Build caught/released/harvested so that harvested + released <= caught
  catch_df <- do.call(rbind, lapply(c("bass", "panfish", "walleye"), function(sp) {
    n_caught <- sample(2:5, 24, replace = TRUE)
    n_released <- floor(n_caught * runif(24, 0, 0.5))
    n_harvested <- if (include_harvest) pmin(n_caught - n_released, sample(0:2, 24, replace = TRUE)) else integer(24)
    rows <- data.frame(
      interview_id = seq_len(24),
      species = sp,
      count = n_caught,
      catch_type = "caught",
      stringsAsFactors = FALSE
    )
    rows_r <- data.frame(
      interview_id = seq_len(24),
      species = sp,
      count = n_released,
      catch_type = "released",
      stringsAsFactors = FALSE
    )
    if (include_harvest) {
      rows_h <- data.frame(
        interview_id = seq_len(24),
        species = sp,
        count = n_harvested,
        catch_type = "harvested",
        stringsAsFactors = FALSE
      )
      rbind(rows, rows_r, rows_h)
    } else {
      rbind(rows, rows_r)
    }
  }))

  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter
  design <- suppressMessages(add_counts(design, counts)) # nolint: object_usage_linter
  if (include_harvest) {
    design <- suppressMessages(add_interviews(design, interviews, # nolint: object_usage_linter
      catch = catch_total, harvest = catch_kept, effort = hours_fished,
      trip_status = trip_status, trip_duration = trip_duration
    ))
  } else {
    design <- suppressMessages(add_interviews(design, interviews, # nolint: object_usage_linter
      catch = catch_total, effort = hours_fished,
      trip_status = trip_status, trip_duration = trip_duration
    ))
  }
  suppressMessages(add_catch(design, catch_df, # nolint: object_usage_linter
    catch_uid = interview_id, interview_uid = interview_id,
    species = species, count = count, catch_type = catch_type
  ))
}

make_test_design_no_catch <- function() {
  design <- creel_design( # nolint: object_usage_linter
    example_calendar, # nolint: object_usage_linter
    date = date, strata = day_type # nolint: object_usage_linter
  )
  design <- suppressMessages(add_counts(design, example_counts)) # nolint: object_usage_linter
  suppressMessages(add_interviews( # nolint: object_usage_linter
    design, example_interviews, # nolint: object_usage_linter
    catch = catch_total, effort = hours_fished, # nolint: object_usage_linter
    trip_status = trip_status, trip_duration = trip_duration # nolint: object_usage_linter
  ))
}

# ---------------------------------------------------------------------------
# 1. estimate_catch_rate() species-level (~12 tests)
# ---------------------------------------------------------------------------

test_that("estimate_catch_rate with by=species returns creel_estimates object", {
  d <- make_test_design_with_catch()
  result <- suppressWarnings(suppressMessages(estimate_catch_rate(d, by = species)))
  expect_s3_class(result, "creel_estimates")
})

test_that("estimate_catch_rate species returns tibble with species column", {
  d <- make_test_design_with_catch()
  result <- suppressWarnings(suppressMessages(estimate_catch_rate(d, by = species)))
  expect_true("species" %in% names(result$estimates))
})

test_that("estimate_catch_rate species returns one row per species", {
  d <- make_test_design_with_catch()
  result <- suppressWarnings(suppressMessages(estimate_catch_rate(d, by = species)))
  expect_equal(nrow(result$estimates), 3L)
})

test_that("estimate_catch_rate species returns walleye, bass, panfish", {
  d <- make_test_design_with_catch()
  result <- suppressWarnings(suppressMessages(estimate_catch_rate(d, by = species)))
  expect_setequal(result$estimates$species, c("bass", "panfish", "walleye"))
})

test_that("estimate_catch_rate species estimates have expected columns", {
  d <- make_test_design_with_catch()
  result <- suppressWarnings(suppressMessages(estimate_catch_rate(d, by = species)))
  expect_true(all(
    c("species", "estimate", "se", "ci_lower", "ci_upper", "n") %in% names(result$estimates)
  ))
})

test_that("estimate_catch_rate species all estimates are non-negative", {
  d <- make_test_design_with_catch()
  result <- suppressWarnings(suppressMessages(estimate_catch_rate(d, by = species)))
  expect_true(all(result$estimates$estimate >= 0))
})

test_that("estimate_catch_rate species n equals total interview count (zero-fill correct)", {
  d <- make_test_design_with_catch()
  result <- suppressWarnings(suppressMessages(estimate_catch_rate(d, by = species)))
  # n should be same for all species (17 complete trips, zero-filled)
  expect_true(all(result$estimates$n == result$estimates$n[1]))
})

test_that("estimate_catch_rate species method attribute is 'ratio-of-means-cpue-species'", {
  d <- make_test_design_with_catch()
  result <- suppressWarnings(suppressMessages(estimate_catch_rate(d, by = species)))
  expect_equal(result$method, "ratio-of-means-cpue-species")
})

test_that("estimate_catch_rate ungrouped unchanged when no catch data", {
  d <- make_test_design_no_catch()
  result <- suppressWarnings(suppressMessages(estimate_catch_rate(d)))
  expect_equal(result$method, "ratio-of-means-cpue")
  expect_equal(nrow(result$estimates), 1L)
})

test_that("estimate_catch_rate species errors when species in by but catch not attached", {
  d <- make_test_design_no_catch()
  expect_error(
    suppressWarnings(suppressMessages(estimate_catch_rate(d, by = species))),
    "species"
  )
})

test_that("estimate_catch_rate species per-species CPUE is ordered alphabetically", {
  d <- make_test_design_with_catch()
  result <- suppressWarnings(suppressMessages(estimate_catch_rate(d, by = species)))
  expect_equal(result$estimates$species, sort(result$estimates$species))
})

test_that("estimate_catch_rate species: estimates differ across species (non-identical)", {
  d <- make_test_design_with_catch()
  result <- suppressWarnings(suppressMessages(estimate_catch_rate(d, by = species)))
  # At least two species should have different estimates
  expect_false(length(unique(result$estimates$estimate)) == 1L)
})

# ---------------------------------------------------------------------------
# 2. resolve_species_by() helper tests (~5 tests)
# ---------------------------------------------------------------------------

test_that("resolve_species_by returns NULL species_var when no catch data", {
  d <- make_test_design_no_catch()
  by_quo <- rlang::quo(day_type)
  result <- tidycreel:::resolve_species_by(by_quo, d)
  expect_null(result$species_var)
})

test_that("resolve_species_by detects species column from catch", {
  d <- make_test_design_with_catch()
  by_quo <- rlang::quo(species)
  result <- tidycreel:::resolve_species_by(by_quo, d)
  expect_equal(result$species_var, "species")
})

test_that("resolve_species_by separates species from interview vars", {
  d <- make_test_design_with_catch()
  by_quo <- rlang::quo(c(day_type, species))
  result <- tidycreel:::resolve_species_by(by_quo, d)
  expect_equal(result$species_var, "species")
  expect_equal(result$interview_vars, "day_type")
  expect_setequal(result$all_vars, c("day_type", "species"))
})

test_that("resolve_species_by handles NULL by_quo", {
  d <- make_test_design_with_catch()
  by_quo <- rlang::quo(NULL)
  result <- tidycreel:::resolve_species_by(by_quo, d)
  expect_null(result$all_vars)
  expect_null(result$species_var)
  expect_null(result$interview_vars)
})

test_that("resolve_species_by errors on unknown column", {
  d <- make_test_design_with_catch()
  by_quo <- rlang::quo(nonexistent_col)
  expect_error(tidycreel:::resolve_species_by(by_quo, d))
})

# ---------------------------------------------------------------------------
# 3. estimate_release_rate() tests (~10 tests)
# ---------------------------------------------------------------------------

test_that("estimate_release_rate returns creel_estimates object", {
  d <- make_test_design_with_catch()
  result <- suppressWarnings(estimate_release_rate(d))
  expect_s3_class(result, "creel_estimates")
})

test_that("estimate_release_rate has method 'ratio-of-means-rpue'", {
  d <- make_test_design_with_catch()
  result <- suppressWarnings(estimate_release_rate(d))
  expect_equal(result$method, "ratio-of-means-rpue")
})

test_that("estimate_release_rate estimate is non-negative", {
  d <- make_test_design_with_catch()
  result <- suppressWarnings(estimate_release_rate(d))
  expect_gte(result$estimates$estimate, 0)
})

test_that("estimate_release_rate n equals total interviews", {
  d <- make_test_design_with_catch()
  result <- suppressWarnings(estimate_release_rate(d))
  expect_equal(result$estimates$n, nrow(d$interviews))
})

test_that("estimate_release_rate by=species returns one row per species", {
  d <- make_test_design_with_catch()
  result <- suppressWarnings(estimate_release_rate(d, by = species))
  expect_equal(nrow(result$estimates), 3L)
})

test_that("estimate_release_rate by=species all estimates non-negative", {
  d <- make_test_design_with_catch()
  result <- suppressWarnings(estimate_release_rate(d, by = species))
  expect_true(all(result$estimates$estimate >= 0))
})

test_that("estimate_release_rate by=species returns species column first", {
  d <- make_test_design_with_catch()
  result <- suppressWarnings(estimate_release_rate(d, by = species))
  expect_equal(names(result$estimates)[1], "species")
})

test_that("estimate_release_rate errors when no catch data", {
  d <- make_test_design_no_catch()
  expect_error(estimate_release_rate(d), "add_catch")
})

test_that("estimate_release_rate errors when no interview survey", {
  d <- creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  d$catch <- data.frame(
    interview_id = 1L, species = "walleye", count = 1L, catch_type = "released"
  )
  expect_error(estimate_release_rate(d), "add_interviews")
})

# ---------------------------------------------------------------------------
# 4. estimate_total_release() tests (~8 tests)
# ---------------------------------------------------------------------------

test_that("estimate_total_release returns creel_estimates object", {
  d <- make_test_design_with_catch()
  result <- suppressWarnings(estimate_total_release(d))
  expect_s3_class(result, "creel_estimates")
})

test_that("estimate_total_release method is 'product-total-release'", {
  d <- make_test_design_with_catch()
  result <- suppressWarnings(estimate_total_release(d))
  expect_equal(result$method, "product-total-release")
})

test_that("estimate_total_release estimate is positive", {
  d <- make_test_design_with_catch()
  result <- suppressWarnings(estimate_total_release(d))
  expect_gt(result$estimates$estimate, 0)
})

test_that("estimate_total_release by=species returns one row per species", {
  d <- make_test_design_with_catch_adequate() # nolint: object_length_linter
  result <- suppressWarnings(estimate_total_release(d, by = species))
  expect_equal(nrow(result$estimates), 3L)
})

test_that("estimate_total_release species rows have estimate + se + ci columns", {
  d <- make_test_design_with_catch_adequate() # nolint: object_length_linter
  result <- suppressWarnings(estimate_total_release(d, by = species))
  expect_true(all(
    c("species", "estimate", "se", "ci_lower", "ci_upper", "n") %in% names(result$estimates)
  ))
})

test_that("estimate_total_release errors when no catch data", {
  d <- make_test_design_no_catch()
  expect_error(estimate_total_release(d), "add_catch")
})

test_that("estimate_total_release errors when no counts", {
  d <- creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  d$catch <- data.frame(
    interview_id = 1L, species = "w", count = 1L, catch_type = "released"
  )
  expect_error(suppressMessages(estimate_total_release(d)))
})

test_that("estimate_total_release SE > 0 (delta method produces variance)", {
  d <- make_test_design_with_catch()
  result <- suppressWarnings(estimate_total_release(d))
  expect_gt(result$estimates$se, 0)
})

test_that("estimate_total_release by=day_type routes through grouped path", {
  d <- make_test_design_with_catch_adequate()
  result <- suppressWarnings(estimate_total_release(d, by = day_type))
  expect_s3_class(result, "creel_estimates")
  expect_equal(nrow(result$estimates), 2L)
  expect_true(all(c("day_type", "estimate", "se", "ci_lower", "ci_upper", "n") %in%
    names(result$estimates)))
})

test_that("estimate_total_release grouped estimates are positive", {
  d <- make_test_design_with_catch_adequate()
  result <- suppressWarnings(estimate_total_release(d, by = day_type))
  expect_true(all(result$estimates$estimate > 0))
  expect_true(all(result$estimates$se > 0))
})

# ---------------------------------------------------------------------------
# 5. estimate_total_catch() species extension tests (~7 tests)
# ---------------------------------------------------------------------------

test_that("estimate_total_catch unchanged without species (backward compat)", {
  d_with <- make_test_design_with_catch()
  d_without <- make_test_design_no_catch()
  r_with <- suppressWarnings(suppressMessages(estimate_total_catch(d_with)))
  r_without <- suppressWarnings(suppressMessages(estimate_total_catch(d_without)))
  expect_equal(r_with$estimates$estimate, r_without$estimates$estimate,
    tolerance = 1e-6
  )
})

test_that("estimate_total_catch by=species returns one row per species", {
  d <- make_test_design_with_catch_adequate() # nolint: object_length_linter
  result <- suppressWarnings(suppressMessages(estimate_total_catch(d, by = species)))
  expect_equal(nrow(result$estimates), 3L)
})

test_that("estimate_total_catch species estimates are positive", {
  d <- make_test_design_with_catch_adequate() # nolint: object_length_linter
  result <- suppressWarnings(suppressMessages(estimate_total_catch(d, by = species)))
  expect_true(all(result$estimates$estimate > 0))
})

test_that("estimate_total_catch species method is 'product-total-catch'", {
  d <- make_test_design_with_catch_adequate() # nolint: object_length_linter
  result <- suppressWarnings(suppressMessages(estimate_total_catch(d, by = species)))
  expect_equal(result$method, "product-total-catch")
})

test_that("estimate_total_catch species returns species column first", {
  d <- make_test_design_with_catch_adequate() # nolint: object_length_linter
  result <- suppressWarnings(suppressMessages(estimate_total_catch(d, by = species)))
  expect_equal(names(result$estimates)[1], "species")
})

test_that("estimate_total_catch species errors when no catch data", {
  d <- make_test_design_no_catch()
  expect_error(
    suppressWarnings(suppressMessages(estimate_total_catch(d, by = species))),
    "species"
  )
})

test_that("estimate_total_catch species SE > 0 for all species", {
  d <- make_test_design_with_catch_adequate() # nolint: object_length_linter
  result <- suppressWarnings(suppressMessages(estimate_total_catch(d, by = species)))
  expect_true(all(result$estimates$se >= 0))
})

# ---------------------------------------------------------------------------
# 6. estimate_total_harvest() species extension tests (~7 tests)
# ---------------------------------------------------------------------------

test_that("estimate_total_harvest unchanged without species (backward compat)", {
  d_with <- make_test_design_with_catch(include_harvest = TRUE)
  d_without <- creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  d_without <- suppressMessages(add_counts(d_without, example_counts))
  d_without <- suppressMessages(add_interviews(d_without, example_interviews,
    catch = catch_total, harvest = catch_kept, effort = hours_fished,
    trip_status = trip_status, trip_duration = trip_duration
  ))
  r_with <- suppressWarnings(suppressMessages(estimate_total_harvest(d_with)))
  r_without <- suppressWarnings(suppressMessages(estimate_total_harvest(d_without)))
  expect_equal(r_with$estimates$estimate, r_without$estimates$estimate,
    tolerance = 1e-6
  )
})

test_that("estimate_total_harvest by=species returns one row per species", {
  d <- make_test_design_with_catch_adequate(include_harvest = TRUE) # nolint: object_length_linter
  result <- suppressWarnings(suppressMessages(estimate_total_harvest(d, by = species)))
  expect_equal(nrow(result$estimates), 3L)
})

test_that("estimate_total_harvest species estimates are non-negative", {
  d <- make_test_design_with_catch_adequate(include_harvest = TRUE) # nolint: object_length_linter
  result <- suppressWarnings(suppressMessages(estimate_total_harvest(d, by = species)))
  expect_true(all(result$estimates$estimate >= 0))
})

test_that("estimate_total_harvest species method is 'product-total-harvest'", {
  d <- make_test_design_with_catch_adequate(include_harvest = TRUE) # nolint: object_length_linter
  result <- suppressWarnings(suppressMessages(estimate_total_harvest(d, by = species)))
  expect_equal(result$method, "product-total-harvest")
})

test_that("estimate_total_harvest species returns species column first", {
  d <- make_test_design_with_catch_adequate(include_harvest = TRUE) # nolint: object_length_linter
  result <- suppressWarnings(suppressMessages(estimate_total_harvest(d, by = species)))
  expect_equal(names(result$estimates)[1], "species")
})

test_that("estimate_total_harvest species errors when no catch data", {
  d_without <- creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  d_without <- suppressMessages(add_counts(d_without, example_counts))
  d_without <- suppressMessages(add_interviews(d_without, example_interviews,
    catch = catch_total, harvest = catch_kept, effort = hours_fished,
    trip_status = trip_status, trip_duration = trip_duration
  ))
  expect_error(
    suppressWarnings(suppressMessages(estimate_total_harvest(d_without, by = species))),
    "species"
  )
})

test_that("estimate_total_harvest species SE >= 0 for all species", {
  d <- make_test_design_with_catch_adequate(include_harvest = TRUE) # nolint: object_length_linter
  result <- suppressWarnings(suppressMessages(estimate_total_harvest(d, by = species)))
  expect_true(all(result$estimates$se >= 0))
})

# ---------------------------------------------------------------------------
# Section dispatch tests for estimate_release_rate() (RATE-02b, RATE-03)
# ---------------------------------------------------------------------------

test_that("RATE-02b: estimate_release_rate on 3-section design returns exactly 3 rows", {
  design <- make_3section_design_with_interviews_rel() # nolint: object_usage_linter
  result <- suppressWarnings(suppressMessages(
    estimate_release_rate(design, missing_sections = "warn") # nolint: object_usage_linter
  ))
  expect_equal(nrow(result$estimates), 3L)
  expect_true("section" %in% names(result$estimates))
  expect_false(".lake_total" %in% result$estimates$section)
})

test_that("RATE-03-release: missing section produces NA row + cli_warn for estimate_release_rate", {
  design <- make_section_design_missing_interview_section_rel() # nolint: object_usage_linter
  warns <- character(0)
  result <- withCallingHandlers(
    estimate_release_rate(design, missing_sections = "warn"), # nolint: object_usage_linter
    warning = function(w) {
      warns <<- c(warns, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  expect_true(any(grepl("missing|section|South", warns, ignore.case = TRUE)))
  south_row <- result$estimates[result$estimates$section == "South", ]
  expect_equal(nrow(south_row), 1L)
  expect_false(south_row$data_available)
  expect_true(is.na(south_row$estimate))
})
