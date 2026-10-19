# GH #414: the lake row of a sectioned catch / harvest / release total summed the
# per-section product variances as if the sections were independent. Sections
# counted on the same days have correlated effort -- a busy day is busy
# everywhere -- so the lake SE was too small whenever they moved together: in a
# 400-replicate simulation (day correlation 0.82) the lake's empirical SD was
# 1.07 x its reported SE, against ~0.95 for each section, and its 95% intervals
# covered 91.5%. Effort's own lake row already carried this covariance.
#
# Pinned here by hand from the raw counts, not by re-deriving the code: the lake
# variance is the sections' own variances plus, for every stratum h,
#   2 * R_Ah * R_Bh * (N_h^2 / n_h) * cov_h(daily count A, daily count B).

lc_design <- function(b_counts) {
  dates <- as.Date("2024-05-06") + 0:13
  cal <- data.frame(date = dates, day_type = rep(c(rep("weekday", 5), rep("weekend", 2)), 2))
  sampled <- c(1, 2, 4, 6, 7, 9, 13, 14) # 5 of 10 weekdays, 3 of 4 weekend days
  s_dates <- dates[sampled]
  s_type <- cal$day_type[sampled]
  d <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter
  d <- add_sections(d, data.frame(section = c("A", "B")), section_col = section) # nolint: object_usage_linter
  counts <- data.frame(
    date = rep(s_dates, 2), day_type = rep(s_type, 2), section = rep(c("A", "B"), each = 8),
    effort_hours = c(c(30, 42, 25, 38, 33, 60, 52, 71), b_counts)
  )
  d <- suppressWarnings(suppressMessages(add_counts(d, counts, count_col = effort_hours))) # nolint: object_usage_linter
  iv <- data.frame(
    date = rep(s_dates, each = 2, times = 2), day_type = rep(s_type, each = 2, times = 2),
    section = rep(c("A", "B"), each = 16),
    hours_fished = rep(c(2, 3.5, 1.5, 4, 2.5, 3, 5, 1, 2, 4.5, 3, 2.5, 1.5, 3, 4, 2), 2),
    catch_total = c(1, 2, 0, 3, 1, 1, 4, 0, 1, 2, 2, 1, 0, 2, 3, 1,
                    0, 1, 1, 0, 2, 0, 1, 0, 0, 1, 1, 0, 1, 0, 2, 1),
    trip_status = "complete"
  )
  iv$trip_duration <- iv$hours_fished
  suppressWarnings(suppressMessages(add_interviews( # nolint: object_usage_linter
    d, iv,
    catch = catch_total, effort = hours_fished, # nolint: object_usage_linter
    trip_status = trip_status, trip_duration = trip_duration # nolint: object_usage_linter
  )))
}

lc_hand_lake_var <- function(d, res) {
  sec <- res[res$section %in% c("A", "B"), ]
  cnt <- d$counts
  n_cal <- table(d$calendar$day_type)
  cross <- 0
  for (h in names(n_cal)) {
    ya <- cnt$effort_hours[cnt$section == "A" & cnt$day_type == h]
    yb <- cnt$effort_hours[cnt$section == "B" & cnt$day_type == h]
    r <- vapply(c("A", "B"), function(s) {
      iv <- d$interviews[d$interviews$section == s & d$interviews$day_type == h, ]
      sum(iv$catch_total) / sum(iv$hours_fished) # ratio of means
    }, numeric(1))
    cross <- cross + 2 * r[["A"]] * r[["B"]] * n_cal[[h]]^2 / length(ya) * stats::cov(ya, yb)
  }
  sum(sec$se^2) + cross
}

test_that("#414: the sectioned lake SE carries the cross-section effort covariance", {
  # B rises and falls with A on the same days.
  d <- lc_design(c(18, 26, 14, 24, 20, 40, 33, 47))
  res <- suppressWarnings(suppressMessages(
    estimate_total_catch(d, target = "period_total") # nolint: object_usage_linter
  ))$estimates
  lake <- res[res$section == ".lake_total", ]
  sec <- res[res$section %in% c("A", "B"), ]
  expect_equal(lake$se^2, lc_hand_lake_var(d, res))
  # The direction that matters: positively correlated sections widen the lake SE
  # beyond the independence sum the old code reported.
  expect_gt(lake$se^2, sum(sec$se^2))
})

test_that("#414: a negatively correlated pair narrows the lake SE", {
  # Same A counts; B = 40 - A / 2, so it moves against A in every stratum.
  d <- lc_design(40 - c(30, 42, 25, 38, 33, 60, 52, 71) / 2)
  res <- suppressWarnings(suppressMessages(
    estimate_total_catch(d, target = "period_total") # nolint: object_usage_linter
  ))$estimates
  lake <- res[res$section == ".lake_total", ]
  expect_equal(lake$se^2, lc_hand_lake_var(d, res))
  expect_lt(lake$se^2, sum(res$se[res$section %in% c("A", "B")]^2))
})

test_that("#414: harvest and release lake rows carry the same term as catch", {
  # Near-twins: the fix has to be in all three files. Each lake SE must exceed
  # its independence sum on the positively correlated pair.
  d <- lc_design(c(18, 26, 14, 24, 20, 40, 33, 47))
  iv <- d$interviews
  iv$iid <- seq_len(nrow(iv))
  iv$kept <- pmax(0, iv$catch_total - 1)
  d2 <- creel_design(d$calendar, date = date, strata = day_type) # nolint: object_usage_linter
  d2 <- add_sections(d2, data.frame(section = c("A", "B")), section_col = section) # nolint: object_usage_linter
  d2 <- suppressWarnings(suppressMessages(add_counts(d2, d$counts, count_col = effort_hours))) # nolint: object_usage_linter
  d2 <- suppressWarnings(suppressMessages(add_interviews( # nolint: object_usage_linter
    d2, iv,
    catch = catch_total, harvest = kept, effort = hours_fished, # nolint: object_usage_linter
    trip_status = trip_status, trip_duration = trip_duration # nolint: object_usage_linter
  )))
  catch_df <- data.frame(
    iid = iv$iid, species = "walleye", count = iv$catch_total - iv$kept, catch_type = "released"
  )
  d2 <- suppressWarnings(suppressMessages(add_catch( # nolint: object_usage_linter
    d2, catch_df,
    catch_uid = iid, interview_uid = iid, species = species, count = count, # nolint: object_usage_linter
    catch_type = catch_type # nolint: object_usage_linter
  )))
  for (fn in list(estimate_total_harvest, estimate_total_release)) { # nolint: object_usage_linter
    res <- suppressWarnings(suppressMessages(fn(d2, target = "period_total")))$estimates
    lake <- res[res$section == ".lake_total", ]
    expect_gt(lake$se^2, sum(res$se[res$section %in% c("A", "B")]^2))
  }
})

# Review findings on the first version of the fix (Codex, DeepSeek). The
# covariance is now built from the shared-day correlation and each section's
# own spread, so it cannot exceed what the section variances allow.

lc_two_sections <- function(counts, cal, ...) {
  d <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter
  d <- add_sections(d, data.frame(section = c("A", "B")), section_col = section) # nolint: object_usage_linter
  suppressWarnings(suppressMessages(add_counts(d, counts, count_col = y, ...))) # nolint: object_usage_linter
}
lc_cells <- function(label, effort, secs = c("A", "B")) {
  stats::setNames(
    lapply(secs, function(s) list(strata = data.frame(day_type = label), effort = effort, rate = 1)),
    secs
  )
}

test_that("#414: partially overlapping day samples cannot give a negative lake variance", {
  # A on days 1-3, B on days 1, 2, 4. The shared days alone imply a covariance
  # (-10000 per pair) larger than the sections' variances (7500 each) allow;
  # the lake variance came out at -5000 and the SE at NaN.
  cal <- data.frame(date = as.Date("2024-06-03") + 0:3, day_type = "x")
  cnt <- data.frame(
    date = as.Date("2024-06-03") + c(0, 1, 2, 0, 1, 3), day_type = "x",
    section = rep(c("A", "B"), each = 3), y = c(0, 100, 50, 100, 0, 50)
  )
  cross <- section_effort_cross_covariance(lc_two_sections(cnt, cal), "sampled_days", lc_cells("x", 150))
  var_section <- 3 * stats::var(c(0, 100, 50))
  expect_gte(2 * var_section + sum(cross), 0)
  expect_gte(sum(cross), -2 * var_section) # |Cov| <= sqrt(Var_A Var_B)
})

test_that("#414: an empty-string stratum label is matched like any other", {
  cal <- data.frame(date = as.Date("2024-06-03") + 0:3, day_type = "x")
  cnt <- data.frame(
    date = as.Date("2024-06-03") + c(0, 1, 2, 0, 1, 3), day_type = "x",
    section = rep(c("A", "B"), each = 3), y = c(0, 100, 50, 100, 0, 50)
  )
  named <- section_effort_cross_covariance(lc_two_sections(cnt, cal), "sampled_days", lc_cells("x", 150))
  cal$day_type <- ""
  cnt$day_type <- ""
  empty <- section_effort_cross_covariance(lc_two_sections(cnt, cal), "sampled_days", lc_cells("", 150))
  expect_equal(empty, named)
})

test_that("#414: a census of days carries no between-day covariance", {
  # Two counts a day put the finite-population correction on an expanded
  # target. With every calendar day counted, the sections' between-day variance
  # is zero, and so must their covariance be.
  cal <- data.frame(date = as.Date("2024-06-03") + 0:2, day_type = "x")
  cnt <- data.frame(
    date = rep(as.Date("2024-06-03") + 0:2, each = 2, times = 2), day_type = "x",
    section = rep(c("A", "B"), each = 6), ct = rep(c("09:00", "15:00"), 6),
    y = rep(c(5, 5, 10, 10, 15, 15), 2)
  )
  d <- lc_two_sections(cnt, cal, count_time_col = ct)
  expect_equal(sum(section_effort_cross_covariance(d, "period_total", lc_cells("x", 60))), 0)
})

test_that("#414: three unevenly overlapping sections report unknown, not certain, shares", {
  # Codex, round 2: A on days 1-3, B on 1, 2, 4, C on 1, 3, 4. The pairwise
  # covariances do not form a valid covariance matrix: the lake variance is
  # positive (1300) but A's share variance is negative, and the share SE was
  # clamped to 0 -- a reported certainty. Now the matrix is checked as a whole.
  cal <- data.frame(date = as.Date("2024-06-03") + 0:3, day_type = "x")
  cnt <- data.frame(
    date = as.Date("2024-06-03") + c(0, 1, 2, 0, 1, 3, 0, 2, 3), day_type = "x",
    section = rep(c("A", "B", "C"), each = 3), y = c(10, 20, 30, 10, 20, 30, 20, 30, 10)
  )
  d <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter
  d <- add_sections(d, data.frame(section = c("A", "B", "C")), section_col = section) # nolint: object_usage_linter
  d <- suppressWarnings(suppressMessages(add_counts(d, cnt, count_col = y))) # nolint: object_usage_linter
  cross <- section_effort_cross_covariance(d, "sampled_days", lc_cells("x", 60, c("A", "B", "C")))
  expect_equal(unname(cross[upper.tri(cross)]), c(200, 200, -200)) # A-B, A-C, B-C
  expect_warning(
    lake <- combine_section_variances( # nolint: object_usage_linter
      d, section_var = rep(300, 3), rate = rep(1, 3), expansion_se = NULL, effort_cross = cross
    ),
    class = "creel_warning_section_covariance_invalid"
  )
  expect_true(is.na(lake$se))
  shares <- section_prop_of_lake_se(rep(60, 3), rep(300, 3), lake$se^2, rowSums(cross)) # nolint: object_usage_linter
  expect_true(all(is.na(shares)))
})

test_that("#414: no stratum column name can collide with the cell values", {
  # Codex, rounds 2 and 3: the cells were columns named effort / rate, then
  # .effort / .rate, and a stratum column of the same name broke the join --
  # and with it every catch total, sectioned or not. The values now sit beside
  # the strata table, never in it.
  for (nm in c("effort", "rate", ".effort", ".rate", "estimate")) {
    e <- data.frame(x = c("hi", "lo"), estimate = c(100, 50))
    r <- data.frame(x = c("lo", "hi"), estimate = c(0.2, 0.5)) # other order
    if (nm != "estimate") names(e)[1] <- names(r)[1] <- nm
    cells <- stratum_cells(e, r, names(e)[1]) # nolint: object_usage_linter
    expect_equal(cells$effort, c(100, 50), info = nm)
    expect_equal(cells$rate, c(0.5, 0.2), info = nm)
  }
})

test_that("#414: an unknown section variance gives an unknown lake SE, not an error", {
  # DeepSeek and Codex, round 3: an NA section variance (e.g. party_size_se =
  # NA) reached eigen() and aborted the whole total.
  d <- structure(list(section_col = "section"), class = "creel_design")
  lake <- combine_section_variances( # nolint: object_usage_linter
    d, section_var = c(300, NA), rate = c(1, 1), expansion_se = NULL,
    effort_cross = matrix(c(0, 50, 50, 0), 2)
  )
  expect_true(is.na(lake$se))
})

test_that("#414: a census section covaries with nothing, whatever the other section's FPC", {
  # Codex, round 3: A has two counts a day on every calendar day (FPC applies,
  # between-day variance 0); B has one count a day (no FPC, variance > 0). The
  # FPC was dropped unless both took it, so a covariance appeared that A's zero
  # variance cannot support, and the lake SE was refused. Each section's own
  # variance now bounds it.
  cal <- data.frame(date = as.Date("2024-06-03") + 0:2, day_type = "x")
  cnt <- data.frame(
    date = c(rep(as.Date("2024-06-03") + 0:2, each = 2), as.Date("2024-06-03") + 0:2),
    day_type = "x", section = c(rep("A", 6), rep("B", 3)),
    ct = c(rep(c("09:00", "15:00"), 3), rep("09:00", 3)),
    y = c(5, 5, 10, 10, 15, 15, 5, 10, 15)
  )
  d <- lc_two_sections(cnt, cal, count_time_col = ct)
  expect_equal(sum(section_effort_cross_covariance(d, "period_total", lc_cells("x", 60))), 0)
})
