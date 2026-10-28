# creel_calendar() (GH #559): the calendar's rows are the population days the
# totals expand to, so every test here protects either "one row per day of
# the season, none missing, none doubled" or "each day lands in the stratum
# the user declared". A wrong calendar gives plausible wrong totals and no
# error (#436, #441, #447).

test_that("every day of the season appears exactly once", {
  cal <- creel_calendar(
    "2024-05-01", "2024-08-31",
    holidays = as.Date("2024-05-27"),
    special_periods = data.frame(
      start_date = "2024-06-29", end_date = "2024-07-07", label = "july4"
    )
  )
  expect_identical(nrow(cal), 123L)
  expect_identical(anyDuplicated(cal$date), 0L)
  expect_equal(cal$date, seq(as.Date("2024-05-01"), as.Date("2024-08-31"), by = "day"))
})

test_that("default strata are month x day type, labelled as connect labels them", {
  cal <- creel_calendar("2024-06-01", "2024-07-31")
  # 2024-06-01 is a Saturday; 2024-07-01 a Monday.
  expect_identical(cal$stratum[cal$date == as.Date("2024-06-01")], "06_weekend")
  expect_identical(cal$stratum[cal$date == as.Date("2024-07-01")], "07_weekday")
  expect_setequal(unique(cal$stratum), c("06_weekday", "06_weekend", "07_weekday", "07_weekend"))
  expect_identical(cal$month, as.integer(format(cal$date, "%m")))
})

test_that("a day-type calendar matches the hand-built example calendar and its estimates", {
  # The replacement for hand-written seq() + format("%u") code must give the
  # same population days and the same effort estimate.
  cal <- creel_calendar("2024-06-01", "2024-06-14", strata = "day_type")
  expect_identical(format(cal$date), format(example_calendar$date))
  expect_identical(cal$day_type, example_calendar$day_type)

  # The example counts carry no period length, which warns identically on
  # both paths; the comparison is what this test is about.
  est <- function(calendar) {
    suppressWarnings(
      creel_design(calendar, date = date, strata = day_type) |> # nolint
        add_counts(example_counts) |> # nolint
        estimate_effort()
    )
  }
  by_hand <- est(example_calendar)
  built <- est(cal)
  expect_equal(built$estimates$estimate, by_hand$estimates$estimate)
  expect_equal(built$estimates$se, by_hand$estimates$se)
})

test_that("a holiday is a weekend day of its own month", {
  cal <- creel_calendar("2024-05-01", "2024-09-30", holidays = c("2024-05-27", "2024-09-02"))
  memorial <- cal[cal$date == as.Date("2024-05-27"), ]
  expect_identical(memorial$day_type, "weekend")
  expect_identical(memorial$stratum, "05_weekend")
  expect_identical(cal$stratum[cal$date == as.Date("2024-09-02")], "09_weekend")
  # Ordinary Mondays are untouched.
  expect_identical(cal$day_type[cal$date == as.Date("2024-05-20")], "weekday")
})

test_that("a special period is one stratum across a month boundary and beats a holiday", {
  cal <- creel_calendar(
    "2024-06-01", "2024-07-31",
    holidays = "2024-07-04",
    special_periods = data.frame(
      start_date = "2024-06-29", end_date = "2024-07-07", label = "july4"
    )
  )
  sp <- cal[cal$stratum == "july4", ]
  expect_identical(nrow(sp), 9L)
  expect_true(all(sp$day_type == "special"))
  expect_setequal(sp$month, c(6L, 7L))
  # Days just outside keep their ordinary strata.
  expect_identical(cal$stratum[cal$date == as.Date("2024-06-28")], "06_weekday")
  expect_identical(cal$stratum[cal$date == as.Date("2024-07-08")], "07_weekday")
})

test_that("weeks start after the weekend, so a weekend is never split", {
  # Saturday-Sunday weekend: weeks start on Monday.
  cal <- creel_calendar("2024-05-01", "2024-05-31", strata = c("week", "day_type"))
  sat <- cal$week[cal$date == as.Date("2024-05-04")]
  sun <- cal$week[cal$date == as.Date("2024-05-05")]
  mon <- cal$week[cal$date == as.Date("2024-05-06")]
  expect_identical(cal$week[1], 1L)
  expect_identical(sat, sun)
  expect_identical(mon, sun + 1L)
  expect_identical(cal$stratum[cal$date == as.Date("2024-05-06")], "wk02_weekday")

  # Friday-Saturday weekend: weeks start on Sunday.
  fs <- creel_calendar("2024-05-01", "2024-05-31", strata = "week", weekend_days = c("Fri", "Sat"))
  expect_identical(
    fs$week[fs$date == as.Date("2024-05-03")],
    fs$week[fs$date == as.Date("2024-05-04")]
  )
  expect_identical(
    fs$week[fs$date == as.Date("2024-05-05")],
    fs$week[fs$date == as.Date("2024-05-04")] + 1L
  )
})

test_that("season blocks run from each start date to the next", {
  cal <- creel_calendar(
    "2024-05-01", "2024-08-31",
    strata = c("season_block", "day_type"),
    season_blocks = data.frame(
      start_date = c("2024-05-01", "2024-07-01"), label = c("early", "late")
    )
  )
  expect_identical(cal$season_block[cal$date == as.Date("2024-06-30")], "early")
  expect_identical(cal$season_block[cal$date == as.Date("2024-07-01")], "late")
  expect_identical(cal$stratum[cal$date == as.Date("2024-07-01")], "late_weekday")
  expect_identical(sum(cal$season_block == "early"), 61L)
})

test_that("dates outside the season are refused, not dropped", {
  # Dropping them would hide a wrong year.
  expect_error(
    creel_calendar("2024-05-01", "2024-08-31", holidays = "2023-07-04"),
    "outside the season"
  )
  expect_error(
    creel_calendar(
      "2024-05-01", "2024-08-31",
      special_periods = data.frame(start_date = "2024-08-30", end_date = "2024-09-02", label = "labor")
    ),
    "outside the season"
  )
})

test_that("ambiguous or malformed inputs are refused", {
  expect_error(creel_calendar("2024-08-31", "2024-05-01"), "before")
  expect_error(creel_calendar("2024-05-01", "2024-08-31", holidays = "07/04/2024"), "must be dates")
  expect_error(creel_calendar("2024-05-01", "2024-08-31", strata = "year"), "strata")
  expect_error(creel_calendar("2024-05-01", "2024-08-31", strata = c("month", "month")), "strata")
  expect_error(creel_calendar("2024-05-01", "2024-08-31", strata = "season_block"), "season_blocks")
  expect_error(
    creel_calendar(
      "2024-05-01", "2024-08-31",
      season_blocks = data.frame(start_date = "2024-05-01", label = "all")
    ),
    "does not use it"
  )
  expect_error(
    creel_calendar(
      "2024-05-01", "2024-08-31",
      strata = "season_block",
      season_blocks = data.frame(start_date = "2024-05-02", label = "a")
    ),
    "first day"
  )
  # A non-consecutive weekend has no "day after the weekend" to start a week.
  expect_error(
    creel_calendar("2024-05-01", "2024-08-31", weekend_days = c("Sat", "Mon")),
    "consecutive"
  )
  # A special label equal to an ordinary stratum would merge two strata.
  expect_error(
    creel_calendar(
      "2024-05-01", "2024-08-31",
      special_periods = data.frame(start_date = "2024-07-04", end_date = "2024-07-04", label = "07_weekday")
    ),
    "ordinary stratum"
  )
  expect_error(
    creel_calendar(
      "2024-05-01", "2024-08-31",
      special_periods = data.frame(
        start_date = c("2024-07-01", "2024-07-03"),
        end_date = c("2024-07-04", "2024-07-06"),
        label = c("a", "b")
      )
    ),
    "overlap"
  )
})
