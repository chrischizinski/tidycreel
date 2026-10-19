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
