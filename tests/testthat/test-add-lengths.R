# Tests for add_lengths() — Phase 30 (LEN-01 through LEN-05)

# --- Shared fixtures -----------------------------------------------------------

make_design_with_interviews <- function() {
  data(example_calendar, package = "tidycreel")
  data(example_interviews, package = "tidycreel")
  d <- suppressWarnings(
    creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  )
  suppressWarnings(
    add_interviews(
      d,
      example_interviews, # nolint: object_usage_linter
      catch = catch_total, # nolint: object_usage_linter
      effort = hours_fished, # nolint: object_usage_linter
      harvest = catch_kept, # nolint: object_usage_linter
      trip_status = trip_status, # nolint: object_usage_linter
      trip_duration = trip_duration # nolint: object_usage_linter
    )
  )
}

# Minimal binned dataset: 2 harvest rows + 2 release rows, interview_id 1
minimal_lengths_binned <- data.frame(
  interview_id = c(1L, 1L, 1L, 1L),
  species = c("walleye", "walleye", "walleye", "walleye"),
  length = c("420", "385", "400-450", "350-400"),
  length_type = c("harvest", "harvest", "release", "release"),
  count = c(NA_integer_, NA_integer_, 3L, 2L),
  stringsAsFactors = FALSE
)

# Minimal individual dataset: harvest and release all numeric
minimal_lengths_individual <- data.frame(
  interview_id = c(1L, 1L),
  species = c("walleye", "walleye"),
  length = c("420", "385"),
  length_type = c("harvest", "release"),
  count = c(NA_integer_, NA_integer_),
  stringsAsFactors = FALSE
)

# --- Happy path (LEN-01) -------------------------------------------------------

test_that("add_lengths() returns a creel_design (LEN-01)", {
  d <- make_design_with_interviews()
  result <- add_lengths(
    d,
    minimal_lengths_binned,
    length_uid = interview_id, # nolint: object_usage_linter
    interview_uid = interview_id, # nolint: object_usage_linter
    species = species, # nolint: object_usage_linter
    length = length, # nolint: object_usage_linter
    length_type = length_type, # nolint: object_usage_linter
    count = count, # nolint: object_usage_linter
    release_format = "binned"
  )
  expect_s3_class(result, "creel_design")
})

test_that("add_lengths() stores data on design$lengths (LEN-01)", {
  d <- make_design_with_interviews()
  result <- add_lengths(
    d,
    minimal_lengths_binned,
    length_uid = interview_id, # nolint: object_usage_linter
    interview_uid = interview_id, # nolint: object_usage_linter
    species = species, # nolint: object_usage_linter
    length = length, # nolint: object_usage_linter
    length_type = length_type, # nolint: object_usage_linter
    count = count, # nolint: object_usage_linter
    release_format = "binned"
  )
  expect_equal(nrow(result[["lengths"]]), 4L)
  expect_true("interview_id" %in% names(result[["lengths"]]))
})

test_that("add_lengths() sets all $lengths_*_col fields (LEN-01)", {
  d <- make_design_with_interviews()
  result <- add_lengths(
    d,
    minimal_lengths_binned,
    length_uid = interview_id, # nolint: object_usage_linter
    interview_uid = interview_id, # nolint: object_usage_linter
    species = species, # nolint: object_usage_linter
    length = length, # nolint: object_usage_linter
    length_type = length_type, # nolint: object_usage_linter
    count = count, # nolint: object_usage_linter
    release_format = "binned"
  )
  expect_equal(result$lengths_uid_col, "interview_id")
  expect_equal(result$lengths_interview_uid_col, "interview_id")
  expect_equal(result$lengths_species_col, "species")
  expect_equal(result$lengths_length_col, "length")
  expect_equal(result$lengths_type_col, "length_type")
  expect_equal(result$lengths_count_col, "count")
  expect_equal(result$lengths_release_format, "binned")
})

test_that("add_lengths() works with example_lengths dataset (LEN-01)", {
  data(example_lengths, package = "tidycreel")
  d <- make_design_with_interviews()
  expect_no_error(
    add_lengths(
      d,
      example_lengths,
      length_uid = interview_id, # nolint: object_usage_linter
      interview_uid = interview_id, # nolint: object_usage_linter
      species = species, # nolint: object_usage_linter
      length = length, # nolint: object_usage_linter
      length_type = length_type, # nolint: object_usage_linter
      count = count, # nolint: object_usage_linter
      release_format = "binned"
    )
  )
})

test_that("add_lengths() works without count arg when release_format is individual (LEN-02)", {
  d <- make_design_with_interviews()
  result <- add_lengths(
    d,
    minimal_lengths_individual,
    length_uid = interview_id, # nolint: object_usage_linter
    interview_uid = interview_id, # nolint: object_usage_linter
    species = species, # nolint: object_usage_linter
    length = length, # nolint: object_usage_linter
    length_type = length_type, # nolint: object_usage_linter
    release_format = "individual"
  )
  expect_s3_class(result, "creel_design")
  expect_null(result$lengths_count_col)
})

test_that("interviews with no length rows are valid (LEN-01)", {
  d <- make_design_with_interviews()
  one_row <- data.frame(
    interview_id = 1L,
    species = "walleye",
    length = "420",
    length_type = "harvest",
    count = NA_integer_,
    stringsAsFactors = FALSE
  )
  result <- add_lengths(
    d,
    one_row,
    length_uid = interview_id, # nolint: object_usage_linter
    interview_uid = interview_id, # nolint: object_usage_linter
    species = species, # nolint: object_usage_linter
    length = length, # nolint: object_usage_linter
    length_type = length_type # nolint: object_usage_linter
  )
  expect_equal(nrow(result[["lengths"]]), 1L)
})

# --- Immutability --------------------------------------------------------------

test_that("add_lengths() does not modify the original design", {
  d <- make_design_with_interviews()
  add_lengths(
    d,
    minimal_lengths_binned,
    length_uid = interview_id, # nolint: object_usage_linter
    interview_uid = interview_id, # nolint: object_usage_linter
    species = species, # nolint: object_usage_linter
    length = length, # nolint: object_usage_linter
    length_type = length_type, # nolint: object_usage_linter
    count = count, # nolint: object_usage_linter
    release_format = "binned"
  )
  expect_null(d[["lengths"]])
})

test_that("add_lengths() errors when lengths already attached", {
  d <- make_design_with_interviews()
  d2 <- add_lengths(
    d,
    minimal_lengths_binned,
    length_uid = interview_id, # nolint: object_usage_linter
    interview_uid = interview_id, # nolint: object_usage_linter
    species = species, # nolint: object_usage_linter
    length = length, # nolint: object_usage_linter
    length_type = length_type, # nolint: object_usage_linter
    count = count, # nolint: object_usage_linter
    release_format = "binned"
  )
  expect_error(
    add_lengths(
      d2,
      minimal_lengths_binned,
      length_uid = interview_id, # nolint: object_usage_linter
      interview_uid = interview_id, # nolint: object_usage_linter
      species = species, # nolint: object_usage_linter
      length = length, # nolint: object_usage_linter
      length_type = length_type, # nolint: object_usage_linter
      count = count, # nolint: object_usage_linter
      release_format = "binned"
    ),
    regexp = "already has length"
  )
})

test_that("add_lengths() errors when no interviews attached", {
  data(example_calendar, package = "tidycreel")
  d <- suppressWarnings(
    creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  )
  expect_error(
    add_lengths(
      d,
      minimal_lengths_binned,
      length_uid = interview_id, # nolint: object_usage_linter
      interview_uid = interview_id, # nolint: object_usage_linter
      species = species, # nolint: object_usage_linter
      length = length, # nolint: object_usage_linter
      length_type = length_type, # nolint: object_usage_linter
      count = count, # nolint: object_usage_linter
      release_format = "binned"
    ),
    regexp = "Interviews must be attached"
  )
})

# --- LEN-03: Interview UID validation ------------------------------------------

test_that("add_lengths() errors on unmatched interview IDs (LEN-03)", {
  d <- make_design_with_interviews()
  bad <- data.frame(
    interview_id = 999L,
    species = "walleye",
    length = "420",
    length_type = "harvest",
    count = NA_integer_,
    stringsAsFactors = FALSE
  )
  expect_error(
    add_lengths(
      d,
      bad,
      length_uid = interview_id, # nolint: object_usage_linter
      interview_uid = interview_id, # nolint: object_usage_linter
      species = species, # nolint: object_usage_linter
      length = length, # nolint: object_usage_linter
      length_type = length_type # nolint: object_usage_linter
    ),
    regexp = "not found in design interviews"
  )
})

# --- LEN-04: length_type normalization and validation -------------------------

test_that("add_lengths() normalizes length_type to lowercase silently (LEN-04)", {
  d <- make_design_with_interviews()
  mixed_case <- data.frame(
    interview_id = c(1L, 1L),
    species = c("walleye", "walleye"),
    length = c("420", "385"),
    length_type = c("Harvest", "HARVEST"),
    count = c(NA_integer_, NA_integer_),
    stringsAsFactors = FALSE
  )
  result <- expect_no_warning(
    add_lengths(
      d,
      mixed_case,
      length_uid = interview_id, # nolint: object_usage_linter
      interview_uid = interview_id, # nolint: object_usage_linter
      species = species, # nolint: object_usage_linter
      length = length, # nolint: object_usage_linter
      length_type = length_type # nolint: object_usage_linter
    )
  )
  expect_true(all(result[["lengths"]]$length_type %in% c("harvest", "release")))
})

test_that("add_lengths() errors on invalid length_type after normalization (LEN-04)", {
  d <- make_design_with_interviews()
  bad_type <- data.frame(
    interview_id = 1L,
    species = "walleye",
    length = "420",
    length_type = "KEPT",
    count = NA_integer_,
    stringsAsFactors = FALSE
  )
  expect_error(
    add_lengths(
      d,
      bad_type,
      length_uid = interview_id, # nolint: object_usage_linter
      interview_uid = interview_id, # nolint: object_usage_linter
      species = species, # nolint: object_usage_linter
      length = length, # nolint: object_usage_linter
      length_type = length_type # nolint: object_usage_linter
    ),
    regexp = "Invalid.*length_type"
  )
})

test_that("add_lengths() errors on invalid release_format (LEN-04)", {
  d <- make_design_with_interviews()
  expect_error(
    add_lengths(
      d,
      minimal_lengths_binned,
      length_uid = interview_id, # nolint: object_usage_linter
      interview_uid = interview_id, # nolint: object_usage_linter
      species = species, # nolint: object_usage_linter
      length = length, # nolint: object_usage_linter
      length_type = length_type, # nolint: object_usage_linter
      release_format = "grouped"
    ),
    regexp = "Invalid.*release_format"
  )
})

test_that("add_lengths() errors when harvest length is non-numeric (LEN-04)", {
  d <- make_design_with_interviews()
  bad <- data.frame(
    interview_id = 1L,
    species = "walleye",
    length = "big",
    length_type = "harvest",
    count = NA_integer_,
    stringsAsFactors = FALSE
  )
  expect_error(
    add_lengths(
      d,
      bad,
      length_uid = interview_id, # nolint: object_usage_linter
      interview_uid = interview_id, # nolint: object_usage_linter
      species = species, # nolint: object_usage_linter
      length = length, # nolint: object_usage_linter
      length_type = length_type # nolint: object_usage_linter
    ),
    regexp = "numeric.*mm"
  )
})

test_that("add_lengths() errors when harvest length is <= 0 (LEN-04)", {
  d <- make_design_with_interviews()
  bad <- data.frame(
    interview_id = 1L,
    species = "walleye",
    length = "0",
    length_type = "harvest",
    count = NA_integer_,
    stringsAsFactors = FALSE
  )
  expect_error(
    add_lengths(
      d,
      bad,
      length_uid = interview_id, # nolint: object_usage_linter
      interview_uid = interview_id, # nolint: object_usage_linter
      species = species, # nolint: object_usage_linter
      length = length, # nolint: object_usage_linter
      length_type = length_type # nolint: object_usage_linter
    ),
    regexp = "positive"
  )
})

test_that("add_lengths() errors when binned release has no count column (LEN-04)", {
  d <- make_design_with_interviews()
  no_count <- data.frame(
    interview_id = c(1L, 1L),
    species = c("walleye", "walleye"),
    length = c("420", "400-450"),
    length_type = c("harvest", "release"),
    stringsAsFactors = FALSE
  )
  expect_error(
    add_lengths(
      d,
      no_count,
      length_uid = interview_id, # nolint: object_usage_linter
      interview_uid = interview_id, # nolint: object_usage_linter
      species = species, # nolint: object_usage_linter
      length = length, # nolint: object_usage_linter
      length_type = length_type, # nolint: object_usage_linter
      release_format = "binned"
    ),
    regexp = "count.*required"
  )
})

test_that("add_lengths() errors when binned release count is NA (LEN-04)", {
  d <- make_design_with_interviews()
  na_count <- data.frame(
    interview_id = c(1L, 1L),
    species = c("walleye", "walleye"),
    length = c("420", "400-450"),
    length_type = c("harvest", "release"),
    count = c(NA_integer_, NA_integer_),
    stringsAsFactors = FALSE
  )
  expect_error(
    add_lengths(
      d,
      na_count,
      length_uid = interview_id, # nolint: object_usage_linter
      interview_uid = interview_id, # nolint: object_usage_linter
      species = species, # nolint: object_usage_linter
      length = length, # nolint: object_usage_linter
      length_type = length_type, # nolint: object_usage_linter
      count = count, # nolint: object_usage_linter
      release_format = "binned"
    ),
    regexp = "count.*not be NA"
  )
})

test_that("add_lengths() errors when binned release count is 0 (LEN-04)", {
  d <- make_design_with_interviews()
  zero_count <- data.frame(
    interview_id = c(1L, 1L),
    species = c("walleye", "walleye"),
    length = c("420", "400-450"),
    length_type = c("harvest", "release"),
    count = c(NA_integer_, 0L),
    stringsAsFactors = FALSE
  )
  expect_error(
    add_lengths(
      d,
      zero_count,
      length_uid = interview_id, # nolint: object_usage_linter
      interview_uid = interview_id, # nolint: object_usage_linter
      species = species, # nolint: object_usage_linter
      length = length, # nolint: object_usage_linter
      length_type = length_type, # nolint: object_usage_linter
      count = count, # nolint: object_usage_linter
      release_format = "binned"
    ),
    regexp = "positive"
  )
})

# Finding 26: the NA guard above claimed "a positive integer count" while nothing
# checked integrality, so a fractional count reached `.fish_count` in
# estimate_length_distribution() and put a fraction of a fish in a bin. Warned, not
# aborted, matching how the party-size validator treats the same category error.
test_that("add_lengths() warns when a binned release count is fractional (LEN-04)", {
  d <- make_design_with_interviews()
  fractional_count <- data.frame(
    interview_id = c(1L, 1L),
    species = c("walleye", "walleye"),
    length = c("420", "400-450"),
    length_type = c("harvest", "release"),
    count = c(NA_real_, 3.5),
    stringsAsFactors = FALSE
  )
  expect_warning(
    add_lengths(
      d,
      fractional_count,
      length_uid = interview_id, # nolint: object_usage_linter
      interview_uid = interview_id, # nolint: object_usage_linter
      species = species, # nolint: object_usage_linter
      length = length, # nolint: object_usage_linter
      length_type = length_type, # nolint: object_usage_linter
      count = count, # nolint: object_usage_linter
      release_format = "binned"
    ),
    regexp = "non-integer"
  )
})

test_that("add_lengths() still accepts a fractional binned count (LEN-04)", {
  # Pins the warn-not-abort call: a fractional count signals a wrong column, but
  # rejecting it would break data that has always been accepted.
  d <- make_design_with_interviews()
  fractional_count <- data.frame(
    interview_id = c(1L, 1L),
    species = c("walleye", "walleye"),
    length = c("420", "400-450"),
    length_type = c("harvest", "release"),
    count = c(NA_real_, 3.5),
    stringsAsFactors = FALSE
  )
  result <- suppressWarnings(
    add_lengths(
      d,
      fractional_count,
      length_uid = interview_id, # nolint: object_usage_linter
      interview_uid = interview_id, # nolint: object_usage_linter
      species = species, # nolint: object_usage_linter
      length = length, # nolint: object_usage_linter
      length_type = length_type, # nolint: object_usage_linter
      count = count, # nolint: object_usage_linter
      release_format = "binned"
    )
  )
  expect_s3_class(result, "creel_design")
  expect_equal(result[["lengths"]][["count"]][2], 3.5)
})

test_that("add_lengths() is silent for whole-number binned counts (LEN-04)", {
  # The warning must not fire on the normal case, or it would train users to
  # ignore it.
  d <- make_design_with_interviews()
  expect_no_warning(
    add_lengths(
      d,
      minimal_lengths_binned,
      length_uid = interview_id, # nolint: object_usage_linter
      interview_uid = interview_id, # nolint: object_usage_linter
      species = species, # nolint: object_usage_linter
      length = length, # nolint: object_usage_linter
      length_type = length_type, # nolint: object_usage_linter
      count = count, # nolint: object_usage_linter
      release_format = "binned"
    )
  )
})

test_that("add_lengths() errors when individual release length is non-numeric (LEN-04)", {
  d <- make_design_with_interviews()
  bad <- data.frame(
    interview_id = c(1L, 1L),
    species = c("walleye", "walleye"),
    length = c("420", "big"),
    length_type = c("harvest", "release"),
    stringsAsFactors = FALSE
  )
  expect_error(
    add_lengths(
      d,
      bad,
      length_uid = interview_id, # nolint: object_usage_linter
      interview_uid = interview_id, # nolint: object_usage_linter
      species = species, # nolint: object_usage_linter
      length = length, # nolint: object_usage_linter
      length_type = length_type, # nolint: object_usage_linter
      release_format = "individual"
    ),
    regexp = "numeric.*individual"
  )
})

# --- LEN-05: print method integration -----------------------------------------

test_that("print shows Length Data section when attached (LEN-05)", {
  data(example_lengths, package = "tidycreel")
  d <- make_design_with_interviews()
  d2 <- add_lengths(
    d,
    example_lengths,
    length_uid = interview_id, # nolint: object_usage_linter
    interview_uid = interview_id, # nolint: object_usage_linter
    species = species, # nolint: object_usage_linter
    length = length, # nolint: object_usage_linter
    length_type = length_type, # nolint: object_usage_linter
    count = count, # nolint: object_usage_linter
    release_format = "binned"
  )
  out <- capture.output(print(d2))
  expect_true(any(grepl("Length Data", out)))
  expect_true(any(grepl("harvest", out)))
  expect_true(any(grepl("release", out)))
})

test_that("print omits Length Data section when not attached (LEN-05)", {
  d <- make_design_with_interviews()
  out <- capture.output(print(d))
  expect_false(any(grepl("Length Data", out)))
})


test_that("the length selector accepts a column not named `length` (GH #127)", {
  # `length` is an argument of this function, so it is a promise in its frame.
  # An unqualified length() call inside the body made R force that promise while
  # looking for a function, and any column name other than `length` aborted with
  # "object 'x' not found" before a single row was read. Every example passed
  # `length = length`, which resolves to base::length, so the whole test suite
  # missed it -- while the two names the fetch layer actually produces,
  # length_mm and length_bin, both failed.
  data(example_calendar)
  data(example_interviews)

  design <- creel_design(example_calendar, date = date, strata = day_type)
  design <- suppressWarnings(add_interviews(design, example_interviews,
    catch = catch_total, effort = hours_fished, harvest = catch_kept,
    trip_status = trip_status, trip_duration = trip_duration
  ))

  lengths_mm <- data.frame(
    interview_id = example_interviews$interview_id[1:3],
    species      = "walleye",
    length_mm    = c(420, 385, 401),
    length_type  = "harvest",
    stringsAsFactors = FALSE
  )

  expect_no_error(
    out <- add_lengths(design, lengths_mm,
      length_uid    = interview_id,
      interview_uid = interview_id,
      species       = species,
      length        = length_mm,
      length_type   = length_type
    )
  )
  expect_equal(out$lengths_length_col, "length_mm")
})

test_that("a binned selector named length_bin resolves too (GH #127)", {
  # The release half of the same defect: the fetch layer names the bin column
  # length_bin, so the binned path was unreachable for exactly the data it was
  # written for.
  data(example_calendar)
  data(example_interviews)

  design <- creel_design(example_calendar, date = date, strata = day_type)
  design <- suppressWarnings(add_interviews(design, example_interviews,
    catch = catch_total, effort = hours_fished, harvest = catch_kept,
    trip_status = trip_status, trip_duration = trip_duration
  ))

  binned <- data.frame(
    interview_id = rep(example_interviews$interview_id[1], 2L),
    species      = "walleye",
    length_bin   = c("300-350", "350-400"),
    count        = c(1, 5),
    length_type  = "release",
    stringsAsFactors = FALSE
  )

  out <- add_lengths(design, binned,
    length_uid     = interview_id,
    interview_uid  = interview_id,
    species        = species,
    length         = length_bin,
    length_type    = length_type,
    count          = count,
    release_format = "binned"
  )

  expect_equal(out$lengths_length_col, "length_bin")
  expect_equal(out$lengths_count_col, "count")
  # The counts reach the summary as fish, not as rows: 1 + 5, never 2.
  freq <- summarize_length_freq(out, type = "release", bin_width = 50)
  expect_equal(sum(freq$N), 6)
})
