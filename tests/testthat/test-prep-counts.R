test_that("prep_counts_daily_effort() returns canonical columns with optional fields", {
  df <- tibble::tibble(
    survey_date = as.Date(c("2024-06-01", "2024-06-02")),
    month = factor(c("6", "6")),
    day_type = factor(c("weekend", "weekend")),
    effort_kind = c("bank", "boat"),
    effort_value = c(12.5, 18.0),
    site_day = c("a", "b"),
    correction = c(1, 1),
    k = c(2L, 3L),
    ss = c(1.2, 2.3),
    method = c("direct_count", "direct_count")
  )

  result <- prep_counts_daily_effort(
    df,
    date = survey_date,
    strata = c(month, day_type),
    effort_type = effort_kind,
    daily_effort = effort_value,
    correction_factor = correction,
    psu = site_day,
    n_counts = k,
    within_day_var = ss,
    source_method = method
  )

  expect_s3_class(result, "tbl_df")
  expect_named(
    result,
    c(
      "date", "month", "day_type", "effort_type", "daily_effort", "psu",
      "correction_factor", "n_counts", "within_day_var", "source_method"
    )
  )
  expect_equal(result$daily_effort, c(12.5, 18.0))
  expect_equal(result$correction_factor, c(1, 1))
  expect_equal(result$psu, c("a", "b"))
  expect_equal(result$effort_type, c("bank", "boat"))
})

test_that("prep_counts_daily_effort() applies scalar correction_factor", {
  df <- tibble::tibble(
    date = as.Date(c("2024-06-01", "2024-06-02")),
    effort_type = c("boat", "boat"),
    effort = c(10, 20)
  )

  result <- prep_counts_daily_effort(
    df,
    date = date,
    effort_type = effort_type,
    daily_effort = effort,
    correction_factor = 1.5
  )

  expect_equal(result$daily_effort, c(15, 30))
  expect_equal(result$correction_factor, c(1.5, 1.5))
})

test_that("prep_counts_daily_effort() applies row-wise correction_factor", {
  df <- tibble::tibble(
    date = as.Date(c("2024-06-01", "2024-06-02")),
    effort_type = c("boat", "boat"),
    effort = c(10, 20),
    factor = c(1.2, 1.5)
  )

  result <- prep_counts_daily_effort(
    df,
    date = date,
    effort_type = effort_type,
    daily_effort = effort,
    correction_factor = factor
  )

  expect_equal(result$daily_effort, c(12, 30))
  expect_equal(result$correction_factor, c(1.2, 1.5))
})

test_that("prep_counts_daily_effort() defaults correction_factor to one", {
  df <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02")),
    day_type = c("weekday", "weekend"),
    effort_type = c("bank", "boat"),
    effort = c(10, 20)
  )

  result <- prep_counts_daily_effort(
    df,
    date = date,
    strata = day_type,
    effort_type = effort_type,
    daily_effort = effort
  )

  expect_equal(result$correction_factor, c(1, 1))
})

test_that("prep_counts_daily_effort() defaults psu to date", {
  df <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02")),
    day_type = c("weekday", "weekend"),
    effort_type = c("bank", "boat"),
    effort = c(10, 20)
  )

  result <- prep_counts_daily_effort(
    df,
    date = date,
    strata = day_type,
    effort_type = effort_type,
    daily_effort = effort
  )

  expect_identical(result$psu, result$date)
})

test_that("prep_counts_daily_effort() preserves date and strata values", {
  df <- tibble::tibble(
    date = as.Date(c("2024-06-01", "2024-06-08")),
    month = factor(c("6", "6")),
    day_type = factor(c("weekend", "weekend")),
    high_use = factor(c("0", "1")),
    effort_type = c("bank", "bank"),
    effort = c(3.5, 7.25)
  )

  result <- prep_counts_daily_effort(
    df,
    date = date,
    strata = c(month, day_type, high_use),
    effort_type = effort_type,
    daily_effort = effort
  )

  expect_identical(result$date, df$date)
  expect_identical(result$month, df$month)
  expect_identical(result$day_type, df$day_type)
  expect_identical(result$high_use, df$high_use)
})

test_that("prep_counts_daily_effort() errors when date column is not Date", {
  df <- data.frame(
    date_chr = c("2024-06-01", "2024-06-02"),
    effort_type = c("bank", "boat"),
    effort = c(10, 20)
  )

  expect_error(
    prep_counts_daily_effort(
      df,
      date = date_chr,
      effort_type = effort_type,
      daily_effort = effort
    ),
    "Date"
  )
})

test_that("prep_counts_daily_effort() errors when daily_effort is not numeric", {
  df <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02")),
    effort_type = c("bank", "boat"),
    effort = c("10", "20")
  )

  expect_error(
    prep_counts_daily_effort(
      df,
      date = date,
      effort_type = effort_type,
      daily_effort = effort
    ),
    "must be numeric"
  )
})

test_that("prep_counts_daily_effort() errors when effort_type is not character or factor", {
  df <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02")),
    effort_type = c(1, 2),
    effort = c(10, 20)
  )

  expect_error(
    prep_counts_daily_effort(
      df,
      date = date,
      effort_type = effort_type,
      daily_effort = effort
    ),
    "character or factor"
  )
})

test_that("prep_counts_daily_effort() errors when correction_factor is not numeric", {
  df <- tibble::tibble(
    date = as.Date(c("2024-06-01", "2024-06-02")),
    effort_type = c("boat", "boat"),
    effort = c(10, 20),
    factor = c("1.2", "1.5")
  )

  expect_error(
    prep_counts_daily_effort(
      df,
      date = date,
      effort_type = effort_type,
      daily_effort = effort,
      correction_factor = factor
    ),
    "correction_factor.*numeric"
  )
})

test_that("prep_counts_daily_effort() errors when correction_factor is non-positive", {
  df <- tibble::tibble(
    date = as.Date(c("2024-06-01", "2024-06-02")),
    effort_type = c("boat", "boat"),
    effort = c(10, 20),
    factor = c(1, 0)
  )

  expect_error(
    prep_counts_daily_effort(
      df,
      date = date,
      effort_type = effort_type,
      daily_effort = effort,
      correction_factor = factor
    ),
    "strictly positive"
  )
})

test_that("prep_counts_boat_party() computes canonical daily boat effort rows", {
  df <- tibble::tibble(
    sample_date = as.Date(c("2024-06-01", "2024-06-02")),
    day_type = c("weekend", "weekend"),
    boats = c(10, 12),
    mean_party = c(2.5, 2.0),
    site_day = c("a", "b")
  )

  result <- prep_counts_boat_party(
    df,
    date = sample_date,
    strata = day_type,
    boat_count = boats,
    mean_party_size = mean_party,
    psu = site_day
  )

  expect_named(
    result,
    c("date", "day_type", "effort_type", "daily_effort", "psu", "correction_factor", "source_method")
  )
  expect_equal(result$effort_type, c("boat", "boat"))
  expect_equal(result$daily_effort, c(25, 24))
  expect_equal(result$correction_factor, c(1, 1))
  expect_equal(result$source_method, c("boat_count_x_mean_party_size", "boat_count_x_mean_party_size"))
})

test_that("prep_counts_boat_party() applies correction_factor", {
  df <- tibble::tibble(
    date = as.Date(c("2024-06-01", "2024-06-02")),
    boats = c(10, 12),
    mean_party = c(2.5, 2.0),
    adjust = c(1.1, 0.9)
  )

  result <- prep_counts_boat_party(
    df,
    date = date,
    boat_count = boats,
    mean_party_size = mean_party,
    correction_factor = adjust
  )

  expect_equal(result$daily_effort, c(27.5, 21.6))
  expect_equal(result$correction_factor, c(1.1, 0.9))
})

test_that("prep_counts_boat_party() errors on invalid boat_count or mean_party_size", {
  df_bad_boats <- tibble::tibble(
    date = as.Date("2024-06-01"),
    boats = -1,
    mean_party = 2
  )

  expect_error(
    prep_counts_boat_party(
      df_bad_boats,
      date = date,
      boat_count = boats,
      mean_party_size = mean_party
    ),
    "non-negative"
  )

  df_bad_party <- tibble::tibble(
    date = as.Date("2024-06-01"),
    boats = 3,
    mean_party = 0
  )

  expect_error(
    prep_counts_boat_party(
      df_bad_party,
      date = date,
      boat_count = boats,
      mean_party_size = mean_party
    ),
    "strictly positive"
  )
})
