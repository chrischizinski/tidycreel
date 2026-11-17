# Tests for geographic summary functions -- Phase 96 (RPT-03, RPT-04, RPT-05, RPT-06)

# --- Shared fixtures -----------------------------------------------------------

make_boat_composition_design <- function() {
  counts_df <- data.frame(
    date = as.Date(c("2024-05-01", "2024-05-04", "2024-06-01", "2024-06-08")),
    day_type = c("weekday", "weekend", "weekday", "weekend"),
    angler_boats = c(3L, 2L, 4L, 1L),
    non_ang_boats = c(1L, 2L, 1L, 3L),
    count = c(10L, 12L, 9L, 8L)
  )
  cal <- data.frame(
    date = counts_df$date,
    day_type = counts_df$day_type
  )
  d <- suppressWarnings(
    creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter
  )
  suppressWarnings(
    add_counts(d, counts_df, count_col = count) # nolint: object_usage_linter
  )
}

make_boat_composition_schema <- function(
  ab_col = "angler_boats",
  nb_col = "non_ang_boats"
) {
  creel_schema(
    survey_type = "instantaneous",
    angler_boats_col = ab_col,
    non_ang_boats_col = nb_col
  )
}

# --- summarize_boat_composition() — RPT-03 ------------------------------------

test_that("summarize_boat_composition() returns creel_summary_boat_composition class", {
  d <- make_boat_composition_design()
  s <- make_boat_composition_schema()
  result <- summarize_boat_composition(d, s)
  expect_s3_class(result, "creel_summary_boat_composition")
  expect_s3_class(result, "data.frame")
})

test_that("summarize_boat_composition() has columns month, day_type, n_events, pct_angler_boats", {
  d <- make_boat_composition_design()
  s <- make_boat_composition_schema()
  result <- summarize_boat_composition(d, s)
  expect_true(all(c("month", "day_type", "n_events", "pct_angler_boats") %in% names(result)))
})

test_that("summarize_boat_composition() n_events is integer, pct_angler_boats is numeric", {
  d <- make_boat_composition_design()
  s <- make_boat_composition_schema()
  result <- summarize_boat_composition(d, s)
  expect_true(is.integer(result$n_events))
  expect_true(is.numeric(result$pct_angler_boats))
})

test_that("summarize_boat_composition() pct_angler_boats is in [0, 100]", {
  d <- make_boat_composition_design()
  s <- make_boat_composition_schema()
  result <- summarize_boat_composition(d, s)
  expect_true(all(result$pct_angler_boats >= 0))
  expect_true(all(result$pct_angler_boats <= 100))
})

test_that("summarize_boat_composition() correct pct for known input", {
  # May weekday: AB=3, NB=1 -> 3/(3+1) = 0.75 -> 75.0%
  d <- make_boat_composition_design()
  s <- make_boat_composition_schema()
  result <- summarize_boat_composition(d, s)
  may_weekday <- result[result$month == "May" & result$day_type == "weekday", ]
  expect_equal(may_weekday$pct_angler_boats, 75.0)
})

test_that("summarize_boat_composition() aborts when design is not creel_design", {
  s <- make_boat_composition_schema()
  expect_error(
    summarize_boat_composition(list(), s),
    regexp = "creel_design"
  )
})

test_that("summarize_boat_composition() aborts when design$counts is NULL", {
  # Build a design without add_counts()
  cal <- data.frame(
    date = as.Date("2024-05-01"),
    day_type = "weekday"
  )
  d_no_counts <- suppressWarnings(
    creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter
  )
  s <- make_boat_composition_schema()
  expect_error(
    summarize_boat_composition(d_no_counts, s),
    regexp = "add_counts"
  )
})

test_that("summarize_boat_composition() aborts when schema$angler_boats_col is NULL", {
  d <- make_boat_composition_design()
  s_no_ab <- creel_schema(
    survey_type = "instantaneous",
    non_ang_boats_col = "non_ang_boats"
  )
  expect_error(
    summarize_boat_composition(d, s_no_ab),
    regexp = "angler_boats_col"
  )
})

test_that("summarize_boat_composition() aborts when schema$non_ang_boats_col is NULL", {
  d <- make_boat_composition_design()
  s_no_nb <- creel_schema(
    survey_type = "instantaneous",
    angler_boats_col = "angler_boats"
  )
  expect_error(
    summarize_boat_composition(d, s_no_nb),
    regexp = "non_ang_boats_col"
  )
})

test_that("summarize_boat_composition() result has one row per month x day_type combination", {
  d <- make_boat_composition_design()
  s <- make_boat_composition_schema()
  result <- summarize_boat_composition(d, s)
  # 2 months (May, June) x 2 day types (weekday, weekend) = 4 rows
  expect_equal(nrow(result), 4L)
})

# --- summarize_by_zip() -------------------------------------------------------

make_zip_design <- function(
  zip_pattern = c("68502", "68502", NA_character_, "68508", NA_character_)
) {
  # Use example_interviews, inject a zip_code column (5 rows, 2 NA) for zip tests
  data(example_interviews, package = "tidycreel")
  data(example_calendar, package = "tidycreel")
  ints <- example_interviews
  # Inject zip_code: cycle through zip_pattern for all rows
  ints$zip_code <- rep_len(zip_pattern, nrow(ints))
  d <- suppressWarnings(
    creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  )
  suppressWarnings(
    add_interviews(
      d,
      ints, # nolint: object_usage_linter
      catch = catch_total, # nolint: object_usage_linter
      effort = hours_fished, # nolint: object_usage_linter
      harvest = catch_kept, # nolint: object_usage_linter
      trip_status = trip_status, # nolint: object_usage_linter
      trip_duration = trip_duration, # nolint: object_usage_linter
      angler_type = angler_type, # nolint: object_usage_linter
      angler_method = angler_method, # nolint: object_usage_linter
      species_sought = species_sought, # nolint: object_usage_linter
      n_anglers = n_anglers, # nolint: object_usage_linter
      refused = refused # nolint: object_usage_linter
    )
  )
}

test_that("summarize_by_zip() returns creel_summary_zip class", {
  d <- make_zip_design()
  result <- summarize_by_zip(d)
  expect_s3_class(result, "creel_summary_zip")
  expect_s3_class(result, "data.frame")
})

test_that("summarize_by_zip() has columns zip_code, n, pct", {
  d <- make_zip_design()
  result <- summarize_by_zip(d)
  expect_true(all(c("zip_code", "n", "pct") %in% names(result)))
})

test_that("summarize_by_zip() n is integer, pct is numeric", {
  d <- make_zip_design()
  result <- summarize_by_zip(d)
  expect_true(is.integer(result$n))
  expect_true(is.numeric(result$pct))
})

test_that("summarize_by_zip() includes Unknown row for NA zips", {
  d <- make_zip_design()
  result <- summarize_by_zip(d)
  expect_true("Unknown" %in% result$zip_code)
})

test_that("summarize_by_zip() pct sums to 100 (tolerance 0.5)", {
  d <- make_zip_design()
  result <- summarize_by_zip(d)
  expect_equal(sum(result$pct), 100, tolerance = 0.5)
})

test_that("summarize_by_zip() Unknown row n matches NA count in interviews", {
  d <- make_zip_design()
  result <- summarize_by_zip(d)
  unk_row <- result[result$zip_code == "Unknown", ]
  # NA count should match what was injected: 2 of every 5 rows are NA
  # Verify Unknown n matches actual NA count in interviews
  n_na <- sum(is.na(d$interviews[["zip_code"]]))
  expect_equal(unk_row$n, as.integer(n_na))
  # pct = n_na / total_n * 100
  total_n <- nrow(d$interviews)
  expect_equal(unk_row$pct, round(100 * n_na / total_n, 1))
})

test_that("summarize_by_zip() aborts when interviews not attached", {
  cal <- data.frame(
    date = as.Date("2024-05-01"),
    day_type = "weekday"
  )
  d_no_int <- suppressWarnings(
    creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter
  )
  expect_error(
    summarize_by_zip(d_no_int),
    regexp = "add_interviews"
  )
})

test_that("summarize_by_zip() aborts when the named zip column is not in interviews", {
  # Use example_interviews, which has no zip column at all
  data(example_interviews, package = "tidycreel")
  data(example_calendar, package = "tidycreel")
  d <- suppressWarnings(
    creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  )
  d <- suppressWarnings(
    add_interviews(
      d,
      example_interviews, # nolint: object_usage_linter
      catch = catch_total, # nolint: object_usage_linter
      effort = hours_fished, # nolint: object_usage_linter
      harvest = catch_kept, # nolint: object_usage_linter
      trip_status = trip_status, # nolint: object_usage_linter
      trip_duration = trip_duration, # nolint: object_usage_linter
      angler_type = angler_type, # nolint: object_usage_linter
      angler_method = angler_method, # nolint: object_usage_linter
      species_sought = species_sought, # nolint: object_usage_linter
      n_anglers = n_anglers, # nolint: object_usage_linter
      refused = refused # nolint: object_usage_linter
    )
  )
  expect_error(
    summarize_by_zip(d),
    regexp = "zip_code"
  )
})

# --- summarize_by_county() ----------------------------------------------------

test_that("summarize_by_county() returns creel_summary_county", {
  d <- make_zip_design()
  result <- summarize_by_county(d)
  expect_s3_class(result, "creel_summary_county")
  expect_s3_class(result, "data.frame")
})

test_that("summarize_by_county() has columns county, state, n, pct", {
  d <- make_zip_design()
  result <- summarize_by_county(d)
  expect_identical(names(result), c("county", "state", "n", "pct"))
})

test_that("summarize_by_county() includes Unknown row for NA zips", {
  d <- make_zip_design()
  result <- summarize_by_county(d)
  expect_true("Unknown" %in% result$county)
})

# GH #376: an integer zip column indexed the zip -> county lookup by POSITION,
# so every party came back "Unknown" with no warning (776 of 776 on a real
# survey whose API returns zips as integers). The table must not depend on
# the storage type of the zip column.
test_that("summarize_by_county() maps integer zip codes like character ones (#376)", {
  chr <- summarize_by_county(make_zip_design())
  int <- summarize_by_county(
    make_zip_design(c(68502L, 68502L, NA_integer_, 68508L, NA_integer_))
  )
  dbl <- summarize_by_county(
    make_zip_design(c(68502, 68502, NA_real_, 68508, NA_real_))
  )
  expect_identical(int, chr)
  expect_identical(dbl, chr)
  # The point of the fix: the known zips are mapped, not "Unknown"
  expect_true("Lancaster County" %in% int$county)
  expect_identical(int$n[int$county == "Unknown"], chr$n[chr$county == "Unknown"])
})

test_that("summarize_by_county() restores the leading zero of an integer zip (#376)", {
  # 02134 (Boston) stored as an integer is 2134; it must still map
  result <- summarize_by_county(make_zip_design(c(2134L, NA_integer_)))
  expect_true("Suffolk County" %in% result$county)
})

test_that("summarize_by_county() maps a factor zip column by its labels (#376)", {
  # A factor indexes by its integer codes, the same position bug. The levels
  # run opposite to the lookup's row order (02134 sorts first) and the two zips
  # are in different counties, so a positional lookup gives the wrong county.
  zips <- c("68502", "68502", "02134", NA)
  chr <- summarize_by_county(make_zip_design(zips))
  fct <- summarize_by_county(
    make_zip_design(factor(zips, levels = c("68502", "02134")))
  )
  expect_identical(fct, chr)
  expect_true(all(c("Lancaster County", "Suffolk County") %in% fct$county))
})

test_that("summarize_by_county() refuses a numeric zip that is not a whole number (#376)", {
  # Truncating 68502.7 to 68502 would invent a county for a corrupt value
  expect_error(
    summarize_by_county(make_zip_design(c(68502.7, 68508))),
    class = "creel_error_invalid_input"
  )
})

# GH #376 part 2: the table carried only the county name, so Washington
# County, MN and Washington County, NE were one row -- anglers from two states
# reported as one place. County must be grouped with its state.
test_that("summarize_by_county() keeps same-named counties in different states apart (#376)", {
  # 55082 Stillwater, MN and 68008 Blair, NE: both Washington County
  result <- summarize_by_county(make_zip_design(c("55082", "68008", "68008")))
  wash <- result[result$county == "Washington County", ]
  expect_identical(nrow(wash), 2L)
  expect_identical(wash$state[order(wash$state)], c("MN", "NE"))
  expect_identical(sum(wash$n), nrow(make_zip_design()$interviews))
})

test_that("summarize_by_county() reports Unknown last with state NA, not a state", {
  result <- summarize_by_county(make_zip_design())
  last <- result[nrow(result), ]
  expect_identical(last$county, "Unknown")
  expect_true(is.na(last$state))
  expect_false(anyNA(result$state[-nrow(result)]))
})

# The default lookup is Census ZCTAs, which omit PO-box ZIPs. A zip the lookup
# lacks must be counted, as Unknown, AND announced: dropping to Unknown quietly
# is the believable-wrong-answer pattern #376 was filed about.
test_that("summarize_by_county() announces zips missing from the lookup", {
  d <- make_zip_design(c("68502", "00000", NA))
  expect_message(result <- summarize_by_county(d), "not in the lookup")
  n_total <- nrow(d$interviews)
  n_unknown <- result$n[result$county == "Unknown"]
  # 00000 and NA both land in Unknown; nothing is dropped
  expect_identical(sum(result$n), n_total)
  expect_identical(n_unknown, sum(rep_len(c(FALSE, TRUE, TRUE), n_total)))
})

test_that("summarize_by_county() stays silent when every zip maps", {
  d <- suppressMessages(make_zip_design())
  expect_no_message(summarize_by_county(d))
})

test_that("summarize_by_county() uses a caller's lookup instead of the Census table (#376)", {
  # 00000 is no ZCTA; a caller's crosswalk can still place it. Numeric lookup
  # zips are keyed like interview zips, so 2134 matches "02134".
  own <- data.frame(
    zip = c(0, 2134),
    county = c("PO Box County", "Own Suffolk"),
    state = c("ZZ", "MA")
  )
  expect_message(
    result <- summarize_by_county(
      make_zip_design(c("00000", "02134", "68502")),
      lookup = own
    ),
    "not in the lookup"
  )
  expect_true(all(c("PO Box County", "Own Suffolk") %in% result$county))
  # 68502 is not in the caller's table, so the Census table is NOT consulted
  expect_false("Lancaster County" %in% result$county)
  expect_identical(result$state[result$county == "PO Box County"], "ZZ")
})

test_that("summarize_by_county() refuses a lookup that maps one zip to two counties", {
  own <- data.frame(
    zip = c("68008", "68008"),
    county = c("Washington County", "Dodge County"),
    state = "NE"
  )
  expect_error(
    summarize_by_county(make_zip_design(), lookup = own),
    class = "creel_error_invalid_input"
  )
})

test_that("summarize_by_county() refuses a lookup without zip, county and state", {
  expect_error(
    summarize_by_county(make_zip_design(), lookup = data.frame(zip = "68502", county = "X")),
    class = "creel_error_invalid_input"
  )
  expect_error(
    summarize_by_county(
      make_zip_design(),
      lookup = data.frame(zip = "68502", county = NA_character_, state = "NE")
    ),
    class = "creel_error_invalid_input"
  )
})

# zip_county is the default the counts above depend on: one county per zip,
# keys that keep their leading zero, and a state on every row.
test_that("zip_county has one row per 5-digit zip, each with a state", {
  data(zip_county, package = "tidycreel")
  expect_false(anyDuplicated(zip_county$zip) > 0L)
  expect_true(all(grepl("^[0-9]{5}$", zip_county$zip)))
  expect_false(anyNA(zip_county$state))
  expect_true(all(zip_county$land_share > 0 & zip_county$land_share <= 1))
  expect_identical(zip_county$land_share[zip_county$n_counties == 1L] == 1, rep(TRUE, sum(zip_county$n_counties == 1L)))
  expect_identical(zip_county$county[zip_county$zip == "02134"], "Suffolk County")
})

test_that("summarize_by_county() aborts when interviews not attached", {
  data(example_calendar, package = "tidycreel")
  d_no_int <- suppressWarnings(
    creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  )
  expect_error(
    summarize_by_county(d_no_int),
    regexp = "add_interviews"
  )
})

test_that("summarize_by_county() aborts when the named zip column is not in interviews", {
  data(example_interviews, package = "tidycreel")
  data(example_calendar, package = "tidycreel")
  d <- suppressWarnings(
    creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  )
  d <- suppressWarnings(
    add_interviews(
      d,
      example_interviews, # nolint: object_usage_linter
      catch = catch_total, # nolint: object_usage_linter
      effort = hours_fished, # nolint: object_usage_linter
      harvest = catch_kept, # nolint: object_usage_linter
      trip_status = trip_status, # nolint: object_usage_linter
      trip_duration = trip_duration, # nolint: object_usage_linter
      angler_type = angler_type, # nolint: object_usage_linter
      angler_method = angler_method, # nolint: object_usage_linter
      species_sought = species_sought, # nolint: object_usage_linter
      n_anglers = n_anglers, # nolint: object_usage_linter
      refused = refused # nolint: object_usage_linter
    )
  )
  expect_error(
    summarize_by_county(d),
    regexp = "zip_code"
  )
})

# --- Day type column resolution — RPT-06 (GH #221) ----------------------------
#
# The same `strata_cols[1]` defect as USUM-09, in the second of its two sites.
# Here it moves numbers as well as labels: the reported percentages were the
# per-site means printed under a `day_type` header.

make_two_strata_boat_design <- function(strata_second = "day_type") {
  dates <- as.Date("2024-06-01") + 0:5
  counts_df <- data.frame(
    date = dates,
    site = rep(c("north", "south"), 3),
    day_type = rep(c("weekday", "weekend"), each = 3),
    period = rep(c("am", "pm"), each = 3),
    # Composition is driven by SITE, so a site grouping and a day_type grouping
    # give different numbers — a balanced fixture could not tell them apart.
    angler_boats = c(9L, 1L, 9L, 1L, 9L, 1L),
    non_ang_boats = c(1L, 9L, 1L, 9L, 1L, 9L),
    count = 10L,
    stringsAsFactors = FALSE
  )
  cal <- counts_df[, c("date", "site", "day_type", "period")]
  # `site` declared FIRST on purpose.
  d <- suppressWarnings(creel_design(
    cal,
    date = date, # nolint: object_usage_linter
    strata = c("site", strata_second),
    survey_type = "instantaneous"
  ))
  suppressWarnings(
    add_counts(d, counts_df, count_col = count) # nolint: object_usage_linter
  )
}

test_that("summarize_boat_composition() groups by the stratum named day_type", {
  d <- make_two_strata_boat_design()
  s <- make_boat_composition_schema()

  result <- suppressWarnings(summarize_boat_composition(d, s))

  expect_setequal(result$day_type, c("weekday", "weekend"))
  expect_false(any(c("north", "south") %in% result$day_type))
})

test_that("summarize_boat_composition() reports the day type percentages, not the site ones", {
  d <- make_two_strata_boat_design()
  s <- make_boat_composition_schema()

  result <- suppressWarnings(summarize_boat_composition(d, s))

  # Truth by day type: weekday days carry ratios 0.9, 0.1, 0.9 -> 63.3%;
  # weekend days 0.1, 0.9, 0.1 -> 36.7%. Grouped by site it was 90 / 10.
  weekday_pct <- result$pct_angler_boats[result$day_type == "weekday"]
  weekend_pct <- result$pct_angler_boats[result$day_type == "weekend"]
  expect_equal(weekday_pct, 63.3, tolerance = 1e-8)
  expect_equal(weekend_pct, 36.7, tolerance = 1e-8)
  expect_false(isTRUE(all.equal(weekday_pct, 90)))
})

test_that("summarize_boat_composition() warns and names the column when it must guess", {
  d <- make_two_strata_boat_design(strata_second = "period")
  s <- make_boat_composition_schema()

  expect_message(
    summarize_boat_composition(d, s),
    "Using stratum.*site.*as the day type"
  )
})

test_that("summarize_boat_composition() honours an explicit day_type_col", {
  d <- make_two_strata_boat_design(strata_second = "period")
  s <- make_boat_composition_schema()

  result <- summarize_boat_composition(d, s, day_type_col = "day_type")

  expect_setequal(result$day_type, c("weekday", "weekend"))
  expect_equal(
    result$pct_angler_boats[result$day_type == "weekday"],
    63.3,
    tolerance = 1e-8
  )
})

test_that("summarize_boat_composition() is silent for a single-stratum design", {
  d <- make_boat_composition_design()
  s <- make_boat_composition_schema()

  # Inertness control — the documented single-stratum workflow must not warn.
  # A message since GH #496, so a no-warning check would pass regardless.
  expect_no_message(summarize_boat_composition(d, s), class = "creel_message_day_type_from_stratum")
})
