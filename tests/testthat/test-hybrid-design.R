# Tests for as_hybrid_svydesign() ----

# Helpers ---------------------------------------------------------------------
make_access <- function() {
  data.frame(
    date = as.Date(c(
      "2024-06-01", "2024-06-02",
      "2024-06-08", "2024-06-09"
    )),
    day_type = c("weekday", "weekday", "weekend", "weekend"),
    count = c(12L, 15L, 30L, 28L),
    stringsAsFactors = FALSE
  )
}

make_roving <- function() {
  data.frame(
    date = as.Date(c(
      "2024-06-01", "2024-06-02",
      "2024-06-08", "2024-06-09"
    )),
    day_type = c("weekday", "weekday", "weekend", "weekend"),
    count = c(8L, 10L, 22L, 25L),
    stringsAsFactors = FALSE
  )
}

fractions <- list(
  access  = c(weekday = 0.5, weekend = 0.5),
  roving  = c(weekday = 0.4, weekend = 0.4)
)

# Input validation ------------------------------------------------------------

test_that("HYBR-01: errors when access_data is not a data frame", {
  expect_error(
    as_hybrid_svydesign(list(), make_roving(),
      access_fraction = fractions$access,
      roving_fraction = fractions$roving
    ),
    class = "rlang_error"
  )
})

test_that("HYBR-02: errors when roving_data is not a data frame", {
  expect_error(
    as_hybrid_svydesign(make_access(), NULL,
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
    as_hybrid_svydesign(df, make_roving(),
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
    as_hybrid_svydesign(make_access(), df,
      access_fraction = fractions$access,
      roving_fraction = fractions$roving
    ),
    class = "rlang_error"
  )
})

test_that("HYBR-05: errors when access_fraction is NULL", {
  expect_error(
    as_hybrid_svydesign(make_access(), make_roving(),
      roving_fraction = fractions$roving
    ),
    class = "rlang_error"
  )
})

test_that("HYBR-06: errors when roving_fraction is NULL", {
  expect_error(
    as_hybrid_svydesign(make_access(), make_roving(),
      access_fraction = fractions$access
    ),
    class = "rlang_error"
  )
})

test_that("HYBR-07: errors when fraction missing a stratum", {
  expect_error(
    as_hybrid_svydesign(make_access(), make_roving(),
      access_fraction = c(weekday = 0.5), # missing weekend
      roving_fraction = fractions$roving
    ),
    class = "rlang_error"
  )
})

test_that("HYBR-08: errors when fraction value <= 0", {
  expect_error(
    as_hybrid_svydesign(make_access(), make_roving(),
      access_fraction = c(weekday = 0, weekend = 0.5),
      roving_fraction = fractions$roving
    ),
    class = "rlang_error"
  )
})

test_that("HYBR-09: errors when fraction value > 1", {
  expect_error(
    as_hybrid_svydesign(make_access(), make_roving(),
      access_fraction = c(weekday = 1.5, weekend = 0.5),
      roving_fraction = fractions$roving
    ),
    class = "rlang_error"
  )
})

# Return structure ------------------------------------------------------------

test_that("HYBR-10: returns an svydesign object", {
  design <- suppressWarnings(as_hybrid_svydesign(
    make_access(), make_roving(),
    access_fraction = fractions$access,
    roving_fraction = fractions$roving
  ))
  expect_true(inherits(design, "survey.design"))
})

test_that("HYBR-11: returns creel_hybrid_svydesign class", {
  design <- suppressWarnings(as_hybrid_svydesign(
    make_access(), make_roving(),
    access_fraction = fractions$access,
    roving_fraction = fractions$roving
  ))
  expect_s3_class(design, "creel_hybrid_svydesign")
})

test_that("HYBR-12: combined data has component column", {
  design <- suppressWarnings(as_hybrid_svydesign(
    make_access(), make_roving(),
    access_fraction = fractions$access,
    roving_fraction = fractions$roving
  ))
  expect_true("component" %in% names(design$variables))
  expect_setequal(unique(design$variables$component), c("access", "roving"))
})

test_that("HYBR-13: combined data has weight column", {
  design <- suppressWarnings(as_hybrid_svydesign(
    make_access(), make_roving(),
    access_fraction = fractions$access,
    roving_fraction = fractions$roving
  ))
  expect_true("weight" %in% names(design$variables))
  expect_true(all(design$variables$weight > 0))
})

test_that("HYBR-14: row count equals nrow(access) + nrow(roving)", {
  design <- suppressWarnings(as_hybrid_svydesign(
    make_access(), make_roving(),
    access_fraction = fractions$access,
    roving_fraction = fractions$roving
  ))
  expect_equal(nrow(design$variables), nrow(make_access()) + nrow(make_roving()))
})

# Weight correctness ----------------------------------------------------------

test_that("HYBR-15: access weights = 1 / access_fraction", {
  design <- suppressWarnings(as_hybrid_svydesign(
    make_access(), make_roving(),
    access_fraction = c(weekday = 0.5, weekend = 0.25),
    roving_fraction = fractions$roving
  ))
  vars <- design$variables
  acc_wk <- vars$weight[vars$component == "access" & vars$day_type == "weekday"]
  expect_equal(unique(acc_wk), 1 / 0.5, tolerance = 1e-9)
  acc_we <- vars$weight[vars$component == "access" & vars$day_type == "weekend"]
  expect_equal(unique(acc_we), 1 / 0.25, tolerance = 1e-9)
})

# PSU alignment warning -------------------------------------------------------

test_that("HYBR-16: asymmetric dates produce a warning", {
  access_extra <- rbind(
    make_access(),
    data.frame(
      date = as.Date("2024-06-15"), day_type = "weekday",
      count = 5L, stringsAsFactors = FALSE
    )
  )
  expect_warning(
    as_hybrid_svydesign(
      access_extra, make_roving(),
      access_fraction = c(weekday = 0.5, weekend = 0.5),
      roving_fraction = fractions$roving
    )
  )
})

test_that("HYBR-17: symmetric dates produce no PSU warning", {
  expect_no_warning(
    as_hybrid_svydesign(
      make_access(), make_roving(),
      access_fraction = fractions$access,
      roving_fraction = fractions$roving,
      fpc = FALSE
    )
  )
})

# fpc = FALSE -----------------------------------------------------------------

test_that("HYBR-18: fpc = FALSE produces a valid design", {
  design <- as_hybrid_svydesign(
    make_access(), make_roving(),
    access_fraction = fractions$access,
    roving_fraction = fractions$roving,
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

  design <- as_hybrid_svydesign(
    access_custom, roving_custom,
    date_col = "survey_date",
    strata_col = "stratum",
    count_col = "n_anglers",
    access_fraction = c(weekday = 0.5, weekend = 0.5),
    roving_fraction = c(weekday = 0.4, weekend = 0.4)
  )
  expect_s3_class(design, "creel_hybrid_svydesign")
})

# svytotal sanity -------------------------------------------------------------

test_that("HYBR-20: svytotal runs without error on the hybrid design", {
  design <- as_hybrid_svydesign(
    make_access(), make_roving(),
    access_fraction = fractions$access,
    roving_fraction = fractions$roving,
    fpc = FALSE
  )
  result <- suppressWarnings(survey::svytotal(~count, design))
  expect_true(is.numeric(coef(result)))
  expect_true(coef(result) > 0)
})
