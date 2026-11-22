# Rates estimated on the same days covary (GH #664) ----
#
# Interview variance is clustered on the survey day (GH #661). Two rates from
# disjoint interviews -- complete and incomplete trips, bank and boat anglers --
# are then no longer independent when they were interviewed on the same days:
# both move with each day's conditions. A difference of two such rates has a
# smaller variance than the sum of theirs, and a sum of them a larger one
# (Cochran 1977, s. 2.13 and 6.11: covariance of domain ratios from one sample;
# Lumley 2010, s. 3.4, svyby(covmat = TRUE)).
#
# The references below are computed in base R from the definitions, sharing no
# tidycreel or survey code.

sdc_q <- function(x) suppressWarnings(suppressMessages(x))

sdc_calendar <- function() {
  data.frame(
    date = as.Date("2024-06-03") + c(0:4, 7:11),
    day_type = rep(c("weekday", "weekend"), each = 5),
    stringsAsFactors = FALSE
  )
}

# Each day has its own catch rate; three complete and three incomplete trips a
# day share it, so the two trip types' rates rise and fall together.
sdc_tost_design <- function(inc_scale = 1.05) {
  cal <- sdc_calendar()
  day_rate <- c(0.6, 1.8, 1.0, 2.4, 1.3, 0.9, 2.0, 1.5, 0.7, 2.2)
  effort <- c(2, 3, 4, 2.5, 3.5, 1.5)
  jitter <- c(-0.3, 0.2, 0.1, -0.1, 0.25, -0.15)
  iv <- do.call(rbind, lapply(seq_along(cal$date), function(i) {
    status <- rep(c("complete", "incomplete"), each = 3)
    rate <- ifelse(status == "complete", day_rate[i], day_rate[i] * inc_scale) + jitter
    data.frame(
      date = cal$date[i], catch_total = rate * effort, hours_fished = effort,
      trip_status = status, trip_duration = effort, stringsAsFactors = FALSE
    )
  }))
  sdc_q(add_interviews(
    creel_design(cal, date = date, strata = day_type), # nolint: object_usage_linter
    iv,
    catch = catch_total, effort = hours_fished, # nolint: object_usage_linter
    trip_status = trip_status, trip_duration = trip_duration # nolint: object_usage_linter
  ))
}

# Stratified between-day covariance of two linearization scores: per-day sums,
# then n_h / (n_h - 1) * sum((Z1 - Z1bar)(Z2 - Z2bar)) within each stratum.
sdc_cov <- function(z1, z2, day, day_stratum) {
  days <- names(day_stratum)
  s1 <- tapply(z1, factor(day, levels = days), sum)
  s2 <- tapply(z2, factor(day, levels = days), sum)
  s1[is.na(s1)] <- 0
  s2[is.na(s2)] <- 0
  v <- 0
  for (h in unique(day_stratum)) {
    k <- day_stratum == h
    n <- sum(k)
    v <- v + n / (n - 1) * sum((s1[k] - mean(s1[k])) * (s2[k] - mean(s2[k])))
  }
  v
}

# Linearization scores of the complete-trip ratio of means and the
# incomplete-trip mean of ratios, each zero outside its own trips.
sdc_tost_scores <- function(iv, in_group = rep(TRUE, nrow(iv))) {
  comp <- iv$trip_status == "complete" & in_group
  inc <- iv$trip_status == "incomplete" & in_group
  y <- iv$catch_total
  x <- iv$hours_fished
  r_c <- sum(y[comp]) / sum(x[comp])
  ratio <- y / x
  r_i <- mean(ratio[inc])
  list(
    r_c = r_c, r_i = r_i,
    z_c = ifelse(comp, (y - r_c * x) / sum(x[comp]), 0),
    z_i = ifelse(inc, (ratio - r_i) / sum(inc), 0)
  )
}

sdc_day_stratum <- function(iv) {
  key <- unique(iv[c("date", "day_type")])
  stats::setNames(key$day_type, as.character(key$date))
}

test_that("SDC-01 (#664): the TOST difference carries the two rates' shared-day covariance", {
  d <- sdc_tost_design()
  iv <- d$interviews
  s <- sdc_tost_scores(iv)
  ds <- sdc_day_stratum(iv)
  day <- as.character(iv$date)
  se_diff_hand <- sqrt(sdc_cov(s$z_c - s$z_i, s$z_c - s$z_i, day, ds))
  se_indep_hand <- sqrt(sdc_cov(s$z_c, s$z_c, day, ds) + sdc_cov(s$z_i, s$z_i, day, ds))

  v <- sdc_q(validate_incomplete_trips(d, catch_total, hours_fished))
  expect_equal(v$overall_test$diff_estimate, s$r_c - s$r_i, tolerance = 1e-10)
  expect_equal(v$overall_test$se_diff, se_diff_hand, tolerance = 1e-8)
  # The rates track each other day by day, so the paired difference is far
  # more precise than two independent rates would be -- and the 5% difference
  # is inside the 20% equivalence bounds only once that is counted.
  expect_lt(se_diff_hand, se_indep_hand / 10)
  expect_true(v$passed)
})

test_that("SDC-02 (#664): each group's TOST counts the covariance within that group", {
  d <- sdc_tost_design()
  iv <- d$interviews
  ds <- sdc_day_stratum(iv)
  day <- as.character(iv$date)
  v <- sdc_q(validate_incomplete_trips(d, catch_total, hours_fished, by = day_type))
  gt <- v$group_tests
  for (g in c("weekday", "weekend")) {
    s <- sdc_tost_scores(iv, iv$day_type == g)
    se_hand <- sqrt(sdc_cov(s$z_c - s$z_i, s$z_c - s$z_i, day, ds))
    row <- gt[gt$day_type == g, ]
    # Design degrees of freedom of a group inside one stratum: that stratum's
    # 5 interviewed days minus 1 (GH #669). The other stratum contributes no
    # variance to this group, and so no degrees of freedom.
    df <- sum(ds == g) - 1
    p_lower_hand <- stats::pt((row$diff_estimate - row$equivalence_lower) / se_hand, df, lower.tail = FALSE)
    expect_equal(row$diff_estimate, s$r_c - s$r_i, tolerance = 1e-10)
    expect_equal(row$p_lower, p_lower_hand, tolerance = 1e-8)
  }
  expect_equal(
    v$overall_test$se_diff,
    sdc_q(validate_incomplete_trips(d, catch_total, hours_fished))$overall_test$se_diff,
    tolerance = 1e-10
  )
})

test_that("SDC-03 (#664): the jackknife TOST deletes a day from both rates at once", {
  # JKn: delete one day, reweight its stratum's other days by n_h / (n_h - 1),
  # recompute both rates; Var = sum_h (n_h - 1) / n_h sum (delta_(d) - delta)^2.
  d <- sdc_tost_design()
  iv <- d$interviews
  ds <- sdc_day_stratum(iv)
  day <- as.character(iv$date)
  comp <- iv$trip_status == "complete"
  ratio <- iv$catch_total / iv$hours_fished
  delta <- function(w) {
    sum(w[comp] * iv$catch_total[comp]) / sum(w[comp] * iv$hours_fished[comp]) -
      sum(w[!comp] * ratio[!comp]) / sum(w[!comp])
  }
  full <- delta(rep(1, nrow(iv)))
  v_hand <- 0
  for (h in unique(ds)) {
    days_h <- names(ds)[ds == h]
    n <- length(days_h)
    reps <- vapply(days_h, function(dd) {
      w <- ifelse(day == dd, 0, ifelse(iv$day_type == h, n / (n - 1), 1))
      delta(w)
    }, numeric(1))
    v_hand <- v_hand + (n - 1) / n * sum((reps - full)^2)
  }
  v <- sdc_q(validate_incomplete_trips(d, catch_total, hours_fished, variance = "jackknife"))
  expect_equal(v$overall_test$se_diff, sqrt(v_hand), tolerance = 1e-8)
})

# Bank and boat anglers counted at the same times and interviewed on the same
# days, with a day effect in the catch rate both types share.
sdc_bank_boat_design <- function() {
  withr::local_seed(664)
  cal <- sdc_calendar()
  day_rate <- c(0.4, 1.2, 0.7, 1.6, 0.9, 0.5, 1.4, 1.0, 0.6, 1.5)
  cn <- do.call(rbind, lapply(seq_along(cal$date), function(i) {
    data.frame(
      date = cal$date[i], day_type = cal$day_type[i], count_time = c(9, 15),
      bank_anglers = stats::rpois(2, 8), boat_anglers = stats::rpois(2, 6), hours = 12
    )
  }))
  long <- derive_angler_count(cn, bank = bank_anglers, boat_anglers = boat_anglers, by_type = TRUE) # nolint: object_usage_linter
  iv <- do.call(rbind, lapply(seq_along(cal$date), function(i) {
    type <- rep(c("bank", "boat"), each = 4)
    hrs <- c(1.5, 2, 3, 2.5, 3, 4, 2, 3.5)
    rate <- day_rate[i] * ifelse(type == "bank", 0.6, 1) + c(-0.1, 0.05, 0.1, -0.05, 0.08, -0.06, 0.02, -0.04)
    data.frame(
      date = cal$date[i], day_type = cal$day_type[i], angler_type = type,
      hours_fished = hrs, catch_total = rate * hrs, catch_kept = rate * hrs,
      trip_status = "complete", n_anglers = 1L
    )
  }))
  iv$interview_id <- seq_len(nrow(iv))
  d <- sdc_q(creel_design(cal, date = date, strata = day_type)) # nolint: object_usage_linter
  d <- sdc_q(add_counts(d, long, # nolint: object_usage_linter
    count_col = "angler_count", count_time_col = count_time,
    period_length_col = "hours", unit_cols = c("date", "day_type", "angler_type")
  ))
  sdc_q(add_interviews(d, iv, # nolint: object_usage_linter
    catch = catch_total, effort = hours_fished, harvest = catch_kept, # nolint: object_usage_linter
    trip_status = trip_status, angler_type = angler_type, n_anglers = n_anglers # nolint: object_usage_linter
  ))
}

sdc_bank_boat_groups <- function() {
  data.frame(
    day_type = rep(c("weekday", "weekend"), each = 2),
    angler_type = rep(c("bank", "boat"), 2),
    grp = rep(c("bank", "boat"), 2)
  )
}

test_that("SDC-04 (#664): rate groups interviewed on the same days covary in the total", {
  # T = E_bank R_bank + E_boat R_boat, both rates pooled over the season.
  # Var = Var_E(sum R_g E_g) + E' V E - Goodman, with V the rates' covariance
  # over the shared days. The effort part comes from the package's effort
  # estimator on counts reweighted by the rates (that is what it is, and the
  # rate-group tests pin it); the rate part is computed here by hand.
  d <- sdc_bank_boat_design()
  rg <- sdc_bank_boat_groups()
  res <- sdc_q(estimate_total_catch(d, target = "period_total", rate_groups = rg))
  rates <- res$rate_groups$rates

  iv <- d$interviews
  ds <- sdc_day_stratum(iv)
  day <- as.character(iv$date)
  z <- lapply(c("bank", "boat"), function(g) {
    k <- iv$angler_type == g
    r <- sum(iv$catch_total[k]) / sum(iv$hours_fished[k])
    list(r = r, z = ifelse(k, (iv$catch_total - r * iv$hours_fished) / sum(iv$hours_fished[k]), 0))
  })
  v_hand <- matrix(0, 2, 2)
  for (a in 1:2) for (b in 1:2) v_hand[a, b] <- sdc_cov(z[[a]]$z, z[[b]]$z, day, ds)
  expect_equal(rates$estimate, c(z[[1]]$r, z[[2]]$r), tolerance = 1e-10)
  expect_equal(rates$se, sqrt(diag(v_hand)), tolerance = 1e-8)
  expect_gt(stats::cov2cor(v_hand)[1, 2], 0.5)

  cells <- sdc_q(estimate_effort(d, by = c(day_type, angler_type), target = "period_total"))$estimates
  e_g <- tapply(cells$estimate, cells$angler_type, sum)[c("bank", "boat")]
  d_rg <- attach_rate_groups(d, resolve_rate_groups(d, rg)) # nolint: object_usage_linter
  rates_int <- data.frame(.rate_group = rates$grp, estimate = rates$estimate)
  w <- reweight_counts_by_rate(d_rg, rates_int) # nolint: object_usage_linter
  effort_part <- sdc_q(estimate_effort_total(w, "taylor", 0.95, target = "period_total"))$estimates$se^2 # nolint: object_usage_linter
  r_cell <- rates$estimate[match(cells$angler_type, rates$grp)]
  v_cell <- rates$se[match(cells$angler_type, rates$grp)]^2
  first <- r_cell^2 * cells$se^2 + cells$estimate^2 * v_cell
  cross <- cells$se^2 * v_cell
  goodman <- sum(ifelse(first - cross > 0, cross, 0))

  expected <- effort_part + as.numeric(t(e_g) %*% v_hand %*% e_g) - goodman
  independent <- effort_part + sum(e_g^2 * diag(v_hand)) - goodman
  expect_equal(res$estimates$se^2, expected, tolerance = 1e-8)
  # Dropping the covariance understates this SE materially.
  expect_gt(sqrt(expected) / sqrt(independent), 1.05)
})

test_that("SDC-05 (#664): harvest and species totals carry the same covariance", {
  # Every fish kept, and one species holding every fish: the harvest total and
  # the species total are the catch total, covariance included. A path that
  # dropped the off-diagonal terms would come out smaller.
  d <- sdc_bank_boat_design()
  rg <- sdc_bank_boat_groups()
  catch <- sdc_q(estimate_total_catch(d, target = "period_total", rate_groups = rg))$estimates
  harvest <- sdc_q(estimate_total_harvest(d, target = "period_total", rate_groups = rg))$estimates
  expect_equal(harvest$estimate, catch$estimate, tolerance = 1e-10)
  expect_equal(harvest$se, catch$se, tolerance = 1e-10)

  iv <- d$interviews
  sp <- data.frame(
    interview_id = iv$interview_id, species = "perch",
    count = iv$catch_total, catch_type = "caught"
  )
  d_sp <- sdc_q(add_catch(d, sp, # nolint: object_usage_linter
    catch_uid = interview_id, interview_uid = interview_id, # nolint: object_usage_linter
    species = species, count = count, catch_type = catch_type # nolint: object_usage_linter
  ))
  by_sp <- sdc_q(estimate_total_catch(d_sp, by = species, target = "period_total", rate_groups = rg))$estimates
  expect_equal(by_sp$estimate, catch$estimate, tolerance = 1e-10)
  expect_equal(by_sp$se, catch$se, tolerance = 1e-10)
})

test_that("SDC-06 (#664): grouped TOST pairs each group's own complete and incomplete trips", {
  # Complete trips on every day, incomplete trips on weekends only. Pairing the
  # two grouped results by row position compared weekday complete trips with
  # weekend incomplete trips and reported it as the weekday test.
  d <- sdc_tost_design()
  iv <- d$interviews
  keep <- iv$trip_status == "complete" | iv$day_type == "weekend"
  d2 <- sdc_q(add_interviews(
    creel_design(sdc_calendar(), date = date, strata = day_type), # nolint: object_usage_linter
    iv[keep, c("date", "catch_total", "hours_fished", "trip_status", "trip_duration")],
    catch = catch_total, effort = hours_fished, # nolint: object_usage_linter
    trip_status = trip_status, trip_duration = trip_duration # nolint: object_usage_linter
  ))
  expect_warning(
    v <- suppressMessages(validate_incomplete_trips(d2, catch_total, hours_fished, by = day_type)),
    class = "creel_warning_tost_degenerate"
  )
  gt <- as.data.frame(v$group_tests)
  wd <- gt[gt$day_type == "weekday", ]
  we <- gt[gt$day_type == "weekend", ]
  expect_true(is.na(wd$equivalence_passed))
  expect_true(is.na(wd$diff_estimate))
  s <- sdc_tost_scores(d2$interviews, d2$interviews$day_type == "weekend")
  expect_equal(we$diff_estimate, s$r_c - s$r_i, tolerance = 1e-10)
  expect_false(v$passed)
  # The untested group is named as untested, not as a failed test.
  expect_match(v$recommendation, "not tested (one trip type only, or no SE): day_type = weekday", fixed = TRUE)
  expect_no_match(v$recommendation, "failed equivalence: day_type = weekday", fixed = TRUE)
  expect_equal(v$plot_data$group_labels, c("day_type = weekday", "day_type = weekend"))
  expect_true(is.na(v$plot_data$incomplete_est[1]))
  expect_no_error(utils::capture.output(print(v)))
})

test_that("SDC-07 (#664): one rate group per stratum is the standard total under the jackknife too", {
  # Strata are sampled independently, so groups in different strata have no
  # covariance -- not the small one a replicate method's centring would invent.
  d <- sdc_bank_boat_design()
  rg <- data.frame(day_type = c("weekday", "weekend"), grp = c("wd", "we"))
  old <- sdc_q(estimate_total_catch(d, target = "period_total", variance = "jackknife"))$estimates
  new <- sdc_q(estimate_total_catch(d, target = "period_total", variance = "jackknife", rate_groups = rg))$estimates
  expect_equal(new$estimate, old$estimate, tolerance = 1e-10)
  expect_equal(new$se, old$se, tolerance = 1e-10)
})

test_that("SDC-08 (#664): the joint TOST never overwrites a user column", {
  # A stratum column with the name a temporary domain variable would take.
  d0 <- sdc_tost_design()
  cal <- sdc_calendar()
  names(cal)[names(cal) == "day_type"] <- ".tost_cn"
  iv <- d0$interviews[c("date", "catch_total", "hours_fished", "trip_status", "trip_duration")]
  d <- sdc_q(add_interviews(
    creel_design(cal, date = date, strata = .tost_cn), iv, # nolint: object_usage_linter
    catch = catch_total, effort = hours_fished, # nolint: object_usage_linter
    trip_status = trip_status, trip_duration = trip_duration # nolint: object_usage_linter
  ))
  v <- sdc_q(validate_incomplete_trips(d, catch_total, hours_fished))
  v0 <- sdc_q(validate_incomplete_trips(d0, catch_total, hours_fished))
  expect_equal(v$overall_test$se_diff, v0$overall_test$se_diff, tolerance = 1e-10)
})

test_that("SDC-09 (#664): a sectioned design is refused, not crashed", {
  d0 <- sdc_tost_design()
  iv <- d0$interviews[c("date", "catch_total", "hours_fished", "trip_status", "trip_duration")]
  iv$section <- rep(c("North", "South"), length.out = nrow(iv))
  des <- sdc_q(add_sections( # nolint: object_usage_linter
    creel_design(sdc_calendar(), date = date, strata = day_type), # nolint: object_usage_linter
    data.frame(section = c("North", "South")), section_col = section # nolint: object_usage_linter
  ))
  d <- sdc_q(add_interviews(des, iv, # nolint: object_usage_linter
    catch = catch_total, effort = hours_fished, # nolint: object_usage_linter
    trip_status = trip_status, trip_duration = trip_duration # nolint: object_usage_linter
  ))
  expect_error(validate_incomplete_trips(d, catch_total, hours_fished), class = "creel_error_tost_sections")
})

# A bus-route (or ice) design of six weekdays, two sites a day, one party per
# visit; each day has its own catch rate, which complete and incomplete trips
# share. Every inclusion probability is equal, so the HT ratio of means and
# the Hajek mean of ratios are the plain ones sdc_tost_scores() linearises.
sdc_br_design <- function(survey_type = "bus_route") {
  cal <- data.frame(date = as.Date("2024-06-03") + 0:5, day_type = "weekday")
  des <- if (survey_type == "ice") {
    creel_design(
      cal,
      date = date, strata = day_type, survey_type = "ice", # nolint: object_usage_linter
      effort_type = "time_on_ice", p_period = 1
    )
  } else {
    sf <- data.frame(site = c("A", "B"), circuit = "c", wait = c(60, 60), ct = 180)
    creel_design(
      cal,
      date = date, strata = day_type, survey_type = "bus_route", # nolint: object_usage_linter
      sampling_frame = sf, site = site, circuit = circuit, # nolint: object_usage_linter
      wait_time = wait, circuit_time = ct, p_period = 1 # nolint: object_usage_linter
    )
  }
  n <- 24L
  iv <- data.frame(
    date = rep(cal$date, each = 4), day_type = "weekday",
    site = rep(c("A", "B"), length.out = n), circuit = "c",
    hrs = rep(c(2, 3, 1.5, 2.5), length.out = n),
    trip_status = rep(c("complete", "incomplete"), length.out = n),
    n_counted = 1L, n_interviewed = 1L
  )
  if (survey_type == "ice") iv$site <- iv$circuit <- NULL
  iv$catch_total <- round(iv$hrs * rep(c(0.8, 1.2, 1, 0.9, 1.1, 1.3), each = 4))
  iv$hours_fished <- iv$hrs
  sdc_q(add_interviews(des, iv, # nolint: object_usage_linter
    effort = hrs, catch = catch_total, trip_status = trip_status, # nolint: object_usage_linter
    trip_duration = hrs, n_counted = n_counted, n_interviewed = n_interviewed, n_anglers = 1 # nolint: object_usage_linter
  ))
}

sdc_br_reference <- function(iv, in_group = rep(TRUE, nrow(iv))) {
  sc <- sdc_tost_scores(iv, in_group)
  st <- sdc_day_stratum(iv)
  v <- sdc_cov(sc$z_c, sc$z_c, iv$date, st) + sdc_cov(sc$z_i, sc$z_i, iv$date, st) -
    2 * sdc_cov(sc$z_c, sc$z_i, iv$date, st)
  sqrt(v)
}

test_that("SDC-10 (#671): bus-route TOST carries the two rates' shared-day covariance", {
  # Bus-route rates are HT ratios on a survey clustered on the day, so the
  # complete and incomplete rates covary as on any design. Their variances were
  # added, as if independent: here more than twice the SE of the difference.
  d <- sdc_br_design()
  v <- sdc_q(validate_incomplete_trips(d, catch_total, hrs)) # nolint: object_usage_linter
  m <- v$metadata
  expect_equal(v$overall_test$se_diff, sdc_br_reference(d$interviews), tolerance = 1e-10)
  expect_lt(v$overall_test$se_diff, 0.5 * sqrt(m$complete$se^2 + m$incomplete$se^2))
  # Degrees of freedom are days minus strata, as everywhere (6 - 1).
  expect_equal(v$overall_test$df, 5)
})

test_that("SDC-17 (#671): ice designs, the degenerate bus route, take the same joint fit", {
  d <- sdc_br_design("ice")
  v <- sdc_q(validate_incomplete_trips(d, catch_total, hrs)) # nolint: object_usage_linter
  expect_equal(v$overall_test$se_diff, sdc_br_reference(d$interviews), tolerance = 1e-10)
})

test_that("SDC-18 (#671): grouped bus-route TOST counts the covariance within each group", {
  d <- sdc_br_design()
  iv <- d$interviews
  iv$zone <- rep(c("n", "n", "s", "s"), length.out = nrow(iv))
  d$interviews <- iv
  # Called directly: twelve trips a group, six of each type, is below the
  # public function's floor of ten per type.
  joint <- tost_joint_se_diff( # nolint: object_usage_linter
    d,
    sdc_q(estimate_catch_rate(d, by = zone)), # nolint: object_usage_linter
    sdc_q(estimate_catch_rate(d, by = zone, estimator = "mor", use_trips = "incomplete")), # nolint: object_usage_linter
    "taylor",
    by_vars = "zone"
  )
  for (z in c("n", "s")) {
    expect_equal(unname(joint[grep(z, names(joint))]), sdc_br_reference(iv, iv$zone == z),
      tolerance = 1e-10, info = z
    )
  }
})

test_that("SDC-11 (#664): Goodman's floor holds for the row once rates covary", {
  # Bank and boat counts trade places day by day (their sum is constant) and
  # their rates trade places too, so sum_g R_g E_g is the same every day: the
  # row's first-order variance is 0. The cell-level Goodman corrections are
  # not, and subtracting them left a negative variance -- an SE of NaN.
  cal <- data.frame(date = as.Date("2024-06-03") + 0:7, day_type = "weekday")
  cn <- data.frame(
    date = rep(cal$date[1:4], each = 2), day_type = "weekday", count_time = c(9, 15),
    bank_anglers = rep(c(10, 2, 10, 2), each = 2), boat_anglers = rep(c(2, 10, 2, 10), each = 2), hours = 12
  )
  long <- derive_angler_count(cn, bank = bank_anglers, boat_anglers = boat_anglers, by_type = TRUE) # nolint: object_usage_linter
  rb <- c(1, 0.2, 1, 0.2)
  ro <- c(0.2, 1, 0.2, 1)
  iv <- do.call(rbind, lapply(1:4, function(i) {
    type <- rep(c("bank", "boat"), each = 5)
    hrs <- c(1, 2, 3, 2, 1.5, 1, 2, 3, 2, 1.5)
    data.frame(
      date = cal$date[i], day_type = "weekday", angler_type = type, hours_fished = hrs,
      catch_total = ifelse(type == "bank", rb[i], ro[i]) * hrs, trip_status = "complete", n_anglers = 1L
    )
  }))
  d <- sdc_q(creel_design(cal, date = date, strata = day_type)) # nolint: object_usage_linter
  d <- sdc_q(add_counts(d, long, # nolint: object_usage_linter
    count_col = "angler_count", count_time_col = count_time,
    period_length_col = "hours", unit_cols = c("date", "day_type", "angler_type")
  ))
  d <- sdc_q(add_interviews(d, iv, # nolint: object_usage_linter
    catch = catch_total, effort = hours_fished, trip_status = trip_status, # nolint: object_usage_linter
    angler_type = angler_type, n_anglers = n_anglers # nolint: object_usage_linter
  ))
  rg <- data.frame(day_type = "weekday", angler_type = c("bank", "boat"), grp = c("bank", "boat"))
  goodman <- sdc_q(estimate_total_catch(d, target = "period_total", rate_groups = rg))$estimates
  first <- sdc_q(estimate_total_catch(d, target = "period_total", rate_groups = rg, product_variance = "first_order"))$estimates
  expect_false(is.nan(goodman$se))
  expect_equal(goodman$se, first$se, tolerance = 1e-8)
})

test_that("SDC-12 (#664): groups in disjoint strata get no covariance from bootstrap noise", {
  # The raw svyby() matrix carries a small cross-stratum covariance from the
  # finite bootstrap draws; strata are sampled independently, so it is zero.
  d <- sdc_bank_boat_design()
  rg <- data.frame(day_type = c("weekday", "weekend"), grp = c("wd", "we"))
  d_rg <- attach_rate_groups(d, resolve_rate_groups(d, rg)) # nolint: object_usage_linter
  withr::with_seed(1, rates <- sdc_q(rate_group_rates(d_rg, "catch", "bootstrap", 0.95))) # nolint: object_usage_linter
  raw <- attr(rates, "rate_vcov")
  v <- shared_day_rate_vcov(d_rg, rates) # nolint: object_usage_linter
  expect_gt(abs(raw[1, 2]), 0)
  expect_equal(v[1, 2], 0)
  expect_equal(diag(v), rates$se^2)
})

test_that("SDC-13 (#669): TOST degrees of freedom are interviewed days minus strata", {
  # The variance is between days, so 10 days in 2 strata give 8 df -- not the
  # 29 that min(n_complete, n_incomplete) - 1 gave, which made the t quantile
  # too small and the p-values too optimistic.
  d <- sdc_tost_design()
  v <- sdc_q(validate_incomplete_trips(d, catch_total, hours_fished))
  expect_equal(v$overall_test$df, 8)
  ot <- v$overall_test
  expect_equal(
    ot$p_lower,
    stats::pt((ot$diff_estimate - ot$equivalence_lower) / ot$se_diff, 8, lower.tail = FALSE),
    tolerance = 1e-12
  )
})

test_that("SDC-14 (#669): catch and effort must be the design's own columns", {
  # They were checked for existence and then ignored, so naming the harvest
  # column silently tested the catch rate.
  d <- sdc_tost_design()
  d$interviews$catch_kept <- d$interviews$catch_total / 2
  expect_error(
    validate_incomplete_trips(d, catch_kept, hours_fished),
    class = "creel_error_tost_columns"
  )
  expect_error(
    validate_incomplete_trips(d, catch_total, trip_duration),
    class = "creel_error_tost_columns"
  )
})

test_that("SDC-15 (#669): grouped metadata reports the overall test's own rates", {
  # Unequal groups: the pooled rate is not the mean of the group rates, and
  # the metadata used to print the mean beside the pooled difference. Weekends
  # keep two complete trips a day (10), weekdays all three (15).
  d0 <- sdc_tost_design()
  iv <- d0$interviews
  nth <- stats::ave(seq_len(nrow(iv)), iv$date, iv$trip_status, FUN = seq_along)
  keep <- iv$trip_status == "incomplete" | iv$day_type == "weekday" | nth <= 2
  d <- sdc_q(add_interviews(
    creel_design(sdc_calendar(), date = date, strata = day_type), # nolint: object_usage_linter
    iv[keep, c("date", "catch_total", "hours_fished", "trip_status", "trip_duration")],
    catch = catch_total, effort = hours_fished, # nolint: object_usage_linter
    trip_status = trip_status, trip_duration = trip_duration # nolint: object_usage_linter
  ))
  v <- sdc_q(validate_incomplete_trips(d, catch_total, hours_fished, by = day_type))
  c_all <- sdc_q(estimate_catch_rate(d, estimator = "ratio-of-means", use_trips = "complete"))$estimates
  i_all <- sdc_q(estimate_catch_rate(d, estimator = "mor", use_trips = "incomplete"))$estimates
  m <- v$metadata$overall
  expect_equal(m$complete$estimate, c_all$estimate, tolerance = 1e-12)
  expect_equal(m$complete$se, c_all$se, tolerance = 1e-12)
  expect_equal(m$incomplete$estimate, i_all$estimate, tolerance = 1e-12)
  expect_equal(m$complete$n, c_all$n)
  expect_equal(m$complete$estimate - m$incomplete$estimate, v$overall_test$diff_estimate, tolerance = 1e-12)
  expect_null(attr(v$overall_test, "rates"))
  # The fixture discriminates: the mean of the group rates is a different number.
  expect_gt(abs(mean(v$group_tests$diff_estimate) - v$overall_test$diff_estimate) +
    abs(mean(sdc_q(estimate_catch_rate(d, by = day_type, estimator = "ratio-of-means", use_trips = "complete"))$estimates$estimate) - c_all$estimate), 1e-3)
})

test_that("SDC-16 (#673): a rate group missed by some bootstrap draws leaves the total's SE NA", {
  d <- sdc_bank_boat_design()
  iv <- d$interviews
  # Bank anglers interviewed on three weekdays only.
  keep <- iv$angler_type == "boat" | iv$date %in% sdc_calendar()$date[1:3]
  base <- d
  base$interviews <- NULL
  base$interview_survey <- NULL
  d <- sdc_q(add_interviews(base, iv[keep, setdiff(names(iv), ".rate_group")], # nolint: object_usage_linter
    catch = catch_total, effort = hours_fished, harvest = catch_kept, # nolint: object_usage_linter
    trip_status = trip_status, angler_type = angler_type, n_anglers = n_anglers # nolint: object_usage_linter
  ))
  rg <- sdc_bank_boat_groups()
  withr::local_seed(1)
  hit <- 0L
  res <- withCallingHandlers(
    suppressMessages(estimate_total_catch(d, target = "period_total", rate_groups = rg, variance = "bootstrap")),
    creel_warning_bootstrap_undefined_draws = function(w) {
      hit <<- hit + 1L
      invokeRestart("muffleWarning")
    },
    warning = function(w) invokeRestart("muffleWarning")
  )
  rates <- res$rate_groups$rates
  expect_true(is.na(rates$se[rates$grp == "bank"]))
  expect_true(is.finite(rates$se[rates$grp == "boat"]))
  expect_true(is.finite(res$estimates$estimate))
  expect_true(is.na(res$estimates$se))
  expect_identical(hit, 1L)
  # Taylor has no such draws.
  tay <- sdc_q(estimate_total_catch(d, target = "period_total", rate_groups = rg))
  expect_true(is.finite(tay$estimates$se))
})
