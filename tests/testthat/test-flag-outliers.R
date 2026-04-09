# Tests for flag_outliers() — OUTL-01 through OUTL-06

# ---- Shared fixtures ----

make_interview_data <- function() {
  data.frame(
    interview_id = 1:10,
    effort = c(1.0, 2.0, 1.5, 2.5, 2.0, 1.8, 1.2, 1.9, 2.1, 20.0),
    catch = c(2L, 3L, 1L, 4L, 2L, 3L, 1L, 2L, 3L, 50L)
  )
}

# ---- OUTL-01: return structure ----

test_that("flag_outliers() returns a data.frame with required columns", {
  df <- make_interview_data()
  result <- flag_outliers(df, col = effort)
  expect_s3_class(result, "data.frame")
  expect_true("is_outlier" %in% names(result))
  expect_true("outlier_reason" %in% names(result))
  expect_true("fence_low" %in% names(result))
  expect_true("fence_high" %in% names(result))
})

test_that("flag_outliers() preserves all original columns", {
  df <- make_interview_data()
  result <- flag_outliers(df, col = effort)
  expect_true(all(names(df) %in% names(result)))
})

test_that("flag_outliers() returns same number of rows as input", {
  df <- make_interview_data()
  result <- flag_outliers(df, col = effort)
  expect_equal(nrow(result), nrow(df))
})

# ---- OUTL-02: correct flagging ----

test_that("flag_outliers() flags the high outlier in effort", {
  df <- make_interview_data()
  result <- flag_outliers(df, col = effort)
  # Row 10 has effort = 20.0 — should be flagged
  expect_true(result$is_outlier[10L])
})

test_that("flag_outliers() does not flag non-outlier rows", {
  df <- make_interview_data()
  result <- flag_outliers(df, col = effort)
  expect_false(any(result$is_outlier[1:9]))
})

test_that("flag_outliers() flags high outlier in catch", {
  df <- make_interview_data()
  result <- flag_outliers(df, col = catch)
  expect_true(result$is_outlier[10L])
})

test_that("flag_outliers() outlier_reason is character", {
  df <- make_interview_data()
  result <- flag_outliers(df, col = effort)
  expect_type(result$outlier_reason, "character")
  expect_true(nzchar(result$outlier_reason[10L]))
})

# ---- OUTL-03: clean data (no outliers) ----

test_that("flag_outliers() flags nothing when all values within fence", {
  df <- data.frame(effort = c(1.0, 1.5, 2.0, 1.8, 1.2, 1.9, 2.1, 1.7))
  result <- flag_outliers(df, col = effort)
  expect_false(any(result$is_outlier))
})

# ---- OUTL-04: small samples ----

test_that("flag_outliers() returns NA fences and no flags when n < 4", {
  df <- data.frame(effort = c(1.0, 2.0, 50.0))
  result <- flag_outliers(df, col = effort)
  expect_true(all(is.na(result$fence_low)))
  expect_true(all(is.na(result$fence_high)))
  expect_false(any(result$is_outlier))
})

test_that("flag_outliers() handles n = 1 without error", {
  df <- data.frame(effort = 5.0)
  expect_no_error(flag_outliers(df, col = effort))
})

# ---- OUTL-05: empty input ----

test_that("flag_outliers() handles empty data.frame", {
  df <- data.frame(effort = numeric(0))
  result <- flag_outliers(df, col = effort)
  expect_equal(nrow(result), 0L)
  expect_true("is_outlier" %in% names(result))
})

# ---- OUTL-06: custom multiplier ----

test_that("flag_outliers() respects custom k multiplier", {
  df <- make_interview_data()
  # With k=3.0 the high outlier may not be flagged
  result_tight <- flag_outliers(df, col = effort, k = 1.5)
  result_loose <- flag_outliers(df, col = effort, k = 5.0)
  # tight should flag row 10; loose may not
  expect_true(result_tight$is_outlier[10L])
  expect_gte(
    sum(result_tight$is_outlier),
    sum(result_loose$is_outlier)
  )
})

# ---- OUTL-07: fence values are scalar (same for all rows) ----

test_that("fence_low and fence_high are the same for all rows", {
  df <- make_interview_data()
  result <- flag_outliers(df, col = effort)
  expect_equal(length(unique(result$fence_low)), 1L)
  expect_equal(length(unique(result$fence_high)), 1L)
})
