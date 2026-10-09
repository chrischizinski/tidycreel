# GH #463: on a bus-route or ice design, a numeric p_period was read as a
# column POSITION of the sampling frame. `p_period = 1` (the period was
# certain to be sampled) selected column 1; with p_site there and constant
# within the circuit, every check passed and the inclusion probability became
# p_site^2 -- half its value -- with no error and no warning.

fpp_frame <- function() {
  # p_site first and constant, the arrangement that let the old code pass.
  data.frame(p_site = c(0.5, 0.5), site = c("S1", "S2"), circuit = "C1", ones = 1,
             stringsAsFactors = FALSE)
}

fpp_design <- function(...) {
  set.seed(463)
  cal <- build_property_calendar(6L)
  d <- creel_design(cal, date = date, strata = day_type, survey_type = "bus_route",
                    sampling_frame = fpp_frame(), site = site, circuit = circuit,
                    p_site = p_site, ...)
  ints <- build_trip_interviews_for_tests(cal, n_interviews = 24L, site_ids = c("S1", "S2"),
                                          circuit_id = "C1")
  suppressMessages(suppressWarnings(add_interviews(
    d, ints, catch = catch_total, effort = hours_fished, harvest = catch_kept,
    n_anglers = n_anglers, trip_status = trip_status, trip_duration = trip_duration,
    n_counted = n_counted, n_interviewed = n_interviewed
  )))
}

test_that("#463: bus-route p_period = 1 is the number one, not the first column", {
  number <- fpp_design(p_period = 1)
  column <- fpp_design(p_period = ones)
  expect_identical(number$bus_route$data$.pi_i, c(0.5, 0.5))
  # The estimate is what the user sees: under the old code the number gave
  # twice the effort of the column holding the same value.
  en <- suppressMessages(suppressWarnings(estimate_effort(number)))$estimates
  ec <- suppressMessages(suppressWarnings(estimate_effort(column)))$estimates
  expect_equal(en$estimate, ec$estimate)
  expect_equal(en$se, ec$se)
})

test_that("#463: a p_period held in a variable or named as a string still resolves", {
  x <- 1
  expect_identical(fpp_design(p_period = x)$bus_route$data$.pi_i, c(0.5, 0.5))
  expect_identical(fpp_design(p_period = "ones")$bus_route$p_period_col, "ones")
})

test_that("#463: a bus-route p_period outside (0, 1] is refused", {
  # 2 selected column 2 before, and its values happened to be valid.
  expect_error(fpp_design(p_period = 2), "\\(0, 1\\]", class = "creel_error_invalid_input")
})

test_that("#463: ice p_period = 1 is the number one, and a typo is refused", {
  isf <- example_ice_sampling_frame
  cal <- unique(isf[, c("date", "day_type")])
  ice <- function(...) {
    suppressWarnings(creel_design(cal, date = date, strata = day_type, survey_type = "ice",
                                  effort_type = "time_on_ice", sampling_frame = isf, ...))
  }
  # Column 1 of this frame is the date, which became the inclusion probability.
  expect_identical(unique(ice(p_period = 1)$bus_route$data$.pi_i), 1)
  expect_identical(ice(p_period = p_period)$ice$p_period_col, "p_period")
  # A name that is not a column was silently ignored on this path.
  expect_error(ice(p_period = "p_perod"), "column of", class = "creel_error_invalid_input")
  # Ice skips the bus-route range check, so nothing refused this before.
  expect_error(
    suppressWarnings(creel_design(cal, date = date, strata = day_type, survey_type = "ice",
                                  effort_type = "time_on_ice", p_period = 1.5)),
    "\\(0, 1\\]", class = "creel_error_invalid_input"
  )
})

test_that("#463: tidyselect helpers and a variable holding a name still select the column (review)", {
  # The first fix decided "column" only from a bare name, which dropped the
  # selector routes the old tidyselect-first code supported.
  cn <- "ones"
  expect_identical(fpp_design(p_period = all_of(cn))$bus_route$p_period_col, "ones")
  expect_identical(fpp_design(p_period = tidyselect::any_of("ones"))$bus_route$p_period_col, "ones")
  expect_identical(fpp_design(p_period = cn)$bus_route$p_period_col, "ones")
  # ... and none of them warns (evaluating all_of() outside a selection does).
  expect_no_warning(creel_design(build_property_calendar(6L), date = date, strata = day_type,
                                 survey_type = "bus_route", sampling_frame = fpp_frame(),
                                 site = site, circuit = circuit, p_site = p_site,
                                 p_period = all_of(cn)))
  # Arithmetic that gives a number is a number, not a position.
  expect_identical(fpp_design(p_period = 2 - 1)$bus_route$data$.pi_i, c(0.5, 0.5))
})

test_that("#463: a p_period that fails to evaluate reports why (review)", {
  expect_error(fpp_design(p_period = no_such_object), "no_such_object")
})
