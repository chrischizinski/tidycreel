# Tests for day_length() -- CBM daylength model (Forsythe et al. 1995)

KEARNEY_LAT <- 40.699 # nolint: object_name_linter

test_that("day_length() matches published solstice daylengths at Kearney", {
  # The model is only useful if it reproduces reality. Forsythe et al. report
  # accuracy within a minute or so; published Kearney values are 15.09 h on the
  # summer solstice and 9.25 h on the winter solstice.
  jun <- day_length(KEARNEY_LAT, as.Date("2024-06-21"))
  dec <- day_length(KEARNEY_LAT, as.Date("2024-12-21"))
  expect_equal(jun, 15.09, tolerance = 0.02)
  expect_equal(dec, 9.25, tolerance = 0.02)
})

test_that("day_length() reproduces the monthly means the package used to hardcode", {
  # tidycreel shipped a hardcoded 12-value vector of Kearney monthly means.
  # day_length() replaced it, so it has to return the same numbers -- otherwise
  # every simulation built against the old constant silently changes.
  hardcoded <- c(
    9.616, 10.621, 11.911, 13.266, 14.425, 15.035,
    14.778, 13.795, 12.508, 11.161, 9.965, 9.318
  )
  dates <- seq(as.Date("2025-01-01"), as.Date("2025-12-31"), by = "day")
  monthly <- tapply(
    day_length(KEARNEY_LAT, dates),
    as.integer(format(dates, "%m")),
    mean
  )
  expect_equal(as.numeric(monthly), hardcoded, tolerance = 1e-3)
})

test_that("day length is symmetric about the equinox and inverted across the equator", {
  # Two physical identities that must hold for any correct implementation, and
  # that a transcription error in the declination term would break.
  north <- day_length(45, as.Date("2024-06-21"))
  south <- day_length(-45, as.Date("2024-06-21"))
  expect_equal(north + south, 24, tolerance = 0.05)

  expect_equal(day_length(0, as.Date("2024-03-20")), 12, tolerance = 0.15)
  expect_equal(day_length(0, as.Date("2024-06-21")), 12, tolerance = 0.15)
})

test_that("higher latitude means a wider seasonal swing", {
  swing <- function(lat) {
    day_length(lat, as.Date("2024-06-21")) - day_length(lat, as.Date("2024-12-21"))
  }
  expect_lt(swing(25), swing(45))
  expect_lt(swing(45), swing(65))
})

test_that("day_length() saturates rather than erroring inside the polar circles", {
  # acos() of an out-of-range value would give NaN. Clamping is what makes
  # polar summer return 24 h instead of a silent NaN propagating into effort.
  expect_equal(day_length(80, as.Date("2024-06-21")), 24)
  expect_equal(day_length(80, as.Date("2024-12-21")), 0)
  expect_false(anyNA(day_length(89.9, as.Date("2024-06-21"))))
})

test_that("a lower horizon lengthens the day", {
  d <- as.Date("2024-06-21")
  expect_lt(
    day_length(KEARNEY_LAT, d, horizon = "sunset"),
    day_length(KEARNEY_LAT, d, horizon = "civil")
  )
  expect_lt(
    day_length(KEARNEY_LAT, d, horizon = "civil"),
    day_length(KEARNEY_LAT, d, horizon = "nautical")
  )
  # A bare number is the depression angle in degrees, so it must agree with the
  # name that stands for the same angle.
  expect_equal(
    day_length(KEARNEY_LAT, d, horizon = 6),
    day_length(KEARNEY_LAT, d, horizon = "civil")
  )
})

test_that("day_length() recycles lat and date and returns the longer length", {
  dates <- seq(as.Date("2024-06-01"), as.Date("2024-06-30"), by = "day")
  expect_length(day_length(KEARNEY_LAT, dates), 30L)
  expect_length(day_length(c(30, 40, 50), as.Date("2024-06-21")), 3L)
  expect_length(day_length(c(30, 40), dates[1:2]), 2L)
})

test_that("day_length() rejects lengths that cannot recycle", {
  expect_error(
    day_length(c(30, 40, 50), seq(as.Date("2024-06-01"), by = "day", length.out = 2)),
    regexp = "recyclable"
  )
})

test_that("day_length() rejects an out-of-range latitude", {
  expect_error(day_length(91, as.Date("2024-06-21")))
  expect_error(day_length(-91, as.Date("2024-06-21")))
})

test_that("day_length() rejects an unusable date", {
  expect_error(day_length(40, as.Date(NA)), regexp = "missing")
  expect_error(day_length(40, as.Date(character(0))), regexp = "non-empty")
})

test_that("day_length() rejects an unknown horizon name", {
  expect_error(
    day_length(40, as.Date("2024-06-21"), horizon = "dusk"),
    regexp = "horizon"
  )
})

# simulate_creel_data() wiring ----

test_that("simulate_creel_data() omits the daylight columns when given no location", {
  # There is no honest default latitude. Supplying neither argument must leave
  # the columns off rather than invent a place, which also keeps the counts
  # table unambiguous for add_counts().
  sim <- simulate_creel_data(
    params = list(
      effort = list(gamma_shape = 2, gamma_rate = 0.8),
      party = list(mean = 1.5),
      catch_per_trip = list(mean = 1.8, nb_size = 0.5),
      harvest = list(mean_pct = 35),
      counts = list(mean_total_anglers = 10)
    ),
    season_days = 30,
    n_sampled_days = 8,
    seed = 7
  )
  expect_false("daylight_hours" %in% names(sim$counts))
  expect_false("angler_hours" %in% names(sim$counts))
})

test_that("simulate_creel_data(lat=) derives T per date and angler_hours from it", {
  sim <- simulate_creel_data(
    params = list(
      effort = list(gamma_shape = 2, gamma_rate = 0.8),
      party = list(mean = 1.5),
      catch_per_trip = list(mean = 1.8, nb_size = 0.5),
      harvest = list(mean_pct = 35),
      counts = list(mean_total_anglers = 10)
    ),
    season_days = 120,
    n_sampled_days = 20,
    start_date = as.Date("2024-04-01"),
    lat = KEARNEY_LAT,
    seed = 7
  )
  expect_true(all(c("daylight_hours", "angler_hours") %in% names(sim$counts)))
  expect_equal(
    sim$counts$daylight_hours,
    day_length(KEARNEY_LAT, sim$counts$date)
  )
  expect_equal(
    sim$counts$angler_hours,
    sim$counts$total_anglers * sim$counts$daylight_hours
  )
  # T must track the season, not sit at one value -- that is the whole reason
  # for computing it per date rather than taking a scalar.
  expect_gt(length(unique(sim$counts$daylight_hours)), 1L)
})

test_that("simulate_creel_data() rejects lat and daylight_hours together", {
  expect_error(
    simulate_creel_data(
      params = list(
        effort = list(gamma_shape = 2, gamma_rate = 0.8),
        party = list(mean = 1.5),
        catch_per_trip = list(mean = 1.8, nb_size = 0.5),
        harvest = list(mean_pct = 35),
        counts = list(mean_total_anglers = 10)
      ),
      season_days = 30,
      n_sampled_days = 8,
      lat = 40,
      daylight_hours = 14,
      seed = 7
    ),
    regexp = "not both"
  )
})
