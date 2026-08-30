# Species totals on sectioned designs (GH #255) ----
#
# Effort on a sectioned design is estimated per section, from that section's own
# counts. A species total is catch apportioned against *whole* effort rather
# than a split of it, so it can be formed inside each section -- what it cannot
# do is borrow effort estimated by pooling the sections together.
#
# Before this, `by = <species>` never reached species apportionment on a
# sectioned design, because the public estimators returned into the section path
# before resolving species. `estimate_total_catch()` failed loudly, with
# tidyselect's "Column `species` doesn't exist" -- species lives in the catch
# table, so it is in neither the counts nor the interviews. Its two near-twins
# resolved species *first* and so never reached the section path at all: they
# returned a lake-wide species total for a design that has sections, with no
# section column and nothing to say the sectioning had been ignored. That is the
# more dangerous of the two, because it is a believable number.

#' Two-section design with species catch, harvest and release rows
make_sectioned_species_design <- function(n_interviews = 36L) {
  cal <- data.frame(
    date = seq.Date(as.Date("2024-06-01"), by = "day", length.out = 8L),
    day_type = rep_len(c("weekday", "weekend"), 8L),
    stringsAsFactors = FALSE
  )
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter

  sections <- c("North", "South")
  counts <- data.frame(
    date = rep(cal$date, each = 2L),
    day_type = rep(cal$day_type, each = 2L),
    section = rep(sections, times = 8L),
    effort_hours = c(15, 12, 23, 19, 18, 14, 21, 17, 45, 38, 52, 44, 48, 40, 51, 43),
    period_hours = rep(12, 16L),
    stringsAsFactors = FALSE
  )
  design <- suppressMessages(suppressWarnings( # nolint: object_usage_linter
    add_counts(design, counts, period_length_col = period_hours)
  ))
  design <- suppressMessages(suppressWarnings(add_sections( # nolint: object_usage_linter
    design,
    data.frame(section = sections, stringsAsFactors = FALSE),
    section_col = section
  )))

  catch_data <- build_species_catch_for_tests(
    interview_ids = seq_len(n_interviews),
    n_species = 2L,
    include_harvest = TRUE
  )
  interviews <- build_trip_interviews_for_tests(
    calendar = cal,
    n_interviews = n_interviews,
    catch_total = catch_data$interview_catch_total,
    catch_kept = catch_data$interview_catch_kept
  )
  interviews$section <- rep_len(sections, n_interviews)

  design <- suppressMessages(suppressWarnings(add_interviews(
    design,
    interviews,
    catch = catch_total,
    effort = hours_fished,
    harvest = catch_kept,
    n_anglers = n_anglers,
    trip_status = trip_status,
    trip_duration = trip_duration,
    n_counted = n_counted,
    n_interviewed = n_interviewed
  )))

  suppressMessages(suppressWarnings(add_catch(
    design,
    add_released_rows_for_tests(catch_data$catch_df),
    catch_uid = interview_id,
    interview_uid = interview_id,
    species = species,
    count = count,
    catch_type = catch_type
  )))
}

test_that("SPS-01: all three totals return one row per section per species", {
  set.seed(255)
  design <- make_sectioned_species_design()

  for (fn in list(estimate_total_catch, estimate_total_harvest, estimate_total_release)) {
    est <- suppressMessages(suppressWarnings(fn(design, by = species)))$estimates # nolint: object_usage_linter
    expect_true(all(c("section", "species") %in% names(est)))
    # 2 sections x 2 species. A pooled answer would be 2 rows and carry no
    # section column at all.
    expect_identical(nrow(est), 4L)
    expect_setequal(unique(est$section), c("North", "South"))
    expect_setequal(unique(est$species), unique(design$catch$species))
  }
})

test_that("SPS-02: each section's species total is built from that section's own interviews", {
  set.seed(255)
  design <- make_sectioned_species_design()
  est <- suppressMessages(suppressWarnings( # nolint: object_usage_linter
    estimate_total_catch(design, by = species)
  ))$estimates

  # The per-section design carries the whole catch table; only the join onto the
  # section's interviews keeps it section-correct. If the full table leaked in,
  # n would be the design-wide interview count instead of the section's.
  per_section <- table(design$interviews$section)
  for (sec in names(per_section)) {
    expect_true(all(est$n[est$section == sec] == per_section[[sec]]))
  }
})

test_that("SPS-03: a species total does not acquire a lake row by summing across species", {
  set.seed(255)
  design <- make_sectioned_species_design()
  est <- suppressMessages(suppressWarnings( # nolint: object_usage_linter
    estimate_total_catch(design, by = species)
  ))$estimates

  # Species leaves by_vars NULL, so a gate keyed on by_vars alone would treat
  # this as the ungrouped path and add a .lake_total that summed bass and
  # panfish together -- a number for no estimand at all. Grouping, not the
  # absence of by_vars, is what decides.
  expect_false(".lake_total" %in% est$section)
  # The share belongs to the ungrouped path; it is not merely NA here, it is
  # absent, exactly as it is for any other grouped sectioned result.
  expect_false("prop_of_lake_total" %in% names(est))
})

test_that("SPS-04: the ungrouped sectioned total keeps its lake row and share", {
  set.seed(255)
  design <- make_sectioned_species_design()
  est <- suppressMessages(suppressWarnings(estimate_total_catch(design)))$estimates # nolint: object_usage_linter

  # The gate was retargeted, so the path it used to guard has to be pinned too.
  expect_true(".lake_total" %in% est$section)
  lake <- est[est$section == ".lake_total", ]
  expect_equal(lake$estimate, sum(est$estimate[est$section != ".lake_total"]))
  expect_false(is.na(lake$se))
  expect_equal(lake$prop_of_lake_total, 1)
})

test_that("SPS-05: species rides on whole effort, a companion grouping still splits it", {
  set.seed(255)
  design <- make_sectioned_species_design()

  # day_type is in the counts, so it can group effort alongside species.
  est <- suppressMessages(suppressWarnings( # nolint: object_usage_linter
    estimate_total_catch(design, by = c(species, day_type))
  ))$estimates
  expect_true(all(c("section", "species", "day_type") %in% names(est)))

  # An interview-only companion cannot: effort still has to be split by it, and
  # the counts never classified it. Same refusal as the unsectioned path, not a
  # second wording.
  design$interviews$target <- rep_len(c("bass", "bluegill"), nrow(design$interviews))
  expect_error(
    estimate_total_catch(design, by = c(species, target)), # nolint: object_usage_linter
    class = "creel_error_count_unobservable_by"
  )
})
