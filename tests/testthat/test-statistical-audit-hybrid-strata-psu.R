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

hy_design <- function(..., repeat_count = TRUE) {
  as_hybrid_svydesign(
    hy_access(repeat_count = repeat_count),
    hy_roving(),
    access_fraction = fr_access,
    roving_fraction = fr_roving,
    trips_disjoint = TRUE,
    ...
  )
}

# Seam 1: each component carries its own population size ----------------------

test_that("HYBAUD-01: constructing with fpc does not warn that fpc varies within strata", {
  # Pre-fix this emitted `fpc' varies within strata: stratum weekday at stage 1
  # from survey::as.fpc(), uncaught and undocumented.
  expect_no_warning(hy_design(repeat_count = FALSE))
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

test_that("HYBAUD-04: each stratum's population is its own sampled dates over its own fraction", {
  design <- hy_design()
  pop <- tapply(design$fpc$popsize, as.character(design$strata[, 1]), unique)
  vars <- design$variables
  n_dates <- function(component, stratum) {
    length(unique(vars$date[vars$component == component &
      vars$day_type == stratum]))
  }
  # The weekday access cell has 3 ROWS but only 2 sampled DATES. Pre-fix the
  # population was derived from the pooled row count, so this identity failed
  # on both counts -- wrong numerator and a fraction from the wrong component.
  expect_equal(unname(pop[["weekday.access"]]),
    n_dates("access", "weekday") / fr_access[["weekday"]])
  expect_equal(unname(pop[["weekday.roving"]]),
    n_dates("roving", "weekday") / fr_roving[["weekday"]])
  expect_equal(unname(pop[["weekend.access"]]),
    n_dates("access", "weekend") / fr_access[["weekend"]])
})

# Seam 2: the date is the PSU -------------------------------------------------

test_that("HYBAUD-05: two counts on one date are one PSU, not two", {
  design <- hy_design()
  vars <- design$variables
  expect_equal(nrow(vars), 9L) # 5 access rows + 4 roving
  psus <- unique(paste(vars$.hybrid_stratum, vars$date))
  # Pre-fix `ids = ~1` gave 9 PSUs for 9 rows; there are only 8 sampled
  # stratum-dates, because 2024-06-01 access was counted twice.
  expect_equal(length(psus), 8L)
  # nest = TRUE renumbers PSU ids within stratum, so the design's own cluster
  # count is the stratum-date count -- 8 here, and 9 pre-fix.
  expect_equal(length(unique(design$cluster[, 1])), length(psus))
})

test_that("HYBAUD-06: the repeat count does not buy an extra degree of freedom", {
  # A second count on an already-sampled date carries information about
  # within-day variation, never about a further day. Treating it as an
  # independent PSU understates the SE of the total.
  clustered <- survey::svytotal(~count, hy_design())
  rows_as_psus <- survey::svydesign(
    ids = ~1,
    strata = ~.hybrid_stratum,
    weights = ~weight,
    fpc = ~fpc_val,
    data = hy_design()$variables
  )
  naive <- survey::svytotal(~count, rows_as_psus)
  expect_equal(unname(coef(clustered)), unname(coef(naive)))
  expect_gt(unname(survey::SE(clustered)), unname(survey::SE(naive)))
})

test_that("HYBAUD-07: the point total is the stratified sum and is unchanged by the repair", {
  # The repair is variance-only. If this moves, the weights changed and the
  # seam fix has become a silent re-estimation.
  design <- hy_design()
  acc <- hy_access()
  rov <- hy_roving()
  expected <- sum(acc$count / fr_access[as.character(acc$day_type)]) +
    sum(rov$count / fr_roving[as.character(rov$day_type)])
  expect_equal(unname(coef(survey::svytotal(~count, design))), expected)
})

# Seam 3: the disjointness precondition ---------------------------------------

test_that("HYBAUD-08: the design cannot be constructed without affirming disjointness", {
  expect_error(
    as_hybrid_svydesign(
      hy_access(),
      hy_roving(),
      access_fraction = fr_access,
      roving_fraction = fr_roving
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
      hy_access(),
      hy_roving(),
      access_fraction = fr_access,
      roving_fraction = fr_roving,
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
        hy_access(),
        hy_roving(),
        access_fraction = fr_access,
        roving_fraction = fr_roving,
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
