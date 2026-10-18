# GH #470 / #366: aerial effort and the totals built on it.
#
# An aerial count is anglers seen at one instant; effort is that count times
# h_open * a / v (fishing-day length, angler-to-people ratio, visibility
# correction). estimate_effort() applied it, but the catch / harvest / release
# totals reached effort through estimate_effort_total() and
# estimate_effort_grouped(), which did not -- every aerial total multiplied the
# rate by the raw count, so h_open, a and v had no effect on it (250.55 at
# h_open = 14 and at h_open = 7 on the example data). And estimate_effort(by = )
# on an aerial design dropped `by` and returned the pooled number (#366).
#
# a and v are single estimates shared by every stratum, so their uncertainty is
# added once to each reported total, estimate^2 * ((se_a/a)^2 + (se_v/v)^2),
# never per stratum and summed in quadrature (#150).

at_calendar <- function() {
  data.frame(
    date = as.Date("2024-07-01") + 0:7,
    day_type = rep(c("weekday", "weekday", "weekend", "weekend"), 2)
  )
}

at_design <- function(h_open = 14, v = 1, v_se = 0, a = 1, a_se = 0, cal = at_calendar()) {
  d <- creel_design( # nolint: object_usage_linter
    cal,
    date = date, strata = day_type, survey_type = "aerial",
    visibility_correction = v, visibility_se = v_se,
    angler_ratio = a, angler_ratio_se = a_se, h_open = h_open
  )
  sampled <- cal[c(1, 2, 5, 3, 4, 8), ] # rows 1-8 are at_calendar()'s days
  counts <- data.frame(sampled, n_anglers = c(22L, 18L, 30L, 45L, 38L, 51L))
  d <- add_counts(d, counts) # nolint: object_usage_linter
  # Five interviews a day, 15 per stratum: ratio estimation by day_type needs 10.
  iv <- data.frame(
    interview_id = 1:30,
    date = rep(sampled$date, each = 5),
    day_type = rep(sampled$day_type, each = 5),
    trip_status = "complete",
    hours_fished = rep(c(2.5, 3, 1.5, 4, 2, 3.5, 1, 2.5, 3, 4.5), 3),
    walleye = c(0L, 1L, 2L, 0L, 1L, 0L, 3L, 1L, 0L, 2L, 1L, 0L, 3L, 1L, 0L,
                2L, 1L, 1L, 4L, 0L, 1L, 2L, 0L, 1L, 3L, 0L, 1L, 2L, 1L, 0L),
    kept = c(0L, 1L, 1L, 0L, 1L, 0L, 2L, 1L, 0L, 1L, 1L, 0L, 2L, 1L, 0L,
             1L, 0L, 1L, 2L, 0L, 1L, 1L, 0L, 0L, 2L, 0L, 1L, 1L, 0L, 0L)
  )
  d <- add_interviews( # nolint: object_usage_linter
    d, iv,
    catch = walleye, harvest = kept, effort = hours_fished,
    trip_status = trip_status, n_anglers = 1
  )
  released <- iv$walleye - iv$kept
  catch <- rbind(
    data.frame(interview_id = iv$interview_id, species = "walleye", count = iv$kept, catch_type = "harvested"),
    data.frame(interview_id = iv$interview_id, species = "walleye", count = released, catch_type = "released")
  )
  add_catch( # nolint: object_usage_linter
    d, catch,
    catch_uid = interview_id, interview_uid = interview_id,
    species = species, count = count, catch_type = catch_type
  )
}

at_quiet <- function(expr) suppressWarnings(suppressMessages(expr))

at_totals <- list(
  catch = function(d, ...) at_quiet(estimate_total_catch(d, ...)), # nolint: object_usage_linter
  harvest = function(d, ...) at_quiet(estimate_total_harvest(d, ...)), # nolint: object_usage_linter
  release = function(d, ...) at_quiet(estimate_total_release(d, ...)) # nolint: object_usage_linter
)

test_that("#470: every aerial total scales with h_open, on every path", {
  d14 <- at_quiet(at_design(h_open = 14))
  d7 <- at_quiet(at_design(h_open = 7))
  for (nm in names(at_totals)) {
    f <- at_totals[[nm]]
    expect_equal(f(d14)$estimates$estimate, 2 * f(d7)$estimates$estimate, info = nm)
    expect_equal(
      f(d14, by = day_type)$estimates$estimate,
      2 * f(d7, by = day_type)$estimates$estimate,
      info = paste(nm, "by")
    )
  }
  # The species path is a third route to effort.
  expect_equal(
    at_totals$catch(d14, by = species)$estimates$estimate,
    2 * at_totals$catch(d7, by = species)$estimates$estimate
  )
})

test_that("#470: an aerial total is the rate times effort in angler-hours, not raw counts", {
  # Hand value: sum over strata of (h_open * expanded count_h) * catch rate_h.
  d <- at_quiet(at_design(h_open = 14))
  effort <- at_quiet(estimate_effort(d, by = day_type))$estimates # nolint: object_usage_linter
  rate <- at_quiet(estimate_catch_rate(d, by = day_type))$estimates # nolint: object_usage_linter
  rate <- rate[match(effort$day_type, rate$day_type), ]
  expect_equal(at_totals$catch(d)$estimates$estimate, sum(effort$estimate * rate$estimate))
  # And the angler ratio and visibility correction reach it: a / v = 0.9 / 0.8.
  d_av <- at_quiet(at_design(h_open = 14, v = 0.8, a = 0.9))
  expect_equal(
    at_totals$catch(d_av)$estimates$estimate,
    0.9 / 0.8 * at_totals$catch(d)$estimates$estimate
  )
})

test_that("#470: a and v uncertainty enters once at the total, not per stratum", {
  base <- at_quiet(at_design(h_open = 14, v = 0.8, a = 0.9))
  cal <- at_quiet(at_design(h_open = 14, v = 0.8, v_se = 0.05, a = 0.9, a_se = 0.03))
  rel <- (0.05 / 0.8)^2 + (0.03 / 0.9)^2
  for (nm in names(at_totals)) {
    f <- at_totals[[nm]]
    t0 <- f(base)$estimates
    t1 <- f(cal)$estimates
    expect_equal(t1$estimate, t0$estimate, info = nm)
    expect_equal(t1$se^2, t0$se^2 + t1$estimate^2 * rel, info = nm)
    # Per row of a grouped total too: each row is its own reported quantity.
    g0 <- f(base, by = day_type)$estimates
    g1 <- f(cal, by = day_type)$estimates
    expect_equal(g1$se^2, g0$se^2 + g1$estimate^2 * rel, info = paste(nm, "by"))
  }
  # The mutant this pins: adding the term per stratum and summing in
  # quadrature gives sum(T_h^2) * rel, strictly less than T^2 * rel here.
  g <- at_totals$catch(cal, by = day_type)$estimates
  expect_lt(sum(g$estimate^2) * rel, sum(g$estimate)^2 * rel)
})

test_that("#470: an unknown visibility SE makes the total's SE unknown, not smaller", {
  # visibility_correction = "none" is the declared opt-out: v = 1, its SE unknown.
  d <- at_quiet(at_design(h_open = 14, v = "none", v_se = NULL))
  t <- at_totals$catch(d)$estimates
  expect_true(is.finite(t$estimate))
  expect_true(is.na(t$se))
})

test_that("#366: estimate_effort(by = ) on an aerial design is grouped, not pooled", {
  d <- at_quiet(at_design(h_open = 14))
  pooled <- at_quiet(estimate_effort(d)) # nolint: object_usage_linter
  grouped <- at_quiet(estimate_effort(d, by = day_type)) # nolint: object_usage_linter
  expect_equal(grouped$by_vars, "day_type")
  expect_equal(nrow(grouped$estimates), 2L)
  expect_equal(sum(grouped$estimates$estimate), pooled$estimates$estimate)
  expect_equal(grouped$unit, "angler-hours")
})

test_that("#366: each aerial effort group carries the shared a and v term in its own SE", {
  base <- at_quiet(at_design(h_open = 14, v = 0.8, a = 0.9))
  cal <- at_quiet(at_design(h_open = 14, v = 0.8, v_se = 0.05, a = 0.9, a_se = 0.03))
  rel <- (0.05 / 0.8)^2 + (0.03 / 0.9)^2
  g0 <- at_quiet(estimate_effort(base, by = day_type))$estimates # nolint: object_usage_linter
  g1 <- at_quiet(estimate_effort(cal, by = day_type))$estimates # nolint: object_usage_linter
  # Two rows, or the identity below holds trivially for one pooled row.
  expect_equal(nrow(g1), 2L)
  expect_equal(g1$se^2, g0$se^2 + g1$estimate^2 * rel)
  # Pooled effort composes the same terms, so a single-stratum grouping of the
  # whole design would agree with it; across two strata, the pooled SE carries
  # T^2 * rel once.
  p1 <- at_quiet(estimate_effort(cal))$estimates # nolint: object_usage_linter
  p0 <- at_quiet(estimate_effort(base))$estimates # nolint: object_usage_linter
  expect_equal(p1$se^2, p0$se^2 + p1$estimate^2 * rel)
})

test_that("#366: estimate_effort(by = ) on a sectioned design is refused, not dropped", {
  sections_df <- data.frame(section = c("North", "Central", "South"))
  d <- at_quiet(creel_design(example_sections_calendar, date = date, strata = day_type)) # nolint: object_usage_linter
  d <- at_quiet(add_sections(d, sections_df, section_col = section)) # nolint: object_usage_linter
  d <- at_quiet(add_counts(d, example_sections_counts)) # nolint: object_usage_linter
  expect_error(
    estimate_effort(d, by = day_type), # nolint: object_usage_linter
    class = "creel_error_dispatch_unsupported"
  )
})

test_that("#470: a zero aerial total has SE 0 even when a and v uncertainty is unknown", {
  # 0 * NA is NA; a total that is exactly zero is zero whatever a and v are.
  d <- at_quiet(at_design(h_open = 14, v = "none", v_se = NULL))
  d$interviews$walleye <- 0L
  d$interviews$kept <- 0L
  t <- at_quiet(estimate_total_harvest(d))$estimates # nolint: object_usage_linter
  expect_equal(t$estimate, 0)
  expect_false(is.na(t$se))
})

test_that("#366: grouped aerial effort names its components, NA when unknown", {
  g <- at_quiet(estimate_effort(at_quiet(at_design(h_open = 14, v = "none", v_se = NULL)), by = day_type)) # nolint: object_usage_linter
  expect_true(all(is.na(g$se_components$visibility)))
  expect_length(g$se_components$visibility, 2L)
  g2 <- at_quiet(estimate_effort(at_quiet(at_design(h_open = 14, v = 0.8, v_se = 0.05)), by = day_type)) # nolint: object_usage_linter
  expect_equal(g2$se_components$visibility, g2$estimates$estimate * 0.05 / 0.8)
})

test_that("#470: add_sections() refuses an aerial design", {
  # No sectioned aerial estimator: effort ignored the sections, and totals
  # treated the shared a and v as independent across them.
  d <- at_quiet(at_design())
  expect_error(
    add_sections(d, data.frame(section = c("N", "S")), section_col = section), # nolint: object_usage_linter
    class = "creel_error_dispatch_unsupported"
  )
})

test_that("#366: the sectioned `by` refusal comes before the period-length warning", {
  sections_df <- data.frame(section = c("North", "Central", "South"))
  d <- at_quiet(creel_design(example_sections_calendar, date = date, strata = day_type)) # nolint: object_usage_linter
  d <- at_quiet(add_sections(d, sections_df, section_col = section)) # nolint: object_usage_linter
  d <- at_quiet(add_counts(d, example_sections_counts)) # nolint: object_usage_linter
  # The warning fires once per session; reset it so this test can see it.
  rlang::reset_warning_verbosity("tidycreel_effort_without_period_length")
  expect_no_warning(
    try(estimate_effort(d, by = day_type), silent = TRUE) # nolint: object_usage_linter
  )
  # And it still fires on the call that reaches the estimator.
  rlang::reset_warning_verbosity("tidycreel_effort_without_period_length")
  expect_warning(estimate_effort(d), "period length") # nolint: object_usage_linter
})

# GH #478: aerial effort and the totals built on it disagreed about what that
# effort is. estimate_effort() reported angler-hours and no warning; the totals
# on the same design said the count had been expanded without a period length
# ("angler-days") and reported their unit as unknown -- while multiplying the
# rate by the correct h_open-scaled angler-hours. h_open is the period length
# of an aerial count, so there is nothing missing to warn about, and a rate per
# angler-hour times angler-hours is fish.

test_that("#478: no aerial total warns that a period length is missing", {
  d <- at_quiet(at_design())
  for (fn in list(estimate_total_catch, estimate_total_harvest, estimate_total_release)) {
    expect_no_warning(fn(d), message = "without a period length")
    expect_no_warning(fn(d, by = day_type), message = "without a period length")
  }
})

test_that("#478: aerial totals are in fish, matching effort in angler-hours", {
  d <- at_quiet(at_design())
  expect_identical(at_quiet(estimate_effort(d))$unit, "angler-hours")
  for (fn in list(estimate_total_catch, estimate_total_harvest, estimate_total_release)) {
    expect_identical(at_quiet(fn(d))$unit, "fish")
    expect_identical(at_quiet(fn(d, by = day_type))$unit, "fish")
  }
})

test_that("#478: an aerial total over a party-hour rate still reports its unit as unknown", {
  # Recording the effort unit must not make the product look resolved when the
  # rate is per party-hour: that pair has no common unit.
  cal <- unique(example_aerial_counts[, c("date", "day_type")])
  d <- creel_design( # nolint: object_usage_linter
    cal,
    date = date, strata = day_type, survey_type = "aerial",
    visibility_correction = "none", angler_ratio = 1, angler_ratio_se = 0, h_open = 14
  )
  d <- at_quiet(add_counts(d, example_aerial_counts)) # nolint: object_usage_linter
  d <- at_quiet(add_interviews( # nolint: object_usage_linter
    d, example_aerial_interviews,
    catch = walleye_catch, effort = hours_fished, trip_status = trip_status
  ))
  expect_warning(estimate_total_catch(d), "different units")
  expect_true(is.na(at_quiet(estimate_total_catch(d))$unit))
})

test_that("#519: aerial effort and totals expand to the calendar by hand-checked formula", {
  # #518 refused aerial expansion everywhere because effort refused it while the
  # totals expanded anyway. #519 established the estimator: total effort for a
  # cell is M x mean daily effort (Smucker et al. 2010, eq. 4), and the shared
  # visibility and angler ratios enter once, at the total -- their uncertainty
  # does not average out across strata. Effort and every total must now expand
  # by that rule, and agree with each other.
  #
  # Four extra unsampled weekend days make the expansion uneven (weekday N/n =
  # 4/3, weekend 8/3), so a single global factor cannot pass.
  cal <- data.frame(
    date = as.Date("2024-07-01") + c(0:7, 20:23),
    day_type = c(rep(c("weekday", "weekday", "weekend", "weekend"), 2), rep("weekend", 4))
  )
  h <- 14
  v <- 0.8
  se_v <- 0.05
  a <- 0.9
  se_a <- 0.03
  d <- at_quiet(at_design(h_open = h, v = v, v_se = se_v, a = a, a_se = se_a, cal = cal))

  # Hand: k * sum_h N_h / n_h * sum(count); variance k^2 * sum_h N_h^2 s_h^2 / n_h
  # plus E^2 * ((se_v / v)^2 + (se_a / a)^2), added once.
  cnt <- d$counts
  n_cal <- table(cal$day_type)
  k <- h * a / v
  total_count <- 0
  var_count <- 0
  for (s in names(n_cal)) {
    y <- cnt$n_anglers[cnt$day_type == s]
    total_count <- total_count + n_cal[[s]] / length(y) * sum(y)
    var_count <- var_count + n_cal[[s]]^2 * stats::var(y) / length(y)
  }
  e_hand <- k * total_count
  se_hand <- sqrt(k^2 * var_count + e_hand^2 * ((se_v / v)^2 + (se_a / a)^2))

  eff <- at_quiet(estimate_effort(d, target = "period_total")) # nolint: object_usage_linter
  expect_equal(eff$estimates$estimate, e_hand)
  expect_equal(eff$estimates$se, se_hand)
  expect_identical(eff$effort_target, "period_total")

  # Every total is the per-stratum rate times the per-stratum expanded effort.
  eff_h <- at_quiet(estimate_effort(d, by = day_type, target = "period_total"))$estimates # nolint: object_usage_linter
  rates <- list(
    catch = estimate_catch_rate, harvest = estimate_harvest_rate, release = estimate_release_rate # nolint: object_usage_linter
  )
  for (nm in names(at_totals)) {
    r <- at_quiet(rates[[nm]](d, by = day_type))$estimates
    r <- r[match(eff_h$day_type, r$day_type), ]
    tot <- at_totals[[nm]](d, target = "period_total")
    expect_equal(tot$estimates$estimate, sum(r$estimate * eff_h$estimate), info = nm)
    expect_identical(tot$effort_target, "period_total", info = nm)
  }
})
