# An interview whose SOUGHT SPECIES was never recorded must not be scored as
# having caught zero of it — GH #336.
#
# The CWS/HWS numerator counts fish of the species the party was targeting. With
# no target recorded, nothing in the catch table can match, so the interview
# falls through the join exactly as a party that caught none of its target does
# — and the fill downstream turned both into 0. Measured on the shipped example
# data, blanking the sought species on 7 of 22 interviews took the boat group's
# mean rate from 0.393 to 0.254 with N unchanged at 9: no row dropped, no group
# missing, no warning.
#
# Those interviews are now excluded from the rate and counted in
# `n_unknown_target`. The estimand is "rate among parties with a known target",
# which equals the rate among all parties only if the target went unrecorded
# independently of what was caught — so the count is reported beside every rate
# rather than the exclusion being silent.

ut_design <- function(blank_sought = FALSE, all_blank = FALSE) {
  data(example_calendar, package = "tidycreel")
  data(example_interviews, package = "tidycreel")
  data(example_catch, package = "tidycreel")
  iv <- example_interviews
  if (all_blank) {
    iv$species_sought <- NA_character_
  } else if (blank_sought) {
    iv$species_sought[seq_len(nrow(iv)) %% 3 == 0] <- NA
  }
  suppressWarnings(suppressMessages({
    d <- creel_design(example_calendar, date = date, strata = day_type)
    d <- add_interviews(d, iv,
      catch = catch_total, effort = hours_fished, harvest = catch_kept,
      trip_status = trip_status, angler_type = angler_type,
      species_sought = species_sought
    )
    add_catch(d, example_catch,
      catch_uid = interview_id, interview_uid = interview_id,
      species = species, count = count, catch_type = catch_type
    )
  }))
}

ut_n <- function() {
  data(example_interviews, package = "tidycreel")
  nrow(example_interviews)
}

# --- complete data must be untouched — TGT-01 --------------------------------

test_that("a design with every target recorded is unchanged (TGT-01)", {
  # Pins the numbers the fix must not move, and the reason the whole class was
  # invisible: with nothing missing there is nothing to exclude.
  result <- summarize_cws_rates(ut_design(), by = "angler_type")
  expect_equal(result$angler_type, c("bank", "boat"))
  expect_equal(result$N, c(13L, 9L))
  expect_equal(round(result$mean_rate, 4), c(0.6667, 0.3929))
  expect_equal(result$n_unknown_target, c(0L, 0L))
})

# --- the rate must stop counting an unknown target as zero — TGT-02..03 ------

test_that("an unrecorded target is excluded from the rate, not scored zero (TGT-02)", {
  # Discriminating on the exact number: 0.2540 is the answer the zero-fill gave,
  # and it must not be reachable any more. The group had 9 interviews and keeps
  # 3; asserting only "the rate changed" would also pass if the fix were wrong
  # in some other direction.
  result <- summarize_cws_rates(ut_design(blank_sought = TRUE), by = "angler_type")
  boat <- result[result$angler_type == "boat", ]
  expect_equal(boat$N, 3L)
  expect_equal(boat$n_unknown_target, 6L)
  expect_false(isTRUE(all.equal(round(boat$mean_rate, 4), 0.2540)))
  expect_equal(round(boat$mean_rate, 4), 0.7619)
})

test_that("every interview is accounted for across N and n_unknown_target (TGT-03)", {
  # The invariant that encodes the intent. Exclusion is only defensible while
  # the excluded are still counted somewhere the reader can see.
  grouped_by_type <- summarize_cws_rates(ut_design(blank_sought = TRUE), by = "angler_type")
  expect_equal(sum(grouped_by_type$N) + sum(grouped_by_type$n_unknown_target), ut_n())

  grouped_by_sought <- summarize_cws_rates(ut_design(blank_sought = TRUE), by = "species_sought")
  expect_equal(sum(grouped_by_sought$N) + sum(grouped_by_sought$n_unknown_target), ut_n())
  ungrouped <- summarize_cws_rates(ut_design(blank_sought = TRUE))
  expect_equal(ungrouped$N + ungrouped$n_unknown_target, ut_n())
})

# --- exclusion must not make a group disappear — TGT-04 ----------------------

test_that("a group with nothing usable keeps its row (TGT-04)", {
  # Grouped by sought species, the unrecorded group consists ENTIRELY of
  # excluded interviews. Dropping it would silently re-create the defect GH #333
  # had just finished fixing, from the opposite direction: counts are taken over
  # every interview and only the rate over the usable ones, which is what keeps
  # this row alive.
  result <- summarize_cws_rates(ut_design(blank_sought = TRUE), by = "species_sought")
  unknown <- result[result$species_sought == "Unknown", ]
  expect_equal(nrow(unknown), 1L)
  expect_equal(unknown$N, 0L)
  expect_equal(unknown$n_unknown_target, 7L)
  # No rate of any kind survives an N of 0 -- not a mean, not an se, not an
  # interval. An se left behind a blanked mean reads as a precision claim.
  expect_true(is.na(unknown$mean_rate))
  expect_true(is.na(unknown$se))
  expect_true(is.na(unknown$ci_lower))
  expect_true(is.na(unknown$ci_upper))
})

# --- a genuine zero must survive — TGT-05 ------------------------------------

test_that("a party that really caught none of its target still counts as zero (TGT-05)", {
  # The control, and the one that stops this fix overreaching. `add_catch()`
  # documents an interview absent from the catch table as having caught none, so
  # a KNOWN target with no catch row is a real zero and must stay in the mean.
  # Turning those into exclusions would bias every rate upward -- the mirror of
  # the defect being fixed.
  result <- summarize_cws_rates(ut_design(blank_sought = TRUE), by = "species_sought")
  bass <- result[result$species_sought == "bass", ]
  expect_equal(bass$N, 4L)
  expect_equal(bass$n_unknown_target, 0L)
  expect_equal(bass$mean_rate, 0)
  expect_false(is.na(bass$mean_rate))
})

# --- the twin must agree — TGT-06 --------------------------------------------

test_that("summarize_hws_rates() behaves identically (TGT-06)", {
  # The two functions differ only in which catch type their caller filters to,
  # and their Step 3-7 blocks were byte-identical copies. They now share one
  # implementation, which is what stops a seam fixed in one surviving in the
  # other.
  cws <- summarize_cws_rates(ut_design(blank_sought = TRUE), by = "angler_type")
  hws <- summarize_hws_rates(ut_design(blank_sought = TRUE), by = "angler_type")
  expect_equal(hws$N, cws$N)
  expect_equal(hws$n_unknown_target, cws$n_unknown_target)
  expect_equal(sum(hws$N) + sum(hws$n_unknown_target), ut_n())
  # Same accounting, different quantity: harvest is not catch.
  expect_false(isTRUE(all.equal(hws$mean_rate, cws$mean_rate)))
})

# --- no usable interview at all — TGT-07 -------------------------------------

test_that("every target unrecorded returns a table instead of crashing (TGT-07)", {
  # Comparing anything with NA yields NA, and an NA subscript selects a PHANTOM
  # all-NA row rather than nothing. With every target unrecorded those phantoms
  # made the filtered frame look non-empty, the aggregate returned zero rows
  # with a logical key, and the join produced a non-numeric target count that
  # failed later as base R's "non-numeric argument to binary operator" --
  # naming nothing the caller had set. Pre-existing; it errored on main too.
  result <- summarize_cws_rates(ut_design(all_blank = TRUE), by = "angler_type")
  expect_s3_class(result, "creel_summary_cws_rates")
  expect_equal(nrow(result), 2L)
  expect_equal(result$N, c(0L, 0L))
  expect_equal(sum(result$n_unknown_target), ut_n())
  expect_true(all(is.na(result$mean_rate)))
})
