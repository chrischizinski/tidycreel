# GH #442: counts at several sites inside a day.
#
# The expansion divides population DAYS (N_h, from the calendar) by sampled
# PSUs (n_h). Two ways that went wrong without an error:
#
#   1a. psu = <site-day>: n_h counted site-days, so with two sites per day every
#       weight was halved and the stratum total came out at half -- 90 where the
#       day-summed reference gives 180. The #183 defect, reached through `psu`.
#   1b. A day with one of its two sites counted was summed over the site it had
#       and expanded as a complete day: the missing site's unknown effort read
#       as zero (66 where sites drawn at p = 0.5 would give 132).
#
# Both are refused for the expanded targets; `sampled_days` (the total over the
# counted units) is unaffected. The fixture is one stratum of 8 days, 4 sampled,
# so the reference is not a census (SE > 0) and a factor-of-two error is
# visible in the point estimate.

sdp_calendar <- function() {
  data.frame(date = as.Date("2024-06-01") + 0:7, day_type = "weekday")
}

sdp_full_counts <- function() {
  cal <- sdp_calendar()
  cn <- data.frame(
    date = rep(cal$date[1:4], each = 2), day_type = "weekday",
    site = rep(c("A", "B"), 4), count = c(10, 12, 14, 8, 9, 11, 20, 6)
  )
  cn$site_day <- paste(cn$site, cn$date)
  cn
}

sdp_design <- function(cal = sdp_calendar()) {
  suppressWarnings(suppressMessages(creel_design(cal, date = date, strata = day_type))) # nolint: object_usage_linter
}

sdp_add <- function(design, counts, ...) {
  suppressWarnings(suppressMessages(add_counts(design, counts, count_col = count, ...))) # nolint: object_usage_linter
}

sdp_total <- function(design, target = "stratum_total") {
  suppressWarnings(suppressMessages(estimate_effort(design, target = target)))$estimates # nolint: object_usage_linter
}

sdp_reference <- function() {
  # Day as PSU, the two sites summed into each day by hand: 180 over 8 days.
  agg <- stats::aggregate(count ~ date + day_type, sdp_full_counts(), sum)
  sdp_total(sdp_add(sdp_design(), agg))
}

test_that("#442: the day-summed reference is not a census, so it can discriminate", {
  ref <- sdp_reference()
  expect_equal(ref$estimate, 180)
  expect_gt(ref$se, 0)
})

test_that("#442: a site-day PSU is refused for the expanded targets", {
  d <- sdp_add(sdp_design(), sdp_full_counts(), psu = "site_day")
  expect_error(sdp_total(d, "stratum_total"), class = "creel_error_psu_finer_than_day")
  expect_error(sdp_total(d, "period_total"), class = "creel_error_psu_finer_than_day")
})

test_that("#442: the site-day PSU's sampled_days total is still the sum of what was counted", {
  d <- sdp_add(sdp_design(), sdp_full_counts(), psu = "site_day")
  expect_equal(sdp_total(d, "sampled_days")$estimate, sum(sdp_full_counts()$count))
})

test_that("#442: the route the refusal points to gives the day-summed answer", {
  # unit_cols = c(date, site) sums the sites into the day before expanding, so
  # it must match the reference exactly -- not the 90 the site-day PSU gave.
  d <- sdp_add(sdp_design(), sdp_full_counts(), unit_cols = c("date", "site"))
  got <- sdp_total(d)
  ref <- sdp_reference()
  expect_equal(got$estimate, ref$estimate)
  expect_equal(got$se, ref$se)
})

test_that("#442: a sampled day missing a site counted on other days is refused", {
  half <- sdp_full_counts()[c(1, 4, 5, 8), ]
  d <- sdp_add(sdp_design(), half, unit_cols = c("date", "site"))
  expect_error(sdp_total(d, "stratum_total"), class = "creel_error_partial_unit_coverage")
  expect_error(sdp_total(d, "period_total"), class = "creel_error_partial_unit_coverage")
  expect_error(
    suppressWarnings(audit_strata(d)), # nolint: object_usage_linter
    class = "creel_error_partial_unit_coverage"
  )
  # The counted units' own total is still available, and labelled as such.
  expect_equal(sdp_total(d, "sampled_days")$estimate, sum(half$count))
})

test_that("#442: one missing site on one day is enough, and the message names it", {
  cn <- sdp_full_counts()[-4, ] # 2024-06-02 has site A only
  d <- sdp_add(sdp_design(), cn, unit_cols = c("date", "site"))
  err <- expect_error(sdp_total(d), class = "creel_error_partial_unit_coverage")
  expect_match(conditionMessage(err), "2024-06-02: no site=B", fixed = TRUE)
  expect_no_match(conditionMessage(err), "2024-06-01", fixed = TRUE)
})

test_that("#442: a recorded zero is a count, so a day with it is complete", {
  # The user's fix for a site counted and found empty: an explicit 0 row. The
  # total is then the reference with that site's count replaced by 0.
  cn <- sdp_full_counts()
  cn$count[4] <- 0
  d <- sdp_add(sdp_design(), cn, unit_cols = c("date", "site"))
  agg <- stats::aggregate(count ~ date + day_type, cn, sum)
  expect_equal(sdp_total(d)$estimate, sdp_total(sdp_add(sdp_design(), agg))$estimate)
})

test_that("#442: sites are expected per stratum, not across the season", {
  # Site B only operates on weekends: a weekday without B is complete.
  cal <- data.frame(
    date = as.Date("2024-06-01") + 0:7,
    day_type = rep(c("weekday", "weekend"), each = 4)
  )
  cn <- data.frame(
    date = cal$date[c(1, 2, 5, 5, 6, 6)],
    day_type = cal$day_type[c(1, 2, 5, 5, 6, 6)],
    site = c("A", "A", "A", "B", "A", "B"),
    count = c(10, 12, 20, 5, 18, 7)
  )
  d <- sdp_add(sdp_design(cal), cn, unit_cols = c("date", "site"))
  expect_equal(sdp_total(d)$estimate, 4 / 2 * 22 + 4 / 2 * 50)
})

test_that("#442: unit_cols without the PSU is refused", {
  # The same site on two days would read as one sampling unit.
  expect_error(
    sdp_add(sdp_design(), sdp_full_counts(), unit_cols = "site"),
    class = "creel_error_invalid_input"
  )
})

test_that("#442: the repeated-unit hint keeps the existing key in its unit_cols advice", {
  cn <- sdp_full_counts()
  cn$site_day <- NULL
  d <- sdp_add(sdp_design(), cn)
  err <- expect_error(sdp_total(d), class = "creel_error_repeated_psus")
  expect_match(conditionMessage(err), 'unit_cols = c("date"', fixed = TRUE)
})

test_that("#442: creel_design() refuses a calendar day with no stratum", {
  cal <- data.frame(
    date = as.Date("2024-06-01") + 0:5,
    day_type = c("wd", "wd", "wd", "we", "we", NA)
  )
  err <- expect_error(
    creel_design(cal, date = date, strata = day_type), # nolint: object_usage_linter
    class = "creel_error_strata_missing"
  )
  expect_match(conditionMessage(err), "2024-06-06", fixed = TRUE)
})

test_that("#442: a unit seen on one day only is not expected on the others", {
  # Per-day labels are allowed (#373), and a label seen once cannot be told from
  # one. Site C on day 1 alone does not make days 2-4 incomplete.
  cn <- sdp_full_counts()
  cn$site_day <- NULL
  cn <- rbind(cn, data.frame(date = cn$date[1], day_type = "weekday", site = "C", count = 3))
  d <- sdp_add(sdp_design(), cn, unit_cols = c("date", "site"))
  expect_equal(sdp_total(d)$estimate, 8 / 4 * sum(cn$count))
})
