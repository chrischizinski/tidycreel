# Tests for as_hybrid_svydesign() ----

# Helpers ---------------------------------------------------------------------
make_access <- function() {
  data.frame(
    date = as.Date(c(
      "2024-06-01",
      "2024-06-02",
      "2024-06-08",
      "2024-06-09"
    )),
    day_type = c("weekday", "weekday", "weekend", "weekend"),
    count = c(12L, 15L, 30L, 28L),
    stringsAsFactors = FALSE
  )
}

make_roving <- function() {
  data.frame(
    date = as.Date(c(
      "2024-06-01",
      "2024-06-02",
      "2024-06-08",
      "2024-06-09"
    )),
    day_type = c("weekday", "weekday", "weekend", "weekend"),
    count = c(8L, 10L, 22L, 25L),
    stringsAsFactors = FALSE
  )
}

fractions <- list(
  access = c(weekday = 0.5, weekend = 0.5),
  roving = c(weekday = 0.4, weekend = 0.4)
)

# The population of days the totals expand to (#246). Ten weekday days and six
# weekend days, chosen to contain every date the fixtures sample -- including
# the 2024-06-15 weekday HYBR-16 adds to one component only.
make_calendar <- function() {
  data.frame(
    date = as.Date(c(
      "2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04", "2024-06-05",
      "2024-06-06", "2024-06-07", "2024-06-15", "2024-06-16", "2024-06-17",
      "2024-06-08", "2024-06-09", "2024-06-10", "2024-06-11", "2024-06-12",
      "2024-06-13"
    )),
    day_type = c(rep("weekday", 10), rep("weekend", 6)),
    stringsAsFactors = FALSE
  )
}


# Input validation ------------------------------------------------------------

test_that("HYBR-01: errors when access_data is not a data frame", {
  expect_error(
    as_hybrid_svydesign(
      list(),
      make_roving(),
      calendar = make_calendar(),
      access_fraction = fractions$access,
      roving_fraction = fractions$roving
    ),
    class = "rlang_error"
  )
})

test_that("HYBR-02: errors when roving_data is not a data frame", {
  expect_error(
    as_hybrid_svydesign(
      make_access(),
      NULL,
      calendar = make_calendar(),
      access_fraction = fractions$access,
      roving_fraction = fractions$roving
    ),
    class = "rlang_error"
  )
})

test_that("HYBR-03: errors when required column missing from access_data", {
  df <- make_access()
  df$count <- NULL
  expect_error(
    as_hybrid_svydesign(
      df,
      make_roving(),
      calendar = make_calendar(),
      access_fraction = fractions$access,
      roving_fraction = fractions$roving
    ),
    class = "rlang_error"
  )
})

test_that("HYBR-04: errors when required column missing from roving_data", {
  df <- make_roving()
  df$date <- NULL
  expect_error(
    as_hybrid_svydesign(
      make_access(),
      df,
      calendar = make_calendar(),
      access_fraction = fractions$access,
      roving_fraction = fractions$roving
    ),
    class = "rlang_error"
  )
})

test_that("HYBR-05: errors when access_fraction is NULL", {
  expect_error(
    as_hybrid_svydesign(
      make_access(),
      make_roving(),
      calendar = make_calendar(),
      roving_fraction = fractions$roving
    ),
    class = "rlang_error"
  )
})

test_that("HYBR-06: errors when roving_fraction is NULL", {
  expect_error(
    as_hybrid_svydesign(
      make_access(),
      make_roving(),
      calendar = make_calendar(),
      access_fraction = fractions$access
    ),
    class = "rlang_error"
  )
})

test_that("HYBR-07: errors when fraction missing a stratum", {
  expect_error(
    as_hybrid_svydesign(
      make_access(),
      make_roving(),
      calendar = make_calendar(),
      access_fraction = c(weekday = 0.5), # missing weekend
      roving_fraction = fractions$roving
    ),
    class = "rlang_error"
  )
})

test_that("HYBR-08: errors when fraction value <= 0", {
  expect_error(
    as_hybrid_svydesign(
      make_access(),
      make_roving(),
      calendar = make_calendar(),
      access_fraction = c(weekday = 0, weekend = 0.5),
      roving_fraction = fractions$roving
    ),
    class = "rlang_error"
  )
})

test_that("HYBR-09: errors when fraction value > 1", {
  expect_error(
    as_hybrid_svydesign(
      make_access(),
      make_roving(),
      calendar = make_calendar(),
      access_fraction = c(weekday = 1.5, weekend = 0.5),
      roving_fraction = fractions$roving
    ),
    class = "rlang_error"
  )
})

# Return structure ------------------------------------------------------------

test_that("HYBR-10: returns an svydesign object", {
  design <- suppressWarnings(as_hybrid_svydesign(
    make_access(),
    make_roving(),
    calendar = make_calendar(),
    access_fraction = fractions$access,
    roving_fraction = fractions$roving,
    trips_disjoint = TRUE
  ))
  expect_true(inherits(design, "survey.design"))
})

test_that("HYBR-11: returns creel_hybrid_svydesign class", {
  design <- suppressWarnings(as_hybrid_svydesign(
    make_access(),
    make_roving(),
    calendar = make_calendar(),
    access_fraction = fractions$access,
    roving_fraction = fractions$roving,
    trips_disjoint = TRUE
  ))
  expect_s3_class(design, "creel_hybrid_svydesign")
})

test_that("HYBR-12: combined data has component column", {
  design <- suppressWarnings(as_hybrid_svydesign(
    make_access(),
    make_roving(),
    calendar = make_calendar(),
    access_fraction = fractions$access,
    roving_fraction = fractions$roving,
    trips_disjoint = TRUE
  ))
  expect_true("component" %in% names(design$variables))
  expect_setequal(unique(design$variables$component), c("access", "roving"))
})

test_that("HYBR-13: combined data has weight column", {
  design <- suppressWarnings(as_hybrid_svydesign(
    make_access(),
    make_roving(),
    calendar = make_calendar(),
    access_fraction = fractions$access,
    roving_fraction = fractions$roving,
    trips_disjoint = TRUE
  ))
  expect_true("weight" %in% names(design$variables))
  expect_true(all(design$variables$weight > 0))
})

test_that("HYBR-14: row count equals nrow(access) + nrow(roving)", {
  design <- suppressWarnings(as_hybrid_svydesign(
    make_access(),
    make_roving(),
    calendar = make_calendar(),
    access_fraction = fractions$access,
    roving_fraction = fractions$roving,
    trips_disjoint = TRUE
  ))
  expect_equal(nrow(design$variables), nrow(make_access()) + nrow(make_roving()))
})

# Weight correctness ----------------------------------------------------------

test_that("HYBR-15: access weights carry the within-day AND the day expansion", {
  # Two factors, not one (#246): 1 / access_fraction expands the access points
  # covered to the whole of a sampled day, and N_h / n_h expands the sampled
  # days to the days the stratum holds. Asserting only the first would pass
  # while the design silently estimated a sampled-day total.
  design <- suppressWarnings(as_hybrid_svydesign(
    make_access(),
    make_roving(),
    calendar = make_calendar(),
    access_fraction = c(weekday = 0.5, weekend = 0.25),
    roving_fraction = fractions$roving,
    trips_disjoint = TRUE
  ))
  vars <- design$variables
  # 10 weekday days and 6 weekend days in the calendar; 2 sampled dates each.
  acc_wk <- vars$weight[vars$component == "access" & vars$day_type == "weekday"]
  expect_equal(unique(acc_wk), (1 / 0.5) * (10 / 2), tolerance = 1e-9)
  acc_we <- vars$weight[vars$component == "access" & vars$day_type == "weekend"]
  expect_equal(unique(acc_we), (1 / 0.25) * (6 / 2), tolerance = 1e-9)
})

# PSU alignment warning -------------------------------------------------------

test_that("HYBR-16: asymmetric dates produce a warning", {
  access_extra <- rbind(
    make_access(),
    data.frame(
      date = as.Date("2024-06-15"),
      day_type = "weekday",
      count = 5L,
      stringsAsFactors = FALSE
    )
  )
  expect_warning(
    as_hybrid_svydesign(
      access_extra,
      make_roving(),
      calendar = make_calendar(),
      access_fraction = c(weekday = 0.5, weekend = 0.5),
      roving_fraction = fractions$roving,
      trips_disjoint = TRUE
    )
  )
})

test_that("HYBR-17: symmetric dates produce no PSU warning", {
  expect_no_warning(
    as_hybrid_svydesign(
      make_access(),
      make_roving(),
      calendar = make_calendar(),
      access_fraction = fractions$access,
      roving_fraction = fractions$roving,
      trips_disjoint = TRUE,
      fpc = FALSE
    )
  )
})

# fpc = FALSE -----------------------------------------------------------------

test_that("HYBR-18: fpc = FALSE produces a valid design", {
  design <- as_hybrid_svydesign(
    make_access(),
    make_roving(),
    calendar = make_calendar(),
    access_fraction = fractions$access,
    roving_fraction = fractions$roving,
    trips_disjoint = TRUE,
    fpc = FALSE
  )
  expect_s3_class(design, "creel_hybrid_svydesign")
})

# Custom column names ---------------------------------------------------------

test_that("HYBR-19: custom column names work", {
  access_custom <- make_access()
  names(access_custom)[names(access_custom) == "date"] <- "survey_date"
  names(access_custom)[names(access_custom) == "day_type"] <- "stratum"
  names(access_custom)[names(access_custom) == "count"] <- "n_anglers"

  roving_custom <- make_roving()
  names(roving_custom)[names(roving_custom) == "date"] <- "survey_date"
  names(roving_custom)[names(roving_custom) == "day_type"] <- "stratum"
  names(roving_custom)[names(roving_custom) == "count"] <- "n_anglers"

  calendar_custom <- make_calendar()
  names(calendar_custom)[names(calendar_custom) == "date"] <- "survey_date"
  names(calendar_custom)[names(calendar_custom) == "day_type"] <- "stratum"

  design <- as_hybrid_svydesign(
    access_custom,
    roving_custom,
    calendar = calendar_custom,
    date_col = "survey_date",
    strata_col = "stratum",
    count_col = "n_anglers",
    access_fraction = c(weekday = 0.5, weekend = 0.5),
    roving_fraction = c(weekday = 0.4, weekend = 0.4),
    trips_disjoint = TRUE
  )
  expect_s3_class(design, "creel_hybrid_svydesign")
})

# svytotal sanity -------------------------------------------------------------

test_that("HYBR-20: svytotal runs without error on the hybrid design", {
  design <- as_hybrid_svydesign(
    make_access(),
    make_roving(),
    calendar = make_calendar(),
    access_fraction = fractions$access,
    roving_fraction = fractions$roving,
    trips_disjoint = TRUE,
    fpc = FALSE
  )
  result <- suppressWarnings(survey::svytotal(~count, design))
  expect_true(is.numeric(coef(result)))
  expect_true(coef(result) > 0)
})

# Missing and mistyped keys ---------------------------------------------------
# Dates and strata are compared through as.character(), which renders NA as the
# string "NA" and then matches it to every other NA. Left unrefused, a missing
# calendar date counts as one more day in N_h -- on a four-day weekday calendar
# with two sampled days, adding one NA row moved the estimated total from 156 to
# 195 with no error and no warning.

test_that("HYBR-21: a missing sampled date is refused", {
  access_na <- make_access()
  access_na$date[2] <- as.Date(NA)
  expect_error(
    as_hybrid_svydesign(
      access_na,
      make_roving(),
      calendar = make_calendar(),
      access_fraction = fractions$access,
      roving_fraction = fractions$roving,
      trips_disjoint = TRUE
    ),
    "date.*access_data.*missing"
  )
})

test_that("HYBR-22: a missing calendar date is refused, not counted as a day", {
  # The clean calendar is the control: the same design builds, so the refusal
  # below is about the NA and not about the fixture.
  design <- as_hybrid_svydesign(
    make_access(),
    make_roving(),
    calendar = make_calendar(),
    access_fraction = fractions$access,
    roving_fraction = fractions$roving,
    trips_disjoint = TRUE
  )
  expect_s3_class(design, "survey.design")

  calendar_na <- make_calendar()
  calendar_na <- rbind(
    calendar_na,
    data.frame(date = as.Date(NA), day_type = "weekday", stringsAsFactors = FALSE)
  )
  expect_error(
    as_hybrid_svydesign(
      make_access(),
      make_roving(),
      calendar = calendar_na,
      access_fraction = fractions$access,
      roving_fraction = fractions$roving,
      trips_disjoint = TRUE
    ),
    "date.*calendar.*missing"
  )
})

test_that("HYBR-23: a missing calendar stratum is refused", {
  # A day whose stratum is NA reaches no stratum population at all, so the
  # season it expands to is shorter than the calendar the caller supplied.
  calendar_na <- make_calendar()
  calendar_na$day_type[3] <- NA_character_
  expect_error(
    as_hybrid_svydesign(
      make_access(),
      make_roving(),
      calendar = calendar_na,
      access_fraction = fractions$access,
      roving_fraction = fractions$roving,
      trips_disjoint = TRUE
    ),
    "day_type.*calendar.*missing"
  )
})

test_that("HYBR-24: a non-Date date column is refused", {
  access_chr <- make_access()
  access_chr$date <- as.character(access_chr$date)
  expect_error(
    as_hybrid_svydesign(
      access_chr,
      make_roving(),
      calendar = make_calendar(),
      access_fraction = fractions$access,
      roving_fraction = fractions$roving,
      trips_disjoint = TRUE
    ),
    "must be a.*Date.*column"
  )
})

test_that("HYBR-25: a non-scalar or missing fpc is refused", {
  # `fpc` is branched on with a bare `if`, where NA is base R's "missing value
  # where TRUE/FALSE needed" and a length-2 vector silently takes its first
  # element -- building the design with a correction the caller never chose.
  for (bad in list(NA, c(TRUE, FALSE), "yes", 1)) {
    expect_error(
      as_hybrid_svydesign(
        make_access(),
        make_roving(),
        calendar = make_calendar(),
        access_fraction = fractions$access,
        roving_fraction = fractions$roving,
        trips_disjoint = TRUE,
        fpc = bad
      ),
      "fpc.*must be"
    )
  }

  # The two valid values still build.
  for (good in c(TRUE, FALSE)) {
    design <- as_hybrid_svydesign(
      make_access(),
      make_roving(),
      calendar = make_calendar(),
      access_fraction = fractions$access,
      roving_fraction = fractions$roving,
      trips_disjoint = TRUE,
      fpc = good
    )
    expect_s3_class(design, "survey.design")
  }
})
