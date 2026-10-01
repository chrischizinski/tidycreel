# Binned release lengths recorded in inch groups (GH #372) ----
#
# Agencies record released fish by inch group ("12") with a count, and harvest
# fish in mm. A single-value label crashed both length consumers in base R
# ("subscript out of bounds") before their own message fired. add_lengths() now
# takes the bins' unit and, for single-value labels, their width; the labels are
# converted to mm midpoints by ONE parser that summarize_length_freq() and
# est_length_distribution() share.

rbu_design <- function(release_labels, ...) {
  data(example_calendar, package = "tidycreel")
  data(example_interviews, package = "tidycreel")
  data(example_lengths, package = "tidycreel")
  data(example_catch, package = "tidycreel")
  lens <- example_lengths
  rel <- lens$length_type == "release"
  lens$length[rel] <- rep_len(release_labels, sum(rel))
  suppressWarnings(suppressMessages({
    d <- creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
    d <- add_interviews(d, example_interviews,
      catch = catch_total, effort = hours_fished, harvest = catch_kept, # nolint: object_usage_linter
      trip_status = trip_status # nolint: object_usage_linter
    )
    d <- add_catch(d, example_catch,
      catch_uid = interview_id, interview_uid = interview_id, # nolint: object_usage_linter
      species = species, count = count, catch_type = catch_type # nolint: object_usage_linter
    )
    add_lengths(d, lens,
      length_uid = interview_id, interview_uid = interview_id, # nolint: object_usage_linter
      species = species, length = length, length_type = length_type, # nolint: object_usage_linter
      count = count, release_format = "binned", ... # nolint: object_usage_linter
    )
  }))
}

test_that("an inch group is the same bin as its mm range, in both consumers", {
  # Why: "12" with width 1 inch is 12.0 to under 13 in = 304.8-330.2 mm. If the
  # unit or the lower-bound reading were wrong anywhere, the two designs would
  # place the released fish in different mm bins.
  inch <- rbu_design(c("12", "8", "14"), release_bin_unit = "inch", release_bin_width = 1)
  mm <- rbu_design(c("304.8-330.2", "203.2-228.6", "355.6-381"))

  for (ty in c("release", "catch")) {
    expect_equal(
      as.data.frame(summarize_length_freq(inch, type = ty, by = species, bin_width = 25)),
      as.data.frame(summarize_length_freq(mm, type = ty, by = species, bin_width = 25))
    )
    expect_equal(
      as.data.frame(est_length_distribution(inch, type = ty, bin_width = 25)),
      as.data.frame(est_length_distribution(mm, type = ty, bin_width = 25))
    )
  }
  # 12.5 in = 317.5 mm, in the [300,325) bin -- mm, not inches.
  rel <- summarize_length_freq(inch, type = "release", bin_width = 25)
  expect_true("[300,325)" %in% as.character(rel$length_bin))
})

test_that("a range label is read in the declared unit", {
  expect_equal(release_bin_midpoints_mm("12-13", "inch"), 12.5 * 25.4)
  expect_equal(release_bin_midpoints_mm("30-35", "cm"), 325)
  expect_equal(release_bin_midpoints_mm("300-350"), 325)
})

test_that("a single-value label without a width is refused, not guessed", {
  # Why: "12" names no upper bound; reading it needs a width and a unit the
  # package cannot know. The old code crashed here; it must name the fix.
  d <- rbu_design(c("12", "8"))
  expect_error(
    summarize_length_freq(d, type = "release", bin_width = 25),
    class = "creel_error_release_bin_width_missing"
  )
  expect_error(
    est_length_distribution(d, type = "release", bin_width = 25),
    class = "creel_error_release_bin_width_missing"
  )
  # Harvest lengths need no release bins and still summarise.
  expect_s3_class(summarize_length_freq(d, type = "harvest", bin_width = 25), "data.frame")
})

test_that("an unparseable label is refused with the package's own error", {
  d <- rbu_design(c("12+", "8"), release_bin_unit = "inch", release_bin_width = 1)
  expect_error(
    summarize_length_freq(d, type = "release", bin_width = 25),
    class = "creel_error_release_bin_unparseable"
  )
})

test_that("add_lengths() validates the bin unit and width", {
  expect_error(rbu_design("300-350", release_bin_unit = "feet"), "release_bin_unit")
  expect_error(rbu_design("12", release_bin_unit = "inch", release_bin_width = 0), "release_bin_width")
  # Inf passed a positivity check and only failed later, in seq(), downstream.
  expect_error(rbu_design("12", release_bin_unit = "inch", release_bin_width = Inf), "release_bin_width")
  # Individual lengths have no bins; a unit given there is refused, not ignored.
  data(example_calendar, package = "tidycreel")
  data(example_interviews, package = "tidycreel")
  data(example_lengths, package = "tidycreel")
  harvest_only <- example_lengths[example_lengths$length_type == "harvest", ]
  d <- suppressWarnings(suppressMessages(add_interviews(
    creel_design(example_calendar, date = date, strata = day_type), # nolint: object_usage_linter
    example_interviews,
    catch = catch_total, effort = hours_fished, harvest = catch_kept, # nolint: object_usage_linter
    trip_status = trip_status # nolint: object_usage_linter
  )))
  expect_error(
    add_lengths(d, harvest_only,
      length_uid = interview_id, interview_uid = interview_id, # nolint: object_usage_linter
      species = species, length = length, length_type = length_type, # nolint: object_usage_linter
      release_bin_unit = "inch"
    ),
    "binned release lengths"
  )
})
