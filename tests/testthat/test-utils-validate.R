test_that("tc_require_cols throws error for missing columns", {
  df <- data.frame(a = 1, b = 2)
  expect_error(tc_require_cols(df, c("a", "b", "c")), "Missing columns")
})

test_that("tc_require_cols passes for all present columns", {
  df <- data.frame(a = 1, b = 2)
  expect_invisible(tc_require_cols(df, c("a", "b")))
})

test_that("tc_guess_cols renames synonyms", {
  df <- data.frame(anglers_count = 1)
  synonyms <- c(count = "anglers_count")
  df2 <- tc_guess_cols(df, synonyms)
  expect_true("count" %in% names(df2))
})

test_that("tc_group_warn drops missing grouping columns with warning", {
  df <- data.frame(a = 1, b = 2)
  expect_warning(tc_group_warn(c("a", "c"), names(df)), "Grouping columns dropped")
})

test_that("tc_diag_drop returns correct diagnostics", {
  df_before <- data.frame(a = 1:5)
  df_after <- data.frame(a = 1:3)
  diag <- tc_diag_drop(df_before, df_after, "test drop")
  expect_equal(diag$n_dropped, 2)
  expect_equal(diag$n_remaining, 3)
})
