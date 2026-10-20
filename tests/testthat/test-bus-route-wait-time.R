# Bus-route site weights from wait and circuit time (GH #539).
#
# On a bus route the clerk visits every site on every pass, so a site's weight
# is not a probability of choosing it: it is the share of the circuit spent
# waiting there, wait / circuit time, with the circuit time including travel
# (Robson & Jones 1989, eq. 12; Pollock et al. 1994, eq. 15.10). The shares sum
# to less than 1 whenever the route has travel time. Before #539, p_site had to
# sum to 1, which refused the published weights; wait shares rescaled to sum to
# 1 returned the published total times (total wait / circuit time), 0.54 here,
# with no warning.

# Pollock et al. (1994) Table 15.15: one day of direct-expansion interviews on
# a five-site route. Circuit 360 min, waits 30/30/15/60/60 min (195 in all),
# morning or afternoon chosen with probability 0.5. Site 3 had no anglers.
pollock_waits <- c(30, 30, 15, 60, 60)

pollock_interviews <- function(dates) {
  one_day <- data.frame(
    site = c("1", "1", "2", "2", "4", "4", "4", "5"),
    trip_min = c(135, 165, 175, 215, 150, 145, 168, 225),
    catch = c(3, 2, 0, 1, 1, 2, 3, 1),
    trip_status = "complete"
  )
  out <- do.call(rbind, lapply(dates, function(d) cbind(date = d, one_day)))
  out$day_type <- "weekday"
  out$circuit <- "am_pm"
  # Every party at a site was interviewed.
  out$n_counted <- stats::ave(rep(1L, nrow(out)), out$date, out$site, FUN = length)
  out$n_interviewed <- out$n_counted
  out
}

# Two copies of the published day: one day is a single PSU, which has no
# between-day variance. Each day's total is the published one, so the
# sampled-day total is twice it.
pollock_dates <- as.Date(c("2024-06-01", "2024-06-02"))

pollock_design <- function(frame, ...) {
  cal <- data.frame(date = pollock_dates, day_type = "weekday")
  d <- creel_design(cal,
    date = date, strata = day_type, survey_type = "bus_route",
    sampling_frame = frame, site = site, circuit = circuit, p_period = 0.5, ...
  )
  # Pollock's effort is party time (trip duration per party), so no n_anglers:
  # the warning that the effort is per party is the expected one here.
  suppressMessages(expect_warning(
    d <- add_interviews(d, pollock_interviews(pollock_dates),
      effort = trip_min, catch = catch, trip_status = trip_status,
      n_counted = n_counted, n_interviewed = n_interviewed
    ),
    "n_anglers"
  ))
  d
}

wait_frame <- function(waits = pollock_waits, circuit_time = 360) {
  data.frame(
    site = as.character(1:5), circuit = "am_pm",
    wait = waits, circuit_min = circuit_time
  )
}

test_that("wait / circuit time reproduces Pollock et al. (1994) Table 15.16 effort", {
  d <- pollock_design(wait_frame(), wait_time = wait, circuit_time = circuit_min)
  e <- suppressMessages(estimate_effort(d))
  # E = T * sum_i (1 / w_i) * sum_j e_ji / pi_j. Pollock prints 24,814.80 min
  # from site terms rounded to two decimals; unrounded it is 24,816 per day.
  published_unrounded <- 360 * sum(c(300, 390, 463, 225) / 0.5 / c(30, 30, 60, 60))
  expect_equal(published_unrounded, 24816)
  expect_equal(e$estimates$estimate, 2 * 24816)
  expect_equal(e$estimates$estimate / 2, 24814.80, tolerance = 1e-4)
})

test_that("wait / circuit time reproduces Pollock et al. (1994) Table 15.17 catch", {
  d <- pollock_design(wait_frame(), wait_time = wait, circuit_time = circuit_min)
  ct <- suppressMessages(estimate_total_catch(d))
  # C = 360 * (10/30 + 2/30 + 0/15 + 12/60 + 2/60) = 228 fish per day; Pollock
  # prints 227.88 from the rounded 0.633.
  expect_equal(ct$estimates$estimate, 2 * 228)
  expect_equal(ct$estimates$estimate / 2, 227.88, tolerance = 1e-3)
})

test_that("each site's p_site is its share of the circuit, and the shares sum below 1", {
  d <- pollock_design(wait_frame(), wait_time = wait, circuit_time = circuit_min)
  br <- d$bus_route$data
  expect_equal(br$.p_site, pollock_waits / 360)
  expect_equal(br$.pi_i, pollock_waits / 360 * 0.5)
  # The travel time (165 of 360 min) is why the shares sum below 1.
  expect_equal(sum(br$.p_site), 195 / 360)
})

test_that("wait shares squeezed to sum to 1 understate the total by wait / circuit time", {
  # The encoding #539 replaces, kept as the contrast: with p_site the only
  # route, this was the design-based choice available, and it returned 54% of
  # the published total.
  sf <- wait_frame()
  sf$p_site <- pollock_waits / sum(pollock_waits)
  shares <- suppressMessages(estimate_effort(pollock_design(sf, p_site = p_site)))
  circuit <- suppressMessages(estimate_effort(
    pollock_design(wait_frame(), wait_time = wait, circuit_time = circuit_min)
  ))
  expect_equal(
    shares$estimates$estimate / circuit$estimates$estimate,
    sum(pollock_waits) / 360
  )
})

test_that("with no travel time the two weightings agree", {
  # Waits filling the whole circuit make wait / circuit time a set of
  # selection shares summing to 1, the case p_site already covered.
  no_travel <- wait_frame(circuit_time = sum(pollock_waits))
  by_wait <- suppressMessages(estimate_effort(
    pollock_design(no_travel, wait_time = wait, circuit_time = circuit_min)
  ))
  no_travel$p_site <- pollock_waits / sum(pollock_waits)
  by_p <- suppressMessages(estimate_effort(pollock_design(no_travel, p_site = p_site)))
  expect_equal(by_wait$estimates$estimate, by_p$estimates$estimate)
  expect_equal(by_wait$estimates$se, by_p$estimates$se)
})

test_that("the site weighting is refused unless it is given one way, completely", {
  cal <- data.frame(date = pollock_dates, day_type = "weekday")
  sf <- wait_frame()
  sf$p_site <- 0.2
  br <- function(...) {
    creel_design(cal,
      date = date, strata = day_type, survey_type = "bus_route",
      sampling_frame = sf, site = site, circuit = circuit, p_period = 0.5, ...
    )
  }
  expect_error(
    br(p_site = p_site, wait_time = wait, circuit_time = circuit_min),
    "not both", class = "creel_error_invalid_input"
  )
  expect_error(br(wait_time = wait), "together", class = "creel_error_invalid_input")
  expect_error(br(circuit_time = circuit_min), "together", class = "creel_error_invalid_input")
  expect_error(br(), "wait_time", class = "creel_error_invalid_input")
})

test_that("waits that do not fit their circuit are refused", {
  cal <- data.frame(date = pollock_dates, day_type = "weekday")
  br <- function(sf) {
    creel_design(cal,
      date = date, strata = day_type, survey_type = "bus_route",
      sampling_frame = sf, site = site, circuit = circuit, p_period = 0.5,
      wait_time = wait, circuit_time = circuit_min
    )
  }
  # Total wait 195 min cannot fit a 150-min circuit.
  expect_error(br(wait_frame(circuit_time = 150)), "more than its circuit time",
    class = "creel_error_invalid_input"
  )
  # One circuit has one circuit time.
  expect_error(br(wait_frame(circuit_time = c(360, 360, 360, 360, 400))),
    "constant within each circuit", class = "creel_error_invalid_input"
  )
  # A zero or missing wait is reported as a wait, not as the p_site it became.
  expect_error(br(wait_frame(waits = c(30, 0, 15, 60, 60))), "wait",
    class = "creel_error_invalid_input"
  )
  expect_error(br(wait_frame(waits = c(30, NA, 15, 60, 60))), "wait",
    class = "creel_error_invalid_input"
  )
})

test_that("wait_time and circuit_time are refused on other survey types", {
  # They would otherwise be dropped without effect.
  cal <- data.frame(date = pollock_dates, day_type = "weekday")
  expect_error(
    creel_design(cal, date = date, strata = day_type, wait_time = wait),
    "apply only", class = "creel_error_invalid_input"
  )
})

test_that("a wait-weighted bus-route design survives write_design() and read_design()", {
  d <- pollock_design(wait_frame(), wait_time = wait, circuit_time = circuit_min)
  p <- file.path(withr::local_tempdir(), "bus-wait")
  write_design(d, p)
  m <- yaml::read_yaml(file.path(p, "manifest.yml"))
  expect_identical(m$steps[[1]]$args$wait_time, "wait")
  expect_identical(m$steps[[1]]$args$circuit_time, "circuit_min")
  expect_null(m$steps[[1]]$args$p_site)
  r <- suppressWarnings(suppressMessages(read_design(p)))
  expect_equal(r$bus_route$data$.pi_i, d$bus_route$data$.pi_i)
  expect_equal(
    suppressMessages(estimate_effort(r))$estimates$estimate,
    suppressMessages(estimate_effort(d))$estimates$estimate
  )
})

test_that("the new arguments come last, so positional calls bind as before", {
  # Inserted before effort_type, they shifted every later argument: an ice
  # design given effort_type as its 11th argument bound it to wait_time.
  f <- names(formals(creel_design))
  expect_identical(utils::tail(f, 2), c("wait_time", "circuit_time"))
  expect_identical(match("effort_type", f), 11L)
})
