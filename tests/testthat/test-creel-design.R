# Tests for creel_design S3 class

test_that("creel_design() creates valid object with basic inputs", {
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02")),
    day_type = c("weekday", "weekend")
  )
  design <- creel_design(cal, date = date, strata = day_type)

  expect_s3_class(design, "creel_design")
  expect_equal(design$date_col, "date")
  expect_equal(design$strata_cols, "day_type")
  expect_null(design$site_col)
  expect_equal(design$design_type, "instantaneous")
  expect_identical(design$calendar, cal)
})

test_that("creel_design() accepts multiple strata columns", {
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03")),
    day_type = c("weekday", "weekend", "weekend"),
    season = c("summer", "summer", "summer")
  )
  design <- creel_design(cal, date = date, strata = c(day_type, season))

  expect_equal(design$strata_cols, c("day_type", "season"))
  expect_length(design$strata_cols, 2)
})

test_that("creel_design() accepts optional site column", {
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02")),
    day_type = c("weekday", "weekend"),
    lake = c("lake_a", "lake_b")
  )
  design <- creel_design(cal, date = date, strata = day_type, site = lake)

  expect_equal(design$site_col, "lake")
})

test_that("creel_design() sets site_col to NULL when site omitted", {
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02")),
    day_type = c("weekday", "weekend")
  )
  design <- creel_design(cal, date = date, strata = day_type)

  expect_null(design$site_col)
})

test_that("creel_design() accepts tidyselect helpers", {
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02")),
    day_type = c("weekday", "weekend"),
    day_season = c("summer", "summer")
  )
  design <- creel_design(cal, date = date, strata = starts_with("day"))

  expect_equal(design$strata_cols, c("day_type", "day_season"))
})

test_that("creel_design() fails when date column is not Date class", {
  cal <- data.frame(
    date = c("2024-06-01", "2024-06-02"),
    day_type = c("weekday", "weekend")
  )

  # Schema validator catches this (no Date column exists in the data frame)
  expect_error(
    creel_design(cal, date = date, strata = day_type),
    class = "rlang_error"
  )
})

test_that("creel_design() fails when date column is numeric", {
  cal <- data.frame(
    date = c(1, 2, 3),
    day_type = c("weekday", "weekend", "weekend")
  )

  # Schema validator catches this (no Date column exists in the data frame)
  expect_error(
    creel_design(cal, date = date, strata = day_type),
    class = "rlang_error"
  )
})

test_that("creel_design() fails when date column contains NA values", {
  cal <- data.frame(
    date = as.Date(c("2024-06-01", NA, "2024-06-03")),
    day_type = c("weekday", "weekend", "weekend")
  )

  expect_error(
    creel_design(cal, date = date, strata = day_type),
    class = "rlang_error"
  )
  expect_error(
    creel_design(cal, date = date, strata = day_type),
    "must not contain"
  )
})

test_that("creel_design() fails when strata column is numeric", {
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02")),
    day_type = c(1, 2)
  )

  # Schema validator catches this (no character/factor column exists)
  expect_error(
    creel_design(cal, date = date, strata = day_type),
    class = "rlang_error"
  )
})

test_that("creel_design() Tier 1 validation fails when selected date is not Date", {
  # Schema passes (has Date column), but selected column is wrong type
  cal <- data.frame(
    actual_date = as.Date(c("2024-06-01", "2024-06-02")),
    date_string = c("2024-06-01", "2024-06-02"),
    day_type = c("weekday", "weekend")
  )

  expect_error(
    creel_design(cal, date = date_string, strata = day_type),
    "must be of class"
  )
})

test_that("creel_design() Tier 1 validation fails when selected strata is numeric", {
  # Schema passes (has character column), but selected column is wrong type
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02")),
    day_type = c("weekday", "weekend"),
    numeric_col = c(1, 2)
  )

  expect_error(
    creel_design(cal, date = date, strata = numeric_col),
    "must be character or factor"
  )
})

test_that("creel_design() fails when selecting non-existent column", {
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02")),
    day_type = c("weekday", "weekend")
  )

  expect_error(
    creel_design(cal, date = nonexistent, strata = day_type)
  )
})

test_that("creel_design() fails when date selector matches multiple columns", {
  cal <- data.frame(
    date1 = as.Date(c("2024-06-01", "2024-06-02")),
    date2 = as.Date(c("2024-06-01", "2024-06-02")),
    day_type = c("weekday", "weekend")
  )

  expect_error(
    creel_design(cal, date = starts_with("date"), strata = day_type),
    "exactly one column"
  )
})

test_that("format.creel_design() returns character vector", {
  cal <- data.frame(
    date = as.Date("2024-06-01"),
    day_type = "weekday"
  )
  design <- creel_design(cal, date = date, strata = day_type)
  out <- format(design)

  expect_type(out, "character")
  expect_true(length(out) > 0)
})

test_that("print.creel_design() returns invisibly", {
  cal <- data.frame(
    date = as.Date("2024-06-01"),
    day_type = "weekday"
  )
  design <- creel_design(cal, date = date, strata = day_type)

  expect_invisible(print(design))
})

test_that("summary.creel_design() returns invisibly", {
  cal <- data.frame(
    date = as.Date("2024-06-01"),
    day_type = "weekday"
  )
  design <- creel_design(cal, date = date, strata = day_type)

  expect_invisible(summary(design))
})

test_that("creel_design() stores original calendar data frame", {
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02")),
    day_type = c("weekday", "weekend")
  )
  design <- creel_design(cal, date = date, strata = day_type)

  expect_identical(design$calendar, cal)
})

test_that("creel_design() defaults design_type to instantaneous", {
  cal <- data.frame(
    date = as.Date("2024-06-01"),
    day_type = "weekday"
  )
  design <- creel_design(cal, date = date, strata = day_type)

  expect_equal(design$design_type, "instantaneous")
})

# Format/print with counts attached ----

test_that("format.creel_design() shows count information when counts attached", {
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
    day_type = c("weekday", "weekday", "weekend", "weekend")
  )
  design <- creel_design(cal, date = date, strata = day_type)
  counts <- data.frame(
    date = cal$date,
    day_type = cal$day_type,
    effort_hours = c(15, 23, 45, 52)
  )
  design_with_counts <- add_counts(design, counts)

  formatted <- format(design_with_counts)

  # Should show counts information
  expect_true(any(grepl("Counts:", formatted, fixed = TRUE)))
  expect_true(any(grepl("PSU column:", formatted, fixed = TRUE)))
  expect_true(any(grepl("Survey:", formatted, fixed = TRUE)))
})

# Bus-Route design ----

# Helper to build a minimal valid sampling_frame for bus-route tests
make_br_sf <- function() {
  data.frame(
    site = c("A", "B", "C"),
    p_site = c(0.3, 0.4, 0.3),
    p_period = rep(0.5, 3),
    stringsAsFactors = FALSE
  )
}

make_br_cal <- function() {
  data.frame(
    date = as.Date("2024-06-01"),
    day_type = "weekday",
    stringsAsFactors = FALSE
  )
}

test_that("creel_design() accepts survey_type = 'bus_route' with valid inputs", {
  d <- creel_design(make_br_cal(),
    date = date, strata = day_type,
    survey_type = "bus_route", sampling_frame = make_br_sf(),
    site = site, p_site = p_site, p_period = p_period
  )

  expect_s3_class(d, "creel_design")
  expect_equal(d$design_type, "bus_route")
  expect_false(is.null(d$bus_route))
})

test_that("bus_route slot contains data frame with .pi_i column", {
  d <- creel_design(make_br_cal(),
    date = date, strata = day_type,
    survey_type = "bus_route", sampling_frame = make_br_sf(),
    site = site, p_site = p_site, p_period = p_period
  )

  expect_true(is.data.frame(d$bus_route$data))
  expect_true(".pi_i" %in% names(d$bus_route$data))
  expect_equal(d$bus_route$data$.pi_i, c(0.15, 0.20, 0.15))
})

test_that("bus_route slot stores correct column mappings", {
  d <- creel_design(make_br_cal(),
    date = date, strata = day_type,
    survey_type = "bus_route", sampling_frame = make_br_sf(),
    site = site, p_site = p_site, p_period = p_period
  )

  expect_equal(d$bus_route$site_col, "site")
  expect_equal(d$bus_route$p_site_col, "p_site")
  expect_equal(d$bus_route$p_period_col, "p_period")
  expect_equal(d$bus_route$pi_i_col, ".pi_i")
})

test_that("omitting circuit column defaults to single .default circuit", {
  d <- creel_design(make_br_cal(),
    date = date, strata = day_type,
    survey_type = "bus_route", sampling_frame = make_br_sf(),
    site = site, p_site = p_site, p_period = p_period
  )

  expect_equal(d$bus_route$circuit_col, ".circuit")
  expect_true(all(d$bus_route$data$.circuit == ".default"))
})

test_that("circuit column is respected when provided", {
  sf <- data.frame(
    site = rep(c("A", "B", "C"), 2),
    route = rep(c("morning", "evening"), each = 3),
    p_site = rep(c(0.3, 0.4, 0.3), 2),
    p_period = rep(c(0.4, 0.6), each = 3),
    stringsAsFactors = FALSE
  )
  d <- creel_design(make_br_cal(),
    date = date, strata = day_type,
    survey_type = "bus_route", sampling_frame = sf,
    site = site, p_site = p_site, circuit = route, p_period = p_period
  )

  expect_equal(d$bus_route$circuit_col, "route")
  expect_setequal(unique(d$bus_route$data$route), c("morning", "evening"))
})

test_that("p_period as scalar applies to all rows", {
  sf <- data.frame(
    site = c("A", "B"), p_site = c(0.6, 0.4),
    stringsAsFactors = FALSE
  )
  d <- creel_design(make_br_cal(),
    date = date, strata = day_type,
    survey_type = "bus_route", sampling_frame = sf,
    site = site, p_site = p_site, p_period = 0.25
  )

  expect_true(all(d$bus_route$data$.p_period == 0.25))
  expect_equal(d$bus_route$data$.pi_i, c(0.6 * 0.25, 0.4 * 0.25))
})

test_that("validation fails when p_site does not sum to 1.0 within circuit", {
  sf <- data.frame(
    site = c("A", "B"), p_site = c(0.3, 0.4), p_period = 0.5,
    stringsAsFactors = FALSE
  )
  expect_error(
    creel_design(make_br_cal(),
      date = date, strata = day_type,
      survey_type = "bus_route", sampling_frame = sf,
      site = site, p_site = p_site, p_period = p_period
    ),
    class = "rlang_error"
  )
  expect_error(
    creel_design(make_br_cal(),
      date = date, strata = day_type,
      survey_type = "bus_route", sampling_frame = sf,
      site = site, p_site = p_site, p_period = p_period
    ),
    "sum to 1\\.0"
  )
})

test_that("validation error message includes circuit name and actual sum", {
  sf <- data.frame(
    site = rep(c("A", "B", "C"), 2),
    route = rep(c("AM", "PM"), each = 3),
    p_site = c(0.3, 0.4, 0.2, 0.3, 0.4, 0.3), # AM sums to 0.9, PM sums to 1.0
    p_period = rep(0.5, 6),
    stringsAsFactors = FALSE
  )
  err <- tryCatch(
    creel_design(make_br_cal(),
      date = date, strata = day_type,
      survey_type = "bus_route", sampling_frame = sf,
      site = site, p_site = p_site, circuit = route, p_period = p_period
    ),
    error = function(e) conditionMessage(e)
  )
  expect_match(err, "AM")
})

test_that("validation fails when p_site value is zero", {
  sf <- data.frame(
    site = c("A", "B", "C"), p_site = c(0.3, 0.0, 0.7), p_period = 0.5,
    stringsAsFactors = FALSE
  )
  expect_error(
    creel_design(make_br_cal(),
      date = date, strata = day_type,
      survey_type = "bus_route", sampling_frame = sf,
      site = site, p_site = p_site, p_period = p_period
    ),
    class = "rlang_error"
  )
})

test_that("validation fails when p_site value exceeds 1", {
  sf <- data.frame(
    site = c("A"), p_site = c(1.1), p_period = 0.5,
    stringsAsFactors = FALSE
  )
  expect_error(
    creel_design(make_br_cal(),
      date = date, strata = day_type,
      survey_type = "bus_route", sampling_frame = sf,
      site = site, p_site = p_site, p_period = p_period
    ),
    class = "rlang_error"
  )
})

test_that("validation fails when p_period value exceeds 1", {
  sf <- data.frame(
    site = c("A", "B"), p_site = c(0.6, 0.4), p_period = c(0.5, 1.5),
    stringsAsFactors = FALSE
  )
  expect_error(
    creel_design(make_br_cal(),
      date = date, strata = day_type,
      survey_type = "bus_route", sampling_frame = sf,
      site = site, p_site = p_site, p_period = p_period
    ),
    class = "rlang_error"
  )
})

test_that("validation fails when sampling_frame is missing for bus_route", {
  expect_error(
    creel_design(make_br_cal(),
      date = date, strata = day_type,
      survey_type = "bus_route", site = site, p_site = p_site, p_period = 0.5
    ),
    class = "rlang_error"
  )
})

test_that("p_site sums within 1e-6 tolerance are accepted", {
  # Floating-point arithmetic: 0.1 + 0.2 + 0.7 may not be exactly 1.0
  sf <- data.frame(
    site = c("A", "B", "C"),
    p_site = c(0.1, 0.2, 0.7),
    p_period = 0.5,
    stringsAsFactors = FALSE
  )
  # Should not error (sum is 1.0 within floating point)
  expect_no_error(
    creel_design(make_br_cal(),
      date = date, strata = day_type,
      survey_type = "bus_route", sampling_frame = sf,
      site = site, p_site = p_site, p_period = p_period
    )
  )
})

test_that("existing instantaneous designs still work with bus_route = NULL", {
  cal <- data.frame(
    date = as.Date("2024-06-01"), day_type = "weekday",
    stringsAsFactors = FALSE
  )
  d <- creel_design(cal, date = date, strata = day_type)

  expect_null(d$bus_route)
  expect_equal(d$design_type, "instantaneous")
})

test_that("format.creel_design() includes Bus-Route section for bus_route designs", {
  d <- creel_design(make_br_cal(),
    date = date, strata = day_type,
    survey_type = "bus_route", sampling_frame = make_br_sf(),
    site = site, p_site = p_site, p_period = p_period
  )
  out <- format(d)

  expect_true(any(grepl("Bus-Route", out, fixed = TRUE)))
  expect_true(any(grepl("p_site", out, fixed = TRUE)))
  expect_true(any(grepl("pi_i", out, fixed = TRUE)))
})

test_that("format.creel_design() does not include Bus-Route section for instantaneous designs", {
  cal <- data.frame(
    date = as.Date("2024-06-01"), day_type = "weekday",
    stringsAsFactors = FALSE
  )
  d <- creel_design(cal, date = date, strata = day_type)
  out <- format(d)

  expect_false(any(grepl("Bus-Route", out, fixed = TRUE)))
})

test_that("get_sampling_frame() returns the stored data frame", {
  d <- creel_design(make_br_cal(),
    date = date, strata = day_type,
    survey_type = "bus_route", sampling_frame = make_br_sf(),
    site = site, p_site = p_site, p_period = p_period
  )
  sf_out <- get_sampling_frame(d)

  expect_true(is.data.frame(sf_out))
  expect_true(".pi_i" %in% names(sf_out))
  expect_true("site" %in% names(sf_out))
  expect_true("p_site" %in% names(sf_out))
})

test_that("get_sampling_frame() errors on non-bus-route design", {
  cal <- data.frame(
    date = as.Date("2024-06-01"), day_type = "weekday",
    stringsAsFactors = FALSE
  )
  d <- creel_design(cal, date = date, strata = day_type)

  expect_error(get_sampling_frame(d), class = "rlang_error")
  expect_error(get_sampling_frame(d), "only available for bus-route")
})

test_that("get_sampling_frame() errors on non-creel_design input", {
  expect_error(get_sampling_frame(list()), class = "rlang_error")
})
