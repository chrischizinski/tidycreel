# Pooled totals over an unclassified domain (GH #242) ----
#
# Counts bound what a total can be broken down by. When a domain is not
# classified in the counts the only available total is
#
#     Catch_total = E_total * CPUE_pooled
#
# and CPUE_pooled is a ratio of means weighted by the INTERVIEW sample's
# composition over that domain. Had the domain been classified in the counts it
# would be a stratum and the total would be sum_h E_h * CPUE_h, which is
# unbiased whatever the interview composition.
#
# The two agree only when the interview sample's effort composition matches the
# true effort composition -- and interview selection is non-proportional to
# effort by construction of the standard designs (Malvestuto 1996: access
# interviews intercept completed trips, over-representing anglers who return to
# a fixed point; roving interviews are length-biased toward longer trips). So
# the mix differs by design, not by accident.
#
# Nothing in the reported output distinguishes the two situations, and it cannot
# be verified from within the data -- the counts hold no composition to compare
# against. These tests pin that the risk is surfaced, that it is surfaced only
# when it plausibly bites, and that it reads as a risk rather than an error.

#' Design carrying an interview-only domain, with the rate under the caller's control
#'
#' `target` (species sought) is knowable only by asking an angler, so a counter
#' cannot classify it and it can never become a stratum.
make_pooled_domain_design <- function(bass_multiplier = 1L, domain = "target") {
  cal <- data.frame(
    date = seq.Date(as.Date("2024-06-01"), by = "day", length.out = 8L),
    day_type = rep_len(c("weekday", "weekend"), 8L),
    stringsAsFactors = FALSE
  )
  design <- creel_design(cal, date = date, strata = day_type) # nolint: object_usage_linter

  counts <- data.frame(
    date = cal$date,
    day_type = cal$day_type,
    effort_hours = c(15, 23, 18, 21, 45, 52, 48, 51),
    period_hours = rep(12, 8L),
    stringsAsFactors = FALSE
  )
  design <- suppressMessages(suppressWarnings( # nolint: object_usage_linter
    add_counts(design, counts, period_length_col = period_hours)
  ))

  n_int <- 24L
  catch_data <- build_species_catch_for_tests(
    interview_ids = seq_len(n_int),
    n_species = 2L,
    include_harvest = TRUE
  )
  interviews <- build_trip_interviews_for_tests(
    calendar = cal,
    n_interviews = n_int,
    catch_total = catch_data$interview_catch_total,
    catch_kept = catch_data$interview_catch_kept
  )
  interviews[[domain]] <- rep_len(c("bass", "bluegill"), n_int)
  bass <- interviews[[domain]] == "bass"
  interviews$catch_total[bass] <- interviews$catch_total[bass] * bass_multiplier
  interviews$catch_kept[bass] <- interviews$catch_kept[bass] * bass_multiplier

  design <- suppressMessages(suppressWarnings(add_interviews(
    design,
    interviews,
    catch = catch_total,
    effort = hours_fished,
    harvest = catch_kept,
    n_anglers = n_anglers,
    trip_status = trip_status,
    trip_duration = trip_duration,
    n_counted = n_counted,
    n_interviewed = n_interviewed
  )))

  suppressMessages(suppressWarnings(add_catch(
    design,
    catch_data$catch_df,
    catch_uid = interview_id,
    interview_uid = interview_id,
    species = species,
    count = count,
    catch_type = catch_type
  )))
}

#' Capture the pooled-domain warning
#'
#' `suppressWarnings()` around the call muffles the condition before a
#' class-specific calling handler ever sees it, which reports a warning that did
#' fire as absent. AGENTS.md calls for withCallingHandlers/invokeRestart for
#' cli_warn capture for exactly this reason.
catch_mix_warning <- function(expr) {
  msg <- NULL
  withCallingHandlers(
    suppressMessages(expr),
    creel_warning_pooled_domain_mix = function(cnd) {
      msg <<- cli::ansi_strip(conditionMessage(cnd))
      invokeRestart("muffleWarning")
    },
    warning = function(cnd) invokeRestart("muffleWarning")
  )
  msg
}

test_that("PDM-01: a total pooled over an unclassified domain warns", {
  set.seed(242)
  design <- make_pooled_domain_design(bass_multiplier = 3L, domain = "sought_pdm01")

  # The class is what a caller can branch on; a bare message could not be
  # distinguished from the other risk warnings on this path.
  msg <- catch_mix_warning(estimate_total_catch(design)) # nolint: object_usage_linter
  expect_false(is.null(msg))
  expect_match(msg, "sought_pdm01")
})

test_that("PDM-02: the warning names the estimator form and the route that removes the assumption", {
  set.seed(242)
  # A domain of its own: the warning fires once per (estimator, domain) per
  # session, so a shared name would make this test depend on what ran before it.
  design <- make_pooled_domain_design(bass_multiplier = 3L, domain = "sought_pdm02")
  msg <- catch_mix_warning(estimate_total_catch(design)) # nolint: object_usage_linter

  # Naming the pooled form is what makes the risk legible: the reader has to see
  # that the weighting came from the interview sample, not from effort.
  expect_match(msg, "E_total * rate_pooled", fixed = TRUE)
  expect_match(msg, "interview mix rather than the effort mix")
  # Classifying the domain in the counts is the actual fix, not a workaround.
  expect_match(msg, "sum(E_h * rate_h)", fixed = TRUE)
})

test_that("PDM-03: the warning reads as a risk, not a defect", {
  set.seed(242)
  design <- make_pooled_domain_design(bass_multiplier = 3L, domain = "sought_pdm03")
  msg <- catch_mix_warning(estimate_total_catch(design)) # nolint: object_usage_linter

  # #242 is explicit that this must not be read as an error: it is unverifiable
  # from within the data, because the counts hold no composition to check.
  expect_match(msg, "risk, not an error")
  expect_match(msg, "cannot be verified")
})

test_that("PDM-04: identical rates across levels do not warn", {
  set.seed(242)
  design <- make_pooled_domain_design(bass_multiplier = 1L, domain = "sought_pdm04")
  # Flatten the rate so the domain cannot bias the pooled total.
  design$interviews$catch_total <- rep(4L, nrow(design$interviews))
  design$interviews$.angler_effort <- rep(2, nrow(design$interviews))

  # Bias needs BOTH a domain the counts miss and rates that differ. Warning on
  # structure alone would fire where the pooled total is unbiased, and a warning
  # that fires when nothing is wrong is one users learn to ignore.
  expect_null(catch_mix_warning(estimate_total_catch(design))) # nolint: object_usage_linter
})

test_that("PDM-05: a single-level column is not a domain", {
  set.seed(242)
  design <- make_pooled_domain_design(bass_multiplier = 3L, domain = "sought_pdm05")
  design$interviews$sought_pdm05 <- "bass"

  expect_null(catch_mix_warning(estimate_total_catch(design))) # nolint: object_usage_linter
})

test_that("PDM-06: columns the design gave a role to are never treated as domains", {
  set.seed(242)
  design <- make_pooled_domain_design(bass_multiplier = 3L, domain = "sought_pdm06")

  # trip_status is categorical and absent from the counts, but it is claimed by
  # trip_status_col -- it describes the interview, it is not a domain effort
  # could have been split by. Same for the strata column, which IS in the counts.
  candidates <- pooled_domain_candidates(design)
  expect_identical(candidates, "sought_pdm06")
  expect_false("trip_status" %in% candidates)
  expect_false("day_type" %in% candidates)
  expect_false(any(startsWith(candidates, ".")))
})

test_that("PDM-07: harvest and release totals raise it on the same footing", {
  set.seed(242)
  design <- make_pooled_domain_design(bass_multiplier = 3L, domain = "sought_pdm07")

  # The three totals are near-twins; a seam warning belonging to one belongs to
  # all three, and harvest screens on the harvest column rather than catch.
  expect_false(is.null(catch_mix_warning(estimate_total_harvest(design)))) # nolint: object_usage_linter
  expect_false(is.null(catch_mix_warning(estimate_total_release(design)))) # nolint: object_usage_linter
})

test_that("PDM-08: the crude screen survives what the survey-weighted rate cannot", {
  set.seed(242)
  design <- make_pooled_domain_design(bass_multiplier = 3L, domain = "sought_pdm08")

  # estimate_catch_rate() refuses sparse interview data -- here on the
  # complete-trip minimum, and on the per-group minimum once that is cleared.
  # Either way it is exactly the sparse case most at risk of a mismatched mix,
  # so a screen built on it would fail where it is needed most. That is why the
  # screen is a ratio of sums and not a survey-weighted estimate.
  design$interviews <- design$interviews[1:6, , drop = FALSE]
  expect_error(
    suppressMessages(suppressWarnings(estimate_catch_rate(design, by = sought_pdm08))) # nolint: object_usage_linter
  )

  spread <- domain_rate_spread(design$interviews, "sought_pdm08", "catch_total", ".angler_effort")
  expect_false(is.null(spread))
  expect_true(spread$spread > 0)
})

test_that("PDM-09: a level with zero catch is the loudest case, not a discarded one", {
  set.seed(242)
  design <- make_pooled_domain_design(bass_multiplier = 3L, domain = "sought_pdm09")
  design$interviews$catch_total[design$interviews$sought_pdm09 == "bass"] <- 0L

  # One level catching nothing against positive effort, beside a level that
  # catches, is as mix-sensitive as this gets: the pooled total is entirely a
  # function of which level the interviews over-sampled. Filtering the zero rate
  # out collapsed the comparison to a single level and returned NULL, silencing
  # the warning precisely where it matters most.
  spread <- domain_rate_spread(design$interviews, "sought_pdm09", "catch_total", ".angler_effort")
  expect_false(is.null(spread))
  expect_equal(spread$spread, 1)

  expect_false(is.null(catch_mix_warning(estimate_total_catch(design)))) # nolint: object_usage_linter
})

test_that("PDM-10: no rate at all is still not a comparison", {
  set.seed(242)
  design <- make_pooled_domain_design(bass_multiplier = 3L, domain = "sought_pdm10")
  design$interviews$catch_total <- 0L

  # Every level at zero has nothing to distinguish it -- keeping zero rates must
  # not turn "no signal" into a 0/0 spread.
  expect_null(domain_rate_spread(design$interviews, "sought_pdm10", "catch_total", ".angler_effort"))
  expect_null(catch_mix_warning(estimate_total_catch(design))) # nolint: object_usage_linter
})

test_that("PDM-11: a harvest total that cannot be computed does not warn on its way out", {
  set.seed(242)
  design <- make_pooled_domain_design(bass_multiplier = 3L, domain = "sought_pdm11")
  design$harvest_col <- NULL

  # Warning about the mix behind a harvest total, then aborting because there is
  # no harvest column, tells the user about a number that was never going to
  # exist. The check belongs after the column validation.
  warned <- FALSE
  expect_error(
    withCallingHandlers(
      suppressMessages(estimate_total_harvest(design)), # nolint: object_usage_linter
      creel_warning_pooled_domain_mix = function(cnd) {
        warned <<- TRUE
        invokeRestart("muffleWarning")
      },
      warning = function(cnd) invokeRestart("muffleWarning")
    ),
    "No harvest column available"
  )
  expect_false(warned)
})
