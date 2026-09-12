# An unrecorded grouping value must be reported, not dropped — GH #333.
#
# `table()` (useNA = "no") and `stats::aggregate(by = )` both drop every record
# whose grouping value is NA. Six summary functions grouped that way, so an
# interview with no recorded angler type, method or sought species left the
# table entirely — out of its own row AND out of the total. The table silently
# stopped accounting for every interview attached to the design, and the groups
# that survived lost their own members.
#
# Nothing in the existing suite could fail on this: every fixture has complete
# grouping columns, which is the one dimension they all share. These tests vary
# exactly that.

# --- Shared fixture -----------------------------------------------------------

# Blanks one interview column on every third row. Blanking is legal: these are
# optional per-interview facts, and an interview with no recorded angler type is
# not a deleted interview.
ug_design <- function(blank_col = NULL) {
  data(example_calendar, package = "tidycreel")
  data(example_interviews, package = "tidycreel")
  data(example_catch, package = "tidycreel")
  iv <- example_interviews
  if (!is.null(blank_col)) {
    iv[[blank_col]][seq_len(nrow(iv)) %% 3 == 0] <- NA
  }
  suppressWarnings(suppressMessages({
    d <- creel_design(example_calendar, date = date, strata = day_type)
    d <- add_interviews(d, iv,
      catch = catch_total, effort = hours_fished, harvest = catch_kept,
      trip_status = trip_status, angler_type = angler_type,
      angler_method = angler_method, species_sought = species_sought
    )
    add_catch(d, example_catch,
      catch_uid = interview_id, interview_uid = interview_id,
      species = species, count = count, catch_type = catch_type
    )
  }))
}

ug_n_interviews <- function() {
  data(example_interviews, package = "tidycreel")
  nrow(example_interviews)
}

# --- the table must account for every interview — UNK-01..03 ------------------

test_that("summarize_by_angler_type() accounts for every interview (UNK-01)", {
  # The invariant that encodes the intent: a summary of N interviews describes
  # N interviews. Asserting the shape of the shipped-data table cannot catch
  # this, because the shipped data has no missing angler type.
  result <- summarize_by_angler_type(ug_design("angler_type"))
  expect_equal(sum(result$N), ug_n_interviews())
  expect_true("Unknown" %in% result$angler_type)
})

test_that("summarize_by_method() accounts for every interview (UNK-02)", {
  result <- summarize_by_method(ug_design("angler_method"))
  expect_equal(sum(result$N), ug_n_interviews())
  expect_true("Unknown" %in% result$method)
})

test_that("summarize_by_species_sought() accounts for every interview (UNK-03)", {
  result <- summarize_by_species_sought(ug_design("species_sought"))
  expect_equal(sum(result$N), ug_n_interviews())
  expect_true("Unknown" %in% result$species)
})

test_that("the unrecorded group sorts last, not alphabetically (UNK-04)", {
  # Discriminating: "Unknown" sorts BEFORE "walleye" in this locale, so a plain
  # alphabetical order would place it mid-table. It belongs at the end, matching
  # summarize_by_zip() and summarize_by_county().
  result <- summarize_by_species_sought(ug_design("species_sought"))
  by_month <- split(as.character(result$species), result$month)
  months_with_unknown <- names(by_month)[vapply(by_month, function(v) "Unknown" %in% v, logical(1))]
  # Asserted, not assumed: without it the loop below has no iterations on code
  # that drops the group entirely, and the test passes having checked nothing.
  expect_gt(length(months_with_unknown), 0L)
  for (m in months_with_unknown) {
    vals <- by_month[[m]]
    expect_equal(vals[length(vals)], "Unknown", info = m)
  }
})

# --- rates: the group that vanished took its rate with it — UNK-05..06 --------

test_that("summarize_cws_rates(by=) keeps every interview and rates the unknown group (UNK-05)", {
  # The worst of the six: the reported RATE moved, not just the count. On this
  # fixture the boat group's mean rate went from 0.393 to 0.762 because the
  # interviews that left were the ones dragging it down. The unknown group's own
  # rate IS determinable -- it comes from those interviews' catch and effort --
  # so it is reported rather than blanked.
  result <- summarize_cws_rates(ug_design("angler_type"), by = "angler_type")
  expect_equal(sum(result$N), ug_n_interviews())
  unknown_row <- result[result$angler_type == "Unknown", ]
  expect_equal(nrow(unknown_row), 1L)
  expect_false(is.na(unknown_row$mean_rate))
})

test_that("summarize_hws_rates(by=) keeps every interview and rates the unknown group (UNK-06)", {
  result <- summarize_hws_rates(ug_design("angler_type"), by = "angler_type")
  expect_equal(sum(result$N), ug_n_interviews())
  expect_false(is.na(result$mean_rate[result$angler_type == "Unknown"]))
})

# --- successful parties: 0 and NA are not the same — UNK-07..10 ---------------

test_that("summarize_successful_parties() accounts for every interview (UNK-07)", {
  result <- summarize_successful_parties(ug_design("species_sought"))
  expect_equal(sum(result$N_total), ug_n_interviews())
  expect_true("Unknown" %in% result$species_sought)
})

test_that("an unrecorded SOUGHT SPECIES makes success undeterminable, not zero (UNK-08)", {
  # A party is successful when it caught some of the species it sought. With no
  # sought species recorded there is nothing to compare the catch against, so
  # success cannot be determined. Reporting 0 successes and 0.0% would say these
  # parties failed, which is a different and unsupported claim.
  result <- summarize_successful_parties(ug_design("species_sought"))
  unknown_rows <- result[result$species_sought == "Unknown", ]
  expect_gt(nrow(unknown_rows), 0L)
  expect_true(all(is.na(unknown_rows$N_successful)))
  expect_true(all(is.na(unknown_rows$percent)))
  # The interviews are still counted: they happened.
  expect_true(all(unknown_rows$N_total > 0L))
})

test_that("an unrecorded ANGLER TYPE leaves success determinable (UNK-09)", {
  # The other half of the same distinction, and the reason UNK-08 cannot simply
  # blank every Unknown row: which species the party sought is known here, so
  # whether it caught that species is knowable. Only the reporting group is
  # unknown. These rows must carry real counts.
  result <- summarize_successful_parties(ug_design("angler_type"))
  unknown_rows <- result[result$angler_type == "Unknown", ]
  expect_gt(nrow(unknown_rows), 0L)
  expect_false(any(is.na(unknown_rows$N_successful)))
  expect_gt(sum(unknown_rows$N_successful), 0L)
  expect_equal(sum(result$N_total), ug_n_interviews())
})

test_that("an all-unrecorded grouping column returns a table instead of crashing (UNK-10)", {
  # `aggregate()` returned a zero-row frame and the function died inside base R
  # with "replacement has 1 row, data has 0" -- an error naming nothing the
  # caller had set.
  data(example_calendar, package = "tidycreel")
  data(example_interviews, package = "tidycreel")
  data(example_catch, package = "tidycreel")
  iv <- example_interviews
  iv$species_sought <- NA_character_
  d <- suppressWarnings(suppressMessages({
    dd <- creel_design(example_calendar, date = date, strata = day_type)
    dd <- add_interviews(dd, iv,
      catch = catch_total, effort = hours_fished, harvest = catch_kept,
      trip_status = trip_status, angler_type = angler_type,
      angler_method = angler_method, species_sought = species_sought
    )
    add_catch(dd, example_catch,
      catch_uid = interview_id, interview_uid = interview_id,
      species = species, count = count, catch_type = catch_type
    )
  }))
  result <- summarize_successful_parties(d)
  expect_s3_class(result, "creel_summary_successful_parties")
  expect_equal(sum(result$N_total), nrow(iv))
  expect_true(all(result$species_sought == "Unknown"))
  expect_true(all(is.na(result$N_successful)))
})

# --- complete data must be untouched — UNK-11 ---------------------------------

test_that("a design with no missing grouping value is unchanged (UNK-11)", {
  # Pins the numbers the fix must not move. Without this, a change that reported
  # everything as Unknown would pass every test above.
  result <- summarize_successful_parties(ug_design())
  expect_equal(nrow(result), 6L)
  expect_false(any(result$species_sought == "Unknown"))
  expect_equal(result$N_total, c(5L, 3L, 5L, 1L, 2L, 6L))
  expect_equal(result$N_successful, c(1L, 1L, 4L, 1L, 0L, 3L))
  expect_equal(result$percent, c(20.0, 33.3, 80.0, 100.0, 0.0, 50.0))

  types <- summarize_by_angler_type(ug_design())
  expect_equal(sum(types$N), ug_n_interviews())
  expect_false(any(types$angler_type == "Unknown"))
})

# --- the label must not be mistaken for data — UNK-12..16 ---------------------
#
# All five come from the pre-push ensemble review, and all five failed before
# the sentinel was introduced.

test_that("a real category named \"Unknown\" keeps its real counts (UNK-12)", {
  # The label is a display string, and a dataset may legitimately contain a
  # category literally called "Unknown" -- a sought species the interviewer
  # recorded as unknown is a real answer, not a missing one. Deciding
  # missingness by comparing against the label blanked those real rows to NA
  # on data with no NA in it at all.
  data(example_calendar, package = "tidycreel")
  data(example_interviews, package = "tidycreel")
  data(example_catch, package = "tidycreel")
  iv <- example_interviews
  iv$species_sought[iv$species_sought == "panfish"] <- "Unknown"
  expect_false(anyNA(iv$species_sought))

  d <- suppressWarnings(suppressMessages({
    dd <- creel_design(example_calendar, date = date, strata = day_type)
    dd <- add_interviews(dd, iv,
      catch = catch_total, effort = hours_fished, harvest = catch_kept,
      trip_status = trip_status, angler_type = angler_type,
      angler_method = angler_method, species_sought = species_sought
    )
    add_catch(dd, example_catch,
      catch_uid = interview_id, interview_uid = interview_id,
      species = species, count = count, catch_type = catch_type
    )
  }))
  result <- summarize_successful_parties(d)
  unknown_rows <- result[result$species_sought == "Unknown", ]
  expect_gt(nrow(unknown_rows), 0L)
  expect_false(any(is.na(unknown_rows$N_successful)))
  expect_equal(sum(result$N_total), nrow(iv))
})

test_that("summarize_cws_rates() sorts the unrecorded group last (UNK-13)", {
  # Discriminating: "Unknown" sorts before "walleye", so plain alphabetical
  # order puts it mid-table. The other four functions place it last and the
  # documentation says so.
  result <- summarize_cws_rates(ug_design("species_sought"), by = "species_sought")
  expect_true("Unknown" %in% result$species_sought)
  expect_equal(as.character(result$species_sought[nrow(result)]), "Unknown")
})

test_that("a complete grouping column keeps its type (UNK-14)", {
  # `x[FALSE] <- "Unknown"` coerces the whole vector to character even though it
  # selects nothing, so an integer or Date `by` column silently became text on
  # data with nothing missing. The fix must be inert on complete data.
  data(example_calendar, package = "tidycreel")
  data(example_interviews, package = "tidycreel")
  data(example_catch, package = "tidycreel")
  iv <- example_interviews
  iv$party_size <- as.integer(rep(1:3, length.out = nrow(iv)))
  d <- suppressWarnings(suppressMessages({
    dd <- creel_design(example_calendar, date = date, strata = day_type)
    dd <- add_interviews(dd, iv,
      catch = catch_total, effort = hours_fished, harvest = catch_kept,
      trip_status = trip_status, angler_type = angler_type,
      species_sought = species_sought
    )
    add_catch(dd, example_catch,
      catch_uid = interview_id, interview_uid = interview_id,
      species = species, count = count, catch_type = catch_type
    )
  }))
  result <- summarize_cws_rates(d, by = "party_size")
  expect_type(result$party_size, "integer")
})

test_that("a rate for an unrecorded SOUGHT SPECIES is NA, not zero (UNK-15)", {
  # The numerator is the catch of "the species this party was targeting". With
  # no target recorded there is nothing to count, and the upstream fill made
  # that count 0 -- which reports a mean rate of exactly 0 and asserts these
  # parties caught none of their target. Same 0-vs-NA distinction as UNK-08.
  result <- summarize_cws_rates(ug_design("species_sought"), by = "species_sought")
  unknown_row <- result[result$species_sought == "Unknown", ]
  expect_equal(nrow(unknown_row), 1L)
  expect_true(is.na(unknown_row$mean_rate))
  expect_true(is.na(unknown_row$se))

  # `N` counts the interviews that produced a rate, and GH #336 excluded the
  # unrecorded-target ones from that, so this group's N is 0 and its members are
  # counted in `n_unknown_target` instead. The row must still exist -- a group
  # that disappears is the defect GH #333 fixed -- and every interview must
  # still be accounted for across the two columns.
  expect_equal(unknown_row$N, 0L)
  expect_gt(unknown_row$n_unknown_target, 0L)
  expect_equal(sum(result$N) + sum(result$n_unknown_target), ug_n_interviews())
})

test_that("grouping by something else leaves the rate determinable (UNK-15b)", {
  # The other half: an unrecorded ANGLER TYPE does not make the rate unknowable,
  # because the catch and effort are the interviews' own.
  result <- summarize_cws_rates(ug_design("angler_type"), by = "angler_type")
  expect_false(any(is.na(result$mean_rate)))
})

test_that("a column holding both NA and a literal \"Unknown\" warns (UNK-16)", {
  # The two cannot be told apart in the output once pooled. Saying so is the
  # honest option; silently merging them is not.
  data(example_calendar, package = "tidycreel")
  data(example_interviews, package = "tidycreel")
  iv <- example_interviews
  iv$angler_type[1:3] <- "Unknown"
  iv$angler_type[4:6] <- NA
  d <- suppressWarnings(suppressMessages({
    dd <- creel_design(example_calendar, date = date, strata = day_type)
    add_interviews(dd, iv,
      catch = catch_total, effort = hours_fished, harvest = catch_kept,
      trip_status = trip_status, angler_type = angler_type
    )
  }))
  expect_warning(summarize_by_angler_type(d), "contains both unrecorded values")
})
