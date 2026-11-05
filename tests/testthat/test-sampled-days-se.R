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

test_that("bootstrap and jackknife on a census of days keep a finite interval (#507)", {
  # Every stratum a census: nothing to resample. A replicate design built here
  # has degf() = 0 and the interval came out NaN beside a finite SE.
  d <- make_507_design(2L)
  taylor <- tidy(suppressWarnings(estimate_effort(d, target = "sampled_days")))
  for (v in c("bootstrap", "jackknife")) {
    r <- tidy(suppressWarnings(estimate_effort(d, target = "sampled_days", variance = v)))
    expect_equal(r$se, taylor$se, info = v)
    expect_true(is.finite(r$ci_lower) && is.finite(r$ci_upper), info = v)
    expect_equal(r$ci_lower, taylor$ci_lower, info = v)
  }
})

test_that("expanded targets are labelled two_stage unless every day was sampled (#507)", {
  # Eight weekdays, two counts a day. Sampling four of them leaves a day-to-day
  # term (reduced by the correction) beside the within-day term: both are in
  # the SE, so "within_day" would misstate it.
  cal <- data.frame(
    date = as.Date("2024-06-03") + 0:7, day_type = "weekday", stringsAsFactors = FALSE
  )
  build <- function(n_days) {
    days <- cal$date[seq_len(n_days)]
    counts <- data.frame(
      date = rep(days, each = 2L), day_type = "weekday",
      count_time = rep(c("am", "pm"), n_days),
      angler_count = rep(c(10, 14), n_days) + rep(seq_len(n_days) * 10, each = 2L),
      stringsAsFactors = FALSE
    )
    add_counts(
      creel_design(cal, date = date, strata = day_type), counts,
      count_col = "angler_count", count_time_col = count_time
    )
  }

  part <- tidy(suppressWarnings(estimate_effort(build(4L), target = "period_total")))
  expect_equal(part$se_basis, "two_stage")
  # The label is true only if both components are in the SE.
  expect_gt(part$se_between, 0)
  expect_gt(part$se_within, 0)

  full <- tidy(suppressWarnings(estimate_effort(build(8L), target = "period_total")))
  expect_equal(full$se_basis, "within_day")
  expect_equal(full$se_between, 0)
})

test_that("unequal counts per day use each day's own within-day variance (#507)", {
  # The pooled Rasmussen form assumes about k_bar counts a day. With 2 and 10 it
  # reported sqrt(2/3) against the exact sqrt(1/2 + 1/10 + 1/2 + 1/10), 25%
  # low -- and on a census of days this term is the whole SE.
  cal <- data.frame(date = as.Date("2024-06-03") + 0:3, day_type = "weekday")
  ks <- c(2L, 10L, 2L, 10L)
  counts <- do.call(rbind, lapply(seq_along(ks), function(i) {
    x <- seq(-1, 1, length.out = ks[i])
    data.frame(
      date = cal$date[i], day_type = "weekday", count_time = paste0("t", seq_len(ks[i])),
      angler_count = 100 + 10 * i + x / stats::sd(x) # sample variance exactly 1
    )
  }))
  d <- add_counts(
    creel_design(cal, date = date, strata = day_type), counts,
    count_col = "angler_count", count_time_col = count_time
  )
  eff <- tidy(suppressWarnings(estimate_effort(d, target = "sampled_days")))
  expect_equal(eff$se_within, sqrt(sum(1 / ks)))
  expect_equal(eff$se, sqrt(sum(1 / ks)))
})

test_that("a grouping column named se_basis is refused (#507)", {
  d <- make_507_design(2L)
  d$counts$se_basis <- d$counts$day_type
  expect_error(
    suppressWarnings(estimate_effort(d, by = se_basis, target = "sampled_days")),
    class = "creel_error_reserved_column"
  )
})

test_that("names the estimators write themselves are refused on every path (#507)", {
  # Sectioned: the section label column is also named se_basis.
  cal <- data.frame(
    date = as.Date("2024-06-03") + 0:3, day_type = "weekday", stringsAsFactors = FALSE
  )
  secs <- c("North", "South")
  d <- creel_design(cal, date = date, strata = day_type)
  d <- add_sections(d, data.frame(se_basis = secs, stringsAsFactors = FALSE), section_col = se_basis)
  counts <- data.frame(
    date = rep(cal$date, times = 2), day_type = "weekday",
    se_basis = rep(secs, each = 4L), angler_count = c(10, 12, 14, 16, 20, 22, 24, 26),
    stringsAsFactors = FALSE
  )
  d <- add_counts(d, counts, count_col = "angler_count")
  expect_error(
    suppressWarnings(estimate_effort(d)),
    class = "creel_error_reserved_column"
  )

  # Bus-route: an interview column named se_basis used as the grouping variable.
  br <- build_br_design_for_tests(4L, 8L, 40L, seed = 11L)
  br$interviews$se_basis <- rep(c("bank", "boat"), length.out = nrow(br$interviews))
  expect_error(
    suppressWarnings(estimate_effort(br, by = se_basis)),
    class = "creel_error_reserved_column"
  )

  # A count column named like the helper column the sampled-day design writes.
  std <- make_507_design(2L)
  std$counts$.fpc_days <- 1
  expect_error(
    suppressWarnings(estimate_effort(std, target = "sampled_days")),
    class = "creel_error_reserved_column"
  )
})

test_that("shared-count-times lake within-day SE weights each day by its own counts (#507)", {
  # Two sections counted at the same times; two days with 2 and 4 counts. On a
  # census of days the lake's within-day variance is, per day, the variance of
  # the mean of the lake's occasion totals: sum_d ss_d / (k_d (k_d - 1)). The
  # cross-covariance used to take one scale from the first day and apply it to
  # the others, which misweights them when k_d differ.
  cal <- data.frame(date = as.Date("2024-06-03") + 0:3, day_type = "weekday")
  times <- list(c(9, 15), c(8, 11, 14, 17))
  days <- cal$date[1:2]
  a <- list(c(10, 16), c(20, 24, 31, 27))
  b <- list(c(30, 41), c(50, 52, 61, 58))
  rows <- do.call(rbind, lapply(1:2, function(i) {
    rbind(
      data.frame(date = days[i], day_type = "weekday", section = "A", count_time = times[[i]], n = a[[i]]),
      data.frame(date = days[i], day_type = "weekday", section = "B", count_time = times[[i]], n = b[[i]])
    )
  }))
  d <- creel_design(cal[1:2, ], date = date, strata = day_type)
  d <- add_sections(d, data.frame(section = c("A", "B")), section_col = section, shared_count_times = TRUE)
  d <- suppressWarnings(add_counts(d, rows, count_col = "n", count_time_col = count_time))
  res <- suppressMessages(suppressWarnings(estimate_effort(d, target = "sampled_days")))$estimates

  hand <- sum(vapply(1:2, function(i) {
    tot <- a[[i]] + b[[i]]
    k <- length(tot)
    sum((tot - mean(tot))^2) / (k * (k - 1))
  }, numeric(1)))
  expect_equal(res$se_within[res$section == ".lake_total"], sqrt(hand))
  expect_gt(res$se[res$section == ".lake_total"], 0)
})

test_that("an empty-string day ID still finds its covariance coefficients (#507)", {
  # The per-section coefficients are looked up by day ID; [[ cannot find a
  # name that is "", which a character PSU column may legitimately hold.
  cal <- data.frame(
    date = as.Date("2024-06-03") + 0:1, day_type = "weekday", day_id = c("", "d2")
  )
  times <- list(c(9, 15), c(8, 11, 14, 17))
  a <- list(c(10, 16), c(20, 24, 31, 27))
  b <- list(c(30, 41), c(50, 52, 61, 58))
  rows <- do.call(rbind, lapply(1:2, function(i) {
    rbind(
      data.frame(date = cal$date[i], day_type = "weekday", day_id = cal$day_id[i],
                 section = "A", count_time = times[[i]], n = a[[i]]),
      data.frame(date = cal$date[i], day_type = "weekday", day_id = cal$day_id[i],
                 section = "B", count_time = times[[i]], n = b[[i]])
    )
  }))
  d <- creel_design(cal, date = date, strata = day_type)
  d <- add_sections(d, data.frame(section = c("A", "B")), section_col = section, shared_count_times = TRUE)
  d <- suppressWarnings(add_counts(d, rows, count_col = "n", count_time_col = count_time, psu = "day_id"))
  res <- suppressMessages(suppressWarnings(estimate_effort(d, target = "sampled_days")))$estimates

  hand <- sum(vapply(1:2, function(i) {
    tot <- a[[i]] + b[[i]]
    k <- length(tot)
    sum((tot - mean(tot))^2) / (k * (k - 1))
  }, numeric(1)))
  expect_equal(res$se_within[res$section == ".lake_total"], sqrt(hand))
})
