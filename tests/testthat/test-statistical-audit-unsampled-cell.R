# An expanded effort target (stratum_total / period_total) multiplies each
# sampled day by its stratum's N_h / n_h. Two shapes of "calendar days with no
# sampled day" used to vanish without a word (GH #421):
#
# - grouped by a calendar variable that cuts across a stratum (a Labor Day
#   stratum straddling August and September), svyby() credits each sampled day
#   to its own group, so a stratum x group cell with no sampled day got nothing
#   and its days were credited to the stratum's other groups: August 285 against
#   a true 190, September 0, no row, no warning;
# - a stratum with no sampled day at all has no count rows, so the expansion
#   never saw it and the season total omitted its days (746.25, labor_day absent).
#
# Both are unknown effort reported as nothing. They now refuse, naming the cell.

# 2025-08-18 .. 2025-09-14. Labor Day 2025 is Sat Aug 30, Sun Aug 31, Mon Sep 1:
# two days in August, one in September. True Labor Day effort Sat 100, Sun 90,
# Mon 50, so the August piece is 190 and the September piece 50.
uc_calendar <- function() {
  dates <- seq(as.Date("2025-08-18"), as.Date("2025-09-14"), by = "day")
  day_type <- ifelse(weekdays(dates) %in% c("Saturday", "Sunday"), "weekend", "weekday")
  day_type[dates %in% as.Date(c("2025-08-30", "2025-08-31", "2025-09-01"))] <- "labor_day"
  data.frame(date = dates, day_type = day_type, month = format(dates, "%m"))
}

uc_design <- function(ld_sampled) {
  cal <- uc_calendar()
  other <- as.Date(c(
    "2025-08-19", "2025-08-21", "2025-09-03", "2025-09-09",
    "2025-08-23", "2025-08-24", "2025-09-06", "2025-09-13"
  ))
  other_effort <- c(20, 22, 18, 21, 60, 62, 58, 61)
  ld_truth <- c("2025-08-30" = 100, "2025-08-31" = 90, "2025-09-01" = 50)
  sampled <- c(other, as.Date(ld_sampled))
  counts <- cal[cal$date %in% sampled, ]
  counts$effort_hours <- ifelse(
    counts$day_type == "labor_day",
    ld_truth[as.character(counts$date)],
    other_effort[match(counts$date, other)]
  )
  d <- suppressMessages(creel_design(cal, date = date, strata = day_type)) # nolint: object_usage_linter
  suppressWarnings(suppressMessages(add_counts(d, counts)))
}

uc_effort <- function(d, ...) suppressWarnings(suppressMessages(estimate_effort(d, ...)))

test_that("#421: a stratum x month cell with no sampled day refuses, naming the cell", {
  d <- uc_design(c("2025-08-30", "2025-08-31")) # September's Labor Day Monday unsampled
  for (tg in c("period_total", "stratum_total")) {
    for (by in list(quote(month), quote(c(day_type, month)))) {
      err <- tryCatch(
        eval(bquote(uc_effort(d, by = .(by), target = .(tg)))),
        error = function(e) e
      )
      expect_s3_class(err, "creel_error_unsampled_cell")
      expect_match(conditionMessage(err), "day_type=labor_day, month=09 (1 day)", fixed = TRUE)
      # The message has to say why the OTHER groups are wrong too, not only
      # the empty one, and point at the design that expands each separately.
      expect_match(conditionMessage(err), "would be overstated", fixed = TRUE)
      expect_match(conditionMessage(err), "strata = c(day_type, month)", fixed = TRUE)
    }
  }
})

test_that("#421: the sampled-days target claims no unsampled day, so it does not refuse", {
  d <- uc_design(c("2025-08-30", "2025-08-31"))
  r <- uc_effort(d, by = month, target = "sampled_days")
  expect_identical(sort(as.character(r$estimates$month)), c("08", "09"))
})

test_that("#421: the season total does not refuse when every stratum is sampled", {
  # The cell guard is for the split. The ungrouped total over a sampled stratum
  # is the ordinary stratified estimator and must keep estimating.
  d <- uc_design(c("2025-08-30", "2025-08-31"))
  r <- uc_effort(d, target = "period_total")
  # 3/2 * 190 = 285 for Labor Day plus the two ordinary strata.
  expect_equal(r$estimates$estimate, 1031.25)
})

test_that("#421: with every cell sampled the month split is unchanged and sums to the total", {
  d <- uc_design(c("2025-08-30", "2025-09-01")) # Sat (Aug) + Mon (Sep)
  by_cell <- as.data.frame(uc_effort(d, by = c(day_type, month), target = "period_total")$estimates)
  ld <- by_cell[by_cell$day_type == "labor_day", ]
  # Each sampled Labor Day expands by N_h / n_h = 3 / 2 into its own month.
  expect_equal(ld$estimate[ld$month == "08"], 150)
  expect_equal(ld$estimate[ld$month == "09"], 75)
  by_month <- uc_effort(d, by = month, target = "period_total")$estimates
  total <- uc_effort(d, target = "period_total")$estimates
  expect_equal(sum(by_month$estimate), total$estimate)
})

test_that("#421: a stratum with no sampled day refuses the expanded total instead of omitting it", {
  d <- uc_design(character(0)) # no Labor Day sampled at all
  for (tg in c("period_total", "stratum_total")) {
    err <- tryCatch(uc_effort(d, target = tg), error = function(e) e)
    expect_s3_class(err, "creel_error_unsampled_cell")
    expect_match(conditionMessage(err), "day_type=labor_day (3 days)", fixed = TRUE)
    expect_match(conditionMessage(err), "left out of the total", fixed = TRUE)
  }
  # The sampled-days total never claimed those days.
  expect_no_error(uc_effort(d, target = "sampled_days"))
})

test_that("#421: a grouping column the calendar does not carry is not checked against it", {
  # A count-level column (here a shift label) has no calendar population, so
  # there is no cell to compare; the guard must not invent one.
  d <- uc_design(c("2025-08-30", "2025-09-01"))
  cal <- uc_calendar()
  counts <- d$counts
  counts$shift <- rep(c("am", "pm"), length.out = nrow(counts))
  d2 <- suppressMessages(creel_design(cal, date = date, strata = day_type)) # nolint: object_usage_linter
  d2 <- suppressWarnings(suppressMessages(add_counts(d2, counts[, c("date", "day_type", "month", "shift", "effort_hours")])))
  expect_false("shift" %in% names(cal))
  err <- tryCatch(uc_effort(d2, by = shift, target = "period_total"), error = function(e) e)
  expect_false(inherits(err, "creel_error_unsampled_cell"))
})

test_that("#421: a brace in a stratum name is printed, not read as cli markup", {
  cal <- uc_calendar()
  cal$day_type[cal$day_type == "labor_day"] <- "{holiday}"
  counts <- cal[cal$date %in% as.Date(c("2025-08-19", "2025-08-21", "2025-08-23", "2025-08-24")), ]
  counts$effort_hours <- c(20, 22, 60, 62)
  d <- suppressMessages(creel_design(cal, date = date, strata = day_type)) # nolint: object_usage_linter
  d <- suppressWarnings(suppressMessages(add_counts(d, counts)))
  err <- tryCatch(uc_effort(d, target = "period_total"), error = function(e) e)
  expect_s3_class(err, "creel_error_unsampled_cell")
  expect_match(conditionMessage(err), "day_type={holiday} (3 days)", fixed = TRUE)
})
