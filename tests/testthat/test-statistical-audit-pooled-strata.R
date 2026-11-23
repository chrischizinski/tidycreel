# GH #691: interview quantities pooled across strata.
#
# The interview survey gives every interview weight 1, so a quantity pooled
# across strata weights each stratum by its share of the INTERVIEWS, not of the
# population. Interviews follow the clerk's schedule (weekends oversampled, a
# fixed number per day), not the effort, so the pooled figure leans toward
# whichever stratum was interviewed more heavily than it was fished. On a
# simulated 120-day season the pooled trip length put season trips off by -16%
# (weekends oversampled) and +8% (proportional day sampling); weighting days by
# N_h / n_h did not remove it. Season figures are built stratum by stratum, as
# Pollock et al. (1994, sec. 15.3.3.6, Table 15.20) build season catch.
#
# Part 1 (this file, trips): trips are sum_h E_h / L_h, and ungrouped effort on
# a stratified design, which has no E_h, is refused.

ps_quiet <- function(expr) suppressWarnings(suppressMessages(expr))

# 20 days: 14 weekdays, 6 weekends. Four of each sampled, so weekends are
# sampled at 4/6 and weekdays at 4/14. Five complete trips interviewed per
# sampled day however busy it was. Weekday trips are about 2 h, weekend about
# 5 h, and weekend effort is four times weekday effort.
ps_design <- function() {
  dates <- as.Date("2024-06-03") + 0:19
  day_type <- ifelse(format(dates, "%u") %in% c("6", "7"), "weekend", "weekday")
  cal <- data.frame(date = dates, day_type = day_type)
  sampled <- c(dates[day_type == "weekday"][c(1, 4, 7, 10)], dates[day_type == "weekend"][1:4])
  st <- day_type[match(sampled, dates)]
  cn <- data.frame(
    date = sampled, day_type = st,
    effort_hours = ifelse(st == "weekend", 80, 20) + c(1, -2, 3, -1, 4, -3, 2, -4),
    T_d = 1
  )
  base <- c(-0.5, 0, 0.5, -0.25, 0.25)
  iv <- do.call(rbind, lapply(seq_along(sampled), function(i) {
    L <- (if (st[i] == "weekend") 5 else 2) + base * (1 + i / 10)
    data.frame(
      date = sampled[i], hours_fished = L, trip_duration = L,
      trip_status = "complete", catch_total = 1L, catch_kept = 1L, n_anglers = 1L
    )
  }))
  d <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter
  d <- ps_quiet(add_counts(d, cn, count_col = effort_hours, period_length_col = T_d)) # nolint: object_usage_linter
  ps_quiet(add_interviews( # nolint: object_usage_linter
    d, iv,
    catch = catch_total, harvest = catch_kept, effort = hours_fished,
    trip_status = trip_status, trip_duration = trip_duration, n_anglers = n_anglers
  ))
}

test_that("#691: season trips are summed per stratum, not effort over a pooled trip length", {
  d <- ps_design()
  g <- ps_quiet(estimate_effort(d, by = day_type)) # nolint: object_usage_linter
  t <- ps_quiet(estimate_angler_trips(g, d))$estimates # nolint: object_usage_linter

  iv <- d$interviews
  L_h <- tapply(iv$trip_duration, iv$day_type, mean)
  E_h <- stats::setNames(g$estimates$estimate, g$estimates$day_type)
  season <- sum(E_h / L_h[names(E_h)])
  expect_equal(t$estimate[t$day_type == ".overall"], season)

  # Why it matters: the pooled trip length counts weekend and weekday trips by
  # how many were interviewed (20 each), but weekdays hold 14 of the 20 days.
  # Effort over that pooled length -- what an ungrouped call returned before
  # #691 -- is materially off.
  pooled <- sum(E_h) / mean(iv$trip_duration)
  expect_gt(abs(pooled / season - 1), 0.10)
})

test_that("#691: ungrouped effort on a stratified design is refused, naming the fix", {
  d <- ps_design()
  e <- ps_quiet(estimate_effort(d)) # nolint: object_usage_linter
  err <- tryCatch(estimate_angler_trips(e, d), error = function(e) e) # nolint: object_usage_linter
  expect_s3_class(err, "creel_error_trips_need_strata")
  msg <- conditionMessage(err)
  expect_match(msg, "Pollock et al. 1994", fixed = TRUE)
  expect_match(msg, "by = day_type", fixed = TRUE)
  expect_match(msg, "?estimate_angler_trips", fixed = TRUE)
})
