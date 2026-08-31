# use_trips on the three total estimators (GH #266) ----
#
# The fourth defect in this cluster, and the second that changes numbers.
#
# `estimate_total_catch()` threaded `use_trips` into each dispatch branch
# separately, so it reached the ungrouped and grouped paths and was dropped at
# the species and section call sites -- accepted, documented, and inert.
# `estimate_total_harvest()` and `estimate_total_release()` had no `use_trips`
# argument at all and no trip filter on any path, so they were built from every
# interview while their own rate functions default to the complete trips.
#
# Why it matters rather than merely differing: a rate from incomplete trips is
# length-biased. An interview taken mid-trip reports the catch so far against
# the effort so far, and the two do not scale together over the trip. A total is
# effort times that rate, so it inherits the bias while still looking plausible.
#
# The fix applies one filter per estimator, before every dispatch, so all four
# paths are built from the same interviews.

# The shared fixture assigns sections with rep_len(c("North", "South"), n), so
# alternating trip_status by row makes North all-complete and South all-
# incomplete -- the factor under test perfectly confounded with the grouping
# variable, which hid the sibling defect (#263) completely on its first probe.
# Mix the status *within* each section instead.
mixed_status_total_design <- function(n_interviews = 48L, seed = 266L) {
  # Seeded: the shared fixture draws catch and effort at random, so without this
  # the file's numbers move between runs and a failure cannot be reproduced from
  # the output alone.
  set.seed(seed)
  design <- make_sectioned_species_design(n_interviews)
  iv <- design$interviews
  iv$trip_status <- stats::ave(
    seq_len(nrow(iv)),
    iv[[design$section_col]],
    FUN = function(i) rep(c("complete", "incomplete"), length.out = length(i))
  )
  design$interviews <- iv
  design$interview_survey <- build_interview_survey(
    iv,
    strata = stats::reformulate(design$strata_cols)
  )
  design
}

drop_sections <- function(design) {
  design[["sections"]] <- NULL
  design
}

# The design the estimator should be equivalent to once it has filtered: the
# same interviews, chosen outside the estimator, with filtering then switched
# off. Built with the same rebuild_interview_survey() the estimators use, so the
# comparison isolates *which interviews* are used and not how the survey object
# is assembled.
complete_only <- function(design) {
  iv <- design$interviews
  rebuild_interview_survey(design, iv[tolower(iv$trip_status) == "complete", , drop = FALSE])
}

quiet_total <- function(f, design, ...) {
  suppressWarnings(suppressMessages(get(f)(design, ...)))
}

total_estimators <- c(
  "estimate_total_catch",
  "estimate_total_harvest",
  "estimate_total_release"
)

test_that("the fixture is not confounded: both sections mix trip statuses (GH #266)", {
  # Guards the guard. Every identity below is vacuous if the fixture reverts to
  # one status per section, and it would still look like a passing test.
  design <- mixed_status_total_design()
  tab <- table(design$interviews$section, design$interviews$trip_status)

  expect_setequal(colnames(tab), c("complete", "incomplete"))
  expect_true(all(tab > 0))
  expect_equal(as.vector(tab["North", ]), as.vector(tab["South", ]))
})

test_that("use_trips = 'complete' restricts the ungrouped total to complete trips (GH #266)", {
  design <- mixed_status_total_design()
  filtered <- complete_only(design)

  for (f in total_estimators) {
    complete <- quiet_total(f, drop_sections(design), use_trips = "complete")
    reference <- quiet_total(f, drop_sections(filtered), use_trips = "all")

    expect_equal(complete$estimates$estimate, reference$estimates$estimate, info = f)
    expect_equal(complete$estimates$se, reference$estimates$se, info = f)
    expect_equal(complete$estimates$n, reference$estimates$n, info = f)
  }
})

test_that("use_trips reaches the grouped total (GH #266)", {
  design <- drop_sections(mixed_status_total_design())
  filtered <- drop_sections(complete_only(mixed_status_total_design()))

  for (f in total_estimators) {
    complete <- quiet_total(f, design, by = day_type, use_trips = "complete")
    reference <- quiet_total(f, filtered, by = day_type, use_trips = "all")

    expect_equal(complete$estimates$estimate, reference$estimates$estimate, info = f)
    expect_equal(complete$estimates$n, reference$estimates$n, info = f)
  }
})

test_that("use_trips reaches the species total, which dropped it (GH #266)", {
  # estimate_total_catch() passed use_trips to its ungrouped and grouped
  # branches but not to estimate_total_catch_species(), so `by = species`
  # returned the unfiltered number on an unsectioned design -- the same
  # mechanism as the section call site, one branch over.
  design <- drop_sections(mixed_status_total_design())
  filtered <- drop_sections(complete_only(mixed_status_total_design()))

  for (f in total_estimators) {
    complete <- quiet_total(f, design, by = species, use_trips = "complete")
    reference <- quiet_total(f, filtered, by = species, use_trips = "all")

    expect_equal(complete$estimates$estimate, reference$estimates$estimate, info = f)
    expect_equal(complete$estimates$n, reference$estimates$n, info = f)
  }
})

test_that("use_trips reaches the sectioned total, the headline defect (GH #266)", {
  design <- mixed_status_total_design()
  filtered <- complete_only(mixed_status_total_design())

  for (f in total_estimators) {
    complete <- quiet_total(f, design, use_trips = "complete")
    reference <- quiet_total(f, filtered, use_trips = "all")

    expect_equal(complete$estimates$estimate, reference$estimates$estimate, info = f)
    expect_equal(complete$estimates$se, reference$estimates$se, info = f)
    expect_equal(complete$estimates$n, reference$estimates$n, info = f)
  }
})

test_that("use_trips = 'all' keeps every interview on every path (GH #266)", {
  # The counterpart to the identities above: filtering must be conditional on
  # the argument, not unconditional. n is the deterministic half of the
  # comparison -- 48 interviews against 24 -- so this does not depend on the
  # fixture's random draw the way comparing point estimates would.
  design <- mixed_status_total_design()
  n_interviews <- nrow(design$interviews)
  n_complete <- sum(tolower(design$interviews$trip_status) == "complete")

  for (f in total_estimators) {
    all_trips <- quiet_total(f, drop_sections(design), use_trips = "all")
    complete <- quiet_total(f, drop_sections(design), use_trips = "complete")

    expect_equal(all_trips$estimates$n, n_interviews, info = f)
    expect_equal(complete$estimates$n, n_complete, info = f)
  }
})

test_that("the totals default to complete trips (GH #266)", {
  # The default is the whole point of the change for harvest and release: they
  # previously had no filter, so their default was every interview.
  design <- drop_sections(mixed_status_total_design())

  for (f in total_estimators) {
    default <- quiet_total(f, design)
    explicit <- quiet_total(f, design, use_trips = "complete")

    expect_equal(default$estimates$estimate, explicit$estimates$estimate, info = f)
    expect_equal(default$estimates$n, explicit$estimates$n, info = f)
  }
})

test_that("an unrecognised use_trips value is refused on every total (GH #266)", {
  design <- drop_sections(mixed_status_total_design())

  for (f in total_estimators) {
    expect_error(quiet_total(f, design, use_trips = "banana"), "should be one of", info = f)
  }
})

test_that("use_trips = 'all' is refused on bus-route and ice totals (GH #266)", {
  # These estimate a completed-trip Horvitz-Thompson total, where an uncompleted
  # trip contributes catch-so-far under the inclusion probability of a completed
  # one. estimate_total_catch() already refused it; the argument is new on the
  # other two and must refuse rather than accept-and-ignore, which is the defect
  # being fixed.
  for (design_type in c("bus_route", "ice")) {
    design <- suppressWarnings(suppressMessages(
      build_ht_multispecies_design(design_type, seed = 266L)
    ))

    for (f in total_estimators) {
      expect_error(
        quiet_total(f, design, use_trips = "all"),
        "not available for",
        info = paste(f, design_type)
      )
    }
  }
})

test_that("a design with no trip status column is unaffected by use_trips (GH #266)", {
  # Backwards compatibility: filtering is impossible without the column, and the
  # totals must not start erroring on designs that never recorded trip status.
  design <- drop_sections(mixed_status_total_design())
  design$trip_status_col <- NULL

  for (f in total_estimators) {
    complete <- quiet_total(f, design, use_trips = "complete")
    all_trips <- quiet_total(f, design, use_trips = "all")

    expect_equal(complete$estimates$estimate, all_trips$estimates$estimate, info = f)
    expect_equal(complete$estimates$n, nrow(design$interviews), info = f)
  }
})
