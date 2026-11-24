# A trip filter estimates a domain, not a smaller survey (GH #663) ----
#
# Interviews are clustered on the survey day (GH #661). Restricting them to one
# trip type -- complete trips, incomplete trips, trips under a truncation
# length -- used to rebuild the survey on the rows that survived, so a day that
# was interviewed but had no trips of that type dropped out of the design. It
# was sampled: it is an observation of zero catch and zero effort in the
# domain, and the between-day variance has to count it (Cochran 1977, s. 2.13,
# domain estimation; Lumley 2010, s. 2.3, subsetting a survey keeps its design).
#
# The references below are computed in base R from the definitions, sharing no
# tidycreel or survey code.

dom_calendar <- function() {
  data.frame(
    date = as.Date("2024-06-03") + c(0:4, 7:11),
    day_type = rep(c("weekday", "weekend"), each = 5),
    stringsAsFactors = FALSE
  )
}

# 6 parties a day; `rate_by_day` sets each day's catch rate.
dom_interviews <- function(dates, status, rate_by_day) {
  n_per <- 6L
  effort <- rep(c(2, 3, 4, 2.5, 3.5, 1.5), times = length(dates))
  jitter <- rep(c(-0.3, 0.2, 0.1, -0.1, 0.25, -0.15), times = length(dates))
  rate <- rep(rate_by_day, each = n_per) + jitter
  data.frame(
    date = rep(dates, each = n_per),
    catch_total = rate * effort,
    hours_fished = effort,
    trip_status = status,
    trip_duration = effort,
    stringsAsFactors = FALSE
  )
}

dom_design <- function(interviews, cal = dom_calendar()) {
  suppressMessages(suppressWarnings(add_interviews(
    creel_design(cal, date = date, strata = day_type), # nolint: object_usage_linter
    interviews,
    catch = catch_total, # nolint: object_usage_linter
    effort = hours_fished, # nolint: object_usage_linter
    trip_status = trip_status, # nolint: object_usage_linter
    trip_duration = trip_duration # nolint: object_usage_linter
  )))
}

# Per-day totals of a linearization score, with every interviewed day present.
# Days without domain rows contribute a score of 0.
dom_day_scores <- function(score, day, stratum, all_days, all_strata) {
  z <- tapply(score, day, sum)
  out <- stats::setNames(numeric(length(all_days)), all_days)
  out[names(z)] <- z
  split(out, all_strata)
}

dom_taylor_se <- function(score_by_stratum) {
  v <- 0
  for (zt in score_by_stratum) {
    n <- length(zt)
    v <- v + n / (n - 1) * sum((zt - mean(zt))^2)
  }
  sqrt(v)
}

# Linearized SE of the combined ratio sum(y) / sum(x) over the domain rows.
dom_ratio_se <- function(y, x, day, all_days, all_strata) {
  r <- sum(y) / sum(x)
  dom_taylor_se(dom_day_scores((y - r * x) / sum(x), day, NULL, all_days, all_strata))
}

test_that("DOM-01 (#663): a complete-trip rate counts the interviewed days with no complete trips", {
  # Weekdays interviewed on all 5 days, complete trips on 3 of them; weekends
  # on 3 days, complete trips on 2. The rebuilt survey saw 3 + 2 days; the
  # design sampled 5 + 3.
  cal <- dom_calendar()
  iv <- rbind(
    dom_interviews(cal$date[1:3], "complete", c(1.0, 1.6, 0.8)),
    dom_interviews(cal$date[4:5], "incomplete", c(1.2, 1.4)),
    dom_interviews(cal$date[6:7], "complete", c(2.0, 1.1)),
    dom_interviews(cal$date[8], "incomplete", 0.9)
  )
  # The hand reference is the interview survey's domain variance with unit
  # weights: what is tested is which days enter it. The effort weighting of a
  # rate pooled across strata (GH #691) sits on top and is tested with this
  # fixture in test-statistical-audit-pooled-strata.R.
  result <- without_rate_pooling(suppressMessages(suppressWarnings(estimate_catch_rate(dom_design(iv))))) # nolint: object_usage_linter

  cp <- iv[iv$trip_status == "complete", ]
  days <- as.character(cal$date[1:8])
  strata <- rep(c("weekday", "weekend"), c(5, 3))
  domain <- dom_ratio_se(cp$catch_total, cp$hours_fished, as.character(cp$date), days, strata)
  rebuilt <- dom_ratio_se(
    cp$catch_total, cp$hours_fished, as.character(cp$date),
    unique(as.character(cp$date)), rep(c("weekday", "weekend"), c(3, 2))
  )

  expect_equal(result$estimates$estimate, sum(cp$catch_total) / sum(cp$hours_fished), tolerance = 1e-12)
  expect_equal(result$estimates$se, domain, tolerance = 1e-10)
  # The rebuilt value is the one #663 replaced; it has to differ here or this
  # test could not tell the two apart.
  expect_false(isTRUE(all.equal(domain, rebuilt, tolerance = 1e-3)))
  # n is still the trips the rate was built from, not the days restored.
  expect_identical(result$estimates$n, nrow(cp))
})

test_that("DOM-02 (#663): the jackknife deletes every interviewed day, not only the days with complete trips", {
  # Replicates drawn from the filtered rows alone would miss the restored
  # days; survey's default row subset drops them, and Taylor alone still
  # counts them, so only a replicate method can tell.
  cal <- dom_calendar()
  wk <- cal$date[1:5]
  iv <- rbind(
    dom_interviews(wk[1:3], "complete", c(1.0, 1.6, 0.8)),
    dom_interviews(wk[4:5], "incomplete", c(1.2, 1.4))
  )
  cal <- cal[1:5, ]
  result <- suppressMessages(suppressWarnings( # nolint: object_usage_linter
    estimate_catch_rate(dom_design(iv, cal), variance = "jackknife")
  ))

  # Delete-one-day jackknife (JKn, one stratum): a deleted day without complete
  # trips leaves the ratio unchanged, but it still counts in n.
  cp <- iv[iv$trip_status == "complete", ]
  y <- tapply(cp$catch_total, as.character(cp$date), sum)
  x <- tapply(cp$hours_fished, as.character(cp$date), sum)
  theta <- sum(y) / sum(x)
  theta_del <- c((sum(y) - y) / (sum(x) - x), rep(theta, 2))
  n <- 5
  jk <- sqrt((n - 1) / n * sum((theta_del - theta)^2))
  n_r <- 3
  jk_rebuilt <- sqrt((n_r - 1) / n_r * sum((theta_del[1:3] - theta)^2))

  expect_equal(result$estimates$se, jk, tolerance = 1e-10)
  expect_false(isTRUE(all.equal(jk, jk_rebuilt, tolerance = 1e-3)))
})

test_that("DOM-03 (#663): complete trips on one day of a multi-day stratum are a domain, not a one-day stratum", {
  # Before #663 the rebuilt weekend stratum held one day and was refused by
  # name. It was interviewed on three; the domain is estimable.
  cal <- dom_calendar()
  iv <- rbind(
    dom_interviews(cal$date[1:3], "complete", c(1.0, 1.6, 0.8)),
    dom_interviews(cal$date[6], "complete", 2.0),
    dom_interviews(cal$date[7:8], "incomplete", c(1.1, 0.9))
  )
  # The hand reference is the interview survey's domain variance with unit
  # weights: what is tested is which days enter it. The effort weighting of a
  # rate pooled across strata (GH #691) sits on top and is tested with this
  # fixture in test-statistical-audit-pooled-strata.R.
  result <- without_rate_pooling(suppressMessages(suppressWarnings(estimate_catch_rate(dom_design(iv))))) # nolint: object_usage_linter

  cp <- iv[iv$trip_status == "complete", ]
  days <- as.character(c(cal$date[1:3], cal$date[6:8]))
  domain <- dom_ratio_se(cp$catch_total, cp$hours_fished, as.character(cp$date), days, rep(c("weekday", "weekend"), c(3, 3)))
  expect_equal(result$estimates$se, domain, tolerance = 1e-10)
  expect_gt(result$estimates$se, 1e-6)
})

test_that("DOM-04 (#663): a trip set met on one day in all is refused, not given se = 0", {
  # One weekday of complete trips, the other days incomplete only. Every day's
  # ratio score is exactly 0 -- the one day holds the whole domain -- so the SE
  # would be 0 under any method.
  cal <- dom_calendar()[1:5, ]
  one <- dom_interviews(cal$date[1], "complete", 1.0)
  iv <- rbind(one, one, dom_interviews(cal$date[2:5], "incomplete", c(1.2, 1.4, 0.9, 1.1)))
  design <- dom_design(iv, cal)
  for (v in c("taylor", "bootstrap", "jackknife")) {
    err <- expect_error(
      suppressMessages(suppressWarnings(estimate_catch_rate(design, variance = v))), # nolint: object_usage_linter
      class = "creel_error_single_psu"
    )
    expect_match(conditionMessage(err), "all come from one day", fixed = TRUE)
  }
})

test_that("DOM-05 (#663): an incomplete-trip mean of ratios counts the days with no incomplete trips", {
  cal <- dom_calendar()[1:5, ]
  iv <- rbind(
    dom_interviews(cal$date[1:3], "incomplete", c(1.0, 1.6, 0.8)),
    dom_interviews(cal$date[4:5], "complete", c(1.2, 1.4))
  )
  result <- suppressMessages(suppressWarnings(estimate_catch_rate( # nolint: object_usage_linter
    dom_design(iv, cal),
    estimator = "mor", use_trips = "incomplete"
  )))

  inc <- iv[iv$trip_status == "incomplete", ]
  r <- inc$catch_total / inc$hours_fished
  score <- (r - mean(r)) / length(r)
  domain <- dom_taylor_se(dom_day_scores(score, as.character(inc$date), NULL, as.character(cal$date), rep("weekday", 5)))

  expect_equal(result$estimates$estimate, mean(r), tolerance = 1e-12)
  expect_equal(result$estimates$se, domain, tolerance = 1e-10)
})

test_that("DOM-06 (#663): a species' targeted rate counts the days no trip caught it", {
  # `targeted = FALSE` keeps the trips that caught bass. Bass were caught only
  # on 2024-06-01 and 2024-06-08, one day in each stratum; the other two days
  # were interviewed and are zero-bass days of the domain.
  dates <- as.Date(c("2024-06-01", "2024-06-02", "2024-06-08", "2024-06-09"))
  cal <- data.frame(date = dates, day_type = rep(c("weekday", "weekend"), each = 2), stringsAsFactors = FALSE)
  n <- 48L
  date <- rep(dates, length.out = n)
  hours <- 1 + (seq_len(n) - 1L) * 0.05
  bass <- ifelse(date %in% dates[c(1, 3)], seq_len(n) %% 4L + 1L, 0L)
  panfish <- rep(c(1L, 2L, 3L), length.out = n)
  interviews <- data.frame(
    interview_id = seq_len(n), date = date, catch_total = bass + panfish,
    hours_fished = hours, trip_status = "incomplete", trip_duration = hours,
    stringsAsFactors = FALSE
  )
  caught <- bass > 0
  catch <- rbind(
    data.frame(interview_id = seq_len(n), species = "panfish", count = panfish, catch_type = "caught"),
    data.frame(interview_id = which(caught), species = "bass", count = bass[caught], catch_type = "caught")
  )
  design <- suppressMessages(suppressWarnings(add_catch( # nolint: object_usage_linter
    dom_design(interviews, cal), catch,
    catch_uid = interview_id, interview_uid = interview_id, # nolint: object_usage_linter
    species = species, count = count, catch_type = catch_type # nolint: object_usage_linter
  )))
  # Hand reference: the interview survey's domain variance, unit weights;
  # the effort weighting across strata (GH #691) is tested elsewhere.
  result <- without_rate_pooling(suppressMessages(suppressWarnings(estimate_catch_rate( # nolint: object_usage_linter
    design,
    by = species, estimator = "mor", use_trips = "incomplete", targeted = FALSE
  ))))$estimates
  got <- result[result$species == "bass", ]

  r <- bass[caught] / hours[caught]
  score <- (r - mean(r)) / length(r)
  domain <- dom_taylor_se(dom_day_scores(
    score, as.character(date[caught]), NULL, as.character(dates), cal$day_type
  ))
  expect_equal(got$estimate, mean(r), tolerance = 1e-12)
  expect_equal(got$se, domain, tolerance = 1e-10)
})

test_that("DOM-07 (#663): a section's rate is estimated over that section's own days", {
  # Found in review: the ungrouped sectioned release path read the whole
  # design's days, so a day interviewed only in the other section was put back
  # into this section as a zero day. The fixture's sections are interviewed on
  # different days (North has none on 2024-06-07), so the two universes differ.
  design <- make_sectioned_species_design()
  section_col <- design$section_col
  for (f in c("estimate_catch_rate", "estimate_harvest_rate", "estimate_release_rate")) {
    sectioned <- suppressMessages(suppressWarnings(get(f)(design)))$estimates
    for (sec in c("North", "South")) {
      sub <- design
      sub$sections <- NULL
      sub$interviews <- design$interviews[design$interviews[[section_col]] == sec, ]
      # The section's own counts: across day types a section's rate is
      # weighted by that section's effort (GH #691).
      sub$counts <- design$counts[design$counts[[section_col]] == sec, ]
      sub <- rebuild_interview_survey(sub, sub$interviews) # nolint: object_usage_linter
      reference <- suppressMessages(suppressWarnings(get(f)(sub)))$estimates
      got <- sectioned[sectioned[[section_col]] == sec, ]
      expect_equal(got$estimate, reference$estimate, tolerance = 1e-12, info = paste(f, sec))
      expect_equal(got$se, reference$se, tolerance = 1e-12, info = paste(f, sec))
    }
  }
})

dom_species_design <- function() {
  # Bass caught only on 2024-06-01 and 2024-06-08, one day in each stratum.
  dates <- as.Date(c("2024-06-01", "2024-06-02", "2024-06-08", "2024-06-09"))
  cal <- data.frame(date = dates, day_type = rep(c("weekday", "weekend"), each = 2), stringsAsFactors = FALSE)
  n <- 48L
  date <- rep(dates, length.out = n)
  hours <- 1 + (seq_len(n) - 1L) * 0.05
  bass <- ifelse(date %in% dates[c(1, 3)], seq_len(n) %% 4L + 1L, 0L)
  panfish <- rep(c(1L, 2L, 3L), length.out = n)
  interviews <- data.frame(
    interview_id = seq_len(n), date = date, catch_total = bass + panfish,
    hours_fished = hours, trip_status = "incomplete", trip_duration = hours,
    stringsAsFactors = FALSE
  )
  caught <- bass > 0
  catch <- rbind(
    data.frame(interview_id = seq_len(n), species = "panfish", count = panfish, catch_type = "caught"),
    data.frame(interview_id = which(caught), species = "bass", count = bass[caught], catch_type = "caught")
  )
  design <- suppressMessages(suppressWarnings(add_catch( # nolint: object_usage_linter
    dom_design(interviews, cal), catch,
    catch_uid = interview_id, interview_uid = interview_id, # nolint: object_usage_linter
    species = species, count = count, catch_type = catch_type # nolint: object_usage_linter
  )))
  list(design = design, cal = cal, date = date, hours = hours, bass = bass)
}

test_that("DOM-08 (#663): a species filter that comes first still keeps every interviewed day", {
  # Found in review: with use_trips = "all" no trip filter runs before the
  # species' targeted filter, so nothing had recorded the design's days, and
  # the MOR build downstream re-read them from the filtered rows.
  fx <- dom_species_design()
  # Hand reference: the interview survey's domain variance, unit weights;
  # the effort weighting across strata (GH #691) is tested elsewhere.
  result <- without_rate_pooling(suppressMessages(suppressWarnings(estimate_catch_rate( # nolint: object_usage_linter
    fx$design,
    by = species, estimator = "mor", use_trips = "all", targeted = FALSE
  ))))$estimates
  got <- result[result$species == "bass", ]
  caught <- fx$bass > 0
  r <- fx$bass[caught] / fx$hours[caught]
  domain <- dom_taylor_se(dom_day_scores(
    (r - mean(r)) / length(r), as.character(fx$date[caught]), NULL, as.character(fx$cal$date), fx$cal$day_type
  ))
  expect_equal(got$estimate, mean(r), tolerance = 1e-12)
  expect_equal(got$se, domain, tolerance = 1e-10)
})

test_that("DOM-09 (#663): MOR truncation that empties a day keeps that day", {
  # Found in review: on use_trips = "all" the truncation is the first filter.
  # Every trip on 2024-06-07 is shorter than truncate_at.
  cal <- dom_calendar()[1:5, ]
  iv <- dom_interviews(cal$date, "incomplete", c(1.0, 1.6, 0.8, 1.2, 1.4))
  iv$trip_duration[iv$date == cal$date[5]] <- 0.25
  result <- suppressMessages(suppressWarnings(estimate_catch_rate( # nolint: object_usage_linter
    dom_design(iv, cal),
    estimator = "mor", use_trips = "all", truncate_at = 0.5
  )))$estimates
  kept <- iv[iv$trip_duration >= 0.5, ]
  r <- kept$catch_total / kept$hours_fished
  domain <- dom_taylor_se(dom_day_scores(
    (r - mean(r)) / length(r), as.character(kept$date), NULL, as.character(cal$date), rep("weekday", 5)
  ))
  expect_equal(result$estimate, mean(r), tolerance = 1e-12)
  expect_equal(result$se, domain, tolerance = 1e-10)
})
