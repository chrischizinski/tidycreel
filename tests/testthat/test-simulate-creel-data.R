test_params <- list(
  effort         = list(gamma_shape = 2.0, gamma_rate = 0.8),
  party          = list(mean = 1.5),
  catch_per_trip = list(mean = 1.8, nb_size = 0.5),
  harvest        = list(mean_pct = 35),
  counts         = list(mean_total_anglers = 10)
)

test_that("simulate_creel_data returns correct structure", {
  sim <- simulate_creel_data(
    params         = test_params,
    season_days    = 30L,
    n_sampled_days = 5L,
    seed           = 1L
  )
  expect_named(sim, c("interviews", "counts", "catch"))
  expect_s3_class(sim$interviews, "data.frame")
  expect_s3_class(sim$counts,     "data.frame")
  expect_s3_class(sim$catch,      "data.frame")
})

test_that("simulate_creel_data interviews have required columns", {
  sim <- simulate_creel_data(params = test_params, season_days = 20L, n_sampled_days = 5L, seed = 2L)
  req <- c("date", "day_type", "interview_id", "trip_status", "hours_fished",
           "trip_duration", "n_anglers", "catch_total", "catch_kept",
           "species_sought")
  expect_true(all(req %in% names(sim$interviews)))
})

test_that("simulate_creel_data counts have required columns", {
  sim <- simulate_creel_data(params = test_params, season_days = 20L, n_sampled_days = 5L, seed = 3L)
  expect_true(all(c("date", "day_type", "total_anglers") %in% names(sim$counts)))
})

test_that("simulate_creel_data catch has required columns", {
  sim <- simulate_creel_data(
    params = test_params, season_days = 20L, n_sampled_days = 5L,
    species = c("walleye", "pike"), seed = 4L
  )
  if (nrow(sim$catch) > 0L) {
    expect_true(all(c("interview_id", "species", "count", "catch_type") %in%
                      names(sim$catch)))
    expect_true(all(sim$catch$catch_type %in% c("caught", "harvested", "released")))
  }
})

test_that("simulate_creel_data date column is Date class", {
  sim <- simulate_creel_data(params = test_params, season_days = 20L, n_sampled_days = 5L, seed = 5L)
  if (nrow(sim$interviews) > 0L) expect_s3_class(sim$interviews$date, "Date")
  expect_s3_class(sim$counts$date, "Date")
})

test_that("simulate_creel_data trip_status is complete or incomplete", {
  sim <- simulate_creel_data(params = test_params, season_days = 30L, n_sampled_days = 10L, seed = 6L)
  if (nrow(sim$interviews) > 0L) {
    expect_true(all(sim$interviews$trip_status %in% c("complete", "incomplete")))
  }
})

test_that("simulate_creel_data incomplete trips: hours_fished <= trip_duration", {
  sim <- simulate_creel_data(params = test_params, season_days = 40L, n_sampled_days = 15L, seed = 7L)
  if (nrow(sim$interviews) > 0L) {
    inc <- sim$interviews[sim$interviews$trip_status == "incomplete", ]
    if (nrow(inc) > 0L) {
      expect_true(all(inc$hours_fished <= inc$trip_duration + 1e-9))
    }
  }
})

test_that("simulate_creel_data n_anglers >= 1", {
  sim <- simulate_creel_data(params = test_params, season_days = 30L, n_sampled_days = 8L, seed = 8L)
  if (nrow(sim$interviews) > 0L) {
    expect_true(all(sim$interviews$n_anglers >= 1L))
  }
})

test_that("simulate_creel_data catch_kept <= catch_total", {
  sim <- simulate_creel_data(params = test_params, season_days = 30L, n_sampled_days = 10L, seed = 9L)
  if (nrow(sim$interviews) > 0L) {
    expect_true(all(sim$interviews$catch_kept <= sim$interviews$catch_total))
  }
})

test_that("simulate_creel_data is reproducible with seed", {
  s1 <- simulate_creel_data(params = test_params, season_days = 20L, n_sampled_days = 5L, seed = 42L)
  s2 <- simulate_creel_data(params = test_params, season_days = 20L, n_sampled_days = 5L, seed = 42L)
  expect_identical(s1$interviews, s2$interviews)
  expect_identical(s1$counts, s2$counts)
})

test_that("simulate_creel_data counts: n_counts_per_day respected", {
  sim <- simulate_creel_data(
    params = test_params, season_days = 10L, n_sampled_days = 4L,
    n_counts_per_day = 5L, seed = 10L
  )
  counts_per_day <- table(sim$counts$date)
  expect_true(all(counts_per_day == 5L))
})

test_that("simulate_creel_data respects day_types stratification", {
  sim <- simulate_creel_data(
    params         = test_params,
    season_days    = 50L,
    n_sampled_days = 20L,
    day_types      = c(weekday = 5/7, weekend = 2/7),
    seed           = 11L
  )
  dtypes <- unique(sim$counts$day_type)
  expect_true(all(dtypes %in% c("weekday", "weekend")))
})

test_that("simulate_creel_data different params produce different results", {
  hi_effort <- list(
    effort         = list(gamma_shape = 5.0, gamma_rate = 0.5),
    party          = list(mean = 1.5),
    catch_per_trip = list(mean = 1.8, nb_size = 0.5),
    harvest        = list(mean_pct = 35),
    counts         = list(mean_total_anglers = 10)
  )
  lo_effort <- list(
    effort         = list(gamma_shape = 1.0, gamma_rate = 2.0),
    party          = list(mean = 1.5),
    catch_per_trip = list(mean = 1.8, nb_size = 0.5),
    harvest        = list(mean_pct = 35),
    counts         = list(mean_total_anglers = 10)
  )
  hi <- simulate_creel_data(params = hi_effort, season_days = 60L, n_sampled_days = 20L, seed = 12L)
  lo <- simulate_creel_data(params = lo_effort, season_days = 60L, n_sampled_days = 20L, seed = 12L)
  hi_mean <- mean(hi$interviews$hours_fished)
  lo_mean <- mean(lo$interviews$hours_fished)
  if (!is.na(hi_mean) && !is.na(lo_mean)) {
    expect_true(hi_mean > lo_mean)
  }
})

test_that("simulate_creel_data multi-species splits catch across species", {
  sim <- simulate_creel_data(
    params = test_params, season_days = 30L, n_sampled_days = 10L,
    species = c("walleye", "pike", "bass"),
    species_weights = c(0.5, 0.3, 0.2),
    seed = 13L
  )
  if (nrow(sim$catch) > 0L) {
    expect_true(all(sim$catch$species %in% c("walleye", "pike", "bass")))
  }
})

test_that("simulate_creel_data empty result on 0 encounters is valid", {
  sparse_params <- test_params
  sparse_params$counts$mean_total_anglers <- 0.01
  sim <- simulate_creel_data(
    params = sparse_params, season_days = 5L, n_sampled_days = 2L, seed = 99L
  )
  expect_named(sim, c("interviews", "counts", "catch"))
})

# ── simulate_creel_catch ──────────────────────────────────────────────────────

test_that("simulate_creel_catch returns integer vector of length n", {
  x <- simulate_creel_catch(n = 100L, seed = 1L)
  expect_type(x, "integer")
  expect_length(x, 100L)
})

test_that("simulate_creel_catch negbin: all values >= 0", {
  x <- simulate_creel_catch(n = 200L, family = "negbin", mu = 5, size = 0.5, seed = 2L)
  expect_true(all(x >= 0L))
})

test_that("simulate_creel_catch delta: zero proportion matches p_zero approximately", {
  p0 <- 0.45
  x  <- simulate_creel_catch(n = 2000L, family = "delta", p_zero = p0, seed = 3L)
  expect_true(abs(mean(x == 0L) - p0) < 0.05)
})

test_that("simulate_creel_catch poisson: all values >= 0", {
  x <- simulate_creel_catch(n = 100L, family = "poisson", mu = 3, seed = 4L)
  expect_true(all(x >= 0L))
})

test_that("simulate_creel_catch reproducible with seed", {
  a <- simulate_creel_catch(n = 50L, seed = 77L)
  b <- simulate_creel_catch(n = 50L, seed = 77L)
  expect_identical(a, b)
})

test_that("simulate_creel_catch proportional var_structure: higher effort → higher mean catch", {
  lo <- simulate_creel_catch(n = 500L, effort = 1.0, mu = 3, var_structure = "proportional", seed = 5L)
  hi <- simulate_creel_catch(n = 500L, effort = 5.0, mu = 3, var_structure = "proportional", seed = 5L)
  expect_true(mean(hi) > mean(lo))
})

test_that("simulate_creel_catch recycled effort works correctly", {
  x <- simulate_creel_catch(n = 10L, effort = 2.0, seed = 6L)
  expect_length(x, 10L)
})

test_that("simulate_creel_catch validates n > 0", {
  expect_error(simulate_creel_catch(n = 0L))
})

test_that("simulate_creel_catch validates p_zero in [0, 1)", {
  expect_error(simulate_creel_catch(n = 10L, family = "delta", p_zero = 1.0))
  expect_error(simulate_creel_catch(n = 10L, family = "delta", p_zero = -0.1))
})
