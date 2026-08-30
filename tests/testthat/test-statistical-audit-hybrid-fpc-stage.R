# A within-day sampling fraction was supplied as the stage-1 fpc (GH #246).
#
# `access_fraction` is the proportion of access points covered on a sampled
# day. Since #229 the PSU is the date, so passing that fraction to
# `svydesign(fpc =)` made `survey` compute each stratum's population as
# `sampled dates / fraction` and read the result as a count of DAYS. Three
# sampled dates at 0.5 gave a "6 day" weekday stratum; a June weekday stratum
# holds about twenty. Nothing in the within-day fraction says anything about
# how much of the season was sampled.
#
# Two consequences, pinned separately below:
#
# 1. The correction ran against the wrong population, so a fraction that
#    should not shrink the stage-1 variance at all shrank it as though half
#    the calendar had been enumerated.
#
# 2. Access and roving each divided by their OWN fraction, so the two
#    components implied different calendars for the same stratum -- 6 days and
#    7.5 days at once. The same arithmetic signature as the defect #229 fixed,
#    displaced from within a stratum to across the pair of them.
#
# The repair takes the population from a caller-supplied `calendar`, the way
# creel_design() does, and puts both expansions in the weight: the within-day
# fraction to the whole of a sampled day, and N_h / n_h to the season. The
# estimand moves from a sampled-day total to a period total, which is what the
# design now documents.
#
# The point estimate carried no signal either way pre-fix: only the SE moved.

fpc_access <- function() {
  data.frame(
    date = as.Date(c("2024-06-03", "2024-06-04", "2024-06-08", "2024-06-09")),
    day_type = c("weekday", "weekday", "weekend", "weekend"),
    count = c(12L, 15L, 30L, 28L),
    stringsAsFactors = FALSE
  )
}

fpc_roving <- function() {
  data.frame(
    date = as.Date(c("2024-06-03", "2024-06-04", "2024-06-08", "2024-06-09")),
    day_type = c("weekday", "weekday", "weekend", "weekend"),
    count = c(8L, 10L, 22L, 25L),
    stringsAsFactors = FALSE
  )
}

# n_weekday and n_weekend are the calendar sizes; the sampled dates above are
# always included, so the calendar can be grown or shrunk around them.
fpc_calendar <- function(n_weekday = 20L, n_weekend = 10L) {
  wk <- unique(c(
    as.Date(c("2024-06-03", "2024-06-04")),
    as.Date("2024-07-01") + seq_len(n_weekday)
  ))[seq_len(n_weekday)]
  we <- unique(c(
    as.Date(c("2024-06-08", "2024-06-09")),
    as.Date("2024-08-01") + seq_len(n_weekend)
  ))[seq_len(n_weekend)]
  data.frame(
    date = c(wk, we),
    day_type = c(rep("weekday", length(wk)), rep("weekend", length(we))),
    stringsAsFactors = FALSE
  )
}

fpc_design <- function(access_fraction = c(weekday = 0.5, weekend = 0.5),
                       roving_fraction = c(weekday = 0.4, weekend = 0.4),
                       calendar = fpc_calendar(),
                       ...) {
  as_hybrid_svydesign(
    fpc_access(),
    fpc_roving(),
    calendar = calendar,
    access_fraction = access_fraction,
    roving_fraction = roving_fraction,
    trips_disjoint = TRUE,
    ...
  )
}

popsizes <- function(design) {
  tapply(design$fpc$popsize, as.character(design$strata[, 1]), unique)
}

# Consequence 1: the fpc runs against the calendar, not the within-day fraction

test_that("HYBFPC-01: the stratum population is the calendar's day count", {
  pop <- popsizes(fpc_design())
  # Pre-fix: 2 sampled dates / 0.5 = 4 for access, 2 / 0.4 = 5 for roving.
  expect_equal(unname(pop[["weekday.access"]]), 20)
  expect_equal(unname(pop[["weekend.access"]]), 10)
})

test_that("HYBFPC-02: the within-day fraction does not move the population", {
  # THE discriminating test. Pre-fix the population WAS the fraction's
  # reciprocal times the sample, so halving the fraction doubled the number of
  # days `survey` believed the stratum held. Nothing about how many access
  # points a crew covered can change the length of the season.
  loose <- popsizes(fpc_design(access_fraction = c(weekday = 0.9, weekend = 0.9)))
  tight <- popsizes(fpc_design(access_fraction = c(weekday = 0.1, weekend = 0.1)))
  expect_equal(unname(loose[["weekday.access"]]), unname(tight[["weekday.access"]]))
  expect_equal(unname(loose[["weekend.access"]]), unname(tight[["weekend.access"]]))
})

test_that("HYBFPC-03: the calendar does move the population, one day for one day", {
  # The other half of HYBFPC-02: the population has to respond to something,
  # and the thing it responds to is the calendar.
  short <- popsizes(fpc_design(calendar = fpc_calendar(n_weekday = 8L)))
  long <- popsizes(fpc_design(calendar = fpc_calendar(n_weekday = 24L)))
  expect_equal(unname(short[["weekday.access"]]), 8)
  expect_equal(unname(long[["weekday.access"]]), 24)
  expect_equal(unname(short[["weekend.access"]]), unname(long[["weekend.access"]]))
})

test_that("HYBFPC-04: the fpc is a fraction of days and never leaves (0, 1]", {
  # Pre-fix nothing bounded it: n_h / (n_h / f) is f, so it was in range by
  # accident, for a quantity that was not a day fraction at all.
  design <- fpc_design()
  vars <- design$variables
  sampled <- design$fpc$sampsize[, 1]
  popsize <- design$fpc$popsize[, 1]
  expect_true(all(sampled <= popsize))
  expect_true(all(sampled / popsize > 0 & sampled / popsize <= 1))
  strata <- as.character(design$strata[, 1])
  expect_equal(unique((sampled / popsize)[strata == "weekday.access"]), 2 / 20)
  expect_equal(unique((sampled / popsize)[strata == "weekend.roving"]), 2 / 10)
})

# Consequence 2: one stratum, one calendar, whichever method observed it

test_that("HYBFPC-05: access and roving agree on how many days the stratum holds", {
  # Pre-fix weekday held 4 days for access and 5 for roving simultaneously,
  # because each divided the same sample by its own within-day fraction.
  pop <- popsizes(fpc_design())
  expect_equal(unname(pop[["weekday.access"]]), unname(pop[["weekday.roving"]]))
  expect_equal(unname(pop[["weekend.access"]]), unname(pop[["weekend.roving"]]))
})

test_that("HYBFPC-06: they still agree when the two fractions differ sharply", {
  pop <- popsizes(fpc_design(
    access_fraction = c(weekday = 1, weekend = 1),
    roving_fraction = c(weekday = 0.1, weekend = 0.1)
  ))
  expect_equal(unname(pop[["weekday.access"]]), unname(pop[["weekday.roving"]]))
  expect_equal(unname(pop[["weekend.access"]]), unname(pop[["weekend.roving"]]))
})

# The estimand: a period total, with both expansions in the weight

test_that("HYBFPC-07: the weight is the product of both expansions", {
  design <- fpc_design()
  vars <- design$variables
  wk_acc <- unique(vars$weight[vars$.hybrid_stratum == "weekday.access"])
  # (1 / 0.5) to the whole day, then (20 / 2) to the season.
  expect_equal(wk_acc, (1 / 0.5) * (20 / 2))
  we_rov <- unique(vars$weight[vars$.hybrid_stratum == "weekend.roving"])
  expect_equal(we_rov, (1 / 0.4) * (10 / 2))
})

test_that("HYBFPC-08: doubling the calendar doubles the total", {
  # The estimand is a period total. If the weight had kept only the within-day
  # fraction, the total would be a sampled-day total and this would not move.
  base <- survey::svytotal(~count, fpc_design(calendar = fpc_calendar(10L, 10L)))
  wide <- survey::svytotal(~count, fpc_design(calendar = fpc_calendar(20L, 20L)))
  expect_equal(unname(coef(wide)), 2 * unname(coef(base)))
})

test_that("HYBFPC-09: halving a within-day fraction doubles that component's contribution", {
  # The within-day expansion survives the repair; it simply stopped driving the
  # fpc. Option (a) in the issue would have discarded it.
  vars_half <- fpc_design(access_fraction = c(weekday = 0.25, weekend = 0.5))$variables
  vars_base <- fpc_design(access_fraction = c(weekday = 0.5, weekend = 0.5))$variables
  wk <- function(v) unique(v$weight[v$.hybrid_stratum == "weekday.access"])
  expect_equal(wk(vars_half), 2 * wk(vars_base))
  # and the roving component is untouched by the access fraction
  rv <- function(v) unique(v$weight[v$.hybrid_stratum == "weekday.roving"])
  expect_equal(rv(vars_half), rv(vars_base))
})

# The correction is real, and it is the only thing fpc = FALSE removes

test_that("HYBFPC-10: fpc = FALSE leaves the total alone and raises the SE", {
  with_fpc <- survey::svytotal(~count, fpc_design())
  without <- survey::svytotal(~count, fpc_design(fpc = FALSE))
  expect_equal(unname(coef(with_fpc)), unname(coef(without)))
  expect_lt(unname(survey::SE(with_fpc)), unname(survey::SE(without)))
})

test_that("HYBFPC-11: a fully sampled calendar is a census and carries no stage-1 variance", {
  # The metamorphic end point. When every day in the stratum was sampled the
  # fpc is 1 and the between-day term vanishes. Pre-fix this was unreachable:
  # the population was the sample over a within-day fraction, so it could only
  # equal the sample when that fraction was exactly 1, which is a statement
  # about access points and not about the calendar.
  census <- fpc_design(calendar = fpc_calendar(n_weekday = 2L, n_weekend = 2L))
  expect_true(all(census$fpc$sampsize[, 1] == census$fpc$popsize[, 1]))
  total <- survey::svytotal(~count, census)
  expect_equal(as.numeric(survey::SE(total)), 0)
  # and with every day enumerated the total is just the within-day expansion
  acc <- fpc_access()
  rov <- fpc_roving()
  expect_equal(
    unname(coef(total)),
    sum(acc$count / c(weekday = 0.5, weekend = 0.5)[acc$day_type]) +
      sum(rov$count / c(weekday = 0.4, weekend = 0.4)[rov$day_type])
  )
})

# The preconditions the day expansion needs

test_that("HYBFPC-12: calendar is required, with no default", {
  expect_error(
    as_hybrid_svydesign(
      fpc_access(),
      fpc_roving(),
      access_fraction = c(weekday = 0.5, weekend = 0.5),
      roving_fraction = c(weekday = 0.4, weekend = 0.4),
      trips_disjoint = TRUE
    ),
    "calendar"
  )
})

test_that("HYBFPC-13: a sampled date absent from the calendar is refused", {
  # Otherwise n_h exceeds N_h, the sampling fraction leaves (0, 1], and the
  # population the total expands to is smaller than the sample it came from.
  expect_error(
    fpc_design(calendar = fpc_calendar()[-1, , drop = FALSE]),
    "absent from"
  )
})

test_that("HYBFPC-14: a repeated count on one date is refused", {
  # A per-day expansion is undefined when a day carries more than one row: the
  # rows are summed, so the total is multiplied by the counts per day and then
  # multiplied again by N_h / n_h.
  repeated <- rbind(
    fpc_access(),
    data.frame(
      date = as.Date("2024-06-03"),
      day_type = "weekday",
      count = 14L,
      stringsAsFactors = FALSE
    )
  )
  expect_error(
    as_hybrid_svydesign(
      repeated,
      fpc_roving(),
      calendar = fpc_calendar(),
      access_fraction = c(weekday = 0.5, weekend = 0.5),
      roving_fraction = c(weekday = 0.4, weekend = 0.4),
      trips_disjoint = TRUE
    ),
    class = "creel_error_repeated_psus"
  )
})

test_that("HYBFPC-15: the stratum-by-component strata from #229 are unchanged", {
  # A regression pin on the seam this one sits on top of. #246 changed where
  # the population comes from, not what a stratum is.
  design <- fpc_design()
  expect_setequal(
    unique(as.character(design$strata[, 1])),
    c("weekday.access", "weekday.roving", "weekend.access", "weekend.roving")
  )
})
