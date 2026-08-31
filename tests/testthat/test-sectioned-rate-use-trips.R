# use_trips on sectioned rate designs (GH #263) ----
#
# The third defect in the sectioned-rate cluster, after #257 and #265, and the
# only one of the three that changes numbers rather than erroring.
#
# `estimate_catch_rate()` runs its use_trips block and *then* dispatches to the
# section path, so the section helper receives a design already filtered to
# complete trips. `estimate_harvest_rate()` and `estimate_release_rate()`
# dispatched first, so their use_trips block was dead code on a sectioned
# design: "all" and "complete" returned the same number, an unrecognised value
# was never rejected, and no filtering message was emitted.
#
# Why it matters rather than merely differing: HPUE and RPUE from incomplete
# trips are length-biased. An interview taken mid-trip reports catch so far
# against effort so far, and the two do not scale together over the trip.
# Excluding incomplete trips is the documented default for that reason, so a
# sectioned design was silently opting out of it and still returning a
# plausible number.

# The fixture assigns sections with rep_len(c("North", "South"), n), so
# alternating trip_status by row makes North all-complete and South all-
# incomplete -- the factor under test perfectly confounded with the grouping
# variable, which hid this defect completely on the first probe. Mix the status
# *within* each section instead.
mixed_status_sectioned_design <- function(n_interviews = 48L) {
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

quiet_rate <- function(f, design, ...) {
  suppressWarnings(suppressMessages(get(f)(design, ...)))
}

use_trips_estimators <- c(
  "estimate_catch_rate",
  "estimate_harvest_rate",
  "estimate_release_rate"
)

test_that("the fixture is not confounded: both sections mix trip statuses (GH #263)", {
  # Guards the guard. Every assertion below is vacuous if the fixture reverts to
  # one status per section, and it would still look like a passing test.
  design <- mixed_status_sectioned_design()
  tab <- table(design$interviews$section, design$interviews$trip_status)

  expect_setequal(colnames(tab), c("complete", "incomplete"))
  expect_true(all(tab > 0))
  expect_equal(as.vector(tab["North", ]), c(12L, 12L))
  expect_equal(as.vector(tab["South", ]), c(12L, 12L))
})

test_that("sectioned rates filter to complete trips by default (GH #263)", {
  # The defect in one number. Each section holds 12 complete and 12 incomplete
  # interviews, so a path honouring the documented default reports n = 12 per
  # section; harvest and release reported 24, silently including every
  # incomplete trip.
  #
  # 24 interviews per section rather than the fixture's usual 18, because
  # estimate_catch_rate() refuses fewer than 10 complete trips and the identity
  # test below builds single-section reference designs.
  design <- mixed_status_sectioned_design()

  for (f in use_trips_estimators) {
    result <- quiet_rate(f, design)
    expect_equal(result$estimates$n, c(12L, 12L), info = f)
  }
})

test_that("use_trips = 'all' reaches the sectioned path (GH #263)", {
  # The argument was accepted and discarded: "all" and "complete" returned
  # identical numbers on all three sections paths for harvest and release.
  design <- mixed_status_sectioned_design()

  for (f in use_trips_estimators) {
    complete <- quiet_rate(f, design, use_trips = "complete")
    all_trips <- quiet_rate(f, design, use_trips = "all")

    expect_equal(complete$estimates$n, c(12L, 12L), info = f)
    expect_equal(all_trips$estimates$n, c(24L, 24L), info = f)
    expect_false(isTRUE(all.equal(
      complete$estimates$estimate,
      all_trips$estimates$estimate
    )), info = f)
  }
})

test_that("each section's rate uses that section's complete trips alone (GH #263)", {
  # What makes the filtered numbers right rather than merely smaller. Removing
  # the sections slot and filtering to one section's complete interviews has to
  # reproduce that section's row exactly -- estimate, SE and n. A path that
  # filtered lake-wide but then leaked the unfiltered interviews into the
  # section loop would pass the n check above and fail here.
  design <- mixed_status_sectioned_design()
  sections <- design$sections[[design$section_col]]

  for (f in use_trips_estimators) {
    sectioned <- quiet_rate(f, design)

    for (i in seq_along(sections)) {
      sec <- sections[[i]]
      iv <- design$interviews
      one_section <- iv[iv[[design$section_col]] == sec, ]

      reference_design <- design
      reference_design$sections <- NULL
      reference_design$interviews <- one_section
      reference_design$interview_survey <- build_interview_survey(
        one_section,
        strata = stats::reformulate(design$strata_cols)
      )
      reference <- quiet_rate(f, reference_design)

      label <- paste(f, sec)
      expect_equal(sectioned$estimates$estimate[[i]], reference$estimates$estimate, info = label)
      expect_equal(sectioned$estimates$se[[i]], reference$estimates$se, info = label)
      expect_equal(sectioned$estimates$n[[i]], reference$estimates$n, info = label)
    }
  }
})

test_that("an unrecognised use_trips is refused on a sectioned design (GH #263)", {
  # The validation lived below the section dispatch, so on a sectioned design a
  # typo fell through and silently produced the complete-trip answer.
  design <- mixed_status_sectioned_design()

  for (f in c("estimate_harvest_rate", "estimate_release_rate")) {
    expect_error(
      suppressWarnings(suppressMessages(get(f)(design, use_trips = "nonsense"))),
      "Invalid use_trips value",
      info = f
    )
  }
})

test_that("the sectioned path announces which trips it used (GH #263)", {
  # Silence was part of the defect: the unsectioned call reported the filtering
  # and the sectioned call reported nothing at all. Counted positively -- an
  # expectation that merely tolerates zero messages would have passed against
  # the unfixed code.
  design <- mixed_status_sectioned_design()

  for (f in c("estimate_harvest_rate", "estimate_release_rate")) {
    messages <- capture_messages(
      suppressWarnings(get(f)(design))
    )
    filtering <- grep("Filtering to complete trips", messages, value = TRUE)

    expect_length(filtering, 1L)
    expect_match(filtering, "n=24", fixed = TRUE, info = f)

    all_messages <- capture_messages(
      suppressWarnings(get(f)(design, use_trips = "all"))
    )
    expect_length(grep("Using all interviews", all_messages, value = TRUE), 1L)
  }
})
