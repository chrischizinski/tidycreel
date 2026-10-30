# Bus-route and ice totals expanded to the season (GH #591).
#
# The Horvitz-Thompson total sum(e_i / pi_i) covers the days worked. Expanding
# it scales each stratum by N_h / n_h, and n_h has to count every worked day,
# including days nobody fished. Those leave no interview, so the interviews
# cannot supply n_h: counting interview dates averages over the fished days
# only and inflates the season total, with no error. The calendar's register
# of sampled days (`creel_design(sampled = )`) supplies it instead.

q <- function(x) suppressWarnings(suppressMessages(x))

# 40 calendar days in two strata; 8 worked in each, of which the first two
# weekday and first weekend day had no anglers. Three sites on one circuit,
# p_period = 0.5 (the AM or PM half worked).
br_season <- function(worked_all = FALSE) {
  withr::local_seed(591)
  dates <- as.Date("2024-06-01") + 0:39
  cal <- data.frame(
    date = dates,
    day_type = ifelse(format(dates, "%u") %in% c("6", "7"), "weekend", "weekday")
  )
  wd <- which(cal$day_type == "weekday")
  we <- which(cal$day_type == "weekend")
  worked <- c(wd[seq(1, by = 3, length.out = 8)], we[1:8])
  cal$worked <- seq_len(nrow(cal)) %in% worked
  if (worked_all) cal$worked <- TRUE
  empty <- c(cal$date[wd[1]], cal$date[wd[4]], cal$date[we[1]])
  fished <- setdiff(cal$date[cal$worked], empty)
  iv <- do.call(rbind, lapply(fished, function(d) {
    k <- sample(2:5, 1)
    data.frame(
      date = as.Date(d, origin = "1970-01-01"),
      site = sample(c("S1", "S2", "S3"), k, replace = TRUE),
      circuit = "C1",
      hours_fished = round(stats::runif(k, 1, 5), 1),
      catch_total = stats::rpois(k, 3),
      catch_kept = 0L,
      trip_status = "complete",
      n_anglers = 1L,
      n_counted = 2L,
      n_interviewed = 1L
    )
  }))
  iv$day_type <- cal$day_type[match(iv$date, cal$date)]
  iv$catch_kept <- stats::rbinom(nrow(iv), iv$catch_total, 0.4)
  iv$interview_id <- seq_len(nrow(iv))
  list(cal = cal, iv = iv, empty = empty)
}

br_frame <- data.frame(
  site = c("S1", "S2", "S3"), circuit = "C1",
  p_site = c(0.5, 0.3, 0.2), p_period = 0.5
)

br_design <- function(x, register = TRUE) {
  d <- if (register) {
    q(creel_design(x$cal,
      date = date, strata = day_type, survey_type = "bus_route",
      sampling_frame = br_frame, site = site, circuit = circuit,
      p_site = p_site, p_period = p_period, sampled = worked
    ))
  } else {
    q(creel_design(x$cal,
      date = date, strata = day_type, survey_type = "bus_route",
      sampling_frame = br_frame, site = site, circuit = circuit,
      p_site = p_site, p_period = p_period
    ))
  }
  q(add_interviews(d, x$iv,
    catch = catch_total, effort = hours_fished, harvest = catch_kept,
    trip_status = trip_status, n_anglers = n_anglers,
    n_counted = n_counted, n_interviewed = n_interviewed
  ))
}

# The expansion written from its definition, not read back from the code:
# daily HT totals over every worked day (empty ones 0), N_h / n_h times their
# sum, and the with-replacement stratified variance N_h^2 s_h^2 / n_h.
hand_expansion <- function(x) {
  pi <- br_frame$p_site[match(x$iv$site, br_frame$site)] * 0.5
  contrib <- x$iv$hours_fished * 2 / pi
  out <- c(estimate = 0, var = 0)
  for (h in c("weekday", "weekend")) {
    days <- x$cal$date[x$cal$worked & x$cal$day_type == h]
    y <- vapply(days, function(d) sum(contrib[x$iv$date == d]), numeric(1))
    n_h <- length(days)
    n_pop <- sum(x$cal$day_type == h)
    out["estimate"] <- out["estimate"] + n_pop / n_h * sum(y)
    out["var"] <- out["var"] + n_pop^2 * stats::var(y) / n_h
  }
  out
}

test_that("the expanded total is N_h / n_h times the worked days' totals, empty days included", {
  x <- br_season()
  d <- br_design(x)
  res <- q(estimate_effort(d, target = "period_total"))$estimates
  hand <- hand_expansion(x)
  expect_equal(res$estimate, unname(hand["estimate"]), tolerance = 1e-10)
  expect_equal(res$se^2, unname(hand["var"]), tolerance = 1e-8)

  # Without the empty days n_h is 7 and 7, not 8 and 8: each fished day then
  # stands for more of the season and the total comes out too large. This is
  # the error the register exists to prevent.
  fished_only <- x
  fished_only$cal$worked <- fished_only$cal$worked & !fished_only$cal$date %in% x$empty
  too_big <- hand_expansion(fished_only)["estimate"]
  expect_gt(unname(too_big), res$estimate)
})

test_that("with every day worked, the period total is the sampled-day total", {
  # N_h / n_h = 1: expansion must be a no-op, estimate and SE, for effort and
  # every total.
  x <- br_season(worked_all = TRUE)
  x$iv <- x$iv # all 40 days worked; the ones without interviews are empty days
  d <- br_design(x)
  for (fn in list(estimate_effort, estimate_total_catch, estimate_total_harvest)) {
    a <- q(fn(d))$estimates
    b <- q(fn(d, target = "period_total"))$estimates
    expect_equal(b$estimate, a$estimate, tolerance = 1e-10)
    expect_equal(b$se, a$se, tolerance = 1e-10)
  }
})

test_that("a design without a register keeps today's sampled-day total exactly", {
  # Empty days are invisible without the register, as before; nothing about
  # the sampled_days path changes for existing designs.
  x <- br_season()
  with_reg <- q(estimate_effort(br_design(x)))$estimates
  without <- q(estimate_effort(br_design(x, register = FALSE)))$estimates
  expect_equal(without$estimate, with_reg$estimate, tolerance = 1e-10)
  # The register adds the empty days as zero days, which widens the
  # between-day variance; without it they are simply absent.
  expect_false(isTRUE(all.equal(without$se, with_reg$se)))
})

test_that("totals expand on the same basis as effort and say which target they are", {
  x <- br_season()
  d <- br_design(x)
  sd <- q(estimate_total_catch(d))
  pt <- q(estimate_total_catch(d, target = "period_total"))
  expect_identical(pt$effort_target, "period_total")
  expect_identical(sd$effort_target, "sampled_days")
  # Per stratum, the period total is N_h / 8 times the sampled-day total.
  sd_h <- q(estimate_total_catch(d, by = day_type))$estimates
  pt_h <- q(estimate_total_catch(d, by = day_type, target = "period_total"))$estimates
  n_pop <- table(x$cal$day_type)[sd_h$day_type]
  expect_equal(pt_h$estimate, as.numeric(n_pop) / 8 * sd_h$estimate, tolerance = 1e-10)
  expect_equal(pt$estimates$estimate, sum(pt_h$estimate), tolerance = 1e-8)
})

test_that("grouped expansion reports real groups only, and they sum to the total", {
  x <- br_season()
  d <- br_design(x)
  total <- q(estimate_effort(d, target = "period_total"))$estimates
  by_site <- q(estimate_effort(d, target = "period_total", by = site))$estimates
  expect_setequal(by_site$site, c("S1", "S2", "S3"))
  expect_equal(sum(by_site$estimate), total$estimate, tolerance = 1e-8)
  expect_equal(sum(by_site$n), nrow(x$iv))
  expect_equal(sum(by_site$proportion), 1, tolerance = 1e-10)

  by_type <- q(estimate_effort(d, target = "period_total", by = day_type))$estimates
  expect_equal(sum(by_type$estimate), total$estimate, tolerance = 1e-8)
})

test_that("an expanded target without the register is refused, not guessed", {
  d <- br_design(br_season(), register = FALSE)
  expect_error(estimate_effort(d, target = "period_total"), class = "creel_error_sampled_register")
  expect_error(estimate_total_catch(d, target = "period_total"), class = "creel_error_sampled_register")
})

test_that("an interview on a day the register says was not worked is refused", {
  x <- br_season()
  x$cal$worked[x$cal$date == x$iv$date[1]] <- FALSE
  expect_error(br_design(x), class = "creel_error_sampled_register")
})

test_that("a calendar stratum with no worked day is refused for expansion only", {
  x <- br_season()
  x$cal$worked[x$cal$day_type == "weekend"] <- FALSE
  x$iv <- x$iv[x$iv$day_type == "weekday", ]
  d <- br_design(x)
  expect_error(estimate_effort(d, target = "period_total"), class = "creel_error_sampled_register")
  expect_no_error(q(estimate_effort(d)))
})

test_that("the register must be a complete logical column, on bus-route or ice designs", {
  x <- br_season()
  bad <- x$cal
  bad$worked[3] <- NA
  expect_error(
    creel_design(bad,
      date = date, strata = day_type, survey_type = "bus_route",
      sampling_frame = br_frame, site = site, circuit = circuit,
      p_site = p_site, p_period = p_period, sampled = worked
    ),
    class = "creel_error_sampled_register"
  )
  expect_error(
    creel_design(x$cal, date = date, strata = day_type, sampled = worked),
    class = "creel_error_sampled_register"
  )
})

test_that("ice designs expand through the same register", {
  sf <- example_ice_sampling_frame
  sf$worked <- TRUE
  extra <- sf
  extra$date <- extra$date + 100
  extra$worked <- FALSE
  d <- q(creel_design(rbind(sf, extra),
    date = date, strata = day_type, survey_type = "ice",
    effort_type = "time_on_ice", p_period = 0.5, sampled = worked
  ))
  d <- q(add_interviews(d, example_ice_interviews,
    catch = walleye_catch, effort = hours_on_ice, harvest = walleye_kept,
    trip_status = trip_status, n_counted = n_counted,
    n_interviewed = n_interviewed, n_anglers = n_anglers
  ))
  sd <- q(estimate_effort(d))$estimates
  pt <- q(estimate_effort(d, target = "period_total"))$estimates
  # 24 calendar days, 12 worked: twice the sampled-day total and SE.
  expect_equal(pt$estimate, 2 * sd$estimate, tolerance = 1e-10)
  expect_equal(pt$se, 2 * sd$se, tolerance = 1e-10)
})

test_that("species totals expand too, and are labelled with the target they used", {
  # One species holding every fish: its expanded total is the expanded total.
  # The species path builds its own result, and once labelled every species
  # total "sampled_days" whatever the target (the GH #520 mislabel).
  x <- br_season()
  d <- br_design(x)
  iv <- x$iv
  catch <- rbind(
    data.frame(interview_id = iv$interview_id, species = "perch", count = iv$catch_kept, catch_type = "harvested"),
    data.frame(
      interview_id = iv$interview_id, species = "perch",
      count = iv$catch_total - iv$catch_kept, catch_type = "released"
    )
  )
  d <- q(add_catch(d, catch[catch$count > 0, ],
    catch_uid = interview_id, interview_uid = interview_id,
    species = species, count = count, catch_type = catch_type
  ))
  for (fn in list(estimate_total_catch, estimate_total_harvest, estimate_total_release)) {
    all <- q(fn(d, target = "period_total"))
    sp <- q(fn(d, by = species, target = "period_total"))
    expect_equal(sp$estimates$estimate, all$estimates$estimate, tolerance = 1e-10)
    expect_equal(sp$estimates$se, all$estimates$se, tolerance = 1e-10)
    expect_identical(sp$effort_target, "period_total")
  }
})
