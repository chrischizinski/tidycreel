# Tests for validation_report() ----
# Note: requires validate_creel_data() and standardize_species() from M016 S01/S02.

make_counts <- function() {
  data.frame(
    date     = as.Date(c("2024-06-01", "2024-06-02", "2024-06-08")),
    day_type = c("weekday", "weekday", "weekend"),
    count    = c(10L, 14L, 30L),
    stringsAsFactors = FALSE
  )
}

make_interviews <- function() {
  data.frame(
    date      = as.Date(c("2024-06-01", "2024-06-02")),
    fish_kept = c(2L, 5L),
    species   = c("walleye", "bass"),
    stringsAsFactors = FALSE
  )
}

# Input validation ------------------------------------------------------------

test_that("VRPT-01: errors when both counts and interviews are NULL", {
  expect_error(
    validation_report(),
    class = "rlang_error"
  )
})

# Return structure ------------------------------------------------------------

test_that("VRPT-02: returns a creel_validation_report", {
  rpt <- validation_report(counts = make_counts())
  expect_s3_class(rpt, "creel_validation_report")
  expect_s3_class(rpt, "data.frame")
})

test_that("VRPT-03: result has expected columns", {
  rpt <- validation_report(counts = make_counts())
  expect_named(rpt, c("table", "check", "n_pass", "n_warn", "n_fail", "detail"))
})

test_that("VRPT-04: one row per unique table x check combination", {
  rpt <- validation_report(
    counts     = make_counts(),
    interviews = make_interviews()
  )
  combos <- paste(rpt$table, rpt$check)
  expect_equal(length(combos), length(unique(combos)))
})

test_that("VRPT-05: counts-only produces table == 'counts' rows", {
  rpt <- validation_report(counts = make_counts())
  expect_true(all(rpt$table == "counts"))
})

test_that("VRPT-06: both inputs produce rows for both tables", {
  rpt <- validation_report(
    counts     = make_counts(),
    interviews = make_interviews()
  )
  expect_true("counts" %in% rpt$table)
  expect_true("interviews" %in% rpt$table)
})

test_that("VRPT-07: n_pass + n_warn + n_fail > 0 for every row", {
  rpt <- validation_report(counts = make_counts())
  totals <- rpt$n_pass + rpt$n_warn + rpt$n_fail
  expect_true(all(totals > 0L))
})

# Species coverage ------------------------------------------------------------

test_that("VRPT-08: species_col adds a species table row", {
  rpt <- validation_report(
    interviews  = make_interviews(),
    species_col = "species"
  )
  expect_true("species" %in% rpt$table)
})

test_that("VRPT-09: species coverage detail contains percentage", {
  rpt <- validation_report(
    interviews  = make_interviews(),
    species_col = "species"
  )
  sp_row <- rpt[rpt$table == "species", ]
  expect_match(sp_row$detail, "%")
})

test_that("VRPT-10: missing species_col warns and skips species row", {
  expect_warning(
    rpt <- validation_report(
      interviews  = make_interviews(),
      species_col = "nonexistent"
    )
  )
  expect_false("species" %in% rpt$table)
})

test_that("VRPT-11: species_col ignored when interviews is NULL", {
  rpt <- validation_report(
    counts      = make_counts(),
    species_col = "species"
  )
  expect_false("species" %in% rpt$table)
})

# Warn/fail propagation -------------------------------------------------------

test_that("VRPT-12: high NA rate shows in n_warn", {
  df <- data.frame(
    date  = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03")),
    count = c(NA_integer_, NA_integer_, 1L)
  )
  rpt <- validation_report(counts = df, na_threshold = 0.10)
  na_row <- rpt[rpt$check == "na_rate", ]
  expect_true(any(na_row$n_warn > 0L))
})

test_that("VRPT-13: flagged columns named in detail field", {
  df <- data.frame(
    date  = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03")),
    count = c(NA_integer_, NA_integer_, 1L)
  )
  rpt <- validation_report(counts = df, na_threshold = 0.10)
  na_row <- rpt[rpt$check == "na_rate" & rpt$n_warn > 0L, ]
  expect_match(na_row$detail, "count")
})

test_that("VRPT-14: all-ok check shows 'all ok' in detail", {
  rpt <- validation_report(counts = make_counts())
  ok_rows <- rpt[rpt$n_warn == 0L & rpt$n_fail == 0L, ]
  expect_true(all(ok_rows$detail == "all ok"))
})

# S3 methods ------------------------------------------------------------------

test_that("VRPT-15: print returns x invisibly", {
  rpt <- validation_report(counts = make_counts())
  returned <- suppressMessages(print(rpt))
  expect_identical(returned, rpt)
})

test_that("VRPT-16: as.data.frame strips class", {
  rpt   <- validation_report(counts = make_counts())
  plain <- as.data.frame(rpt)
  expect_false(inherits(plain, "creel_validation_report"))
  expect_s3_class(plain, "data.frame")
})
