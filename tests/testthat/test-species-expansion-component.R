# The party-size component on species totals (GH #259) ----
#
# A species total's standard error carries the party-size expansion term: the
# effort it multiplies was expanded from boat counts by an estimated party size,
# and that estimate has a standard error. The component reported alongside `se`
# is how a reader decomposes it.
#
# `compute_stratum_product_sum()` returned that component, and the species
# estimators then dropped it: their ungrouped-product branch returns a base
# data.frame, and the column reorder that moves the species column to the front
# goes through `[.data.frame`, which keeps only names, row.names and class. The
# result reported `se_expansion = NULL` while the party-size term was inside the
# number -- absence and unknown made to look alike, which is the one thing the
# component contract forbids. The grouped branch returns a tibble, whose `[`
# preserves attributes, which is why this was invisible for `by = c(species, x)`.

spx_calendar <- function() {
  data.frame(
    date = as.Date("2024-06-01") + 0:5,
    day_type = rep(c("weekday", "weekend"), 3),
    stringsAsFactors = FALSE
  )
}

spx_raw <- function() {
  data.frame(
    date = as.Date("2024-06-01") + 0:5,
    day_type = rep(c("weekday", "weekend"), 3),
    angler_boats = c(6, 2, 4, 8, 5, 5),
    stringsAsFactors = FALSE
  )
}

spx_interviews <- function() {
  data.frame(
    date = rep(as.Date("2024-06-01") + 0:5, each = 4),
    day_type = rep(rep(c("weekday", "weekend"), 3), each = 4),
    catch_total = c(3, 4, 2, 5, 6, 4, 2, 3, 3, 6, 7, 5, 4, 4, 5, 3, 2, 4, 3, 5, 4, 6, 3, 4),
    harvest_total = c(2, 2, 1, 3, 4, 2, 1, 2, 2, 4, 5, 3, 2, 3, 3, 2, 1, 2, 2, 3, 3, 4, 2, 2),
    hours_fished = 2,
    status = "complete",
    interview_id = seq_len(24),
    stringsAsFactors = FALSE
  )
}

# One species accounting for every fish, so the species row and the ungrouped
# total are the same estimand and their components must agree exactly. A test
# that only asserted "not NULL" would pass on any number the code happened to
# attach; this one fails unless the value reported is the one that went into
# `se`.
spx_catch <- function() {
  iv <- spx_interviews()
  data.frame(
    interview_id = rep(iv$interview_id, 2),
    species = "walleye",
    count = c(iv$harvest_total, iv$catch_total - iv$harvest_total),
    catch_type = rep(c("harvested", "released"), each = nrow(iv)),
    stringsAsFactors = FALSE
  )
}

spx_counts <- function(party_size_se = 0.4) {
  if (is.null(party_size_se)) {
    derive_angler_count(spx_raw(), boat_count = angler_boats, party_size = 2.5)
  } else {
    derive_angler_count(
      spx_raw(),
      boat_count = angler_boats,
      party_size = 2.5,
      party_size_se = party_size_se
    )
  }
}

spx_design <- function(party_size_se = 0.4) {
  design <- creel_design(spx_calendar(), date = date, strata = day_type)
  design <- suppressWarnings(add_counts(design, spx_counts(party_size_se), count_col = "angler_count"))
  design <- suppressMessages(suppressWarnings(add_interviews(
    design,
    spx_interviews(),
    catch = catch_total,
    effort = hours_fished,
    harvest = harvest_total,
    trip_status = status
  )))
  suppressWarnings(add_catch(
    design,
    spx_catch(),
    catch_uid = interview_id,
    interview_uid = interview_id,
    species = species,
    count = count,
    catch_type = catch_type
  ))
}

test_that("a species total reports the party-size component it carries (GH #259)", {
  # The defect: `se` moved with party_size_se while the component came back
  # NULL, so a reader decomposing the standard error was told the party-size
  # contribution was absent when it was inside the number.
  design <- spx_design()
  species_total <- suppressWarnings(estimate_total_catch(design, by = species))

  expect_false(is.null(species_total$se_expansion))
  expect_length(species_total$se_expansion, nrow(species_total$estimates))
  expect_true(all(is.finite(species_total$se_expansion)))
})

test_that("the species component equals the ungrouped one for a single species (GH #259)", {
  # Every fish in the fixture is a walleye, so `by = species` and the ungrouped
  # total estimate the same quantity. Pins the value rather than its presence:
  # attaching some other vector of the right length would satisfy the test
  # above and fail this one.
  design <- spx_design()
  ungrouped <- suppressWarnings(estimate_total_catch(design))
  species_total <- suppressWarnings(estimate_total_catch(design, by = species))

  expect_equal(species_total$estimates$estimate, ungrouped$estimates$estimate)
  expect_equal(species_total$se_expansion, ungrouped$se_expansion)
})

test_that("the component is absent exactly when the standard error does not carry it (GH #259)", {
  # The contract the defect broke: NULL means the term is not in `se`, not that
  # nobody looked. Without a party-size standard error there is nothing to
  # report and `se` is smaller; with one, both change together.
  without <- suppressWarnings(estimate_total_catch(spx_design(NULL), by = species))
  with_se <- suppressWarnings(estimate_total_catch(spx_design(0.4), by = species))

  expect_null(without$se_expansion)
  expect_false(is.null(with_se$se_expansion))
  expect_gt(with_se$estimates$se, without$estimates$se)
})

test_that("species harvest and release totals report their component too (GH #259)", {
  # The three totals are near-twins and the dropped reorder was in all three,
  # so a fix applied to one only would leave two estimators reporting absence.
  design <- spx_design()

  harvest_species <- suppressWarnings(estimate_total_harvest(design, by = species))
  harvest_total <- suppressWarnings(estimate_total_harvest(design))
  expect_equal(harvest_species$se_expansion, harvest_total$se_expansion)

  release_species <- suppressWarnings(estimate_total_release(design, by = species))
  release_total <- suppressWarnings(estimate_total_release(design))
  expect_equal(release_species$se_expansion, release_total$se_expansion)
})

test_that("grouping alongside species still reports one component per row (GH #259)", {
  # This branch was never broken -- it returns a tibble, whose `[` preserves
  # attributes. It is asserted so a fix that re-routed the reorder cannot quietly
  # change the path that already worked.
  design <- spx_design()
  grouped <- suppressWarnings(estimate_total_catch(design, by = c(species, day_type)))

  expect_length(grouped$se_expansion, nrow(grouped$estimates))
  expect_true(all(is.finite(grouped$se_expansion)))
})

# Sectioned species totals -------------------------------------------------
#
# The sections wrapper fills its per-section component only on the ungrouped
# branch, so a sectioned `by = species` result reported NULL for a second
# reason, downstream of the one above. Its rows are per species within section,
# which is why the component travels as a column through bind_rows() rather than
# as one scalar per section.

spx_sec_calendar <- function() {
  data.frame(
    date = as.Date("2024-06-01") + 0:7,
    day_type = rep(c("weekday", "weekday", "weekend", "weekend"), 2),
    stringsAsFactors = FALSE
  )
}

spx_sec_raw <- function() {
  data.frame(
    date = as.Date("2024-06-01") + 0:7,
    day_type = rep(c("weekday", "weekday", "weekend", "weekend"), 2),
    section = rep(c("North", "South"), 4),
    angler_boats = c(6, 4, 2, 3, 4, 5, 8, 6),
    stringsAsFactors = FALSE
  )
}

spx_sec_interviews <- function() {
  raw <- spx_sec_raw()
  data.frame(
    date = rep(raw$date, each = 4),
    day_type = rep(raw$day_type, each = 4),
    section = rep(raw$section, each = 4),
    catch_total = rep(c(3, 4, 2, 5), 8),
    harvest_total = rep(c(2, 2, 1, 3), 8),
    hours_fished = 2,
    status = "complete",
    interview_id = seq_len(32),
    stringsAsFactors = FALSE
  )
}

spx_sec_catch <- function() {
  iv <- spx_sec_interviews()
  data.frame(
    interview_id = rep(iv$interview_id, 2),
    species = "walleye",
    count = c(iv$harvest_total, iv$catch_total - iv$harvest_total),
    catch_type = rep(c("harvested", "released"), each = nrow(iv)),
    stringsAsFactors = FALSE
  )
}

spx_sec_design <- function(registered = c("North", "South"), party_size_se = 0.1) {
  design <- creel_design(spx_sec_calendar(), date = date, strata = day_type)
  design <- suppressMessages(suppressWarnings(add_sections(
    design,
    data.frame(section = registered, stringsAsFactors = FALSE),
    section_col = section
  )))
  counts <- if (is.null(party_size_se)) {
    derive_angler_count(spx_sec_raw(), boat_count = angler_boats, party_size = 2.5)
  } else {
    derive_angler_count(
      spx_sec_raw(),
      boat_count = angler_boats,
      party_size = 2.5,
      party_size_se = party_size_se
    )
  }
  design <- suppressWarnings(add_counts(design, counts, count_col = "angler_count"))
  design <- suppressMessages(suppressWarnings(add_interviews(
    design,
    spx_sec_interviews(),
    catch = catch_total,
    effort = hours_fished,
    harvest = harvest_total,
    trip_status = status
  )))
  suppressWarnings(add_catch(
    design,
    spx_sec_catch(),
    catch_uid = interview_id,
    interview_uid = interview_id,
    species = species,
    count = count,
    catch_type = catch_type
  ))
}

test_that("a sectioned species total reports each section's component (GH #259)", {
  # One species again, so each section's species row is that section's own
  # total: the components must match the ungrouped sectioned result row for row,
  # excluding its lake row, which a grouped result does not have.
  design <- spx_sec_design()
  ungrouped <- suppressWarnings(estimate_total_catch(design))
  species_total <- suppressWarnings(estimate_total_catch(design, by = species))

  section_rows <- ungrouped$estimates$section != ".lake_total"
  expect_equal(species_total$se_expansion, ungrouped$se_expansion[section_rows])
  expect_equal(species_total$estimates$estimate, ungrouped$estimates$estimate[section_rows])
})

test_that("an absent section keeps the sectioned component aligned to its rows (GH #259)", {
  # The placeholder row a missing section contributes has no component. It has
  # to stay in the vector as NA rather than shorten it, or every component after
  # it describes the wrong section.
  design <- suppressWarnings(spx_sec_design(registered = c("North", "South", "East")))
  species_total <- suppressWarnings(
    estimate_total_catch(design, by = species, missing_sections = "warn")
  )

  expect_length(species_total$se_expansion, nrow(species_total$estimates))
  absent <- species_total$estimates$section == "East"
  expect_true(is.na(species_total$se_expansion[absent]))
  expect_true(all(is.finite(species_total$se_expansion[!absent])))
})

test_that("the sectioned carrier column does not reach the returned estimates (GH #259)", {
  # The component rides to the aggregation as a column so bind_rows() keeps it
  # row-aligned. It is an internal carrier: leaking it would add a column to a
  # documented output shape and put the same number in two places.
  design <- spx_sec_design()
  species_total <- suppressWarnings(estimate_total_catch(design, by = species))

  expect_false(".se_expansion" %in% names(species_total$estimates))
})

test_that("a sectioned species total reports nothing when there is no party-size SE (GH #259)", {
  # Same absence rule as the unsectioned case: no estimate behind the expansion
  # means no component, not a zero.
  design <- spx_sec_design(party_size_se = NULL)
  species_total <- suppressWarnings(estimate_total_catch(design, by = species))

  expect_null(species_total$se_expansion)
  expect_false(".se_expansion" %in% names(species_total$estimates))
})
