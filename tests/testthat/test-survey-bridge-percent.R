# Tests for mor_truncation_message() percent formatting
# mor_truncation_message() is defined in R/survey-bridge.R
# After DEPS-01: uses sprintf("%.1f%%", pct * 100) not scales::percent()

test_that("mor_truncation_message produces a warning with percent label", {
  # 10 out of 100 trips truncated = 10.0%
  expect_warning(
    tidycreel:::mor_truncation_message(
      n_truncated = 10L,
      n_incomplete_original = 100L,
      truncate_at = 0.5
    ),
    regexp = "10\\.0%"
  )
})

test_that("mor_truncation_message percent label uses base R sprintf format", {
  # 1 out of 3 truncated = 33.3%
  w <- tryCatch(
    tidycreel:::mor_truncation_message(
      n_truncated = 1L,
      n_incomplete_original = 3L,
      truncate_at = 0.5
    ),
    warning = function(w) w
  )
  expect_true(grepl("33\\.3%", conditionMessage(w)))
})
