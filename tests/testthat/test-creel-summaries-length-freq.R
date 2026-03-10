# Tests for summarize_length_freq() in R/creel-summaries.R

# Fixtures ----

make_design_with_lengths <- function() { # nolint: object_length_linter
  data(example_calendar, package = "tidycreel")
  data(example_interviews, package = "tidycreel")
  data(example_lengths, package = "tidycreel")
  d <- suppressWarnings(
    creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  )
  d <- suppressWarnings(add_interviews(d, example_interviews, # nolint: object_usage_linter
    catch = catch_total, # nolint: object_usage_linter
    effort = hours_fished, # nolint: object_usage_linter
    harvest = catch_kept, # nolint: object_usage_linter
    trip_status = trip_status # nolint: object_usage_linter
  ))
  add_lengths(d, example_lengths, # nolint: object_usage_linter
    length_uid = interview_id, # nolint: object_usage_linter
    interview_uid = interview_id, # nolint: object_usage_linter
    species = species, # nolint: object_usage_linter
    length = length, # nolint: object_usage_linter
    length_type = length_type, # nolint: object_usage_linter
    count = count, # nolint: object_usage_linter
    release_format = "binned"
  )
}

make_design_no_lengths <- function() { # nolint: object_length_linter
  data(example_calendar, package = "tidycreel")
  data(example_interviews, package = "tidycreel")
  d <- suppressWarnings(
    creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  )
  suppressWarnings(add_interviews(d, example_interviews, # nolint: object_usage_linter
    catch = catch_total, # nolint: object_usage_linter
    effort = hours_fished, # nolint: object_usage_linter
    harvest = catch_kept, # nolint: object_usage_linter
    trip_status = trip_status # nolint: object_usage_linter
  ))
}

# summarize_length_freq() guard tests ----

test_that("summarize_length_freq() errors when design is not creel_design", {
  expect_error(
    summarize_length_freq(list()),
    "must be a"
  )
})

test_that("summarize_length_freq() errors when no lengths attached", {
  expect_error(
    summarize_length_freq(make_design_no_lengths()),
    "No length data found"
  )
})

test_that("summarize_length_freq() errors when bin_width is not positive", {
  d <- make_design_with_lengths()
  expect_error(summarize_length_freq(d, bin_width = 0), "positive")
  expect_error(summarize_length_freq(d, bin_width = -5), "positive")
  expect_error(summarize_length_freq(d, bin_width = "10"), "positive")
})

# summarize_length_freq() output structure tests ----

test_that("summarize_length_freq() returns correct columns for type = 'catch'", {
  d <- make_design_with_lengths()
  result <- summarize_length_freq(d, type = "catch")
  expect_true(all(c("length_bin", "N", "percent", "cumulative_percent") %in% names(result)))
})

test_that("summarize_length_freq() returns class c('creel_summary_length_freq', 'data.frame')", {
  d <- make_design_with_lengths()
  result <- summarize_length_freq(d)
  expect_s3_class(result, "creel_summary_length_freq")
  expect_s3_class(result, "data.frame")
})

test_that("summarize_length_freq() N column is integer", {
  d <- make_design_with_lengths()
  result <- summarize_length_freq(d, type = "harvest")
  expect_true(is.integer(result[["N"]]))
})

test_that("summarize_length_freq() length_bin is an ordered factor", {
  d <- make_design_with_lengths()
  result <- summarize_length_freq(d, type = "harvest")
  expect_true(is.ordered(result[["length_bin"]]))
})

test_that("summarize_length_freq() returns only non-zero bins", {
  d <- make_design_with_lengths()
  result <- summarize_length_freq(d, type = "harvest")
  expect_true(all(result[["N"]] > 0))
})

# summarize_length_freq() type filtering tests ----

test_that("type = 'harvest' returns total N equal to 14 harvest fish", {
  d <- make_design_with_lengths()
  result <- summarize_length_freq(d, type = "harvest")
  expect_equal(sum(result[["N"]]), 14L)
})

test_that("type = 'release' returns total N equal to 23 release fish (expanded from bins)", {
  d <- make_design_with_lengths()
  result <- summarize_length_freq(d, type = "release")
  # walleye: 2+3=5, bass: 4+5=9, panfish: 6+3=9 -> 23 total
  expect_equal(sum(result[["N"]]), 23L)
})

test_that("type = 'catch' returns total N equal to harvest + release = 37", {
  d <- make_design_with_lengths()
  result <- summarize_length_freq(d, type = "catch")
  expect_equal(sum(result[["N"]]), 37L)
})

# summarize_length_freq() by = species tests ----

test_that("by = species adds species column to result", {
  d <- make_design_with_lengths()
  result <- summarize_length_freq(d, type = "harvest", by = species) # nolint: object_usage_linter
  expect_true("species" %in% names(result))
})

test_that("by = species returns three species for harvest", {
  d <- make_design_with_lengths()
  result <- summarize_length_freq(d, type = "harvest", by = species) # nolint: object_usage_linter
  expect_equal(length(unique(result[["species"]])), 3L)
})

test_that("by = species: per-species N sums match known fish counts", {
  d <- make_design_with_lengths()
  result <- summarize_length_freq(d, type = "harvest", by = species) # nolint: object_usage_linter
  n_by_species <- tapply(result[["N"]], result[["species"]], sum)
  expect_equal(n_by_species[["walleye"]], 8L)
  expect_equal(n_by_species[["bass"]], 4L)
  expect_equal(n_by_species[["panfish"]], 2L)
})

test_that("by = species: release N by species matches expanded bin counts", {
  d <- make_design_with_lengths()
  result <- summarize_length_freq(d, type = "release", by = species) # nolint: object_usage_linter
  n_by_species <- tapply(result[["N"]], result[["species"]], sum)
  expect_equal(n_by_species[["walleye"]], 5L)
  expect_equal(n_by_species[["bass"]], 9L)
  expect_equal(n_by_species[["panfish"]], 9L)
})

# summarize_length_freq() bin_width tests ----

test_that("bin_width = 1 produces 1mm-wide bins (default)", {
  d <- make_design_with_lengths()
  result <- summarize_length_freq(d, type = "harvest") # bin_width = 1 default
  bins <- levels(result[["length_bin"]])[1] # first occupied bin
  # Label like "[155,156)" spans 1mm
  lower <- as.numeric(sub("\\[([0-9.]+),.*", "\\1", bins))
  upper <- as.numeric(sub(".*,([0-9.]+).*", "\\1", bins))
  expect_equal(upper - lower, 1, tolerance = 1e-10)
})

test_that("bin_width = 50 produces 50mm-wide bins", {
  d <- make_design_with_lengths()
  result <- summarize_length_freq(d, type = "harvest", bin_width = 50)
  bins <- as.character(levels(result[["length_bin"]]))
  lowers <- as.numeric(sub("\\[([0-9.]+),.*", "\\1", bins))
  uppers <- as.numeric(sub(".*,([0-9.]+).*", "\\1", bins))
  spans <- uppers - lowers
  expect_true(all(abs(spans - 50) < 1e-10))
})

test_that("larger bin_width produces fewer bins than smaller bin_width", {
  d <- make_design_with_lengths()
  r_narrow <- summarize_length_freq(d, type = "harvest", bin_width = 1)
  r_wide <- summarize_length_freq(d, type = "harvest", bin_width = 100)
  expect_true(nrow(r_wide) < nrow(r_narrow))
})

test_that("bin_width = 25: walleye harvest bins span 25mm", {
  d <- make_design_with_lengths()
  result <- summarize_length_freq(
    d,
    type = "harvest", by = species, bin_width = 25 # nolint: object_usage_linter
  )
  walleye <- result[result$species == "walleye", ]
  bins <- as.character(walleye[["length_bin"]])
  lowers <- as.numeric(sub("\\[([0-9.]+),.*", "\\1", bins))
  uppers <- as.numeric(sub(".*,([0-9.]+).*", "\\1", bins))
  expect_true(all(abs((uppers - lowers) - 25) < 1e-10))
})

# summarize_length_freq() pre-binned release handling tests ----

test_that("release type with binned format returns non-empty result (LFREQ-05)", {
  d <- make_design_with_lengths()
  result <- summarize_length_freq(d, type = "release")
  expect_true(nrow(result) > 0)
})

test_that("release bins reflect midpoints of original bin labels", {
  d <- make_design_with_lengths()
  result <- summarize_length_freq(
    d,
    type = "release", by = species, bin_width = 1 # nolint: object_usage_linter
  )
  # walleye midpoints: 375 and 425; with bin_width=1 each fish is at 375 or 425
  walleye <- result[result$species == "walleye", ]
  bin_labels <- as.character(walleye[["length_bin"]])
  # Lower bounds should include 375 and 425 (from "350-400" and "400-450")
  lowers <- as.numeric(sub("\\[([0-9.]+),.*", "\\1", bin_labels))
  expect_true(375 %in% lowers)
  expect_true(425 %in% lowers)
})

test_that("release N is expanded from count: walleye 'count=2' bin has N=2", {
  d <- make_design_with_lengths()
  result <- summarize_length_freq(
    d,
    type = "release", by = species, bin_width = 1 # nolint: object_usage_linter
  )
  walleye <- result[result$species == "walleye", ]
  # "350-400" midpoint=375, count=2 -> expect a bin at 375 with N=2
  lowers <- as.numeric(sub("\\[([0-9.]+),.*", "\\1", as.character(walleye[["length_bin"]])))
  n_at_375 <- walleye$N[lowers == 375]
  expect_equal(n_at_375, 2L)
})

test_that("catch type combines individual harvest + expanded binned release without error", {
  d <- make_design_with_lengths()
  result <- summarize_length_freq(d, type = "catch", by = species) # nolint: object_usage_linter
  expect_true(nrow(result) > 0)
  n_by_species <- tapply(result[["N"]], result[["species"]], sum)
  expect_equal(n_by_species[["walleye"]], 13L) # 8 harvest + 5 release
  expect_equal(n_by_species[["bass"]], 13L) # 4 harvest + 9 release
  expect_equal(n_by_species[["panfish"]], 11L) # 2 harvest + 9 release
})

# summarize_length_freq() cumulative_percent tests ----

test_that("cumulative_percent is non-decreasing within each species", {
  d <- make_design_with_lengths()
  result <- summarize_length_freq(d, type = "harvest", by = species) # nolint: object_usage_linter
  for (sp in unique(result$species)) {
    sub <- result[result$species == sp, ]
    diffs <- diff(sub$cumulative_percent)
    expect_true(
      all(diffs >= -1e-10),
      info = paste("Non-monotone cumulative_percent for species:", sp)
    )
  }
})

test_that("cumulative_percent reaches ~100 at last bin within each species", {
  d <- make_design_with_lengths()
  result <- summarize_length_freq(d, type = "harvest", by = species) # nolint: object_usage_linter
  for (sp in unique(result$species)) {
    sub <- result[result$species == sp, ]
    expect_equal(max(sub$cumulative_percent), 100, tolerance = 0.1)
  }
})

test_that("percent values sum to ~100 within each species", {
  d <- make_design_with_lengths()
  result <- summarize_length_freq(d, type = "catch", by = species) # nolint: object_usage_linter
  for (sp in unique(result$species)) {
    sub <- result[result$species == sp, ]
    expect_equal(sum(sub$percent), 100, tolerance = 0.1)
  }
})

# summarize_length_freq() edge case tests ----

test_that("ungrouped result (by = NULL) returns single block of bins", {
  d <- make_design_with_lengths()
  result <- summarize_length_freq(d, type = "harvest")
  # no species column
  expect_false("species" %in% names(result))
  # overall percent sums to ~100
  expect_equal(sum(result[["percent"]]), 100, tolerance = 0.1)
})

test_that("type = 'release' percent sums to ~100", {
  d <- make_design_with_lengths()
  result <- summarize_length_freq(d, type = "release")
  expect_equal(sum(result[["percent"]]), 100, tolerance = 0.1)
})

test_that("match.arg rejects invalid type", {
  d <- make_design_with_lengths()
  expect_error(summarize_length_freq(d, type = "total"), "arg")
})
