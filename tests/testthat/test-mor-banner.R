# Which trips does a mean-of-ratios estimate actually describe? (GH #276)
#
# The printed MOR banner is a claim about the data behind the number, and it was
# making two false ones.
#
#   1. Only two of three metrics printed it at all. `estimate_cpue_total()` and
#      `estimate_cpue_grouped()` returned a MOR-classed object; the HPUE
#      internals computed the same truncation metadata and then dropped it on
#      the floor, returning a plain `creel_estimates`. The same
#      `estimator = "mor"` request therefore produced a caveat and a truncation
#      report for CPUE and RPUE, and silence for HPUE.
#   2. The banner said "incomplete trip interviews" whatever trips were used.
#      That was true while mean-of-ratios *was* the incomplete-trip estimator,
#      but the roving auto-route (GH #268 for catch, GH #271 for harvest and
#      release) made MOR the default over *all* trips. A roving default rate
#      announced an incomplete-trip caveat while using every trip it had, and
#      `use_trips = "complete"` announced one while using none.
#
# The claim these tests defend is that the banner describes the trip set the
# estimate was built from, on every metric that takes the estimator, and that
# the caveat which only makes sense for incomplete trips appears only there.
# `mor_estimation_warning()` already stays silent on the "all" and "complete"
# paths; the printed banner is the counterpart obeying the same rule, so a test
# that only checked the incomplete path would pass while the other two lied.
#
# Two further claims are asserted separately because they are about information
# the banner reports rather than the wording:
#
#   - a MOR result carries the same unit as the ratio-of-means result beside it.
#     `new_creel_estimates_mor()` had no `unit` argument, so every MOR rate was
#     unitless while its ROM twin read "fish/angler-hour". Nothing warned.
#   - the incomplete count is NA, never 0, when the design has no trip status
#     column. Zero would report an absence of data as a measurement of zero,
#     which is the distinction this package refuses to blur anywhere else.

mor_banner_design <- function(n_incomplete = 24, n_complete = 24) {
  n <- n_incomplete + n_complete
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
    day_type = rep("weekday", 4),
    stringsAsFactors = FALSE
  )
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter

  # Interleaved rather than blocked: a fixture whose statuses are contiguous
  # confounds trip status with position, and the "all" path is then not being
  # shown a mixture at all.
  status <- rep("complete", n)
  status[seq_len(n) %% 2L == 1L][seq_len(n_incomplete)] <- "incomplete"

  interviews <- data.frame(
    interview_id = sprintf("I%03d", seq_len(n)),
    date = as.Date(rep("2024-06-01", n)),
    catch_total = rep(c(4, 6, 5, 7), length.out = n),
    hours_fished = rep(c(2.0, 3.0, 4.0, 2.5), length.out = n),
    catch_kept = rep(c(2, 2, 3, 4), length.out = n),
    trip_status = status,
    trip_duration = rep(c(2.0, 3.0, 4.0, 2.5), length.out = n),
    stringsAsFactors = FALSE
  )

  design <- add_interviews(
    design,
    interviews,
    catch = catch_total,
    effort = hours_fished,
    harvest = catch_kept,
    trip_status = trip_status,
    trip_duration = trip_duration,
    n_anglers = 1
  ) # nolint: object_usage_linter

  # Release estimation reads catch records, not an interview column, so the
  # release rate is unreachable without them -- and the symmetry these tests
  # assert is across all three metrics. harvested + released partitions caught
  # exactly, so the reconciliation advisory stays quiet.
  catch_rows <- data.frame(
    interview_id = rep(interviews$interview_id, each = 3L),
    species = "walleye",
    count = as.vector(rbind(
      interviews$catch_total,
      interviews$catch_kept,
      interviews$catch_total - interviews$catch_kept
    )),
    catch_type = rep(c("caught", "harvested", "released"), times = n),
    stringsAsFactors = FALSE
  )

  add_catch(
    design,
    catch_rows,
    catch_uid = interview_id,
    interview_uid = interview_id,
    species = species,
    count = count,
    catch_type = catch_type
  ) # nolint: object_usage_linter
}

quiet_mor <- function(f, ...) suppressMessages(suppressWarnings(f(...)))

# The banner is everything printed ahead of the estimates block, so an assertion
# about it cannot accidentally match the method label or the tibble below.
mor_banner <- function(x) {
  out <- format(x)
  end <- which(grepl("Creel Survey Estimates", out, fixed = TRUE))[1]
  paste(out[seq_len(end - 1L)], collapse = "\n")
}

# ---- every metric that takes the estimator reports it the same way ----------

test_that("all three metrics return a MOR-classed result for a MOR request", {
  design <- mor_banner_design()

  # HPUE is the one that did not. Asserting the class on all three rather than
  # on harvest alone is deliberate: the asymmetry is the defect, so the test has
  # to fail if any metric drifts away from the other two again.
  for (fn in c("estimate_catch_rate", "estimate_harvest_rate", "estimate_release_rate")) {
    result <- quiet_mor(get(fn), design, use_trips = "all", estimator = "mor")
    expect_s3_class(result, "creel_estimates_mor")
    expect_match(mor_banner(result), "MOR Estimator", info = fn)
  }
})

test_that("a MOR result carries the truncation metadata on every metric", {
  design <- mor_banner_design()

  # Computed for harvest and then discarded before GH #276: the design held it,
  # the returned object did not.
  for (fn in c("estimate_catch_rate", "estimate_harvest_rate", "estimate_release_rate")) {
    result <- quiet_mor(get(fn), design, use_trips = "all", estimator = "mortr", truncate_at = 2.2)
    expect_false(is.null(result$mor_truncate_at), info = fn)
    expect_identical(result$mor_truncate_at, 2.2, info = fn)
    expect_true(result$mor_n_truncated > 0L, info = fn)
    expect_match(mor_banner(result), "Truncation:", info = fn)
  }
})

test_that("grouped HPUE gets the banner too, not only the ungrouped path", {
  design <- mor_banner_design()

  # estimate_harvest_total() and estimate_harvest_grouped() are separate
  # internals with separate returns; fixing one and not the other reproduces the
  # asymmetry one level down.
  grouped <- quiet_mor(
    estimate_harvest_rate,
    design,
    by = trip_status,
    use_trips = "all",
    estimator = "mor"
  )
  expect_s3_class(grouped, "creel_estimates_mor")
  expect_match(mor_banner(grouped), "MOR Estimator")
})

# ---- the banner names the trips actually used ------------------------------

test_that("a MOR estimate over all trips is not described as incomplete-trip only", {
  design <- mor_banner_design()
  result <- quiet_mor(estimate_catch_rate, design, use_trips = "all", estimator = "mor")
  banner <- mor_banner(result)

  # The estimate used every interview, so a caveat about incomplete trips is not
  # a hedge, it is wrong. This is the roving default path since GH #268.
  expect_identical(result$estimates$n, 48L)
  expect_match(banner, "All Trips")
  expect_match(banner, "48 interviews")
  expect_false(grepl("DIAGNOSTIC", banner, fixed = TRUE))
  expect_false(grepl("Complete trips preferred", banner, fixed = TRUE))
  expect_false(grepl("incomplete trip interviews", banner, fixed = TRUE))

  # The mixture is still reported -- how many of those trips were incomplete is
  # exactly what a reader needs to judge length-of-stay bias for themselves.
  expect_match(banner, "24 incomplete")
})

test_that("a MOR estimate over complete trips is not described as incomplete-trip only", {
  design <- mor_banner_design()
  result <- quiet_mor(estimate_catch_rate, design, use_trips = "complete", estimator = "mor")
  banner <- mor_banner(result)

  expect_identical(result$estimates$n, 24L)
  expect_match(banner, "Complete Trips")
  expect_match(banner, "24 complete trips")
  expect_false(grepl("DIAGNOSTIC", banner, fixed = TRUE))
  expect_false(grepl("incomplete trip interviews", banner, fixed = TRUE))
})

test_that("the incomplete-trip path keeps its caveat and its validation pointer", {
  design <- mor_banner_design()
  result <- quiet_mor(estimate_catch_rate, design, use_trips = "incomplete", estimator = "mor")
  banner <- mor_banner(result)

  # Where the diagnostic reading is true it must survive: length-of-stay bias is
  # a real property of an incomplete-trip sample, and this is the one trip set
  # mor_estimation_warning() also still warns about.
  expect_identical(result$estimates$n, 24L)
  expect_match(banner, "DIAGNOSTIC")
  expect_match(banner, "Incomplete Trips")
  expect_match(banner, "Complete trips preferred")
  expect_match(banner, "validate_incomplete_trips")

  # No fabricated denominator. Filtering happens upstream, so "24 of 24 total"
  # was the only number the old wording could produce here.
  expect_false(grepl("of 24 total", banner, fixed = TRUE))
})

test_that("the truncation report survives on the non-diagnostic trip sets", {
  design <- mor_banner_design()

  # Truncation is part of the estimator, not a diagnostic-only detail: an
  # untruncated MOR has infinite variance (Hoenig et al. 1997). Suppressing the
  # whole banner off the incomplete path would have taken this with it.
  for (trips in c("all", "complete")) {
    result <- quiet_mor(
      estimate_catch_rate,
      design,
      use_trips = trips,
      estimator = "mortr",
      truncate_at = 2.2
    )
    banner <- mor_banner(result)
    expect_match(banner, "Truncation:", info = trips)
    expect_false(grepl("DIAGNOSTIC", banner, fixed = TRUE), info = trips)
  }
})

test_that("the banner names the metric it belongs to on each trip set", {
  design <- mor_banner_design()

  # The rate label was hardcoded "CPUE" until GH #271. Checking it on the
  # rewritten non-diagnostic wording as well, because that sentence is new and
  # could have been written with the same constant.
  hpue <- quiet_mor(estimate_harvest_rate, design, use_trips = "all", estimator = "mor")
  expect_match(mor_banner(hpue), "HPUE")
  expect_false(grepl("CPUE", mor_banner(hpue), fixed = TRUE))

  rpue <- quiet_mor(estimate_release_rate, design, use_trips = "all", estimator = "mor")
  expect_match(mor_banner(rpue), "RPUE")
  expect_false(grepl("CPUE", mor_banner(rpue), fixed = TRUE))
})

test_that("the reported count is the trips that survived truncation, not the set that entered", {
  design <- mor_banner_design()

  # The banner's count is the sample behind the estimate. Reported from before
  # truncation it contradicted the truncation line printed directly beneath it:
  # "over all 48 interviews" above "Truncation: 12 trips excluded", when 36
  # ratios had been averaged. The two numbers have to reconcile, and the only
  # way to check that is against the n the estimator itself reports.
  for (fn in c("estimate_catch_rate", "estimate_harvest_rate", "estimate_release_rate")) {
    result <- quiet_mor(
      get(fn), design,
      use_trips = "all", estimator = "mortr", truncate_at = 2.2
    )

    expect_true(result$mor_n_truncated > 0L, info = fn)
    expect_identical(result$n_total, result$estimates$n, info = fn)
    expect_identical(
      result$n_total + result$mor_n_truncated,
      nrow(design$interviews),
      info = fn
    )

    # The incomplete count has to move with it: counted over the pre-truncation
    # set it can exceed the number of trips the banner says were used.
    expect_lte(result$n_incomplete, result$n_total)
    expect_match(mor_banner(result), paste0(result$n_total, " interviews"), info = fn)
  }
})

test_that("interviews the rate internals discard are not counted as used", {
  # The internals drop missing effort, zero effort and missing harvest AFTER the
  # design-level counts are stamped, so reading those counts reported trips the
  # estimate never saw. The fixture above has none of those, which is exactly why
  # it did not reach this path -- a green suite was not evidence the banner
  # agreed with the estimate.
  #
  # The effort column is the DERIVED one. Setting `hours_fished` here changes
  # nothing the estimator reads, and a probe that does so reports "no defect"
  # while never entering the branch.
  design <- mor_banner_design()
  iv <- design$interviews
  iv[[design$angler_effort_col]][1:4] <- 0
  iv[[design$angler_effort_col]][5:6] <- NA_real_
  design$interviews <- iv
  design$interview_survey <- build_interview_survey(
    iv,
    strata = stats::reformulate(design$strata_cols)
  )

  for (fn in c("estimate_catch_rate", "estimate_harvest_rate", "estimate_release_rate")) {
    result <- quiet_mor(get(fn), design, use_trips = "all", estimator = "mor")

    expect_identical(result$estimates$n, 42L, info = fn)
    expect_identical(result$n_total, result$estimates$n, info = fn)
    expect_match(mor_banner(result), "42 interviews", info = fn)
    expect_lte(result$n_incomplete, result$n_total)
  }

  # Grouped goes through a different internal with its own filtering.
  grouped <- quiet_mor(
    estimate_harvest_rate, design,
    by = trip_status, use_trips = "all", estimator = "mor"
  )
  # expect_equal, not expect_identical: the grouped `n` column comes back double
  # where the ungrouped one is integer. That inconsistency is pre-existing and
  # unrelated to the banner, so it is not asserted on here.
  expect_equal(grouped$n_total, sum(grouped$estimates$n))
})

# ---- information the banner reports ----------------------------------------

test_that("a MOR rate carries the same unit as the ratio-of-means rate beside it", {
  design <- mor_banner_design()

  # The unit is derived from the design and describes the quantity, not the
  # estimator, so the two must agree. new_creel_estimates_mor() had no `unit`
  # argument at all, which left every MOR rate reporting NA.
  rom <- quiet_mor(estimate_catch_rate, design, use_trips = "complete", estimator = "ratio-of-means")
  mor <- quiet_mor(estimate_catch_rate, design, use_trips = "complete", estimator = "mor")

  expect_false(is.na(mor$unit))
  expect_identical(mor$unit, rom$unit)

  # The estimators still disagree about the number -- otherwise this test would
  # pass on a design where the two are the same quantity for uninteresting
  # reasons, and prove nothing about which object was built.
  expect_false(isTRUE(all.equal(mor$estimates$estimate, rom$estimates$estimate)))
})

test_that("HPUE keeps its unit now that it is built by the MOR constructor", {
  design <- mor_banner_design()

  # Harvest MOR had a unit only because it went through the plain constructor.
  # Routing it to the MOR one without forwarding `unit` would have taken the
  # unit away in the act of fixing the banner.
  rom <- quiet_mor(estimate_harvest_rate, design, use_trips = "complete", estimator = "ratio-of-means")
  mor <- quiet_mor(estimate_harvest_rate, design, use_trips = "complete", estimator = "mor")

  expect_false(is.na(mor$unit))
  expect_identical(mor$unit, rom$unit)
})

test_that("an unknowable incomplete count is NA and is not printed as zero", {
  design <- mor_banner_design()
  design$interviews[[design$trip_status_col]] <- NULL
  design$trip_status_col <- NULL
  design$interview_survey <- build_interview_survey(
    design$interviews,
    strata = stats::reformulate(design$strata_cols)
  )

  result <- quiet_mor(estimate_harvest_rate, design, use_trips = "all", estimator = "mor")

  # A design with no trip status never measured how many trips were incomplete.
  # Reporting 0 there states a count that was never taken; NA states that it was
  # not, and the banner drops the clause rather than printing a number.
  expect_true(is.na(result$n_incomplete))
  banner <- mor_banner(result)
  expect_match(banner, "All Trips")
  expect_false(grepl("incomplete", banner, fixed = TRUE))
})

test_that("a trip filter that could not run is reported as all trips", {
  design <- mor_banner_design()
  design$interviews[[design$trip_status_col]] <- NULL
  design$trip_status_col <- NULL
  design$interview_survey <- build_interview_survey(
    design$interviews,
    strata = stats::reformulate(design$strata_cols)
  )

  # use_trips = "complete" cannot filter without a trip status column, so every
  # interview was used. Recording the request rather than the effect would put
  # "Complete Trips" on a banner describing all of them.
  result <- quiet_mor(estimate_harvest_rate, design, use_trips = "complete", estimator = "mor")
  expect_identical(result$mor_use_trips, "all")
  expect_match(mor_banner(result), "All Trips")
})

# ---- the estimator is still recoverable from the object (GH #275) -----------

test_that("the banner rewrite did not disturb the recorded estimator", {
  design <- mor_banner_design()

  # mortr normalises to mor for every branch test, so a result that reports
  # "mor" here would be losing the distinction GH #275 established.
  result <- quiet_mor(estimate_harvest_rate, design, use_trips = "all", estimator = "mortr")
  expect_identical(result$estimator, "mortr")
  expect_identical(result$method, "mean-of-ratios-truncated-hpue")
})
