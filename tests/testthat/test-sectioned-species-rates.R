# Species rates on sectioned designs (GH #257) ----
#
# The rates counterpart to GH #255. On a sectioned design the public rate
# estimators return into the section path before their own species dispatch
# runs, so the section helper has to recognise a species selector itself.
# `estimate_catch_rate()`'s did; the other two resolved `by=` against the
# interviews alone and failed with tidyselect's "Column `species` doesn't
# exist" -- species lives in the catch table, so it is in neither the
# interviews nor the counts.
#
# This is the safe failure, and the reason it is a smaller change than #255
# was: two of the three *totals* silently returned a pooled lake-wide number
# instead. It is also why no count-observability refusal belongs here. A rate
# is estimated from interviews alone, so it may be grouped by things a total
# may not (GH #241): nothing has to be split by the counts, no effort is
# apportioned, and there is no lake row or share to form.

sectioned_rate <- function(f, design, ...) {
  suppressWarnings(suppressMessages(get(f)(design, ...)))
}

rate_estimators <- c("estimate_catch_rate", "estimate_harvest_rate", "estimate_release_rate")

test_that("every sectioned rate can group by species (GH #257)", {
  # The defect was an error, not a wrong number, so presence is the first thing
  # to pin: one row per section per species, with the species column reported.
  design <- make_sectioned_species_design()

  for (f in rate_estimators) {
    result <- sectioned_rate(f, design, by = species)

    expect_true(all(c("section", "species") %in% names(result$estimates)), info = f)
    expect_equal(nrow(result$estimates), 4L, info = f)
    expect_setequal(unique(result$estimates$species), c("bass", "panfish"))
    expect_setequal(unique(result$estimates$section), c("North", "South"))
    expect_true(all(is.finite(result$estimates$estimate)), info = f)
    expect_equal(result$by_vars, c("section", "species"), info = f)
  }
})

test_that("each section's species rate equals the same rate on that section alone (GH #257)", {
  # What makes the numbers right rather than merely present. A section's rate is
  # estimated from that section's own interviews, so removing the sections slot
  # and filtering to one section has to reproduce it exactly -- estimate, SE and
  # n. A species path that leaked another section's interviews into the
  # denominator would still return four plausible rows and fail here.
  design <- make_sectioned_species_design()
  section_col <- design$section_col

  section_only <- function(sec) {
    sub <- design
    sub$sections <- NULL
    rebuild_interview_survey(
      sub,
      design$interviews[design$interviews[[section_col]] == sec, ]
    )
  }

  for (f in rate_estimators) {
    sectioned <- sectioned_rate(f, design, by = species)$estimates

    for (sec in c("North", "South")) {
      reference <- sectioned_rate(f, section_only(sec), by = species)$estimates
      got <- sectioned[sectioned$section == sec, ]

      expect_equal(got$species, reference$species, info = paste(f, sec))
      expect_equal(got$estimate, reference$estimate, info = paste(f, sec))
      expect_equal(got$se, reference$se, info = paste(f, sec))
      expect_equal(got$n, reference$n, info = paste(f, sec))
    }
  }
})

test_that("sectioned species CPUE is sectioned HPUE plus RPUE (GH #257)", {
  # An arithmetic identity across the three estimators, which no single one of
  # them can satisfy on its own: every fish is either harvested or released, and
  # all three rates share the same effort denominator, so the per-species
  # per-section rates must add. Catches a harvest or release path that grouped
  # correctly but built its per-species counts from the wrong catch_type.
  design <- make_sectioned_species_design()

  cpue <- sectioned_rate("estimate_catch_rate", design, by = species)$estimates
  hpue <- sectioned_rate("estimate_harvest_rate", design, by = species)$estimates
  rpue <- sectioned_rate("estimate_release_rate", design, by = species)$estimates

  expect_equal(hpue[c("section", "species")], cpue[c("section", "species")])
  expect_equal(rpue[c("section", "species")], cpue[c("section", "species")])
  expect_equal(hpue$estimate + rpue$estimate, cpue$estimate)
})

test_that("species can be grouped alongside an interview variable (GH #257)", {
  # `by_info$interview_vars` has to reach the species estimator, not be dropped
  # once species is recognised. A larger design because the extra split halves
  # the per-group sample and ratio estimation refuses fewer than ten.
  design <- make_sectioned_species_design(n_interviews = 80L)

  for (f in rate_estimators) {
    result <- sectioned_rate(f, design, by = c(species, day_type))

    expect_true(all(c("section", "species", "day_type") %in% names(result$estimates)), info = f)
    expect_equal(result$by_vars, c("section", "species", "day_type"), info = f)
    expect_equal(nrow(result$estimates), 8L, info = f)
  }
})

test_that("an absent section still yields one placeholder row under species (GH #257)", {
  # The placeholder is built before the species branch is reached, so its
  # grouping columns come from the resolved `by=` rather than from any section's
  # result. Without that it would bind a row missing the species column.
  design <- make_sectioned_species_design()
  design$sections <- rbind(
    design$sections,
    data.frame(section = "East", stringsAsFactors = FALSE)
  )

  for (f in rate_estimators) {
    result <- sectioned_rate(f, design, by = species, missing_sections = "warn")
    absent <- result$estimates[result$estimates$section == "East", ]

    expect_equal(nrow(absent), 1L, info = f)
    expect_true("species" %in% names(result$estimates), info = f)
    expect_true(is.na(absent$species), info = f)
    expect_false(absent$data_available, info = f)
  }
})

test_that("a missing section warns by default and errors on request under species (GH #257)", {
  # The species path must not become a way around the missing-section contract.
  # The default is `warn` -- the placeholder row above is what it produces --
  # and `error` still refuses. Sized past the small-sample threshold so the only
  # warning in flight is the one under test.
  design <- make_sectioned_species_design(n_interviews = 80L)
  design$sections <- rbind(
    design$sections,
    data.frame(section = "East", stringsAsFactors = FALSE)
  )

  for (f in rate_estimators) {
    expect_warning(
      suppressMessages(get(f)(design, by = species)),
      "missing section",
      info = f
    )
    expect_error(
      suppressMessages(get(f)(design, by = species, missing_sections = "error")),
      "missing section",
      info = f
    )
  }
})

# Section column in by= (GH #265) ----
#
# The rates counterpart to SPS-09 in test-sectioned-species-totals.R. The
# refusal and its wording already existed -- `refuse_section_in_by()`, class
# `creel_error_section_in_by` -- and were wired into the three totals only.
# Every rate path fell through to tibble's "Column `section` must not be
# duplicated", a message about the implementation rather than the request.

test_that("naming the section column in by= is refused on every sectioned rate (GH #265)", {
  design <- make_sectioned_species_design()

  # All three, because the sectioned paths are near-twins: fixing only the two
  # #264 touched would re-create the catch-vs-twins asymmetry #257 removed.
  for (f in rate_estimators) {
    expect_error(
      sectioned_rate(f, design, by = section), # nolint: object_usage_linter
      class = "creel_error_section_in_by",
      info = f
    )
    # Alongside species too: the selector resolves through the species
    # prototype, so the section name survives into the same collision.
    expect_error(
      sectioned_rate(f, design, by = c(section, species)), # nolint: object_usage_linter
      class = "creel_error_section_in_by",
      info = f
    )
  }

  # The class is the contract, but the caller reads the message: it has to name
  # the situation, which the tibble error it replaces never did.
  err <- expect_error(sectioned_rate("estimate_catch_rate", design, by = section)) # nolint: object_usage_linter
  msg <- cli::ansi_strip(conditionMessage(err))
  expect_match(msg, "already how the result is split")
  expect_no_match(msg, "must not be duplicated")
})

test_that("the section refusal does not over-refuse other groupings (GH #265)", {
  # The guard has to key on the section column specifically. A refusal that
  # fired for any `by=` on a sectioned design would pass the tests above while
  # removing grouping from sectioned rates entirely.
  design <- make_sectioned_species_design()

  for (f in rate_estimators) {
    est <- sectioned_rate(f, design, by = day_type)$estimates
    expect_true(all(c("section", "day_type") %in% names(est)), info = f)
    expect_gt(nrow(est), 1L)
  }
})
