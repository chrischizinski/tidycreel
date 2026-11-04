# GH #507: the SE of the total over the sampled days.
#
# With two or more counts a day, the between-day variance of the daily totals
# already contains the within-day variation, and the within-day term was then
# added on top: the same variation counted twice. The sampled days are the
# population of this target (N = n), so the finite-population correction removes
# the day-to-day term and the within-day term is the whole variance.
#
# Reference values below are computed in base R from the fixture, not through
# any tidycreel helper.

make_507_design <- function(weekday_counts_per_day = 2L, with_weekend = FALSE) {
  cal <- data.frame(
    date = as.Date("2024-06-03") + 0:9, # Mon 3 Jun .. Wed 12 Jun
    day_type = ifelse(
      format(as.Date("2024-06-03") + 0:9, "%u") %in% c("6", "7"), "weekend", "weekday"
    ),
    stringsAsFactors = FALSE
  )
  weekday_days <- cal$date[cal$day_type == "weekday"][1:4]
  means <- c(10, 20, 30, 40)
  if (weekday_counts_per_day == 2L) {
    counts <- data.frame(
      date = rep(weekday_days, each = 2L),
      day_type = "weekday",
      count_time = rep(c("am", "pm"), 4L),
      angler_count = as.vector(rbind(means - 3, means + 3)),
      stringsAsFactors = FALSE
    )
  } else {
    counts <- data.frame(
      date = weekday_days, day_type = "weekday", count_time = "am",
      angler_count = means, stringsAsFactors = FALSE
    )
  }
  if (with_weekend) {
    wk <- cal$date[cal$day_type == "weekend"]
    counts <- rbind(counts, data.frame(
      date = wk, day_type = "weekend", count_time = "am",
      angler_count = c(50, 90), stringsAsFactors = FALSE
    ))
  }
  add_counts(
    creel_design(cal, date = date, strata = day_type),
    counts,
    count_col = "angler_count", count_time_col = count_time
  )
}

test_that("sampled_days SE with 2+ counts a day is the within-day term alone (#507)", {
  eff <- tidy(suppressWarnings(estimate_effort(make_507_design(2L), target = "sampled_days")))

  # Independent reference. Each day's two counts are m -/+ 3, so the sample
  # variance within a day is 18; n = 4 days, k = 2 counts: Var = n * s2w / k.
  expected_se <- sqrt(4 * 18 / 2)

  expect_equal(eff$se, expected_se)
  expect_equal(eff$se_within, expected_se)
  # The day-to-day term is removed, not merely shrunk: a census of days has no
  # day-to-day sampling variance.
  expect_equal(eff$se_between, 0)
  expect_equal(eff$se_basis, "within_day")
  # A silent regression to the double count would give sqrt(between^2 + within^2)
  # > within; the equality above fails on it.
  expect_lt(eff$se, sqrt(expected_se^2 + 4 * stats::var(c(10, 20, 30, 40))))
})

test_that("sampled_days SE with one count a day is unchanged and labelled an upper bound (#507)", {
  eff <- tidy(suppressWarnings(estimate_effort(make_507_design(1L), target = "sampled_days")))

  # Unit weights, no FPC: Var(total) = n^2 * s^2 / n = n * s^2.
  expect_equal(eff$se, sqrt(4 * stats::var(c(10, 20, 30, 40))))
  expect_equal(eff$se_basis, "between_day_upper_bound")
  # Never NA: the within-day variance is unknown, the day-to-day one still stands.
  expect_false(is.na(eff$se))
  expect_gt(eff$se, 0)
})

test_that("a design mixing 2-count and 1-count strata is labelled per group and mixed overall (#507)", {
  d <- make_507_design(2L, with_weekend = TRUE)

  total <- tidy(suppressWarnings(estimate_effort(d, target = "sampled_days")))
  expect_equal(total$se_basis, "mixed")

  by <- tidy(suppressWarnings(estimate_effort(d, by = day_type, target = "sampled_days")))
  basis <- stats::setNames(by$se_basis, by$day_type)
  expect_equal(basis[["weekday"]], "within_day")
  expect_equal(basis[["weekend"]], "between_day_upper_bound")
  # The weekday row's SE is the weekday within-day term alone.
  expect_equal(by$se[by$day_type == "weekday"], sqrt(4 * 18 / 2))
})

test_that("bus-route effort is always labelled between_day_upper_bound (#507)", {
  d <- build_br_design_for_tests(4L, 8L, 40L, seed = 11L)
  eff <- tidy(suppressWarnings(estimate_effort(d)))
  expect_equal(eff$se_basis, "between_day_upper_bound")
})
