# Tests for impute_camera_counts() ----

# Helpers ----

make_camera_counts_clean <- function() {
  data.frame(
    date = as.Date(c(
      "2024-06-03",
      "2024-06-04",
      "2024-06-05",
      "2024-06-08",
      "2024-06-09",
      "2024-06-10"
    )),
    day_type = c("weekday", "weekday", "weekday", "weekend", "weekend", "weekend"),
    ingress_count = c(48L, 52L, 43L, 80L, 75L, 88L),
    camera_status = rep("operational", 6L),
    stringsAsFactors = FALSE
  )
}

make_camera_counts_with_outages <- function() {
  data.frame(
    date = as.Date(c(
      "2024-06-03",
      "2024-06-04",
      "2024-06-05",
      "2024-06-08",
      "2024-06-09",
      "2024-06-10"
    )),
    day_type = c("weekday", "weekday", "weekday", "weekend", "weekend", "weekend"),
    ingress_count = c(48L, NA, 43L, 80L, NA, 88L),
    camera_status = c(
      "operational",
      "battery_failure",
      "operational",
      "operational",
      "memory_full",
      "operational"
    ),
    stringsAsFactors = FALSE
  )
}

make_camera_counts_high_miss <- function() {
  # Weekday stratum has 2 out of 3 rows missing (>50%)
  data.frame(
    date = as.Date(c("2024-06-03", "2024-06-04", "2024-06-05", "2024-06-08", "2024-06-09")),
    day_type = c("weekday", "weekday", "weekday", "weekend", "weekend"),
    ingress_count = c(48L, NA, NA, 80L, 75L),
    camera_status = c(
      "operational",
      "battery_failure",
      "memory_full",
      "operational",
      "operational"
    ),
    stringsAsFactors = FALSE
  )
}

make_camera_counts_all_missing_stratum <- function() {
  # Weekend stratum has ALL rows as outages (no observed counts)
  data.frame(
    date = as.Date(c("2024-06-03", "2024-06-04", "2024-06-08", "2024-06-09")),
    day_type = c("weekday", "weekday", "weekend", "weekend"),
    ingress_count = c(48L, 43L, NA, NA),
    camera_status = c("operational", "operational", "battery_failure", "memory_full"),
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
    impute_camera_counts(
      counts,
      count_col = "ingress_count",
      strata_col = "day_type",
      method = "invalid"
    ),
    class = "error"
  )
})

test_that("aborts when count_col is missing from data", {
  counts <- make_camera_counts_with_outages()
  expect_error(
    impute_camera_counts(counts, count_col = "no_such_col", strata_col = "day_type"),
    class = "rlang_error"
  )
})

test_that("aborts when strata_col is missing from data", {
  counts <- make_camera_counts_with_outages()
  expect_error(
    impute_camera_counts(counts, count_col = "ingress_count", strata_col = "no_such_col"),
    class = "rlang_error"
  )
})

test_that("aborts when status_col is missing from data", {
  counts <- make_camera_counts_with_outages()
  expect_error(
    impute_camera_counts(
      counts,
      count_col = "ingress_count",
      strata_col = "day_type",
      status_col = "no_such_status"
    ),
    class = "rlang_error"
  )
})

# GLM method (CAMP-01 and CAMP-02) ----

test_that("CAMP-01: returns all rows including imputed ones", {
  counts <- make_camera_counts_with_outages()
  result <- impute_camera_counts(counts, count_col = "ingress_count", strata_col = "day_type")
  expect_equal(nrow(result), nrow(counts))
})

test_that("CAMP-01: no NA values remain in count column after imputation", {
  counts <- make_camera_counts_with_outages()
  result <- impute_camera_counts(counts, count_col = "ingress_count", strata_col = "day_type")
  expect_true(all(!is.na(result$ingress_count)))
})

test_that("CAMP-01: .imputed flag column is present in output", {
  counts <- make_camera_counts_with_outages()
  result <- impute_camera_counts(counts, count_col = "ingress_count", strata_col = "day_type")
  expect_true(".imputed" %in% names(result))
})

test_that("CAMP-02: imputed rows have .imputed = TRUE", {
  counts <- make_camera_counts_with_outages()
  result <- impute_camera_counts(counts, count_col = "ingress_count", strata_col = "day_type")
  outage_rows <- which(
    counts$camera_status != "operational" &
      is.na(counts$ingress_count)
  )
  expect_true(all(result$.imputed[outage_rows]))
})

test_that("CAMP-02: operational rows have .imputed = FALSE", {
  counts <- make_camera_counts_with_outages()
  result <- impute_camera_counts(counts, count_col = "ingress_count", strata_col = "day_type")
  op_rows <- which(counts$camera_status == "operational")
  expect_true(all(!result$.imputed[op_rows]))
})

test_that("CAMP-03: imputed count column is integer type", {
  counts <- make_camera_counts_with_outages()
  result <- impute_camera_counts(counts, count_col = "ingress_count", strata_col = "day_type")
  expect_true(is.integer(result$ingress_count))
})

test_that("D-07: original camera_status values are preserved in imputed rows", {
  counts <- make_camera_counts_with_outages()
  result <- impute_camera_counts(counts, count_col = "ingress_count", strata_col = "day_type")
  # battery_failure row should still show battery_failure
  bat_fail_idx <- which(counts$camera_status == "battery_failure")
  expect_equal(result$camera_status[bat_fail_idx], "battery_failure")
  # memory_full row should still show memory_full
  mem_full_idx <- which(counts$camera_status == "memory_full")
  expect_equal(result$camera_status[mem_full_idx], "memory_full")
})

test_that("clean data (no outages) returns unchanged with .imputed = FALSE everywhere", {
  counts <- make_camera_counts_clean()
  result <- impute_camera_counts(counts, count_col = "ingress_count", strata_col = "day_type")
  expect_equal(nrow(result), nrow(counts))
  expect_true(all(!result$.imputed))
  expect_equal(result$ingress_count, counts$ingress_count)
})

test_that("imputed counts are positive integers (GLM Poisson predictions)", {
  counts <- make_camera_counts_with_outages()
  result <- impute_camera_counts(counts, count_col = "ingress_count", strata_col = "day_type")
  imputed_rows <- which(result$.imputed)
  expect_true(all(result$ingress_count[imputed_rows] >= 0L))
})

# Diagnostics (CAMP-04 and CAMP-05) ----

test_that("CAMP-04: warns when missingness > 50% in a stratum", {
  counts <- make_camera_counts_high_miss()
  expect_warning(
    impute_camera_counts(counts, count_col = "ingress_count", strata_col = "day_type"),
    class = "warning"
  )
})

test_that("CAMP-05: aborts when entire stratum has no observed counts", {
  counts <- make_camera_counts_all_missing_stratum()
  # A high-missingness warning fires before the abort (100% missing weekend),
  # so suppress warnings to let expect_error see the error condition.
  expect_error(
    suppressWarnings(
      impute_camera_counts(counts, count_col = "ingress_count", strata_col = "day_type")
    ),
    class = "rlang_error"
  )
})

# Output structure ----

test_that("output has same columns as input plus .imputed", {
  counts <- make_camera_counts_with_outages()
  result <- impute_camera_counts(counts, count_col = "ingress_count", strata_col = "day_type")
  expect_equal(names(result), c(names(counts), ".imputed"))
})

test_that("non-count columns (date, day_type) are preserved unchanged", {
  counts <- make_camera_counts_with_outages()
  result <- impute_camera_counts(counts, count_col = "ingress_count", strata_col = "day_type")
  expect_equal(result$date, counts$date)
  expect_equal(result$day_type, counts$day_type)
})

# GLMM guard (CAMP-02 method guard) ----

test_that("CAMP-02: method = 'glmm' proceeds or errors on missing glmmTMB", {
  counts <- make_camera_counts_with_outages()
  # If glmmTMB is installed the GLMM path runs and returns a data frame.
  # If not installed rlang::check_installed() fires an error mentioning glmmTMB.
  if (requireNamespace("glmmTMB", quietly = TRUE)) {
    result <- suppressWarnings(
      impute_camera_counts(
        counts,
        count_col = "ingress_count",
        strata_col = "day_type",
        method = "glmm"
      )
    )
    expect_s3_class(result, "data.frame")
    expect_true(".imputed" %in% names(result))
  } else {
    expect_error(
      impute_camera_counts(
        counts,
        count_col = "ingress_count",
        strata_col = "day_type",
        method = "glmm"
      ),
      regexp = "glmmTMB"
    )
  }
})

# Schema compatibility (CAMP-03 chain test) ----

test_that("CAMP-03: imputed output passes into add_counts() without column manipulation", {
  counts <- make_camera_counts_with_outages()
  imputed <- impute_camera_counts(counts, count_col = "ingress_count", strata_col = "day_type")
  cal <- data.frame(
    date = imputed$date,
    day_type = imputed$day_type,
    stringsAsFactors = FALSE
  )
  design <- suppressWarnings(
    creel_design(
      cal,
      date = date,
      strata = day_type, # nolint
      survey_type = "camera",
      camera_mode = "counter"
    )
  )
  # Should not error — schema-compatible imputed output
  expect_no_error(
    suppressWarnings(add_counts(design, imputed))
  )
})

# CAMP-04 no-warning boundary ----

test_that("CAMP-04: no warning when missingness <= 50% in all strata", {
  # 1/3 weekday = 33% missing — below the 50% threshold, no warning expected
  counts <- make_camera_counts_with_outages()
  # make_camera_counts_with_outages has 1 outage per stratum (1/3 each = 33%)
  expect_no_warning(
    impute_camera_counts(counts, count_col = "ingress_count", strata_col = "day_type")
  )
})

# CR-01 fix: .imputed false-positive for pre-existing non-NA non-operational rows ----

test_that("CR-01: non-operational row with pre-existing non-NA count is NOT marked .imputed", {
  # A non-operational row that already has a count (manually keyed by biologist)
  # should not be flagged as imputed — only truly NA-before rows should be.
  counts <- data.frame(
    date = as.Date(c(
      "2024-06-01",
      "2024-06-02",
      "2024-06-03",
      "2024-06-04",
      "2024-06-05",
      "2024-06-06"
    )),
    day_type = c("weekday", "weekday", "weekday", "weekend", "weekend", "weekend"),
    ingress_count = c(10L, NA_integer_, 8L, 15L, 12L, NA_integer_),
    camera_status = c(
      "operational",
      "battery_failure",
      "partial_outage",
      "operational",
      "operational",
      "battery_failure"
    ),
    stringsAsFactors = FALSE
  )
  # row 3: non-operational ("partial_outage") but count is already 8 (non-NA)
  # row 2: non-operational + NA => should be imputed
  # row 6: non-operational + NA => should be imputed
  result <- impute_camera_counts(counts, count_col = "ingress_count", strata_col = "day_type")
  # Row 3 (partial_outage, pre-existing count 8) must NOT be marked imputed
  row3 <- result[result$date == as.Date("2024-06-03"), ]
  expect_false(
    row3$.imputed,
    info = "non-operational row with pre-existing count should not be .imputed"
  )
  # Rows 2 and 6 (NA before) MUST be marked imputed
  row2 <- result[result$date == as.Date("2024-06-02"), ]
  row6 <- result[result$date == as.Date("2024-06-06"), ]
  expect_true(row2$.imputed, info = "genuine outage row should be .imputed")
  expect_true(row6$.imputed, info = "genuine outage row should be .imputed")
})
