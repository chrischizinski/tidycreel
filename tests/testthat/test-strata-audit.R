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

test_that("Test R: the allocation spends exactly n_total days (GH #384)", {
  # Why: the function answers "how do I split THESE days". Rounding every
  # stratum up returned a plan for more days than the budget.
  result <- reallocate_strata(36L, N_h = N_h_ref, s2_h = s2_h_ref) # nolint: object_name_linter
  expect_identical(sum(result), 36L)
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

# --- GH #384: a feasible allocation ---

test_that("the day-type example from #384 is a plan the season can carry out", {
  # Why: highuse has 9 days; the old code gave it 10, and the total was 120
  # for a budget of 118. Both made a plan the season could not carry out.
  res <- reallocate_strata(118,
    N_h = c(highuse = 9, weekday = 151, weekend = 54),
    s2_h = c(297452, 57243, 184405)
  )
  expect_identical(sum(res), 118L)
  expect_identical(res[["highuse"]], 9L)
  expect_true(all(res <= c(9, 151, 54)))
})

test_that("awkward weights still sum to n_total", {
  N_h <- c(a = 31, b = 7, c = 12, d = 19, e = 3) # nolint: object_name_linter
  s2 <- c(10, 900, 55, 1, 4000)
  for (n in c(10L, 17L, 33L, 50L, 70L)) {
    res <- reallocate_strata(n, N_h = N_h, s2_h = s2)
    expect_identical(sum(res), n, label = paste("n_total =", n))
    expect_true(all(res <= N_h), label = paste("cap, n_total =", n))
    expect_true(all(res >= pmin(2, N_h)), label = paste("floor, n_total =", n))
  }
})

test_that("a capped stratum's excess goes to the others in Neyman proportion", {
  # Why: capping is not enough on its own; the freed days must go where
  # Neyman allocation would send them, not be dropped or spread evenly.
  N_h <- c(small = 5, x = 100, y = 100) # nolint: object_name_linter
  s2 <- c(1e6, 100, 400) # small would get far more than 5 uncapped
  res <- reallocate_strata(40, N_h = N_h, s2_h = s2)
  expect_identical(res[["small"]], 5L)
  # x : y weights are 100 * 10 : 100 * 20 = 1 : 2, over the remaining 35 days:
  # continuous shares 11.67 and 23.33; rounding moves each by less than 1.
  expect_lt(abs(res[["x"]] - 35 / 3), 1)
  expect_lt(abs(res[["y"]] - 70 / 3), 1)
})

test_that("every stratum keeps at least min_n days so its variance is estimable", {
  # Why: a stratum with one sampled day has no estimable variance.
  N_h <- c(quiet = 40, busy = 40) # nolint: object_name_linter
  res <- reallocate_strata(20, N_h = N_h, s2_h = c(0.01, 1e5))
  expect_identical(res[["quiet"]], 2L)
  expect_identical(sum(res), 20L)
  res3 <- reallocate_strata(20, N_h = N_h, s2_h = c(0.01, 1e5), min_n = 3)
  expect_identical(res3[["quiet"]], 3L)
})

test_that("a stratum with fewer days than min_n is censused, not over-allocated", {
  res <- reallocate_strata(10, N_h = c(one = 1, many = 50), s2_h = c(100, 100))
  expect_identical(res[["one"]], 1L)
  expect_identical(sum(res), 10L)
})

test_that("a census stratum stays a census", {
  # n_total equal to every day there is: each stratum is sampled completely.
  N_h <- c(a = 4, b = 9, c = 2) # nolint: object_name_linter
  res <- reallocate_strata(15, N_h = N_h, s2_h = c(1, 50, 3))
  expect_identical(unname(res), c(4L, 9L, 2L))
})

test_that("an infeasible n_total is refused", {
  # More days than the season has, or fewer than min_n in every stratum.
  expect_error(
    reallocate_strata(100, N_h = c(a = 30, b = 40), s2_h = c(1, 1)),
    class = "creel_error_invalid_input"
  )
  expect_error(
    reallocate_strata(3, N_h = c(a = 30, b = 40), s2_h = c(1, 1)),
    class = "creel_error_invalid_input"
  )
})

test_that("weights spanning many orders of magnitude still spend n_total", {
  # Why: a linear bisection bracket of 1e60 never reached the answer, and the
  # plan came back as 102 days for a budget of 30.
  res <- reallocate_strata(30, N_h = c(a = 50, b = 50, c = 50), s2_h = c(100, 400, 1e-120))
  expect_identical(sum(res), 30L)
  expect_identical(res[["c"]], 2L)
})

test_that("integer-ish doubles do not lose a day to rounding", {
  res <- reallocate_strata(0.29 * 100, N_h = c(weekday = 70, weekend = 30), s2_h = c(400, 500))
  expect_identical(sum(res), 29L)
})

test_that("a missing pilot variance is refused, not crashed on", {
  # audit_strata() reports NA for a stratum with one sampled day.
  expect_error(
    reallocate_strata(16, N_h = c(a = 10, b = 10), s2_h = c(1, NA)),
    "missing or infinite variance",
    class = "creel_error_invalid_input"
  )
})
