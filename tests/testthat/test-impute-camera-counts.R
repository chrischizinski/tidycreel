# Tests for impute_camera_counts() ----

# Helpers ----

make_camera_counts_clean <- function() {
  data.frame(
    date           = as.Date(c("2024-06-03", "2024-06-04", "2024-06-05",
                               "2024-06-08", "2024-06-09", "2024-06-10")),
    day_type       = c("weekday", "weekday", "weekday", "weekend", "weekend", "weekend"),
    ingress_count  = c(48L, 52L, 43L, 80L, 75L, 88L),
    camera_status  = rep("operational", 6L),
    stringsAsFactors = FALSE
  )
}

make_camera_counts_with_outages <- function() {
  data.frame(
    date           = as.Date(c("2024-06-03", "2024-06-04", "2024-06-05",
                               "2024-06-08", "2024-06-09", "2024-06-10")),
    day_type       = c("weekday", "weekday", "weekday", "weekend", "weekend", "weekend"),
    ingress_count  = c(48L, NA, 43L, 80L, NA, 88L),
    camera_status  = c("operational", "battery_failure", "operational",
                       "operational", "memory_full", "operational"),
    stringsAsFactors = FALSE
  )
}

make_camera_counts_high_miss <- function() {
  # Weekday stratum has 2 out of 3 rows missing (>50%)
  data.frame(
    date           = as.Date(c("2024-06-03", "2024-06-04", "2024-06-05",
                               "2024-06-08", "2024-06-09")),
    day_type       = c("weekday", "weekday", "weekday", "weekend", "weekend"),
    ingress_count  = c(48L, NA, NA, 80L, 75L),
    camera_status  = c("operational", "battery_failure", "memory_full",
                       "operational", "operational"),
    stringsAsFactors = FALSE
  )
}

make_camera_counts_all_missing_stratum <- function() {
  # Weekend stratum has ALL rows as outages (no observed counts)
  data.frame(
    date           = as.Date(c("2024-06-03", "2024-06-04",
                               "2024-06-08", "2024-06-09")),
    day_type       = c("weekday", "weekday", "weekend", "weekend"),
    ingress_count  = c(48L, 43L, NA, NA),
    camera_status  = c("operational", "operational", "battery_failure", "memory_full"),
    stringsAsFactors = FALSE
  )
}

# Input validation ----

test_that("rejects non-data-frame input", {
  expect_error(
    impute_camera_counts(list(a = 1), count_col = "a", strata_col = "b"),
    class = "error"
  )
})

test_that("rejects invalid method argument", {
  counts <- make_camera_counts_with_outages()
  expect_error(
    impute_camera_counts(counts, count_col = "ingress_count",
                         strata_col = "day_type", method = "invalid"),
    class = "error"
  )
})

test_that("aborts when count_col is missing from data", {
  counts <- make_camera_counts_with_outages()
  expect_error(
    impute_camera_counts(counts, count_col = "no_such_col",
                         strata_col = "day_type"),
    class = "rlang_error"
  )
})

test_that("aborts when strata_col is missing from data", {
  counts <- make_camera_counts_with_outages()
  expect_error(
    impute_camera_counts(counts, count_col = "ingress_count",
                         strata_col = "no_such_col"),
    class = "rlang_error"
  )
})

test_that("aborts when status_col is missing from data", {
  counts <- make_camera_counts_with_outages()
  expect_error(
    impute_camera_counts(counts, count_col = "ingress_count",
                         strata_col = "day_type",
                         status_col = "no_such_status"),
    class = "rlang_error"
  )
})

# GLM method (CAMP-01 and CAMP-02) ----

test_that("CAMP-01: returns all rows including imputed ones", {
  counts <- make_camera_counts_with_outages()
  result <- impute_camera_counts(counts, count_col = "ingress_count",
                                 strata_col = "day_type")
  expect_equal(nrow(result), nrow(counts))
})

test_that("CAMP-01: no NA values remain in count column after imputation", {
  counts <- make_camera_counts_with_outages()
  result <- impute_camera_counts(counts, count_col = "ingress_count",
                                 strata_col = "day_type")
  expect_true(all(!is.na(result$ingress_count)))
})

test_that("CAMP-01: .imputed flag column is present in output", {
  counts <- make_camera_counts_with_outages()
  result <- impute_camera_counts(counts, count_col = "ingress_count",
                                 strata_col = "day_type")
  expect_true(".imputed" %in% names(result))
})

test_that("CAMP-02: imputed rows have .imputed = TRUE", {
  counts <- make_camera_counts_with_outages()
  result <- impute_camera_counts(counts, count_col = "ingress_count",
                                 strata_col = "day_type")
  outage_rows <- which(counts$camera_status != "operational" &
                         is.na(counts$ingress_count))
  expect_true(all(result$.imputed[outage_rows]))
})

test_that("CAMP-02: operational rows have .imputed = FALSE", {
  counts <- make_camera_counts_with_outages()
  result <- impute_camera_counts(counts, count_col = "ingress_count",
                                 strata_col = "day_type")
  op_rows <- which(counts$camera_status == "operational")
  expect_true(all(!result$.imputed[op_rows]))
})

test_that("CAMP-03: imputed count column is integer type", {
  counts <- make_camera_counts_with_outages()
  result <- impute_camera_counts(counts, count_col = "ingress_count",
                                 strata_col = "day_type")
  expect_true(is.integer(result$ingress_count))
})

test_that("D-07: original camera_status values are preserved in imputed rows", {
  counts <- make_camera_counts_with_outages()
  result <- impute_camera_counts(counts, count_col = "ingress_count",
                                 strata_col = "day_type")
  # battery_failure row should still show battery_failure
  bat_fail_idx <- which(counts$camera_status == "battery_failure")
  expect_equal(result$camera_status[bat_fail_idx], "battery_failure")
  # memory_full row should still show memory_full
  mem_full_idx <- which(counts$camera_status == "memory_full")
  expect_equal(result$camera_status[mem_full_idx], "memory_full")
})

test_that("clean data (no outages) returns unchanged with .imputed = FALSE everywhere", {
  counts <- make_camera_counts_clean()
  result <- impute_camera_counts(counts, count_col = "ingress_count",
                                 strata_col = "day_type")
  expect_equal(nrow(result), nrow(counts))
  expect_true(all(!result$.imputed))
  expect_equal(result$ingress_count, counts$ingress_count)
})

test_that("imputed counts are positive integers (GLM Poisson predictions)", {
  counts <- make_camera_counts_with_outages()
  result <- impute_camera_counts(counts, count_col = "ingress_count",
                                 strata_col = "day_type")
  imputed_rows <- which(result$.imputed)
  expect_true(all(result$ingress_count[imputed_rows] >= 0L))
})

# Diagnostics (CAMP-04 and CAMP-05) ----

test_that("CAMP-04: warns when missingness > 50% in a stratum", {
  counts <- make_camera_counts_high_miss()
  expect_warning(
    impute_camera_counts(counts, count_col = "ingress_count",
                         strata_col = "day_type"),
    class = "warning"
  )
})

test_that("CAMP-05: aborts when entire stratum has no observed counts", {
  counts <- make_camera_counts_all_missing_stratum()
  expect_error(
    impute_camera_counts(counts, count_col = "ingress_count",
                         strata_col = "day_type"),
    class = "rlang_error"
  )
})

# Output structure ----

test_that("output has same columns as input plus .imputed", {
  counts <- make_camera_counts_with_outages()
  result <- impute_camera_counts(counts, count_col = "ingress_count",
                                 strata_col = "day_type")
  expect_equal(names(result), c(names(counts), ".imputed"))
})

test_that("non-count columns (date, day_type) are preserved unchanged", {
  counts <- make_camera_counts_with_outages()
  result <- impute_camera_counts(counts, count_col = "ingress_count",
                                 strata_col = "day_type")
  expect_equal(result$date, counts$date)
  expect_equal(result$day_type, counts$day_type)
})
