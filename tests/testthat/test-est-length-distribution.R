# Tests for est_length_distribution() in R/creel-estimates-length.R

# Fixtures ----

make_design_with_lengths_for_est <- function() {
  # nolint: object_length_linter
  data(example_calendar, package = "tidycreel")
  data(example_interviews, package = "tidycreel")
  data(example_lengths, package = "tidycreel")
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
  add_lengths(
    d,
    example_lengths, # nolint: object_usage_linter
    length_uid = interview_id, # nolint: object_usage_linter
    interview_uid = interview_id, # nolint: object_usage_linter
    species = species, # nolint: object_usage_linter
    length = length, # nolint: object_usage_linter
    length_type = length_type, # nolint: object_usage_linter
    count = count, # nolint: object_usage_linter
    release_format = "binned"
  )
}

make_design_no_lengths_for_est <- function() {
  # nolint: object_length_linter
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

# Guard tests ----

test_that("est_length_distribution() errors when design is not creel_design", {
  expect_error(
    est_length_distribution(list()),
    "must be a"
  )
})

test_that("est_length_distribution() errors when no lengths attached", {
  expect_error(
    est_length_distribution(make_design_no_lengths_for_est()),
    "No length data found"
  )
})

test_that("est_length_distribution() errors when bin_width is not positive", {
  d <- make_design_with_lengths_for_est()
  expect_error(est_length_distribution(d, bin_width = 0), "positive")
  expect_error(est_length_distribution(d, bin_width = -10), "positive")
  expect_error(est_length_distribution(d, bin_width = "25"), "positive")
})

test_that("est_length_distribution() errors on missing length_col", {
  d <- make_design_with_lengths_for_est()
  expect_error(
    est_length_distribution(d, length_col = "length_mm"),
    "not found"
  )
})

# Output structure tests ----

test_that("est_length_distribution() returns classed data.frame", {
  d <- make_design_with_lengths_for_est()
  result <- est_length_distribution(d)
  expect_s3_class(result, "creel_length_distribution")
  expect_s3_class(result, "data.frame")
})

test_that("est_length_distribution() returns expected columns", {
  d <- make_design_with_lengths_for_est()
  result <- est_length_distribution(d, type = "catch")
  expect_true(all(
    c(
      "length_bin",
      "bin_lower",
      "bin_upper",
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

test_that("est_length_distribution() length_bin is ordered", {
  d <- make_design_with_lengths_for_est()
  result <- est_length_distribution(d, type = "harvest")
  expect_true(is.ordered(result[["length_bin"]]))
})

test_that("est_length_distribution() stores metadata attrs", {
  d <- make_design_with_lengths_for_est()
  result <- est_length_distribution(d, type = "release", bin_width = 25)
  expect_equal(attr(result, "type"), "release")
  expect_equal(attr(result, "bin_width"), 25)
  expect_equal(attr(result, "variance_method"), "taylor")
})

# Estimation behavior tests ----

test_that("ungrouped catch estimate sums to expected total fish count for example data", {
  # #310: the totals describe the REPORTED catch, not the measured subsample.
  # Pinned against the design's own reported total rather than a constant, so
  # the test states the two-phase identity instead of restating an output.
  # Before #310 this summed to 37 -- the number of measured fish.
  d <- make_design_with_lengths_for_est()
  result <- est_length_distribution(d, type = "catch")
  reported <- sum(d$interviews[[d$catch_col]])
  expect_equal(sum(result[["estimate"]]), reported, tolerance = 1e-8)
  expect_equal(reported, 127)
})

test_that("ungrouped harvest estimate sums to expected total harvest fish count", {
  # Before #310 this summed to 14, the measured harvest fish.
  d <- make_design_with_lengths_for_est()
  result <- est_length_distribution(d, type = "harvest")
  reported <- sum(d$interviews[[d$harvest_col]])
  expect_equal(sum(result[["estimate"]]), reported, tolerance = 1e-8)
  expect_equal(reported, 77)
})

test_that("ungrouped release estimate sums to expected expanded release fish count", {
  # Release has no interview column; the catch model implies it as
  # caught - harvested. Before #310 this summed to 23, the measured releases.
  d <- make_design_with_lengths_for_est()
  result <- est_length_distribution(d, type = "release")
  reported <- sum(d$interviews[[d$catch_col]]) - sum(d$interviews[[d$harvest_col]])
  expect_equal(sum(result[["estimate"]]), reported, tolerance = 1e-8)
  expect_equal(reported, 50)
})

test_that("grouped species estimate returns expected species totals", {
  d <- make_design_with_lengths_for_est()
  # A species group can only be scaled by that species' own reported total,
  # which lives in the catch table -- the interview column is not
  # species-resolved. Pinned against that table directly.
  result <- est_length_distribution(d, type = "catch", by = species) # nolint: object_usage_linter
  est_by_species <- tapply(result[["estimate"]], result[["species"]], sum)
  caught <- d[["catch"]][d[["catch"]][[d$catch_type_col]] == "caught", , drop = FALSE]
  reported <- tapply(caught[[d$catch_count_col]], caught[[d$catch_species_col]], sum)
  for (sp in names(reported)) {
    expect_equal(est_by_species[[sp]], as.numeric(reported[[sp]]), tolerance = 1e-8)
  }
  # Before #310 these were the measured counts: walleye 13, bass 13, panfish 11.
  expect_equal(as.numeric(reported[["walleye"]]), 33)
})

test_that("grouped output includes by variable and keeps percent near 100 within group", {
  d <- make_design_with_lengths_for_est()
  result <- est_length_distribution(d, type = "catch", by = species, bin_width = 25) # nolint: object_usage_linter
  expect_true("species" %in% names(result))
  for (sp in unique(result$species)) {
    sub <- result[result$species == sp, ]
    expect_equal(sum(sub$percent), 100, tolerance = 0.1)
  }
})

test_that("cumulative_percent is non-decreasing within species", {
  d <- make_design_with_lengths_for_est()
  result <- est_length_distribution(d, type = "harvest", by = species, bin_width = 25) # nolint: object_usage_linter
  for (sp in unique(result$species)) {
    sub <- result[result$species == sp, ]
    diffs <- diff(sub$cumulative_percent)
    expect_true(all(diffs >= -1e-10))
  }
})

test_that("standard errors are non-negative", {
  d <- make_design_with_lengths_for_est()
  result <- est_length_distribution(d, type = "catch", by = species) # nolint: object_usage_linter
  expect_true(all(result$se >= 0))
})

# autoplot tests ----

skip_if_not_installed("ggplot2")

test_that("autoplot() returns a ggplot object for ungrouped length distribution", {
  d <- make_design_with_lengths_for_est()
  result <- est_length_distribution(d, type = "catch", bin_width = 25)
  p <- ggplot2::autoplot(result)
  expect_s3_class(p, "ggplot")
})

test_that("autoplot() returns a ggplot object for grouped length distribution", {
  d <- make_design_with_lengths_for_est()
  result <- est_length_distribution(d, type = "catch", by = species, bin_width = 25) # nolint: object_usage_linter
  p <- ggplot2::autoplot(result)
  expect_s3_class(p, "ggplot")
})

test_that("autoplot() renders without error for length distribution", {
  d <- make_design_with_lengths_for_est()
  result <- est_length_distribution(d, type = "harvest", by = species, bin_width = 25) # nolint: object_usage_linter
  p <- ggplot2::autoplot(result)
  expect_no_error(ggplot2::ggplot_build(p))
})

test_that("autoplot() uses histogram-style columns for length distribution", {
  d <- make_design_with_lengths_for_est()
  result <- est_length_distribution(d, type = "catch", bin_width = 25)
  p <- ggplot2::autoplot(result)
  built <- ggplot2::ggplot_build(p)
  expect_true("xmin" %in% names(built$data[[1L]]))
  expect_true("xmax" %in% names(built$data[[1L]]))
})

test_that("autoplot() accepts a title argument for length distribution", {
  d <- make_design_with_lengths_for_est()
  result <- est_length_distribution(d, type = "release", bin_width = 25)
  p <- ggplot2::autoplot(result, title = "Release Size Structure")
  expect_equal(p$labels$title, "Release Size Structure")
})

test_that("autoplot() accepts theme = 'creel' for length distribution", {
  d <- make_design_with_lengths_for_est()
  result <- est_length_distribution(d, type = "catch", by = species, bin_width = 25) # nolint: object_usage_linter
  p <- ggplot2::autoplot(result, theme = "creel")
  expect_s3_class(p, "ggplot")
  expect_no_error(ggplot2::ggplot_build(p))
})

# Percent accumulation and the meaning of n (GH #313) ---------------------------
#
# `cumulative_percent` used to be `cumsum()` of the already-rounded `percent`
# column, so each bin's rounding error was carried into every later bin and the
# final entry drifted off 100 -- 99.9 on this fixture. The existing coverage
# asserted `sum(percent)` to `tolerance = 0.1`, which is wider than the drift it
# was meant to catch, so the defect sat under a green test.

test_that("EST-LD-13 (#313): cumulative_percent accumulates unrounded shares", {
  d <- suppressWarnings(suppressMessages(make_design_with_lengths_for_est()))
  result <- suppressWarnings(
    est_length_distribution(d, type = "catch", by = species, bin_width = 25)
  )

  for (sp in unique(result$species)) {
    sub <- result[result$species == sp, , drop = FALSE]

    # The share of a group's own total must reach 100 exactly, not approximately.
    expect_identical(sub$cumulative_percent[nrow(sub)], 100)

    # And it must be non-decreasing, since it is a cumulative share.
    expect_true(all(diff(sub$cumulative_percent) >= 0))
  }
})

test_that("EST-LD-14 (#313): accumulating the rounded column would drift off 100", {
  d <- suppressWarnings(suppressMessages(make_design_with_lengths_for_est()))
  result <- suppressWarnings(
    est_length_distribution(d, type = "harvest", bin_width = 25)
  )

  # This is the mutant the fix kills, pinned explicitly: on this fixture the old
  # implementation's value and the new one differ, so a revert cannot pass. If a
  # future fixture makes these equal the test is no longer discriminating and
  # should be re-pointed at one where they are not.
  old_behaviour <- cumsum(result$percent)
  expect_false(
    isTRUE(all.equal(old_behaviour[length(old_behaviour)], 100))
  )
  expect_identical(result$cumulative_percent[nrow(result)], 100)
})

test_that("EST-LD-15 (#313): n counts interviews with a measured fish, not fish", {
  d <- suppressWarnings(suppressMessages(make_design_with_lengths_for_est()))
  result <- suppressWarnings(
    est_length_distribution(d, type = "harvest", bin_width = 25)
  )

  # `n` is documented as the number of interviews contributing at least one
  # measured fish to the group. Two consequences a reader relies on: it is
  # constant across the group's bins, and it is not the fish count.
  expect_identical(length(unique(result$n)), 1L)

  lengths_data <- d$lengths
  harvest_rows <- lengths_data[lengths_data[[d$lengths_type_col]] == "harvest", , drop = FALSE]
  n_interviews <- length(unique(harvest_rows[[d$lengths_interview_uid_col]]))
  expect_identical(unique(result$n), n_interviews)

  # The distinction that makes the column worth documenting: more fish were
  # measured than there were interviews to measure them in.
  expect_gt(nrow(harvest_rows), n_interviews)
})

# Two-phase rescaling onto the reported catch (GH #310) -------------------------
#
# Lengths are measured on a SUBSAMPLE of the catch. Expanding that subsample
# through the interview design estimated "total fish that happened to get
# measured" -- 14 against a reported harvest of 77 on this fixture -- and
# est_biomass() then called the result total biomass. The estimator is now
# two-phase: bin proportion among measured fish, scaled by the design-estimated
# reported total.

test_that("EST-LD-16 (#310): measuring each fish twice does not change the totals", {
  data("example_calendar", package = "tidycreel")
  data("example_interviews", package = "tidycreel")
  data("example_lengths", package = "tidycreel")
  data("example_catch", package = "tidycreel")

  build <- function(lengths_df) {
    d <- suppressMessages(creel_design(example_calendar, date = date, strata = day_type))
    d <- suppressWarnings(suppressMessages(add_interviews(
      d, example_interviews,
      catch = catch_total, effort = hours_fished,
      harvest = catch_kept, trip_status = trip_status
    )))
    d <- suppressWarnings(add_catch(
      d, example_catch,
      catch_uid = interview_id, interview_uid = interview_id,
      species = species, count = count, catch_type = catch_type
    ))
    suppressWarnings(add_lengths(
      d, lengths_df,
      length_uid = interview_id, interview_uid = interview_id,
      species = species, length = length, length_type = length_type,
      count = count, release_format = "binned"
    ))
  }

  # The sampling design, the interview weights and the true harvest are all
  # identical between these two. ONLY the measurement effort differs.
  once <- build(example_lengths)
  twice <- build(example_lengths[rep(seq_len(nrow(example_lengths)), 2), ])

  ld1 <- suppressWarnings(est_length_distribution(once, type = "harvest", bin_width = 25))
  ld2 <- suppressWarnings(est_length_distribution(twice, type = "harvest", bin_width = 25))

  # This is the whole point of #310. Before the fix these doubled -- and
  # est_biomass() doubled with them, reporting twice the fish because someone
  # measured twice as many of the same fish.
  expect_equal(sum(ld1$estimate), sum(ld2$estimate), tolerance = 1e-8)

  b1 <- est_biomass(ld1, a = 0.0088, b = 3.1)
  b2 <- est_biomass(ld2, a = 0.0088, b = 3.1)
  expect_equal(b1$biomass_estimate, b2$biomass_estimate, tolerance = 1e-8)

  # The shape was always right and must stay right.
  expect_equal(
    est_mean_length(ld1)$mean_length,
    est_mean_length(ld2)$mean_length,
    tolerance = 1e-8
  )
})

test_that("EST-LD-17 (#310): the totals reconcile with the design's reported total", {
  d <- make_design_with_lengths_for_est()
  ld <- suppressWarnings(est_length_distribution(d, type = "harvest", bin_width = 25))

  # The reconciliation the audit found missing: the distribution's total and the
  # design's own harvest total must estimate the same quantity.
  expect_equal(sum(ld$estimate), sum(d$interviews[[d$harvest_col]]), tolerance = 1e-8)

  # The scale factor is recorded rather than left to be inferred.
  expect_equal(attr(ld, "measured_total"), 14)
  expect_equal(attr(ld, "reported_total"), 77)
})

test_that("EST-LD-18 (#310): rescaling warns, and says by how much", {
  d <- make_design_with_lengths_for_est()

  # Silence here would be the defect in a new form: the totals are built from a
  # subsample and the caller has to know that.
  expect_warning(
    est_length_distribution(d, type = "harvest", bin_width = 25),
    class = "creel_warn_two_phase_rescale"
  )
  expect_warning(
    est_length_distribution(d, type = "harvest", bin_width = 25),
    "factor of 5.5"
  )
})

test_that("EST-LD-19 (#310): refuses when no reported total is available", {
  data("example_calendar", package = "tidycreel")
  data("example_interviews", package = "tidycreel")
  data("example_lengths", package = "tidycreel")

  # No `harvest =` on this design, so there is nothing to scale a harvest
  # distribution to. Refusing is the point: the alternative is a total on a
  # measured-fish basis, which is exactly what #310 removed.
  d <- suppressMessages(creel_design(example_calendar, date = date, strata = day_type))
  d <- suppressWarnings(suppressMessages(add_interviews(
    d, example_interviews,
    catch = catch_total, effort = hours_fished, trip_status = trip_status
  )))
  d <- suppressWarnings(add_lengths(
    d, example_lengths,
    length_uid = interview_id, interview_uid = interview_id,
    species = species, length = length, length_type = length_type,
    count = count, release_format = "binned"
  ))

  expect_error(
    est_length_distribution(d, type = "harvest", bin_width = 25),
    class = "creel_error_no_rescale_total"
  )
})

test_that("EST-LD-20 (#310): a grouped request's parts sum back to the whole", {
  d <- make_design_with_lengths_for_est()

  # Ensemble review finding. The first implementation handed EVERY group the
  # whole fishery's reported total, because the total column was the raw
  # interview column with no group restriction. by = length_type then returned
  # 127 for each of two groups against a reported catch of 127 -- the parts
  # summed to twice the whole, silently.
  #
  # length_type lives only in the lengths table, so it cannot restrict a
  # per-interview total at all. Refusing is the correct answer; the wrong one
  # was scaling by the whole.
  expect_error(
    suppressWarnings(est_length_distribution(d, type = "catch", by = length_type, bin_width = 25)),
    class = "creel_error_ungroupable_rescale"
  )

  # A species grouping CAN be restricted, via the catch table, and must
  # decompose exactly.
  ld <- suppressWarnings(est_length_distribution(d, type = "catch", by = species, bin_width = 25))
  caught <- d[["catch"]][d[["catch"]][[d$catch_type_col]] == "caught", , drop = FALSE]
  expect_equal(
    sum(ld$estimate),
    sum(caught[[d$catch_count_col]]),
    tolerance = 1e-8
  )
})

test_that("EST-LD-21 (#310): a species with no 'caught' row falls back per species", {
  data("example_calendar", package = "tidycreel")
  data("example_interviews", package = "tidycreel")
  data("example_lengths", package = "tidycreel")
  data("example_catch", package = "tidycreel")

  # Ensemble review finding. add_catch() makes a "caught" row optional --
  # absent, catch is harvested + released. That fallback was applied by testing
  # the WHOLE table, so one species having caught rows suppressed it for every
  # other species, which then scaled to a reported total of zero and reported
  # zero fish with no warning. Drop walleye's caught rows to make that concrete
  # while other species keep theirs.
  ct <- example_catch
  ct <- ct[!(ct$species == "walleye" & ct$catch_type == "caught"), , drop = FALSE]
  expect_true(any(ct$catch_type == "caught"))
  expect_true(any(ct$species == "walleye"))

  d <- suppressMessages(creel_design(example_calendar, date = date, strata = day_type))
  d <- suppressWarnings(suppressMessages(add_interviews(
    d, example_interviews,
    catch = catch_total, effort = hours_fished,
    harvest = catch_kept, trip_status = trip_status
  )))
  d <- suppressWarnings(add_catch(
    d, ct,
    catch_uid = interview_id, interview_uid = interview_id,
    species = species, count = count, catch_type = catch_type
  ))
  d <- suppressWarnings(add_lengths(
    d, example_lengths,
    length_uid = interview_id, interview_uid = interview_id,
    species = species, length = length, length_type = length_type,
    count = count, release_format = "binned"
  ))

  ld <- suppressWarnings(est_length_distribution(d, type = "catch", by = species, bin_width = 25))
  walleye <- sum(ld$estimate[ld$species == "walleye"])

  # Not zero, and equal to walleye's harvested + released.
  wal <- ct[ct$species == "walleye" & ct$catch_type %in% c("harvested", "released"), ]
  expect_gt(walleye, 0)
  expect_equal(walleye, sum(wal$count), tolerance = 1e-8)
})
