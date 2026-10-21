# GH #542: bus-route and ice totals summed e_i / pi_i with na.rm = TRUE, so a row
# whose contribution was unknown entered the total as zero. Parties counted but
# not interviewed have an undefined expansion (n_counted / 0); their effort and
# catch vanished from a believable, low total whose only symptom was SE = NaN.
# Absent is not zero: the totals now refuse and name the rows.
#
# Fixture arithmetic: two sites, each waited 60 of a 180-minute circuit,
# p_period = 1, so pi = 1/3 and every row contributes 3 x its expanded value.

br542_design <- function() {
  cal <- data.frame(date = as.Date(c("2024-06-01", "2024-06-02")), day_type = "weekday")
  sf <- data.frame(site = c("A", "B"), circuit = "c", wait = c(60, 60), ct = 180)
  creel_design(
    cal,
    date = date, strata = day_type, survey_type = "bus_route", # nolint: object_usage_linter
    sampling_frame = sf, site = site, circuit = circuit, # nolint: object_usage_linter
    wait_time = wait, circuit_time = ct, p_period = 1 # nolint: object_usage_linter
  )
}

# Day 1 at site B: 3 parties counted, none interviewed.
br542_interviews <- function() {
  data.frame(
    iid = 1:4,
    date = as.Date(c("2024-06-01", "2024-06-01", "2024-06-02", "2024-06-02")),
    day_type = "weekday", site = c("A", "B", "A", "B"), circuit = "c",
    hrs = c(2, NA, 3, 1), catch = c(1, NA, 2, 0), kept = c(1, NA, 1, 0),
    trip_status = "complete",
    n_counted = c(1L, 3L, 1L, 1L), n_interviewed = c(1L, 0L, 1L, 1L)
  )
}

br542_attach <- function(iv, release = FALSE) {
  d <- suppressWarnings(suppressMessages(add_interviews(
    br542_design(), iv,
    effort = hrs, catch = catch, harvest = kept, trip_status = trip_status, # nolint: object_usage_linter
    n_counted = n_counted, n_interviewed = n_interviewed, n_anglers = 1 # nolint: object_usage_linter
  )))
  if (release) {
    # Released fish recorded only for interviewed parties: nobody asked the others.
    asked <- iv$iid[iv$n_interviewed > 0]
    d <- suppressWarnings(add_catch( # nolint: object_usage_linter
      d,
      data.frame(iid = asked, species = "walleye", count = 1L, catch_type = "released"),
      catch_uid = iid, interview_uid = iid, species = species, count = count, # nolint: object_usage_linter
      catch_type = catch_type # nolint: object_usage_linter
    ))
  }
  d
}

test_that("#542: every bus-route total refuses parties counted but not interviewed", {
  d <- br542_attach(br542_interviews(), release = TRUE)
  # Before the fix effort returned 18 = (2 + 3 + 1) x 3: site B's three parties
  # on day 1 added nothing. Each total must stop rather than return a low number.
  totals <- list(
    effort = function(...) estimate_effort(d, ...),
    catch = function(...) estimate_total_catch(d, ...),
    harvest = function(...) estimate_total_harvest(d, ...),
    release = function(...) estimate_total_release(d, ...)
  )
  for (nm in names(totals)) {
    expect_error(
      suppressWarnings(totals[[nm]]()),
      class = "creel_error_unknown_contribution",
      info = nm
    )
    # Grouping must not route around the refusal: the by-site path used to
    # report site A's proportion against the na.rm overall total.
    expect_error(
      suppressWarnings(totals[[nm]](by = site)), # nolint: object_usage_linter
      class = "creel_error_unknown_contribution",
      info = paste(nm, "by site")
    )
  }
  # Species totals delegate to the same totals, so they refuse too.
  expect_error(
    suppressWarnings(estimate_total_release(d, by = species)), # nolint: object_usage_linter
    class = "creel_error_unknown_contribution"
  )
})

test_that("#542: the refusal names the site-day and why it is unknown", {
  d <- br542_attach(br542_interviews())
  err <- tryCatch(suppressWarnings(estimate_effort(d)), error = identity)
  msg <- conditionMessage(err)
  # The user has to find the row in their own data, so the date, site and
  # circuit all have to be there, with the cause.
  expect_match(msg, "date=2024-06-01, site=B, circuit=c: 3 counted, none interviewed", fixed = TRUE)
  expect_match(msg, "not zero", fixed = TRUE)
  # The error is raised for the function the user called, not the helper.
  expect_false(grepl("br_abort_unknown_contribution", deparse(conditionCall(err))))
})

test_that("#542: both resolutions in the message give the totals they describe", {
  iv <- br542_interviews()

  # Dropping the row leaves those parties out on purpose: the total is the
  # interviewed-only 18, now as the user's choice rather than a silent default.
  dropped <- br542_attach(iv[iv$n_interviewed > 0, ])
  expect_equal(suppressWarnings(estimate_effort(dropped))$estimates$estimate, 18)

  # Imputing a per-party value (1 h, 0 fish) with n_interviewed = 1 makes it
  # stand for all 3 parties: 18 + 1 x 3/1 x 3 = 27. The three parties count.
  imputed <- iv
  imputed$hrs[2] <- 1
  imputed$catch[2] <- 0
  imputed$kept[2] <- 0
  imputed$n_interviewed[2] <- 1L
  d <- br542_attach(imputed)
  expect_equal(suppressWarnings(estimate_effort(d))$estimates$estimate, 27)
  expect_equal(suppressWarnings(estimate_total_catch(d))$estimates$estimate, 9)
})

test_that("#542: other unknown contributions are refused, not zeroed", {
  # An interviewed party with no effort recorded: before the fix the effort
  # total dropped it (18, not 18 + 4 x 3 x 3 = 54) under a warning about CPUE.
  iv <- br542_interviews()
  iv$hrs[2] <- 4
  iv$catch[2] <- 2
  iv$kept[2] <- 1
  iv$n_interviewed[2] <- 1L
  no_effort <- iv
  no_effort$hrs[2] <- NA
  err <- tryCatch(suppressWarnings(estimate_effort(br542_attach(no_effort))), error = identity)
  expect_s3_class(err, "creel_error_unknown_contribution")
  expect_match(conditionMessage(err), "effort value is missing", fixed = TRUE)
  # The catch total does not need the missing effort, so it still runs.
  expect_equal(
    suppressWarnings(estimate_total_catch(br542_attach(no_effort)))$estimates$estimate,
    (1 + 2 * 3 + 2 + 0) * 3
  )

  # A missing count dropped the row from every total with no warning at all.
  no_count <- iv
  no_count$n_counted[2] <- NA
  err <- tryCatch(suppressWarnings(estimate_total_catch(br542_attach(no_count))), error = identity)
  expect_s3_class(err, "creel_error_unknown_contribution")
  expect_match(conditionMessage(err), "n_counted or n_interviewed is missing", fixed = TRUE)

  # Complete data are untouched: the same design with the party known is 54.
  expect_equal(suppressWarnings(estimate_effort(br542_attach(iv)))$estimates$estimate, 54)
})

test_that("#542: a 0/0 visit (nobody there) is still a true zero", {
  # True zeros always count; only unknowns are refused.
  iv <- br542_interviews()
  iv$n_counted[2] <- 0L
  d <- br542_attach(iv)
  expect_equal(suppressWarnings(estimate_effort(d))$estimates$estimate, 18)
  expect_equal(suppressWarnings(estimate_total_catch(d))$estimates$estimate, 9)
})

test_that("#542: ice designs, which reuse the bus-route totals, refuse too", {
  cal <- data.frame(
    date = as.Date(c("2024-01-10", "2024-01-11", "2024-01-12", "2024-01-13")),
    day_type = c("weekday", "weekday", "weekend", "weekend")
  )
  design <- creel_design(
    cal,
    date = date, strata = day_type, survey_type = "ice", # nolint: object_usage_linter
    effort_type = "time_on_ice", p_period = 0.5
  )
  iv <- data.frame(
    date = cal$date, day_type = cal$day_type,
    n_counted = c(10L, 8L, 12L, 9L), n_interviewed = c(3L, 0L, 4L, 3L),
    hours_fished = c(2.0, NA, 3.0, 2.5), walleye_catch = c(1L, NA, 2L, 1L),
    trip_status = "complete"
  )
  d <- suppressWarnings(suppressMessages(add_interviews(
    design, iv,
    catch = walleye_catch, effort = hours_fished, # nolint: object_usage_linter
    n_counted = n_counted, n_interviewed = n_interviewed, trip_status = trip_status # nolint: object_usage_linter
  )))
  err <- tryCatch(suppressWarnings(estimate_effort(d)), error = identity)
  expect_s3_class(err, "creel_error_unknown_contribution")
  # Ice interviews have no site or circuit column; the date still identifies the row.
  expect_match(conditionMessage(err), "date=2024-01-11: 8 counted, none interviewed", fixed = TRUE)
  # The shared helper must not call an ice survey a bus route.
  expect_match(conditionMessage(err), "^Ice effort total")
})

# GH #545: the rates on the same rows returned NA with SE NaN and no reason.
# They refuse the same rows the totals do, so resolving the data once lets both
# run. All rates delegate to estimate_harvest_br(), so the four metrics and the
# three use_trips modes are checked through the public functions.
test_that("#545: bus-route rates refuse parties counted but not interviewed", {
  d <- br542_attach(br542_interviews(), release = TRUE)
  rates <- list(
    catch = function(...) estimate_catch_rate(d, ...),
    harvest = function(...) estimate_harvest_rate(d, ...),
    release = function(...) estimate_release_rate(d, ...)
  )
  for (nm in names(rates)) {
    err <- tryCatch(suppressWarnings(rates[[nm]]()), error = identity)
    expect_s3_class(err, "creel_error_unknown_contribution")
    expect_match(conditionMessage(err), paste0("^Bus-route ", nm, " rate has 1 interview row"), info = nm)
    expect_match(conditionMessage(err), "site=B, circuit=c: 3 counted, none interviewed", fixed = TRUE)
    expect_error(
      suppressWarnings(rates[[nm]](by = site)), # nolint: object_usage_linter
      class = "creel_error_unknown_contribution", info = paste(nm, "by site")
    )
  }
  # Diagnostic mode needs both trip types; the uncovered row stays complete.
  mixed <- br542_interviews()
  mixed$trip_status[3:4] <- "incomplete"
  expect_error(
    suppressWarnings(suppressMessages(
      estimate_catch_rate(br542_attach(mixed), use_trips = "diagnostic")
    )),
    class = "creel_error_unknown_contribution"
  )
})

test_that("#545: the incomplete-trip rate refuses before truncation can hide the row", {
  # An uncovered party has no effort, so truncation (NA duration) and the
  # zero-effort drop would each have removed it under a message about short or
  # zero-effort trips. The refusal has to come first.
  iv <- br542_interviews()
  iv$trip_status <- c("incomplete", "incomplete", "incomplete", "incomplete")
  d <- br542_attach(iv)
  err <- tryCatch(
    suppressWarnings(suppressMessages(estimate_catch_rate(d, use_trips = "incomplete"))),
    error = identity
  )
  expect_s3_class(err, "creel_error_unknown_contribution")
  expect_match(conditionMessage(err), "3 counted, none interviewed", fixed = TRUE)
})

test_that("#545: a missing catch on an interviewed party is refused, a 0/0 visit is not", {
  iv <- br542_interviews()
  iv$n_counted[2] <- 1L
  iv$n_interviewed[2] <- 1L
  iv$hrs[2] <- 2
  iv$kept[2] <- 0
  err <- tryCatch(suppressWarnings(estimate_catch_rate(br542_attach(iv))), error = identity)
  expect_s3_class(err, "creel_error_unknown_contribution")
  expect_match(conditionMessage(err), "catch or effort value is missing", fixed = TRUE)

  # Nobody at site B on day 1: the rate is total catch over total effort of the
  # three interviewed parties, (1 + 2 + 0) / (2 + 3 + 1) = 0.5 (pi cancels).
  iv <- br542_interviews()
  iv$n_counted[2] <- 0L
  expect_equal(suppressWarnings(estimate_catch_rate(br542_attach(iv)))$estimates$estimate, 0.5)
})

test_that("#545: the incomplete-trip rate refuses missing effort but still drops zero effort", {
  iv <- br542_interviews()
  iv$trip_status <- "incomplete"
  iv$n_interviewed[2] <- 1L
  iv$hrs[2] <- NA
  iv$catch[2] <- 1
  # Missing effort is unknown, so the rate refuses rather than dropping the party.
  err <- tryCatch(
    suppressWarnings(suppressMessages(estimate_catch_rate(br542_attach(iv), use_trips = "incomplete"))),
    error = identity
  )
  expect_s3_class(err, "creel_error_unknown_contribution")
  expect_match(conditionMessage(err), "site=B, circuit=c: effort value is missing", fixed = TRUE)

  # Zero effort (met at the start of the trip) has an undefined ratio, not an
  # unknown one: it is still excluded, with the warning, and the rate runs.
  iv$hrs[2] <- 0
  d <- br542_attach(iv)
  expect_warning(
    res <- suppressMessages(estimate_catch_rate(d, use_trips = "incomplete", truncate_at = NULL)),
    class = "creel_warning_effort_excluded"
  )
  expect_false(is.na(res$estimates$estimate))
})
