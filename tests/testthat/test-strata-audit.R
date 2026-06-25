# Two-stratum weekday/weekend pilot reference fixture
N_h_ref <- c(weekday = 65, weekend = 28) # nolint: object_name_linter
n_h_ref <- c(weekday = 22, weekend = 14) # nolint: object_name_linter
ybar_h_ref <- c(weekday = 50, weekend = 60) # nolint: object_name_linter
s2_h_ref <- c(weekday = 400, weekend = 500) # nolint: object_name_linter
rse_target_ref <- 0.20

# Pre-computed RSE values (FPC-corrected)
SE_wday <- sqrt((1 - 22 / 65) * 400 / 22) # nolint: object_name_linter
RSE_wday <- SE_wday / 50 # nolint: object_name_linter
SE_wend <- sqrt((1 - 14 / 28) * 500 / 14) # nolint: object_name_linter
RSE_wend <- SE_wend / 60 # nolint: object_name_linter

# --- STRAT-01 / STRAT-04: audit_strata.default ---

test_that("Test A: audit_strata.default returns creel_strata_audit class", {
  result <- audit_strata(N_h_ref, n_h = n_h_ref, ybar_h = ybar_h_ref, s2_h = s2_h_ref) # nolint: object_name_linter
  expect_s3_class(result, "creel_strata_audit")
})

test_that("Test B: $strata has required column names", {
  result <- audit_strata(N_h_ref, n_h = n_h_ref, ybar_h = ybar_h_ref, s2_h = s2_h_ref) # nolint: object_name_linter
  expect_named(
    result$strata,
    c("stratum", "N_h", "n_h", "ybar_h", "s2_h", "RSE", "DEFF", "meets_target")
  ) # nolint: object_name_linter
})

test_that("Test C: weekday RSE matches FPC-corrected reference value", {
  result <- audit_strata(N_h_ref, n_h = n_h_ref, ybar_h = ybar_h_ref, s2_h = s2_h_ref) # nolint: object_name_linter
  expect_equal(
    result$strata$RSE[result$strata$stratum == "weekday"],
    RSE_wday,
    tolerance = 1e-10,
    ignore_attr = TRUE
  ) # nolint: object_name_linter
})

test_that("Test D: weekend RSE matches FPC-corrected reference value", {
  result <- audit_strata(N_h_ref, n_h = n_h_ref, ybar_h = ybar_h_ref, s2_h = s2_h_ref) # nolint: object_name_linter
  expect_equal(
    result$strata$RSE[result$strata$stratum == "weekend"],
    RSE_wend,
    tolerance = 1e-10,
    ignore_attr = TRUE
  ) # nolint: object_name_linter
})

test_that("Test E: $n_total equals sum of n_h", {
  result <- audit_strata(N_h_ref, n_h = n_h_ref, ybar_h = ybar_h_ref, s2_h = s2_h_ref) # nolint: object_name_linter
  expect_equal(result$n_total, as.integer(sum(n_h_ref))) # nolint: object_name_linter
  expect_true(is.integer(result$n_total))
})

test_that("Test F: meets_target is logical and correct for both strata", {
  result <- audit_strata(N_h_ref, n_h = n_h_ref, ybar_h = ybar_h_ref, s2_h = s2_h_ref) # nolint: object_name_linter
  expect_type(result$strata$meets_target, "logical")
  expect_equal(
    result$strata$meets_target[result$strata$stratum == "weekday"],
    RSE_wday <= rse_target_ref,
    ignore_attr = TRUE
  ) # nolint: object_name_linter
  expect_equal(
    result$strata$meets_target[result$strata$stratum == "weekend"],
    RSE_wend <= rse_target_ref,
    ignore_attr = TRUE
  ) # nolint: object_name_linter
})

test_that("Test G: $rse_target equals supplied value", {
  result <- audit_strata(
    N_h_ref,
    n_h = n_h_ref,
    ybar_h = ybar_h_ref,
    s2_h = s2_h_ref, # nolint: object_name_linter
    rse_target = 0.15
  )
  expect_equal(result$rse_target, 0.15)
})

test_that("Test H: unnamed N_h fires checkmate error", {
  expect_error(
    audit_strata(c(65, 28), n_h = n_h_ref, ybar_h = ybar_h_ref, s2_h = s2_h_ref) # nolint: object_name_linter
  )
})

test_that("Test I: mismatched N_h/n_h lengths fires checkmate error", {
  expect_error(
    audit_strata(N_h_ref, n_h = c(weekday = 22L), ybar_h = ybar_h_ref, s2_h = s2_h_ref) # nolint: object_name_linter
  )
})

# --- STRAT-01 / STRAT-04: audit_strata.creel_design ---

local({
  cal <- data.frame(
    date = as.Date(c(
      "2024-01-01",
      "2024-01-02",
      "2024-01-03",
      "2024-01-06",
      "2024-01-07",
      "2024-01-08"
    )),
    day_type = c("weekday", "weekday", "weekday", "weekend", "weekend", "weekend")
  )
  design_base <- creel_design(cal, date = date, strata = day_type)
  counts <- data.frame(
    date = as.Date(c("2024-01-01", "2024-01-02", "2024-01-06", "2024-01-07")),
    day_type = c("weekday", "weekday", "weekend", "weekend"),
    count = c(48L, 52L, 57L, 63L)
  )
  design_with_counts <<- add_counts(design_base, counts)
})

test_that("Test J: audit_strata dispatches to creel_design method", {
  result <- audit_strata(design_with_counts)
  expect_s3_class(result, "creel_strata_audit")
})

test_that("Test K: creel_design method returns same structure as default method", {
  result <- audit_strata(design_with_counts)
  expect_named(
    result$strata,
    c("stratum", "N_h", "n_h", "ybar_h", "s2_h", "RSE", "DEFF", "meets_target")
  ) # nolint: object_name_linter
  expect_true(is.numeric(result$deff))
  expect_true(is.integer(result$n_total))
})

# --- STRAT-02: simulate_strata_collapse ---

# Three-stratum fixture for collapse tests
N_h_3 <- c(early = 30, mid = 30, late = 20) # nolint: object_name_linter
n_h_3 <- c(early = 10, mid = 12, late = 8) # nolint: object_name_linter
ybar_h_3 <- c(early = 40, mid = 45, late = 38) # nolint: object_name_linter
s2_h_3 <- c(early = 300, mid = 320, late = 280) # nolint: object_name_linter
audit_3 <- audit_strata(N_h_3, n_h = n_h_3, ybar_h = ybar_h_3, s2_h = s2_h_3) # nolint: object_name_linter

test_that("Test L: simulate_strata_collapse returns tibble with state column", {
  result <- simulate_strata_collapse(audit_3, merge_strata = c("early", "mid"))
  expect_true(inherits(result, "data.frame"))
  expect_true("state" %in% names(result))
  expect_true(all(c("before", "after") %in% result$state))
})

test_that("Test M: unmerged strata appear identically in before and after", {
  result <- simulate_strata_collapse(audit_3, merge_strata = c("early", "mid"))
  before_late <- result[result$state == "before" & result$stratum == "late", ]
  after_late <- result[result$state == "after" & result$stratum == "late", ]
  expect_equal(nrow(before_late), 1L)
  expect_equal(nrow(after_late), 1L)
  expect_equal(before_late$N_h, after_late$N_h) # nolint: object_name_linter
  expect_equal(before_late$n_h, after_late$n_h)
})

test_that("Test N: merged stratum label is paste(merge_strata, collapse = '+')", {
  result <- simulate_strata_collapse(audit_3, merge_strata = c("early", "mid"))
  after_strata <- result$stratum[result$state == "after"]
  expect_true("early+mid" %in% after_strata)
})

test_that("Test O: unknown stratum in merge_strata fires cli_abort error", {
  expect_error(
    simulate_strata_collapse(audit_3, merge_strata = c("early", "ghost_stratum")),
    regexp = "ghost_stratum"
  )
})

# --- STRAT-03: reallocate_strata ---

test_that("Test P: reallocate_strata returns named integer vector", {
  result <- reallocate_strata(36L, N_h = N_h_ref, s2_h = s2_h_ref) # nolint: object_name_linter
  expect_true(is.integer(result))
  expect_named(result, names(N_h_ref)) # nolint: object_name_linter
})

test_that("Test Q: result length equals number of strata", {
  result <- reallocate_strata(36L, N_h = N_h_ref, s2_h = s2_h_ref) # nolint: object_name_linter
  expect_equal(length(result), length(N_h_ref)) # nolint: object_name_linter
})

test_that("Test R: sum of reallocated n_h is at least n_total (ceiling may overshoot)", {
  result <- reallocate_strata(36L, N_h = N_h_ref, s2_h = s2_h_ref) # nolint: object_name_linter
  expect_true(sum(result) >= 36L)
})

test_that("Test S: Neyman allocation gives more samples to stratum with larger N_h * sqrt(s2_h)", {
  # weekday: 65 * sqrt(400) = 1300; weekend: 28 * sqrt(500) ~= 625.9 -> weekday gets more
  result <- reallocate_strata(36L, N_h = N_h_ref, s2_h = s2_h_ref) # nolint: object_name_linter
  expect_true(result[["weekday"]] > result[["weekend"]])
})

# --- STRAT-05: DEFF ---

test_that("Test T: $deff is a positive numeric scalar", {
  result <- audit_strata(N_h_ref, n_h = n_h_ref, ybar_h = ybar_h_ref, s2_h = s2_h_ref) # nolint: object_name_linter
  expect_true(is.numeric(result$deff))
  expect_equal(length(result$deff), 1L)
  expect_true(result$deff > 0)
})

test_that("Test U: $strata$DEFF column has same length as number of strata", {
  result <- audit_strata(N_h_ref, n_h = n_h_ref, ybar_h = ybar_h_ref, s2_h = s2_h_ref) # nolint: object_name_linter
  expect_equal(length(result$strata$DEFF), length(N_h_ref)) # nolint: object_name_linter
})

test_that("Test V: $deff matches Var_strat / Var_SRS computed from reference values", {
  result <- audit_strata(N_h_ref, n_h = n_h_ref, ybar_h = ybar_h_ref, s2_h = s2_h_ref) # nolint: object_name_linter
  N <- sum(N_h_ref) # nolint: object_name_linter
  n <- sum(n_h_ref)
  s2_overall <- sum(N_h_ref * s2_h_ref) / N # nolint: object_name_linter
  Var_SRS <- (1 - n / N) * s2_overall / n # nolint: object_name_linter
  Var_strat <- sum((N_h_ref / N)^2 * (1 - n_h_ref / N_h_ref) * s2_h_ref / n_h_ref) # nolint: object_name_linter
  deff_ref <- Var_strat / Var_SRS # nolint: object_name_linter
  expect_equal(result$deff, deff_ref, tolerance = 1e-10)
})

# --- Smoke tests ---

test_that("Test W: @examples call runs without error", {
  expect_no_error(
    audit_strata(
      c(weekday = 65, weekend = 28),
      n_h = c(weekday = 22, weekend = 14),
      ybar_h = c(50, 60),
      s2_h = c(400, 500),
      rse_target = 0.20
    )
  )
})

test_that("Test X: reallocate_strata @examples runs without error", {
  expect_no_error(
    reallocate_strata(
      n_total = 36,
      N_h = c(weekday = 65, weekend = 28),
      s2_h = c(400, 500)
    )
  )
})
