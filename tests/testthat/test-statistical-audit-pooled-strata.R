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

# 20 days from a Monday: 15 weekdays, 5 weekend days. Four of each sampled, so
# weekends are sampled at 4/5 and weekdays at 4/15. Five complete trips are
# interviewed per sampled day however busy it was. Weekday trips are about 2 h,
# weekend about 5 h, and weekend effort is four times weekday effort.
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
  # how many were interviewed (20 each), but weekdays hold 15 of the 20 days.
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

  # The suggested call keeps a non-default target, or following it would
  # change the quantity estimated.
  s <- ps_quiet(estimate_effort(d, target = "sampled_days")) # nolint: object_usage_linter
  msg <- tryCatch(estimate_angler_trips(s, d), error = conditionMessage) # nolint: object_usage_linter
  expect_match(msg, "target = \"sampled_days\"", fixed = TRUE)
})

# Part 2 (rates): a rate pooled across strata -- ungrouped, or grouped by a
# column that is not a stratum -- is sum_h E_h R_h / sum_h E_h. Each interview
# in stratum h is weighted E_h / D_h (D_h = the stratum's interviewed hours),
# which gives exactly that ratio, and the SE adds the effort estimate's own
# variance by the delta method. The references below are built with the
# survey package directly.

# Weekends oversampled (4 of 5) against weekdays (4 of 15), five interviews a
# day whatever the effort; weekend anglers catch three times as fast and fish
# longer, so weekends hold about 60% of the interviewed hours but about 40% of
# the effort. Two gears on every day, two incomplete trips per day.
ps_rate_design <- function(with_counts = TRUE) {
  dates <- as.Date("2024-06-03") + 0:19
  day_type <- ifelse(format(dates, "%u") %in% c("6", "7"), "weekend", "weekday")
  cal <- data.frame(date = dates, day_type = day_type)
  sampled <- c(dates[day_type == "weekday"][c(1, 4, 7, 10)], dates[day_type == "weekend"][1:4])
  st <- day_type[match(sampled, dates)]
  iv <- do.call(rbind, lapply(seq_along(sampled), function(i) {
    we <- st[i] == "weekend"
    hrs <- c(2, 3, 2.5, 4, 1.5) * (if (we) 1.5 else 1)
    data.frame(
      date = sampled[i], hours_fished = hrs, trip_duration = hrs,
      trip_status = c(rep("complete", 3), rep("incomplete", 2)),
      catch_total = round(hrs * (if (we) 1.5 else 0.5) + c(0, 1, -1, 1, 0) + i %% 2),
      # Alternating by day, so each gear has 12 complete trips.
      gear = if (i %% 2) c("bank", "boat", "bank", "boat", "bank") else c("boat", "bank", "boat", "bank", "boat")
    )
  }))
  iv$catch_kept <- pmax(iv$catch_total - 1, 0)
  d <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter
  if (with_counts) {
    cn <- data.frame(
      date = sampled, day_type = st,
      effort_hours = ifelse(st == "weekend", 40, 20) + c(1, -2, 3, -1, 4, -3, 2, -4)
    )
    d <- ps_quiet(add_counts(d, cn, count_col = effort_hours)) # nolint: object_usage_linter
  }
  ps_quiet(add_interviews( # nolint: object_usage_linter
    d, iv,
    catch = catch_total, harvest = catch_kept, effort = hours_fished,
    trip_status = trip_status, trip_duration = trip_duration
  ))
}

# Effort-weighted survey reference over the complete trips, as a domain of all
# interviewed days. `group` adds a domain column.
ps_rate_reference <- function(d, y = "catch_total", group = NULL) {
  iv <- d$interviews
  E <- ps_quiet(estimate_effort(d, by = day_type))$estimates # nolint: object_usage_linter
  E_h <- stats::setNames(E$estimate, E$day_type)
  se_E <- stats::setNames(E$se, E$day_type)
  ok <- iv$trip_status == "complete"
  D_h <- tapply(iv$hours_fished[ok], iv$day_type[ok], sum)
  iv$w <- as.numeric(E_h[iv$day_type] / D_h[iv$day_type])
  iv$.y <- iv[[y]]
  s <- survey::svydesign(ids = ~date, strata = ~day_type, nest = TRUE, weights = ~w, data = iv)
  s <- subset(s, trip_status == "complete")
  keep <- if (is.null(group)) rep(TRUE, nrow(iv)) else iv$gear == group
  if (!is.null(group)) s <- subset(s, gear == group)
  r <- survey::svyratio(~.y, ~hours_fished, s)
  R <- as.numeric(coef(r))
  k <- ok & keep
  A <- tapply(iv$.y[k], factor(iv$day_type[k], names(D_h)), sum) / D_h
  B <- tapply(iv$hours_fished[k], factor(iv$day_type[k], names(D_h)), sum) / D_h
  A[is.na(A)] <- 0
  B[is.na(B)] <- 0
  g <- (A - R * B) / sum(E_h[names(D_h)] * B)
  list(
    R = R, se = sqrt(as.numeric(vcov(r)) + sum(g^2 * se_E[names(D_h)]^2)),
    closed = sum(E_h[names(D_h)] * A) / sum(E_h[names(D_h)] * B),
    unweighted = sum(iv$.y[k]) / sum(iv$hours_fished[k])
  )
}

test_that("#691: an ungrouped catch rate is weighted by each stratum's effort", {
  d <- ps_rate_design()
  r <- ps_quiet(estimate_catch_rate(d))$estimates # nolint: object_usage_linter
  ref <- ps_rate_reference(d)
  expect_equal(r$estimate, ref$R, tolerance = 1e-10)
  expect_equal(ref$R, ref$closed, tolerance = 1e-12)
  # The SE carries the effort weights' variance on top of the survey's, over
  # every interviewed day (incomplete-only days enter as zeros, GH #663).
  expect_equal(r$se, ref$se, tolerance = 1e-10)
  # Why it matters: weekends were interviewed beyond their share of the
  # effort, so the interview-weighted ratio leans to their faster rate.
  expect_lt(r$estimate / ref$unweighted - 1, -0.10)
})

test_that("#691: harvest rate takes the same weights", {
  d <- ps_rate_design()
  r <- ps_quiet(estimate_harvest_rate(d))$estimates # nolint: object_usage_linter
  ref <- ps_rate_reference(d, y = "catch_kept")
  expect_equal(r$estimate, ref$R, tolerance = 1e-10)
  expect_equal(r$se, ref$se, tolerance = 1e-10)
})

test_that("#691: a rate grouped by a non-stratum column weights each stratum by that group's effort", {
  d <- ps_rate_design()
  r <- ps_quiet(estimate_catch_rate(d, by = gear))$estimates # nolint: object_usage_linter
  for (g in c("bank", "boat")) {
    ref <- ps_rate_reference(d, group = g)
    expect_equal(r$estimate[r$gear == g], ref$R, tolerance = 1e-10, info = g)
    expect_equal(r$estimate[r$gear == g], ref$closed, tolerance = 1e-10, info = g)
    expect_equal(r$se[r$gear == g], ref$se, tolerance = 1e-10, info = g)
  }
})

test_that("#691: a rate grouped by the strata is untouched", {
  d <- ps_rate_design()
  r <- ps_quiet(estimate_catch_rate(d, by = day_type))$estimates # nolint: object_usage_linter
  r0 <- without_rate_pooling(ps_quiet(estimate_catch_rate(d, by = day_type)))$estimates # nolint: object_usage_linter
  expect_equal(r$estimate, r0$estimate)
  expect_equal(r$se, r0$se)
})

test_that("#691: a mean-of-ratios rate combines the strata's means by effort", {
  d <- ps_rate_design()
  r <- ps_quiet(estimate_catch_rate(d, estimator = "mor", use_trips = "incomplete", truncate_at = NULL))$estimates # nolint: object_usage_linter
  iv <- d$interviews[d$interviews$trip_status == "incomplete", ]
  M_h <- tapply(iv$catch_total / iv$hours_fished, iv$day_type, mean)
  E <- ps_quiet(estimate_effort(d, by = day_type))$estimates # nolint: object_usage_linter
  E_h <- stats::setNames(E$estimate, E$day_type)[names(M_h)]
  expect_equal(r$estimate, sum(E_h * M_h) / sum(E_h), tolerance = 1e-10)
})

test_that("#691: without counts a pooled rate is refused, and a rate by stratum is not", {
  d <- ps_rate_design(with_counts = FALSE)
  err <- tryCatch(estimate_catch_rate(d), error = function(e) e) # nolint: object_usage_linter
  expect_s3_class(err, "creel_error_rate_needs_effort")
  msg <- conditionMessage(err)
  expect_match(msg, "Pollock et al. 1994", fixed = TRUE)
  expect_match(msg, "by = day_type", fixed = TRUE)
  expect_match(msg, "?estimate_catch_rate", fixed = TRUE)
  expect_error(ps_quiet(estimate_harvest_rate(d)), class = "creel_error_rate_needs_effort") # nolint: object_usage_linter
  expect_error(ps_quiet(estimate_catch_rate(d, by = gear)), class = "creel_error_rate_needs_effort") # nolint: object_usage_linter
  expect_s3_class(ps_quiet(estimate_catch_rate(d, by = day_type)), "creel_estimates") # nolint: object_usage_linter
})

test_that("#691: diagnostics comparing rates on the same interviews need no counts", {
  # validate_incomplete_trips() asks whether complete and incomplete trips give
  # the same rate; effort does not enter, so it runs without counts.
  d <- ps_rate_design(with_counts = FALSE)
  v <- ps_quiet(validate_incomplete_trips(d, catch_total, hours_fished)) # nolint: object_usage_linter
  expect_s3_class(v, "creel_tost_validation")
  # And it leaves pooling switched on for the caller afterwards.
  expect_true(rate_pooling_on())
})

test_that("#691: a stratum fished but never interviewed has no rate, so pooling is refused by name", {
  # Leaving the weekend out would make this a rate over weekdays only while
  # reporting it as the season's.
  d <- ps_rate_design()
  iv <- d$interviews[d$interviews$day_type == "weekday", c(
    "date", "hours_fished", "trip_duration", "trip_status", "catch_total", "catch_kept", "gear"
  )]
  d2 <- creel_design(d$calendar[c("date", "day_type")], date = date, strata = day_type) # nolint: object_usage_linter
  d2 <- ps_quiet(add_counts(d2, d$counts[c("date", "day_type", "effort_hours")], count_col = effort_hours)) # nolint: object_usage_linter
  d2 <- ps_quiet(add_interviews( # nolint: object_usage_linter
    d2, iv,
    catch = catch_total, harvest = catch_kept, effort = hours_fished,
    trip_status = trip_status, trip_duration = trip_duration
  ))
  err <- tryCatch(ps_quiet(estimate_catch_rate(d2)), error = function(e) e) # nolint: object_usage_linter
  expect_s3_class(err, "creel_error_rate_needs_effort")
  expect_match(conditionMessage(err), "weekend", fixed = TRUE)
})

# Part 3: the species, sectioned, regression and bus-route/ice routes.

test_that("#691: each species' rate is weighted by the strata's effort, and the species sum to the whole", {
  d <- ps_rate_design()
  iv <- d$interviews
  iv$interview_id <- seq_len(nrow(iv))
  d$interviews$interview_id <- iv$interview_id
  # Two species splitting each trip's catch unevenly by day type.
  share <- ifelse(iv$day_type == "weekend", 0.8, 0.3)
  a <- round(iv$catch_total * share)
  catch <- rbind(
    data.frame(interview_id = iv$interview_id, species = "walleye", count = a, catch_type = "caught"),
    data.frame(interview_id = iv$interview_id, species = "perch", count = iv$catch_total - a, catch_type = "caught")
  )
  catch <- catch[catch$count > 0, ]
  d <- ps_quiet(add_catch( # nolint: object_usage_linter
    d, catch,
    catch_uid = interview_id, interview_uid = interview_id,
    species = species, count = count, catch_type = catch_type
  ))
  r <- ps_quiet(estimate_catch_rate(d, by = species))$estimates # nolint: object_usage_linter
  all <- ps_quiet(estimate_catch_rate(d))$estimates # nolint: object_usage_linter
  expect_equal(sum(r$estimate), all$estimate, tolerance = 1e-10)

  E <- ps_quiet(estimate_effort(d, by = day_type))$estimates # nolint: object_usage_linter
  E_h <- stats::setNames(E$estimate, E$day_type)
  ok <- iv$trip_status == "complete"
  D_h <- tapply(iv$hours_fished[ok], iv$day_type[ok], sum)
  for (sp in c("walleye", "perch")) {
    y <- if (sp == "walleye") a else iv$catch_total - a
    R_h <- tapply(y[ok], iv$day_type[ok], sum) / D_h
    expect_equal(
      r$estimate[r$species == sp], sum(E_h[names(R_h)] * R_h) / sum(E_h[names(R_h)]),
      tolerance = 1e-10, info = sp
    )
  }
})

test_that("#691: a section's rate is weighted by that section's own effort in each stratum", {
  data(example_sections_calendar, envir = environment())
  data(example_sections_counts, envir = environment())
  data(example_sections_interviews, envir = environment())
  cnt <- example_sections_counts # nolint: object_usage_linter
  cal <- example_sections_calendar # nolint: object_usage_linter
  d <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter
  d <- ps_quiet(add_sections(d, data.frame(section = unique(cnt$section)), section_col = section)) # nolint: object_usage_linter
  d <- ps_quiet(add_counts(d, prep_counts_daily_effort( # nolint: object_usage_linter
    cnt,
    date = date, strata = day_type, daily_effort = effort_hours, section = section
  )))
  d <- ps_quiet(add_interviews( # nolint: object_usage_linter
    d, example_sections_interviews, # nolint: object_usage_linter
    catch = catch_total, effort = hours_fished, n_anglers = 1, harvest = catch_kept,
    trip_status = trip_status, trip_duration = trip_duration
  ))
  r <- ps_quiet(estimate_catch_rate(d))$estimates # nolint: object_usage_linter
  iv <- d$interviews
  N_h <- table(cal$day_type)
  for (sec in unique(cnt$section)) {
    k <- iv$section == sec & iv$trip_status == "complete"
    cs <- cnt[cnt$section == sec, ]
    tot <- tapply(cs$effort_hours, cs$day_type, sum)
    n_h <- tapply(cs$date, cs$day_type, function(x) length(unique(x)))
    E_h <- tot * as.numeric(N_h[names(tot)]) / n_h
    R_h <- tapply(iv$catch_total[k], iv$day_type[k], sum) / tapply(iv$hours_fished[k], iv$day_type[k], sum)
    expect_equal(
      r$estimate[r$section == sec], sum(E_h[names(R_h)] * R_h) / sum(E_h[names(R_h)]),
      tolerance = 1e-10, info = sec
    )
  }
})

test_that("#691: a regression rate across strata is each stratum's slope weighted by its effort", {
  d <- ps_rate_design()
  for (origin in c(TRUE, FALSE)) {
    r <- ps_quiet(estimate_catch_rate(d, estimator = "regression", force_origin = origin))$estimates # nolint: object_usage_linter
    per <- ps_quiet(estimate_catch_rate(d, estimator = "regression", force_origin = origin, by = day_type))$estimates # nolint: object_usage_linter
    E <- ps_quiet(estimate_effort(d, by = day_type))$estimates # nolint: object_usage_linter
    E_h <- stats::setNames(E$estimate, E$day_type)[per$day_type]
    se_E <- stats::setNames(E$se, E$day_type)[per$day_type]
    R <- sum(E_h * per$estimate) / sum(E_h)
    expect_equal(r$estimate, R, tolerance = 1e-10, info = origin)
    v <- sum((E_h / sum(E_h))^2 * per$se^2) + sum(((per$estimate - R) / sum(E_h))^2 * se_E^2)
    expect_equal(r$se, sqrt(v), tolerance = 1e-10, info = origin)
  }
  # The through-origin slope by hand, per stratum: Petrere's sum(c e) / sum(e^2).
  iv <- d$interviews[d$interviews$trip_status == "complete", ]
  b_h <- tapply(iv$catch_total * iv$hours_fished, iv$day_type, sum) / tapply(iv$hours_fished^2, iv$day_type, sum)
  r <- ps_quiet(estimate_catch_rate(d, estimator = "regression"))$estimates # nolint: object_usage_linter
  E <- ps_quiet(estimate_effort(d, by = day_type))$estimates # nolint: object_usage_linter
  E_h <- stats::setNames(E$estimate, E$day_type)[names(b_h)]
  expect_equal(r$estimate, sum(E_h * b_h) / sum(E_h), tolerance = 1e-10)

  # A group that is not a stratum has no effort to weight its slopes by.
  expect_error(
    ps_quiet(estimate_catch_rate(d, estimator = "regression", by = gear)), # nolint: object_usage_linter
    class = "creel_error_regression_pooled_group"
  )
  # The ungrouped rate's own three-interview floor still applies.
  tiny <- rebuild_interview_survey(d, d$interviews[c(1, 2), ]) # nolint: object_usage_linter
  expect_error(ps_quiet(estimate_catch_rate(tiny, estimator = "regression", use_trips = "all")), "at least 3") # nolint: object_usage_linter
})

test_that("#691: a bus-route rate across strata is the expanded catch over the expanded effort", {
  d <- build_br_design_for_tests(n_sites = 3, n_days = 8, n_interviews = 40, seed = 691) # nolint: object_usage_linter
  # Two weekdays left unworked, so the day types are sampled unevenly
  # (N_h / n_h differs between them).
  wd <- d$calendar$date[d$calendar$day_type == "weekday"]
  off <- wd[seq_len(2)]
  d$calendar$.sampled[d$calendar$date %in% off] <- FALSE
  d <- rebuild_interview_survey(d, d$interviews[!d$interviews$date %in% off, ]) # nolint: object_usage_linter
  expect_gt(length(unique(tapply(d$calendar$.sampled, d$calendar$day_type, mean))), 1L)
  r <- ps_quiet(estimate_catch_rate(d))$estimates # nolint: object_usage_linter
  C <- ps_quiet(estimate_total_catch(d, target = "period_total"))$estimates # nolint: object_usage_linter
  E <- ps_quiet(estimate_effort(d, target = "period_total"))$estimates # nolint: object_usage_linter
  expect_equal(r$estimate, C$estimate / E$estimate, tolerance = 1e-10)
  # Not the ratio of the sampled-day totals, which weights strata by their
  # sampled days: the fixture samples its day types unevenly.
  Cs <- ps_quiet(estimate_total_catch(d, target = "sampled_days"))$estimates # nolint: object_usage_linter
  Es <- ps_quiet(estimate_effort(d, target = "sampled_days"))$estimates # nolint: object_usage_linter
  expect_false(isTRUE(all.equal(r$estimate, Cs$estimate / Es$estimate)))

  # Without the register of sampled days n_h is unknown, so it is refused.
  d0 <- d
  d0$sampled_col <- NULL
  expect_error(ps_quiet(estimate_catch_rate(d0)), class = "creel_error_sampled_register") # nolint: object_usage_linter
  # By day type it needs no register.
  expect_s3_class(ps_quiet(estimate_catch_rate(d0, by = day_type)), "creel_estimates") # nolint: object_usage_linter
})

# Review follow-ups (part 3).

test_that("#691: a survey SE of exactly zero still gets an interval from the effort term", {
  # Every trip's catch is exactly its hours times its day type's rate, so the
  # survey's ratio variance is 0; the effort weights still vary.
  d <- ps_rate_design()
  iv <- d$interviews
  iv$catch_total <- iv$hours_fished * ifelse(iv$day_type == "weekend", 3, 1)
  iv$catch_kept <- iv$catch_total
  d2 <- creel_design(d$calendar[c("date", "day_type")], date = date, strata = day_type) # nolint: object_usage_linter
  d2 <- ps_quiet(add_counts(d2, d$counts[c("date", "day_type", "effort_hours")], count_col = effort_hours)) # nolint: object_usage_linter
  d2 <- ps_quiet(add_interviews( # nolint: object_usage_linter
    d2, iv[c("date", "hours_fished", "trip_duration", "trip_status", "catch_total", "catch_kept", "gear")],
    catch = catch_total, harvest = catch_kept, effort = hours_fished,
    trip_status = trip_status, trip_duration = trip_duration
  ))
  r <- ps_quiet(estimate_catch_rate(d2))$estimates # nolint: object_usage_linter
  expect_gt(r$se, 0)
  expect_true(is.finite(r$ci_lower) && is.finite(r$ci_upper))
  expect_equal(r$ci_upper - r$estimate, stats::qnorm(0.975) * r$se)
})

test_that("#691: a stratum whose regression slope cannot be identified is refused, not NA", {
  d <- ps_rate_design()
  iv <- d$interviews
  # Every weekend trip the same length: no slope with an intercept there.
  iv$hours_fished[iv$day_type == "weekend"] <- 3
  iv$trip_duration <- iv$hours_fished
  d2 <- creel_design(d$calendar[c("date", "day_type")], date = date, strata = day_type) # nolint: object_usage_linter
  d2 <- ps_quiet(add_counts(d2, d$counts[c("date", "day_type", "effort_hours")], count_col = effort_hours)) # nolint: object_usage_linter
  d2 <- ps_quiet(add_interviews( # nolint: object_usage_linter
    d2, iv[c("date", "hours_fished", "trip_duration", "trip_status", "catch_total", "catch_kept", "gear")],
    catch = catch_total, harvest = catch_kept, effort = hours_fished,
    trip_status = trip_status, trip_duration = trip_duration
  ))
  expect_true(is.na(ps_quiet(estimate_catch_rate( # nolint: object_usage_linter
    d2,
    estimator = "regression", force_origin = FALSE, by = day_type
  ))$estimates$estimate[2]))
  expect_error(
    ps_quiet(estimate_catch_rate(d2, estimator = "regression", force_origin = FALSE)), # nolint: object_usage_linter
    class = "creel_error_rate_needs_effort"
  )
})

test_that("#691: bus-route pooling refuses a stratum the trip filter emptied, and a one-day stratum by name", {
  d <- build_br_design_for_tests(n_sites = 3, n_days = 8, n_interviews = 40, seed = 691) # nolint: object_usage_linter
  # Incomplete trips on weekdays only: the weekend has no rate from them.
  d$interviews$trip_status <- ifelse(d$interviews$day_type == "weekday" & seq_len(nrow(d$interviews)) %% 2 == 0,
    "incomplete", "complete"
  )
  d <- rebuild_interview_survey(d, d$interviews) # nolint: object_usage_linter
  expect_error(
    ps_quiet(estimate_catch_rate(d, use_trips = "incomplete")), # nolint: object_usage_linter
    class = "creel_error_rate_needs_effort"
  )
  # The diagnostic compares the two trip types on the same interviews and
  # needs no register.
  d0 <- d
  d0$sampled_col <- NULL
  expect_no_error(ps_quiet(estimate_catch_rate(d0, use_trips = "diagnostic"))) # nolint: object_usage_linter

  # One sampled weekend day: refused by name, not survey's unclassed error.
  d1 <- build_br_design_for_tests(n_sites = 3, n_days = 8, n_interviews = 40, seed = 691) # nolint: object_usage_linter
  we <- d1$calendar$date[d1$calendar$day_type == "weekend"]
  off <- we[-1]
  d1$calendar$.sampled[d1$calendar$date %in% off] <- FALSE
  d1 <- rebuild_interview_survey(d1, d1$interviews[!d1$interviews$date %in% off, ]) # nolint: object_usage_linter
  expect_error(ps_quiet(estimate_catch_rate(d1)), class = "creel_error_single_psu") # nolint: object_usage_linter
})
