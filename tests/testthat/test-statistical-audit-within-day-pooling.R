# Within-day variance of a total that combines units (GH #373).
#
# A common roving count records bank anglers and boat anglers at the same
# moment, entered long form: one row per count x angler type, with
# `unit_cols = c("date", "day_type", "gear")`. `design$within_day_var` holds a
# sum of squares for each date x gear. Asked for the unsplit total, the
# estimator fed those per-gear rows straight into the per-day formula, which
# went wrong twice and silently:
#
#   * it counted rows as sampled days, so two gears halved the variance;
#   * it summed sums of squares, so the covariance between bank and boat counted
#     at the same occasion was lost.
#
# The right component is the one the same data gives entered as one pooled row
# per count (bank + boat): the variance across occasions of the day's total.
# Every expected value below is computed by hand from that definition.

wdp_cal <- function() {
  data.frame(
    date = as.Date(c(
      "2024-06-03", "2024-06-04", "2024-06-05",
      "2024-06-08", "2024-06-09", "2024-06-15"
    )),
    day_type = rep(c("weekday", "weekend"), each = 3L),
    stringsAsFactors = FALSE
  )
}

# Two sampled days per stratum, two counts per day, two gears. `boat` gives the
# boat counts as a function of the bank counts, which is how a test sets the
# bank-boat covariance without touching anything else.
wdp_counts <- function(boat = function(bank, day) 2 * bank + c(10, 4, 30, 26)[day],
                       times_bank = c("08:00", "16:00"),
                       times_boat = times_bank) {
  dates <- as.Date(c("2024-06-03", "2024-06-04", "2024-06-08", "2024-06-09"))
  day_type <- c("weekday", "weekday", "weekend", "weekend")
  bank <- rbind(c(10, 14), c(6, 12), c(20, 26), c(16, 18))
  rows <- list()
  for (d in seq_along(dates)) {
    for (j in 1:2) {
      rows[[length(rows) + 1L]] <- data.frame(
        date = dates[d], day_type = day_type[d], gear = "bank",
        count_time = times_bank[j], anglers = bank[d, j],
        stringsAsFactors = FALSE
      )
      rows[[length(rows) + 1L]] <- data.frame(
        date = dates[d], day_type = day_type[d], gear = "boat",
        count_time = times_boat[j], anglers = boat(bank[d, j], d),
        stringsAsFactors = FALSE
      )
    }
  }
  do.call(rbind, rows)
}

wdp_design <- function(counts, ...) {
  d <- suppressMessages(creel_design(wdp_cal(), date = date, strata = day_type)) # nolint: object_usage_linter
  suppressWarnings(suppressMessages(add_counts(
    d, counts,
    count_col = anglers, # nolint: object_usage_linter
    count_time_col = count_time, # nolint: object_usage_linter
    unit_cols = c("date", "day_type", "gear"),
    ...
  )))
}

wdp_se_within <- function(design, ...) {
  suppressWarnings(suppressMessages(estimate_effort(design, ...)))$estimates
}

# Rasmussen within-day variance of the stratum totals, by hand: add the gears up
# at each occasion, take the sum of squares across occasions per day, then
# (scale / k) * sum(ss) / (n * (k - 1)), with scale = N (expanded) or n (sampled).
wdp_hand_var <- function(counts, target = "period_total", strata = c("weekday", "weekend")) {
  cal <- wdp_cal()
  v <- 0
  for (s in strata) {
    sc <- counts[counts$day_type == s, ]
    tot <- tapply(sc$anglers, list(as.character(sc$date), sc$count_time), sum)
    ss <- apply(tot, 1, function(x) sum((x - mean(x))^2))
    n <- length(ss)
    k <- ncol(tot)
    scale <- if (target == "sampled_days") n else sum(cal$day_type == s)
    v <- v + scale / k * sum(ss) / (n * (k - 1))
  }
  v
}

test_that("#373: the unsplit total's se_within is the variance of the day's total count", {
  counts <- wdp_counts()
  design <- wdp_design(counts)

  for (target in c("period_total", "stratum_total", "sampled_days")) {
    est <- wdp_se_within(design, target = target)
    # Against the hand two-stage value. Before the fix period_total came out at
    # sqrt(1/2) of the no-covariance value: rows counted as days, and no
    # cross-products.
    expect_equal(est$se_within, sqrt(wdp_hand_var(counts, target)), label = target)
  }
})

test_that("#373: long form and one pooled row per count give the same se_within", {
  # The same data entered the other way the field form allows. The estimand is
  # identical, so the component must be too -- this is the comparison the issue
  # was found by (2,026 long vs 3,095 pooled on a real creel).
  counts <- wdp_counts()
  pooled <- stats::aggregate(anglers ~ date + day_type + count_time, counts, sum)
  d0 <- suppressMessages(creel_design(wdp_cal(), date = date, strata = day_type)) # nolint: object_usage_linter
  pooled_design <- suppressWarnings(suppressMessages(add_counts(
    d0, pooled,
    count_col = anglers, count_time_col = count_time # nolint: object_usage_linter
  )))

  long <- wdp_se_within(wdp_design(counts), target = "period_total")
  wide <- wdp_se_within(pooled_design, target = "period_total")
  expect_equal(long$estimate, wide$estimate)
  expect_equal(long$se_within, wide$se_within)
})

test_that("#373: gears that cancel at every occasion leave no within-day variance", {
  # The covariance on its own. Boat counts mirror bank counts, so each day's
  # total is the same at both occasions: the total has no within-day variance,
  # even though each gear has plenty. Summing per-gear sums of squares -- the
  # old behaviour -- reports a positive component here.
  cancelling <- function(bank, day) c(40, 30, 60, 50)[day] - bank
  design <- wdp_design(wdp_counts(boat = cancelling))

  est <- wdp_se_within(design, target = "period_total")
  expect_identical(est$se_within, 0)

  # And each gear still reports its own variation, so the zero above is the
  # covariance cancelling and not the component having stopped being computed.
  by_gear <- wdp_se_within(design, by = gear, target = "period_total")
  expect_true(all(by_gear$se_within > 0))
})

test_that("#373: by = the unit column is unchanged, and by = stratum pools the gears", {
  counts <- wdp_counts()
  design <- wdp_design(counts)

  # Per gear the unit key is the reporting grain, so nothing is pooled: each
  # gear's component is its own two-stage variance.
  by_gear <- wdp_se_within(design, by = gear, target = "period_total")
  for (g in c("bank", "boat")) {
    expect_equal(
      by_gear$se_within[by_gear$gear == g],
      sqrt(wdp_hand_var(counts[counts$gear == g, ])),
      label = g
    )
  }

  # Per stratum the gears are combined within each stratum, so they pool.
  by_stratum <- wdp_se_within(design, by = day_type, target = "period_total")
  for (s in c("weekday", "weekend")) {
    expect_equal(
      by_stratum$se_within[by_stratum$day_type == s],
      sqrt(wdp_hand_var(counts, strata = s)),
      label = s
    )
  }
})

test_that("#373: units counted at different occasions are added as independent, and said so", {
  # Bank and boat counted at different times of day cannot be paired occasion by
  # occasion. Their components are then added -- each gear its own variance,
  # with the day counted once per gear, not twice per stratum.
  counts <- wdp_counts(times_bank = c("08:00", "16:00"), times_boat = c("09:00", "17:00"))
  design <- wdp_design(counts)

  expect_message(
    suppressWarnings(estimate_effort(design, target = "period_total")),
    class = "creel_message_within_day_independent"
  )
  est <- wdp_se_within(design, target = "period_total")
  hand_bank <- wdp_hand_var(counts[counts$gear == "bank", ])
  hand_boat <- wdp_hand_var(counts[counts$gear == "boat", ])
  expect_equal(est$se_within, sqrt(hand_bank + hand_boat))
})

test_that("#373: a supplied sum of squares cannot be combined across units", {
  # prep_counts_*() hands over a sum of squares per unit and no occasions. The
  # cross-products are unknown, so the unsplit total is refused rather than
  # reported with the covariance silently set to zero.
  counts <- wdp_counts()
  per_unit <- stats::aggregate(anglers ~ date + day_type + gear, counts, mean)
  ss <- stats::aggregate(
    anglers ~ date + day_type + gear, counts,
    function(x) sum((x - mean(x))^2)
  )
  per_unit$within_day_var <- ss$anglers
  per_unit$n_counts <- 2L
  d0 <- suppressMessages(creel_design(wdp_cal(), date = date, strata = day_type)) # nolint: object_usage_linter
  design <- suppressWarnings(suppressMessages(add_counts(
    d0, per_unit,
    count_col = anglers, # nolint: object_usage_linter
    unit_cols = c("date", "day_type", "gear")
  )))

  expect_error(
    suppressMessages(estimate_effort(design, target = "period_total")),
    class = "creel_error_within_day_unpooled"
  )
  # Per gear the supplied sums of squares are exactly what is needed.
  by_gear <- wdp_se_within(design, by = gear, target = "period_total")
  expect_equal(
    by_gear$se_within[by_gear$gear == "boat"],
    sqrt(wdp_hand_var(counts[counts$gear == "boat", ]))
  )
})

test_that("#373: occasions are pooled in effort units, each gear by its own period length", {
  # The raw occasions must be scaled by T_d before they are added, as the sums
  # of squares are. A boat period of 12 h against a bank period of 8 h makes the
  # day's effort total 8 * bank + 12 * boat at each occasion.
  counts <- wdp_counts()
  counts$period_length <- ifelse(counts$gear == "bank", 8, 12)
  design <- wdp_design(counts, period_length_col = period_length) # nolint: object_usage_linter

  effort <- counts
  effort$anglers <- effort$anglers * effort$period_length
  est <- wdp_se_within(design, target = "period_total")
  expect_equal(est$se_within, sqrt(wdp_hand_var(effort)))
})

# Per-day hand value for schedules that pair on some days and not others. A day
# whose gears share the same known occasions is pooled; any other day adds the
# gears' own sums of squares (equal counts per gear, so no rescaling).
wdp_hand_var_mixed <- function(counts, target = "period_total") {
  cal <- wdp_cal()
  v <- 0
  for (s in c("weekday", "weekend")) {
    sc <- counts[counts$day_type == s, ]
    ss <- c()
    for (dd in unique(as.character(sc$date))) {
      day <- sc[as.character(sc$date) == dd, ]
      tb <- day$count_time[day$gear == "bank"]
      to <- day$count_time[day$gear == "boat"]
      if (!anyNA(c(tb, to)) && identical(sort(tb), sort(to))) {
        tot <- tapply(day$anglers, day$count_time, sum)
        ss <- c(ss, sum((tot - mean(tot))^2))
      } else {
        per_gear <- tapply(day$anglers, day$gear, function(x) sum((x - mean(x))^2))
        ss <- c(ss, sum(per_gear))
      }
    }
    n <- length(ss)
    scale <- if (target == "sampled_days") n else sum(cal$day_type == s)
    v <- v + scale / 2 * sum(ss) / (n * (2 - 1))
  }
  v
}

test_that("#373: pairing is decided per day, so one off-schedule day keeps the others pooled", {
  # One weekday counted boat-first at different times; every other day pairs.
  # Deciding pairing once per stratum dropped the covariance on the weekday
  # that did pair as well.
  counts <- wdp_counts()
  off <- counts$gear == "boat" & counts$date == as.Date("2024-06-03")
  counts$count_time[off] <- c("09:00", "17:00")
  design <- wdp_design(counts)

  expect_message(
    suppressWarnings(estimate_effort(design, target = "period_total")),
    class = "creel_message_within_day_independent"
  )
  est <- wdp_se_within(design, target = "period_total")
  expect_equal(est$se_within, sqrt(wdp_hand_var_mixed(counts)))
  # Not the all-independent value: the paired days still carry their covariance.
  all_indep <- wdp_hand_var(counts[counts$gear == "bank", ]) +
    wdp_hand_var(counts[counts$gear == "boat", ])
  expect_false(isTRUE(all.equal(est$se_within, sqrt(all_indep))))
})

test_that("#373: an unknown occasion is not dropped -- its day is added as independent", {
  # An NA count time cannot be matched to anything. Both gears' second count on
  # one day lost its time: their label sets still look alike once NA is
  # dropped, so the day would pair on its one known occasion and lose a count
  # from each gear, understating the variance. It is kept in each gear's own
  # sum of squares instead.
  counts <- wdp_counts()
  na_row <- counts$date == as.Date("2024-06-03") & counts$count_time == "16:00"
  counts$count_time[na_row] <- NA
  design <- wdp_design(counts)

  expect_message(
    suppressWarnings(estimate_effort(design, target = "period_total")),
    class = "creel_message_within_day_independent"
  )
  est <- wdp_se_within(design, target = "period_total")
  expect_equal(est$se_within, sqrt(wdp_hand_var_mixed(counts)))
})

test_that("#373: by = a column outside the unit key still pools the units", {
  # `season` is on the count rows but not in the unit key, so it is not in the
  # occasion table either. The day is found through the unit, not rebuilt from
  # columns the occasion table does not carry. A regression pin: the first
  # version rebuilt it from columns and happened to group correctly anyway,
  # because the missing column pasted as an empty field on every row.
  counts <- wdp_counts()
  counts$season <- "summer"
  design <- wdp_design(counts)

  est <- wdp_se_within(design, by = season, target = "period_total")
  expect_equal(est$se_within, sqrt(wdp_hand_var(counts)))
})

test_that("#373: with no day paired, the unsplit component is the sum of the by-unit ones", {
  # Independent units throughout: the total's within-day variance is the sum of
  # what `by = gear` reports for each, however often each gear was counted. Bank
  # and boat are counted at different times, so nothing pairs, and boat gets two
  # extra counts on the first day of each stratum only. Its number of counts
  # then varies from day to day -- the case where folding each day to one
  # pseudo-row at its mean count disagreed with the by-unit sum. (With a count
  # number constant per unit the two agree algebraically.)
  counts <- wdp_counts(times_bank = c("08:00", "16:00"), times_boat = c("09:00", "17:00"))
  extra <- counts[counts$gear == "boat" &
    counts$date %in% as.Date(c("2024-06-03", "2024-06-08")), ]
  extra$count_time <- ifelse(extra$count_time == "09:00", "11:00", "19:00")
  extra$anglers <- extra$anglers + c(5, -3, 9, 1)
  counts <- rbind(counts, extra)
  design <- wdp_design(counts)

  total <- wdp_se_within(design, target = "period_total")
  by_gear <- wdp_se_within(design, by = gear, target = "period_total")
  expect_equal(total$se_within^2, sum(by_gear$se_within^2))
})
