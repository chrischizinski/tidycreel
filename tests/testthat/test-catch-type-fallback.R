# GH #318 -- the `add_catch()` catch-type model is defined per SPECIES-INTERVIEW
# pair, not per species. `make_species_catch_for_interviews()` decided the
# "caught" fallback once per species across the whole catch table, so a pair
# holding only harvested/released rows read as a catch of ZERO the moment any
# other pair for that species recorded a caught row.
#
# On the package's own example data that made reported harvest EXCEED reported
# catch for all three species -- the contradiction CATCH-04 forbids per row.
#
# The fixture below is built so that the old rule and the new one cannot agree.
# `example_catch` cannot do that job: every pair there that has a caught row has
# `caught == harvested + released`, so it cannot tell "prefer the pair's caught
# row" apart from "always sum the sub-rows". Interview 1 breaks that tie
# deliberately, with caught (10) strictly greater than harvested + released (5).

make_mixed_catch_design <- function() {
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-08", "2024-06-09")),
    day_type = c("weekday", "weekday", "weekend", "weekend"),
    stringsAsFactors = FALSE
  )

  # Per-interview bass catch the model implies, used for catch_total below and
  # pinned one by one in the tests.
  bass_expected <- c(10, 5, 2, 3, 6, 0)

  interviews <- data.frame(
    interview_id = 1:6,
    date = as.Date(rep(
      c("2024-06-01", "2024-06-02", "2024-06-08", "2024-06-09"),
      length.out = 6
    )),
    catch_total = bass_expected + 1,
    hours_fished = c(2, 3, 2.5, 4, 1.5, 3),
    trip_status = rep("incomplete", 6),
    trip_duration = c(2, 3, 2.5, 4, 1.5, 3),
    stringsAsFactors = FALSE
  )

  catch <- data.frame(
    interview_id = c(
      1L, 1L, 1L, # caught row AND both sub-types; caught (10) > h + r (5)
      2L, 2L, # sub-types only
      3L, # harvested only
      4L, # released only
      5L, # caught only
      # interview 6 records no bass at all
      1L, 2L, 3L, 4L, 5L, 6L # panfish: never a caught row, anywhere
    ),
    species = c(rep("bass", 8), rep("panfish", 6)),
    count = c(
      10, 3, 2,
      4, 1,
      2,
      3,
      6,
      1, 1, 1, 1, 1, 1
    ),
    catch_type = c(
      "caught", "harvested", "released",
      "harvested", "released",
      "harvested",
      "released",
      "caught",
      rep("harvested", 6)
    ),
    stringsAsFactors = FALSE
  )

  design <- suppressMessages(creel_design(cal, date = date, strata = day_type))
  design <- suppressMessages(suppressWarnings(add_interviews(
    design, interviews,
    catch = catch_total, effort = hours_fished,
    trip_status = trip_status, trip_duration = trip_duration
  )))
  suppressMessages(suppressWarnings(add_catch(
    design, catch,
    catch_uid = interview_id, interview_uid = interview_id,
    species = species, count = count, catch_type = catch_type
  )))
}

bass_counts <- function(design, type = "caught") {
  out <- tidycreel:::make_species_catch_for_interviews(design, "bass", type)
  out$.species_count[order(out$interview_id)]
}

test_that("CATCH-FB-00: the fixture actually mixes the two shapes", {
  # If this stops holding, every test below can pass under the old rule and the
  # file stops testing anything. Both shapes must be present for bass at once:
  # at least one pair with a caught row, and at least one without.
  design <- make_mixed_catch_design()
  ct <- design[["catch"]]
  bass <- ct[ct$species == "bass", , drop = FALSE]
  with_caught <- unique(bass$interview_id[bass$catch_type == "caught"])
  sub_only <- setdiff(unique(bass$interview_id), with_caught)

  expect_gt(length(with_caught), 0L)
  expect_gt(length(sub_only), 0L)

  # And interview 1's caught row must NOT equal its harvested + released, or a
  # rule that always summed the sub-rows would be indistinguishable from one
  # that reads the caught row.
  iv1 <- bass[bass$interview_id == 1L, , drop = FALSE]
  expect_equal(iv1$count[iv1$catch_type == "caught"], 10)
  expect_equal(sum(iv1$count[iv1$catch_type != "caught"]), 5)
})

test_that("CATCH-FB-01 (#318): a pair with no caught row derives harvested + released", {
  # The defect. Interviews 2, 3 and 4 record only sub-types, and under the
  # table-level rule all three read as 0 because interviews 1 and 5 happen to
  # carry caught rows for the same species.
  design <- make_mixed_catch_design()
  counts <- bass_counts(design)

  expect_equal(counts[[2]], 5) # 4 harvested + 1 released
  expect_equal(counts[[3]], 2) # harvested only
  expect_equal(counts[[4]], 3) # released only
})

test_that("CATCH-FB-02 (#318): a pair WITH a caught row uses it, not its sub-rows", {
  # The other direction, and the reason the fixture sets caught (10) above
  # harvested + released (5): over-correcting into "always sum the sub-rows"
  # would report 5 here. A caught row is the pair's total; fish with no
  # recorded disposition are legitimate (CATCH-06 warns, it does not abort).
  design <- make_mixed_catch_design()
  counts <- bass_counts(design)

  expect_equal(counts[[1]], 10)
  expect_equal(counts[[5]], 6)
})

test_that("CATCH-FB-03 (#318): a pair with no rows at all is still zero", {
  # The absence that DOES mean zero, and the one the fix must not disturb.
  # add_catch() documents it: an angler who caught none of a species need not
  # appear in the catch table. Interview 6 records no bass.
  design <- make_mixed_catch_design()
  expect_equal(bass_counts(design)[[6]], 0)
})

test_that("CATCH-FB-04 (#318): a species with no caught row anywhere is unchanged", {
  # Anti-regression for the path the old rule got right. panfish never records
  # a caught row, so every pair derives -- exactly as before.
  design <- make_mixed_catch_design()
  out <- tidycreel:::make_species_catch_for_interviews(design, "panfish", "caught")
  expect_equal(out$.species_count[order(out$interview_id)], rep(1, 6))
})

test_that("CATCH-FB-05 (#318): harvested and released are untouched by the caught rule", {
  # "harvested" and "released" are recorded types with nothing to derive. A
  # pair with no row of that type harvested or released none -- that really is
  # a zero, and reading it as one is not the bug.
  design <- make_mixed_catch_design()

  expect_equal(bass_counts(design, "harvested"), c(3, 4, 2, 0, 0, 0))
  expect_equal(bass_counts(design, "released"), c(2, 1, 0, 3, 0, 0))
})

test_that("CATCH-FB-06 (#318): reported catch is not below reported harvest + release", {
  # The invariant the defect broke, checked end to end on the SHIPPED example
  # data rather than on a fixture written for this test. Before the fix all
  # three species reported more harvest than catch.
  data("example_calendar", package = "tidycreel")
  data("example_interviews", package = "tidycreel")
  data("example_catch", package = "tidycreel")

  d <- suppressMessages(creel_design(example_calendar, date = date, strata = day_type))
  d <- suppressWarnings(suppressMessages(add_interviews(
    d, example_interviews,
    catch = catch_total, effort = hours_fished,
    harvest = catch_kept, trip_status = trip_status
  )))
  d <- suppressWarnings(add_catch(
    d, example_catch,
    catch_uid = interview_id, interview_uid = interview_id,
    species = species, count = count, catch_type = catch_type
  ))

  for (sp in unique(example_catch$species)) {
    caught <- sum(tidycreel:::make_species_catch_for_interviews(d, sp, "caught")$.species_count)
    harvested <- sum(tidycreel:::make_species_catch_for_interviews(d, sp, "harvested")$.species_count)
    released <- sum(tidycreel:::make_species_catch_for_interviews(d, sp, "released")$.species_count)

    expect_gte(caught, harvested + released)
    # Not a vacuous pass on a species that reports nothing.
    expect_gt(caught, 0)
  }
})

test_that("CATCH-FB-07 (#318): the estimator path carries the corrected total", {
  # The helper feeds estimate_total_catch(); this pins that the fix reaches the
  # estimate rather than stopping at the helper. Catch cannot come in below
  # harvest for the same species.
  data("example_calendar", package = "tidycreel")
  data("example_interviews", package = "tidycreel")
  data("example_counts", package = "tidycreel")
  data("example_catch", package = "tidycreel")

  d <- suppressMessages(creel_design(example_calendar, date = date, strata = day_type))
  d <- suppressWarnings(suppressMessages(add_interviews(
    d, example_interviews,
    catch = catch_total, effort = hours_fished,
    harvest = catch_kept, trip_status = trip_status
  )))
  d <- suppressWarnings(suppressMessages(add_counts(d, example_counts)))
  d <- suppressWarnings(add_catch(
    d, example_catch,
    catch_uid = interview_id, interview_uid = interview_id,
    species = species, count = count, catch_type = catch_type
  ))

  catch_res <- suppressWarnings(estimate_total_catch(d, by = species))
  harv_res <- suppressWarnings(estimate_total_harvest(d, by = species))
  catch_est <- catch_res$estimates
  harv_est <- harv_res$estimates

  for (sp in unique(as.character(catch_est$species))) {
    c_val <- sum(catch_est$estimate[as.character(catch_est$species) == sp])
    h_val <- sum(harv_est$estimate[as.character(harv_est$species) == sp])
    expect_gte(c_val, h_val)
    expect_gt(c_val, 0)
  }
})
