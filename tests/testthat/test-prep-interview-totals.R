# GH #560: add_interviews() needs a per-interview catch total, but catch is
# recorded long (interview x species x fate). Every analysis aggregated it by
# hand, with "no row = zero" assumed silently. prep_interview_totals() does the
# aggregation with the add_catch() model and makes the absent-row rule explicit.

pit <- function(iv, ct, absent = "zero") {
  prep_interview_totals(iv, ct,
    interview_uid = interview_id, catch_uid = interview_id,
    species = species, count = count, catch_type = catch_type, absent = absent
  )
}

test_that("totals agree with the per-species catch model add_catch() uses", {
  # The estimators resolve catch per species-interview pair through
  # species_counts_per_interview(); the interview total must be that, summed
  # over species, or a rate built from catch_total and one built from the
  # catch table would disagree on the same data.
  bare <- example_interviews[setdiff(names(example_interviews), c("catch_total", "catch_kept"))]
  out <- pit(bare, example_catch)
  for (fate in c("caught", "harvested", "released")) {
    per_sp <- do.call(rbind, lapply(unique(example_catch$species), function(sp) {
      tidycreel:::species_counts_per_interview(
        example_catch, sp, fate,
        uid_col = "interview_id", species_col = "species",
        type_col = "catch_type", count_col = "count"
      )
    }))
    s <- tapply(per_sp$count, as.character(per_sp$uid), sum)
    want <- unname(s[as.character(out$interview_id)])
    want[is.na(want)] <- 0
    col <- c(caught = "catch_total", harvested = "harvest_total", released = "release_total")[[fate]]
    expect_equal(out[[col]], as.numeric(want), info = fate)
  }
})

test_that("a pair's own caught row wins; without one, catch is harvested + released", {
  iv <- data.frame(interview_id = c("a", "b"))
  ct <- data.frame(
    interview_id = c("a", "a", "a", "b", "b"),
    species = c("walleye", "walleye", "walleye", "bass", "bass"),
    count = c(7, 2, 3, 1, 4),
    catch_type = c("caught", "harvested", "released", "harvested", "released")
  )
  out <- pit(iv, ct)
  expect_equal(out$catch_total, c(7, 5))
  expect_equal(out$harvest_total, c(2, 1))
  expect_equal(out$release_total, c(3, 4))
})

test_that("an interview with no catch rows is zero or unknown, as the user states", {
  iv <- data.frame(interview_id = c("a", "b"))
  ct <- data.frame(interview_id = "a", species = "walleye", count = 2, catch_type = "harvested")
  expect_equal(pit(iv, ct, "zero")$catch_total, c(2, 0))
  expect_equal(pit(iv, ct, "unknown")$catch_total, c(2, NA))
  expect_equal(pit(iv, ct, "unknown")$harvest_total, c(2, NA))
})

test_that("the absent-row rule has no default", {
  expect_error(
    prep_interview_totals(example_interviews, example_catch,
      interview_uid = interview_id, catch_uid = interview_id,
      species = species, count = count, catch_type = catch_type
    ),
    "absent"
  )
})

test_that("unknown counts, unknown fates and orphan rows are refused", {
  iv <- data.frame(interview_id = "a")
  ct <- data.frame(interview_id = "a", species = "walleye", count = NA_real_, catch_type = "caught")
  expect_error(pit(iv, ct), "NA")
  ct$count <- 1
  ct$catch_type <- "kept"
  expect_error(pit(iv, ct), "kept")
  ct$catch_type <- "caught"
  ct$interview_id <- "z"
  expect_error(pit(iv, ct), "not in")
})

test_that("rebuilt totals equal the shipped totals for every example interview", {
  # GH #569: example_catch once covered 12 of the 22 interviews, so species
  # results on the shipped data counted ten parties as catching nothing. Every
  # interview caught fish, so the catch table must cover all of them and
  # rebuild exactly the shipped catch_total and catch_kept.
  bare <- example_interviews[setdiff(names(example_interviews), c("catch_total", "catch_kept"))]
  out <- pit(bare, example_catch)
  expect_setequal(unique(example_catch$interview_id), example_interviews$interview_id)
  expect_equal(out$catch_total, as.numeric(example_interviews$catch_total))
  expect_equal(out$harvest_total, as.numeric(example_interviews$catch_kept))
})

test_that("a repeated interview id is refused, not given its catch twice", {
  iv <- data.frame(interview_id = c("a", "a"))
  ct <- data.frame(interview_id = "a", species = "walleye", count = 2, catch_type = "harvested")
  expect_error(pit(iv, ct), "more than once")
})

test_that("species estimates on the example data sum to the overall estimates (#569)", {
  # What the coverage gap broke in practice: with ten interviews missing from
  # example_catch, the species totals summed to 1,525 fish against 1,955 from
  # catch_total. The example data must not teach that the two can disagree.
  q <- function(x) suppressWarnings(suppressMessages(x))
  d <- creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  d <- add_counts(d, example_counts)
  d <- q(add_interviews(d, example_interviews,
    catch = catch_total, effort = hours_fished, harvest = catch_kept, # nolint: object_usage_linter
    trip_status = trip_status # nolint: object_usage_linter
  ))
  d <- q(add_catch(d, example_catch,
    catch_uid = interview_id, interview_uid = interview_id, # nolint: object_usage_linter
    species = species, count = count, catch_type = catch_type # nolint: object_usage_linter
  ))
  for (f in list(estimate_catch_rate, estimate_total_catch, estimate_harvest_rate, estimate_total_harvest)) {
    overall <- q(f(d))$estimates$estimate
    by_species <- q(f(d, by = species))$estimates$estimate # nolint: object_usage_linter
    expect_equal(sum(by_species), overall, tolerance = 1e-10)
  }
})
