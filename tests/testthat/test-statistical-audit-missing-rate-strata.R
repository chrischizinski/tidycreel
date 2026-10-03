# A total is effort x rate summed over the strata (and `by` cells) that carry
# effort. A cell with effort but no rate -- no interviews, or only incomplete
# trips -- has an UNKNOWN catch. `compute_stratum_product_sum()` inner-merged
# effort onto rates, so such a cell dropped out of the sum: its catch became
# zero and the result read as the season total (GH #373, part 2). On the package
# example with no complete weekend trips, the ungrouped total was the weekday
# catch alone -- 54% of the season's effort left out -- and `by = day_type`
# returned no weekend row at all.
#
# An unknown is the user's to resolve, never dropped by default: the totals now
# refuse, and `missing_rate = "exclude"` is the explicit opt-in that reports a
# total over the covered cells and records what it left out.

mrs_design <- function(drop_weekend_bank = FALSE, weekend_incomplete = TRUE) {
  data(example_counts, package = "tidycreel")
  data(example_calendar, package = "tidycreel")
  data(example_interviews, package = "tidycreel")
  data(example_catch, package = "tidycreel")
  weekend <- example_counts$date[example_counts$day_type == "weekend"]
  iv <- example_interviews
  if (weekend_incomplete) {
    iv$trip_status[iv$date %in% weekend] <- "incomplete"
  }
  if (drop_weekend_bank) {
    iv <- iv[!(iv$date %in% weekend & iv$angler_type == "bank"), ]
  }
  d <- suppressMessages(creel_design(example_calendar, date = date, strata = day_type)) # nolint: object_usage_linter
  d <- suppressWarnings(suppressMessages(add_counts(d, example_counts)))
  d <- suppressWarnings(suppressMessages(add_interviews(
    d, iv,
    catch = catch_total, harvest = catch_kept, effort = hours_fished, # nolint: object_usage_linter
    n_anglers = n_anglers, trip_status = trip_status, trip_duration = trip_duration # nolint: object_usage_linter
  )))
  catch <- example_catch[example_catch$interview_id %in% iv$interview_id, ]
  suppressWarnings(suppressMessages(add_catch(
    d, catch,
    catch_uid = interview_id, interview_uid = interview_id, # nolint: object_usage_linter
    species = species, count = count, catch_type = catch_type # nolint: object_usage_linter
  )))
}

# Long form by angler type, so a stratum x type cell can be uncovered while both
# of its margins are covered.
mrs_type_design <- function() {
  data(example_counts, package = "tidycreel")
  data(example_calendar, package = "tidycreel")
  data(example_interviews, package = "tidycreel")
  bank <- example_counts
  bank$angler_type <- "bank"
  boat <- example_counts
  boat$angler_type <- "boat"
  boat$effort_hours <- boat$effort_hours * 2
  weekend <- example_counts$date[example_counts$day_type == "weekend"]
  iv <- example_interviews[!(example_interviews$date %in% weekend &
    example_interviews$angler_type == "bank"), ]
  d <- suppressMessages(creel_design(example_calendar, date = date, strata = day_type)) # nolint: object_usage_linter
  d <- suppressWarnings(suppressMessages(add_counts(
    d, rbind(bank, boat),
    unit_cols = c("date", "day_type", "angler_type")
  )))
  suppressWarnings(suppressMessages(add_interviews(
    d, iv,
    catch = catch_total, harvest = catch_kept, effort = hours_fished, # nolint: object_usage_linter
    n_anglers = n_anglers, trip_status = trip_status, trip_duration = trip_duration # nolint: object_usage_linter
  )))
}

quiet <- function(expr) suppressWarnings(suppressMessages(expr))

test_that("#373: a stratum with effort and no rate stops every total by default", {
  d <- mrs_design()
  # All three near-twins share the merge, so all three must refuse. Before the
  # fix each returned the weekday product as the season total.
  expect_error(quiet(estimate_total_catch(d)), class = "creel_error_missing_rate_strata")
  expect_error(quiet(estimate_total_harvest(d)), class = "creel_error_missing_rate_strata")
  expect_error(quiet(estimate_total_release(d)), class = "creel_error_missing_rate_strata")
  # Grouped and species paths reach the same merge.
  expect_error(
    quiet(estimate_total_catch(d, by = day_type)),
    class = "creel_error_missing_rate_strata"
  )
  expect_error(
    quiet(estimate_total_catch(d, by = species)),
    class = "creel_error_missing_rate_strata"
  )
})

test_that("#373: the refusal names the uncovered cell and its share of effort", {
  err <- tryCatch(
    quiet(estimate_total_catch(mrs_design())),
    creel_error_missing_rate_strata = function(e) e
  )
  msg <- conditionMessage(err)
  expect_match(msg, "weekend")
  # 201.9 of 372.5 effort units: the share is what tells a user whether this is
  # a corner or most of the season.
  expect_match(msg, "54.2%", fixed = TRUE)
  expect_match(msg, "missing_rate", fixed = TRUE)
})

test_that("#373: a stratum x by cell with no rate stops a grouped total", {
  # Bank anglers on weekends have effort but no interviews, while bank and
  # weekend are each covered elsewhere. The cell, not a margin, is unknown.
  expect_error(
    quiet(estimate_total_catch(mrs_type_design(), by = angler_type)),
    class = "creel_error_missing_rate_strata"
  )
})

test_that("#373: missing_rate = 'exclude' reports the covered total and records what it left out", {
  d <- mrs_design()
  expect_warning(
    res <- suppressMessages(estimate_total_catch(d, missing_rate = "exclude")),
    class = "creel_warning_missing_rate_strata"
  )
  # The covered total is the weekday product, which is what the old default
  # silently called the season total.
  weekday_only <- quiet(estimate_total_catch(d, by = day_type, missing_rate = "exclude"))
  expect_equal(
    res$estimates$estimate,
    weekday_only$estimates$estimate[weekday_only$estimates$day_type == "weekday"]
  )
  # The record: which cell, how much effort, from which call.
  ex <- res$excluded_strata
  expect_s3_class(ex, "data.frame")
  expect_equal(nrow(ex), 1L)
  expect_identical(as.character(ex$day_type), "weekend")
  effort <- quiet(estimate_effort(d, by = day_type))$estimates
  expect_equal(ex$effort_excluded, effort$estimate[effort$day_type == "weekend"])
})

test_that("#373: an excluded by-group is an NA row, not a missing one", {
  # Every weekend cell is uncovered, so the weekend group has no covered
  # stratum to sum. Its catch is unknown -- an NA row -- not absent.
  res <- quiet(estimate_total_catch(mrs_design(), by = day_type, missing_rate = "exclude"))
  est <- res$estimates
  expect_setequal(as.character(est$day_type), c("weekday", "weekend"))
  wk <- est[est$day_type == "weekend", ]
  expect_true(is.na(wk$estimate))
  expect_true(is.na(wk$se))
  expect_identical(wk$n, 0L)
})

test_that("#373: a fully covered design is unchanged and records nothing excluded", {
  d <- mrs_design(weekend_incomplete = FALSE)
  a <- quiet(estimate_total_catch(d))
  b <- quiet(estimate_total_catch(d, missing_rate = "exclude"))
  expect_equal(a$estimates, b$estimates)
  expect_null(a$excluded_strata)
  expect_null(b$excluded_strata)
})

test_that("#373: a sectioned grouped total refuses, and its record names the section", {
  # Each section is estimated on its own filtered design, so the section is not
  # a join column; the record has to add it or "weekend" names no place.
  d <- make_sectioned_species_design()
  sel <- d$interviews$section == "South" & d$interviews$day_type == "weekend"
  d$interviews$trip_status[sel] <- "incomplete"

  expect_error(
    quiet(estimate_total_catch(d, by = day_type)),
    class = "creel_error_missing_rate_strata"
  )
  res <- quiet(estimate_total_catch(d, by = day_type, missing_rate = "exclude"))
  expect_equal(nrow(res$excluded_strata), 1L)
  expect_identical(res$excluded_strata$section, "South")
  expect_identical(as.character(res$excluded_strata$day_type), "weekend")
  south_wk <- res$estimates[res$estimates$section == "South" & res$estimates$day_type == "weekend", ]
  expect_true(is.na(south_wk$estimate))
})

test_that("#373: missing_rate = 'exclude' is refused where there is no cell to exclude", {
  # Bus-route totals are Horvitz-Thompson sums with no per-stratum product;
  # accepting the argument there would make it inert (GH #266).
  br <- build_br_design_for_tests(3, 6, 20, seed = 1)
  expect_error(
    quiet(estimate_total_catch(br, missing_rate = "exclude")),
    "does not apply"
  )
})

test_that("#373: a printed total over part of the effort says so", {
  # The warning scrolls past; the printed object is what gets read and pasted.
  res <- quiet(estimate_total_catch(mrs_design(), missing_rate = "exclude"))
  printed <- paste(format(res), collapse = "\n")
  expect_match(printed, "excluded_strata", fixed = TRUE)
  # Named, not only counted: two totals excluding different cells of equal
  # effort would otherwise print identically.
  expect_match(printed, "day_type = weekend: 201.9 effort units", fixed = TRUE)
  full <- quiet(estimate_total_catch(mrs_design(weekend_incomplete = FALSE)))
  expect_no_match(paste(format(full), collapse = "\n"), "excluded_strata", fixed = TRUE)
})

test_that("#373: a product sum with no covered stratum is NA, not zero", {
  # sum() over no strata is 0, which would report an unknown catch as none.
  # Not reachable through the public totals today (a design with no usable
  # trips fails earlier, in the rate), so the helper is pinned directly.
  effort <- tibble::tibble(day_type = "weekend", estimate = 200, se = 10, n = 2L)
  rate <- tibble::tibble(day_type = "weekday", estimate = 0.9, se = 0.1, n = 10L)
  out <- compute_stratum_product_sum(
    effort_df = effort, rate_df = rate,
    stratum_by_vars = "day_type", interview_by_vars = NULL,
    conf_level = 0.95, rate_suffix = "cpue"
  )
  expect_true(is.na(out$estimate))
  expect_identical(out$n, 0L)
})

test_that("#373: an ungrouped sectioned total refuses an uncovered stratum, under either setting", {
  # This total multiplies each section's effort by one rate pooled across its
  # strata, so it never formed per-stratum cells: South's weekend effort took
  # South's weekday rate, with no error and no record.
  d <- make_sectioned_species_design()
  sel <- d$interviews$section == "South" & d$interviews$day_type == "weekend"
  d$interviews$trip_status[sel] <- "incomplete"

  expect_error(quiet(estimate_total_catch(d)), class = "creel_error_missing_rate_strata")
  expect_error(quiet(estimate_total_harvest(d)), class = "creel_error_missing_rate_strata")
  expect_error(quiet(estimate_total_release(d)), class = "creel_error_missing_rate_strata")
  # A pooled rate leaves nothing to exclude, so the opt-in is refused too, and
  # points at the stratified total that can.
  expect_error(
    quiet(estimate_total_catch(d, missing_rate = "exclude")),
    "by = day_type",
    fixed = TRUE,
    class = "creel_error_missing_rate_strata"
  )
  # A fully covered sectioned design is untouched.
  expect_no_error(quiet(estimate_total_catch(make_sectioned_species_design())))
})

test_that("#373: an unknown excluded effort is reported as unknown, not as zero", {
  # na.rm would turn an NA effort into a plausible "0 effort units, 0%".
  d <- set_missing_rate_policy(mrs_design(), "error")
  effort <- tibble::tibble(day_type = c("weekday", "weekend"), estimate = c(170, NA))
  rate <- tibble::tibble(day_type = "weekday", estimate = 0.9)
  err <- tryCatch(
    check_missing_rate_strata(d, effort, rate, "day_type", "test"),
    creel_error_missing_rate_strata = function(e) e
  )
  msg <- conditionMessage(err)
  expect_match(msg, "unknown amount of effort", fixed = TRUE)
  expect_match(msg, "unknown share", fixed = TRUE)
  expect_no_match(msg, "0 effort units", fixed = TRUE)
})

test_that("#373: the refusal does not call a harvest or release total 'catch'", {
  msg <- tryCatch(
    quiet(estimate_total_harvest(mrs_design())),
    creel_error_missing_rate_strata = conditionMessage
  )
  expect_no_match(msg, "catch is unknown", fixed = TRUE)
  expect_match(msg, "estimate_total_harvest", fixed = TRUE)
})

test_that("#373: the exclusion record never overwrites a grouping column", {
  # The record's metadata used to be written as `effort` and `context`, which
  # would silently replace a `by` column of either name.
  d <- set_missing_rate_policy(mrs_design(), "exclude")
  effort <- tibble::tibble(
    day_type = c("weekday", "weekend"), effort = c("low", "high"),
    estimate = c(170, 201.9)
  )
  rate <- tibble::tibble(day_type = "weekday", effort = "low", estimate = 0.9)
  quiet(check_missing_rate_strata(d, effort, rate, c("day_type", "effort"), "test"))
  rec <- d$total_excluded$rows[[1]]
  expect_identical(rec$effort, "high")
  expect_equal(rec$effort_excluded, 201.9)
  expect_identical(rec$excluded_from, "test")
})

test_that("#373: a section with counts but no usable interviews is not summed out of the lake total", {
  # South has effort, but the trip filter leaves it no interviews. It used to be
  # reported as a section "not found", given an NA row, and the .lake_total was
  # North alone, still marked available.
  d <- make_sectioned_species_design()
  d$interviews$trip_status[d$interviews$section == "South"] <- "incomplete"

  for (fn in list(estimate_total_catch, estimate_total_harvest, estimate_total_release)) {
    expect_error(
      quiet(fn(d, use_trips = "complete")),
      class = "creel_error_missing_rate_strata"
    )
  }

  res <- quiet(estimate_total_catch(d, use_trips = "complete", missing_rate = "exclude"))
  expect_identical(res$excluded_strata$section, "South")
  expect_gt(res$excluded_strata$effort_excluded, 0)
  south <- res$estimates[res$estimates$section == "South", ]
  expect_true(is.na(south$estimate))
  # It was found -- it has counts -- so it is not reported as missing.
  expect_no_warning(
    suppressMessages(withCallingHandlers(
      estimate_total_catch(d, use_trips = "complete", missing_rate = "exclude"),
      creel_warning_missing_rate_strata = function(w) invokeRestart("muffleWarning")
    )),
    message = "not found"
  )
})

# A cell whose effort is a KNOWN zero (estimate 0, se 0: every sampled count was
# zero) has a product of exactly 0 whatever its rate is, so a missing rate leaves
# nothing unknown. Refusing it by default regressed a total the old code got
# right, and the message contradicted itself ("unknown, not zero: 0 effort
# units, 0%") -- Copilot, #408. Only estimate 0 AND se 0 is known; zero observed
# with spread is not.
mrs_zero_weekend_design <- function() {
  data(example_counts, package = "tidycreel")
  data(example_calendar, package = "tidycreel")
  data(example_interviews, package = "tidycreel")
  cn <- example_counts
  cn$effort_hours[cn$day_type == "weekend"] <- 0
  iv <- example_interviews
  iv$trip_status[iv$date %in% cn$date[cn$day_type == "weekend"]] <- "incomplete"
  d <- suppressMessages(creel_design(example_calendar, date = date, strata = day_type)) # nolint: object_usage_linter
  d <- quiet(add_counts(d, cn))
  d <- quiet(add_interviews(
    d, iv,
    catch = catch_total, harvest = catch_kept, effort = hours_fished, # nolint: object_usage_linter
    n_anglers = n_anglers, trip_status = trip_status, trip_duration = trip_duration # nolint: object_usage_linter
  ))
  data(example_catch, package = "tidycreel")
  quiet(add_catch(
    d, example_catch[example_catch$interview_id %in% iv$interview_id, ],
    catch_uid = interview_id, interview_uid = interview_id, # nolint: object_usage_linter
    species = species, count = count, catch_type = catch_type # nolint: object_usage_linter
  ))
}

test_that("#373: a known-zero effort cell with no rate is a zero product, not an unknown", {
  d <- mrs_zero_weekend_design()
  for (fn in list(estimate_total_catch, estimate_total_harvest, estimate_total_release)) {
    tot <- quiet(fn(d))
    expect_false(is.na(tot$estimates$estimate))
    grp <- quiet(fn(d, by = day_type))
    wk <- grp$estimates[grp$estimates$day_type == "weekend", ]
    expect_equal(nrow(wk), 1L)
    # 0, not NA: NA would say the weekend catch is unknown when it is known.
    expect_equal(wk$estimate, 0)
    expect_equal(wk$se, 0)
    # The weekday cell is untouched by carrying the zero cell.
    expect_equal(
      grp$estimates$estimate[grp$estimates$day_type == "weekday"],
      tot$estimates$estimate
    )
  }
})

test_that("#373: known_zero_effort() needs estimate 0 AND se 0; NA is never known", {
  df <- data.frame(
    estimate = c(0, 0, 5, NA, 0, 0),
    se = c(0, 2, 0, 0, NA, 0)
  )
  expect_identical(tidycreel:::known_zero_effort(df), c(TRUE, FALSE, FALSE, FALSE, FALSE, TRUE))
})
