# GH #618: R never matches the empty name. `x[""]` is NA, `x[[""]]` on a list
# is NULL, so any lookup BY NAME loses a stratum, group or frame labelled "".
# "" is a legal label everywhere else in the package, and a label is only a
# name: renaming one to "" must not move any number. #614 fixed the effort
# variance terms; these are the remaining sites, found by probing each with a
# relabelled fixture (see the discovery comment on #618).
#
# Each test builds the same data twice, once with a real label and once with
# "", and compares by label -- "" sorts first, so row order differs.

relabel_rows <- function(df, col, from) {
  df <- as.data.frame(df)
  df[[col]][df[[col]] == from] <- ""
  `rownames<-`(df[order(df[[col]]), , drop = FALSE], NULL)
}

quiet <- function(x) suppressWarnings(suppressMessages(x))

# ---- Sample size n beside a grouped estimate --------------------------------

test_that("#618: effort n counts a group labelled \"\"", {
  # Before: n_by_key[""] was NA and the next line turned NA into 0, so the
  # group reported n = 0 beside an estimate built from its counts.
  mk <- function(label) {
    cal <- data.frame(
      date = as.Date("2024-06-03") + 0:5,
      day_type = c(rep("weekday", 4), label, label)
    )
    cnt <- data.frame(
      date = cal$date[c(1, 2, 5, 6)],
      day_type = cal$day_type[c(1, 2, 5, 6)],
      count = c(10, 9, 20, 30)
    )
    quiet(add_counts(creel_design(cal, date = date, strata = day_type), cnt)) # nolint: object_usage_linter
  }
  est <- function(d) {
    as.data.frame(quiet(estimate_effort(d, by = day_type))$estimates)[ # nolint: object_usage_linter
      c("day_type", "estimate", "se", "n")
    ]
  }
  blank <- est(mk(""))
  expect_equal(blank, relabel_rows(est(mk("weekend")), "day_type", "weekend"))
  expect_identical(blank$n[blank$day_type == ""], 2L)
})

test_that("#618: catch and harvest rate n count a group labelled \"\"", {
  # Before: n = NA for the "" group. The key IS in names(n_by_key) (%in% matches
  # ""), so the absent-group zero did not fire either.
  data(example_calendar, package = "tidycreel")
  data(example_interviews, package = "tidycreel")
  # Doubled so each angler type clears the n >= 10 ratio guard.
  iv <- rbind(
    example_interviews,
    transform(example_interviews, interview_id = interview_id + 100L)
  )
  mk <- function(label) {
    iv$angler_type[iv$angler_type == "bank"] <- label
    quiet(add_interviews(
      creel_design(example_calendar, date = date, strata = day_type), # nolint: object_usage_linter
      iv,
      catch = catch_total, effort = hours_fished, harvest = catch_kept, # nolint: object_usage_linter
      trip_status = trip_status # nolint: object_usage_linter
    ))
  }
  blank <- mk("")
  named <- mk("bank")
  for (fn in list(estimate_catch_rate, estimate_harvest_rate)) {
    est <- function(d) {
      as.data.frame(quiet(fn(d, by = angler_type))$estimates)[ # nolint: object_usage_linter
        c("angler_type", "estimate", "se", "n")
      ]
    }
    b <- est(blank)
    expect_equal(b, relabel_rows(est(named), "angler_type", "bank"))
    expect_false(anyNA(b$n))
  }
})

test_that("#618: bus-route effort, totals and rates count a site labelled \"\"", {
  mk <- function(label) {
    cal <- data.frame(date = as.Date(c("2024-06-01", "2024-06-02")), day_type = "weekday")
    sf <- data.frame(site = c(label, "B"), circuit = "c", wait = c(60, 60), ct = 180)
    d <- creel_design(
      cal,
      date = date, strata = day_type, survey_type = "bus_route", # nolint: object_usage_linter
      sampling_frame = sf, site = site, circuit = circuit, # nolint: object_usage_linter
      wait_time = wait, circuit_time = ct, p_period = 1 # nolint: object_usage_linter
    )
    iv <- data.frame(
      iid = 1:4,
      date = as.Date(c("2024-06-01", "2024-06-01", "2024-06-02", "2024-06-02")),
      day_type = "weekday", site = c(label, "B", label, "B"), circuit = "c",
      hrs = c(2, 4, 3, 1), catch = c(1, 3, 2, 0), kept = c(1, 2, 1, 0),
      trip_status = "complete",
      n_counted = 1L, n_interviewed = 1L
    )
    quiet(add_interviews(
      d, iv,
      effort = hrs, catch = catch, harvest = kept, trip_status = trip_status, # nolint: object_usage_linter
      n_counted = n_counted, n_interviewed = n_interviewed, n_anglers = 1 # nolint: object_usage_linter
    ))
  }
  blank <- mk("")
  named <- mk("A")
  fns <- list(
    effort = function(d) estimate_effort(d, by = site, target = "sampled_days"), # nolint: object_usage_linter
    total_catch = function(d) estimate_total_catch(d, by = site, target = "sampled_days"), # nolint: object_usage_linter
    catch_rate = function(d) estimate_catch_rate(d, by = site), # nolint: object_usage_linter
    harvest_rate = function(d) estimate_harvest_rate(d, by = site) # nolint: object_usage_linter
  )
  for (nm in names(fns)) {
    est <- function(d) {
      as.data.frame(quiet(fns[[nm]](d))$estimates)[c("site", "estimate", "se", "n")]
    }
    b <- est(blank)
    expect_equal(b, relabel_rows(est(named), "site", "A"), info = nm)
    expect_false(anyNA(b$n), info = nm)
  }
})

# ---- Length: cross-bin covariance and percentages ---------------------------

length_design <- function(label) {
  data(example_calendar, package = "tidycreel")
  data(example_interviews, package = "tidycreel")
  data(example_lengths, package = "tidycreel")
  data(example_catch, package = "tidycreel")
  sp <- sort(unique(example_lengths$species))[1]
  lens <- example_lengths
  cat <- example_catch
  lens$species[lens$species == sp] <- label
  cat$species[cat$species == sp] <- label
  d <- creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  d <- add_interviews(
    d, example_interviews,
    catch = catch_total, effort = hours_fished, harvest = catch_kept, # nolint: object_usage_linter
    trip_status = trip_status # nolint: object_usage_linter
  )
  d <- add_catch(
    d, cat,
    catch_uid = interview_id, interview_uid = interview_id, # nolint: object_usage_linter
    species = species, count = count, catch_type = catch_type # nolint: object_usage_linter
  )
  d <- add_lengths(
    d, lens,
    length_uid = interview_id, interview_uid = interview_id, # nolint: object_usage_linter
    species = species, length = length, length_type = length_type, # nolint: object_usage_linter
    count = count, release_format = "binned" # nolint: object_usage_linter
  )
  list(design = quiet(d), species = sp)
}

test_that("#618: mean length keeps the cross-bin covariance of a species labelled \"\"", {
  # Before: mats[[""]] was NULL, so the "" species fell back to independent bins
  # -- SE 13% low on this fixture -- under a warning that blamed subsetting.
  named <- length_design("zzz")
  blank <- length_design("")
  ld_named <- quiet(est_length_distribution(named$design, by = species, bin_width = 25)) # nolint: object_usage_linter
  ld_blank <- quiet(est_length_distribution(blank$design, by = species, bin_width = 25)) # nolint: object_usage_linter
  expect_no_warning(ml_blank <- est_mean_length(ld_blank))
  ml_named <- est_mean_length(ld_named)
  cols <- c("species", "mean_length", "mean_length_se")
  expect_equal(
    as.data.frame(ml_blank)[ml_blank$species == "", cols[-1]],
    as.data.frame(ml_named)[ml_named$species == "zzz", cols[-1]],
    ignore_attr = TRUE
  )
})

test_that("#618: summarize_length_freq() gives percentages for a species labelled \"\"", {
  named <- length_design("zzz")$design
  blank <- length_design("")$design
  s_named <- as.data.frame(quiet(summarize_length_freq(named, by = species))) # nolint: object_usage_linter
  s_blank <- as.data.frame(quiet(summarize_length_freq(blank, by = species))) # nolint: object_usage_linter
  cols <- c("N", "percent", "cumulative_percent")
  got <- s_blank[s_blank$species == "", cols]
  expect_false(anyNA(got))
  expect_equal(got, s_named[s_named$species == "zzz", cols], ignore_attr = TRUE)
})

# ---- Hybrid design: stratum and frame labels --------------------------------

test_that("#618: a hybrid design accepts a stratum or frame labelled \"\"", {
  # Before: a "" stratum aborted with "missing values in weights" (population
  # days and the within-day fraction both looked up by name) and a "" frame
  # was refused as if its fraction were missing.
  mk <- function(stratum = "weekday", frame = "access") {
    dates <- as.Date(c("2024-06-01", "2024-06-02", "2024-06-08", "2024-06-09"))
    dt <- c(stratum, stratum, "weekend", "weekend")
    counts <- data.frame(
      date = rep(dates, 2),
      day_type = rep(dt, 2),
      count = c(12L, 15L, 30L, 28L, 8L, 10L, 22L, 25L),
      component = rep(c(frame, "roving"), each = 4)
    )
    cal_dates <- as.Date("2024-06-01") + 0:15
    calendar <- data.frame(
      date = cal_dates,
      day_type = ifelse(cal_dates %in% dates[3:4] | cal_dates > as.Date("2024-06-11"), "weekend", stratum)
    )
    frac <- list(c(0.5, 0.5), c(0.4, 0.4))
    frac <- lapply(frac, function(f) stats::setNames(f, c(stratum, "weekend")))
    names(frac) <- c(frame, "roving")
    d <- as_hybrid_svydesign(
      counts,
      frame_col = "component", calendar = calendar,
      fraction = frac, trips_disjoint = TRUE
    )
    t <- survey::svytotal(~count, d)
    c(total = unname(stats::coef(t)), se = unname(survey::SE(t)))
  }
  base <- mk()
  expect_equal(mk(stratum = ""), base)
  expect_equal(mk(frame = ""), base)
})
