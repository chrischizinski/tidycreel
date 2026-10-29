# Totals with catch rates pooled more coarsely than effort (GH #389).
#
# The tests below fail on the obvious wrong implementation -- the pooled rate
# joined onto every effort cell and fed to the per-stratum product -- which
# understates the SE in three ways: a shared rate's error summed as if each
# cell had its own, its interviews counted once per cell, and bank and boat
# effort from the same drives summed with no covariance.

q <- function(x) suppressWarnings(suppressMessages(x))

season_design <- function() {
  d <- q(creel_design(example_season_calendar, date = date, strata = day_type))
  d <- q(add_counts(d, example_season_counts,
    count_col = "total_anglers", period_length_col = "daylight_hours"
  ))
  q(add_interviews(d, example_season_interviews,
    catch = catch_total, effort = hours_fished, harvest = catch_kept,
    trip_status = trip_status, n_anglers = n_anglers
  ))
}

# Bank and boat counted on the same drives at shared times, with a common day
# effect, so their effort covaries; bank trips are thin per day type.
bank_boat_design <- function(paired = TRUE) {
  withr::local_seed(389)
  cal <- creel_calendar("2024-06-01", "2024-07-31", strata = "day_type")[c("date", "day_type")]
  we <- cal$day_type == "weekend"
  u <- exp(stats::rnorm(nrow(cal), 0, 0.5)) * ifelse(we, 2, 1)
  s <- c(sample(which(!we), 12), sample(which(we), 7))
  cn <- do.call(rbind, lapply(s, function(i) {
    v <- exp(stats::rnorm(2, 0, 0.3))
    data.frame(
      date = cal$date[i], day_type = cal$day_type[i], count_time = c(9, 15),
      bank_anglers = stats::rpois(2, 6 * u[i] * v),
      boat_anglers = stats::rpois(2, 5 * u[i] * v), hours = 12
    )
  }))
  long <- derive_angler_count(cn, bank = bank_anglers, boat_anglers = boat_anglers, by_type = TRUE)
  if (!paired) {
    # Bank counted half an hour after boat: no shared occasions to pair on.
    long$count_time[long$angler_type == "bank"] <- long$count_time[long$angler_type == "bank"] + 0.5
  }
  iv <- do.call(rbind, lapply(s, function(i) {
    type <- rep(c("bank", "boat"), c(1L, 6L))
    hrs <- stats::runif(7, 1, 5)
    rate <- ifelse(type == "bank", 0.3, ifelse(we[i], 0.7, 0.5))
    data.frame(
      date = cal$date[i], day_type = cal$day_type[i], angler_type = type,
      hours_fished = hrs, catch_total = stats::rpois(7, rate * hrs),
      trip_status = "complete", n_anglers = 1L
    )
  }))
  d <- q(creel_design(cal, date = date, strata = day_type))
  d <- q(add_counts(d, long,
    count_col = "angler_count", count_time_col = count_time,
    period_length_col = "hours", unit_cols = c("date", "day_type", "angler_type")
  ))
  q(add_interviews(d, iv,
    catch = catch_total, effort = hours_fished,
    trip_status = trip_status, angler_type = angler_type, n_anglers = n_anglers
  ))
}

bank_boat_groups <- function() {
  data.frame(
    day_type = rep(c("weekday", "weekend"), each = 2),
    angler_type = rep(c("bank", "boat"), 2),
    grp = c("bank", "boat_wd", "bank", "boat_we")
  )
}

test_that("one rate group per stratum reproduces the standard total exactly", {
  # The regression anchor: with no rate shared across cells the new estimator
  # must be today's estimator, SE included. This is what caught the Goodman
  # term entering with the wrong sign.
  d <- season_design()
  rg <- data.frame(day_type = c("weekday", "weekend"), grp = c("weekday", "weekend"))
  for (fn in list(estimate_total_catch, estimate_total_harvest)) {
    for (tg in c("sampled_days", "period_total")) {
      old <- q(fn(d, target = tg))$estimates
      new <- q(fn(d, target = tg, rate_groups = rg))$estimates
      expect_equal(new$estimate, old$estimate, tolerance = 1e-10)
      expect_equal(new$se, old$se, tolerance = 1e-10)
      expect_equal(new$n, old$n)
    }
  }
  old <- q(estimate_total_catch(d, by = day_type, target = "period_total"))$estimates
  new <- q(estimate_total_catch(d, by = day_type, target = "period_total", rate_groups = rg))$estimates
  expect_equal(new$se, old$se, tolerance = 1e-10)
})

test_that("a rate shared by two strata enters the variance as (E1 + E2)^2 Var(R)", {
  # Written from the definition, not read back from the estimator. The per-cell
  # form (E1^2 + E2^2) Var(R) is smaller and must not be what comes out.
  d <- season_design()
  rg <- data.frame(day_type = c("weekday", "weekend"), grp = "season")
  res <- q(estimate_total_catch(d, target = "period_total", rate_groups = rg))
  rate <- res$rate_groups$rates
  e_cells <- q(estimate_effort(d, by = day_type, target = "period_total"))$estimates
  e_all <- q(estimate_effort(d, target = "period_total"))$estimates

  r <- rate$estimate
  v_r <- rate$se^2
  e_sum <- sum(e_cells$estimate)
  goodman_cross <- sum(e_cells$se^2) * v_r
  expected <- r^2 * e_all$se^2 + e_sum^2 * v_r - goodman_cross
  per_cell <- r^2 * e_all$se^2 + sum(e_cells$estimate^2) * v_r - goodman_cross

  expect_equal(res$estimates$estimate, r * e_sum, tolerance = 1e-10)
  expect_equal(res$estimates$se^2, expected, tolerance = 1e-8)
  expect_gt(expected, per_cell)
})

test_that("a pooled group's interviews are counted once", {
  d <- season_design()
  rg <- data.frame(day_type = c("weekday", "weekend"), grp = "season")
  res <- q(estimate_total_catch(d, target = "period_total", rate_groups = rg))
  n_complete <- sum(d$interviews$trip_status == "complete")
  expect_equal(res$estimates$n, n_complete)
  expect_equal(res$rate_groups$rates$n, n_complete)
})

test_that("bank and boat counted on the same drives covary in the total", {
  # Effort here shares a day effect and count times, so the bank-boat
  # covariance is positive and the total's variance exceeds the sum of the two
  # rows' variances. Summing per-type rows as independent understates the SE.
  d <- bank_boat_design()
  rg <- bank_boat_groups()
  total <- q(estimate_total_catch(d, target = "period_total", rate_groups = rg))$estimates
  rows <- q(estimate_total_catch(d, by = angler_type, target = "period_total", rate_groups = rg))$estimates

  expect_equal(total$estimate, sum(rows$estimate), tolerance = 1e-8)
  expect_gt(total$se^2, sum(rows$se^2))
})

test_that("the result shows which rate each cell used", {
  d <- bank_boat_design()
  res <- q(estimate_total_catch(d, target = "period_total", rate_groups = bank_boat_groups()))
  expect_equal(res$rate_groups$map, bank_boat_groups())
  expect_setequal(res$rate_groups$rates$grp, c("bank", "boat_wd", "boat_we"))
  expect_true(all(res$rate_groups$rates$n >= 10))
})

test_that("release totals take rate groups too", {
  d <- q(creel_design(example_calendar, date = date, strata = day_type))
  d <- q(add_counts(d, example_counts))
  d <- q(add_interviews(d, example_interviews,
    catch = catch_total, effort = hours_fished, harvest = catch_kept,
    trip_status = trip_status, trip_duration = trip_duration
  ))
  d <- q(add_catch(d, example_catch,
    catch_uid = interview_id, interview_uid = interview_id,
    species = species, count = count, catch_type = catch_type
  ))
  rg <- data.frame(day_type = c("weekday", "weekend"), grp = "season")
  res <- q(estimate_total_release(d, rate_groups = rg))
  expect_s3_class(res, "creel_estimates")
  expect_equal(res$estimates$estimate, res$rate_groups$rates$estimate *
    q(estimate_effort(d))$estimates$estimate, tolerance = 1e-10)
})

test_that("rate groups refuse every cell, interview or row they cannot place", {
  d <- bank_boat_design()
  rg <- bank_boat_groups()

  expect_error(
    estimate_total_catch(d, rate_groups = rg[-2, ]),
    "no rate group", class = "creel_error_rate_groups"
  )
  extra <- rbind(rg, data.frame(day_type = "weekday", angler_type = "ice", grp = "x"))
  expect_error(
    estimate_total_catch(d, rate_groups = extra),
    "no effort cell", class = "creel_error_rate_groups"
  )
  expect_error(
    estimate_total_catch(d, rate_groups = rbind(rg, rg[1, ])),
    "more than once", class = "creel_error_rate_groups"
  )
  bad <- rg
  bad$grp[1] <- NA
  expect_error(
    estimate_total_catch(d, rate_groups = bad),
    "empty or missing group", class = "creel_error_rate_groups"
  )
  expect_error(
    estimate_total_catch(d, rate_groups = transform(rg, other = 1)),
    "exactly one group column", class = "creel_error_rate_groups"
  )
  expect_error(
    estimate_total_catch(d, rate_groups = rg, missing_rate = "exclude"),
    "does not combine", class = "creel_error_rate_groups"
  )
})

test_that("an interview outside every rate group is refused, not left out", {
  d <- bank_boat_design()
  d$interviews$angler_type[1] <- "kayak"
  expect_error(
    estimate_total_catch(d, rate_groups = bank_boat_groups()),
    "in no rate group", class = "creel_error_rate_groups"
  )
})

test_that("a rate group under the 10-trip floor is refused", {
  # Bank trips are one a day, so bank by day type alone is 12 and 7 trips: the
  # weekend bank group is below the floor that pooling exists to reach.
  d <- bank_boat_design()
  rg <- bank_boat_groups()
  rg$grp <- c("bank_wd", "boat_wd", "bank_we", "boat_we")
  expect_error(
    q(estimate_total_catch(d, rate_groups = rg)),
    "Insufficient sample size"
  )
})

test_that("angler_type keys need angler-type counts", {
  d <- season_design()
  rg <- data.frame(day_type = "weekday", angler_type = "bank", grp = "a")
  expect_error(
    estimate_total_catch(d, rate_groups = rg),
    "counts have no", class = "creel_error_rate_groups"
  )
})

test_that("rate groups by species are refused until they are supported", {
  d <- bank_boat_design()
  expect_error(
    estimate_total_catch(d, by = species, rate_groups = bank_boat_groups())
  )
})

test_that("one group over every bank and boat cell scales effort's full variance, within-day included", {
  # With a single rate the total is R * E, so its effort term is R^2 Var(E),
  # where Var(E) is the package's own effort variance: between days, within
  # days with bank and boat paired at their shared count times. A reweighting
  # that missed any stored form of the counts (the occasions, say) would leave
  # part of Var(E) unscaled and miss this.
  d <- bank_boat_design()
  rg <- bank_boat_groups()
  rg$grp <- "all"
  res <- q(estimate_total_catch(d, target = "period_total", rate_groups = rg))
  rate <- res$rate_groups$rates
  e_all <- q(estimate_effort(d, target = "period_total"))$estimates
  expect_gt(e_all$se_within, 0)

  e_cell <- q(estimate_effort(d, by = c(day_type, angler_type), target = "period_total"))$estimates
  v_r <- rate$se^2
  expected <- rate$estimate^2 * e_all$se^2 + e_all$estimate^2 * v_r - e_all$se^2 * v_r
  expect_equal(res$estimates$se^2, expected, tolerance = 1e-8)
  expect_equal(res$estimates$estimate, rate$estimate * sum(e_cell$estimate), tolerance = 1e-8)
})

test_that("the same holds when bank and boat were not counted at the same times", {
  # Unpaired units take the within-day term from each unit's own sums of
  # squares rather than from the occasions, so that stored form is scaled too.
  d <- bank_boat_design(paired = FALSE)
  rg <- bank_boat_groups()
  rg$grp <- "all"
  res <- q(estimate_total_catch(d, target = "period_total", rate_groups = rg))
  rate <- res$rate_groups$rates
  e_all <- q(estimate_effort(d, target = "period_total"))$estimates
  expect_gt(e_all$se_within, 0)
  v_r <- rate$se^2
  expected <- rate$estimate^2 * e_all$se^2 + e_all$estimate^2 * v_r - e_all$se^2 * v_r
  expect_equal(res$estimates$se^2, expected, tolerance = 1e-8)
})
