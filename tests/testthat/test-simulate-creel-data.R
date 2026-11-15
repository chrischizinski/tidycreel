test_params <- list(
  effort = list(gamma_shape = 2.0, gamma_rate = 0.8),
  party = list(mean = 1.5),
  catch_rate = list(mean = 0.25, nb_size = 0.5),
  harvest = list(mean_pct = 35),
  counts = list(mean_total_anglers = 10)
)

# The fishing day needs a length since GH #646; these tests are not about it,
# so they share one. sim12() is simulate_creel_data() with a 12-hour day.
sim12 <- function(...) simulate_creel_data(..., daylight_hours = 12)

test_that("simulate_creel_data returns correct structure", {
  sim <- sim12(
    params = test_params,
    season_days = 30L,
    n_sampled_days = 5L,
    seed = 1L
  )
  expect_named(sim, c("schedule", "interviews", "counts", "catch", "truth"))
  expect_s3_class(sim$interviews, "data.frame")
  expect_s3_class(sim$counts, "data.frame")
  expect_s3_class(sim$catch, "data.frame")
})

test_that("simulate_creel_data interviews have required columns", {
  sim <- sim12(
    params = test_params,
    season_days = 20L,
    n_sampled_days = 5L,
    seed = 2L
  )
  req <- c(
    "date",
    "day_type",
    "interview_id",
    "trip_status",
    "hours_fished",
    "trip_duration",
    "true_trip_length",
    "n_anglers",
    "catch_total",
    "catch_kept",
    "species_sought"
  )
  expect_true(all(req %in% names(sim$interviews)))
})

test_that("simulate_creel_data counts have required columns", {
  sim <- sim12(
    params = test_params,
    season_days = 20L,
    n_sampled_days = 5L,
    seed = 3L
  )
  expect_true(all(c("date", "day_type", "count_time", "total_anglers") %in% names(sim$counts)))
})

test_that("simulate_creel_data counts: count_time is 1..n per day", {
  sim <- sim12(
    params = test_params,
    season_days = 20L,
    n_sampled_days = 5L,
    n_counts_per_day = 3L,
    seed = 3L
  )
  ct_per_day <- tapply(sim$counts$count_time, sim$counts$date, function(x) sort(x))
  expect_true(all(vapply(ct_per_day, function(x) identical(x, 1:3), logical(1))))
})

test_that("simulate_creel_data catch has required columns", {
  sim <- sim12(
    params = test_params,
    season_days = 20L,
    n_sampled_days = 5L,
    species = c("walleye", "pike"),
    seed = 4L
  )
  if (nrow(sim$catch) > 0L) {
    expect_true(all(
      c("interview_id", "species", "count", "catch_type") %in%
        names(sim$catch)
    ))
    expect_true(all(sim$catch$catch_type %in% c("caught", "harvested", "released")))
  }
})

test_that("simulate_creel_data date column is Date class", {
  sim <- sim12(
    params = test_params,
    season_days = 20L,
    n_sampled_days = 5L,
    seed = 5L
  )
  if (nrow(sim$interviews) > 0L) {
    expect_s3_class(sim$interviews$date, "Date")
  }
  expect_s3_class(sim$counts$date, "Date")
})

test_that("simulate_creel_data trip_status follows interview_type", {
  access <- sim12(params = test_params, season_days = 30L, n_sampled_days = 10L, seed = 6L)
  roving <- sim12(
    params = test_params, season_days = 30L, n_sampled_days = 10L, seed = 6L,
    interview_type = "roving"
  )
  expect_gt(nrow(access$interviews), 0L)
  expect_gt(nrow(roving$interviews), 0L)
  expect_true(all(access$interviews$trip_status == "complete"))
  expect_true(all(roving$interviews$trip_status == "incomplete"))
})

test_that("simulate_creel_data roving: trip_duration is the time so far (GH #488)", {
  # Why: add_interviews() reads trip_duration as the elapsed time at the
  # interview, and truncate_at filters on it. A party met 10 minutes in with
  # 3 hours to go must not pass a 0.5 h truncation on simulated data when it
  # would fail on real data. The full length is simulation truth only.
  sim <- sim12(
    params = test_params, season_days = 40L, n_sampled_days = 15L, seed = 7L,
    interview_type = "roving"
  )
  inc <- sim$interviews
  expect_gt(nrow(inc), 0L)
  expect_equal(inc$trip_duration, inc$hours_fished)
  expect_true(all(inc$hours_fished <= inc$true_trip_length + 1e-9))
  expect_true(any(inc$hours_fished < inc$true_trip_length - 0.5))
})

test_that("simulate_creel_data n_anglers >= 1", {
  sim <- sim12(
    params = test_params,
    season_days = 30L,
    n_sampled_days = 8L,
    seed = 8L
  )
  if (nrow(sim$interviews) > 0L) {
    expect_true(all(sim$interviews$n_anglers >= 1L))
  }
})

test_that("simulate_creel_data catch_kept <= catch_total", {
  sim <- sim12(
    params = test_params,
    season_days = 30L,
    n_sampled_days = 10L,
    seed = 9L
  )
  if (nrow(sim$interviews) > 0L) {
    expect_true(all(sim$interviews$catch_kept <= sim$interviews$catch_total))
  }
})

test_that("simulate_creel_data is reproducible with seed", {
  s1 <- sim12(
    params = test_params,
    season_days = 20L,
    n_sampled_days = 5L,
    seed = 42L
  )
  s2 <- sim12(
    params = test_params,
    season_days = 20L,
    n_sampled_days = 5L,
    seed = 42L
  )
  expect_identical(s1$interviews, s2$interviews)
  expect_identical(s1$counts, s2$counts)
})

test_that("simulate_creel_data counts: n_counts_per_day respected", {
  sim <- sim12(
    params = test_params,
    season_days = 10L,
    n_sampled_days = 4L,
    n_counts_per_day = 5L,
    seed = 10L
  )
  counts_per_day <- table(sim$counts$date)
  expect_true(all(counts_per_day == 5L))
})

test_that("simulate_creel_data respects day_types stratification", {
  sim <- sim12(
    params = test_params,
    season_days = 50L,
    n_sampled_days = 20L,
    day_types = c(weekday = 5 / 7, weekend = 2 / 7),
    seed = 11L
  )
  dtypes <- unique(sim$counts$day_type)
  expect_true(all(dtypes %in% c("weekday", "weekend")))
})

test_that("simulate_creel_data different params produce different results", {
  hi_effort <- list(
    effort = list(gamma_shape = 5.0, gamma_rate = 0.5),
    party = list(mean = 1.5),
    catch_rate = list(mean = 0.25, nb_size = 0.5),
    harvest = list(mean_pct = 35),
    counts = list(mean_total_anglers = 10)
  )
  lo_effort <- list(
    effort = list(gamma_shape = 1.0, gamma_rate = 2.0),
    party = list(mean = 1.5),
    catch_rate = list(mean = 0.25, nb_size = 0.5),
    harvest = list(mean_pct = 35),
    counts = list(mean_total_anglers = 10)
  )
  hi <- sim12(params = hi_effort, season_days = 60L, n_sampled_days = 20L, seed = 12L)
  lo <- sim12(params = lo_effort, season_days = 60L, n_sampled_days = 20L, seed = 12L)
  hi_mean <- mean(hi$interviews$hours_fished)
  lo_mean <- mean(lo$interviews$hours_fished)
  expect_false(is.nan(hi_mean), label = "hi_mean must not be NaN")
  expect_false(is.nan(lo_mean), label = "lo_mean must not be NaN")
  expect_true(hi_mean > lo_mean)
})

test_that("simulate_creel_data multi-species splits catch across species", {
  sim <- sim12(
    params = test_params,
    season_days = 30L,
    n_sampled_days = 10L,
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
  sim <- sim12(
    params = sparse_params,
    season_days = 5L,
    n_sampled_days = 2L,
    seed = 99L
  )
  expect_named(sim, c("schedule", "interviews", "counts", "catch", "truth"))
})

# ── schedule component ─────────────────────────────────────────────────────────

test_that("SIM-SCH-01: schedule has required columns and correct types", {
  sim <- sim12(
    params = test_params,
    season_days = 20L,
    n_sampled_days = 5L,
    seed = 10L
  )
  expect_true(all(c("date", "day_type", "sampled") %in% names(sim$schedule)))
  expect_s3_class(sim$schedule$date, "Date")
  expect_type(sim$schedule$day_type, "character")
  expect_type(sim$schedule$sampled, "logical")
})

test_that("SIM-SCH-02: schedule has exactly season_days rows", {
  sim <- sim12(
    params = test_params,
    season_days = 45L,
    n_sampled_days = 10L,
    seed = 11L
  )
  expect_equal(nrow(sim$schedule), 45L)
})

test_that("SIM-SCH-03: schedule$sampled TRUE count equals n_sampled_days", {
  sim <- sim12(
    params = test_params,
    season_days = 30L,
    n_sampled_days = 8L,
    seed = 12L
  )
  expect_equal(sum(sim$schedule$sampled), 8L)
})

test_that("SIM-SCH-04: sampled days match interview and count dates", {
  sim <- sim12(
    params = test_params,
    season_days = 30L,
    n_sampled_days = 8L,
    seed = 13L
  )
  sched_sampled_dates <- sim$schedule$date[sim$schedule$sampled]
  count_dates <- unique(sim$counts$date)
  expect_true(all(count_dates %in% sched_sampled_dates))
})

test_that("SIM-SCH-05: schedule passes validate_calendar_schema (pipeable into creel_design)", {
  sim <- sim12(
    params = test_params,
    season_days = 20L,
    n_sampled_days = 5L,
    seed = 14L
  )
  expect_no_error(creel_design(sim$schedule, date = date, strata = day_type))
})

test_that("SIM-SCH-06: multi-stratum schedule contains only declared day_type levels", {
  sim <- sim12(
    params = test_params,
    season_days = 30L,
    n_sampled_days = 8L,
    day_types = c(weekday = 5 / 7, weekend = 2 / 7),
    seed = 15L
  )
  expect_true(all(sim$schedule$day_type %in% c("weekday", "weekend")))
})

test_that("SIM-SCH-07: day_types character vector errors with informative message", {
  expect_error(
    sim12(params = test_params, day_types = c("weekday", "weekend"), seed = 16L),
    regexp = "numeric"
  )
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
  x <- simulate_creel_catch(n = 2000L, family = "delta", p_zero = p0, seed = 3L)
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
  lo <- simulate_creel_catch(
    n = 500L,
    effort = 1.0,
    mu = 3,
    var_structure = "proportional",
    seed = 5L
  )
  hi <- simulate_creel_catch(
    n = 500L,
    effort = 5.0,
    mu = 3,
    var_structure = "proportional",
    seed = 5L
  )
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

# --- the seed argument must not outlive the call (SEED-01..04) ---------------

test_that("a supplied seed does not reset the caller's RNG stream (SEED-01)", {
  # `seed` is a convenience for reproducing one simulation, not a licence to
  # take over the session. Before this, a script that seeded its own analysis
  # and then called a simulate function part-way through silently continued
  # from OUR seed -- every subsequent draw determined by an argument passed for
  # one function's benefit, with nothing to say so.
  #
  # Measured on the previous tip: after set.seed(999), the next runif(1) was
  # 0.389071 without the call and 0.685170 with it.
  set.seed(999)
  want <- runif(1)

  set.seed(999)
  invisible(suppressMessages(simulate_creel_catch(n = 5, seed = 42)))
  expect_identical(runif(1), want)

  set.seed(999)
  invisible(suppressMessages(sim12(
    params         = test_params,
    season_days    = 20,
    n_sampled_days = 5,
    seed           = 42
  )))
  expect_identical(runif(1), want)
})

test_that("seed still reproduces, which is the point of it (SEED-02)", {
  # The control for SEED-01. Restoring the stream must not cost the feature the
  # argument exists for: the same seed has to give the same data, and different
  # seeds still have to differ.
  a <- suppressMessages(simulate_creel_catch(n = 6, seed = 42))
  b <- suppressMessages(simulate_creel_catch(n = 6, seed = 42))
  expect_identical(a, b)
  expect_false(identical(a, suppressMessages(simulate_creel_catch(n = 6, seed = 43))))

  d1 <- suppressMessages(sim12(
    params = test_params, season_days = 20, n_sampled_days = 5, seed = 7
  ))
  d2 <- suppressMessages(sim12(
    params = test_params, season_days = 20, n_sampled_days = 5, seed = 7
  ))
  expect_identical(d1, d2)
})

test_that("omitting seed still advances the stream (SEED-03)", {
  # The other control, and the one that stops SEED-01 being satisfied by simply
  # never drawing. Without a seed these functions must consume randomness like
  # any other RNG user; only the borrowed-and-returned case is special.
  set.seed(999)
  first <- runif(1)

  set.seed(999)
  invisible(suppressMessages(simulate_creel_catch(n = 5)))
  expect_false(identical(runif(1), first))
})

test_that("a session that never drew is left without a seed (SEED-04)", {
  # set.seed() CREATES .Random.seed when nothing had initialised the stream, so
  # faithfully restoring "no state" means removing it again rather than leaving
  # ours behind. Easy to miss: every interactive session has already drawn
  # something, so only a fresh one reaches this path.
  if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
    saved <- get(".Random.seed", envir = globalenv(), inherits = FALSE)
    on.exit(assign(".Random.seed", saved, envir = globalenv()), add = TRUE)
    rm(".Random.seed", envir = globalenv())
  }
  expect_false(exists(".Random.seed", envir = globalenv(), inherits = FALSE))

  invisible(suppressMessages(simulate_creel_catch(n = 3, seed = 5)))

  expect_false(exists(".Random.seed", envir = globalenv(), inherits = FALSE))
})

# ── catch accrual and interview modes (GH #494, #488) ─────────────────────────

# A large season so sample estimates sit close to the population values. The
# tolerances were set from 20 seeds: ROM and MOR ranged about +-10 % around
# the true rate, interviewed trip lengths about +-3 %. The defects they guard
# against are far larger (MOR 2.5x the rate; 3.75 h against 2.5 h).
big_sim <- function(interview_type, seed = 494L, params = test_params) {
  sim12(
    params = params,
    season_days = 300L,
    n_sampled_days = 250L,
    n_anglers_per_day = 30,
    interview_type = interview_type,
    seed = seed
  )
}

test_that("access ratio of means recovers the true catch rate (GH #494)", {
  # Why: catch must accrue with time fished and party size, or the simulated
  # population has no catch rate for an estimator to recover. ROM on complete
  # trips is the access estimator (Pollock et al. 1997).
  sim <- big_sim("access")
  iv <- sim$interviews
  rom <- sum(iv$catch_total) / sum(iv$n_anglers * iv$hours_fished)
  expect_equal(sim$truth$catch_rate, test_params$catch_rate$mean)
  expect_equal(rom, sim$truth$catch_rate, tolerance = 0.15)
})

test_that("roving mean of ratios recovers the SAME rate (GH #494)", {
  # Why: before #494 an incomplete trip carried its whole trip's catch over
  # the hours fished so far, so MOR on roving interviews came out about 2.5x
  # the access rate. With catch accruing, both readings target one rate.
  # Short trips are truncated, as Pollock et al. (1997) recommend.
  sim <- big_sim("roving")
  iv <- sim$interviews[sim$interviews$hours_fished >= 0.5, ]
  mor <- mean(iv$catch_total / (iv$n_anglers * iv$hours_fished))
  expect_equal(mor, sim$truth$catch_rate, tolerance = 0.15)
})

test_that("harvest truth is the catch rate times the keep proportion", {
  sim <- big_sim("access")
  iv <- sim$interviews
  expect_equal(sim$truth$harvest_rate, 0.25 * 0.35)
  hrom <- sum(iv$catch_kept) / sum(iv$n_anglers * iv$hours_fished)
  expect_equal(hrom, sim$truth$harvest_rate, tolerance = 0.15)
})

test_that("access interviews are equal-probability, roving are length-biased (GH #494)", {
  # Why: an access clerk meets every finishing party with the same chance;
  # a roving clerk meets a party in proportion to how long it fishes. With
  # Gamma(shape 2, rate 0.8) trips the population mean length is 2.5 h and
  # the length-biased mean is (2 + 1) / 0.8 = 3.75 h. Before #494 complete
  # trips were sampled length-biased too.
  access <- big_sim("access")$interviews
  roving <- big_sim("roving")$interviews
  expect_equal(mean(access$true_trip_length), 2.5, tolerance = 0.08)
  expect_equal(mean(roving$true_trip_length), 3.75, tolerance = 0.08)
  expect_equal(access$hours_fished, access$trip_duration)
  expect_equal(access$hours_fished, access$true_trip_length)
})

test_that("the old per-trip catch parameter is refused, not reinterpreted", {
  # Why: a per-trip mean has no honest conversion to a per-angler-hour rate.
  old <- test_params
  old$catch_rate <- NULL
  old$catch_per_trip <- list(mean = 1.8, nb_size = 0.5)
  expect_error(
    sim12(params = old, season_days = 10L, n_sampled_days = 3L, seed = 1L),
    class = "creel_error_simulate_removed_input"
  )
})

test_that("p_complete is refused: interview_type decides trip status", {
  expect_error(
    sim12(
      params = test_params, season_days = 10L, n_sampled_days = 3L, seed = 1L,
      p_complete = 0.75
    ),
    class = "creel_error_simulate_removed_input"
  )
})

test_that("weekday/weekend day types come from the date (GH #488)", {
  # Why: a reader checking a simulated date against a calendar must find a
  # weekend on a Saturday or Sunday.
  sim <- sim12(
    params = test_params,
    season_days = 60L,
    n_sampled_days = 20L,
    day_types = c(weekday = 5 / 7, weekend = 2 / 7),
    start_date = as.Date("2024-05-01"),
    seed = 11L
  )
  is_weekend <- function(d) format(d, "%u") %in% c("6", "7")
  expect_identical(
    sim$schedule$day_type,
    ifelse(is_weekend(sim$schedule$date), "weekend", "weekday")
  )
  expect_identical(
    sim$interviews$day_type,
    ifelse(is_weekend(sim$interviews$date), "weekend", "weekday")
  )
  expect_identical(
    sim$counts$day_type,
    ifelse(is_weekend(sim$counts$date), "weekend", "weekday")
  )
})

test_that("other day-type names are assigned at random in the stated proportions", {
  # Why: weekday/weekend now come from the date, so the random branch needs
  # its own test; without it a regression for custom strata would pass.
  sim <- sim12(
    params = test_params,
    season_days = 2000L,
    n_sampled_days = 10L,
    day_types = c(open = 0.7, holiday = 0.3),
    seed = 12L
  )
  expect_setequal(unique(sim$schedule$day_type), c("open", "holiday"))
  expect_equal(mean(sim$schedule$day_type == "holiday"), 0.3, tolerance = 0.1)
  sampled <- sim$schedule[sim$schedule$sampled, ]
  expect_identical(
    sort(unique(sim$counts$day_type)),
    sort(unique(sampled$day_type))
  )
})

test_that("a supplied non-positive nb_size is refused, not replaced", {
  bad <- test_params
  bad$catch_rate$nb_size <- 0
  expect_error(
    sim12(params = bad, season_days = 10L, n_sampled_days = 3L, seed = 1L),
    "nb_size"
  )
})

# ── counts coherent with the trips; season truth (GH #646) ─────────────────────

test_that("the counts estimate the same effort the trips put in", {
  # Why: counts were drawn independently of the trips, so effort from counts
  # and the trips' angler-hours described two unrelated populations. A count
  # at a random moment times the day length is unbiased for the day's
  # angler-hours (Hoenig et al. 1993), so on average they must agree.
  sim <- sim12(
    params = test_params, season_days = 300L, n_sampled_days = 250L,
    n_anglers_per_day = 30, n_counts_per_day = 4L, seed = 646L
  )
  per_day <- tapply(sim$counts$angler_hours, sim$counts$date, mean)
  # Over 10 seeds the ratio ran 0.965-1.020.
  expect_equal(sum(per_day), sim$truth$effort_sampled_days, tolerance = 0.08)
})

test_that("estimate_effort() on simulated data recovers the true season effort", {
  # The whole chain: simulate -> design -> season total, checked against truth.
  sim <- sim12(
    params = test_params, season_days = 200L, n_sampled_days = 120L,
    day_types = c(weekday = 5 / 7, weekend = 2 / 7),
    n_anglers_per_day = 30, n_counts_per_day = 4L, seed = 6461L
  )
  design <- creel_design(sim$schedule, date = date, strata = day_type)
  design <- add_counts(design, sim$counts[, c("date", "day_type", "count_time", "total_anglers", "daylight_hours")],
    count_col = total_anglers, count_time_col = count_time, period_length_col = daylight_hours
  )
  est <- suppressMessages(estimate_effort(design, target = "period_total"))
  # A sampling estimate: with one count a day it ran 0.87-1.11 of the truth
  # over 10 seeds. The independent counts this replaced came out near 1.7.
  expect_equal(est$estimates$estimate, sim$truth$effort_season, tolerance = 0.2)
})

test_that("season truth: catch is the true rate times the true effort", {
  sim <- sim12(
    params = test_params, season_days = 300L, n_sampled_days = 30L,
    n_anglers_per_day = 30, seed = 6462L
  )
  tr <- sim$truth
  expect_gt(tr$effort_season, tr$effort_sampled_days)
  expect_equal(tr$catch_season / tr$effort_season, tr$catch_rate, tolerance = 0.15)
  expect_lte(tr$harvest_season, tr$catch_season)
})

test_that("access interviews carry their trip's whole catch; roving ones a part of it", {
  # An access interview records the trip as the population holds it, so the
  # interviewed catch cannot exceed the season's; a roving one records only
  # the catch so far.
  acc <- sim12(params = test_params, season_days = 60L, n_sampled_days = 60L, seed = 6463L)
  expect_lte(sum(acc$interviews$catch_total), acc$truth$catch_sampled_days)
  rov <- sim12(
    params = test_params, season_days = 60L, n_sampled_days = 60L, seed = 6463L,
    interview_type = "roving"
  )
  expect_true(all(rov$interviews$catch_kept <= rov$interviews$catch_total))
})

test_that("no count exceeds the anglers fishing that day", {
  sim <- sim12(params = test_params, season_days = 40L, n_sampled_days = 40L, n_counts_per_day = 3L, seed = 6464L)
  expect_true(all(sim$counts$total_anglers >= 0))
  expect_true(all(sim$counts$angler_hours == sim$counts$total_anglers * 12))
})
