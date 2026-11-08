# GH #504: with one count per sampled day the count-sampling SE is still right,
# and it is all in se_between, but the within-day part cannot be estimated on
# its own -- there is nothing to estimate it from. Reporting se_within = 0 said
# "measured, and there is none". se_within is now NA where it is not
# identified; se and se_between are unchanged. se_between is kept because on a
# design with a party-size or calibration term it is the only reported
# count-sampling SE.

one_count_design <- function() {
  cal <- data.frame(
    date = as.Date("2024-06-01") + 0:3,
    day_type = rep(c("weekday", "weekend"), each = 2)
  )
  cnt <- data.frame(
    date = cal$date, day_type = cal$day_type,
    n_anglers = c(15L, 23L, 45L, 52L), hrs = 10
  )
  suppressWarnings(add_counts(
    creel_design(cal, date = date, strata = day_type), cnt,
    period_length_col = hrs
  ))
}

# weekday: three days with two counts each (within-day identified);
# weekend: three days with one count (not identified).
mixed_design <- function() {
  cal <- data.frame(
    date = as.Date("2024-06-01") + 0:7,
    day_type = rep(c("weekday", "weekend"), each = 4)
  )
  cnt <- rbind(
    data.frame(
      date = rep(cal$date[1:3], each = 2), day_type = "weekday",
      t = rep(1:2, 3), n_anglers = c(10, 14, 20, 18, 15, 9), hrs = 10
    ),
    data.frame(
      date = cal$date[5:7], day_type = "weekend", t = 1,
      n_anglers = c(40, 52, 47), hrs = 10
    )
  )
  suppressWarnings(add_counts(
    creel_design(cal, date = date, strata = day_type), cnt,
    count_time_col = t, period_length_col = hrs
  ))
}

test_that("one count per day: se_within is NA and se_between is the whole count-sampling SE", {
  d <- one_count_design()
  for (target in c("period_total", "stratum_total", "sampled_days")) {
    reported <- suppressWarnings(estimate_effort(d, target = target))$estimates
    internal <- estimate_effort_total(d, "taylor", 0.95, target = target)$estimates
    expect_identical(reported$se_basis, "between_day_upper_bound")
    expect_true(is.na(reported$se_within))
    # se and se_between are not touched: they are the day-to-day SE survey
    # computed, which already contains the within-day variation.
    expect_equal(reported$se, internal$se_between)
    expect_equal(reported$se_between, internal$se_between)
    expect_true(is.finite(reported$se))
  }
})

test_that("grouped: only the rows that cannot identify the within-day term go NA", {
  est <- suppressWarnings(estimate_effort(mixed_design(), by = day_type))$estimates
  wk <- est[est$day_type == "weekday", ]
  we <- est[est$day_type == "weekend", ]

  expect_identical(wk$se_basis, "two_stage")
  expect_true(wk$se_within > 0)
  expect_equal(wk$se^2, wk$se_between^2 + wk$se_within^2)

  expect_identical(we$se_basis, "between_day_upper_bound")
  expect_true(is.na(we$se_within))
  expect_equal(we$se, we$se_between)
  expect_true(is.finite(we$se))
})

test_that("a mixed row keeps its split: the identified strata's within-day term is a number", {
  est <- suppressWarnings(estimate_effort(mixed_design()))$estimates
  expect_identical(est$se_basis, "mixed")
  expect_true(est$se_within > 0)
  expect_equal(est$se^2, est$se_between^2 + est$se_within^2)
})

test_that("sectioned: se_within goes NA on every row but the lake se, built from it, does not", {
  sections_df <- data.frame(section = c("North", "Central", "South"))
  counts <- prep_counts_daily_effort(example_sections_counts,
    date = date, strata = day_type, daily_effort = effort_hours,
    section = section
  )
  d <- creel_design(example_sections_calendar, date = date, strata = day_type)
  d <- add_sections(d, sections_df, section_col = section)
  d <- suppressWarnings(add_counts(d, counts))

  reported <- suppressWarnings(estimate_effort(d))$estimates
  # The lake row sums each section's se_within internally; a one-count
  # section's true 0 there must not become an NA that wipes the lake se.
  internal <- suppressWarnings(estimate_effort_sections(
    d, "taylor", 0.95, TRUE, "correlated", "warn",
    target = "period_total"
  ))$estimates

  expect_true(all(reported$se_basis == "between_day_upper_bound"))
  expect_true(all(is.na(reported$se_within)))
  expect_equal(reported$se, internal$se)
  expect_equal(reported$se_between, internal$se_between)
  expect_true(all(is.finite(reported$se)))
})

test_that("aerial: the within_day component is folded into count_sampling", {
  cal <- data.frame(
    date = example_aerial_counts$date,
    day_type = example_aerial_counts$day_type
  )
  d <- creel_design(cal,
    date = date, strata = day_type, survey_type = "aerial",
    visibility_correction = 0.8, angler_ratio = 1, angler_ratio_se = 0,
    h_open = 14
  )
  d <- suppressWarnings(add_counts(d, example_aerial_counts))
  res <- suppressWarnings(estimate_effort(d))

  expect_identical(res$estimates$se_basis, "between_day_upper_bound")
  expect_true(is.na(res$estimates$se_within))
  # NA in se_components means "unknown, so se is NA" to print(), and 0 would
  # read as measured; it is inside count_sampling, which is the whole
  # count-sampling SE, as se_between is.
  expect_false("within_day" %in% names(res$se_components))
  expect_equal(res$se_components$count_sampling, res$estimates$se_between)
  expect_true(is.finite(res$estimates$se))
})

test_that("grouped aerial with mixed rows: no 0 within_day for the one-flight group", {
  # Weekday flown twice a day, weekend once.
  cal <- data.frame(
    date = as.Date("2024-06-03") + 0:9,
    day_type = rep(c("weekday", "weekend"), each = 5)
  )
  cnt <- rbind(
    data.frame(
      date = rep(cal$date[1:3], each = 2), day_type = "weekday",
      flight = rep(1:2, 3), n_anglers = c(10, 16, 22, 18, 12, 9)
    ),
    data.frame(
      date = cal$date[6:8], day_type = "weekend", flight = 1L,
      n_anglers = c(40, 52, 47)
    )
  )
  d <- creel_design(cal,
    date = date, strata = day_type, survey_type = "aerial",
    visibility_correction = 0.8, visibility_se = 0.05,
    angler_ratio = 1, angler_ratio_se = 0, h_open = 12
  )
  d <- suppressWarnings(add_counts(d, cnt, count_time_col = flight))
  res <- suppressWarnings(estimate_effort(d, by = day_type))
  est <- res$estimates
  wk <- est$day_type == "weekday"

  expect_identical(est$se_basis[!wk], "between_day_upper_bound")
  expect_true(is.na(est$se_within[!wk]))
  expect_true(est$se_within[wk] > 0)
  expect_false("within_day" %in% names(res$se_components))
  # Every row's count-sampling component is its whole count-sampling SE: the
  # day-to-day and within-day terms where both exist, se_between alone where
  # the within-day term is inside it.
  expect_equal(
    res$se_components$count_sampling[wk],
    sqrt(est$se_between[wk]^2 + est$se_within[wk]^2)
  )
  expect_equal(res$se_components$count_sampling[!wk], est$se_between[!wk])
  expect_true(all(is.finite(est$se)))
})

test_that("a party-size expansion keeps the count-sampling SE beside it", {
  # The reason se_between is not masked with se_within: here se has a second
  # term, and se_between is the only reported count-sampling SE.
  cal <- data.frame(
    date = as.Date("2024-06-01") + 0:5,
    day_type = rep(c("weekday", "weekend"), each = 3)
  )
  cnt <- data.frame(
    date = cal$date[c(1, 2, 4, 5)],
    day_type = cal$day_type[c(1, 2, 4, 5)],
    n_boats = c(4, 6, 9, 11), hrs = 10
  )
  cnt <- derive_angler_count(cnt,
    boat_count = n_boats, party_size = 2.4,
    party_size_se = 0.2
  )
  d <- suppressWarnings(add_counts(
    creel_design(cal, date = date, strata = day_type), cnt,
    period_length_col = hrs
  ))
  res <- suppressWarnings(estimate_effort(d))
  est <- res$estimates
  expect_identical(est$se_basis, "between_day_upper_bound")
  expect_true(is.na(est$se_within))
  expect_true(is.finite(est$se_between))
  expect_equal(est$se^2, est$se_between^2 + res$se_expansion^2)
})
