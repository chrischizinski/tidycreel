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

# Inclusion probability calculation ----

# Helper for multi-circuit sampling frame (2 circuits, 2 sites each)
make_br_sf_2circuit <- function() {
  data.frame(
    site = c("A", "B", "C", "D"),
    route = c("R1", "R1", "R2", "R2"),
    p_site = c(0.3, 0.7, 0.6, 0.4),
    p_period = c(0.4, 0.4, 0.5, 0.5),
    stringsAsFactors = FALSE
  )
}

# Golden tests — pi_i arithmetic correctness (VALID-03) ----

test_that("golden test 1: single-circuit scalar p_period pi_i = p_site * p_period", {
  sf <- data.frame(
    site = c("A", "B", "C"),
    p_site = c(0.20, 0.50, 0.30),
    stringsAsFactors = FALSE
  )
  d <- creel_design(make_br_cal(),
    date = date, strata = day_type,
    survey_type = "bus_route", sampling_frame = sf,
    site = site, p_site = p_site, p_period = 0.30
  )

  expect_equal(d$bus_route$data$.pi_i, c(0.06, 0.15, 0.09), tolerance = 1e-10)
})

test_that("golden test 2: single-circuit column p_period pi_i = p_site * p_period", {
  sf <- data.frame(
    site = c("A", "B"),
    p_site = c(0.40, 0.60),
    p_period = c(0.25, 0.25),
    stringsAsFactors = FALSE
  )
  d <- creel_design(make_br_cal(),
    date = date, strata = day_type,
    survey_type = "bus_route", sampling_frame = sf,
    site = site, p_site = p_site, p_period = p_period
  )

  expect_equal(d$bus_route$data$.pi_i, c(0.10, 0.15), tolerance = 1e-10)
})

test_that("golden test 3: multi-circuit varying p_site and p_period", {
  d <- creel_design(make_br_cal(),
    date = date, strata = day_type,
    survey_type = "bus_route", sampling_frame = make_br_sf_2circuit(),
    site = site, p_site = p_site, circuit = route, p_period = p_period
  )

  expect_equal(d$bus_route$data$.pi_i, c(0.12, 0.28, 0.30, 0.20), tolerance = 1e-10)
})

test_that("golden test 4: boundary values p_site=1.0, p_period=1.0 -> pi_i=1.0 exactly", {
  sf <- data.frame(
    site = c("A"),
    p_site = c(1.0),
    p_period = c(1.0),
    stringsAsFactors = FALSE
  )
  d <- creel_design(make_br_cal(),
    date = date, strata = day_type,
    survey_type = "bus_route", sampling_frame = sf,
    site = site, p_site = p_site, p_period = p_period
  )

  expect_equal(d$bus_route$data$.pi_i, 1.0, tolerance = 1e-10)
})

# Validation tests — p_period uniformity constraint ----

test_that("p_period varying within single circuit errors with 'constant within each circuit'", {
  sf <- data.frame(
    site = c("A", "B"),
    p_site = c(0.5, 0.5),
    p_period = c(0.3, 0.6),
    stringsAsFactors = FALSE
  )
  expect_error(
    creel_design(make_br_cal(),
      date = date, strata = day_type,
      survey_type = "bus_route", sampling_frame = sf,
      site = site, p_site = p_site, p_period = p_period
    ),
    "constant within each circuit"
  )
})

test_that("p_period varying within one of two circuits errors mentioning failing circuit name", {
  sf <- data.frame(
    site = c("A", "B", "C", "D"),
    route = c("R1", "R1", "R2", "R2"),
    p_site = c(0.5, 0.5, 0.5, 0.5),
    p_period = c(0.4, 0.4, 0.3, 0.6), # R2 non-uniform
    stringsAsFactors = FALSE
  )
  expect_error(
    creel_design(make_br_cal(),
      date = date, strata = day_type,
      survey_type = "bus_route", sampling_frame = sf,
      site = site, p_site = p_site, circuit = route, p_period = p_period
    ),
    "constant within each circuit"
  )
  expect_error(
    creel_design(make_br_cal(),
      date = date, strata = day_type,
      survey_type = "bus_route", sampling_frame = sf,
      site = site, p_site = p_site, circuit = route, p_period = p_period
    ),
    "R2"
  )
})

test_that("different circuits with different but uniform p_period values succeed", {
  # R1 has p_period=0.4, R2 has p_period=0.6 — each circuit is uniform
  sf <- data.frame(
    site = c("A", "B", "C", "D"),
    route = c("R1", "R1", "R2", "R2"),
    p_site = c(0.5, 0.5, 0.5, 0.5),
    p_period = c(0.4, 0.4, 0.6, 0.6),
    stringsAsFactors = FALSE
  )
  expect_no_error(
    creel_design(make_br_cal(),
      date = date, strata = day_type,
      survey_type = "bus_route", sampling_frame = sf,
      site = site, p_site = p_site, circuit = route, p_period = p_period
    )
  )
})

test_that("scalar p_period always passes uniformity check", {
  sf <- data.frame(
    site = c("A", "B", "C"),
    p_site = c(0.2, 0.5, 0.3),
    stringsAsFactors = FALSE
  )
  expect_no_error(
    creel_design(make_br_cal(),
      date = date, strata = day_type,
      survey_type = "bus_route", sampling_frame = sf,
      site = site, p_site = p_site, p_period = 0.45
    )
  )
})

# get_inclusion_probs() unit tests ----

test_that("get_inclusion_probs() returns data frame with 3 correct columns for single-circuit design", {
  d <- creel_design(make_br_cal(),
    date = date, strata = day_type,
    survey_type = "bus_route", sampling_frame = make_br_sf(),
    site = site, p_site = p_site, p_period = p_period
  )
  out <- get_inclusion_probs(d)

  expect_true(is.data.frame(out))
  expect_equal(ncol(out), 3L)
  expect_equal(names(out), c("site", ".circuit", ".pi_i"))
})

test_that("get_inclusion_probs() returns correct pi_i values matching bus_route$data$.pi_i", {
  # Same setup as golden test 1 for value consistency check
  sf <- data.frame(
    site = c("A", "B", "C"),
    p_site = c(0.20, 0.50, 0.30),
    stringsAsFactors = FALSE
  )
  d <- creel_design(make_br_cal(),
    date = date, strata = day_type,
    survey_type = "bus_route", sampling_frame = sf,
    site = site, p_site = p_site, p_period = 0.30
  )
  out <- get_inclusion_probs(d)

  expect_equal(out$.pi_i, d$bus_route$data$.pi_i, tolerance = 1e-10)
  expect_equal(out$.pi_i, c(0.06, 0.15, 0.09), tolerance = 1e-10)
})

test_that("get_inclusion_probs() multi-circuit returns correct site, circuit, and pi_i columns", {
  d <- creel_design(make_br_cal(),
    date = date, strata = day_type,
    survey_type = "bus_route", sampling_frame = make_br_sf_2circuit(),
    site = site, p_site = p_site, circuit = route, p_period = p_period
  )
  out <- get_inclusion_probs(d)

  expect_equal(ncol(out), 3L)
  expect_equal(names(out), c("site", "route", ".pi_i"))
  expect_equal(out$.pi_i, c(0.12, 0.28, 0.30, 0.20), tolerance = 1e-10)
  expect_equal(out$route, c("R1", "R1", "R2", "R2"))
})

test_that("get_inclusion_probs() on non-bus-route design errors with 'only available for bus-route'", {
  cal <- data.frame(
    date = as.Date("2024-06-01"), day_type = "weekday",
    stringsAsFactors = FALSE
  )
  d <- creel_design(cal, date = date, strata = day_type)

  expect_error(get_inclusion_probs(d), "only available for bus-route")
})

test_that("get_inclusion_probs() on plain list errors with 'must be a creel_design'", {
  expect_error(
    get_inclusion_probs(list()),
    "must be a"
  )
  expect_error(
    get_inclusion_probs(list()),
    class = "rlang_error"
  )
})

# Property tests — range invariant (BUSRT-05) ----

test_that("range invariant: all pi_i values in (0,1] for edge-case probability combinations", {
  # p_site=0.01, p_period=0.99 -> pi_i=0.0099 (near 0 but valid)
  sf1 <- data.frame(
    site = c("A", "B"),
    p_site = c(0.01, 0.99),
    p_period = c(0.99, 0.99),
    stringsAsFactors = FALSE
  )
  d1 <- creel_design(make_br_cal(),
    date = date, strata = day_type,
    survey_type = "bus_route", sampling_frame = sf1,
    site = site, p_site = p_site, p_period = p_period
  )
  pi_i_1 <- d1$bus_route$data$.pi_i
  expect_true(all(pi_i_1 > 0))
  expect_true(all(pi_i_1 <= 1))
  expect_equal(pi_i_1[1], 0.01 * 0.99, tolerance = 1e-10)

  # p_site=0.99, p_period=0.01 -> pi_i=0.0099 (same product, different factors)
  sf2 <- data.frame(
    site = c("A", "B"),
    p_site = c(0.99, 0.01),
    p_period = c(0.01, 0.01),
    stringsAsFactors = FALSE
  )
  d2 <- creel_design(make_br_cal(),
    date = date, strata = day_type,
    survey_type = "bus_route", sampling_frame = sf2,
    site = site, p_site = p_site, p_period = p_period
  )
  pi_i_2 <- d2$bus_route$data$.pi_i
  expect_true(all(pi_i_2 > 0))
  expect_true(all(pi_i_2 <= 1))
  expect_equal(pi_i_2[1], 0.99 * 0.01, tolerance = 1e-10)
})

test_that("vectorization consistency: 5-site design with varying p_site and scalar p_period", {
  p_sites <- c(0.1, 0.2, 0.3, 0.25, 0.15)
  p_period_val <- 0.4
  sf <- data.frame(
    site = c("A", "B", "C", "D", "E"),
    p_site = p_sites,
    stringsAsFactors = FALSE
  )
  d <- creel_design(make_br_cal(),
    date = date, strata = day_type,
    survey_type = "bus_route", sampling_frame = sf,
    site = site, p_site = p_site, p_period = p_period_val
  )

  expected_pi_i <- p_sites * p_period_val
  expect_equal(d$bus_route$data$.pi_i, expected_pi_i, tolerance = 1e-10)
})

test_that("new creel_design has NULL sections and section_col by default", {
  cal <- data.frame(
    date = as.Date("2024-06-01"),
    day_type = "weekday",
    stringsAsFactors = FALSE
  )
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter
  expect_null(design$sections)
  expect_null(design$section_col)
})

test_that("format.creel_design() shows 'Sections: none' when no sections registered", {
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02")),
    day_type = c("weekday", "weekend"),
    stringsAsFactors = FALSE
  )
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter
  output <- format(design)
  expect_true(any(grepl("none", output)))
})

test_that("format.creel_design() shows section count when sections registered", {
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02")),
    day_type = c("weekday", "weekend"),
    stringsAsFactors = FALSE
  )
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter
  secs <- data.frame(
    section = c("North", "South"),
    stringsAsFactors = FALSE
  )
  design2 <- add_sections(design, secs, section_col = section) # nolint: object_usage_linter
  output <- format(design2)
  expect_true(any(grepl("2", output)))
  expect_true(any(grepl("[Ss]ection", output)))
})

test_that("format.creel_design() shows area when area_col registered", {
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02")),
    day_type = c("weekday", "weekend"),
    stringsAsFactors = FALSE
  )
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter
  secs <- data.frame(
    section = c("North", "South"),
    area_ha = c(100.0, 200.0),
    stringsAsFactors = FALSE
  )
  design2 <- add_sections(design, secs,
    section_col = section, # nolint: object_usage_linter
    area_col    = area_ha # nolint: object_usage_linter
  )
  output <- format(design2)
  expect_true(any(grepl("ha", output)))
})

# Enum guard (INFRA-02) and ice/camera/aerial stubs (INFRA-01) ----

make_enum_cal <- function() {
  data.frame(
    date = as.Date("2024-06-01"),
    day_type = "weekday",
    stringsAsFactors = FALSE
  )
}

test_that("creel_design() aborts with rlang_error for unknown survey_type", {
  expect_error(
    creel_design(make_enum_cal(),
      date = date, strata = day_type,
      survey_type = "unknown_type"
    ),
    class = "rlang_error"
  )
})

test_that("enum guard error message names the bad survey_type value", {
  expect_error(
    creel_design(make_enum_cal(),
      date = date, strata = day_type,
      survey_type = "unknown_type"
    ),
    "unknown_type"
  )
})

test_that("creel_design() accepts survey_type = 'ice' with effort_type and returns creel_design", {
  d <- creel_design(make_enum_cal(),
    date = date, strata = day_type,
    survey_type = "ice",
    effort_type = "time_on_ice",
    p_period = 0.5
  )
  expect_s3_class(d, "creel_design")
  expect_equal(d$design_type, "ice")
})

test_that("creel_design() accepts survey_type = 'camera' and returns creel_design", {
  d <- creel_design(make_enum_cal(),
    date = date, strata = day_type,
    survey_type = "camera",
    camera_mode = "counter"
  )
  expect_s3_class(d, "creel_design")
  expect_equal(d$design_type, "camera")
})

test_that("creel_design() accepts survey_type = 'aerial' and returns creel_design", {
  d <- creel_design(make_enum_cal(),
    date = date, strata = day_type,
    survey_type = "aerial",
    h_open = 14
  )
  expect_s3_class(d, "creel_design")
  expect_equal(d$design_type, "aerial")
})

# ICE-01: Ice constructor and p_site=1.0 enforcement ----

make_ice_cal <- function() {
  data.frame(
    date = as.Date(c("2024-01-10", "2024-01-11", "2024-01-12", "2024-01-13")),
    day_type = c("weekday", "weekday", "weekend", "weekend"),
    stringsAsFactors = FALSE
  )
}

test_that("ICE-01: creel_design(ice, effort_type='time_on_ice', p_period=0.5) constructs non-NULL ice slot", {
  d <- creel_design(make_ice_cal(),
    date = date, strata = day_type,
    survey_type = "ice",
    effort_type = "time_on_ice",
    p_period = 0.5
  )
  expect_false(is.null(d$ice))
  expect_equal(d$ice$effort_type, "time_on_ice")
})

test_that("ICE-01: design$ice$effort_type stores 'active_fishing_time' when supplied", {
  d <- creel_design(make_ice_cal(),
    date = date, strata = day_type,
    survey_type = "ice",
    effort_type = "active_fishing_time",
    p_period = 0.5
  )
  expect_equal(d$ice$effort_type, "active_fishing_time")
})

test_that("ICE-01: creel_design(ice) with valid sampling_frame (all p_site==1.0) constructs", {
  sf <- data.frame(
    location = c("site_A", "site_B"),
    p_site = c(1.0, 1.0),
    p_period = 0.5,
    stringsAsFactors = FALSE
  )
  d <- creel_design(make_ice_cal(),
    date = date, strata = day_type,
    survey_type = "ice",
    effort_type = "time_on_ice",
    sampling_frame = sf,
    p_period = 0.5
  )
  expect_s3_class(d, "creel_design")
  expect_false(is.null(d$ice))
})

test_that("ICE-01: creel_design(ice) aborts with cli_abort when any p_site != 1.0", {
  sf_bad <- data.frame(
    location = c("site_A", "site_B"),
    p_site = c(1.0, 0.8),
    p_period = 0.5,
    stringsAsFactors = FALSE
  )
  expect_error(
    creel_design(make_ice_cal(),
      date = date, strata = day_type,
      survey_type = "ice",
      effort_type = "time_on_ice",
      sampling_frame = sf_bad,
      p_period = 0.5
    ),
    class = "rlang_error"
  )
})

test_that("ICE-01: p_site enforcement error message names offending row indices", {
  sf_bad <- data.frame(
    location = c("site_A", "site_B", "site_C"),
    p_site = c(1.0, 0.8, 1.0),
    p_period = 0.5,
    stringsAsFactors = FALSE
  )
  expect_error(
    creel_design(make_ice_cal(),
      date = date, strata = day_type,
      survey_type = "ice",
      effort_type = "time_on_ice",
      sampling_frame = sf_bad,
      p_period = 0.5
    ),
    regexp = "2"
  )
})

# ICE-02: effort_type validation ----

test_that("ICE-02: creel_design(ice) without effort_type aborts with cli_abort", {
  expect_error(
    creel_design(make_ice_cal(),
      date = date, strata = day_type,
      survey_type = "ice",
      p_period = 0.5
    ),
    class = "rlang_error"
  )
})

test_that("ICE-02: creel_design(ice) with unknown effort_type aborts with informative message", {
  expect_error(
    creel_design(make_ice_cal(),
      date = date, strata = day_type,
      survey_type = "ice",
      effort_type = "unknown_type",
      p_period = 0.5
    ),
    regexp = "time_on_ice|active_fishing_time"
  )
})

# ICE-04: add_interviews() ice path ----

make_ice_design_no_sf <- function() {
  creel_design( # nolint: object_usage_linter
    make_ice_cal(),
    date = date, strata = day_type, # nolint: object_usage_linter
    survey_type = "ice",
    effort_type = "time_on_ice",
    p_period = 0.5
  )
}

make_ice_interviews_valid <- function() {
  data.frame(
    date = as.Date(c("2024-01-10", "2024-01-11", "2024-01-12")),
    n_counted = c(10L, 8L, 12L),
    n_interviewed = c(3L, 2L, 4L),
    hours_fished = c(2.0, 1.5, 3.0),
    walleye_catch = c(1L, 0L, 2L),
    trip_status = rep("complete", 3L),
    stringsAsFactors = FALSE
  )
}

test_that("ICE-04: add_interviews(ice) without n_counted aborts with informative error", {
  design <- make_ice_design_no_sf()
  interviews <- make_ice_interviews_valid()
  expect_error(
    add_interviews(
      design,
      interviews,
      catch = walleye_catch,
      effort = hours_fished,
      n_interviewed = n_interviewed,
      trip_status = trip_status
    ),
    regexp = "n_counted",
    class = "rlang_error"
  )
})

test_that("ICE-04: add_interviews(ice) without n_interviewed aborts with informative error", {
  design <- make_ice_design_no_sf()
  interviews <- make_ice_interviews_valid()
  expect_error(
    add_interviews(
      design,
      interviews,
      catch = walleye_catch,
      effort = hours_fished,
      n_counted = n_counted,
      trip_status = trip_status
    ),
    regexp = "n_interviewed",
    class = "rlang_error"
  )
})

test_that("ICE-04: add_interviews(ice) with valid inputs attaches non-NULL interview_survey", {
  design <- make_ice_design_no_sf()
  interviews <- make_ice_interviews_valid()
  result <- suppressWarnings(add_interviews(
    design,
    interviews,
    catch = walleye_catch,
    effort = hours_fished,
    n_counted = n_counted,
    n_interviewed = n_interviewed,
    trip_status = trip_status
  ))
  expect_false(is.null(result$interview_survey))
})

test_that("ICE-04: add_interviews(ice) broadcasts p_period_scalar to .pi_i on all rows", {
  design <- make_ice_design_no_sf()
  interviews <- make_ice_interviews_valid()
  result <- suppressWarnings(add_interviews(
    design,
    interviews,
    catch = walleye_catch,
    effort = hours_fished,
    n_counted = n_counted,
    n_interviewed = n_interviewed,
    trip_status = trip_status
  ))
  expect_true(".pi_i" %in% names(result$interviews))
  expect_true(all(result$interviews$.pi_i == 0.5))
})

# Phase 46: Camera constructor and preprocessing (CAM-01, CAM-02, CAM-03) ----

make_cam_cal <- function() {
  data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
    day_type = c("weekday", "weekday", "weekend", "weekend"),
    stringsAsFactors = FALSE
  )
}

# CAM-01: counter mode construction ----

test_that("CAM-01: creel_design(camera, counter) constructs without error", {
  d <- creel_design(make_cam_cal(),
    date = date, strata = day_type,
    survey_type = "camera",
    camera_mode = "counter"
  )
  expect_s3_class(d, "creel_design")
  expect_equal(d$design_type, "camera")
  expect_equal(d$camera$camera_mode, "counter")
})

test_that("CAM-01: creel_design(camera) without camera_mode aborts with cli_abort", {
  expect_error(
    creel_design(make_cam_cal(),
      date = date, strata = day_type,
      survey_type = "camera"
    ),
    class = "rlang_error"
  )
})

test_that("CAM-01: camera_mode absent error message names valid values", {
  expect_error(
    creel_design(make_cam_cal(),
      date = date, strata = day_type,
      survey_type = "camera"
    ),
    regexp = "counter|ingress_egress"
  )
})

test_that("CAM-01: creel_design(camera, bad_mode) aborts naming the bad value", {
  expect_error(
    creel_design(make_cam_cal(),
      date = date, strata = day_type,
      survey_type = "camera",
      camera_mode = "unknown_mode"
    ),
    regexp = "unknown_mode"
  )
})

# CAM-02: ingress_egress mode construction ----

test_that("CAM-02: creel_design(camera, ingress_egress) constructs without error", {
  d <- creel_design(make_cam_cal(),
    date = date, strata = day_type,
    survey_type = "camera",
    camera_mode = "ingress_egress"
  )
  expect_s3_class(d, "creel_design")
  expect_equal(d$camera$camera_mode, "ingress_egress")
})

# CAM-02: preprocess_camera_timestamps() ----

make_cam_timestamps <- function() {
  base_date <- as.Date("2024-06-01")
  data.frame(
    survey_date = rep(c(base_date, base_date + 1), each = 2L),
    ingress_time = as.POSIXct(c(
      "2024-06-01 06:00:00", "2024-06-01 09:00:00",
      "2024-06-02 07:00:00", "2024-06-02 10:30:00"
    ), tz = "UTC"),
    egress_time = as.POSIXct(c(
      "2024-06-01 08:00:00", "2024-06-01 11:00:00",
      "2024-06-02 09:00:00", "2024-06-02 13:00:00"
    ), tz = "UTC"),
    stringsAsFactors = FALSE
  )
}

test_that("CAM-02: preprocess_camera_timestamps() returns data frame with date + daily_effort_hours", {
  ts <- make_cam_timestamps()
  result <- preprocess_camera_timestamps(ts,
    date_col = survey_date,
    ingress_col = ingress_time,
    egress_col = egress_time
  )
  expect_s3_class(result, "data.frame")
  expect_true("date" %in% names(result))
  expect_true("daily_effort_hours" %in% names(result))
  expect_equal(nrow(result), 2L)
})

test_that("CAM-02: preprocess_camera_timestamps() aggregates hours correctly", {
  ts <- make_cam_timestamps()
  result <- preprocess_camera_timestamps(ts,
    date_col = survey_date,
    ingress_col = ingress_time,
    egress_col = egress_time
  )
  # Date 1: 2h + 2h = 4h; Date 2: 2h + 2.5h = 4.5h
  result_sorted <- result[order(result$date), ]
  expect_equal(result_sorted$daily_effort_hours[1L], 4.0, tolerance = 1e-6)
  expect_equal(result_sorted$daily_effort_hours[2L], 4.5, tolerance = 1e-6)
})

test_that("CAM-02: preprocess_camera_timestamps() warns on egress < ingress and sets duration to NA", {
  ts <- make_cam_timestamps()
  # Make one row have egress before ingress
  ts$egress_time[2L] <- ts$ingress_time[2L] - 3600
  expect_warning(
    result <- preprocess_camera_timestamps(ts,
      date_col = survey_date,
      ingress_col = ingress_time,
      egress_col = egress_time
    ),
    regexp = "negative|duration|invalid"
  )
  # Date 1 should only sum the valid row (2h), not the negative-duration row
  result_sorted <- result[order(result$date), ]
  expect_equal(result_sorted$daily_effort_hours[1L], 2.0, tolerance = 1e-6)
})

# Phase 47: Aerial constructor ----

make_aerial_cal <- function() {
  data.frame(
    date = as.Date(c(
      "2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04",
      "2024-06-08", "2024-06-09", "2024-06-15", "2024-06-16"
    )),
    day_type = rep(c("weekday", "weekend"), each = 4L),
    stringsAsFactors = FALSE
  )
}

describe("Phase 47: Aerial constructor", {
  it("AIR-01: creel_design(survey_type = 'aerial', h_open = 14) constructs; design$aerial$h_open == 14", {
    d <- creel_design(make_aerial_cal(),
      date = date, strata = day_type,
      survey_type = "aerial",
      h_open = 14
    )
    expect_s3_class(d, "creel_design")
    expect_equal(d$design_type, "aerial")
    expect_equal(d$aerial$h_open, 14)
  })

  it("AIR-01: creel_design(survey_type = 'aerial') without h_open aborts with cli_abort()", {
    expect_error(
      creel_design(make_aerial_cal(),
        date = date, strata = day_type,
        survey_type = "aerial"
      ),
      regexp = "h_open"
    )
  })

  it("AIR-01: creel_design(survey_type = 'aerial', h_open = -1) aborts with informative message", {
    expect_error(
      creel_design(make_aerial_cal(),
        date = date, strata = day_type,
        survey_type = "aerial",
        h_open = -1
      ),
      regexp = "h_open"
    )
  })

  it("AIR-03: creel_design(survey_type = 'aerial', h_open = 14, visibility_correction = 0.85) constructs", {
    d <- creel_design(make_aerial_cal(),
      date = date, strata = day_type,
      survey_type = "aerial",
      h_open = 14,
      visibility_correction = 0.85
    )
    expect_equal(d$aerial$visibility_correction, 0.85)
  })

  it("AIR-03: visibility_correction = 1.5 aborts (outside (0, 1])", {
    expect_error(
      creel_design(make_aerial_cal(),
        date = date, strata = day_type,
        survey_type = "aerial",
        h_open = 14,
        visibility_correction = 1.5
      ),
      regexp = "visibility_correction"
    )
  })

  it("AIR-03: visibility_correction = 0 aborts (not > 0)", {
    expect_error(
      creel_design(make_aerial_cal(),
        date = date, strata = day_type,
        survey_type = "aerial",
        h_open = 14,
        visibility_correction = 0
      ),
      regexp = "visibility_correction"
    )
  })

  it("AIR-01: design$design_type == 'aerial' after construction", {
    d <- creel_design(make_aerial_cal(),
      date = date, strata = day_type,
      survey_type = "aerial",
      h_open = 14
    )
    expect_equal(d$design_type, "aerial")
  })
})

# ---- NA-weight diagnostics: bus-route inclusion probabilities ----------------

test_that("DIAG-WGHT-01: bus-route design with NA p_site aborts naming p_site", {
  sf_na <- data.frame(
    site = c("A", "B", "C"),
    p_site = c(0.3, NA, 0.3),
    p_period = rep(0.5, 3),
    stringsAsFactors = FALSE
  )
  expect_error(
    creel_design(
      make_br_cal(),
      date = date, strata = day_type,
      survey_type = "bus_route", sampling_frame = sf_na,
      site = site, p_site = p_site, p_period = p_period
    ),
    regexp = "p_site"
  )
})

test_that("DIAG-WGHT-02: bus-route design with NA p_period aborts naming p_period", {
  sf_na <- data.frame(
    site = c("A", "B", "C"),
    p_site = c(0.3, 0.4, 0.3),
    p_period = c(0.5, NA, 0.5),
    stringsAsFactors = FALSE
  )
  expect_error(
    creel_design(
      make_br_cal(),
      date = date, strata = day_type,
      survey_type = "bus_route", sampling_frame = sf_na,
      site = site, p_site = p_site, p_period = p_period
    ),
    regexp = "p_period"
  )
})

test_that("DIAG-WGHT-03: bus-route design with p_site = 0 aborts (zero probability invalid)", {
  sf_zero <- data.frame(
    site = c("A", "B", "C"),
    p_site = c(0.3, 0.0, 0.3),
    p_period = rep(0.5, 3),
    stringsAsFactors = FALSE
  )
  expect_error(
    creel_design(
      make_br_cal(),
      date = date, strata = day_type,
      survey_type = "bus_route", sampling_frame = sf_zero,
      site = site, p_site = p_site, p_period = p_period
    ),
    regexp = "p_site"
  )
})
