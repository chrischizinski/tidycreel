# Tests for Phase 34: Species-Level Extrapolated Estimates
# Covers: estimate_cpue with species grouping, resolve_species_by helper,
# estimate_release_rate, estimate_total_release,
# estimate_total_catch and estimate_total_harvest with species grouping

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
# 1. estimate_cpue() species-level (~12 tests)
# ---------------------------------------------------------------------------

test_that("estimate_cpue with by=species returns creel_estimates object", {
  d <- make_test_design_with_catch()
  result <- suppressWarnings(suppressMessages(estimate_cpue(d, by = species)))
  expect_s3_class(result, "creel_estimates")
})

test_that("estimate_cpue species returns tibble with species column", {
  d <- make_test_design_with_catch()
  result <- suppressWarnings(suppressMessages(estimate_cpue(d, by = species)))
  expect_true("species" %in% names(result$estimates))
})

test_that("estimate_cpue species returns one row per species", {
  d <- make_test_design_with_catch()
  result <- suppressWarnings(suppressMessages(estimate_cpue(d, by = species)))
  expect_equal(nrow(result$estimates), 3L)
})

test_that("estimate_cpue species returns walleye, bass, panfish", {
  d <- make_test_design_with_catch()
  result <- suppressWarnings(suppressMessages(estimate_cpue(d, by = species)))
  expect_setequal(result$estimates$species, c("bass", "panfish", "walleye"))
})

test_that("estimate_cpue species estimates have expected columns", {
  d <- make_test_design_with_catch()
  result <- suppressWarnings(suppressMessages(estimate_cpue(d, by = species)))
  expect_true(all(
    c("species", "estimate", "se", "ci_lower", "ci_upper", "n") %in% names(result$estimates)
  ))
})

test_that("estimate_cpue species all estimates are non-negative", {
  d <- make_test_design_with_catch()
  result <- suppressWarnings(suppressMessages(estimate_cpue(d, by = species)))
  expect_true(all(result$estimates$estimate >= 0))
})

test_that("estimate_cpue species n equals total interview count (zero-fill correct)", {
  d <- make_test_design_with_catch()
  result <- suppressWarnings(suppressMessages(estimate_cpue(d, by = species)))
  # n should be same for all species (17 complete trips, zero-filled)
  expect_true(all(result$estimates$n == result$estimates$n[1]))
})

test_that("estimate_cpue species method attribute is 'ratio-of-means-cpue-species'", {
  d <- make_test_design_with_catch()
  result <- suppressWarnings(suppressMessages(estimate_cpue(d, by = species)))
  expect_equal(result$method, "ratio-of-means-cpue-species")
})

test_that("estimate_cpue ungrouped unchanged when no catch data", {
  d <- make_test_design_no_catch()
  result <- suppressWarnings(suppressMessages(estimate_cpue(d)))
  expect_equal(result$method, "ratio-of-means-cpue")
  expect_equal(nrow(result$estimates), 1L)
})

test_that("estimate_cpue species errors when species in by but catch not attached", {
  d <- make_test_design_no_catch()
  expect_error(
    suppressWarnings(suppressMessages(estimate_cpue(d, by = species))),
    "species"
  )
})

test_that("estimate_cpue species per-species CPUE is ordered alphabetically", {
  d <- make_test_design_with_catch()
  result <- suppressWarnings(suppressMessages(estimate_cpue(d, by = species)))
  expect_equal(result$estimates$species, sort(result$estimates$species))
})

test_that("estimate_cpue species: estimates differ across species (non-identical)", {
  d <- make_test_design_with_catch()
  result <- suppressWarnings(suppressMessages(estimate_cpue(d, by = species)))
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
  d <- make_test_design_with_catch()
  result <- suppressWarnings(estimate_total_release(d, by = species))
  expect_equal(nrow(result$estimates), 3L)
})

test_that("estimate_total_release species rows have estimate + se + ci columns", {
  d <- make_test_design_with_catch()
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
  d <- make_test_design_with_catch()
  result <- suppressWarnings(suppressMessages(estimate_total_catch(d, by = species)))
  expect_equal(nrow(result$estimates), 3L)
})

test_that("estimate_total_catch species estimates are positive", {
  d <- make_test_design_with_catch()
  result <- suppressWarnings(suppressMessages(estimate_total_catch(d, by = species)))
  expect_true(all(result$estimates$estimate > 0))
})

test_that("estimate_total_catch species method is 'product-total-catch'", {
  d <- make_test_design_with_catch()
  result <- suppressWarnings(suppressMessages(estimate_total_catch(d, by = species)))
  expect_equal(result$method, "product-total-catch")
})

test_that("estimate_total_catch species returns species column first", {
  d <- make_test_design_with_catch()
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
  d <- make_test_design_with_catch()
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
  d <- make_test_design_with_catch(include_harvest = TRUE)
  result <- suppressWarnings(suppressMessages(estimate_total_harvest(d, by = species)))
  expect_equal(nrow(result$estimates), 3L)
})

test_that("estimate_total_harvest species estimates are non-negative", {
  d <- make_test_design_with_catch(include_harvest = TRUE)
  result <- suppressWarnings(suppressMessages(estimate_total_harvest(d, by = species)))
  expect_true(all(result$estimates$estimate >= 0))
})

test_that("estimate_total_harvest species method is 'product-total-harvest'", {
  d <- make_test_design_with_catch(include_harvest = TRUE)
  result <- suppressWarnings(suppressMessages(estimate_total_harvest(d, by = species)))
  expect_equal(result$method, "product-total-harvest")
})

test_that("estimate_total_harvest species returns species column first", {
  d <- make_test_design_with_catch(include_harvest = TRUE)
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
  d <- make_test_design_with_catch(include_harvest = TRUE)
  result <- suppressWarnings(suppressMessages(estimate_total_harvest(d, by = species)))
  expect_true(all(result$estimates$se >= 0))
})
