# A common roving design draws ONE of two shifts per sampled day at random
# (p = 0.5) and counts only inside it. Daily effort is the Horvitz-Thompson
# expansion C_bar x T_d / p. add_counts() had no argument for p, so passing the
# real shift length gave half the effort, silently, and the only workaround was
# to pass T_d / p in a column documented as a length (GH #368).

sp_calendar <- function() {
  data.frame(
    date = as.Date("2024-06-03") + 0:7,
    day_type = rep(c("weekday", "weekday", "weekend", "weekend"), 2)
  )
}

# Two counts per sampled day, so the within-day variance is non-zero and the
# probability has to reach it as well as the count.
sp_counts <- function(shift_hours = 7) {
  days <- as.Date("2024-06-03") + c(0, 1, 2, 3, 4, 6)
  data.frame(
    date = rep(days, each = 2),
    day_type = rep(c("weekday", "weekday", "weekend", "weekend", "weekday", "weekend"), each = 2),
    count_time = rep(c("08:00", "11:00"), 6),
    anglers = c(10, 14, 6, 9, 22, 30, 18, 25, 12, 8, 27, 21),
    shift_hours = shift_hours,
    p_shift = 0.5
  )
}

sp_design <- function(counts, ...) {
  d <- suppressMessages(creel_design(sp_calendar(), date = date, strata = day_type)) # nolint: object_usage_linter
  suppressWarnings(suppressMessages(add_counts( # nolint: object_usage_linter
    d, counts,
    count_col = anglers, count_time_col = count_time, period_length_col = shift_hours, ...
  )))
}

sp_effort <- function(d, ...) suppressWarnings(suppressMessages(estimate_effort(d, ...)))$estimates

test_that("#368: p_period = 0.5 on a 7-hour shift equals the old 14-hour workaround exactly", {
  # Same estimate AND same SE: the probability reached the within-day variance
  # (scaled by (T_d / p)^2), not only the count.
  with_p <- sp_design(sp_counts(7), p_period = 0.5)
  workaround <- sp_design(sp_counts(14))
  for (tg in c("sampled_days", "period_total")) {
    a <- sp_effort(with_p, target = tg)
    b <- sp_effort(workaround, target = tg)
    expect_equal(a$estimate, b$estimate, tolerance = 1e-12, info = tg)
    expect_equal(a$se, b$se, tolerance = 1e-12, info = tg)
    expect_equal(a$se_within, b$se_within, tolerance = 1e-12, info = tg)
  }
})

test_that("#368: daily effort is the mean count x shift length / p", {
  # Hand value for the sampled-day total: sum over days of mean(count) x 7 / 0.5.
  cn <- sp_counts(7)
  daily_mean <- tapply(cn$anglers, cn$date, mean)
  expected <- sum(daily_mean * 7 / 0.5)
  d <- sp_design(cn, p_period = 0.5)
  expect_equal(sp_effort(d)$estimate, expected, tolerance = 1e-12)
  # And it is twice what the real length alone gives: the error #368 removes.
  expect_equal(sp_effort(d)$estimate, 2 * sp_effort(sp_design(cn))$estimate, tolerance = 1e-12)
})

test_that("#368: a p_period column gives the same result as the number", {
  cn <- sp_counts(7)
  expect_equal(
    sp_effort(sp_design(cn, p_period = p_shift))$estimate,
    sp_effort(sp_design(cn, p_period = 0.5))$estimate,
    tolerance = 1e-12
  )
})

test_that("#368: the probability must not be applied twice -- a divided length with p_period doubles effort", {
  # Pins the migration hazard: a pipeline that keeps T_d = shift / p AND adds
  # p_period = 0.5 gets 4x the real-length effort instead of 2x. add_counts()
  # cannot tell the inputs apart, which is why the length must be the real
  # shift hours (documented) and why #426 checks it against the declared window.
  cn7 <- sp_counts(7)
  right <- sp_effort(sp_design(cn7, p_period = 0.5))$estimate
  doubled <- sp_effort(sp_design(sp_counts(14), p_period = 0.5))$estimate
  expect_equal(doubled, 2 * right, tolerance = 1e-12)
})

test_that("#368: the design records and prints the probability", {
  d <- sp_design(sp_counts(7), p_period = 0.5)
  expect_identical(d$p_period, 0.5)
  expect_match(paste(format(d), collapse = "\n"), "Period selection probability: 0.5", fixed = TRUE)
  d_col <- sp_design(sp_counts(7), p_period = p_shift)
  expect_identical(d_col$p_period, "p_shift")
  expect_match(paste(format(d_col), collapse = "\n"), "column `p_shift`", fixed = TRUE)
  expect_null(sp_design(sp_counts(7))$p_period)
})

test_that("#368: an out-of-range or missing probability is refused", {
  for (bad in list(0, 1.2, -0.5, NA_real_)) {
    cn <- sp_counts(7)
    cn$p_shift <- bad
    expect_error(sp_design(cn, p_period = p_shift), class = "creel_error_p_period_invalid")
  }
  expect_error(sp_design(sp_counts(7), p_period = 0), class = "creel_error_p_period_invalid")
  expect_error(sp_design(sp_counts(7), p_period = c(0.5, 0.5)), class = "creel_error_p_period_invalid")
  # p = 1 is allowed: the period was certain to be worked.
  expect_equal(
    sp_effort(sp_design(sp_counts(7), p_period = 1))$estimate,
    sp_effort(sp_design(sp_counts(7)))$estimate
  )
})

test_that("#368: p_period needs a period length to divide", {
  d <- suppressMessages(creel_design(sp_calendar(), date = date, strata = day_type)) # nolint: object_usage_linter
  expect_error(
    suppressWarnings(add_counts(d, sp_counts(7), count_col = anglers, count_time_col = count_time, p_period = 0.5)),
    class = "creel_error_p_period_invalid"
  )
})

test_that("#368: a probability that varies within a sampled day is refused", {
  # The counts on one day come from one drawn shift.
  cn <- sp_counts(7)
  cn$p_shift[2] <- 0.25
  expect_error(sp_design(cn, p_period = p_shift), class = "creel_error_p_period_invalid")
})

test_that("#368: a period length over 24 h with p_period is refused as a doubled length", {
  # With p_period the length is one shift's real clock length, at most a day. A
  # 14 h fishing day already divided by 0.5 arrives as 28 and would be divided
  # again. 24 h exactly is a legitimate (round-the-clock) shift.
  expect_error(sp_design(sp_counts(28), p_period = 0.5), class = "creel_error_p_period_applied_twice")
  expect_no_error(sp_design(sp_counts(24), p_period = 0.5))
  # Without p_period, a length over 24 h is the legacy workaround's T_d / p and
  # stays accepted.
  expect_no_error(sp_design(sp_counts(28)))
})

test_that("#368: a doubled length under 24 h is warned on through the average coverage", {
  # A 7 h shift entered as 14 is a plausible single shift, so it is not refused
  # (only the declared window can be certain, #385/#426). But averaged over
  # days, length / p estimates the total length of the shifts: 14 / 0.5 = 28 h,
  # more than a day, so it warns. The real length averages 14 h and is silent.
  doubled <- character(0)
  withCallingHandlers(
    suppressMessages(add_counts(
      suppressMessages(creel_design(sp_calendar(), date = date, strata = day_type)), # nolint: object_usage_linter
      sp_counts(14),
      count_col = anglers, count_time_col = count_time, period_length_col = shift_hours, p_period = 0.5
    )),
    warning = function(cnd) {
      doubled <<- c(doubled, class(cnd)[1])
      invokeRestart("muffleWarning")
    }
  )
  expect_true("creel_warning_p_period_coverage" %in% doubled)
  w <- character(0)
  withCallingHandlers(
    suppressMessages(add_counts(
      suppressMessages(creel_design(sp_calendar(), date = date, strata = day_type)), # nolint: object_usage_linter
      sp_counts(7),
      count_col = anglers, count_time_col = count_time, period_length_col = shift_hours, p_period = 0.5
    )),
    warning = function(cnd) {
      w <<- c(w, class(cnd)[1])
      invokeRestart("muffleWarning")
    }
  )
  expect_false("creel_warning_p_period_coverage" %in% w)
})

test_that("#368: unequal shifts drawn evenly do not trip the coverage warning", {
  # AM 4 h and PM 20 h at p = 0.5: a PM day stands for 40 h on its own, which is
  # why the check is on the average. Drawn alternately the average is
  # (8 + 40) / 2 = 24 h, a full day and not more, so it is silent.
  cn <- sp_counts(4)
  pm_days <- unique(cn$date)[c(FALSE, TRUE)]
  cn$shift_hours[cn$date %in% pm_days] <- 20
  w <- character(0)
  withCallingHandlers(
    suppressMessages(add_counts(
      suppressMessages(creel_design(sp_calendar(), date = date, strata = day_type)), # nolint: object_usage_linter
      cn,
      count_col = anglers, count_time_col = count_time, period_length_col = shift_hours, p_period = 0.5
    )),
    warning = function(cnd) {
      w <<- c(w, class(cnd)[1])
      invokeRestart("muffleWarning")
    }
  )
  expect_false("creel_warning_p_period_coverage" %in% w)
})

test_that("#368: on a sectioned design the coverage warning is per section and names it", {
  # Each section has its own shifts, so each is averaged on its own. North is
  # entered doubled (14 h at p = 0.5 -> 28 h a day), South correctly (7 h).
  cal <- sp_calendar()
  d <- suppressMessages(creel_design(cal, date = date, strata = day_type)) # nolint: object_usage_linter
  d <- add_sections(d, data.frame(section = c("North", "South")), section_col = section) # nolint: object_usage_linter
  base <- sp_counts(7)
  cn <- rbind(transform(base, section = "North", shift_hours = 14), transform(base, section = "South"))
  msg <- NULL
  withCallingHandlers(
    suppressMessages(add_counts(
      d, cn,
      count_col = anglers, count_time_col = count_time, period_length_col = shift_hours, p_period = 0.5
    )),
    creel_warning_p_period_coverage = function(cnd) {
      msg <<- conditionMessage(cnd)
      invokeRestart("muffleWarning")
    },
    warning = function(cnd) invokeRestart("muffleWarning")
  )
  expect_false(is.null(msg))
  expect_match(msg, "(North)", fixed = TRUE)
  expect_no_match(msg, "South", fixed = TRUE)
})

test_that("#368: a factor section column with an uncounted level neither warns falsely nor hides an overrun", {
  # A factor keeps the level of a declared section with no counts; averaged per
  # section, that empty level came back NA, which warned "NA hours" on correct
  # data and turned max() over a real overrun into NA.
  cal <- sp_calendar()
  d <- suppressMessages(creel_design(cal, date = date, strata = day_type)) # nolint: object_usage_linter
  d <- add_sections(d, data.frame(section = c("North", "South", "East")), section_col = section) # nolint: object_usage_linter
  base <- sp_counts(7)
  coverage_msgs <- function(north_hours) {
    cn <- rbind(transform(base, section = "North", shift_hours = north_hours), transform(base, section = "South"))
    cn$section <- factor(cn$section, levels = c("North", "South", "East"))
    msgs <- character(0)
    withCallingHandlers(
      suppressMessages(add_counts(
        d, cn,
        count_col = anglers, count_time_col = count_time, period_length_col = shift_hours, p_period = 0.5
      )),
      creel_warning_p_period_coverage = function(cnd) {
        msgs <<- c(msgs, conditionMessage(cnd))
        invokeRestart("muffleWarning")
      },
      warning = function(cnd) invokeRestart("muffleWarning")
    )
    msgs
  }
  expect_length(coverage_msgs(7), 0L)
  overrun <- coverage_msgs(14)
  expect_length(overrun, 1L)
  expect_match(overrun, "cover 28 hours a day on average (North)", fixed = TRUE)
})
