# Tests for add_catch() — Phase 29 (CATCH-01 through CATCH-05)

# --- Shared fixtures -----------------------------------------------------------

make_design_with_interviews <- function() {
  data(example_calendar, package = "tidycreel")
  data(example_interviews, package = "tidycreel")
  d <- suppressWarnings(
    creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  )
  suppressWarnings(
    add_interviews(d, example_interviews, # nolint: object_usage_linter
      catch = catch_total, # nolint: object_usage_linter
      effort = hours_fished, # nolint: object_usage_linter
      harvest = catch_kept, # nolint: object_usage_linter
      trip_status = trip_status, # nolint: object_usage_linter
      trip_duration = trip_duration # nolint: object_usage_linter
    )
  )
}

minimal_catch <- data.frame(
  interview_id = c(1L, 1L),
  species = c("walleye", "walleye"),
  count = c(5L, 2L),
  catch_type = c("caught", "harvested"),
  stringsAsFactors = FALSE
)

# --- Happy path ----------------------------------------------------------------

test_that("add_catch() returns a creel_design", {
  d <- make_design_with_interviews()
  result <- add_catch(d, minimal_catch,
    catch_uid = interview_id, interview_uid = interview_id, # nolint: object_usage_linter
    species = species, count = count, catch_type = catch_type # nolint: object_usage_linter
  )
  expect_s3_class(result, "creel_design")
})

test_that("add_catch() stores catch data on design$catch", {
  d <- make_design_with_interviews()
  result <- add_catch(d, minimal_catch,
    catch_uid = interview_id, interview_uid = interview_id, # nolint: object_usage_linter
    species = species, count = count, catch_type = catch_type # nolint: object_usage_linter
  )
  expect_equal(nrow(result$catch), 2L)
  expect_true("interview_id" %in% names(result$catch))
})

test_that("add_catch() sets all $catch_*_col fields", {
  d <- make_design_with_interviews()
  result <- add_catch(d, minimal_catch,
    catch_uid = interview_id, interview_uid = interview_id, # nolint: object_usage_linter
    species = species, count = count, catch_type = catch_type # nolint: object_usage_linter
  )
  expect_equal(result$catch_uid_col, "interview_id")
  expect_equal(result$catch_interview_uid_col, "interview_id")
  expect_equal(result$catch_species_col, "species")
  expect_equal(result$catch_count_col, "count")
  expect_equal(result$catch_type_col, "catch_type")
})

test_that("add_catch() works with example_catch dataset (CATCH-01)", {
  data(example_catch, package = "tidycreel")
  d <- make_design_with_interviews()
  expect_no_error(
    add_catch(d, example_catch,
      catch_uid = interview_id, interview_uid = interview_id, # nolint: object_usage_linter
      species = species, count = count, catch_type = catch_type # nolint: object_usage_linter
    )
  )
})

test_that("interviews with no catch rows are valid (CATCH-01)", {
  d <- make_design_with_interviews()
  one_row <- data.frame(
    interview_id = 1L, species = "walleye", count = 5L,
    catch_type = "caught", stringsAsFactors = FALSE
  )
  result <- add_catch(d, one_row,
    catch_uid = interview_id, interview_uid = interview_id, # nolint: object_usage_linter
    species = species, count = count, catch_type = catch_type # nolint: object_usage_linter
  )
  expect_equal(nrow(result$catch), 1L)
})

# --- Immutability --------------------------------------------------------------

test_that("add_catch() does not modify the original design", {
  d <- make_design_with_interviews()
  add_catch(d, minimal_catch,
    catch_uid = interview_id, interview_uid = interview_id, # nolint: object_usage_linter
    species = species, count = count, catch_type = catch_type # nolint: object_usage_linter
  )
  expect_null(d[["catch"]])
})

test_that("add_catch() errors when catch already attached", {
  d <- make_design_with_interviews()
  d2 <- add_catch(d, minimal_catch,
    catch_uid = interview_id, interview_uid = interview_id, # nolint: object_usage_linter
    species = species, count = count, catch_type = catch_type # nolint: object_usage_linter
  )
  expect_error(
    add_catch(d2, minimal_catch,
      catch_uid = interview_id, interview_uid = interview_id, # nolint: object_usage_linter
      species = species, count = count, catch_type = catch_type # nolint: object_usage_linter
    ),
    regexp = "already has catch"
  )
})

test_that("add_catch() errors when no interviews attached", {
  data(example_calendar, package = "tidycreel")
  d <- suppressWarnings(
    creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  )
  expect_error(
    add_catch(d, minimal_catch,
      catch_uid = interview_id, interview_uid = interview_id, # nolint: object_usage_linter
      species = species, count = count, catch_type = catch_type # nolint: object_usage_linter
    ),
    regexp = "Interviews must be attached"
  )
})

# --- CATCH-02: Interview UID validation ----------------------------------------

test_that("add_catch() errors on unmatched interview IDs (CATCH-02)", {
  d <- make_design_with_interviews()
  bad <- data.frame(
    interview_id = 999L, species = "walleye", count = 1L,
    catch_type = "caught", stringsAsFactors = FALSE
  )
  expect_error(
    add_catch(d, bad,
      catch_uid = interview_id, interview_uid = interview_id, # nolint: object_usage_linter
      species = species, count = count, catch_type = catch_type # nolint: object_usage_linter
    ),
    regexp = "not found in design interviews"
  )
})

# --- CATCH-03: catch_type normalization and validation -------------------------

test_that("add_catch() normalizes catch_type to lowercase silently (CATCH-03)", {
  d <- make_design_with_interviews()
  mixed_case <- data.frame(
    interview_id = c(1L, 1L),
    species = c("walleye", "walleye"),
    count = c(5L, 2L),
    catch_type = c("Caught", "HARVESTED"),
    stringsAsFactors = FALSE
  )
  result <- expect_no_warning(
    add_catch(d, mixed_case,
      catch_uid = interview_id, interview_uid = interview_id, # nolint: object_usage_linter
      species = species, count = count, catch_type = catch_type # nolint: object_usage_linter
    )
  )
  expect_true(all(result$catch$catch_type %in% c("caught", "harvested", "released")))
})

test_that("add_catch() errors on invalid catch_type after normalization (CATCH-03)", {
  d <- make_design_with_interviews()
  bad_type <- data.frame(
    interview_id = 1L, species = "walleye", count = 1L,
    catch_type = "KEPT",
    stringsAsFactors = FALSE
  )
  expect_error(
    add_catch(d, bad_type,
      catch_uid = interview_id, interview_uid = interview_id, # nolint: object_usage_linter
      species = species, count = count, catch_type = catch_type # nolint: object_usage_linter
    ),
    regexp = "Invalid.*catch_type"
  )
})

# --- CATCH-04: caught >= harvested + released ----------------------------------

test_that("add_catch() errors when caught < harvested (CATCH-04)", {
  d <- make_design_with_interviews()
  bad <- data.frame(
    interview_id = c(1L, 1L),
    species = c("walleye", "walleye"),
    count = c(1L, 5L),
    catch_type = c("caught", "harvested"),
    stringsAsFactors = FALSE
  )
  expect_error(
    add_catch(d, bad,
      catch_uid = interview_id, interview_uid = interview_id, # nolint: object_usage_linter
      species = species, count = count, catch_type = catch_type # nolint: object_usage_linter
    ),
    regexp = "Harvest \\+ release exceeds"
  )
})

test_that("add_catch() errors when caught < released (CATCH-04)", {
  d <- make_design_with_interviews()
  bad <- data.frame(
    interview_id = c(1L, 1L),
    species = c("walleye", "walleye"),
    count = c(2L, 5L),
    catch_type = c("caught", "released"),
    stringsAsFactors = FALSE
  )
  expect_error(
    add_catch(d, bad,
      catch_uid = interview_id, interview_uid = interview_id, # nolint: object_usage_linter
      species = species, count = count, catch_type = catch_type # nolint: object_usage_linter
    ),
    regexp = "Harvest \\+ release exceeds"
  )
})

test_that("add_catch() allows harvested rows with no caught row (CATCH-04)", {
  d <- make_design_with_interviews()
  harvest_only <- data.frame(
    interview_id = 1L, species = "walleye", count = 5L,
    catch_type = "harvested", stringsAsFactors = FALSE
  )
  expect_no_error(
    add_catch(d, harvest_only,
      catch_uid = interview_id, interview_uid = interview_id, # nolint: object_usage_linter
      species = species, count = count, catch_type = catch_type # nolint: object_usage_linter
    )
  )
})

test_that("add_catch() allows caught == harvested + released (CATCH-04)", {
  d <- make_design_with_interviews()
  exact <- data.frame(
    interview_id = c(1L, 1L, 1L),
    species = c("walleye", "walleye", "walleye"),
    count = c(5L, 3L, 2L),
    catch_type = c("caught", "harvested", "released"),
    stringsAsFactors = FALSE
  )
  expect_no_error(
    add_catch(d, exact,
      catch_uid = interview_id, interview_uid = interview_id, # nolint: object_usage_linter
      species = species, count = count, catch_type = catch_type # nolint: object_usage_linter
    )
  )
})

# --- CATCH-05: print method integration ----------------------------------------

test_that("print shows Catch Data section when attached (CATCH-05)", {
  data(example_catch, package = "tidycreel")
  d <- make_design_with_interviews()
  d2 <- add_catch(d, example_catch,
    catch_uid = interview_id, interview_uid = interview_id, # nolint: object_usage_linter
    species = species, count = count, catch_type = catch_type # nolint: object_usage_linter
  )
  out <- capture.output(print(d2))
  expect_true(any(grepl("Catch Data", out)))
  expect_true(any(grepl("species", out)))
})

test_that("print omits Catch Data section when not attached (CATCH-05)", {
  d <- make_design_with_interviews()
  out <- capture.output(print(d))
  expect_false(any(grepl("Catch Data", out)))
})

# --- Consistency check ---------------------------------------------------------

test_that("add_catch() warns when catch totals diverge from interview-level catch", {
  d <- make_design_with_interviews()
  diverged <- data.frame(
    interview_id = 1L, species = "walleye", count = 99L,
    catch_type = "caught", stringsAsFactors = FALSE
  )
  expect_warning(
    add_catch(d, diverged,
      catch_uid = interview_id, interview_uid = interview_id, # nolint: object_usage_linter
      species = species, count = count, catch_type = catch_type # nolint: object_usage_linter
    ),
    regexp = "diverge"
  )
})
