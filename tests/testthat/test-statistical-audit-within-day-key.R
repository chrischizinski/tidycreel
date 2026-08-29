# Within-day variance must be keyed by the sampling unit, not by the PSU alone
# (GH #227). `add_counts()` keys `design$within_day_var` by the full unit key --
# the section, the site, or whatever `unit_cols` named. Two consumers rebuilt a
# narrower `c(psu_col, strata_cols)` key, which joined every section of a date to
# every other section of that date. Nothing errored: the join returned more rows
# than it was given, so each section reported the lake-wide within-day variance
# and its `se` was dominated by other sections' data.
#
# See AUDIT-sections-hybrid-2026-08-28.md findings 1 and 3.

# One weekday pair and one weekend pair, so every stratum has 2 PSUs. Two
# sections. `spread` sets how far apart a section's two daily counts are, which
# is the entire within-day signal.
wdk_design <- function(spread_a, spread_b, len_a = 12, len_b = 12) {
  dates <- as.Date(c("2024-06-03", "2024-06-04", "2024-06-08", "2024-06-09"))
  cal <- data.frame(
    date = dates,
    day_type = c("weekday", "weekday", "weekend", "weekend"),
    stringsAsFactors = FALSE
  )

  base <- data.frame(
    date = rep(dates, times = 2L),
    day_type = rep(cal$day_type, times = 2L),
    section = rep(c("A", "B"), each = 4L),
    level = rep(c(20, 24, 28, 32), times = 2L),
    stringsAsFactors = FALSE
  )
  spread <- ifelse(base$section == "A", spread_a, spread_b)

  first <- base
  second <- base
  first$count_time <- 9
  second$count_time <- 15
  first$effort_hours <- base$level * (1 - spread)
  second$effort_hours <- base$level * (1 + spread)

  counts <- rbind(first, second)
  counts$period_length <- ifelse(counts$section == "A", len_a, len_b)
  counts$level <- NULL

  sections <- data.frame(section = c("A", "B"), stringsAsFactors = FALSE)
  design <- creel_design(calendar = cal, date = date, strata = day_type)
  design <- add_sections(design, sections, section_col = section)
  suppressWarnings(add_counts(
    design,
    counts,
    count_col = effort_hours,
    count_time_col = count_time,
    period_length_col = period_length
  ))
}

wdk_effort <- function(design) {
  est <- as.data.frame(suppressWarnings(suppressMessages(estimate_effort(design)))$estimates)
  est[est$section != ".lake_total", ]
}

test_that("a section with no within-day variation reports se_within of exactly 0", {
  # The sharpest statement of the defect: section B is counted identically at
  # both times, so it has no within-day component to report. Before the fix it
  # reported section A's, because the join gave it A's rows. A zero here is a
  # true zero -- both looks at the unit agreed -- not an un-propagated component.
  est <- wdk_effort(wdk_design(spread_a = 0.9, spread_b = 0))

  expect_identical(est$se_within[est$section == "B"], 0)
  expect_gt(est$se_within[est$section == "A"], 0)
})

test_that("one section's within-day spread does not move another section's se_within", {
  # Metamorphic, and the property that cannot pass for the wrong reason: hold
  # section B's data fixed and vary only section A's within-day spread. B's
  # within-day variance is a function of B's counts alone, so it must not move.
  # Under the old key both sections summed the same pooled ss_d, so B tracked A.
  narrow <- wdk_effort(wdk_design(spread_a = 0.1, spread_b = 0.4))
  wide <- wdk_effort(wdk_design(spread_a = 0.9, spread_b = 0.4))

  b_narrow <- narrow$se_within[narrow$section == "B"]
  b_wide <- wide$se_within[wide$section == "B"]
  expect_equal(b_wide, b_narrow)

  # And the section that did change must actually respond, so the test cannot
  # pass by the estimator having stopped computing the component at all.
  expect_gt(
    wide$se_within[wide$section == "A"],
    narrow$se_within[narrow$section == "A"]
  )
})

test_that("the within-day join returns one row per count row", {
  # The mechanism, asserted directly. A key narrower than the one the table was
  # built with silently multiplies the frame -- 12 count rows became 36 -- and
  # that inflated row count also became `n_sampled` in the variance divisor.
  design <- wdk_design(spread_a = 0.5, spread_b = 0.2)
  wdv <- design$within_day_var
  key_cols <- within_day_key_cols(wdv)

  expect_true(all(c("date", "day_type", "section") %in% key_cols))

  section_counts <- design$counts[design$counts$section == "A", ]
  joined <- merge(section_counts, wdv, by = key_cols, all.x = TRUE, sort = FALSE)
  expect_identical(nrow(joined), nrow(section_counts))
})

test_that("the T_d rescaling uses each unit's own period length", {
  # ss_d is scaled by T_d^2 to reach effort^2 units. Keyed on the date alone,
  # `match()` returned the first row carrying that date, so every section was
  # scaled by whichever section sorted first -- a 12 h period applied to a 6 h
  # section overstated its within-day variance fourfold.
  twelve <- wdk_design(spread_a = 0.5, spread_b = 0.5, len_a = 12, len_b = 12)
  halved <- wdk_design(spread_a = 0.5, spread_b = 0.5, len_a = 12, len_b = 6)

  ss_by_section <- function(d) tapply(d$within_day_var$ss_d, d$within_day_var$section, sum)

  expect_equal(
    unname(ss_by_section(halved)[["B"]]),
    unname(ss_by_section(twelve)[["B"]]) * (6 / 12)^2
  )
  # Section A's period length never changed, so its component must not move.
  expect_equal(
    unname(ss_by_section(halved)[["A"]]),
    unname(ss_by_section(twelve)[["A"]])
  )
})

test_that("grouping by a unit_cols column returns per-group within-day variance", {
  # Same root cause, different symptom. When the extra unit-key column comes
  # from `unit_cols` rather than `add_sections()`, the narrow join renamed the
  # duplicated column to .x/.y, `combined[[by_vars]]` became NULL, and the
  # function died inside base R with "replacement has 0 rows, data has 32" --
  # a message naming nothing the caller supplied.
  dates <- as.Date(c("2024-06-03", "2024-06-04", "2024-06-08", "2024-06-09"))
  cal <- data.frame(
    date = dates,
    day_type = c("weekday", "weekday", "weekend", "weekend"),
    stringsAsFactors = FALSE
  )
  base <- data.frame(
    date = rep(dates, times = 2L),
    day_type = rep(cal$day_type, times = 2L),
    gear = rep(c("boat", "bank"), each = 4L),
    stringsAsFactors = FALSE
  )
  # boat swings within the day; bank is counted identically at both times.
  spread <- ifelse(base$gear == "boat", 0.9, 0)
  first <- base
  second <- base
  first$count_time <- 9
  second$count_time <- 15
  first$effort_hours <- 40 * (1 - spread)
  second$effort_hours <- 40 * (1 + spread)
  counts <- rbind(first, second)
  counts$period_length <- 12

  design <- creel_design(calendar = cal, date = date, strata = day_type)
  design <- suppressWarnings(add_counts(
    design,
    counts,
    count_col = effort_hours,
    count_time_col = count_time,
    period_length_col = period_length,
    unit_cols = c("date", "day_type", "gear")
  ))

  est <- as.data.frame(
    suppressWarnings(suppressMessages(estimate_effort(design, by = gear)))$estimates
  )

  expect_identical(est$se_within[est$gear == "bank"], 0)
  expect_gt(est$se_within[est$gear == "boat"], 0)
})
