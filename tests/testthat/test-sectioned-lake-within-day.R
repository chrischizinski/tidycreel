# GH #599: the sectioned lake row's within-day terms.
#
# 1. The lake row is estimated on the pooled counts, so a stratum where any
#    section has a one-count day takes no finite-population correction there
#    (#505), and its uncorrected day-to-day term already holds every section's
#    within-day variation. It also added the 2+-count sections' within-day
#    terms: the double count #405 removed everywhere else.
# 2. A section's share of the lake total took its SE from svyratio() on the
#    day-to-day design only. With 2+ counts a day on sampled_days (a census of
#    days) that was exactly 0. The within-day part is now added by the delta
#    method on p = S / T.
#
# Reference values are computed in base R from the counts below.

q599 <- function(x) suppressWarnings(suppressMessages(x))

# Ten weekdays and four weekend days; four weekdays and two weekend days sampled.
make_599 <- function(k_north, k_south, k_weekend = 2L) {
  cal <- data.frame(date = as.Date("2024-06-03") + 0:13)
  cal$day_type <- ifelse(format(cal$date, "%u") %in% c("6", "7"), "weekend", "weekday")
  wd <- cal$date[cal$day_type == "weekday"][1:4]
  we <- cal$date[cal$day_type == "weekend"][1:2]
  day_rows <- function(dates, dt, sec, means, k, step) {
    do.call(rbind, lapply(seq_along(dates), function(i) {
      data.frame(
        date = dates[i], day_type = dt, section = sec,
        t = sprintf("t%d", seq_len(k)),
        n = means[i] + (seq_len(k) - (k + 1) / 2) * step
      )
    }))
  }
  cnt <- rbind(
    day_rows(wd, "weekday", "North", c(12, 25, 31, 44), k_north, 2),
    day_rows(wd, "weekday", "South", c(9, 4, 13, 7), k_south, 3),
    day_rows(we, "weekend", "North", c(60, 70), k_weekend, 4),
    day_rows(we, "weekend", "South", c(20, 15), k_weekend, 2)
  )
  d <- creel_design(cal, date = date, strata = day_type)
  d <- add_sections(d, data.frame(section = c("North", "South")), section_col = section)
  list(design = q599(add_counts(d, cnt, count_col = n, count_time_col = t)), counts = cnt)
}

# sum over days of var(y_d) / k_d, for one section and stratum
within_sum <- function(cnt, sec, dt) {
  x <- cnt[cnt$section == sec & cnt$day_type == dt, ]
  per_day <- split(x$n, x$date)
  sum(vapply(per_day, function(y) if (length(y) < 2) 0 else stats::var(y) / length(y), numeric(1)))
}

lake_row <- function(e) e[e$section == ".lake_total", ]

test_that("a stratum some section counted once adds no within-day term to the lake (#599)", {
  f <- make_599(k_north = 2L, k_south = 1L)
  e <- q599(estimate_effort(f$design, target = "sampled_days"))$estimates
  lake <- lake_row(e)
  # Weekday is uncorrected in the pooled design (South counted once), so only
  # the weekend, where both sections have 2 counts, contributes. On
  # sampled_days the within-day term is sum_d var/k_d, summed over sections.
  expected_within <- within_sum(f$counts, "North", "weekend") + within_sum(f$counts, "South", "weekend")
  expect_equal(lake$se_within^2, expected_within)
  expect_equal(lake$se, sqrt(lake$se_between^2 + lake$se_within^2))
  # The section rows are unchanged by the lake's rule: North still carries its
  # weekday within-day term.
  north <- e[e$section == "North", ]
  expect_equal(
    north$se_within^2,
    within_sum(f$counts, "North", "weekday") + within_sum(f$counts, "North", "weekend")
  )
  expect_equal(lake$se_basis, "mixed")
})

test_that("with every stratum uncorrected the lake row is the day-to-day bound alone (#599)", {
  f <- make_599(k_north = 2L, k_south = 1L, k_weekend = 1L)
  for (target in c("sampled_days", "stratum_total")) {
    lake <- lake_row(q599(estimate_effort(f$design, target = target))$estimates)
    # Not identified on the lake row either: NA, not a measured 0 (#504).
    expect_true(is.na(lake$se_within), label = target)
    expect_equal(lake$se, lake$se_between, label = target)
    expect_equal(lake$se_basis, "between_day_upper_bound", label = target)
  }
})

test_that("a share's SE includes the within-day part (#599)", {
  f <- make_599(k_north = 2L, k_south = 2L)
  e <- q599(estimate_effort(f$design, target = "sampled_days"))$estimates
  secs <- e[e$section %in% c("North", "South"), ]
  total <- sum(secs$estimate)
  v_n <- within_sum(f$counts, "North", "weekday") + within_sum(f$counts, "North", "weekend")
  v_s <- within_sum(f$counts, "South", "weekday") + within_sum(f$counts, "South", "weekend")
  p <- secs$estimate[secs$section == "North"] / total
  within_share <- ((1 - p)^2 * v_n + p^2 * v_s) / total^2
  # Every stratum is a census of days here, so the day-to-day part is 0 and
  # the share SE is the within-day part alone -- 0 before #599.
  expect_equal(secs$se_prop_of_lake_total[secs$section == "North"], sqrt(within_share))
  expect_gt(secs$se_prop_of_lake_total[secs$section == "North"], 0)
  # Two sections: their shares sum to 1, so they share one SE.
  expect_equal(secs$se_prop_of_lake_total[1], secs$se_prop_of_lake_total[2])
})

test_that("one count a day leaves the share SE at its day-to-day value (#599)", {
  f <- make_599(k_north = 1L, k_south = 1L, k_weekend = 1L)
  e <- q599(estimate_effort(f$design, target = "sampled_days"))$estimates
  ratio <- tidycreel:::section_prop_of_lake(
    tidycreel:::get_variance_design(tidycreel:::get_effort_target_design(f$design, "sampled_days"), "taylor"),
    "n", "section", "North"
  )
  expect_equal(e$se_prop_of_lake_total[e$section == "North"], ratio$se)
})
