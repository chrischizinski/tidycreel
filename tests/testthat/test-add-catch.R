# Tests for add_catch() — Phase 29 (CATCH-01 through CATCH-05)

# --- Shared fixtures -----------------------------------------------------------

make_design_with_interviews <- function() {
  data(example_calendar, package = "tidycreel")
  data(example_interviews, package = "tidycreel")
  d <- suppressWarnings(
    creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  )
  suppressWarnings(
    add_interviews(
      d,
      example_interviews, # nolint: object_usage_linter
      catch = catch_total, # nolint: object_usage_linter
      effort = hours_fished, # nolint: object_usage_linter
      harvest = catch_kept, # nolint: object_usage_linter
      trip_status = trip_status, # nolint: object_usage_linter
      trip_duration = trip_duration # nolint: object_usage_linter
    )
  )
}

minimal_catch <- data.frame(
  interview_id = c(1L, 1L),
  species = c("walleye", "walleye"),
  count = c(5L, 2L),
  catch_type = c("caught", "harvested"),
  stringsAsFactors = FALSE
)

# --- Happy path ----------------------------------------------------------------

test_that("add_catch() returns a creel_design", {
  d <- make_design_with_interviews()
  result <- add_catch(
    d,
    minimal_catch,
    catch_uid = interview_id,
    interview_uid = interview_id, # nolint: object_usage_linter
    species = species,
    count = count,
    catch_type = catch_type # nolint: object_usage_linter
  )
  expect_s3_class(result, "creel_design")
})

test_that("add_catch() stores catch data on design$catch", {
  d <- make_design_with_interviews()
  result <- add_catch(
    d,
    minimal_catch,
    catch_uid = interview_id,
    interview_uid = interview_id, # nolint: object_usage_linter
    species = species,
    count = count,
    catch_type = catch_type # nolint: object_usage_linter
  )
  expect_equal(nrow(result$catch), 2L)
  expect_true("interview_id" %in% names(result$catch))
})

test_that("add_catch() sets all $catch_*_col fields", {
  d <- make_design_with_interviews()
  result <- add_catch(
    d,
    minimal_catch,
    catch_uid = interview_id,
    interview_uid = interview_id, # nolint: object_usage_linter
    species = species,
    count = count,
    catch_type = catch_type # nolint: object_usage_linter
  )
  expect_equal(result$catch_uid_col, "interview_id")
  expect_equal(result$catch_interview_uid_col, "interview_id")
  expect_equal(result$catch_species_col, "species")
  expect_equal(result$catch_count_col, "count")
  expect_equal(result$catch_type_col, "catch_type")
})

test_that("add_catch() works with example_catch dataset (CATCH-01)", {
  data(example_catch, package = "tidycreel")
  d <- make_design_with_interviews()
  expect_no_error(
    add_catch(
      d,
      example_catch,
      catch_uid = interview_id,
      interview_uid = interview_id, # nolint: object_usage_linter
      species = species,
      count = count,
      catch_type = catch_type # nolint: object_usage_linter
    )
  )
})

test_that("interviews with no catch rows are valid (CATCH-01)", {
  d <- make_design_with_interviews()
  one_row <- data.frame(
    interview_id = 1L,
    species = "walleye",
    count = 5L,
    catch_type = "caught",
    stringsAsFactors = FALSE
  )
  result <- add_catch(
    d,
    one_row,
    catch_uid = interview_id,
    interview_uid = interview_id, # nolint: object_usage_linter
    species = species,
    count = count,
    catch_type = catch_type # nolint: object_usage_linter
  )
  expect_equal(nrow(result$catch), 1L)
})

# --- Immutability --------------------------------------------------------------

test_that("add_catch() does not modify the original design", {
  d <- make_design_with_interviews()
  add_catch(
    d,
    minimal_catch,
    catch_uid = interview_id,
    interview_uid = interview_id, # nolint: object_usage_linter
    species = species,
    count = count,
    catch_type = catch_type # nolint: object_usage_linter
  )
  expect_null(d[["catch"]])
})

test_that("add_catch() errors when catch already attached", {
  d <- make_design_with_interviews()
  d2 <- add_catch(
    d,
    minimal_catch,
    catch_uid = interview_id,
    interview_uid = interview_id, # nolint: object_usage_linter
    species = species,
    count = count,
    catch_type = catch_type # nolint: object_usage_linter
  )
  expect_error(
    add_catch(
      d2,
      minimal_catch,
      catch_uid = interview_id,
      interview_uid = interview_id, # nolint: object_usage_linter
      species = species,
      count = count,
      catch_type = catch_type # nolint: object_usage_linter
    ),
    regexp = "already has catch"
  )
})

test_that("add_catch() errors when no interviews attached", {
  data(example_calendar, package = "tidycreel")
  d <- suppressWarnings(
    creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  )
  expect_error(
    add_catch(
      d,
      minimal_catch,
      catch_uid = interview_id,
      interview_uid = interview_id, # nolint: object_usage_linter
      species = species,
      count = count,
      catch_type = catch_type # nolint: object_usage_linter
    ),
    regexp = "Interviews must be attached"
  )
})

# --- CATCH-02: Interview UID validation ----------------------------------------

test_that("add_catch() errors on unmatched interview IDs (CATCH-02)", {
  d <- make_design_with_interviews()
  bad <- data.frame(
    interview_id = 999L,
    species = "walleye",
    count = 1L,
    catch_type = "caught",
    stringsAsFactors = FALSE
  )
  expect_error(
    add_catch(
      d,
      bad,
      catch_uid = interview_id,
      interview_uid = interview_id, # nolint: object_usage_linter
      species = species,
      count = count,
      catch_type = catch_type # nolint: object_usage_linter
    ),
    regexp = "not found in design interviews"
  )
})

# --- CATCH-03: catch_type normalization and validation -------------------------

test_that("add_catch() normalizes catch_type to lowercase silently (CATCH-03)", {
  d <- make_design_with_interviews()
  mixed_case <- data.frame(
    interview_id = c(1L, 1L),
    species = c("walleye", "walleye"),
    count = c(5L, 2L),
    catch_type = c("Caught", "HARVESTED"),
    stringsAsFactors = FALSE
  )
  result <- expect_no_warning(
    add_catch(
      d,
      mixed_case,
      catch_uid = interview_id,
      interview_uid = interview_id, # nolint: object_usage_linter
      species = species,
      count = count,
      catch_type = catch_type # nolint: object_usage_linter
    )
  )
  expect_true(all(result$catch$catch_type %in% c("caught", "harvested", "released")))
})

test_that("add_catch() errors on invalid catch_type after normalization (CATCH-03)", {
  d <- make_design_with_interviews()
  bad_type <- data.frame(
    interview_id = 1L,
    species = "walleye",
    count = 1L,
    catch_type = "KEPT",
    stringsAsFactors = FALSE
  )
  expect_error(
    add_catch(
      d,
      bad_type,
      catch_uid = interview_id,
      interview_uid = interview_id, # nolint: object_usage_linter
      species = species,
      count = count,
      catch_type = catch_type # nolint: object_usage_linter
    ),
    regexp = "Invalid.*catch_type"
  )
})

# --- CATCH-04: caught >= harvested + released ----------------------------------

test_that("add_catch() errors when caught < harvested (CATCH-04)", {
  d <- make_design_with_interviews()
  bad <- data.frame(
    interview_id = c(1L, 1L),
    species = c("walleye", "walleye"),
    count = c(1L, 5L),
    catch_type = c("caught", "harvested"),
    stringsAsFactors = FALSE
  )
  expect_error(
    add_catch(
      d,
      bad,
      catch_uid = interview_id,
      interview_uid = interview_id, # nolint: object_usage_linter
      species = species,
      count = count,
      catch_type = catch_type # nolint: object_usage_linter
    ),
    regexp = "Harvest \\+ release exceeds"
  )
})

test_that("add_catch() errors when caught < released (CATCH-04)", {
  d <- make_design_with_interviews()
  bad <- data.frame(
    interview_id = c(1L, 1L),
    species = c("walleye", "walleye"),
    count = c(2L, 5L),
    catch_type = c("caught", "released"),
    stringsAsFactors = FALSE
  )
  expect_error(
    add_catch(
      d,
      bad,
      catch_uid = interview_id,
      interview_uid = interview_id, # nolint: object_usage_linter
      species = species,
      count = count,
      catch_type = catch_type # nolint: object_usage_linter
    ),
    regexp = "Harvest \\+ release exceeds"
  )
})

test_that("add_catch() allows harvested rows with no caught row (CATCH-04)", {
  d <- make_design_with_interviews()
  harvest_only <- data.frame(
    interview_id = 1L,
    species = "walleye",
    count = 5L,
    catch_type = "harvested",
    stringsAsFactors = FALSE
  )
  expect_no_error(
    add_catch(
      d,
      harvest_only,
      catch_uid = interview_id,
      interview_uid = interview_id, # nolint: object_usage_linter
      species = species,
      count = count,
      catch_type = catch_type # nolint: object_usage_linter
    )
  )
})

test_that("add_catch() allows caught == harvested + released (CATCH-04)", {
  d <- make_design_with_interviews()
  exact <- data.frame(
    interview_id = c(1L, 1L, 1L),
    species = c("walleye", "walleye", "walleye"),
    count = c(5L, 3L, 2L),
    catch_type = c("caught", "harvested", "released"),
    stringsAsFactors = FALSE
  )
  expect_no_error(
    add_catch(
      d,
      exact,
      catch_uid = interview_id,
      interview_uid = interview_id, # nolint: object_usage_linter
      species = species,
      count = count,
      catch_type = catch_type # nolint: object_usage_linter
    )
  )
})

# --- CATCH-06: full-partition reconciliation advisory --------------------------

# `caught` rows carry the per-species total; `harvested` and `released`
# partition it. CATCH-04 aborts when the partition exceeds the total. These
# tests pin the opposite direction, which is only advisory because the two
# readings of a shortfall — a dropped row versus a fish whose disposition was
# never recorded — are indistinguishable from the data alone. The warning is
# therefore restricted to pairs recording BOTH dispositions, where a full
# partition was evidently intended. Widening it to partial recording would
# make it fire on ordinary field data and train users to ignore it.

test_that("add_catch() warns when a full partition falls short of caught (CATCH-06)", {
  d <- make_design_with_interviews()
  short_partition <- data.frame(
    interview_id = c(1L, 1L, 1L),
    species = "walleye",
    count = c(10L, 4L, 3L), # 4 + 3 < 10, both dispositions recorded
    catch_type = c("caught", "harvested", "released"),
    stringsAsFactors = FALSE
  )
  expect_warning(
    add_catch(
      d,
      short_partition,
      catch_uid = interview_id,
      interview_uid = interview_id, # nolint: object_usage_linter
      species = species,
      count = count,
      catch_type = catch_type # nolint: object_usage_linter
    ),
    regexp = "less than caught"
  )
})

test_that("add_catch() is silent when only one disposition is recorded (CATCH-06)", {
  d <- make_design_with_interviews()
  partial <- data.frame(
    interview_id = c(1L, 1L),
    species = "walleye",
    count = c(5L, 2L), # 3 fish with no recorded disposition — routine
    catch_type = c("caught", "harvested"),
    stringsAsFactors = FALSE
  )
  expect_no_warning(
    add_catch(
      d,
      partial,
      catch_uid = interview_id,
      interview_uid = interview_id, # nolint: object_usage_linter
      species = species,
      count = count,
      catch_type = catch_type # nolint: object_usage_linter
    )
  )
})

test_that("add_catch() is silent when a full partition reconciles exactly (CATCH-06)", {
  d <- make_design_with_interviews()
  exact <- data.frame(
    interview_id = c(1L, 1L, 1L),
    species = "walleye",
    count = c(7L, 4L, 3L),
    catch_type = c("caught", "harvested", "released"),
    stringsAsFactors = FALSE
  )
  expect_no_warning(
    add_catch(
      d,
      exact,
      catch_uid = interview_id,
      interview_uid = interview_id, # nolint: object_usage_linter
      species = species,
      count = count,
      catch_type = catch_type # nolint: object_usage_linter
    ),
    message = "less than caught"
  )
})

test_that("CATCH-06 advisory does not fire per-species across a mixed table (CATCH-06)", {
  d <- make_design_with_interviews()
  mixed <- data.frame(
    interview_id = c(1L, 1L, 1L, 1L, 1L),
    species = c("walleye", "walleye", "walleye", "northern_pike", "northern_pike"),
    count = c(6L, 4L, 2L, 5L, 2L), # walleye reconciles; pike is partial
    catch_type = c("caught", "harvested", "released", "caught", "harvested"),
    stringsAsFactors = FALSE
  )
  expect_no_warning(
    add_catch(
      d,
      mixed,
      catch_uid = interview_id,
      interview_uid = interview_id, # nolint: object_usage_linter
      species = species,
      count = count,
      catch_type = catch_type # nolint: object_usage_linter
    ),
    message = "less than caught"
  )
})

# --- CATCH-05: print method integration ----------------------------------------

test_that("print shows Catch Data section when attached (CATCH-05)", {
  data(example_catch, package = "tidycreel")
  d <- make_design_with_interviews()
  d2 <- add_catch(
    d,
    example_catch,
    catch_uid = interview_id,
    interview_uid = interview_id, # nolint: object_usage_linter
    species = species,
    count = count,
    catch_type = catch_type # nolint: object_usage_linter
  )
  out <- capture.output(print(d2))
  expect_true(any(grepl("Catch Data", out)))
  expect_true(any(grepl("species", out)))
})

test_that("print omits Catch Data section when not attached (CATCH-05)", {
  d <- make_design_with_interviews()
  out <- capture.output(print(d))
  expect_false(any(grepl("Catch Data", out)))
})

# --- Consistency check ---------------------------------------------------------

test_that("add_catch() warns when catch totals diverge from interview-level catch", {
  d <- make_design_with_interviews()
  diverged <- data.frame(
    interview_id = 1L,
    species = "walleye",
    count = 99L,
    catch_type = "caught",
    stringsAsFactors = FALSE
  )
  expect_warning(
    add_catch(
      d,
      diverged,
      catch_uid = interview_id,
      interview_uid = interview_id, # nolint: object_usage_linter
      species = species,
      count = count,
      catch_type = catch_type # nolint: object_usage_linter
    ),
    regexp = "diverge"
  )
})

# An unknown count is not a zero one (CATCH-07, GH #324) ----
#
# `add_catch()` documents that an angler who caught none of a species need not
# appear in this table at all, so every consumer reads a MISSING ROW as a catch
# of none. That reading is right for an absent row and wrong for a present row
# holding an unknown count -- and nothing downstream could tell them apart.

add_catch_std <- function(d, data) {
  add_catch(
    d, data,
    catch_uid = interview_id,
    interview_uid = interview_id, # nolint: object_usage_linter
    species = species,
    count = count,
    catch_type = catch_type # nolint: object_usage_linter
  )
}

test_that("add_catch() refuses an unknown count and names the pair (CATCH-07)", {
  d <- make_design_with_interviews()
  unknown <- data.frame(
    interview_id = c(1L, 1L),
    species = c("walleye", "walleye"),
    count = c(10L, NA_integer_),
    catch_type = c("caught", "harvested"),
    stringsAsFactors = FALSE
  )
  err <- tryCatch(add_catch_std(d, unknown), error = function(e) e)
  expect_s3_class(err, "creel_error_na_catch_count")

  # The offending pair is named. CATCH-04 used to abort on this input for the
  # wrong reason: `caught_total < sub_total` is NA when a count is NA, and
  # `combined[NA, ]` yields a PHANTOM all-NA row, so the message read
  # `"NA/NA"` and told the user nothing about which row to fix.
  msg <- conditionMessage(err)
  expect_match(msg, "1/walleye", fixed = TRUE)
  expect_false(grepl("NA/NA", msg, fixed = TRUE))
})

test_that("add_catch() refuses an unknown count on any catch type (CATCH-07)", {
  # Three separate reasons the three types need covering: a `caught` NA reached
  # CATCH-04's phantom row; a `harvested` NA was ZEROED by the `sub_total` fill
  # and so passed CATCH-04 in silence; a `released` NA took the same path.
  d <- make_design_with_interviews()
  for (ct in c("caught", "harvested", "released")) {
    unknown <- data.frame(
      interview_id = 1L,
      species = "walleye",
      count = NA_integer_,
      catch_type = ct,
      stringsAsFactors = FALSE
    )
    expect_error(
      add_catch_std(d, unknown),
      class = "creel_error_na_catch_count",
      info = ct
    )
  }
})

test_that("an unknown harvest no longer reads as a genuine zero (CATCH-07)", {
  # The defect as measured. Same design three ways, changing only one
  # harvested count. Before the refusal, NA and 0 produced byte-identical
  # output -- the rate understated and the CI narrowed, with no error and no
  # warning -- because `summarize_hws_rates()` left-joins the catch table onto
  # the interviews and fills the join miss with zero, which swallowed the NA
  # along with it.
  skip_if_not(exists("example_catch"))
  data(example_calendar, package = "tidycreel")
  data(example_counts, package = "tidycreel")
  data(example_interviews, package = "tidycreel")
  data(example_catch, package = "tidycreel")

  d <- suppressWarnings(suppressMessages(
    add_interviews(
      add_counts(
        creel_design(example_calendar, date = date, strata = day_type), # nolint: object_usage_linter
        example_counts
      ),
      example_interviews,
      catch = catch_total, # nolint: object_usage_linter
      effort = hours_fished, # nolint: object_usage_linter
      harvest = catch_kept, # nolint: object_usage_linter
      trip_status = trip_status, # nolint: object_usage_linter
      n_anglers = n_anglers, # nolint: object_usage_linter
      species_sought = species_sought # nolint: object_usage_linter
    )
  ))

  target <- function(cd) {
    cd$interview_id == 2 & cd$species == "walleye" & cd$catch_type == "harvested"
  }
  rate_for <- function(val) {
    cd <- example_catch
    cd$count[target(cd)] <- val
    res <- suppressWarnings(suppressMessages(
      summarize_hws_rates(add_catch_std(d, cd))
    ))
    as.data.frame(res)$mean_rate[[1]]
  }

  # The known count is what the pair actually recorded.
  expect_equal(rate_for(5L), 0.2332251, tolerance = 1e-6)

  # A GENUINE zero still reads as a zero -- the documented behaviour, and the
  # thing the refusal must not break.
  expect_equal(rate_for(0L), 0.16829, tolerance = 1e-5)

  # An UNKNOWN count is refused rather than quietly reported as that same
  # 0.16829. This is the assertion that fails against the old code, where the
  # two were indistinguishable.
  cd_na <- example_catch
  cd_na$count[target(cd_na)] <- NA_integer_
  expect_error(add_catch_std(d, cd_na), class = "creel_error_na_catch_count")
})

test_that("an interview absent from the catch table still reads as zero (CATCH-07)", {
  # The other half of the distinction, pinned so the refusal cannot be
  # "fixed" by making absence unknown too. add_catch() documents that an
  # angler who caught none of a species need not appear at all.
  #
  # Asserted THROUGH the summary, not at add_catch(). An earlier version of
  # this test only checked that add_catch() succeeded and returned one row,
  # which would still have passed if a later change made an absent interview
  # read as NA downstream -- so it did not pin the behaviour its name claims.
  data(example_calendar, package = "tidycreel")
  data(example_counts, package = "tidycreel")
  data(example_interviews, package = "tidycreel")

  d <- suppressWarnings(suppressMessages(
    add_interviews(
      add_counts(
        creel_design(example_calendar, date = date, strata = day_type), # nolint: object_usage_linter
        example_counts
      ),
      example_interviews,
      catch = catch_total, # nolint: object_usage_linter
      effort = hours_fished, # nolint: object_usage_linter
      harvest = catch_kept, # nolint: object_usage_linter
      trip_status = trip_status, # nolint: object_usage_linter
      n_anglers = n_anglers, # nolint: object_usage_linter
      species_sought = species_sought # nolint: object_usage_linter
    )
  ))

  # One interview has a harvested row; every other interview is ABSENT from
  # the catch table entirely.
  one_row <- data.frame(
    interview_id = 2L,
    species = "walleye",
    count = 5L,
    catch_type = "harvested",
    stringsAsFactors = FALSE
  )
  res <- suppressWarnings(suppressMessages(
    summarize_hws_rates(add_catch_std(d, one_row))
  ))
  df <- as.data.frame(res)

  # The absent interviews are counted, not dropped: they contribute a rate of
  # zero, so the mean rate is the one interview's catch spread over all of
  # them, and the summary is not NA.
  expect_false(is.na(df$mean_rate[[1]]))
  expect_gt(df$mean_rate[[1]], 0)
  # All 22 interviews are counted, not just the one carrying a catch row.
  expect_equal(df$N[[1]], nrow(example_interviews))

  # And it really is a zero rather than a dropped row: the same design with
  # NO catch rows at all for that species gives a mean rate of exactly zero,
  # over the same number of interviews.
  none <- data.frame(
    interview_id = 2L,
    species = "bass",
    count = 5L,
    catch_type = "harvested",
    stringsAsFactors = FALSE
  )
  res_none <- suppressWarnings(suppressMessages(
    summarize_hws_rates(add_catch_std(d, none))
  ))
  df_none <- as.data.frame(res_none)
  expect_equal(df_none$N[[1]], df$N[[1]])
  expect_equal(df_none$mean_rate[[1]], 0)
  expect_lt(df_none$mean_rate[[1]], df$mean_rate[[1]])
})
