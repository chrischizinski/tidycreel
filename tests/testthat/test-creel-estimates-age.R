# Tests for est_age_distribution() / est_mean_age() in R/creel-estimates-age.R
# Prefix: AGD- (Age Distribution)

# Fixtures ----

make_age_design <- function() {
  data(example_calendar, package = "tidycreel")
  data(example_interviews, package = "tidycreel")
  data(example_ages, package = "tidycreel")
  data(example_catch, package = "tidycreel")

  d <- suppressWarnings(
    creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  )
  d <- suppressWarnings(add_interviews(
    d,
    example_interviews, # nolint: object_usage_linter
    catch = catch_total, # nolint: object_usage_linter
    effort = hours_fished, # nolint: object_usage_linter
    harvest = catch_kept, # nolint: object_usage_linter
    trip_status = trip_status # nolint: object_usage_linter
  ))
  # #310: the distribution is now rescaled onto the REPORTED catch, so a
  # species grouping needs that species' own total. Only add_catch() supplies
  # it -- the interview-level column is not species-resolved.
  d <- suppressWarnings(add_catch(
    d,
    example_catch, # nolint: object_usage_linter
    catch_uid = interview_id, # nolint: object_usage_linter
    interview_uid = interview_id, # nolint: object_usage_linter
    species = species, # nolint: object_usage_linter
    count = count, # nolint: object_usage_linter
    catch_type = catch_type # nolint: object_usage_linter
  ))
  add_ages(
    d,
    example_ages, # nolint: object_usage_linter
    age_uid = interview_id, # nolint: object_usage_linter
    interview_uid = interview_id, # nolint: object_usage_linter
    species = species, # nolint: object_usage_linter
    age = age, # nolint: object_usage_linter
    age_type = age_type # nolint: object_usage_linter
  )
}

make_age_design_no_ages <- function() {
  data(example_calendar, package = "tidycreel")
  data(example_interviews, package = "tidycreel")

  d <- suppressWarnings(
    creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  )
  suppressWarnings(add_interviews(
    d,
    example_interviews, # nolint: object_usage_linter
    catch = catch_total, # nolint: object_usage_linter
    effort = hours_fished, # nolint: object_usage_linter
    harvest = catch_kept, # nolint: object_usage_linter
    trip_status = trip_status # nolint: object_usage_linter
  ))
}

# AGD- guard tests ----

test_that("AGD-01 est_age_distribution() errors when design is not creel_design", {
  expect_error(est_age_distribution(list()), "must be a")
})

test_that("AGD-02 est_age_distribution() errors when no ages attached", {
  expect_error(
    est_age_distribution(make_age_design_no_ages()),
    "No age data found"
  )
})

test_that("AGD-03 est_age_distribution() errors when interviews not attached", {
  d <- suppressWarnings(
    creel_design(
      tidycreel::example_calendar,
      date = date,
      strata = day_type
    )
  )
  expect_error(est_age_distribution(d), "No interview survey")
})

test_that("AGD-04 est_age_distribution() errors on invalid variance method", {
  d <- make_age_design()
  expect_error(est_age_distribution(d, variance = "nonsense"), "Invalid variance")
})

test_that("AGD-05 est_age_distribution() errors on out-of-range conf_level", {
  d <- make_age_design()
  expect_error(est_age_distribution(d, conf_level = 0), "conf_level")
  expect_error(est_age_distribution(d, conf_level = 1), "conf_level")
  expect_error(est_age_distribution(d, conf_level = 1.5), "conf_level")
})

test_that("AGD-06 est_age_distribution() errors on invalid type", {
  d <- make_age_design()
  expect_error(est_age_distribution(d, type = "bogus"))
})

# AGD- output structure tests ----

test_that("AGD-07 est_age_distribution() returns creel_age_distribution S3 class", {
  d <- make_age_design()
  result <- est_age_distribution(d)
  expect_s3_class(result, "creel_age_distribution")
  expect_s3_class(result, "data.frame")
})

test_that("AGD-08 est_age_distribution() returns expected columns", {
  d <- make_age_design()
  result <- est_age_distribution(d, type = "catch")
  expect_true(all(
    c(
      "age",
      "estimate",
      "se",
      "ci_lower",
      "ci_upper",
      "percent",
      "cumulative_percent",
      "n"
    ) %in%
      names(result)
  ))
})

test_that("AGD-09 est_age_distribution() age column is integer", {
  d <- make_age_design()
  result <- est_age_distribution(d, type = "catch")
  expect_type(result$age, "integer")
})

test_that("AGD-10 est_age_distribution() stores metadata attrs", {
  d <- make_age_design()
  result <- est_age_distribution(d, type = "release")
  expect_equal(attr(result, "type"), "release")
  expect_equal(attr(result, "variance_method"), "taylor")
  expect_equal(attr(result, "method"), "age-distribution")
})

test_that("AGD-11 est_age_distribution() ages are sorted ascending", {
  d <- make_age_design()
  result <- est_age_distribution(d, type = "catch")
  expect_false(is.unsorted(result$age))
})

# AGD- estimation behavior tests ----

test_that("AGD-12 ungrouped catch estimate sums to total fish count", {
  d <- make_age_design()
  result <- est_age_distribution(d, type = "catch")
  # #310: the totals describe the REPORTED catch, not the aged subsample.
  # Before #310 this summed to 18 -- the number of aged fish in example_ages.
  reported <- weighted_interview_total(d, d$interviews[[d$catch_col]])
  expect_equal(sum(result$estimate), reported, tolerance = 1e-8)
  expect_equal(reported, 127)
})

test_that("AGD-13 ungrouped harvest estimate sums to harvest fish count", {
  d <- make_age_design()
  result <- est_age_distribution(d, type = "harvest")
  # Before #310 this summed to 12, the aged harvest rows.
  reported <- weighted_interview_total(d, d$interviews[[d$harvest_col]])
  expect_equal(sum(result$estimate), reported, tolerance = 1e-8)
  expect_equal(reported, 77)
})

test_that("AGD-14 ungrouped release estimate sums to release fish count", {
  d <- make_age_design()
  result <- est_age_distribution(d, type = "release")
  # Before #310 this summed to 6, the aged release rows.
  reported <- weighted_interview_total(
    d,
    d$interviews[[d$catch_col]] - d$interviews[[d$harvest_col]]
  )
  expect_equal(sum(result$estimate), reported, tolerance = 1e-8)
  expect_equal(reported, 50)
})

test_that("AGD-15 percent sums to 100 (ungrouped)", {
  d <- make_age_design()
  result <- est_age_distribution(d, type = "catch")
  expect_equal(sum(result$percent), 100, tolerance = 0.1)
})

test_that("AGD-16 cumulative_percent ends at 100 (ungrouped)", {
  d <- make_age_design()
  result <- est_age_distribution(d, type = "catch")
  expect_equal(result$cumulative_percent[nrow(result)], 100, tolerance = 0.1)
})

test_that("AGD-17 cumulative_percent is non-decreasing (ungrouped)", {
  d <- make_age_design()
  result <- est_age_distribution(d, type = "catch")
  expect_true(all(diff(result$cumulative_percent) >= -1e-10))
})

test_that("AGD-18 standard errors are non-negative", {
  d <- make_age_design()
  result <- est_age_distribution(d, type = "catch")
  expect_true(all(result$se >= 0))
})

test_that("AGD-19 ci_lower <= estimate <= ci_upper", {
  d <- make_age_design()
  result <- est_age_distribution(d, type = "catch")
  expect_true(all(result$ci_lower <= result$estimate + 1e-8))
  expect_true(all(result$estimate <= result$ci_upper + 1e-8))
})

# AGD- grouping tests ----

test_that("AGD-20 by = species adds species column", {
  d <- make_age_design()
  result <- est_age_distribution(d, type = "catch", by = species) # nolint: object_usage_linter
  expect_true("species" %in% names(result))
})

test_that("AGD-21 by = species returns expected per-species totals", {
  d <- make_age_design()
  # A species group scales by that species' own reported total, which only the
  # catch table carries. Before #310 these were the aged counts: walleye 9,
  # bass 5, panfish 4.
  result <- est_age_distribution(d, type = "catch", by = species) # nolint: object_usage_linter
  est_by_species <- tapply(result$estimate, result$species, sum)
  for (sp in unique(result[[d$catch_species_col]])) {
    expect_equal(
      est_by_species[[sp]],
      weighted_interview_total(d, species_reported_vector(d, sp, "catch")),
      tolerance = 1e-8
    )
  }
  caught <- d[["catch"]][d[["catch"]][[d$catch_type_col]] == "caught", , drop = FALSE]
  reported <- tapply(caught[[d$catch_count_col]], caught[[d$catch_species_col]], sum)
  expect_equal(as.numeric(reported[["walleye"]]), 33)
})

test_that("AGD-22 percent sums to 100 within each species group", {
  d <- make_age_design()
  result <- est_age_distribution(d, type = "catch", by = species) # nolint: object_usage_linter
  for (sp in unique(result$species)) {
    sub <- result[result$species == sp, ]
    expect_equal(sum(sub$percent), 100, tolerance = 0.1)
  }
})

test_that("AGD-23 cumulative_percent ends at 100 within each species group", {
  d <- make_age_design()
  result <- est_age_distribution(d, type = "catch", by = species) # nolint: object_usage_linter
  for (sp in unique(result$species)) {
    sub <- result[result$species == sp, ]
    expect_equal(sub$cumulative_percent[nrow(sub)], 100, tolerance = 0.1)
  }
})

test_that("AGD-24 by_vars attr records grouping variable", {
  d <- make_age_design()
  result <- est_age_distribution(d, type = "catch", by = species) # nolint: object_usage_linter
  expect_equal(attr(result, "by_vars"), "species")
})

# AGD- type subset tests ----

test_that("AGD-25 harvest type excludes release-only ages", {
  d <- make_age_design()
  harvest <- est_age_distribution(d, type = "harvest")
  catch <- est_age_distribution(d, type = "catch")
  expect_lte(sum(harvest$estimate), sum(catch$estimate))
})

test_that("AGD-26 harvest + release estimates equal catch estimate", {
  d <- make_age_design()
  harvest <- est_age_distribution(d, type = "harvest")
  release <- est_age_distribution(d, type = "release")
  catch <- est_age_distribution(d, type = "catch")
  expect_equal(
    sum(harvest$estimate) + sum(release$estimate),
    sum(catch$estimate),
    tolerance = 1e-8
  )
})

# AGD- variance method tests ----

test_that("AGD-27 bootstrap variance produces valid numeric SE", {
  d <- make_age_design()
  result <- est_age_distribution(d, type = "catch", variance = "bootstrap")
  expect_true(all(is.finite(result$se)))
  expect_true(all(result$se >= 0))
})

test_that("AGD-28 jackknife variance produces valid numeric SE", {
  d <- make_age_design()
  result <- est_age_distribution(d, type = "catch", variance = "jackknife")
  expect_true(all(is.finite(result$se)))
  expect_true(all(result$se >= 0))
})

test_that("AGD-29 variance_method attr reflects requested method", {
  d <- make_age_design()
  result <- est_age_distribution(d, type = "catch", variance = "bootstrap")
  expect_equal(attr(result, "variance_method"), "bootstrap")
})

# AGD- est_mean_age tests ----

test_that("AGD-30 est_mean_age() errors when input is not creel_age_distribution", {
  expect_error(est_mean_age(data.frame(age = 1:3)), "must be a")
})

test_that("AGD-31 est_mean_age() returns creel_mean_age S3 class", {
  d <- make_age_design()
  ad <- est_age_distribution(d, type = "catch")
  result <- est_mean_age(ad)
  expect_s3_class(result, "creel_mean_age")
  expect_s3_class(result, "data.frame")
})

test_that("AGD-32 est_mean_age() returns expected columns", {
  d <- make_age_design()
  ad <- est_age_distribution(d, type = "catch")
  result <- est_mean_age(ad)
  expect_true(all(
    c(
      "mean_age",
      "mean_age_se",
      "mean_age_ci_lower",
      "mean_age_ci_upper"
    ) %in%
      names(result)
  ))
})

test_that("AGD-33 est_mean_age() mean is between min and max observed age", {
  d <- make_age_design()
  ad <- est_age_distribution(d, type = "catch")
  result <- est_mean_age(ad)
  expect_gte(result$mean_age, min(ad$age))
  expect_lte(result$mean_age, max(ad$age))
})

test_that("AGD-34 est_mean_age() SE is non-negative", {
  d <- make_age_design()
  ad <- est_age_distribution(d, type = "catch")
  result <- est_mean_age(ad)
  expect_true(all(result$mean_age_se >= 0))
})

test_that("AGD-35 est_mean_age() CI brackets the mean", {
  d <- make_age_design()
  ad <- est_age_distribution(d, type = "catch")
  result <- est_mean_age(ad)
  expect_lte(result$mean_age_ci_lower, result$mean_age)
  expect_gte(result$mean_age_ci_upper, result$mean_age)
})

test_that("AGD-36 est_mean_age() with by = species returns one row per species", {
  d <- make_age_design()
  ad <- est_age_distribution(d, type = "catch", by = species) # nolint: object_usage_linter
  result <- est_mean_age(ad)
  expect_true("species" %in% names(result))
  expect_equal(nrow(result), length(unique(ad$species)))
})

test_that("AGD-37 est_mean_age() grouped means lie within group age range", {
  d <- make_age_design()
  ad <- est_age_distribution(d, type = "catch", by = species) # nolint: object_usage_linter
  result <- est_mean_age(ad)
  for (sp in result$species) {
    sub_ages <- ad$age[ad$species == sp]
    mean_sp <- result$mean_age[result$species == sp]
    expect_gte(mean_sp, min(sub_ages))
    expect_lte(mean_sp, max(sub_ages))
  }
})

test_that("AGD-38 est_mean_age() respects conf_level argument width", {
  d <- make_age_design()
  ad <- est_age_distribution(d, type = "catch")
  narrow <- est_mean_age(ad, conf_level = 0.80)
  wide <- est_mean_age(ad, conf_level = 0.99)
  narrow_width <- narrow$mean_age_ci_upper - narrow$mean_age_ci_lower
  wide_width <- wide$mean_age_ci_upper - wide$mean_age_ci_lower
  expect_gt(wide_width, narrow_width)
})

test_that("AGD-39 est_mean_age() errors on out-of-range conf_level", {
  d <- make_age_design()
  ad <- est_age_distribution(d, type = "catch")
  expect_error(est_mean_age(ad, conf_level = 0), "conf_level")
  expect_error(est_mean_age(ad, conf_level = 2), "conf_level")
})

test_that("AGD-40 est_mean_age() defaults conf_level from distribution attr", {
  d <- make_age_design()
  ad <- est_age_distribution(d, type = "catch", conf_level = 0.90)
  result <- est_mean_age(ad)
  expect_equal(attr(result, "conf_level"), 0.90)
})

# Zero-total guard ----

test_that("AGD-41 est_mean_age() warns and returns NA when all estimates are zero", {
  fake_ad <- data.frame(
    age = c(1L, 2L, 3L),
    estimate = c(0, 0, 0),
    se = c(0, 0, 0),
    stringsAsFactors = FALSE
  )
  class(fake_ad) <- c("creel_age_distribution", "data.frame")
  attr(fake_ad, "by_vars") <- NULL
  attr(fake_ad, "conf_level") <- 0.95

  expect_warning(result <- est_mean_age(fake_ad), "zero")
  expect_true(is.na(result$mean_age))
  expect_true(is.na(result$mean_age_se))
  expect_true(is.na(result$mean_age_ci_lower))
  expect_true(is.na(result$mean_age_ci_upper))
})

test_that("AGD-42 est_mean_age() warns NA only for zero-total group in grouped call", {
  fake_ad <- data.frame(
    species = c("walleye", "walleye", "perch", "perch"),
    age = c(1L, 2L, 1L, 2L),
    estimate = c(10, 20, 0, 0),
    se = c(1, 2, 0, 0),
    stringsAsFactors = FALSE
  )
  class(fake_ad) <- c("creel_age_distribution", "data.frame")
  attr(fake_ad, "by_vars") <- "species"
  attr(fake_ad, "conf_level") <- 0.95

  expect_warning(result <- est_mean_age(fake_ad), "zero")
  walleye_row <- result[result$species == "walleye", ]
  perch_row <- result[result$species == "perch", ]
  expect_false(is.na(walleye_row$mean_age))
  expect_true(is.na(perch_row$mean_age))
})

# Percent accumulation and the meaning of n (GH #313) ---------------------------
#
# The age path carries the same block as the length path, so it carried the same
# defect: `cumulative_percent` was `cumsum()` of the rounded `percent` column.
# AGD-16 above pins the endpoint at `tolerance = 0.1`, which is wider than the
# drift, so it passed either way. These pin it exactly.

test_that("AGD-24 (#313): cumulative_percent accumulates unrounded shares", {
  d <- suppressWarnings(suppressMessages(make_age_design()))
  result <- suppressWarnings(est_age_distribution(d, type = "catch"))

  expect_identical(result$cumulative_percent[nrow(result)], 100)
  expect_true(all(diff(result$cumulative_percent) >= 0))
})

test_that("AGD-25 (#313): n counts interviews with an aged fish, not fish", {
  d <- suppressWarnings(suppressMessages(make_age_design()))
  result <- suppressWarnings(est_age_distribution(d, type = "catch"))

  # Constant across the group's age classes, and an interview count rather than
  # a fish count -- the two things the documented meaning commits to.
  expect_identical(length(unique(result$n)), 1L)

  ages_data <- d$ages
  n_interviews <- length(unique(ages_data[[d$ages_interview_uid_col]]))
  expect_identical(unique(result$n), n_interviews)
})

test_that("AGD-43 (#317): the age path derives the reported total per pair too", {
  data("example_calendar", package = "tidycreel")
  data("example_interviews", package = "tidycreel")
  data("example_ages", package = "tidycreel")
  data("example_catch", package = "tidycreel")

  # The length and age paths call ONE reported-total helper. This pins that the
  # age caller inherits the per-species-interview-pair catch-type rule (#318)
  # rather than carrying its own copy -- the failure mode the near-twin files in
  # this package have produced before.
  iv <- example_interviews
  iv$gear <- iv$angler_type
  ages <- merge(example_ages, iv[, c("interview_id", "gear")],
                by = "interview_id", all.x = TRUE)

  d <- suppressMessages(creel_design(example_calendar, date = date, strata = day_type))
  d <- suppressWarnings(suppressMessages(add_interviews(
    d, iv,
    catch = catch_total, effort = hours_fished,
    harvest = catch_kept, trip_status = trip_status
  )))
  d <- suppressWarnings(suppressMessages(add_catch(
    d, example_catch,
    catch_uid = interview_id, interview_uid = interview_id,
    species = species, count = count, catch_type = catch_type
  )))
  d <- suppressWarnings(add_ages(
    d, ages,
    age_uid = interview_id, interview_uid = interview_id,
    species = species, age = age, age_type = age_type
  ))

  res <- suppressWarnings(suppressMessages(
    est_age_distribution(d, type = "catch", by = c(species, gear))
  ))
  got <- stats::aggregate(
    res$estimate,
    by = list(species = as.character(res$species), gear = as.character(res$gear)),
    FUN = sum
  )
  totals <- stats::setNames(round(got$x, 6), paste(got$species, got$gear))

  # Per-pair reported catch. The old per-table rule counted "caught" rows only
  # and gave panfish/bank 7, walleye/bank 18, bass/boat 5, walleye/boat 15.
  expect_equal(totals[["panfish bank"]], 10)
  expect_equal(totals[["walleye bank"]], 28)
  expect_equal(totals[["bass boat"]], 18)
  expect_equal(totals[["walleye boat"]], 27)
})

test_that("AGD-44 (#317): the age path refuses per group, not per species", {
  data("example_calendar", package = "tidycreel")
  data("example_interviews", package = "tidycreel")
  data("example_ages", package = "tidycreel")
  data("example_catch", package = "tidycreel")

  iv <- example_interviews
  iv$gear <- iv$angler_type
  bank_ids <- iv$interview_id[iv$gear == "bank"]
  # Walleye keeps its boat rows, so a species-wide test cannot see the bank
  # group as empty -- it used to be scaled onto a total of zero instead.
  catch2 <- example_catch[!(example_catch$species == "walleye" &
                              example_catch$interview_id %in% bank_ids), , drop = FALSE]
  ages <- merge(example_ages, iv[, c("interview_id", "gear")],
                by = "interview_id", all.x = TRUE)

  expect_true(any(ages$species == "walleye" & ages$gear == "bank"))
  expect_true(any(catch2$species == "walleye"))

  d <- suppressMessages(creel_design(example_calendar, date = date, strata = day_type))
  d <- suppressWarnings(suppressMessages(add_interviews(
    d, iv,
    catch = catch_total, effort = hours_fished,
    harvest = catch_kept, trip_status = trip_status
  )))
  d <- suppressWarnings(suppressMessages(add_catch(
    d, catch2,
    catch_uid = interview_id, interview_uid = interview_id,
    species = species, count = count, catch_type = catch_type
  )))
  d <- suppressWarnings(add_ages(
    d, ages,
    age_uid = interview_id, interview_uid = interview_id,
    species = species, age = age, age_type = age_type
  ))

  expect_error(
    suppressWarnings(suppressMessages(
      est_age_distribution(d, type = "catch", by = c(species, gear))
    )),
    class = "creel_error_no_rescale_total"
  )
})
