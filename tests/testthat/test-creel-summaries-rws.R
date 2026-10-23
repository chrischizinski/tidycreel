# GH #558: released-while-sought (RWS) rates complete the while-sought trio.
# CWS, HWS and RWS now share one body (summarize_sought_rates()), so they use
# the same interviews and the same exclusions and differ only in the fate.

rws_design <- function(catch = example_catch) {
  d <- creel_design(example_calendar, date = date, strata = day_type)
  d <- suppressWarnings(suppressMessages(add_interviews(
    d, example_interviews,
    catch = catch_total, effort = hours_fished, harvest = catch_kept,
    trip_status = trip_status, species_sought = species_sought,
    angler_type = angler_type, n_anglers = n_anglers
  )))
  suppressWarnings(suppressMessages(add_catch(
    d, catch,
    catch_uid = interview_id, interview_uid = interview_id,
    species = species, count = count, catch_type = catch_type
  )))
}

test_that("summarize_rws_rates() returns its own class and the HWS columns", {
  r <- summarize_rws_rates(rws_design(), by = species_sought)
  h <- summarize_hws_rates(rws_design(), by = species_sought)
  expect_s3_class(r, "creel_summary_rws_rates")
  expect_identical(names(r), names(h))
  expect_identical(r$N, h$N)
})

test_that("with caught inferred, RWS = CWS - HWS for every group", {
  # The identity that pins what RWS counts. When no pair records a caught row,
  # each party's catch of its target IS harvested + released, so its released
  # rate is its caught rate minus its harvested rate, and the group means
  # (over the same interviews) obey the same identity.
  inferred <- example_catch[example_catch$catch_type != "caught", ]
  d <- rws_design(inferred)
  cws <- summarize_cws_rates(d, by = species_sought)
  hws <- summarize_hws_rates(d, by = species_sought)
  rws <- summarize_rws_rates(d, by = species_sought)
  expect_equal(rws$mean_rate, cws$mean_rate - hws$mean_rate)
  # not vacuous: some party released some of its target
  expect_true(any(rws$mean_rate > 0, na.rm = TRUE))
})

test_that("a party that released none of its target is a zero, not dropped", {
  # Remove every released row: every seeker released none. That is a recorded
  # zero (the sheet lists fish by fate), so N is unchanged and the rate is 0.
  no_release <- example_catch[example_catch$catch_type != "released", ]
  r <- summarize_rws_rates(rws_design(no_release), by = species_sought)
  base <- summarize_rws_rates(rws_design(), by = species_sought)
  expect_identical(r$N, base$N)
  expect_true(all(r$mean_rate[r$N > 0] == 0))
})

test_that("an unrecorded sought species is excluded and counted, as for CWS and HWS", {
  iv <- example_interviews
  iv$species_sought[1:3] <- NA
  d <- creel_design(example_calendar, date = date, strata = day_type)
  d <- suppressWarnings(suppressMessages(add_interviews(
    d, iv,
    catch = catch_total, effort = hours_fished, harvest = catch_kept,
    trip_status = trip_status, species_sought = species_sought, n_anglers = n_anglers
  )))
  d <- suppressWarnings(suppressMessages(add_catch(
    d, example_catch,
    catch_uid = interview_id, interview_uid = interview_id,
    species = species, count = count, catch_type = catch_type
  )))
  r <- summarize_rws_rates(d)
  expect_equal(r$n_unknown_target, 3L)
  expect_identical(r$n_unknown_target, summarize_hws_rates(d)$n_unknown_target)
})

test_that("guards name the function the user called", {
  d <- creel_design(example_calendar, date = date, strata = day_type)
  d <- suppressWarnings(suppressMessages(add_interviews(
    d, example_interviews,
    catch = catch_total, effort = hours_fished, trip_status = trip_status,
    species_sought = species_sought, n_anglers = n_anglers
  )))
  err <- tryCatch(summarize_rws_rates(d), error = function(e) e)
  expect_match(conditionMessage(err), "No catch data")
  expect_identical(deparse(conditionCall(err)[[1]]), "summarize_rws_rates")
  err_c <- tryCatch(summarize_cws_rates(d), error = function(e) e)
  expect_identical(deparse(conditionCall(err_c)[[1]]), "summarize_cws_rates")
})
