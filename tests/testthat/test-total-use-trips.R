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

test_that("a missing trip status drops the interview rather than becoming a phantom row (GH #266)", {
  # `==` returns NA for a missing status, and a logical index carrying NA
  # subsets a data frame to an all-NA *row* instead of dropping it. That row
  # reaches svydesign() with a missing stratum and aborts inside survey with
  # "missing values in `strata'" -- a failure with no tidycreel wording at all.
  #
  # add_interviews() refuses NA trip status ("Trip status is required for all
  # interviews"), so this is not reachable through the constructor. The guard is
  # cheap and exactly equivalent when no status is missing, and this test pins
  # it: with `==` in place of `%in%` the estimators below abort.
  design <- drop_sections(mixed_status_total_design())
  iv <- design$interviews
  iv$trip_status[c(3L, 7L, 11L)] <- NA
  design$interviews <- iv
  design$interview_survey <- build_interview_survey(
    iv,
    strata = stats::reformulate(design$strata_cols)
  )

  filtered <- filter_interviews_use_trips(design, "complete")
  expect_false(anyNA(filtered$interviews$trip_status))
  expect_equal(
    nrow(filtered$interviews),
    sum(tolower(iv$trip_status) == "complete", na.rm = TRUE)
  )

  for (f in total_estimators) {
    result <- quiet_total(f, design, use_trips = "complete")
    expect_equal(result$estimates$n, nrow(filtered$interviews), info = f)
  }
})

# A design whose unclassified domain has a rate spread *only* among the
# incomplete trips. Under use_trips = "complete" those interviews are not in the
# estimate, so a warning about them describes data the returned number was not
# built from -- and reports per-level rates that are not the estimate's either.
# The domain is named distinctively because the warning is cli .frequency =
# "once", keyed by estimator and domain: a name shared with another test file
# would silence it here depending on run order.
incomplete_only_spread_design <- function(seed = 266L) {
  set.seed(seed)
  design <- make_sectioned_species_design(48L)
  design[["sections"]] <- NULL
  iv <- design$interviews
  # Both cycles must be co-prime with each other or the two factors confound:
  # rep_len(c("complete","incomplete"), n) alongside rep_len(c("bank","boat"), n)
  # makes every complete trip a bank trip and every incomplete one a boat trip,
  # leaving one gear level after filtering. The warning would then be silent
  # because the domain degenerated, not because its rates agree -- the assertion
  # would hold without testing anything. Period 4 against period 2 fills all
  # four cells evenly.
  iv$trip_status <- rep_len(c("complete", "complete", "incomplete", "incomplete"), nrow(iv))
  iv$gear_266 <- rep_len(c("bank", "boat"), nrow(iv))

  complete <- tolower(iv$trip_status) == "complete"
  boat_incomplete <- !complete & iv$gear_266 == "boat"
  bank_incomplete <- !complete & iv$gear_266 == "bank"

  # The complete trips must have *identical* rates across gear, not merely
  # similar ones: the rate is a ratio of sums, so drawing effort at random and
  # scaling catch by a constant leaves a spread that the threshold can clear on
  # its own (measured: bank 0.251 against boat 0.174). Fixing effort and catch
  # per row makes the two levels equal by construction, so any spread the
  # warning reports under use_trips = "complete" came from the incomplete trips.
  # `.angler_effort` is the denominator the rate actually divides by -- a column
  # add_interviews() derives from hours_fished and n_anglers at attach time, so
  # editing those two afterwards leaves the rate reading a stale denominator.
  # Set the derived column too, or the "equal rates" this fixture depends on are
  # not equal (measured: bank 0.301 against boat 0.209).
  iv$hours_fished[complete] <- 4
  iv$n_anglers[complete] <- 1L
  iv$.angler_effort[complete] <- 4
  iv$catch_total[complete] <- 2
  iv$catch_kept[complete] <- 1

  # The wide gear split lives entirely in the trips "complete" excludes.
  iv$catch_total[boat_incomplete] <- round(iv$hours_fished[boat_incomplete] * 4)
  iv$catch_total[bank_incomplete] <- round(iv$hours_fished[bank_incomplete] * 0.05)
  iv$catch_kept[boat_incomplete] <- round(iv$hours_fished[boat_incomplete] * 4)
  iv$catch_kept[bank_incomplete] <- round(iv$hours_fished[bank_incomplete] * 0.05)

  design$interviews <- iv
  design$interview_survey <- build_interview_survey(
    iv,
    strata = stats::reformulate(design$strata_cols)
  )

  # The release screen rebuilds its numerator from the catch table's released
  # rows rather than the interview catch column, so the same shape has to be
  # given to it there or the release case would test nothing.
  boat_ids <- iv$interview_id[boat_incomplete]
  bank_ids <- iv$interview_id[bank_incomplete]
  complete_ids <- iv$interview_id[complete]

  # Setting a constant `count` on the existing released rows is not enough: the
  # generator gives an interview one row, two rows, or none at all (35 of 48
  # carry any), so a per-row constant still sums to 0, 3 or 6 per interview and
  # the two gear levels end up with different RPUE anyway (measured: bank 0.812
  # against boat 0.625). Replace the complete trips' released rows outright with
  # exactly one row each, so the per-interview numerator is constant.
  rel <- design$catch$catch_type == "released"
  design$catch <- design$catch[!(rel & design$catch$interview_id %in% complete_ids), , drop = FALSE]
  design$catch <- rbind(
    design$catch,
    data.frame(
      interview_id = complete_ids,
      species = "bass",
      count = 3,
      catch_type = "released",
      stringsAsFactors = FALSE
    )
  )

  rel <- design$catch$catch_type == "released"
  design$catch$count[rel & design$catch$interview_id %in% boat_ids] <- 40L
  design$catch$count[rel & design$catch$interview_id %in% bank_ids] <- 0L

  design
}

test_that("the spread fixture is not confounded: all four cells are filled (GH #266)", {
  # Guards the guard, as above. If gear collapses to one level under
  # use_trips = "complete", the silence asserted below proves nothing: a domain
  # with a single level has no rate spread to report either way.
  design <- incomplete_only_spread_design()
  tab <- table(design$interviews$gear_266, design$interviews$trip_status)

  expect_true(all(tab > 0))
  expect_length(unique(design$interviews$gear_266[
    tolower(design$interviews$trip_status) == "complete"
  ]), 2L)
})

test_that("the pooled-domain warning describes the filtered interviews (GH #266)", {
  # The filter runs before warn_pooled_domain_mix() for this reason. With the
  # order reversed both calls warn identically, because the warning reads the
  # interviews as supplied rather than the ones the estimate is built from.
  #
  # "complete" is asserted first on purpose: the warning is cli .frequency =
  # "once", so a firing in the "all" call would mask a regression in the
  # "complete" call if the order were swapped.
  for (f in total_estimators) {
    design <- incomplete_only_spread_design()

    expect_no_warning(
      suppressMessages(get(f)(design, use_trips = "complete")),
      class = "creel_warning_pooled_domain_mix"
    )
    expect_warning(
      suppressMessages(get(f)(design, use_trips = "all")),
      class = "creel_warning_pooled_domain_mix"
    )
  }
})
