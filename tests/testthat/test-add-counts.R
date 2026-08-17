# Test helpers ----

#' Create test calendar data with 4+ rows per stratum
make_test_calendar <- function() {
  data.frame(
    date = as.Date(c(
      "2024-06-01",
      "2024-06-02",
      "2024-06-03",
      "2024-06-04",
      "2024-06-08",
      "2024-06-09",
      "2024-06-15",
      "2024-06-16"
    )),
    day_type = rep(c("weekday", "weekend"), each = 4),
    stringsAsFactors = FALSE
  )
}

#' Create test count data matching test calendar structure
#' Each day_type stratum has at least 2 distinct dates (PSUs)
make_test_counts <- function() {
  data.frame(
    date = as.Date(c(
      "2024-06-01",
      "2024-06-02",
      "2024-06-03",
      "2024-06-04",
      "2024-06-08",
      "2024-06-09",
      "2024-06-15",
      "2024-06-16"
    )),
    day_type = rep(c("weekday", "weekend"), each = 4),
    count = c(15, 23, 18, 21, 45, 52, 48, 51),
    stringsAsFactors = FALSE
  )
}

#' Create test creel_design
make_test_design <- function() {
  cal <- make_test_calendar()
  creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter
}

# add_counts() happy path tests ----

test_that("add_counts returns creel_design S3 class", {
  design <- make_test_design()
  counts <- make_test_counts()

  result <- add_counts(design, counts)

  expect_s3_class(result, "creel_design")
})

test_that("add_counts attaches count data to $counts slot", {
  design <- make_test_design()
  counts <- make_test_counts()

  result <- add_counts(design, counts)

  expect_false(is.null(result$counts))
  expect_identical(result$counts, counts)
})

test_that("add_counts constructs svydesign object eagerly", {
  design <- make_test_design()
  counts <- make_test_counts()

  result <- add_counts(design, counts)

  expect_false(is.null(result$survey))
  expect_s3_class(result$survey, "survey.design2")
})

test_that("add_counts preserves immutability - original design unchanged", {
  design <- make_test_design()
  counts <- make_test_counts()

  result <- add_counts(design, counts)

  expect_null(design$counts)
  expect_null(design$survey)
})

test_that("add_counts works with named arguments", {
  design <- make_test_design()
  counts <- make_test_counts()

  result <- add_counts(design, counts = counts)

  expect_s3_class(result, "creel_design")
  expect_false(is.null(result$counts))
})

test_that("add_counts retains all original design fields", {
  design <- make_test_design()
  counts <- make_test_counts()

  result <- add_counts(design, counts)

  expect_identical(result$calendar, design$calendar)
  expect_identical(result$date_col, design$date_col)
  expect_identical(result$strata_cols, design$strata_cols)
  expect_identical(result$site_col, design$site_col)
  expect_identical(result$design_type, design$design_type)
})

# add_counts() validation error tests ----

test_that("add_counts errors when counts already attached", {
  design <- make_test_design()
  counts <- make_test_counts()

  result <- add_counts(design, counts)

  expect_error(
    add_counts(result, counts),
    "already"
  )
})

test_that("add_counts errors when design is not creel_design class", {
  counts <- make_test_counts()
  fake_design <- list(calendar = make_test_calendar())

  expect_error(
    add_counts(fake_design, counts),
    "creel_design"
  )
})

test_that("add_counts errors when count data has no Date column", {
  design <- make_test_design()
  bad_counts <- data.frame(
    day = c("2024-06-01", "2024-06-02"),
    count = c(10, 20)
  )

  expect_error(
    add_counts(design, bad_counts),
    "Date"
  )
})

test_that("add_counts errors when count data has no numeric column", {
  design <- make_test_design()
  bad_counts <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02")),
    description = c("weekday", "weekend")
  )

  expect_error(
    add_counts(design, bad_counts),
    "numeric"
  )
})

test_that("add_counts errors when date_col from design not in count data", {
  design <- make_test_design()
  bad_counts <- make_test_counts()
  names(bad_counts)[names(bad_counts) == "date"] <- "survey_date"

  expect_error(
    add_counts(design, bad_counts),
    "date"
  )
})

test_that("add_counts errors when strata_cols from design not in count data", {
  design <- make_test_design()
  bad_counts <- make_test_counts()
  names(bad_counts)[names(bad_counts) == "day_type"] <- "stratum"

  expect_error(
    add_counts(design, bad_counts),
    "day_type"
  )
})

test_that("add_counts errors when PSU column not in count data", {
  design <- make_test_design()
  bad_counts <- make_test_counts()
  names(bad_counts)[names(bad_counts) == "date"] <- "survey_date"

  expect_error(
    add_counts(design, bad_counts, psu = "date"),
    "PSU|date"
  )
})

test_that("add_counts errors when date column contains NA values", {
  design <- make_test_design()
  bad_counts <- make_test_counts()
  bad_counts$date[2] <- NA

  expect_error(
    add_counts(design, bad_counts),
    "NA"
  )
})

test_that("add_counts errors when strata columns contain NA values", {
  design <- make_test_design()
  bad_counts <- make_test_counts()
  bad_counts$day_type[3] <- NA

  expect_error(
    add_counts(design, bad_counts),
    "NA"
  )
})

# construct_survey_design() tests ----

test_that("construct_survey_design returns survey.design2 object", {
  design <- make_test_design()
  counts <- make_test_counts()

  result <- add_counts(design, counts)

  expect_s3_class(result$survey, "survey.design2")
})

test_that("survey object has correct strata - single stratum", {
  design <- make_test_design()
  counts <- make_test_counts()

  result <- add_counts(design, counts)

  # Survey object should have strata based on day_type
  expect_true(!is.null(result$survey$strata))
})

test_that("survey object has correct strata - multiple strata", {
  cal <- data.frame(
    date = as.Date(c(
      "2024-06-01",
      "2024-06-02",
      "2024-06-03",
      "2024-06-04",
      "2024-06-08",
      "2024-06-09",
      "2024-06-15",
      "2024-06-16"
    )),
    day_type = rep(c("weekday", "weekend"), each = 4),
    season = rep(c("spring", "summer"), 4)
  )
  design <- creel_design(cal, date = date, strata = c(day_type, season)) # nolint: object_usage_linter

  counts <- data.frame(
    date = as.Date(c(
      "2024-06-01",
      "2024-06-02",
      "2024-06-03",
      "2024-06-04",
      "2024-06-08",
      "2024-06-09",
      "2024-06-15",
      "2024-06-16"
    )),
    day_type = rep(c("weekday", "weekend"), each = 4),
    season = rep(c("spring", "summer"), 4),
    count = c(15, 23, 18, 21, 45, 52, 48, 51)
  )

  result <- add_counts(design, counts)

  # Survey object should combine multiple strata via interaction
  expect_true(!is.null(result$survey$strata))
})

test_that("construct_survey_design allows lonely PSU (errors caught during estimation)", {
  # Create design with lonely PSU - only one date per stratum
  # Note: survey package doesn't error during construction, only during variance estimation
  # This is correct behavior - we catch lonely PSU errors in Phase 4 estimation functions
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-08")),
    day_type = c("weekday", "weekend")
  )
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter

  counts <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-08")),
    day_type = c("weekday", "weekend"),
    count = c(15, 45)
  )

  # Should construct successfully - lonely PSU errors happen during estimation
  result <- add_counts(design, counts)
  expect_s3_class(result, "creel_design")
  expect_s3_class(result$survey, "survey.design2")
})

# Validation storage tests ----

test_that("add_counts stores validation results in $validation slot", {
  design <- make_test_design()
  counts <- make_test_counts()

  result <- add_counts(design, counts)

  expect_s3_class(result$validation, "creel_validation")
})

test_that("validation$passed is TRUE when counts are valid", {
  design <- make_test_design()
  counts <- make_test_counts()

  result <- add_counts(design, counts)

  expect_true(result$validation$passed)
})

test_that("validation$tier is 1L (integer Tier 1)", {
  design <- make_test_design()
  counts <- make_test_counts()

  result <- add_counts(design, counts)

  expect_identical(result$validation$tier, 1L)
})

# Error handling tests for construct_survey_design ----

test_that("add_counts errors gracefully when PSU column missing from count data", {
  design <- make_test_design()
  bad_counts <- make_test_counts()
  # Remove date column (which is default PSU)
  bad_counts <- bad_counts[, setdiff(names(bad_counts), "date")]

  # Should error with friendly message about missing PSU column
  expect_error(
    add_counts(design, bad_counts, psu = "date"),
    "PSU|date|column"
  )
})

test_that("add_counts errors gracefully when strata column missing from count data", {
  design <- make_test_design()
  bad_counts <- make_test_counts()
  # Remove strata column
  bad_counts <- bad_counts[, setdiff(names(bad_counts), "day_type")]

  # Should error with friendly message about missing strata column
  expect_error(
    add_counts(design, bad_counts),
    "day_type|strata|column"
  )
})

# Multiple counts per PSU (Phase 36) ----

test_that("add_counts() accepts count_time_col without error (CNT-02)", {
  counts_am <- example_counts
  counts_am$count_time <- "am"
  counts_pm <- example_counts
  counts_pm$count_time <- "pm"
  multi_counts <- rbind(counts_am, counts_pm)
  design <- creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  expect_no_error(
    add_counts(design, multi_counts, count_time_col = count_time) # nolint: object_usage_linter
  )
})

test_that("add_counts() with count_time_col reduces counts to one row per PSU (EFF-03)", {
  # Build two-count-per-day data
  counts_am <- example_counts
  counts_am$count_time <- "am"
  counts_pm <- example_counts
  counts_pm$count_time <- "pm"
  counts_pm$effort_hours <- counts_pm$effort_hours + 2 # different values per count
  multi_counts <- rbind(counts_am, counts_pm)

  design <- creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  d <- add_counts(design, multi_counts, count_time_col = count_time) # nolint: object_usage_linter

  # After aggregation: one row per unique PSU (date x strata)
  expect_equal(nrow(d$counts), nrow(example_counts))
})

test_that("add_counts() stores within_day_var slot with ss_d and k_d columns", {
  counts_am <- example_counts
  counts_am$count_time <- "am"
  counts_pm <- example_counts
  counts_pm$count_time <- "pm"
  counts_pm$effort_hours <- counts_pm$effort_hours + 4
  multi_counts <- rbind(counts_am, counts_pm)

  design <- creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  d <- add_counts(design, multi_counts, count_time_col = count_time) # nolint: object_usage_linter

  expect_false(is.null(d$within_day_var))
  expect_true(all(c("ss_d", "k_d") %in% names(d$within_day_var)))
  expect_equal(nrow(d$within_day_var), nrow(example_counts))
  expect_true(all(d$within_day_var$k_d == 2L))
})

test_that("add_counts() single-count path produces NULL within_day_var (CNT-04)", {
  design <- creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  d <- add_counts(design, example_counts)

  expect_null(d$within_day_var)
  expect_null(d$count_time_col)
})

test_that("add_counts() warns on repeated sampling units when count_time_col = NULL (CNT-06)", {
  # Duplicate every row to simulate forgotten count_time_col
  dup_counts <- rbind(example_counts, example_counts)

  design <- creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  expect_warning(
    add_counts(design, dup_counts),
    regexp = "Repeated sampling units"
  )
})

test_that("CNT-06 names the key it judged the repeat on (GH #155)", {
  # The warning used to say "duplicate values in column date", which was both
  # the wrong question and unactionable on a design with sections or sites.
  # Naming the key is what tells a user whether the repeat is a real one.
  dup_counts <- rbind(example_counts, example_counts)
  design <- creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter

  w <- tryCatch(
    add_counts(design, dup_counts),
    warning = function(x) x
  )
  msg <- cli::ansi_strip(paste(conditionMessage(w), collapse = "\n"))
  expect_match(msg, "date", fixed = TRUE)
  expect_match(msg, "day_type", fixed = TRUE)
})

test_that("add_counts() sets count_type slot to 'instantaneous' by default", {
  design <- creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  d <- add_counts(design, example_counts)
  expect_equal(d$count_type, "instantaneous")
})

test_that("add_counts() aborts when count_type = 'progressive' and circuit_time = NULL (CNT-05)", {
  design <- creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  expect_error(
    add_counts(design, example_counts, count_type = "progressive"),
    regexp = "circuit_time"
  )
})

#' Create progressive count data (raw angler counts + shift duration)
make_progressive_counts <- function() {
  data.frame(
    date = as.Date(c(
      "2024-06-01",
      "2024-06-02",
      "2024-06-03",
      "2024-06-04",
      "2024-06-08",
      "2024-06-09",
      "2024-06-15",
      "2024-06-16"
    )),
    day_type = rep(c("weekday", "weekend"), each = 4),
    n_anglers = c(15L, 23L, 18L, 21L, 45L, 52L, 48L, 51L),
    shift_hours = rep(8, 8),
    stringsAsFactors = FALSE
  )
}

test_that("add_counts() accepts count_type = 'progressive' with required args (CNT-01)", {
  design <- creel_design(make_test_calendar(), date = date, strata = day_type)
  prog_counts <- make_progressive_counts()
  expect_no_error(
    add_counts(
      design,
      prog_counts,
      count_type = "progressive",
      circuit_time = 2,
      period_length_col = shift_hours # nolint: object_usage_linter
    )
  )
})

test_that("add_counts() aborts when count_type = 'progressive' and period_length_col = NULL (CNT-05)", {
  design <- creel_design(make_test_calendar(), date = date, strata = day_type)
  prog_counts <- make_progressive_counts()
  expect_error(
    add_counts(design, prog_counts, count_type = "progressive", circuit_time = 2),
    regexp = "period_length_col"
  )
})

# A shift shorter than one circuit (finding 20) ----

test_that("add_counts() rejects a shift shorter than one circuit (CNT-12)", {
  # Hoenig et al. (1993) eq. 3 expands the count over K = T_d/tau whole circuits in
  # the day. With T_d = 8 and tau = 12 there is no whole circuit, so the count is not
  # a progressive count of that shift and the expansion has nothing to expand. This
  # used to warn and then return a number regardless.
  design <- creel_design(make_test_calendar(), date = date, strata = day_type)
  expect_error(
    add_counts(
      design,
      make_progressive_counts(),
      count_type = "progressive",
      circuit_time = 12,
      period_length_col = shift_hours # nolint: object_usage_linter
    ),
    class = "creel_error_circuit_exceeds_shift"
  )
})

test_that("add_counts() points at the scheduler that already enforces the circuit fit", {
  # generate_progressive_start() aborts on the same design, so reaching this error at
  # all means the schedule was hand-built. The message has to say where the guard is.
  design <- creel_design(make_test_calendar(), date = date, strata = day_type)
  expect_error(
    add_counts(
      design,
      make_progressive_counts(),
      count_type = "progressive",
      circuit_time = 12,
      period_length_col = shift_hours # nolint: object_usage_linter
    ),
    regexp = "generate_progressive_start"
  )
})

test_that("add_counts() accepts a shift exactly one circuit long", {
  # tau == T_d is Robson's (1961) all-day-circuit case, K = 1: valid, not an edge to
  # reject. The guard must trigger on T_d < tau only, or it would refuse this.
  design <- creel_design(make_test_calendar(), date = date, strata = day_type)
  expect_no_error(
    add_counts(
      design,
      make_progressive_counts(),
      count_type = "progressive",
      circuit_time = 8,
      period_length_col = shift_hours # nolint: object_usage_linter
    )
  )
})

test_that("add_counts() replaces raw counts with Ê_d = count × period_length for progressive (EFF-02)", {
  design <- creel_design(make_test_calendar(), date = date, strata = day_type)
  prog_counts <- make_progressive_counts()
  # κ = 8 / 2 = 4; Ê_d = n_anglers × circuit_time × κ = n_anglers × shift_hours
  expected_effort <- prog_counts$n_anglers * prog_counts$shift_hours

  d <- add_counts(
    design,
    prog_counts,
    count_type = "progressive",
    circuit_time = 2,
    period_length_col = shift_hours # nolint: object_usage_linter
  )

  expect_equal(d$counts$n_anglers, expected_effort, tolerance = 1e-10)
})

test_that("add_counts() drops period_length_col from design$counts after progressive computation", {
  design <- creel_design(make_test_calendar(), date = date, strata = day_type)
  d <- add_counts(
    design,
    make_progressive_counts(),
    count_type = "progressive",
    circuit_time = 2,
    period_length_col = shift_hours # nolint: object_usage_linter
  )
  expect_false("shift_hours" %in% names(d$counts))
})

test_that("add_counts() stores circuit_time and period_length_col slots (CNT-03)", {
  design <- creel_design(make_test_calendar(), date = date, strata = day_type)
  d <- add_counts(
    design,
    make_progressive_counts(),
    count_type = "progressive",
    circuit_time = 2,
    period_length_col = shift_hours # nolint: object_usage_linter
  )
  expect_equal(d$circuit_time, 2)
  expect_equal(d$period_length_col, "shift_hours")
})

test_that("add_counts() accepts count_time_col + count_type = 'progressive' (multi-circuit, CNT-07)", {
  design <- creel_design(make_test_calendar(), date = date, strata = day_type)
  # Two circuits (am/pm) per day: duplicate each row
  single <- make_progressive_counts()
  multi <- rbind(
    transform(single, circuit_id = "am", n_anglers = n_anglers),
    transform(single, circuit_id = "pm", n_anglers = n_anglers + 5L)
  )
  multi <- multi[order(multi$date), ]
  expect_no_error(
    add_counts(
      design,
      multi,
      count_time_col = circuit_id, # nolint: object_usage_linter
      count_type = "progressive",
      circuit_time = 2,
      period_length_col = shift_hours # nolint: object_usage_linter
    )
  )
})

test_that("add_counts() multi-circuit progressive: Ê_d = mean(C_k) × T_d (CNT-08)", {
  design <- creel_design(make_test_calendar(), date = date, strata = day_type)
  single <- make_progressive_counts()
  # am count = 20, pm count = 30 → mean = 25; T_d = 8 → Ê_d = 200
  multi <- rbind(
    transform(single, circuit_id = "am", n_anglers = 20L),
    transform(single, circuit_id = "pm", n_anglers = 30L)
  )
  multi <- multi[order(multi$date), ]
  result <- add_counts(
    design, multi,
    count_time_col = circuit_id, # nolint: object_usage_linter
    count_type = "progressive",
    circuit_time = 2,
    period_length_col = shift_hours # nolint: object_usage_linter
  )
  # Each day: mean(20, 30) × 8 = 200
  expect_equal(result$counts$n_anglers, rep(200, nrow(single)))
})

test_that("add_counts() multi-circuit progressive: within_day_var is non-NULL (CNT-09)", {
  design <- creel_design(make_test_calendar(), date = date, strata = day_type)
  single <- make_progressive_counts()
  multi <- rbind(
    transform(single, circuit_id = "am", n_anglers = 20L),
    transform(single, circuit_id = "pm", n_anglers = 30L)
  )
  multi <- multi[order(multi$date), ]
  result <- add_counts(
    design, multi,
    count_time_col = circuit_id, # nolint: object_usage_linter
    count_type = "progressive",
    circuit_time = 2,
    period_length_col = shift_hours # nolint: object_usage_linter
  )
  expect_false(is.null(result$within_day_var))
  expect_true(all(c("ss_d", "k_d") %in% names(result$within_day_var)))
})

test_that("add_counts() multi-circuit progressive: ss_d scaled by T_d^2 (CNT-10)", {
  design <- creel_design(make_test_calendar(), date = date, strata = day_type)
  single <- make_progressive_counts()
  # am = 20, pm = 30, T_d = 8 → count ss_d = (20-25)^2 + (30-25)^2 = 50
  # effort ss_d must be 50 * 8^2 = 3200
  multi <- rbind(
    transform(single, circuit_id = "am", n_anglers = 20L),
    transform(single, circuit_id = "pm", n_anglers = 30L)
  )
  multi <- multi[order(multi$date), ]
  result <- add_counts(
    design, multi,
    count_time_col = circuit_id, # nolint: object_usage_linter
    count_type = "progressive",
    circuit_time = 2,
    period_length_col = shift_hours # nolint: object_usage_linter
  )
  expect_equal(result$within_day_var$ss_d, rep(3200, nrow(single)))
})

test_that("add_counts() aborts when period_length column contains non-positive values", {
  design <- creel_design(make_test_calendar(), date = date, strata = day_type)
  bad_counts <- make_progressive_counts()
  bad_counts$shift_hours[1] <- 0
  expect_error(
    add_counts(
      design,
      bad_counts,
      count_type = "progressive",
      circuit_time = 2,
      period_length_col = shift_hours # nolint: object_usage_linter
    ),
    regexp = "positive"
  )
})

# CNT-11: count column is named, never chosen by position ----

#' Counts where the intended count column is NOT the leftmost numeric column.
#' Mirrors the shape that broke in the field: simulate_creel_data() gained
#' daylight_hours, which sorted ahead of the angler count and was silently
#' expanded into "Total Effort".
make_ambiguous_counts <- function() {
  counts <- make_test_counts()
  data.frame(
    date = counts$date,
    day_type = counts$day_type,
    daylight_hours = rep(14, nrow(counts)),
    count = counts$count,
    stringsAsFactors = FALSE
  )
}

test_that("add_counts() aborts rather than guessing when two numeric columns qualify", {
  design <- make_test_design()
  expect_error(
    add_counts(design, make_ambiguous_counts()),
    regexp = "Cannot tell which column holds the angler counts"
  )
})

test_that("add_counts() names the ambiguity candidates so the caller can resolve it", {
  design <- make_test_design()
  expect_error(
    add_counts(design, make_ambiguous_counts()),
    regexp = "daylight_hours"
  )
})

test_that("count_col resolves the ambiguity and the estimator uses the named column", {
  # The point of the guard: a positional pick would expand daylight_hours (14 per
  # day) instead of the angler counts, and report the wrong number as effort with
  # no warning. Naming the column must make the estimate the counts, not the hours.
  ambiguous <- make_ambiguous_counts()
  design <- add_counts(
    make_test_design(),
    ambiguous,
    count_col = count # nolint: object_usage_linter
  )
  expect_identical(design$count_col, "count")

  result <- suppressWarnings(estimate_effort(design))
  expect_equal(result$estimates$estimate, sum(ambiguous$count))
  expect_false(isTRUE(all.equal(
    result$estimates$estimate,
    sum(ambiguous$daylight_hours)
  )))
})

test_that("add_counts() still infers the count column when only one candidate exists", {
  design <- add_counts(make_test_design(), make_test_counts())
  expect_identical(design$count_col, "count")
})

test_that("add_counts() aborts when count_col names a column that is not numeric", {
  design <- make_test_design()
  counts <- make_test_counts()
  counts$observer <- "AB"
  expect_error(
    add_counts(design, counts, count_col = observer), # nolint: object_usage_linter
    regexp = "must be numeric"
  )
})

test_that("add_counts() aborts when count_col names a column that is absent", {
  design <- make_test_design()
  expect_error(
    add_counts(design, make_test_counts(), count_col = no_such_col), # nolint: object_usage_linter
    regexp = "doesn't exist|not found"
  )
})

test_that("prep_counts_daily_effort() output stays unambiguous for add_counts()", {
  # prep_counts_daily_effort() emits correction_factor (and optionally n_counts
  # and within_day_var) alongside daily_effort. Those are contract metadata, not
  # counts. If they ever count as candidates, the preferred documented pipeline
  # aborts on every call.
  raw <- data.frame(
    sample_date = make_test_calendar()$date,
    day_type = make_test_calendar()$day_type,
    effort_kind = "bank",
    effort_value = c(15, 23, 18, 21, 45, 52, 48, 51),
    n_obs = 3L,
    ss = 4.5,
    stringsAsFactors = FALSE
  )
  ready <- prep_counts_daily_effort(
    raw,
    date = sample_date, # nolint: object_usage_linter
    strata = day_type, # nolint: object_usage_linter
    effort_type = effort_kind, # nolint: object_usage_linter
    daily_effort = effort_value, # nolint: object_usage_linter
    n_counts = n_obs, # nolint: object_usage_linter
    within_day_var = ss # nolint: object_usage_linter
  )
  expect_true(all(
    c("correction_factor", "n_counts", "within_day_var") %in% names(ready)
  ))

  design <- add_counts(make_test_design(), ready)
  expect_identical(design$count_col, "daily_effort")
})

# Finding 13: instantaneous counts accept and apply T_d ----
#
# An instantaneous count estimates the number of anglers present at one moment,
# not effort. Effort is that count times the length of the period the count was
# randomised within (Hoenig et al. 1993): Ê_d = C̄_d × T_d. Before these tests,
# `period_length_col` was accepted on an instantaneous design, recorded on the
# design object, and then silently discarded -- the estimate came back as the
# bare counts summed over days, with nothing to say so.

#' Counts whose T_d varies WITH the count, so Cov(C, T) != 0.
#' A fixture with constant T_d cannot distinguish per-date multiplication from
#' scaling the collapsed total, which is the whole point of finding 13.
make_instantaneous_counts_varying_td <- function() {
  data.frame(
    date = as.Date(c(
      "2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04",
      "2024-06-08", "2024-06-09", "2024-06-15", "2024-06-16"
    )),
    day_type = rep(c("weekday", "weekend"), each = 4),
    # weekdays: few anglers, short days; weekends: many anglers, long days
    n_anglers = c(10L, 12L, 11L, 15L, 40L, 55L, 48L, 52L),
    shift_hours = c(8, 8, 9, 9, 14, 14, 13, 13),
    stringsAsFactors = FALSE
  )
}

test_that("add_counts() applies T_d to instantaneous counts (finding 13)", {
  design <- creel_design(make_test_calendar(), date = date, strata = day_type)
  cnt <- make_instantaneous_counts_varying_td()

  result <- add_counts(
    design, cnt,
    period_length_col = shift_hours # nolint: object_usage_linter
  )

  # The count column is replaced by Ê_d = C × T_d, per date
  expect_equal(result$counts$n_anglers, cnt$n_anglers * cnt$shift_hours)
})

test_that("instantaneous T_d is applied per date, not to the collapsed total", {
  # Anglers fish more on long days, so Cov(C, T) > 0 and the collapsed form
  # C_total × mean(T) biases LOW. Multiplying per date makes that term exactly
  # zero at any stratum width; this test fails if the multiplication is ever
  # moved after aggregation.
  design <- creel_design(make_test_calendar(), date = date, strata = day_type)
  cnt <- make_instantaneous_counts_varying_td()

  per_date <- sum(cnt$n_anglers * cnt$shift_hours)
  collapsed <- sum(cnt$n_anglers) * mean(cnt$shift_hours)

  # Guard the fixture itself: if these ever coincide the test proves nothing
  expect_gt(per_date, collapsed)

  d <- add_counts(design, cnt, period_length_col = shift_hours) # nolint: object_usage_linter
  est <- suppressWarnings(estimate_effort(d))$estimates$estimate

  expect_equal(est, per_date)
  expect_false(isTRUE(all.equal(est, collapsed)))
})

test_that("add_counts() drops period_length_col from instantaneous counts", {
  # Left in place it is a second numeric column and can be resolved as the count
  # variable by an estimator that re-resolves it.
  design <- creel_design(make_test_calendar(), date = date, strata = day_type)
  result <- add_counts(
    design, make_instantaneous_counts_varying_td(),
    period_length_col = shift_hours # nolint: object_usage_linter
  )

  expect_false("shift_hours" %in% names(result$counts))
  expect_identical(result$period_length_col, "shift_hours")
  expect_identical(result$count_col, "n_anglers")
})

test_that("add_counts() aborts on non-positive T_d for instantaneous counts too", {
  # The guard used to live inside the progressive-only block, so a zero or
  # negative period sailed through on an instantaneous design.
  design <- creel_design(make_test_calendar(), date = date, strata = day_type)
  bad <- make_instantaneous_counts_varying_td()
  bad$shift_hours[3] <- 0

  expect_error(
    add_counts(design, bad, period_length_col = shift_hours), # nolint: object_usage_linter
    regexp = "positive"
  )
})

test_that("instantaneous multi-count PSUs scale ss_d by T_d^2 (finding 13)", {
  # aggregate_within_day() computes ss_d in count^2 units, but the within-day
  # variance contribution must be in effort^2 units once the counts become
  # Ê_d = C̄_d × T_d. Without the scaling the SE is missing the T_d^2 factor.
  design <- creel_design(make_test_calendar(), date = date, strata = day_type)
  single <- make_instantaneous_counts_varying_td()
  # am = 20, pm = 30 on every date → count ss_d = (20-25)^2 + (30-25)^2 = 50
  multi <- rbind(
    transform(single, circuit_id = "am", n_anglers = 20L),
    transform(single, circuit_id = "pm", n_anglers = 30L)
  )
  multi <- multi[order(multi$date), ]

  result <- add_counts(
    design, multi,
    count_time_col = circuit_id, # nolint: object_usage_linter
    period_length_col = shift_hours # nolint: object_usage_linter
  )

  td_by_psu <- single$shift_hours[match(result$within_day_var$date, single$date)]
  expect_equal(result$within_day_var$ss_d, 50 * td_by_psu^2)
})

test_that("grouped effort inherits T_d, so strata do not need equal day lengths", {
  # The per-date multiplication happens at attach time, so every downstream
  # path -- grouped included -- gets it without its own dispatch.
  design <- creel_design(make_test_calendar(), date = date, strata = day_type)
  cnt <- make_instantaneous_counts_varying_td()
  d <- add_counts(design, cnt, period_length_col = shift_hours) # nolint: object_usage_linter

  res <- suppressWarnings(estimate_effort(d, by = day_type))$estimates
  effort <- cnt$n_anglers * cnt$shift_hours
  expected <- tapply(effort, cnt$day_type, sum)

  expect_equal(res$estimate[res$day_type == "weekday"], as.numeric(expected[["weekday"]]))
  expect_equal(res$estimate[res$day_type == "weekend"], as.numeric(expected[["weekend"]]))
})

test_that("estimate_effort() warns when instantaneous counts carry no T_d", {
  # The gap is the point of finding 13: without T_d the estimator returns the
  # counts summed over days, which is not angler-hours. Once per session, so
  # force it rather than depending on test order.
  withr::local_options(rlib_warning_verbosity = "verbose")

  design <- creel_design(make_test_calendar(), date = date, strata = day_type)
  cnt <- make_instantaneous_counts_varying_td()
  d <- add_counts(design, cnt[, c("date", "day_type", "n_anglers")])

  expect_warning(estimate_effort(d), regexp = "angler-days")
})

test_that("estimate_effort() does not warn once T_d is supplied", {
  withr::local_options(rlib_warning_verbosity = "verbose")

  design <- creel_design(make_test_calendar(), date = date, strata = day_type)
  d <- add_counts(
    design, make_instantaneous_counts_varying_td(),
    period_length_col = shift_hours # nolint: object_usage_linter
  )

  expect_no_warning(estimate_effort(d), message = "angler-days")
})

test_that("estimate_effort() does not warn on progressive designs", {
  # Progressive always carries T_d, so the warning must not fire there.
  withr::local_options(rlib_warning_verbosity = "verbose")

  design <- creel_design(make_test_calendar(), date = date, strata = day_type)
  d <- add_counts(
    design, make_progressive_counts(),
    count_type = "progressive",
    circuit_time = 2,
    period_length_col = shift_hours # nolint: object_usage_linter
  )

  expect_no_warning(estimate_effort(d), message = "angler-days")
})

# Finding 21: aerial designs already carry their period length as h_open -------
#
# estimate_effort_aerial() scales the count by h_open/v. Finding 13 made
# add_counts() apply T_d for any count type, so an aerial design given
# period_length_col multiplied by time twice and the unit spine then labelled
# the result "angler-hours". Refusing is what keeps h_open the single source.

test_that("F21: add_counts() refuses period_length_col on an aerial design", {
  cal <- data.frame(
    date = as.Date("2024-06-01") + 0:3,
    day_type = c("weekday", "weekday", "weekend", "weekend"),
    stringsAsFactors = FALSE
  )
  counts <- data.frame(
    date = as.Date("2024-06-01") + 0:3,
    day_type = c("weekday", "weekday", "weekend", "weekend"),
    anglers = c(10, 20, 30, 40),
    shift_hours = rep(2, 4),
    stringsAsFactors = FALSE
  )
  d <- suppressWarnings(creel_design(
    cal,
    date = date,
    strata = day_type, # nolint
    survey_type = "aerial",
    h_open = 14
  ))

  expect_error(
    add_counts(
      d,
      counts,
      count_col = anglers, # nolint: object_usage_linter
      period_length_col = shift_hours # nolint: object_usage_linter
    ),
    class = "creel_error_aerial_period_length"
  )
})

test_that("F21: aerial effort still applies h_open once when T_d is absent", {
  cal <- data.frame(
    date = as.Date("2024-06-01") + 0:3,
    day_type = c("weekday", "weekday", "weekend", "weekend"),
    stringsAsFactors = FALSE
  )
  counts <- data.frame(
    date = as.Date("2024-06-01") + 0:3,
    day_type = c("weekday", "weekday", "weekend", "weekend"),
    anglers = c(10, 20, 30, 40),
    stringsAsFactors = FALSE
  )
  d <- suppressWarnings(creel_design(
    cal,
    date = date,
    strata = day_type, # nolint
    survey_type = "aerial",
    h_open = 14
  ))
  d <- suppressWarnings(add_counts(d, counts, count_col = anglers)) # nolint: object_usage_linter

  # sum(anglers) = 100 over a 4-day calendar, scaled by h_open = 14 exactly
  # once. The pre-finding-13 answer, and the correct one.
  expect_equal(
    suppressWarnings(estimate_effort(d))$estimates$estimate,
    1400
  )
})

# GH #155: the sampling unit is the PSU crossed with section/site, not the date -

# add_counts() held four separate notions of "the same unit" -- duplicate
# detection, within-day aggregation, the supplied within-day-variance key, and
# the party-size constancy check -- and none carried the section. A day sampled
# in two sections therefore read as one unit.

sec_calendar <- function() {
  data.frame(
    date = as.Date("2024-06-01") + 0:1,
    day_type = "weekday",
    stringsAsFactors = FALSE
  )
}

sec_design <- function() {
  d <- creel_design(sec_calendar(), date = date, strata = day_type)
  add_sections(
    d,
    data.frame(section = c("North", "South"), stringsAsFactors = FALSE),
    section_col = section
  )
}

# North is busy (~100 anglers), South is quiet (~10). Two count times each.
sec_subdaily_counts <- function() {
  data.frame(
    date = rep(as.Date("2024-06-01") + 0:1, each = 4),
    day_type = "weekday",
    section = rep(rep(c("North", "South"), each = 2), 2),
    count_time = rep(c("am", "pm"), 4),
    angler_count = c(100, 110, 10, 12, 102, 108, 11, 13),
    stringsAsFactors = FALSE
  )
}

test_that("within-day aggregation never averages across sections (GH #155)", {
  # The severe case: eight rows collapsed to two, giving
  # mean(100, 110, 10, 12) = 58 on a row still labelled North, with South gone
  # entirely. The daily total came out 58 where the truth is 105 + 11 = 116.
  # Silent, and it moves the point estimate.
  d <- suppressWarnings(add_counts(
    sec_design(),
    sec_subdaily_counts(),
    count_col = "angler_count",
    count_time_col = count_time
  ))

  expect_equal(nrow(d$counts), 4L)
  got <- d$counts[order(d$counts$date, d$counts$section), ]
  expect_equal(as.character(got$section), c("North", "South", "North", "South"))
  expect_equal(got$angler_count, c(105, 11, 105, 12))
})

test_that("the within-day variance measures within-day spread, not between-section (GH #155)", {
  # ss_d came out 8888 with k_d = 4 -- almost entirely the 100-vs-10 gap
  # between places. The component exists to capture count-to-count variation
  # inside one unit, so keying it across sections made it report the wrong
  # quantity, inflated by two orders of magnitude.
  d <- suppressWarnings(add_counts(
    sec_design(),
    sec_subdaily_counts(),
    count_col = "angler_count",
    count_time_col = count_time
  ))

  wdv <- d$within_day_var[order(d$within_day_var$date, d$within_day_var$section), ]
  expect_equal(wdv$ss_d, c(50, 2, 18, 2))
  expect_true(all(wdv$k_d == 2L))
})

test_that("a clean multi-section day raises no duplicate warning (GH #155)", {
  # Two sections counted once each is ordinary structure. The old key read it
  # as a repeated date and warned, and a warning that fires on correct input is
  # one users learn to ignore -- which matters because it is the only signal
  # for the case that is genuinely wrong.
  counts <- data.frame(
    date = rep(as.Date("2024-06-01") + 0:1, each = 2),
    day_type = "weekday",
    section = rep(c("North", "South"), 2),
    angler_count = c(10, 8, 12, 9),
    stringsAsFactors = FALSE
  )
  expect_no_warning(
    suppressWarnings(add_counts(sec_design(), counts, count_col = "angler_count")),
    class = "rlang_warning"
  )
})

test_that("a genuine repeat of one unit still warns (GH #155)", {
  # The check must not be weakened into uselessness: same date AND same
  # section, counted twice with no count time, is the real CNT-06 case.
  counts <- data.frame(
    date = rep(as.Date("2024-06-01") + 0:1, each = 2),
    day_type = "weekday",
    section = rep(c("North", "South"), 2),
    angler_count = c(10, 8, 12, 9),
    stringsAsFactors = FALSE
  )
  expect_warning(
    add_counts(sec_design(), rbind(counts, counts[1, ]), count_col = "angler_count"),
    regexp = "Repeated sampling units"
  )
})

test_that("a section-specific party size is accepted on a multi-section day (GH #155)", {
  # check_expansion_constant_per_psu() refused this, reporting "expansion_se
  # varies within a single PSU" and blaming two derive_angler_count() calls.
  # There is one call, and the design is coherent: parties in North average 2.5
  # anglers and in South 3.0. Under sections the unit is the day WITHIN a
  # section, and each such unit does carry exactly one estimate.
  raw <- data.frame(
    date = rep(as.Date("2024-06-01") + 0:1, each = 2),
    day_type = "weekday",
    section = rep(c("North", "South"), 2),
    angler_boats = c(5, 4, 6, 3),
    stringsAsFactors = FALSE
  )
  lookup <- data.frame(section = c("North", "South"), mps = c(2.5, 3.0))
  attr(lookup, "se") <- c(North = 0.1, South = 0.12)
  counts <- derive_angler_count(raw, boat_count = angler_boats, party_size = lookup)

  d <- suppressWarnings(add_counts(sec_design(), counts, count_col = "angler_count"))
  got <- unique(d$counts[, c("section", "expansion_se", "expansion_group")])
  got <- got[order(got$section), ]
  expect_equal(got$expansion_se, c(0.10, 0.12))
  expect_equal(as.character(got$expansion_group), c("North", "South"))
})

test_that("two different party-size estimates for ONE unit still abort (GH #131, #155)", {
  # The constancy guard's real purpose has to survive the key fix. Two count
  # times inside one date+section carrying different standard errors is a
  # malformed input, and aggregation would silently resolve it to whichever
  # row sorted first.
  raw <- data.frame(
    date = rep(as.Date("2024-06-01") + 0:1, each = 4),
    day_type = "weekday",
    section = rep(rep(c("North", "South"), each = 2), 2),
    count_time = rep(c("am", "pm"), 4),
    angler_boats = c(5, 4, 6, 3, 7, 5, 6, 4),
    stringsAsFactors = FALSE
  )
  lookup <- data.frame(section = c("North", "South"), mps = c(2.5, 3.0))
  attr(lookup, "se") <- c(North = 0.1, South = 0.12)
  counts <- derive_angler_count(raw, boat_count = angler_boats, party_size = lookup)
  counts$expansion_se[1] <- 0.99

  expect_error(
    suppressWarnings(add_counts(
      sec_design(), counts,
      count_col = "angler_count", count_time_col = count_time
    )),
    regexp = "varies within a single PSU"
  )
})
