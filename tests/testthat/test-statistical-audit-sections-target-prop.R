# Two seams in estimate_effort_sections() (GH #231).
#
# 1. `target` was not forwarded to the per-section estimator. The call was
#    positional, so every section was computed on "sampled_days" while the
#    returned object was labelled with the caller's target. Latent today
#    because estimate_effort() aborts for a sectioned design whenever
#    target != "sampled_days" -- but that abort calls itself temporary, and the
#    day it lifts this labels sampled-day numbers as period totals.
#
# 2. `prop_of_lake_total` was a bare division of two correlated survey
#    estimates, reported with no uncertainty in a table where every other
#    quantity carries an SE.
#
# See AUDIT-sections-hybrid-2026-08-28.md findings 8 and 9.

# Three calendar weeks, one of which is sampled, so an expanded target is a
# clean multiple of the sampled-day figure and a target that failed to reach the
# sections is visible as an unmultiplied number rather than a subtle shift.
tp_design <- function() {
  sampled <- as.Date(c("2024-06-03", "2024-06-04", "2024-06-08", "2024-06-09"))
  day_types <- c("weekday", "weekday", "weekend", "weekend")
  cal <- data.frame(
    date = rep(sampled, 3) + rep(c(0L, 14L, 28L), each = 4L),
    day_type = rep(day_types, 3),
    stringsAsFactors = FALSE
  )
  counts <- data.frame(
    date = rep(sampled, 2),
    day_type = rep(day_types, 2),
    section = rep(c("A", "B"), each = 4L),
    effort_hours = c(20, 24, 28, 32, 10, 11, 14, 15),
    stringsAsFactors = FALSE
  )
  design <- creel_design(cal, date = date, strata = day_type)
  design <- add_sections(
    design,
    data.frame(section = c("A", "B"), stringsAsFactors = FALSE),
    section_col = section
  )
  suppressWarnings(add_counts(design, counts, count_col = effort_hours))
}

tp_sections <- function(target = "sampled_days") {
  # Reached directly: estimate_effort() refuses an expanded target on a
  # sectioned design, so the public surface cannot exercise the forwarding this
  # asserts. Testing through the guard would assert only that the guard exists.
  suppressWarnings(suppressMessages(
    estimate_effort_sections(
      tp_design(),
      variance_method = "taylor",
      conf_level = 0.95,
      aggregate_sections = TRUE,
      method = "correlated",
      missing_sections = "warn",
      target = target
    )
  ))
}

tp_rows <- function(result) {
  as.data.frame(result$estimates)
}

test_that("the target reaches the per-section estimates, not just the label", {
  # The defect in one line: every section was computed on sampled days while the
  # object said otherwise. The calendar holds three times the sampled days, so a
  # section that ignored the target reports the sampled-day figure unchanged
  # while `effort_target` claims a stratum total.
  sampled <- tp_rows(tp_sections("sampled_days"))
  expanded <- tp_rows(tp_sections("stratum_total"))

  expect_equal(sampled$estimate, c(104, 50, 154))
  expect_equal(expanded$estimate, c(312, 150, 462))

  # Both halves of the defect were needed: the lake row read `design$survey`
  # directly rather than going through `get_effort_target_design()`, so it was
  # stuck on sampled days too. Pre-fix the expanded call returned
  # `104, 50, 154` -- identical to the sampled-day call in every row -- while
  # reporting `effort_target = "stratum_total"`. Nothing in the table
  # disagreed with anything else, which is why only the label was wrong.
  expect_true(all(expanded$estimate > sampled$estimate))
})

test_that("the reported target labels the numbers actually computed", {
  # The mislabelling half. A label is only meaningful if the quantity beneath it
  # was computed the same way, which is the estimand-integrity rule the audit
  # protocol ranks highest.
  expect_identical(tp_sections("sampled_days")$effort_target, "sampled_days")
  expect_identical(tp_sections("stratum_total")$effort_target, "stratum_total")
})

test_that("prop_of_lake_total carries a standard error", {
  # It was a bare number in a column where every neighbour has an SE, so a
  # reader comparing sections across the table had nothing to judge the
  # comparison by.
  rows <- tp_rows(tp_sections())
  sections <- rows[rows$section != ".lake_total", ]

  expect_true("se_prop_of_lake_total" %in% names(rows))
  expect_false(any(is.na(sections$se_prop_of_lake_total)))
  expect_true(all(sections$se_prop_of_lake_total > 0))
})

test_that("the proportion itself is unchanged by gaining an SE", {
  # `svyratio()` replaces a division, so its point estimate has to reproduce
  # that division exactly. This is the guard against the SE having been bought
  # with a shifted number.
  rows <- tp_rows(tp_sections())
  lake_est <- rows$estimate[rows$section == ".lake_total"]
  sections <- rows[rows$section != ".lake_total", ]

  expect_equal(sections$prop_of_lake_total, sections$estimate / lake_est)
  expect_equal(sum(sections$prop_of_lake_total), 1)
})

test_that("a two-section partition gives both sections the same proportion SE", {
  # Pins the arithmetic rather than merely its presence. The two shares sum to a
  # constant, so one is a linear function of the other and their variances are
  # equal. A hand-rolled delta method that dropped the covariance between
  # numerator and denominator -- the denominator contains the numerator -- would
  # not reproduce this.
  sections <- tp_rows(tp_sections())
  sections <- sections[sections$section != ".lake_total", ]

  expect_equal(
    sections$se_prop_of_lake_total[1L],
    sections$se_prop_of_lake_total[2L]
  )
})

test_that("the lake row's own share is exactly one, with a structural zero SE", {
  # Not NA. The lake total's share of itself is 1 by construction and was never
  # estimated, so there is no uncertainty to be unknown about -- and NA would
  # assert the opposite. This is the one place in this package where a zero SE
  # is the honest answer rather than a component that failed to propagate.
  lake <- tp_rows(tp_sections())
  lake <- lake[lake$section == ".lake_total", ]

  expect_identical(lake$prop_of_lake_total, 1)
  expect_identical(lake$se_prop_of_lake_total, 0)
})

test_that("an absent section reports no proportion and no SE", {
  # Absence stays absence: a section with no counts has no share to report, and
  # a zero would claim it held none of the effort rather than that nothing was
  # observed.
  design <- tp_design()
  design$sections <- data.frame(
    section = c("A", "B", "C"),
    stringsAsFactors = FALSE
  )
  result <- suppressWarnings(suppressMessages(
    estimate_effort_sections(
      design,
      variance_method = "taylor",
      conf_level = 0.95,
      aggregate_sections = TRUE,
      method = "correlated",
      missing_sections = "warn",
      target = "sampled_days"
    )
  ))
  rows <- as.data.frame(result$estimates)
  absent <- rows[rows$section == "C", ]

  expect_false(absent$data_available)
  expect_true(is.na(absent$prop_of_lake_total))
  expect_true(is.na(absent$se_prop_of_lake_total))
})
