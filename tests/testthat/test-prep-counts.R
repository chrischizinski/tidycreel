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
      "date",
      "month",
      "day_type",
      "effort_type",
      "daily_effort",
      "psu",
      "correction_factor",
      "n_counts",
      "within_day_var",
      "source_method"
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
    c(
      "date",
      "day_type",
      "effort_type",
      "daily_effort",
      "psu",
      "correction_factor",
      "source_method"
    )
  )
  expect_equal(result$effort_type, c("boat", "boat"))
  expect_equal(result$daily_effort, c(25, 24))
  expect_equal(result$correction_factor, c(1, 1))
  expect_equal(
    result$source_method,
    c("boat_count_x_mean_party_size", "boat_count_x_mean_party_size")
  )
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

# GH #109 — within-day variance reaches the estimator (audit finding 6) ----
#
# `prep_counts_*()` wrote `n_counts` and `within_day_var` into its output tibble
# and `add_counts()` never read them, so a user who supplied a within-day sum of
# squares through the documented preferred seam got an SE with the entire
# within-day component missing. Downward-biased SE is the dangerous direction.

make_wdv_raw <- function(n_days = 8L, counts_per_day = c(8, 12, 16)) {
  dates <- seq(as.Date("2024-06-01"), by = "day", length.out = n_days)
  do.call(rbind, lapply(seq_along(dates), function(i) {
    data.frame(
      date = dates[i],
      day_type = "weekday",
      count = counts_per_day + i
    )
  }))
}

# Collapses the raw counts to the per-PSU summary a user would compute by hand
# before calling prep_counts_*().
make_wdv_per_day <- function(raw) {
  out <- do.call(rbind, lapply(split(raw, raw$date), function(g) {
    data.frame(
      date = g$date[1],
      day_type = "weekday",
      mean_count = mean(g$count),
      ss = sum((g$count - mean(g$count))^2),
      k = nrow(g),
      effort_type = "angler_hours",
      boats = mean(g$count),
      mps = 2.5
    )
  }))
  out$date <- as.Date(out$date, origin = "1970-01-01")
  out
}

make_wdv_design <- function(raw) {
  cal <- data.frame(date = unique(raw$date), day_type = "weekday")
  suppressMessages(creel_design(calendar = cal, date = date, strata = day_type)) # nolint: object_usage_linter
}

test_that("supplied within_day_var reaches the design and the SE (GH #109)", {
  # The component used to be dropped on the floor: design$within_day_var stayed
  # NULL and the within-day contribution evaluated to exactly 0.
  raw <- make_wdv_raw()
  prepped <- prep_counts_daily_effort(
    make_wdv_per_day(raw),
    date = date, # nolint: object_usage_linter
    strata = day_type, # nolint: object_usage_linter
    effort_type = effort_type, # nolint: object_usage_linter
    daily_effort = mean_count, # nolint: object_usage_linter
    n_counts = k, # nolint: object_usage_linter
    within_day_var = ss # nolint: object_usage_linter
  )
  d <- suppressMessages(add_counts(
    make_wdv_design(raw),
    prepped,
    count_col = daily_effort, # nolint: object_usage_linter
    psu = "psu"
  ))

  expect_false(is.null(d$within_day_var))
  expect_identical(d$within_day_var$ss_d, prepped$within_day_var)
  expect_identical(d$within_day_var$k_d, prepped$n_counts)
  expect_gt(compute_within_day_var_contribution(d), 0)
})

test_that("both within-day seams give the same SE on the same data (GH #109)", {
  # The strongest statement of the fix: routing identical counts through the
  # prep_counts seam and through add_counts(count_time_col =) must agree. Before
  # the fix the prep seam reported a strictly smaller SE, because it was missing
  # a variance component the other one included.
  raw <- make_wdv_raw()

  prepped <- prep_counts_daily_effort(
    make_wdv_per_day(raw),
    date = date,
    strata = day_type,
    effort_type = effort_type,
    daily_effort = mean_count,
    n_counts = k,
    within_day_var = ss
  )
  d_prep <- suppressMessages(add_counts(
    make_wdv_design(raw), prepped, count_col = daily_effort, psu = "psu"
  ))

  raw_timed <- raw
  raw_timed$count_time <- rep(c(9, 13, 17), times = length(unique(raw$date)))
  d_time <- suppressMessages(add_counts(
    make_wdv_design(raw),
    raw_timed,
    count_col = count, # nolint: object_usage_linter
    psu = "date",
    count_time_col = count_time # nolint: object_usage_linter
  ))

  e_prep <- suppressMessages(estimate_effort(d_prep))$estimates
  e_time <- suppressMessages(estimate_effort(d_time))$estimates

  expect_equal(e_prep$estimate, e_time$estimate, tolerance = 1e-9)
  expect_equal(e_prep$se, e_time$se, tolerance = 1e-9)

  # And the within-day component is a real part of that SE, not a rounding
  # artefact: dropping it would shrink the SE.
  se_between_only <- sqrt(e_prep$se^2 - compute_within_day_var_contribution(d_prep))
  expect_lt(se_between_only, e_prep$se)
})

test_that("within_day_var is rescaled by correction_factor squared (GH #109)", {
  # daily_effort is multiplied by correction_factor, so a sum of squares computed
  # on the unscaled counts is a factor of cf^2 away from the between-day term it
  # is added to. Passing it through unscaled was the latent half of finding 6.
  raw <- make_wdv_raw()
  per_day <- make_wdv_per_day(raw)

  prepped <- prep_counts_daily_effort(
    per_day,
    date = date,
    strata = day_type,
    effort_type = effort_type,
    daily_effort = mean_count,
    correction_factor = 2,
    n_counts = k,
    within_day_var = ss
  )
  expect_equal(prepped$within_day_var, per_day$ss * 4, tolerance = 1e-9)

  # Cross-check against the raw-count seam with the counts themselves doubled,
  # which is the same survey.
  d_prep <- suppressMessages(add_counts(
    make_wdv_design(raw), prepped, count_col = daily_effort, psu = "psu"
  ))
  raw_doubled <- raw
  raw_doubled$count <- raw_doubled$count * 2
  raw_doubled$count_time <- rep(c(9, 13, 17), times = length(unique(raw$date)))
  d_time <- suppressMessages(add_counts(
    make_wdv_design(raw), raw_doubled, count_col = count, psu = "date",
    count_time_col = count_time
  ))

  expect_equal(
    suppressMessages(estimate_effort(d_prep))$estimates$se,
    suppressMessages(estimate_effort(d_time))$estimates$se,
    tolerance = 1e-9
  )
})

test_that("boat path rescales within_day_var by (party size x cf) squared (GH #109)", {
  # daily_effort is boat_count x mean_party_size x correction_factor, so a sum of
  # squares computed on boat counts needs both factors squared.
  raw <- make_wdv_raw()
  per_day <- make_wdv_per_day(raw)

  prepped <- prep_counts_boat_party(
    per_day,
    date = date,
    strata = day_type,
    effort_type = effort_type,
    boat_count = boats, # nolint: object_usage_linter
    mean_party_size = mps, # nolint: object_usage_linter
    correction_factor = 2,
    n_counts = k,
    within_day_var = ss
  )
  expect_equal(prepped$within_day_var, per_day$ss * (2.5 * 2)^2, tolerance = 1e-9)

  d_prep <- suppressMessages(add_counts(
    make_wdv_design(raw), prepped, count_col = daily_effort, psu = "psu"
  ))
  raw_scaled <- raw
  raw_scaled$count <- raw_scaled$count * 2.5 * 2
  raw_scaled$count_time <- rep(c(9, 13, 17), times = length(unique(raw$date)))
  d_time <- suppressMessages(add_counts(
    make_wdv_design(raw), raw_scaled, count_col = count, psu = "date",
    count_time_col = count_time
  ))

  expect_equal(
    suppressMessages(estimate_effort(d_prep))$estimates$se,
    suppressMessages(estimate_effort(d_time))$estimates$se,
    tolerance = 1e-9
  )
})

test_that("within_day_var without n_counts is an error (GH #109)", {
  # k_d is needed to compute the component at all, and demanding it is what
  # makes the sum-of-squares contract statable.
  per_day <- make_wdv_per_day(make_wdv_raw())
  expect_error(
    prep_counts_daily_effort(
      per_day,
      date = date,
      strata = day_type,
      effort_type = effort_type,
      daily_effort = mean_count,
      within_day_var = ss
    ),
    "requires"
  )
})

test_that("a non-zero within_day_var where n_counts is 1 is an error (GH #109)", {
  # One count carries no within-day information, so a non-zero sum of squares
  # there means the column is a variance, or the two columns disagree. Either
  # way it must not be silently used.
  per_day <- make_wdv_per_day(make_wdv_raw())
  per_day$k <- 1L
  expect_error(
    prep_counts_daily_effort(
      per_day,
      date = date,
      strata = day_type,
      effort_type = effort_type,
      daily_effort = mean_count,
      n_counts = k,
      within_day_var = ss
    ),
    "non-zero"
  )
})

test_that("a negative within_day_var is an error (GH #109)", {
  per_day <- make_wdv_per_day(make_wdv_raw())
  per_day$ss <- -1
  expect_error(
    prep_counts_daily_effort(
      per_day,
      date = date,
      strata = day_type,
      effort_type = effort_type,
      daily_effort = mean_count,
      n_counts = k,
      within_day_var = ss
    ),
    "must not be negative"
  )
})

test_that("supplying the within-day component twice is an error (GH #109)", {
  # count_time_col derives it from raw counts and the columns carry it directly.
  # Taking both would double-count the component.
  raw <- make_wdv_raw()
  raw$count_time <- rep(c(9, 13, 17), times = length(unique(raw$date)))
  raw$within_day_var <- 1
  raw$n_counts <- 3L

  expect_error(
    add_counts(
      make_wdv_design(raw), raw, count_col = count, psu = "date",
      count_time_col = count_time
    ),
    "supplied twice"
  )
})

test_that("a within_day_var column without n_counts is an error in add_counts() (GH #109)", {
  raw <- make_wdv_raw()
  prepped <- prep_counts_daily_effort(
    make_wdv_per_day(raw),
    date = date,
    strata = day_type,
    effort_type = effort_type,
    daily_effort = mean_count,
    n_counts = k,
    within_day_var = ss
  )
  prepped$n_counts <- NULL

  expect_error(
    add_counts(make_wdv_design(raw), prepped, count_col = daily_effort, psu = "psu"),
    "requires an"
  )
})

test_that("counts with neither column still build a design (GH #109)", {
  # The wiring must not make the columns mandatory. A counts table that never
  # carried them is unaffected, and its within-day contribution stays 0.
  raw <- make_wdv_raw()
  per_day <- make_wdv_per_day(raw)
  prepped <- prep_counts_daily_effort(
    per_day,
    date = date,
    strata = day_type,
    effort_type = effort_type,
    daily_effort = mean_count
  )
  expect_false("within_day_var" %in% names(prepped))
  expect_false("n_counts" %in% names(prepped))

  d <- suppressMessages(add_counts(
    make_wdv_design(raw), prepped, count_col = daily_effort, psu = "psu"
  ))
  expect_null(d$within_day_var)
  expect_identical(compute_within_day_var_contribution(d), 0)
})

# GH #143: the party-size variance component on the prep path ------------------

# prep_counts_boat_party() performs the same boat -> angler expansion as
# derive_angler_count(), but wrote no expansion_* carriers and had no argument
# through which a party-size standard error could be supplied. The component
# was not omitted by default -- it was unreachable, and on the pipeline the
# documentation calls preferred, so the two documented routes to one expansion
# were not statistically equivalent and nothing said so.

bp_raw <- function() {
  data.frame(
    date = as.Date("2024-06-01") + 0:5,
    day_type = rep(c("weekday", "weekend"), 3),
    angler_boats = rep(4, 6),
    mps = 2.5,
    mps_se = 0.1,
    stringsAsFactors = FALSE
  )
}

bp_calendar <- function() {
  data.frame(
    date = as.Date("2024-06-01") + 0:5,
    day_type = rep(c("weekday", "weekend"), 3),
    stringsAsFactors = FALSE
  )
}

bp_effort <- function(counts, count_col) {
  design <- creel_design(bp_calendar(), date = date, strata = day_type)
  suppressWarnings(estimate_effort(
    suppressWarnings(add_counts(design, counts, count_col = count_col))
  ))
}

test_that("both documented routes to one expansion agree (GH #143)", {
  # The point of the issue: identical design, identical party size, identical
  # party-size SE, two documented entry points. Before this argument existed
  # the prep path reported the pre-3.2.0 understated SE with se_expansion NULL,
  # and no user action could change that.
  prep <- prep_counts_boat_party(
    bp_raw(),
    date = date,
    strata = day_type,
    boat_count = angler_boats,
    mean_party_size = mps,
    mean_party_size_se = mps_se
  )
  derived <- derive_angler_count(
    bp_raw(),
    boat_count = angler_boats,
    party_size = mps,
    party_size_se = mps_se
  )

  from_prep <- bp_effort(prep, "daily_effort")
  from_derive <- bp_effort(derived, "angler_count")

  expect_equal(from_prep$estimates$estimate, from_derive$estimates$estimate)
  expect_equal(from_prep$estimates$se, from_derive$estimates$se)
  expect_equal(from_prep$se_expansion, from_derive$se_expansion)
  expect_false(is.null(from_prep$se_expansion))
})

test_that("prep_counts_boat_party() emits all four carrier columns (GH #143)", {
  # All four or none: a proper subset cannot be produced by a writer, so
  # add_counts() treats one as evidence of partial deletion (GH #132).
  prep <- prep_counts_boat_party(
    bp_raw(),
    date = date,
    boat_count = angler_boats,
    mean_party_size = mps,
    mean_party_size_se = mps_se
  )
  expect_true(all(
    c("expansion_basis", "expansion_se", "expansion_group", "expansion_of") %in%
      names(prep)
  ))
})

test_that("the emitted basis includes the correction factor (GH #131, #143)", {
  # This function applies correction_factor to the product, so
  # d(daily_effort)/d(mean_party_size) is boat_count * correction_factor. A
  # basis of the bare boat count would be the derivative of a quantity this
  # function never produces, and add_counts() would be right to reject it as
  # desynchronised -- the exact hazard #131 added expansion_of to catch.
  prep <- prep_counts_boat_party(
    bp_raw(),
    date = date,
    strata = day_type,
    boat_count = angler_boats,
    mean_party_size = mps,
    mean_party_size_se = mps_se,
    correction_factor = 1.2
  )
  expect_equal(unique(prep$expansion_basis), 4 * 1.2)
  expect_equal(unique(prep$daily_effort), 4 * 2.5 * 1.2)
  expect_identical(unique(prep$expansion_of), "daily_effort")

  # And it survives the seam rather than merely being written: the component
  # is 4% of the total, matching the multiplier's own 0.1 / 2.5 relative error.
  effort <- bp_effort(prep, "daily_effort")
  expect_equal(
    effort$se_expansion / effort$estimates$estimate,
    0.1 / 2.5
  )
})

test_that("omitting the SE leaves the component absent, not zero (GH #143)", {
  # NULL is load-bearing: it distinguishes a component that was never
  # propagated from one measured as zero. Emitting carriers with se = 0 would
  # report the multiplier as exactly known.
  prep <- prep_counts_boat_party(
    bp_raw(),
    date = date,
    strata = day_type,
    boat_count = angler_boats,
    mean_party_size = mps
  )
  expect_false(any(c("expansion_basis", "expansion_se") %in% names(prep)))
  expect_null(bp_effort(prep, "daily_effort")$se_expansion)
})

test_that("an unknown party-size SE propagates as NA, not as absent (GH #143)", {
  # The third state: the component applies but could not be measured. It must
  # reach the estimator rather than being silently dropped to nothing.
  raw <- bp_raw()
  raw$mps_se <- NA_real_
  prep <- prep_counts_boat_party(
    raw,
    date = date,
    strata = day_type,
    boat_count = angler_boats,
    mean_party_size = mps,
    mean_party_size_se = mps_se
  )
  expect_true(all(is.na(prep$expansion_se)))
  expect_true(is.na(bp_effort(prep, "daily_effort")$se_expansion))
})

test_that("a negative party-size SE is refused (GH #143)", {
  raw <- bp_raw()
  raw$mps_se <- -0.1
  expect_error(
    prep_counts_boat_party(
      raw,
      date = date,
      boat_count = angler_boats,
      mean_party_size = mps,
      mean_party_size_se = mps_se
    ),
    "must not be negative"
  )
})

test_that("a scalar party-size SE is accepted alongside a column (GH #143)", {
  # Mirrors derive_angler_count(party_size_se = ), which takes either.
  prep <- prep_counts_boat_party(
    bp_raw(),
    date = date,
    boat_count = angler_boats,
    mean_party_size = mps,
    mean_party_size_se = 0.1
  )
  expect_equal(unique(prep$expansion_se), 0.1)
})
