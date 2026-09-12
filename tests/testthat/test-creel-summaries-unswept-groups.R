# The two summary functions GH #333's sweep could not reach — GH #337.
#
# #333 fixed six functions that dropped records whose grouping value was NA.
# These two use the same `stats::aggregate(by = )` idiom but were left alone,
# because no fixture built from the shipped data reached either one. That is the
# work here: `summarize_length_freq()`'s `by` selects columns of the LENGTHS
# frame rather than the interviews, and `example_lengths` carries binned release
# rows that `add_lengths(release_format = "individual")` refuses.

# --- fixtures -----------------------------------------------------------------

# Release rows in example_lengths are bin labels ("400-450") with a count, so
# the frame only attaches with release_format = "binned". A binned row stands
# for several fish, which is why the weights below are not row counts.
usg_length_design <- function(blank_species = FALSE) {
  data(example_calendar, package = "tidycreel")
  data(example_interviews, package = "tidycreel")
  data(example_catch, package = "tidycreel")
  data(example_lengths, package = "tidycreel")
  lg <- example_lengths
  if (blank_species) {
    lg$species[seq_len(nrow(lg)) %% 3 == 0] <- NA
  }
  suppressWarnings(suppressMessages({
    d <- creel_design(example_calendar, date = date, strata = day_type)
    d <- add_interviews(d, example_interviews,
      catch = catch_total, effort = hours_fished, harvest = catch_kept,
      trip_status = trip_status, angler_type = angler_type,
      species_sought = species_sought
    )
    d <- add_catch(d, example_catch,
      catch_uid = interview_id, interview_uid = interview_id,
      species = species, count = count, catch_type = catch_type
    )
    add_lengths(d, lg,
      length_uid = interview_id, interview_uid = interview_id,
      species = species, length = length, length_type = length_type,
      count = count, release_format = "binned"
    )
  }))
}

usg_boat_schema <- function() {
  tidycreel::creel_schema(
    survey_type      = "instantaneous",
    angler_boats_col = "angler_boats",
    non_ang_boats_col = "non_ang_boats"
  )
}

usg_boat_design <- function(mod = NULL) {
  data(example_calendar, package = "tidycreel")
  data(example_interviews, package = "tidycreel")
  dts <- sort(unique(example_calendar$date))[1:12]
  cts <- data.frame(
    date = dts,
    day_type = example_calendar$day_type[match(dts, example_calendar$date)],
    angler_boats = c(3, 4, 2, 5, 6, 1, 4, 3, 2, 5, 4, 3),
    non_ang_boats = c(1, 2, 1, 0, 2, 1, 1, 2, 0, 1, 3, 1),
    stringsAsFactors = FALSE
  )
  if (!is.null(mod)) cts <- mod(cts)
  suppressWarnings(suppressMessages({
    d <- creel_design(example_calendar, date = date, strata = day_type)
    d <- add_interviews(d, example_interviews,
      catch = catch_total, effort = hours_fished, harvest = catch_kept,
      trip_status = trip_status
    )
    add_counts(d, cts, count_col = "angler_boats")
  }))
}

# --- summarize_length_freq(by=) — LFQ-01..05 ----------------------------------

test_that("summarize_length_freq(by=) keeps every fish (LFQ-01)", {
  # The invariant that encodes the intent: a distribution of N fish describes N
  # fish. Measured before the fix, blanking species on 6 of 20 length rows took
  # the total from 37 to 26.
  baseline <- summarize_length_freq(usg_length_design(), type = "catch", by = "species")
  blanked <- summarize_length_freq(
    usg_length_design(blank_species = TRUE),
    type = "catch", by = "species"
  )
  expect_equal(sum(baseline$N), 37)
  expect_equal(sum(blanked$N), sum(baseline$N))
  expect_true("Unknown" %in% as.character(blanked$species))
})

test_that("the lost weight is fish, not rows (LFQ-02)", {
  # 6 blanked ROWS cost 11 FISH, because a binned release row stands for several.
  # Asserting a row count would understate the defect and would not fail if the
  # weights were ever dropped while the rows survived.
  blanked <- summarize_length_freq(
    usg_length_design(blank_species = TRUE),
    type = "catch", by = "species"
  )
  unknown <- blanked[as.character(blanked$species) == "Unknown", ]
  expect_gt(nrow(unknown), 0L)
  expect_equal(sum(unknown$N), 11)
})

test_that("the unrecorded group sorts last (LFQ-03)", {
  # Discriminating: "Unknown" sorts before "walleye", so plain alphabetical
  # order would put it mid-table.
  blanked <- summarize_length_freq(
    usg_length_design(blank_species = TRUE),
    type = "catch", by = "species"
  )
  species <- as.character(blanked$species)
  expect_true("Unknown" %in% species)
  expect_equal(species[length(species)], "Unknown")
})

test_that("a design with every species recorded is unchanged (LFQ-04)", {
  # Pins the numbers the fix must not move.
  result <- summarize_length_freq(usg_length_design(), type = "catch", by = "species")
  expect_false(any(as.character(result$species) == "Unknown"))
  expect_equal(sum(result$N), 37)
  expect_equal(sort(unique(as.character(result$species))), c("bass", "panfish", "walleye"))
})

test_that("the ungrouped total was never affected (LFQ-05)", {
  # The control that explains why this stayed invisible: without `by`, nothing
  # is grouped and nothing was ever dropped. It passes on main too.
  baseline <- summarize_length_freq(usg_length_design(), type = "catch")
  blanked <- summarize_length_freq(usg_length_design(blank_species = TRUE), type = "catch")
  expect_equal(sum(blanked$N), sum(baseline$N))
})

# --- summarize_boat_composition() — BC-01..05 ---------------------------------

test_that("an unrecorded boat count is counted, not dropped twice over (BC-01)", {
  # `keep <- (ab + nb) > 0` is NA when either count is NA, and an NA subscript
  # selects a PHANTOM all-NA row rather than dropping one (GH #324's shape). The
  # event survived the subset with an NA month and day type, and aggregate()
  # then dropped it for having an NA grouping value. Two mechanisms chained,
  # neither visible: the event total went 12 -> 9 and a reported share moved
  # from 73.4% to 76.7%.
  result <- summarize_boat_composition(
    usg_boat_design(function(x) {
      x$angler_boats[c(1, 6, 9)] <- NA
      x
    }),
    schema = usg_boat_schema()
  )
  expect_equal(sum(result$n_unknown_boats), 3L)
  expect_equal(sum(result$n_events) + sum(result$n_unknown_boats) + sum(result$n_zero_boats), 12L)
})

test_that("a zero-boat event is counted rather than silently excluded (BC-02)", {
  # Excluding it is right -- no boats means no angler-boat share to take -- but
  # it used to leave no trace that the count event had happened at all.
  result <- summarize_boat_composition(
    usg_boat_design(function(x) {
      x$angler_boats[c(1, 6, 9)] <- 0
      x$non_ang_boats[c(1, 6, 9)] <- 0
      x
    }),
    schema = usg_boat_schema()
  )
  expect_equal(sum(result$n_zero_boats), 3L)
  expect_equal(sum(result$n_unknown_boats), 0L)
  expect_equal(sum(result$n_events) + sum(result$n_zero_boats), 12L)
})

test_that("a group whose every event is excluded keeps its row (BC-03)", {
  # It would otherwise vanish from the table entirely -- the failure GH #333
  # fixed, reached here through a different door.
  result <- summarize_boat_composition(
    usg_boat_design(function(x) {
      x$angler_boats[x$day_type == "weekend"] <- NA
      x
    }),
    schema = usg_boat_schema()
  )
  weekend <- result[result$day_type == "weekend", ]
  expect_equal(nrow(weekend), 1L)
  expect_equal(weekend$n_events, 0L)
  expect_gt(weekend$n_unknown_boats, 0L)
  expect_true(is.na(weekend$pct_angler_boats))
})

test_that("a design with every boat count recorded is unchanged (BC-04)", {
  # Pins the numbers the fix must not move.
  result <- summarize_boat_composition(usg_boat_design(), schema = usg_boat_schema())
  expect_equal(sum(result$n_events), 12L)
  expect_equal(sum(result$n_unknown_boats), 0L)
  expect_equal(sum(result$n_zero_boats), 0L)
  expect_equal(result$pct_angler_boats, c(73.4, 75.4))
})

test_that("an unrecorded day_type never reaches this function (BC-05)", {
  # Records a NEGATIVE finding so it is not re-investigated. GH #337 assumed the
  # grouping columns could be NA here; they cannot. `add_counts()` refuses a
  # counts frame with a missing stratum, so the only way an NA grouping value
  # ever appeared was the phantom-subscript path BC-01 covers.
  expect_error(
    usg_boat_design(function(x) {
      x$day_type[c(2, 5)] <- NA
      x
    }),
    "[Ss]trata column"
  )
})
