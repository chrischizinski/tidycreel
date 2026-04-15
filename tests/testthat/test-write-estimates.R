# Tests for write_estimates() -------------------------------------------------

# Helper: build a minimal creel_estimates object
.make_eff <- function() {
  data("example_counts", package = "tidycreel", envir = parent.frame())
  data("example_interviews", package = "tidycreel", envir = parent.frame())
  cal <- unique(example_counts[, c("date", "day_type")]) # nolint: object_usage_linter
  d <- suppressWarnings(
    creel_design(cal, date = date, strata = day_type) # nolint
  )
  d <- suppressWarnings(add_counts(d, example_counts)) # nolint: object_usage_linter
  d <- suppressWarnings(
    add_interviews(
      d, example_interviews, # nolint: object_usage_linter
      catch = catch_total, # nolint: object_usage_linter
      effort = hours_fished, # nolint: object_usage_linter
      trip_status = trip_status # nolint: object_usage_linter
    )
  )
  suppressWarnings(estimate_effort(d))
}

# ---- WRITE-01: CSV output ----------------------------------------------------

test_that("WRITE-01: write_estimates() creates a file at the given path", {
  eff <- .make_eff()
  tmp <- tempfile(fileext = ".csv")
  write_estimates(eff, tmp)
  expect_true(file.exists(tmp))
})

test_that("WRITE-02: CSV output has survey metadata comment lines", {
  eff <- .make_eff()
  tmp <- tempfile(fileext = ".csv")
  write_estimates(eff, tmp)
  lines <- readLines(tmp, n = 6L)
  comment_lines <- grep("^#", lines)
  expect_gte(length(comment_lines), 3L)
})

test_that("WRITE-02b: CSV output includes effort target when present", {
  eff <- .make_eff()
  tmp <- tempfile(fileext = ".csv")
  write_estimates(eff, tmp)
  header <- paste(readLines(tmp, n = 6L), collapse = " ")
  expect_match(header, "Effort target", ignore.case = FALSE)
  expect_match(header, "sampled_days", ignore.case = FALSE)
})

test_that("WRITE-03: CSV comment lines mention method and CI", {
  eff <- .make_eff()
  tmp <- tempfile(fileext = ".csv")
  write_estimates(eff, tmp)
  header <- paste(readLines(tmp, n = 6L), collapse = " ")
  expect_match(header, "CI", ignore.case = FALSE)
  expect_match(header, "Generated")
})

test_that("WRITE-04: CSV data is readable with comment.char='#'", {
  eff <- .make_eff()
  tmp <- tempfile(fileext = ".csv")
  write_estimates(eff, tmp)
  out <- utils::read.csv(tmp, comment.char = "#")
  expect_s3_class(out, "data.frame")
  expect_gt(nrow(out), 0L)
  expect_true("Estimate" %in% names(out))
})

test_that("WRITE-05: write_estimates() accepts a creel_summary object", {
  eff <- .make_eff()
  s <- summary(eff)
  tmp <- tempfile(fileext = ".csv")
  write_estimates(s, tmp)
  expect_true(file.exists(tmp))
  out <- utils::read.csv(tmp, comment.char = "#")
  expect_gt(nrow(out), 0L)
})

test_that("WRITE-06: write_estimates() returns path invisibly", {
  eff <- .make_eff()
  tmp <- tempfile(fileext = ".csv")
  result <- write_estimates(eff, tmp)
  expect_equal(result, tmp)
})

test_that("WRITE-07: overwrite = FALSE raises error when file exists", {
  eff <- .make_eff()
  tmp <- tempfile(fileext = ".csv")
  write_estimates(eff, tmp)
  expect_error(
    write_estimates(eff, tmp, overwrite = FALSE),
    class = "rlang_error"
  )
})

test_that("WRITE-08: overwrite = TRUE silently replaces existing file", {
  eff <- .make_eff()
  tmp <- tempfile(fileext = ".csv")
  write_estimates(eff, tmp)
  expect_no_error(write_estimates(eff, tmp, overwrite = TRUE))
  expect_true(file.exists(tmp))
})

test_that("WRITE-09: unsupported extension raises informative error", {
  eff <- .make_eff()
  tmp <- tempfile(fileext = ".json")
  expect_error(
    write_estimates(eff, tmp),
    regexp = "format"
  )
})

test_that("WRITE-10: non-creel object raises informative error", {
  expect_error(
    write_estimates(list(a = 1), tempfile(fileext = ".csv")),
    class = "rlang_error"
  )
})
