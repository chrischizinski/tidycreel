# Three seams in as_hybrid_svydesign() (GH #229).
#
# 1. The two components were pooled into one stratum (`~day_type`) while each
#    kept its own sampling fraction, so `survey` derived a population size from
#    a row count that mixed access and roving rows. `fpc` then varied within
#    stratum -- one stratum carried two population sizes at once -- and the
#    only signal was an unexplained warning from `survey` next to a number
#    that looked fine.
#
# 2. `ids = ~1` made every ROW a PSU, so two counts taken on one date were two
#    independent sampling units. That is the defect class
#    `refuse_duplicate_psus()` (#193) exists to prevent on the creel_design
#    path, and this bridge routed around it. The consequence is an understated
#    standard error, never a wrong point estimate.
#
# 3. Adding the component totals is valid only if the components sample
#    disjoint sets of angler trips. Nothing in date/strata/count can establish
#    that, and nothing in the API stated it, so a user who ran both methods
#    over the same anglers got a double-counted total with no signal.
#
# See AUDIT-sections-hybrid-2026-08-28.md findings 5, 6 and 7.
#
# Revised for #246. The repeat count on 2024-06-01 that seam 2 was written
# around is now refused outright, because a per-day expansion is undefined
# when a day carries more than one row -- and the summing understated nothing,
# it inflated the total. HYBAUD-05 and -06 pin the refusal instead of the
# clustering it made unreachable; HYBAUD-04 and -07 move to the calendar-based
# population, which the pre-#246 versions of both actively pinned the defect of.

fr_access <- c(weekday = 0.5, weekend = 0.5)
fr_roving <- c(weekday = 0.4, weekend = 0.4)

# Two sampled dates per day_type so no stratum-by-component cell is left with a
# single PSU, and the weekday access column carries a REPEAT count on
# 2024-06-01 -- the row that seam 2 turns into a second independent PSU.
hy_access <- function(repeat_count = TRUE) {
  d <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-08", "2024-06-09")),
    day_type = c("weekday", "weekday", "weekend", "weekend"),
    count = c(12L, 15L, 30L, 28L),
    stringsAsFactors = FALSE
  )
  if (repeat_count) {
    d <- rbind(d, data.frame(
      date = as.Date("2024-06-01"),
      day_type = "weekday",
      count = 14L,
      stringsAsFactors = FALSE
    ))
  }
  d[order(d$date), ]
}

hy_roving <- function() {
  data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-08", "2024-06-09")),
    day_type = c("weekday", "weekday", "weekend", "weekend"),
    count = c(8L, 10L, 22L, 25L),
    stringsAsFactors = FALSE
  )
}

# The population of days every frame expands to (#246). Ten weekday days
# and six weekend days; the fixtures sample two of each.
hy_calendar <- function() {
  data.frame(
    date = as.Date(c(
      "2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04", "2024-06-05",
      "2024-06-06", "2024-06-07", "2024-06-15", "2024-06-16", "2024-06-17",
      "2024-06-08", "2024-06-09", "2024-06-10", "2024-06-11", "2024-06-12",
      "2024-06-13"
    )),
    day_type = c(rep("weekday", 10), rep("weekend", 6)),
    stringsAsFactors = FALSE
  )
}

# Long-form counts, one row per frame per sampled date (#248). The frame column
# is named `component` with values "access"/"roving" so the stratum keys stay
# "weekday.access" and every assertion below tests the same arithmetic it did
# before the API change.
hy_counts <- function(access = hy_access(), roving = hy_roving()) {
  access$component <- "access"
  roving$component <- "roving"
  rbind(access, roving)
}

hy_fraction <- list(access = fr_access, roving = fr_roving)

hy_design <- function(..., repeat_count = FALSE) {
  as_hybrid_svydesign(
    hy_counts(access = hy_access(repeat_count = repeat_count)),
    frame_col = "component",
    calendar = hy_calendar(),
    fraction = hy_fraction,
    trips_disjoint = TRUE,
    ...
  )
}

# Seam 1: each component carries its own population size ----------------------

test_that("HYBAUD-01: constructing with fpc does not warn that fpc varies within strata", {
  # Pre-fix this emitted `fpc' varies within strata: stratum weekday at stage 1
  # from survey::as.fpc(), uncaught and undocumented.
  expect_no_warning(hy_design())
})

test_that("HYBAUD-02: strata are the stratum-by-component interaction, not the stratum alone", {
  design <- hy_design()
  strata <- unique(as.character(design$strata[, 1]))
  # Pre-fix: c("weekday", "weekend") -- two strata, both components pooled.
  expect_setequal(
    strata,
    c("weekday.access", "weekday.roving", "weekend.access", "weekend.roving")
  )
  expect_true(".hybrid_stratum" %in% names(design$variables))
})

test_that("HYBAUD-03: every stratum carries exactly one population size", {
  design <- hy_design()
  by_stratum <- split(design$fpc$popsize, as.character(design$strata[, 1]))
  n_distinct <- vapply(by_stratum, function(x) length(unique(x)), integer(1))
  # Pre-fix weekday held 10 AND 12.5 simultaneously: one stratum, two frames.
  expect_true(all(n_distinct == 1L),
    info = paste("strata with >1 popsize:",
      paste(names(n_distinct)[n_distinct != 1L], collapse = ", "))
  )
})

test_that("HYBAUD-04: each stratum's population is its calendar days, not a fraction of its sample", {
  design <- hy_design()
  pop <- tapply(design$fpc$popsize, as.character(design$strata[, 1]), unique)
  cal <- hy_calendar()
  n_cal <- function(stratum) {
    length(unique(cal$date[cal$day_type == stratum]))
  }
  # Pre-#246 this identity was `sampled dates / within-day fraction`, which is
  # what the earlier version of this test pinned: 2 / 0.5 = 4 for access and
  # 2 / 0.4 = 5 for roving. `survey` read those as counts of DAYS, so one
  # stratum implied two different calendars, and neither was the real one.
  expect_equal(unname(pop[["weekday.access"]]), n_cal("weekday"))
  expect_equal(unname(pop[["weekday.roving"]]), n_cal("weekday"))
  expect_equal(unname(pop[["weekend.access"]]), n_cal("weekend"))
  expect_equal(unname(pop[["weekend.roving"]]), n_cal("weekend"))
})

test_that("HYBAUD-04b: both components agree on how many days the stratum holds", {
  # The consequence #246 named second: access and roving derived their
  # population from their own within-day fraction, so weekday was 4 days to one
  # component and 5 to the other, in the same survey.
  design <- hy_design()
  pop <- tapply(design$fpc$popsize, as.character(design$strata[, 1]), unique)
  expect_equal(unname(pop[["weekday.access"]]), unname(pop[["weekday.roving"]]))
  expect_equal(unname(pop[["weekend.access"]]), unname(pop[["weekend.roving"]]))
})

test_that("HYBAUD-04c: the fpc is a fraction of days and stays in range", {
  design <- hy_design()
  strata <- as.character(design$strata[, 1])
  frac <- design$fpc$sampsize[, 1] / design$fpc$popsize[, 1]
  expect_true(all(frac > 0 & frac <= 1))
  # 2 sampled weekday dates out of 10 calendar days.
  expect_equal(unique(frac[strata == "weekday.access"]), 2 / 10)
})

# Seam 2: the date is the PSU, and a day is one row ---------------------------

test_that("HYBAUD-05: repeated counts on one date are refused, not silently pooled", {
  # Seam 2 made every ROW a PSU. Clustering on the date fixed the variance but
  # left the point estimate summing both looks at one day, and #246's per-day
  # expansion then multiplies that inflation again. Refuse instead.
  expect_error(
    hy_design(repeat_count = TRUE),
    class = "creel_error_repeated_psus"
  )
})

test_that("HYBAUD-06: the refused repeat count is the one that would inflate the total", {
  # Pins WHY the refusal exists rather than merely that it fires: summing the
  # two looks at 2024-06-01 and averaging them are different numbers, and
  # nothing downstream could tell which one it had been handed.
  acc <- hy_access(repeat_count = TRUE)
  wk <- acc[acc$day_type == "weekday", ]
  summed <- sum(wk$count)
  averaged <- sum(tapply(wk$count, as.character(wk$date), mean))
  expect_gt(summed, averaged)
  expect_equal(length(unique(wk$date)), nrow(wk) - 1L)
})

test_that("HYBAUD-06b: the date is the PSU, so a stratum has one cluster per sampled date", {
  design <- hy_design()
  vars <- design$variables
  psus <- unique(paste(vars$.hybrid_stratum, vars$date))
  # nest = TRUE renumbers PSU ids within stratum, so the design's own cluster
  # count is the stratum-date count.
  expect_equal(length(unique(paste(
    as.character(design$strata[, 1]), design$cluster[, 1]
  ))), length(psus))
})

test_that("HYBAUD-07: the point total is the stratified sum of both expansions", {
  # If this moves, the weights changed. Pre-#246 the expected value was the
  # sampled-day total (counts / within-day fraction); it is now the period
  # total, which is the estimand the design documents.
  design <- hy_design()
  acc <- hy_access(repeat_count = FALSE)
  rov <- hy_roving()
  cal <- hy_calendar()
  n_cal <- vapply(
    split(cal$date, cal$day_type), function(x) length(unique(x)), integer(1)
  )
  expand <- function(dat, frac) {
    strata <- as.character(dat$day_type)
    n_sampled <- vapply(
      split(dat$date, strata), function(x) length(unique(x)), integer(1)
    )
    sum(dat$count / frac[strata] * (n_cal[strata] / n_sampled[strata]))
  }
  expected <- expand(acc, fr_access) + expand(rov, fr_roving)
  expect_equal(unname(coef(survey::svytotal(~count, design))), expected)
})

# Seam 3: the disjointness precondition ---------------------------------------

test_that("HYBAUD-08: the design cannot be constructed without affirming disjointness", {
  expect_error(
    as_hybrid_svydesign(
      hy_counts(),
      frame_col = "component",
      calendar = hy_calendar(),
      fraction = hy_fraction
    ),
    "trips_disjoint",
    class = "rlang_error"
  )
})

test_that("HYBAUD-09: declaring the components non-disjoint refuses rather than double counts", {
  # The arithmetic would happily produce a number; the number would be the sum
  # of two overlapping frames.
  expect_error(
    as_hybrid_svydesign(
      hy_counts(),
      frame_col = "component",
      calendar = hy_calendar(),
      fraction = hy_fraction,
      trips_disjoint = FALSE
    ),
    "may not be summed",
    class = "rlang_error"
  )
})

test_that("HYBAUD-10: trips_disjoint must be a non-missing logical scalar", {
  bad <- list("yes", NA, c(TRUE, TRUE), 1)
  for (value in bad) {
    expect_error(
      as_hybrid_svydesign(
        hy_counts(),
        frame_col = "component",
        calendar = hy_calendar(),
        fraction = hy_fraction,
        trips_disjoint = value
      ),
      class = "rlang_error"
    )
  }
})

# The documented estimation route ---------------------------------------------

test_that("HYBAUD-11: estimate_effort() refuses the hybrid object, as the docs now say", {
  # The help page previously routed users to estimate_effort(), which aborts on
  # anything that is not a creel_design. The documentation now sends them to
  # survey:: instead; this pins the behaviour the documentation describes.
  design <- hy_design()
  expect_false(inherits(design, "creel_design"))
  expect_error(estimate_effort(design), class = "rlang_error")
})

test_that("HYBAUD-12: the survey:: route from the examples runs and yields a finite SE", {
  design <- hy_design()
  total <- survey::svytotal(~count, design)
  expect_true(is.finite(coef(total)))
  expect_true(is.finite(survey::SE(total)))
  expect_gt(unname(survey::SE(total)), 0)
})
