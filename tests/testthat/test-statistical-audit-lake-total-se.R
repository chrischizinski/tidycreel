# The .lake_total row must report the same variance components its section rows
# do (GH #228). Section rows come from estimate_effort_total(), whose `se` is
# sqrt(var_between + var_within). The lake row came from
# aggregate_section_totals(), a pure svyby() + svycontrast() aggregation that
# carries the between-day component and its across-section covariance and
# nothing else. Two definitions of variance in one column, with `se_between` and
# `se_within` reported as NA so the omission read as "unknown" rather than
# "not included".
#
# See AUDIT-sections-hybrid-2026-08-28.md finding 2.

# Two sections over two weekday and two weekend PSUs. `spread` is the entire
# within-day signal: 0 counts a section identically at both times, so it has no
# within-day component at all.
lts_design <- function(spread_a, spread_b, repeat_counts = TRUE) {
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

  sections <- data.frame(section = c("A", "B"), stringsAsFactors = FALSE)
  design <- creel_design(calendar = cal, date = date, strata = day_type)
  design <- add_sections(design, sections, section_col = section)

  if (!repeat_counts) {
    # One count per day is the geometry every pre-existing sections fixture
    # uses: var_within is 0 for the sections too, so the two definitions of
    # variance coincide and the discrepancy cannot appear.
    counts <- base
    counts$effort_hours <- counts$level
    counts$level <- NULL
    return(suppressWarnings(add_counts(design, counts, count_col = effort_hours)))
  }

  first <- base
  second <- base
  first$count_time <- 9
  second$count_time <- 15
  first$effort_hours <- base$level * (1 - spread)
  second$effort_hours <- base$level * (1 + spread)

  counts <- rbind(first, second)
  counts$period_length <- 12
  counts$level <- NULL

  suppressWarnings(add_counts(
    design,
    counts,
    count_col = effort_hours,
    count_time_col = count_time,
    period_length_col = period_length
  ))
}

lts_effort <- function(design, ...) {
  as.data.frame(
    suppressWarnings(suppressMessages(estimate_effort(design, ...)))$estimates
  )
}

test_that("the lake total's se is at least as large as the largest section's", {
  # The headline symptom. Sections on shared days are positively correlated, so
  # the total's se must exceed even an independent combination of theirs -- it
  # cannot be smaller than a single section it contains. The reported figure was
  # smaller than every one of them, because it was missing a component they all
  # carried.
  est <- lts_effort(lts_design(spread_a = 0.4, spread_b = 0.4))
  lake <- est[est$section == ".lake_total", ]
  sections <- est[est$section != ".lake_total", ]

  expect_gte(lake$se, max(sections$se))
})

test_that("the lake total reports the components its se is built from", {
  # `se_between` and `se_within` were NA on this row. The package's convention
  # is that NA means unknown, so the missing component read as a decomposition
  # that could not be done rather than one that was never added. Reporting the
  # two components is what makes the omission visible if it ever returns.
  est <- lts_effort(lts_design(spread_a = 0.4, spread_b = 0.4))
  lake <- est[est$section == ".lake_total", ]

  expect_false(is.na(lake$se_between))
  expect_false(is.na(lake$se_within))
  expect_gt(lake$se_within, 0)
  expect_equal(lake$se, sqrt(lake$se_between^2 + lake$se_within^2))
})

test_that("the lake total's within-day component is the sum of the sections'", {
  # Within-day variance is second-stage sampling error inside one unit, so on a
  # shared day it is independent across sections and the section components add.
  # The between-day covariance the sections do share is already inside the
  # svycontrast() figure, which is why only this component is combined by hand.
  est <- lts_effort(lts_design(spread_a = 0.7, spread_b = 0.2))
  lake <- est[est$section == ".lake_total", ]
  sections <- est[est$section != ".lake_total", ]

  expect_equal(lake$se_within, sqrt(sum(sections$se_within^2)))
})

test_that("a section's within-day spread moves the lake total's se", {
  # Metamorphic, and the one property that cannot pass for the wrong reason:
  # hold section B fixed and widen only A's within-day spread. If the lake row
  # were still built from the survey object alone its se would not move at all,
  # because the between-day totals are unchanged by redistributing a day's
  # effort between its two counts.
  narrow <- lts_effort(lts_design(spread_a = 0.1, spread_b = 0.3))
  wide <- lts_effort(lts_design(spread_a = 0.9, spread_b = 0.3))

  narrow_lake <- narrow[narrow$section == ".lake_total", ]
  wide_lake <- wide[wide$section == ".lake_total", ]

  expect_gt(wide_lake$se_within, narrow_lake$se_within)
  expect_gt(wide_lake$se, narrow_lake$se)

  # The between-day component is what was there before, and it is genuinely
  # unmoved by the change. Asserting that pins the difference above to the
  # component that was missing rather than to the estimator having shifted.
  expect_equal(wide_lake$se_between, narrow_lake$se_between)
})

test_that("the independent method carries the within-day component too", {
  # method = "independent" takes a different route to the between-day figure
  # (Cochran 5.2 rather than svycontrast) but omitted the within-day component
  # by the same mechanism, so the fix has to reach both.
  est <- lts_effort(lts_design(spread_a = 0.4, spread_b = 0.4), method = "independent")
  lake <- est[est$section == ".lake_total", ]
  sections <- est[est$section != ".lake_total", ]

  expect_gt(lake$se_within, 0)
  expect_gte(lake$se, max(sections$se))
})

test_that("one count per day leaves the lake total's se unchanged", {
  # The complement, and the reason no existing test failed: with a single count
  # per day there is no within-day variance to add, so the component is a true
  # 0 and the reported se is still the between-day figure. A fix that inflated
  # this case would be adding variance that the design does not contain.
  est <- lts_effort(lts_design(spread_a = 0, spread_b = 0, repeat_counts = FALSE))
  lake <- est[est$section == ".lake_total", ]

  expect_identical(lake$se_within, 0)
  expect_equal(lake$se, lake$se_between)
})
