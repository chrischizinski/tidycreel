# Tests for summarize_*() functions — Phase 31 (USUM-01 through USUM-09)

# --- Shared fixtures -----------------------------------------------------------

make_design_with_extended_interviews <- function() {
  # nolint: object_length_linter
  data(example_calendar, package = "tidycreel")
  data(example_interviews, package = "tidycreel")
  # Inject one refusal for USUM-01 coverage (example_interviews has all refused=FALSE)
  example_interviews$refused[1] <- TRUE
  d <- suppressWarnings(
    creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  )
  suppressWarnings(
    # nolint: object_usage_linter
    add_interviews(
      d,
      example_interviews, # nolint: object_usage_linter
      catch = catch_total, # nolint: object_usage_linter
      effort = hours_fished, # nolint: object_usage_linter
      harvest = catch_kept, # nolint: object_usage_linter
      trip_status = trip_status, # nolint: object_usage_linter
      trip_duration = trip_duration, # nolint: object_usage_linter
      angler_type = angler_type, # nolint: object_usage_linter
      angler_method = angler_method, # nolint: object_usage_linter
      species_sought = species_sought, # nolint: object_usage_linter
      n_anglers = n_anglers, # nolint: object_usage_linter
      refused = refused # nolint: object_usage_linter
    )
  )
}

make_design_with_catch <- function() {
  data(example_catch, package = "tidycreel")
  d <- make_design_with_extended_interviews()
  add_catch(
    d,
    example_catch, # nolint: object_usage_linter
    catch_uid = interview_id, # nolint: object_usage_linter
    interview_uid = interview_id, # nolint: object_usage_linter
    species = species, # nolint: object_usage_linter
    count = count, # nolint: object_usage_linter
    catch_type = catch_type # nolint: object_usage_linter
  )
}

# --- summarize_refusals() — USUM-01 -------------------------------------------

test_that("summarize_refusals() returns a data.frame with correct classes", {
  d <- make_design_with_extended_interviews()
  result <- summarize_refusals(d)
  expect_s3_class(result, "data.frame")
  expect_s3_class(result, "creel_summary_refusals")
})

test_that("summarize_refusals() has correct columns", {
  d <- make_design_with_extended_interviews()
  result <- summarize_refusals(d)
  expect_true(all(c("month", "participation", "N", "percent") %in% names(result)))
})

test_that("summarize_refusals() N is integer and percent is numeric", {
  d <- make_design_with_extended_interviews()
  result <- summarize_refusals(d)
  expect_true(is.integer(result$N))
  expect_true(is.numeric(result$percent))
})

test_that("summarize_refusals() includes both 'accepted' and 'refused' rows", {
  d <- make_design_with_extended_interviews()
  result <- summarize_refusals(d)
  expect_true("accepted" %in% result$participation)
  expect_true("refused" %in% result$participation)
})

test_that("summarize_refusals() percent sums to 100 within each month", {
  d <- make_design_with_extended_interviews()
  result <- summarize_refusals(d)
  for (m in unique(result$month)) {
    month_sum <- sum(result$percent[result$month == m])
    expect_equal(month_sum, 100, tolerance = 0.5)
  }
})

test_that("summarize_refusals() errors when refused_col is NULL", {
  data(example_calendar, package = "tidycreel")
  data(example_interviews, package = "tidycreel")
  d <- suppressWarnings(
    creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  )
  d2 <- suppressWarnings(
    add_interviews(
      d,
      example_interviews, # nolint: object_usage_linter
      catch = catch_total, # nolint: object_usage_linter
      effort = hours_fished, # nolint: object_usage_linter
      harvest = catch_kept, # nolint: object_usage_linter
      trip_status = trip_status # nolint: object_usage_linter
    )
  )
  expect_error(summarize_refusals(d2), regexp = "refused")
})

# --- summarize_by_day_type() — USUM-02 ----------------------------------------

test_that("summarize_by_day_type() returns creel_summary_day_type", {
  d <- make_design_with_extended_interviews()
  result <- summarize_by_day_type(d)
  expect_s3_class(result, "creel_summary_day_type")
  expect_s3_class(result, "data.frame")
})

test_that("summarize_by_day_type() has correct columns", {
  d <- make_design_with_extended_interviews()
  result <- summarize_by_day_type(d)
  expect_true(all(c("month", "day_type", "N", "percent") %in% names(result)))
})

test_that("summarize_by_day_type() N is integer", {
  d <- make_design_with_extended_interviews()
  result <- summarize_by_day_type(d)
  expect_true(is.integer(result$N))
})

test_that("summarize_by_day_type() percent sums to ~100 within each month", {
  d <- make_design_with_extended_interviews()
  result <- summarize_by_day_type(d)
  for (m in unique(result$month)) {
    month_sum <- sum(result$percent[result$month == m])
    expect_equal(month_sum, 100, tolerance = 0.5)
  }
})

test_that("summarize_by_day_type() works without optional Phase 28 fields", {
  data(example_calendar, package = "tidycreel")
  data(example_interviews, package = "tidycreel")
  d <- suppressWarnings(
    creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  )
  d2 <- suppressWarnings(
    add_interviews(
      d,
      example_interviews, # nolint: object_usage_linter
      catch = catch_total, # nolint: object_usage_linter
      effort = hours_fished, # nolint: object_usage_linter
      harvest = catch_kept, # nolint: object_usage_linter
      trip_status = trip_status # nolint: object_usage_linter
    )
  )
  expect_no_error(summarize_by_day_type(d2))
})

# --- summarize_by_angler_type() — USUM-03 -------------------------------------

test_that("summarize_by_angler_type() returns creel_summary_angler_type", {
  d <- make_design_with_extended_interviews()
  result <- summarize_by_angler_type(d)
  expect_s3_class(result, "creel_summary_angler_type")
  expect_s3_class(result, "data.frame")
})

test_that("summarize_by_angler_type() has correct columns", {
  d <- make_design_with_extended_interviews()
  result <- summarize_by_angler_type(d)
  expect_true(all(c("month", "angler_type", "N", "percent") %in% names(result)))
})

test_that("summarize_by_angler_type() N is integer", {
  d <- make_design_with_extended_interviews()
  result <- summarize_by_angler_type(d)
  expect_true(is.integer(result$N))
})

test_that("summarize_by_angler_type() angler_type values match source data", {
  d <- make_design_with_extended_interviews()
  result <- summarize_by_angler_type(d)
  expect_true(all(result$angler_type %in% c("bank", "boat")))
})

test_that("summarize_by_angler_type() errors when angler_type_col is NULL", {
  data(example_calendar, package = "tidycreel")
  data(example_interviews, package = "tidycreel")
  d <- suppressWarnings(
    creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  )
  d2 <- suppressWarnings(
    add_interviews(
      d,
      example_interviews, # nolint: object_usage_linter
      catch = catch_total, # nolint: object_usage_linter
      effort = hours_fished, # nolint: object_usage_linter
      harvest = catch_kept, # nolint: object_usage_linter
      trip_status = trip_status # nolint: object_usage_linter
    )
  )
  expect_error(summarize_by_angler_type(d2), regexp = "angler_type")
})

# --- summarize_by_method() — USUM-04 ------------------------------------------

test_that("summarize_by_method() returns creel_summary_method", {
  d <- make_design_with_extended_interviews()
  result <- summarize_by_method(d)
  expect_s3_class(result, "creel_summary_method")
  expect_s3_class(result, "data.frame")
})

test_that("summarize_by_method() has correct columns", {
  d <- make_design_with_extended_interviews()
  result <- summarize_by_method(d)
  expect_true(all(c("month", "method", "N", "percent") %in% names(result)))
})

test_that("summarize_by_method() N is integer", {
  d <- make_design_with_extended_interviews()
  result <- summarize_by_method(d)
  expect_true(is.integer(result$N))
})

test_that("summarize_by_method() method values match source data", {
  d <- make_design_with_extended_interviews()
  result <- summarize_by_method(d)
  expect_true(all(result$method %in% c("bait", "artificial", "fly")))
})

test_that("summarize_by_method() errors when angler_method_col is NULL", {
  data(example_calendar, package = "tidycreel")
  data(example_interviews, package = "tidycreel")
  d <- suppressWarnings(
    creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  )
  d2 <- suppressWarnings(
    add_interviews(
      d,
      example_interviews, # nolint: object_usage_linter
      catch = catch_total, # nolint: object_usage_linter
      effort = hours_fished, # nolint: object_usage_linter
      harvest = catch_kept, # nolint: object_usage_linter
      trip_status = trip_status # nolint: object_usage_linter
    )
  )
  expect_error(summarize_by_method(d2), regexp = "angler_method")
})

# --- summarize_by_species_sought() — USUM-05 ----------------------------------

test_that("summarize_by_species_sought() returns creel_summary_species_sought", {
  d <- make_design_with_extended_interviews()
  result <- summarize_by_species_sought(d)
  expect_s3_class(result, "creel_summary_species_sought")
  expect_s3_class(result, "data.frame")
})

test_that("summarize_by_species_sought() has correct columns", {
  d <- make_design_with_extended_interviews()
  result <- summarize_by_species_sought(d)
  expect_true(all(c("month", "species", "N", "percent") %in% names(result)))
})

test_that("summarize_by_species_sought() N is integer", {
  d <- make_design_with_extended_interviews()
  result <- summarize_by_species_sought(d)
  expect_true(is.integer(result$N))
})

test_that("summarize_by_species_sought() species values match source data", {
  d <- make_design_with_extended_interviews()
  result <- summarize_by_species_sought(d)
  expect_true(all(result$species %in% c("walleye", "bass", "panfish")))
})

test_that("summarize_by_species_sought() errors when species_sought_col is NULL", {
  data(example_calendar, package = "tidycreel")
  data(example_interviews, package = "tidycreel")
  d <- suppressWarnings(
    creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  )
  d2 <- suppressWarnings(
    add_interviews(
      d,
      example_interviews, # nolint: object_usage_linter
      catch = catch_total, # nolint: object_usage_linter
      effort = hours_fished, # nolint: object_usage_linter
      harvest = catch_kept, # nolint: object_usage_linter
      trip_status = trip_status # nolint: object_usage_linter
    )
  )
  expect_error(summarize_by_species_sought(d2), regexp = "species_sought")
})

# --- summarize_successful_parties() — USUM-06 ---------------------------------

test_that("summarize_successful_parties() returns creel_summary_successful_parties", {
  d <- make_design_with_catch()
  result <- summarize_successful_parties(d)
  expect_s3_class(result, "creel_summary_successful_parties")
  expect_s3_class(result, "data.frame")
})

test_that("summarize_successful_parties() has correct columns", {
  d <- make_design_with_catch()
  result <- summarize_successful_parties(d)
  expect_true(
    all(c("angler_type", "species_sought", "N_successful", "N_total", "percent") %in% names(result))
  )
})

test_that("summarize_successful_parties() N_successful and N_total are integer", {
  d <- make_design_with_catch()
  result <- summarize_successful_parties(d)
  expect_true(is.integer(result$N_successful))
  expect_true(is.integer(result$N_total))
})

test_that("summarize_successful_parties() N_successful <= N_total for all rows", {
  d <- make_design_with_catch()
  result <- summarize_successful_parties(d)
  expect_true(all(result$N_successful <= result$N_total))
})

# A `caught` row is OPTIONAL (GH #329) ----
#
# `add_catch()` documents that when a pair records no `caught` row, its total
# catch is `harvested + released`. This function read success off a `caught` row
# alone, with no fallback, so a party recording only its dispositions counted as
# unsuccessful while its own harvest was positive.

catch_without <- function(drop_types = "caught", interview = NULL, species = NULL) {
  data(example_catch, package = "tidycreel")
  cd <- example_catch
  hit <- cd$catch_type %in% drop_types
  if (!is.null(interview)) hit <- hit & cd$interview_id == interview
  if (!is.null(species)) hit <- hit & cd$species == species
  cd[!hit, , drop = FALSE]
}

design_with <- function(cd) {
  d <- make_design_with_extended_interviews()
  suppressWarnings(suppressMessages(add_catch(
    d, cd,
    catch_uid = interview_id, # nolint: object_usage_linter
    interview_uid = interview_id, # nolint: object_usage_linter
    species = species, # nolint: object_usage_linter
    count = count, # nolint: object_usage_linter
    catch_type = catch_type # nolint: object_usage_linter
  )))
}

test_that("SSP-01 (#329): a party recording only dispositions counts as successful", {
  # Four pairs in the SHIPPED example catch have no `caught` row and positive
  # dispositions -- interviews 11, 12 and 14 (walleye) and 13 (bass) -- so this
  # was not hypothetical: those parties demonstrably caught their sought
  # species and were all reported unsuccessful. The total was 6; it is 10.
  d <- design_with(example_catch)
  result <- summarize_successful_parties(d)
  expect_equal(sum(result$N_successful), 10L)
})

test_that("SSP-02 (#329): omitting the optional caught rows does not change the answer", {
  # The invariance that makes the rule real. Dropping every `caught` row is
  # legal by construction -- the documentation says so, and each pair's
  # harvested and released rows are untouched, so the same parties caught the
  # same fish. Before the fix this took the count from 6 to ZERO and every
  # reported rate to 0.0%.
  with_caught <- summarize_successful_parties(design_with(example_catch))
  without <- summarize_successful_parties(design_with(catch_without()))

  expect_equal(without$N_successful, with_caught$N_successful)
  expect_equal(without$percent, with_caught$percent)
  expect_gt(sum(without$N_successful), 0L)
})

test_that("SSP-03 (#329): dropping ONE pair's caught row does not change that pair", {
  # The realistic case. Interview 1 recorded caught 5 / harvested 2 /
  # released 3 walleye and sought walleye; with its caught row removed the
  # derived total is the same 5. Before the fix bank/walleye fell from 60.0%
  # to 40.0%.
  base <- summarize_successful_parties(design_with(example_catch))
  one <- summarize_successful_parties(
    design_with(catch_without(interview = 1L, species = "walleye"))
  )
  expect_equal(one$N_successful, base$N_successful)
})

test_that("SSP-04 (#329): a pair that caught none of its sought species is not successful", {
  # The mirror, so the fix cannot be "count any row". A recorded catch of zero
  # is data, not an absence, and must stay unsuccessful.
  data(example_catch, package = "tidycreel")
  cd <- example_catch
  keep <- !(cd$interview_id == 1L & cd$species == "walleye")
  zeroed <- data.frame(
    interview_id = 1L,
    species = "walleye",
    count = 0L,
    catch_type = "caught",
    stringsAsFactors = FALSE
  )
  cd2 <- rbind(cd[keep, names(zeroed), drop = FALSE], zeroed)

  base <- summarize_successful_parties(design_with(example_catch))
  res <- summarize_successful_parties(design_with(cd2))
  bw <- res$N_successful[res$angler_type == "bank" & res$species_sought == "walleye"]
  bw0 <- base$N_successful[base$angler_type == "bank" & base$species_sought == "walleye"]
  expect_equal(bw, bw0 - 1L)
})

test_that("SSP-05 (#329): a zero caught row does NOT fall back to its dispositions", {
  # The case SSP-04 above cannot reach. A pair recording `caught = 0` ALONGSIDE
  # positive harvested/released rows violates CATCH-04 (caught >= harvested +
  # released), so `add_catch()` refuses to build it and the public path cannot
  # construct the fixture. The rule is therefore pinned on the helper directly.
  #
  # Without this, a regression that read a zero `caught` row as ABSENT and fell
  # back to harvested + released would go uncaught: SSP-04's party has no
  # dispositions left, so it would report zero either way.
  cd <- data.frame(
    interview_id = c(1L, 1L, 1L),
    species = "walleye",
    count = c(0L, 3L, 2L),
    catch_type = c("caught", "harvested", "released"),
    stringsAsFactors = FALSE
  )
  got <- tidycreel:::species_counts_per_interview(
    cd, "walleye", "caught",
    uid_col = "interview_id", species_col = "species",
    type_col = "catch_type", count_col = "count"
  )
  expect_equal(nrow(got), 1L)
  # 0, not 5: the pair has its own caught row and keeps it.
  expect_equal(got$count, 0)
})

test_that("summarize_successful_parties() errors when catch is not attached", {
  d <- make_design_with_extended_interviews()
  expect_error(summarize_successful_parties(d), regexp = "catch")
})

test_that("summarize_successful_parties() errors when angler_type_col is NULL", {
  data(example_calendar, package = "tidycreel")
  data(example_interviews, package = "tidycreel")
  d <- suppressWarnings(
    creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  )
  d2 <- suppressWarnings(
    add_interviews(
      d,
      example_interviews, # nolint: object_usage_linter
      catch = catch_total, # nolint: object_usage_linter
      effort = hours_fished, # nolint: object_usage_linter
      harvest = catch_kept, # nolint: object_usage_linter
      trip_status = trip_status # nolint: object_usage_linter
    )
  )
  expect_error(summarize_successful_parties(d2), regexp = "angler_type")
})

# --- summarize_by_trip_length() — USUM-07 -------------------------------------

test_that("summarize_by_trip_length() returns creel_summary_trip_length", {
  d <- make_design_with_extended_interviews()
  result <- summarize_by_trip_length(d)
  expect_s3_class(result, "creel_summary_trip_length")
  expect_s3_class(result, "data.frame")
})

test_that("summarize_by_trip_length() has correct columns", {
  d <- make_design_with_extended_interviews()
  result <- summarize_by_trip_length(d)
  expect_true(all(c("trip_length_bin", "N", "percent") %in% names(result)))
})

test_that("summarize_by_trip_length() trip_length_bin is an ordered factor", {
  d <- make_design_with_extended_interviews()
  result <- summarize_by_trip_length(d)
  expect_true(is.ordered(result$trip_length_bin))
})

test_that("summarize_by_trip_length() bin levels span '[0,1)' through '10+' (11 levels)", {
  d <- make_design_with_extended_interviews()
  result <- summarize_by_trip_length(d)
  expect_true("[0,1)" %in% levels(result$trip_length_bin))
  expect_true("10+" %in% levels(result$trip_length_bin))
  expect_equal(length(levels(result$trip_length_bin)), 11L)
})

test_that("summarize_by_trip_length() N is integer and percent is numeric", {
  d <- make_design_with_extended_interviews()
  result <- summarize_by_trip_length(d)
  expect_true(is.integer(result$N))
  expect_true(is.numeric(result$percent))
})

test_that("summarize_by_trip_length() errors when trip_duration_col is NULL", {
  data(example_calendar, package = "tidycreel")
  data(example_interviews, package = "tidycreel")
  d <- suppressWarnings(
    creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  )
  d2 <- suppressWarnings(
    add_interviews(
      d,
      example_interviews, # nolint: object_usage_linter
      catch = catch_total, # nolint: object_usage_linter
      effort = hours_fished, # nolint: object_usage_linter
      harvest = catch_kept, # nolint: object_usage_linter
      trip_status = trip_status # nolint: object_usage_linter
    )
  )
  expect_error(summarize_by_trip_length(d2), regexp = "trip_duration")
})

# --- Cross-function guard tests — USUM-08 -------------------------------------

test_that("summarize_refusals() errors when design is not creel_design", {
  expect_error(summarize_refusals(list()), regexp = "creel_design")
})

test_that("summarize_by_day_type() errors when interviews not attached", {
  data(example_calendar, package = "tidycreel")
  d_bare <- suppressWarnings(
    creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  )
  expect_error(summarize_by_day_type(d_bare), regexp = "interview")
})

test_that("all seven functions return 'data.frame' as part of their class vector", {
  d_full <- make_design_with_catch()
  results <- list(
    summarize_refusals(d_full),
    summarize_by_day_type(d_full),
    summarize_by_angler_type(d_full),
    summarize_by_method(d_full),
    summarize_by_species_sought(d_full),
    summarize_successful_parties(d_full),
    summarize_by_trip_length(d_full)
  )
  for (result in results) {
    expect_true("data.frame" %in% class(result))
  }
})

# --- Day type column resolution — USUM-09 (GH #221) ---------------------------
#
# `strata_cols[1]` is the order the caller declared their strata in, not a
# definition of day type. A design declaring `strata = c(site, day_type)` put
# site names under a `day_type` header with no warning, and the real weekday /
# weekend split was absent from the output entirely. These tests pin the
# resolution order, not the tabulation arithmetic, which USUM-02 already covers.

make_two_strata_design <- function(strata_second = "day_type") {
  dates <- as.Date("2024-06-01") + 0:5
  cal <- data.frame(
    date = dates,
    site = rep(c("north", "south"), 3),
    day_type = rep(c("weekday", "weekend"), each = 3),
    period = rep(c("am", "pm"), each = 3),
    stringsAsFactors = FALSE
  )
  ints <- data.frame(
    date = rep(dates, each = 2),
    site = rep(rep(c("north", "south"), 3), each = 2),
    day_type = rep(rep(c("weekday", "weekend"), each = 3), each = 2),
    period = rep(rep(c("am", "pm"), each = 3), each = 2),
    hours_fished = 2,
    catch_total = 1,
    catch_kept = 1,
    trip_status = "complete",
    stringsAsFactors = FALSE
  )
  # `site` is declared FIRST on purpose — that is the defect's trigger.
  d <- suppressWarnings(creel_design(
    cal,
    date = date, # nolint: object_usage_linter
    strata = c("site", strata_second),
    survey_type = "instantaneous"
  ))
  suppressWarnings(add_interviews(
    d,
    ints,
    effort = hours_fished, # nolint: object_usage_linter
    catch = catch_total, # nolint: object_usage_linter
    harvest = catch_kept, # nolint: object_usage_linter
    trip_status = trip_status # nolint: object_usage_linter
  ))
}

test_that("summarize_by_day_type() groups by the stratum named day_type, not the first one", {
  d <- make_two_strata_design()
  expect_identical(d$strata_cols, c("site", "day_type"))

  result <- suppressWarnings(summarize_by_day_type(d))

  # The load-bearing assertion: the day_type column holds day types. Before the
  # fix this held "north"/"south" — plausible stratum labels under a day_type
  # header, which is exactly why no test and no reader caught it.
  expect_setequal(result$day_type, c("weekday", "weekend"))
  expect_false(any(c("north", "south") %in% result$day_type))
})

test_that("summarize_by_day_type() reports the real day type split, not the site split", {
  d <- make_two_strata_design()
  result <- suppressWarnings(summarize_by_day_type(d))

  # 6 interviews on each of 3 weekdays / 3 weekend days. The site split is 6/6
  # too, so counts alone cannot distinguish the two groupings — the labels are
  # what carry the meaning, which is why the row identity is asserted here.
  weekday_n <- result$N[result$day_type == "weekday"]
  expect_identical(weekday_n, 6L)
  expect_identical(sum(result$N), 12L)
})

test_that("summarize_by_day_type() honours an explicit day_type_col", {
  d <- make_two_strata_design(strata_second = "period")
  result <- summarize_by_day_type(d, day_type_col = "day_type")

  # `day_type` is not a stratum in this design at all, so nothing could infer
  # it — the caller has to be able to say so.
  expect_setequal(result$day_type, c("weekday", "weekend"))
})

test_that("summarize_by_day_type() warns and names the column when it must guess", {
  d <- make_two_strata_design(strata_second = "period")

  # Neither stratum is named day_type. Falling back is defensible; doing it
  # silently is not, because the output is indistinguishable from a real one.
  expect_warning(
    summarize_by_day_type(d),
    "Using stratum.*site.*as the day type"
  )
  expect_warning(summarize_by_day_type(d), "none is named")
})

test_that("summarize_by_day_type() still uses the first stratum when it guesses", {
  d <- make_two_strata_design(strata_second = "period")
  result <- suppressWarnings(summarize_by_day_type(d))

  # The warning changes what the caller knows, not what the function returns.
  expect_setequal(result$day_type, c("north", "south"))
})

test_that("summarize_by_day_type() is silent for a single-stratum design", {
  d <- make_design_with_extended_interviews()
  expect_identical(length(d$strata_cols), 1L)

  # Inertness control: with one stratum there is nothing to choose between, so
  # the warning must not fire on the ordinary documented workflow.
  expect_no_warning(summarize_by_day_type(d))
})

test_that("summarize_by_day_type() rejects a day_type_col that is not one column name", {
  d <- make_two_strata_design()
  expect_error(
    summarize_by_day_type(d, day_type_col = c("site", "day_type")),
    "single non-empty column name"
  )
  expect_error(summarize_by_day_type(d, day_type_col = ""), "single non-empty")
})

test_that("summarize_by_day_type() names the missing column when day_type_col is absent", {
  d <- make_two_strata_design()
  # Matching only "not_a_column" would pass against R's own "unused argument"
  # error, i.e. it would pass on a build with no day_type_col at all. Asserting
  # where the column is absent FROM is what pins this to the real guard.
  expect_error(
    summarize_by_day_type(d, day_type_col = "not_a_column"),
    "absent from"
  )
  expect_error(
    summarize_by_day_type(d, day_type_col = "not_a_column"),
    "design\\$interviews"
  )
})
