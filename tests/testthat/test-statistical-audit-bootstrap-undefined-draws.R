# A bootstrap draw that misses a domain leaves its SE unknown (GH #673) ----
#
# Interview variances are taken between days, and a bootstrap draw resamples
# days within each stratum. A group seen on two of five weekdays is missed
# entirely by some draws, and its rate on such a draw is 0/0. survey's
# svrVar() dropped those draws, behind a suppressed warning, and reported the
# SE of the draws where the group happened to appear: a variance conditional
# on the domain being sampled, not the one asked for. The SE is now NA, with
# creel_warning_bootstrap_undefined_draws naming the domain. Taylor and the
# jackknife have no such draws (deleting one day never empties a domain seen
# on two) and are unchanged.

bud_q <- function(x) suppressMessages(x)

bud_calendar <- function() {
  data.frame(
    date = as.Date("2024-06-03") + c(0:4, 7:11),
    day_type = rep(c("weekday", "weekend"), each = 5),
    stringsAsFactors = FALSE
  )
}

# Eight trips a day; the fly anglers were interviewed on two weekdays only.
bud_interviews <- function(fly_status = "complete") {
  cal <- bud_calendar()
  effort <- c(2, 3, 4, 2.5, 3.5, 1.5, 2, 3)
  do.call(rbind, lapply(seq_len(nrow(cal)), function(i) {
    fly <- i %in% c(1L, 2L)
    gear <- if (fly) c(rep("fly", 5), rep("bait", 3)) else rep("bait", 8)
    data.frame(
      date = cal$date[i],
      catch_total = c(1, 3, 2, 4, 0, 2, 1, 5) + i %% 3,
      catch_kept = pmin(c(1, 2, 1, 3, 0, 1, 1, 4) + i %% 2, c(1, 3, 2, 4, 0, 2, 1, 5) + i %% 3),
      hours_fished = effort, trip_duration = effort,
      trip_status = ifelse(gear == "fly", fly_status, "complete"),
      gear = gear,
      stringsAsFactors = FALSE
    )
  }))
}

bud_design <- function(iv = bud_interviews()) {
  suppressWarnings(bud_q(add_interviews(
    add_rate_counts(creel_design(bud_calendar(), date = date, strata = day_type)), # rates pooled across strata need each stratum's effort (GH #691)
    iv,
    catch = catch_total, harvest = catch_kept, effort = hours_fished, # nolint: object_usage_linter
    trip_status = trip_status, trip_duration = trip_duration, n_anglers = 1 # nolint: object_usage_linter
  )))
}

# Runs `expr` under a fixed seed and returns its value with the classed
# warnings it raised (the rest -- small-sample and the like -- are muffled).
bud_run <- function(expr, seed = 1) {
  set.seed(seed)
  hits <- list()
  value <- withCallingHandlers(
    bud_q(expr),
    creel_warning_bootstrap_undefined_draws = function(w) {
      hits[[length(hits) + 1L]] <<- w
      invokeRestart("muffleWarning")
    },
    warning = function(w) invokeRestart("muffleWarning")
  )
  list(value = value, warnings = hits)
}

bud_se <- function(r, group) r$estimates$se[r$estimates$gear == group]

test_that("BUD-00: the fixture has draws that miss the fly days", {
  d <- bud_design()
  set.seed(1)
  rep <- suppressWarnings(survey::as.svrepdesign(
    d$interview_survey,
    type = "bootstrap", replicates = 500
  ))
  w <- stats::weights(rep, "analysis")
  fly <- rep$variables$gear == "fly"
  expect_gt(sum(colSums(w[fly, , drop = FALSE]) == 0), 0)
})

test_that("BUD-01 (#673): a grouped bootstrap rate leaves the missed group's SE NA and warns", {
  d <- bud_design()
  out <- bud_run(estimate_catch_rate(d, by = gear, variance = "bootstrap")) # nolint: object_usage_linter
  r <- out$value
  expect_true(is.na(bud_se(r, "fly")))
  expect_true(is.na(r$estimates$ci_lower[r$estimates$gear == "fly"]))
  # The point estimate is not a resampling quantity and stays.
  expect_true(is.finite(r$estimates$estimate[r$estimates$gear == "fly"]))
  # A group present on every day keeps its bootstrap SE.
  expect_true(is.finite(bud_se(r, "bait")))
  expect_length(out$warnings, 1L)
  expect_match(conditionMessage(out$warnings[[1]]), "gear = fly", fixed = TRUE)
})

test_that("BUD-02 (#673): Taylor and the jackknife are unaffected", {
  d <- bud_design()
  for (v in c("taylor", "jackknife")) {
    out <- bud_run(estimate_catch_rate(d, by = gear, variance = v)) # nolint: object_usage_linter
    expect_true(all(is.finite(out$value$estimates$se)), info = v)
    expect_length(out$warnings, 0L)
  }
})

test_that("BUD-03 (#673): every grouped rate estimator applies the same rule", {
  # A fresh design per fit, since a tier-2 warning prints once per design.
  fits <- list(
    harvest = function(d) estimate_harvest_rate(d, by = gear, variance = "bootstrap"),
    origin = function(d) estimate_catch_rate(d, by = gear, variance = "bootstrap", estimator = "regression"),
    # With an intercept svyglm() gives no warning on an empty draw: it returned
    # a bare vector there, and the next step aborted on it.
    intercept = function(d) {
      estimate_catch_rate(d, by = gear, variance = "bootstrap", estimator = "regression", force_origin = FALSE)
    }
  )
  for (nm in names(fits)) {
    out <- bud_run(fits[[nm]](bud_design()))
    expect_true(is.na(bud_se(out$value, "fly")), info = nm)
    expect_true(is.finite(bud_se(out$value, "bait")), info = nm)
    expect_length(out$warnings, 1L)
  }
  # The slope itself is the full-sample fit, the one Taylor reports.
  boot <- bud_run(fits$intercept(bud_design()))$value$estimates
  taylor <- bud_run(estimate_catch_rate( # nolint: object_usage_linter
    bud_design(),
    by = gear, variance = "taylor", estimator = "regression", force_origin = FALSE
  ))$value$estimates
  expect_equal(boot$estimate, taylor$estimate, tolerance = 1e-10)
})

test_that("BUD-04 (#673): mean-of-ratios, grouped and as a lone domain", {
  # The incomplete trips are on weekdays only, so pooled across day types the
  # weekend has no rate from them and the call is refused (GH #691). The
  # bootstrap behaviour under test is the interview survey's, checked with the
  # pooling switched off.
  d <- bud_design(bud_interviews(fly_status = "incomplete"))
  expect_error(
    bud_q(estimate_catch_rate(d, estimator = "mor", use_trips = "incomplete")), # nolint: object_usage_linter
    class = "creel_error_rate_needs_effort"
  )
  grouped <- bud_run(without_rate_pooling(estimate_catch_rate( # nolint: object_usage_linter
    d,
    by = gear, variance = "bootstrap", estimator = "mor", use_trips = "incomplete" # nolint: object_usage_linter
  )))
  expect_true(is.na(bud_se(grouped$value, "fly")))
  # The incomplete trips are all fly trips: the domain itself is missed. A
  # fresh design, since a tier-2 warning prints once per design.
  d <- bud_design(bud_interviews(fly_status = "incomplete"))
  lone <- bud_run(without_rate_pooling(estimate_catch_rate( # nolint: object_usage_linter
    d,
    variance = "bootstrap", estimator = "mor", use_trips = "incomplete"
  )))
  expect_true(is.na(lone$value$estimates$se))
  expect_length(lone$warnings, 1L)
  expect_match(conditionMessage(lone$warnings[[1]]), "the estimate", fixed = TRUE)
})

test_that("BUD-05 (#673): the groups' covariance uses every draw, not those where all groups appeared", {
  d <- bud_design()
  set.seed(7)
  got <- suppressWarnings(bud_q(estimate_cpue_grouped(
    d, "gear", "bootstrap", 0.95,
    covmat = TRUE
  )))
  fly <- got$estimates$gear == "fly"
  expect_true(all(is.na(got$rate_vcov[fly, ])))
  expect_true(all(is.na(got$rate_vcov[, fly])))
  # The bait variance from all 500 draws equals its reported SE squared; the
  # old matrix dropped the draws that missed fly and disagreed with it.
  bait <- which(!fly)
  expect_equal(got$rate_vcov[bait, bait], got$estimates$se[bait]^2, tolerance = 1e-12)
})

test_that("BUD-06 (#673): svyby_rate_vcov() recomputes off-diagonals from every draw", {
  set.seed(3)
  x <- data.frame(
    day = rep(1:8, each = 3), st = rep(c("a", "b"), each = 12),
    c = stats::rpois(24, 3), e = stats::runif(24, 1, 4)
  )
  # p and q on every day; rare on two days of stratum a only.
  x$g <- ifelse(x$day %in% 1:2 & rep(1:3, 8) == 3L, "rare", ifelse(rep(1:3, 8) == 1L, "p", "q"))
  des <- survey::svydesign(ids = ~day, strata = ~st, data = x, weights = rep(1, 24))
  rep <- survey::as.svrepdesign(des, type = "bootstrap", replicates = 300)
  all3 <- suppressWarnings(survey::svyby(~c, ~g, rep, draws_defined(survey::svyratio, "g"),
    denominator = ~e, covmat = TRUE, return.replicates = TRUE
  ))
  se <- survey::SE(all3)
  v <- svyby_rate_vcov(all3, se)
  # Reference: the same draws, rare left out, so none is dropped.
  two <- suppressWarnings(survey::svyby(~c, ~g, subset(rep, g != "rare"), survey::svyratio,
    denominator = ~e, covmat = TRUE
  ))
  keep <- all3$g != "rare"
  expect_equal(v[keep, keep], unname(as.matrix(stats::vcov(two))), tolerance = 1e-12)
  expect_true(all(is.na(v[!keep, ])))
})

test_that("BUD-07 (#673): the equivalence test is left untested, not tested on part of the draws", {
  d <- bud_design(bud_interviews(fly_status = "incomplete"))
  out <- bud_run(validate_incomplete_trips( # nolint: object_usage_linter
    d,
    catch = catch_total, effort = hours_fished, variance = "bootstrap" # nolint: object_usage_linter
  ))
  # Untested (NA), neither passed nor failed; the joint SE of the difference
  # is unknown, not the SE over the draws that saw incomplete trips.
  expect_true(is.na(out$value$overall_test$equivalence_passed))
  expect_true(is.na(out$value$overall_test$se_diff))
  expect_match(out$value$recommendation, "^Not tested")
  # The incomplete-trip fit ran under suppressWarnings(), which marked the
  # class printed and silenced every later copy: no warning reached the user.
  expect_length(out$warnings, 1L)
  expect_no_error(utils::capture.output(print(out$value)))
})

test_that("BUD-08 (#673): bus-route rates apply the same rule", {
  d <- build_br_design_for_tests(3, 10, 120, seed = 1)
  iv <- d$interviews
  days <- sort(unique(iv$date))
  weekdays_seen <- days[!weekdays(days) %in% c("Saturday", "Sunday")]
  iv$gear <- ifelse(iv$date %in% weekdays_seen[1:2], "fly", "bait")
  d$interviews <- iv
  boot <- bud_run(estimate_catch_rate(d, by = gear, variance = "bootstrap")) # nolint: object_usage_linter
  expect_true(is.na(bud_se(boot$value, "fly")))
  expect_true(is.finite(bud_se(boot$value, "bait")))
  expect_length(boot$warnings, 1L)
  taylor <- bud_run(estimate_catch_rate(d, by = gear, variance = "taylor")) # nolint: object_usage_linter
  expect_true(all(is.finite(taylor$value$estimates$se)))
})

test_that("BUD-09 (#673): an ungrouped ratio-of-means rate over a sparse trip type", {
  # Complete trips are the fly trips, on two weekdays; the rest are incomplete.
  iv <- bud_interviews()
  iv$trip_status <- ifelse(iv$gear == "fly", "complete", "incomplete")
  d <- bud_design(iv)
  # The complete trips are on weekdays only, so pooled across day types the
  # weekend has no rate from them and the call is refused (GH #691). The
  # bootstrap behaviour under test is the interview survey's, checked with the
  # pooling switched off.
  expect_error(bud_q(estimate_catch_rate(d)), class = "creel_error_rate_needs_effort") # nolint: object_usage_linter
  cpue <- bud_run(without_rate_pooling(estimate_catch_rate(d, variance = "bootstrap"))) # nolint: object_usage_linter
  expect_true(is.na(cpue$value$estimates$se))
  expect_length(cpue$warnings, 1L)
  hpue <- bud_run(without_rate_pooling(estimate_harvest_rate(bud_design(iv), variance = "bootstrap"))) # nolint: object_usage_linter
  expect_true(is.na(hpue$value$estimates$se))
  taylor <- bud_run(without_rate_pooling(estimate_catch_rate(d, variance = "taylor"))) # nolint: object_usage_linter
  expect_true(is.finite(taylor$value$estimates$se))
})

test_that("BUD-10 (#673): grouped regression names every group left without an SE", {
  # A second sparse group, spin, on two weekend days.
  iv <- bud_interviews()
  days <- sort(unique(iv$date))
  idx <- which(iv$date %in% days[6:7] & iv$gear == "bait")
  iv$gear[idx[(seq_along(idx) %% 8) %in% 1:5]] <- "spin"
  out <- bud_run(estimate_catch_rate( # nolint: object_usage_linter
    bud_design(iv),
    by = gear, variance = "bootstrap", estimator = "regression"
  ))
  expect_true(all(is.na(out$value$estimates$se[out$value$estimates$gear != "bait"])))
  # One warning for the call, naming both: each group used to warn on its own,
  # and the once-per-design rule muffled every group after the first.
  expect_length(out$warnings, 1L)
  msg <- conditionMessage(out$warnings[[1]])
  expect_match(msg, "gear = fly", fixed = TRUE)
  expect_match(msg, "gear = spin", fixed = TRUE)
})

test_that("BUD-11 (#673): an unweighted grouped mean of ratios kept with its replicates", {
  # covmat = TRUE returns the replicates; svymean() then keeps its variance on
  # $mean, and blanking the outer attribute left the conditional SE in place.
  set.seed(5)
  got <- suppressWarnings(bud_q(estimate_cpue_grouped(
    bud_design(), "gear", "bootstrap", 0.95,
    estimator = "mor", covmat = TRUE
  )))
  fly <- got$estimates$gear == "fly"
  expect_true(is.na(got$estimates$se[fly]))
  expect_true(is.finite(got$estimates$se[!fly]))
  expect_true(all(is.na(got$rate_vcov[fly, ])))
})

test_that("BUD-12 (#673): the warning names a group by its values, not their codes", {
  # The first row has zero weight: the label comes from the domain's rows.
  v <- data.frame(
    g = factor(c("a", "b"), levels = c("a", "b")), z = c(9, 1),
    dt = as.Date("2024-06-03") + 0:1, w = c(0, 1)
  )
  des <- suppressWarnings(survey::svydesign(ids = ~1, weights = ~w, data = v))
  lab <- draws_domain_label(des, c("g", "z", "dt"))
  expect_identical(lab, "g = b, z = 1, dt = 2024-06-04")
})

test_that("BUD-13 (#673): a jackknife replicate that cannot fit leaves the SE unknown, named as such", {
  # Fly on three weekdays, effort constant within each day at 2, 2 and 4
  # hours: deleting the third day leaves no effort contrast and no slope.
  iv <- bud_interviews()
  days <- sort(unique(iv$date))
  iv$gear[iv$date == days[3] & seq_len(nrow(iv)) %% 8 %in% 1:5] <- "fly"
  fly <- iv$gear == "fly"
  iv$hours_fished[fly] <- c(2, 2, 4)[match(iv$date[fly], days[1:3])]
  iv$trip_duration <- iv$hours_fished
  out <- bud_run(estimate_catch_rate( # nolint: object_usage_linter
    bud_design(iv),
    by = gear, variance = "jackknife", estimator = "regression", force_origin = FALSE
  ))
  expect_true(is.na(bud_se(out$value, "fly")))
  expect_true(is.finite(bud_se(out$value, "bait")))
  expect_length(out$warnings, 1L)
  # Not the bootstrap's advice to switch to the jackknife already in use.
  expect_no_match(conditionMessage(out$warnings[[1]]), "jackknife", fixed = TRUE)
})

test_that("BUD-14 (#673): a grouped equivalence test left untested is reported as untested", {
  # Every trip recorded twice, once complete and once incomplete, so the two
  # rates agree and every test that can run passes. Fly is on two weekdays
  # only, 15 trips a day to clear the ratio floor of 10 per group.
  iv <- bud_interviews()
  iv <- rbind(iv, iv[iv$gear == "fly", ], iv[iv$gear == "fly", ])
  iv <- rbind(transform(iv, trip_status = "complete"), transform(iv, trip_status = "incomplete"))
  out <- bud_run(validate_incomplete_trips( # nolint: object_usage_linter
    bud_design(iv),
    catch = catch_total, effort = hours_fished, by = gear, variance = "bootstrap" # nolint: object_usage_linter
  ))
  g <- out$value$group_tests
  fly <- g$gear == "fly"
  expect_true(is.na(g$equivalence_passed[fly]))
  expect_true(isTRUE(g$equivalence_passed[!fly]))
  # Nothing failed: the whole is untested, not failed.
  expect_true(is.na(out$value$passed))
  expect_match(out$value$recommendation, "^Not tested")
  expect_match(out$value$recommendation, "gear = fly", fixed = TRUE)
  # The joint fit keeps the group by zeroing the others; it is named, not
  # reported as "the estimate".
  expect_true(any(grepl("gear = fly", vapply(out$warnings, conditionMessage, ""), fixed = TRUE)))
  printed <- format(out$value)
  expect_true(any(grepl("NOT TESTED", printed, fixed = TRUE)))
  expect_true(any(grepl("one trip type only, or no SE", printed, fixed = TRUE)))
  expect_no_error(utils::capture.output(print(out$value)))
})
