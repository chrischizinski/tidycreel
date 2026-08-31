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

# `make_sectioned_species_design()` lives in helper-generators.R: the sectioned
# species *rate* tests (GH #257) estimate over the same design, and one fixture
# is what makes the two files' numbers comparable.
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

test_that("SPS-06: moving the section dispatch did not strand the checks above it", {
  set.seed(255)
  design <- make_sectioned_species_design()

  # Dispatching to sections earlier (so species could be resolved inside it)
  # moved the return ahead of everything below it. Anything a sectioned design
  # is still supposed to hear has to sit above that return, and this is the test
  # that says so -- the ordering is otherwise invisible.
  no_harvest_col <- design
  no_harvest_col$harvest_col <- NULL
  expect_error(
    suppressMessages(suppressWarnings(estimate_total_harvest(no_harvest_col))), # nolint: object_usage_linter
    "No harvest column available"
  )
})

test_that("SPS-07: the pooled-domain warning still reaches sectioned totals", {
  set.seed(255)
  design <- make_sectioned_species_design()

  fired <- function(expr) {
    seen <- FALSE
    withCallingHandlers(
      suppressMessages(expr),
      creel_warning_pooled_domain_mix = function(cnd) {
        seen <<- TRUE
        invokeRestart("muffleWarning")
      },
      warning = function(cnd) invokeRestart("muffleWarning")
    )
    seen
  }

  # #242's warning is raised before the section dispatch precisely so both paths
  # hear it. The catch and harvest screens read the interview catch and harvest
  # columns, so a domain difference there is what they see.
  d_catch <- design
  d_catch$interviews$sought_sps07 <- rep_len(c("bass", "bluegill"), nrow(d_catch$interviews))
  bass <- d_catch$interviews$sought_sps07 == "bass"
  d_catch$interviews$catch_total[bass] <- d_catch$interviews$catch_total[bass] * 4L
  d_catch$interviews$catch_kept[bass] <- d_catch$interviews$catch_kept[bass] * 4L
  expect_true(fired(estimate_total_catch(d_catch))) # nolint: object_usage_linter

  d_harvest <- d_catch
  names(d_harvest$interviews)[names(d_harvest$interviews) == "sought_sps07"] <- "sought_sps07h"
  expect_true(fired(estimate_total_harvest(d_harvest))) # nolint: object_usage_linter

  # Release screens .release_count, so its domain difference has to be in the
  # released rows -- scaling the interview catch column would leave it silent,
  # correctly.
  d_release <- design
  d_release$interviews$sought_sps07r <- rep_len(c("bass", "bluegill"), nrow(d_release$interviews))
  uid <- d_release$catch_interview_uid_col
  domain_of <- stats::setNames(d_release$interviews$sought_sps07r, d_release$interviews$interview_id)
  catch_df <- d_release$catch
  is_released <- catch_df[[d_release$catch_type_col]] == "released"
  row_domain <- domain_of[as.character(catch_df[[uid]])]
  catch_df[[d_release$catch_count_col]][is_released & row_domain == "bass"] <- 9L
  catch_df[[d_release$catch_count_col]][is_released & row_domain == "bluegill"] <- 1L
  d_release$catch <- catch_df
  expect_true(fired(estimate_total_release(d_release))) # nolint: object_usage_linter
})

test_that("SPS-08: a missing section does not smuggle lake-share columns into a grouped result", {
  set.seed(255)
  design <- make_sectioned_species_design()
  # A registered section with no count or interview data behind it.
  design$sections <- rbind(design$sections, data.frame(section = "East", stringsAsFactors = FALSE))

  # The placeholder row for an absent section is built whatever the grouping.
  # Carrying the share columns there put them into a grouped result through
  # bind_rows(), which is the one thing SPS-03 says a grouped result never has --
  # so the contract held only as long as every section had data.
  species_est <- suppressMessages(suppressWarnings( # nolint: object_usage_linter
    estimate_total_catch(design, by = species, missing_sections = "warn")
  ))$estimates
  expect_false("prop_of_lake_total" %in% names(species_est))
  expect_false("se_prop_of_lake_total" %in% names(species_est))

  # Same for an ordinary grouping: this predates the species work.
  grouped_est <- suppressMessages(suppressWarnings( # nolint: object_usage_linter
    estimate_total_catch(design, by = day_type, missing_sections = "warn")
  ))$estimates
  expect_false("prop_of_lake_total" %in% names(grouped_est))

  # The ungrouped path must keep them, including on the placeholder row, or the
  # fix would have removed a column the lake-share path is supposed to report.
  ungrouped_est <- suppressMessages(suppressWarnings( # nolint: object_usage_linter
    estimate_total_catch(design, missing_sections = "warn")
  ))$estimates
  expect_true(all(c("prop_of_lake_total", "se_prop_of_lake_total") %in% names(ungrouped_est)))
  absent <- ungrouped_est[ungrouped_est$section == "East", ]
  expect_identical(nrow(absent), 1L)
  expect_true(is.na(absent$prop_of_lake_total))
  expect_false(absent$data_available)
})

test_that("SPS-09: naming the section column in by= is refused, not left to collide", {
  set.seed(255)
  design <- make_sectioned_species_design()

  # A sectioned estimate is one row per section by construction, so `section` in
  # by= asks for a split that has already happened. Left alone it reached
  # tibble::add_column() and failed with "Column `section` must not be
  # duplicated" -- a message about the implementation, not about the request.
  expect_error(
    estimate_total_catch(design, by = section), # nolint: object_usage_linter
    class = "creel_error_section_in_by"
  )
  expect_error(
    estimate_total_catch(design, by = c(species, section)), # nolint: object_usage_linter
    class = "creel_error_section_in_by"
  )

  err <- expect_error(estimate_total_catch(design, by = section)) # nolint: object_usage_linter
  expect_match(cli::ansi_strip(conditionMessage(err)), "already how the result is split")

  # The twins are near-identical here, so the refusal belongs to all three.
  for (fn in list(estimate_total_harvest, estimate_total_release)) {
    expect_error(fn(design, by = section), class = "creel_error_section_in_by") # nolint: object_usage_linter
  }

  # Grouping within sections by something else is still fine.
  ok <- suppressMessages(suppressWarnings( # nolint: object_usage_linter
    estimate_total_catch(design, by = day_type)
  ))$estimates
  expect_true(all(c("section", "day_type") %in% names(ok)))
})
