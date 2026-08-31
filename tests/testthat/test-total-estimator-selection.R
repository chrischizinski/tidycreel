# Estimator selection on the total estimators (GH #268)
#
# `estimate_catch_rate()` routes a roving design to all-trip mean-of-ratios,
# because a clerk who intercepts a trip mid-stream records catch-so-far against
# effort-so-far and the two do not scale together (Hoenig et al. 1997). The
# totals requested "ratio-of-means" unconditionally, so a roving design's total
# used a different estimator -- and a different trip set -- from its own rate
# function on the same object, with no message. Neither number looked wrong.
#
# The claim these tests defend is not "the total calls MOR". It is that a total
# and the rate it is a product of resolve the same specification from the same
# design, so the two can never disagree about what the design calls for.

# Mixed trip status *within* each section, for the reason recorded in
# test-total-use-trips.R: alternating by row confounds status with section and
# hides exactly the defects this file is checking for.
roving_selection_design <- function(n_interviews = 48L, seed = 268L) {
  set.seed(seed)
  design <- make_sectioned_species_design(n_interviews)
  iv <- design$interviews
  iv$trip_status <- stats::ave(
    seq_len(nrow(iv)),
    iv[[design$section_col]],
    FUN = function(i) rep(c("complete", "incomplete"), length.out = length(i))
  )
  design$interviews <- iv
  design$interview_survey <- build_interview_survey(
    iv,
    strata = stats::reformulate(design$strata_cols)
  )
  design
}

as_roving <- function(design) {
  # Exactly what add_interviews(interview_type = "roving") records.
  design$interview_type <- "roving"
  design
}

drop_sections_sel <- function(design) {
  design[["sections"]] <- NULL
  design
}

quiet_sel <- function(f, ...) {
  suppressMessages(suppressWarnings(f(...)))
}

est_of <- function(x) x$estimates$estimate

# ---- the auto-route is exactly one pair, on every path ----------------------

# The equality is the whole point: "roving auto-route" is defined as
# use_trips="all" + MOR, so the auto-routed total must be indistinguishable from
# that pair requested by hand. An approximate check would pass if the total
# routed to some other MOR-ish variant.
test_that("a roving design's total catch is exactly the all-trip MOR total", {
  access <- drop_sections_sel(roving_selection_design())
  roving <- as_roving(access)

  expect_equal(
    est_of(quiet_sel(estimate_total_catch, roving)),
    est_of(quiet_sel(
      estimate_total_catch,
      access,
      use_trips = "all",
      estimator = "mor"
    ))
  )
})

test_that("the roving auto-route changes the total it replaces", {
  access <- drop_sections_sel(roving_selection_design())
  roving <- as_roving(access)

  # Without this the equality above would also hold if both were ratio-of-means
  # on complete trips -- i.e. if the auto-route never fired at all.
  expect_false(isTRUE(all.equal(
    est_of(quiet_sel(estimate_total_catch, roving)),
    est_of(quiet_sel(estimate_total_catch, access))
  )))
})

# Threading a resolved value into each dispatch branch is what let `use_trips`
# reach only two of four paths (GH #266). The estimator travels on the design
# instead, and every path has to read it.
test_that("every dispatch path honours the roving auto-route", {
  sectioned <- roving_selection_design()
  flat <- drop_sections_sel(sectioned)
  species_col <- sectioned$species_col %||% "species"

  paths <- list(
    ungrouped = list(design = flat, args = list()),
    grouped = list(design = flat, args = list(by = "day_type")),
    species = list(design = flat, args = list(by = species_col)),
    sectioned = list(design = sectioned, args = list())
  )

  for (nm in names(paths)) {
    design <- paths[[nm]]$design
    args <- paths[[nm]]$args

    auto <- do.call(
      quiet_sel,
      c(list(estimate_total_catch, as_roving(design)), args)
    )
    explicit <- do.call(
      quiet_sel,
      c(
        list(estimate_total_catch, design),
        args,
        list(use_trips = "all", estimator = "mor")
      )
    )
    # Same trip set, ratio-of-means instead of MOR. Holding use_trips fixed is
    # what makes this an estimator test: comparing the auto-routed total against
    # the plain default varies the trip set *and* the estimator, so a path that
    # honoured "all" while silently keeping ratio-of-means still produced a
    # different number and passed. Both mutants -- the stratum-product helper
    # and the species call site reverting to "ratio-of-means" -- survived that
    # weaker check.
    same_trips_rom <- do.call(
      quiet_sel,
      c(
        list(estimate_total_catch, design),
        args,
        list(use_trips = "all", estimator = "ratio-of-means")
      )
    )

    expect_equal(
      auto$estimates$estimate,
      explicit$estimates$estimate,
      info = paste("auto-route not honoured on the", nm, "path")
    )
    expect_false(
      isTRUE(all.equal(
        auto$estimates$estimate,
        same_trips_rom$estimates$estimate
      )),
      info = paste("estimator was ignored on the", nm, "path")
    )
  }
})

# ---- specifying either half suppresses the auto-route ----------------------

test_that("naming use_trips or estimator suppresses the roving auto-route", {
  roving <- as_roving(drop_sections_sel(roving_selection_design()))
  access_default <- est_of(quiet_sel(
    estimate_total_catch,
    drop_sections_sel(roving_selection_design())
  ))

  # The auto-route fires only when the caller expressed no preference at all;
  # a caller who named one half has chosen the access-point reading.
  expect_equal(
    est_of(quiet_sel(estimate_total_catch, roving, use_trips = "complete")),
    access_default
  )
  expect_equal(
    est_of(quiet_sel(
      estimate_total_catch,
      roving,
      estimator = "ratio-of-means"
    )),
    access_default
  )
})

# ---- truncation is part of the estimator, not a tuning knob ----------------

test_that("truncate_at excludes short trips from the MOR total", {
  design <- drop_sections_sel(roving_selection_design())

  # Untruncated MOR has infinite variance (Hoenig et al. 1997), so a
  # truncate_at that the estimator ignored would ship that estimator under the
  # truncated one's name.
  loose <- quiet_sel(
    estimate_total_catch,
    design,
    use_trips = "all",
    estimator = "mor",
    truncate_at = NULL
  )
  tight <- quiet_sel(
    estimate_total_catch,
    design,
    use_trips = "all",
    estimator = "mor",
    truncate_at = 2.0
  )

  expect_false(isTRUE(all.equal(
    est_of(loose),
    est_of(tight)
  )))
})

test_that("truncate_at is inert under ratio-of-means", {
  design <- drop_sections_sel(roving_selection_design())

  # ROM is a ratio of totals and has a finite second moment without truncation,
  # so the threshold must not silently reshape the sample it is applied to.
  expect_equal(
    est_of(quiet_sel(
      estimate_total_catch,
      design,
      use_trips = "all",
      estimator = "ratio-of-means",
      truncate_at = 2.0
    )),
    est_of(quiet_sel(
      estimate_total_catch,
      design,
      use_trips = "all",
      estimator = "ratio-of-means",
      truncate_at = NULL
    ))
  )
})

test_that("mortr is mor with truncation made mandatory", {
  design <- drop_sections_sel(roving_selection_design())

  expect_equal(
    est_of(quiet_sel(
      estimate_total_catch,
      design,
      use_trips = "all",
      estimator = "mortr",
      truncate_at = NULL
    )),
    est_of(quiet_sel(
      estimate_total_catch,
      design,
      use_trips = "all",
      estimator = "mor",
      truncate_at = 0.5
    ))
  )
})

# ---- bus-route and ice never auto-route (GH #270) --------------------------

test_that("a roving bus-route or ice design still produces its complete-trip total", {
  for (design_type in c("bus_route", "ice")) {
    design <- suppressWarnings(suppressMessages(
      build_ht_multispecies_design(design_type, seed = 268L)
    ))

    # These designs estimate a completed-trip Horvitz-Thompson total; "all" is
    # not an estimator there. Gating the auto-route on design_type keeps the
    # flip from happening, rather than happening and being undone downstream --
    # undoing it is what aborts in estimate_catch_rate() (GH #270).
    expect_equal(
      est_of(quiet_sel(estimate_total_catch, as_roving(design))),
      est_of(quiet_sel(estimate_total_catch, design)),
      info = paste(design_type, "roving total diverged from its access total")
    )
  }
})

test_that("bus-route and ice totals refuse a mean-of-ratios estimator", {
  for (design_type in c("bus_route", "ice")) {
    design <- suppressWarnings(suppressMessages(
      build_ht_multispecies_design(design_type, seed = 268L)
    ))

    # Refused rather than ignored: accepting the argument and returning a ratio
    # of HT totals is the defect class this work removes.
    expect_error(
      quiet_sel(estimate_total_catch, design, estimator = "mor"),
      "not available for"
    )
  }
})

# ---- the reduced vocabulary is enforced ------------------------------------

test_that("the totals refuse rate-only trip vocabulary", {
  design <- drop_sections_sel(roving_selection_design())

  # "incomplete" and "diagnostic" support a rate, not a total.
  expect_error(
    quiet_sel(estimate_total_catch, design, use_trips = "incomplete"),
    "Must be one of"
  )
  expect_error(
    quiet_sel(estimate_total_harvest, design, use_trips = "diagnostic"),
    "Must be one of"
  )
  expect_error(
    quiet_sel(estimate_total_release, design, use_trips = "incomplete"),
    "Must be one of"
  )
})

test_that("the totals refuse an estimator with no product-variance form", {
  design <- drop_sections_sel(roving_selection_design())

  # regression returns a slope with a jackknife SE; there is no product form of
  # it here, so it is refused rather than silently downgraded.
  expect_error(
    quiet_sel(estimate_total_catch, design, estimator = "regression"),
    "Must be one of"
  )
})

test_that("truncate_at must be a positive number or NULL", {
  design <- drop_sections_sel(roving_selection_design())

  expect_error(
    quiet_sel(estimate_total_catch, design, estimator = "mor", truncate_at = -1),
    "positive"
  )
})

# ---- harvest and release follow their own rate functions -------------------

test_that("interview_type does not move the harvest or release total", {
  access <- drop_sections_sel(roving_selection_design())
  roving <- as_roving(access)

  # Not an oversight and not a copy of the catch behaviour: estimate_harvest_rate()
  # and estimate_release_rate() take no estimator argument and do not auto-route,
  # so a total that auto-routed would disagree with its own rate function -- the
  # same defect as #268 with the sign flipped. Pinned here so that when those two
  # grow estimator selection (GH #271), this test fails and has to be updated
  # deliberately rather than the totals drifting apart unnoticed.
  expect_equal(
    est_of(quiet_sel(estimate_total_harvest, roving)),
    est_of(quiet_sel(estimate_total_harvest, access))
  )
  expect_equal(
    est_of(quiet_sel(estimate_total_release, roving)),
    est_of(quiet_sel(estimate_total_release, access))
  )
})

# ---- the resolver itself ----------------------------------------------------

test_that("resolve_total_rate_spec routes only catch, and only on standard designs", {
  standard <- as_roving(drop_sections_sel(roving_selection_design()))

  catch_spec <- resolve_total_rate_spec(standard, "catch")
  expect_equal(catch_spec$use_trips, "all")
  expect_equal(catch_spec$estimator, "mor")
  expect_true(catch_spec$roving_auto)

  for (metric in c("harvest", "release")) {
    spec <- resolve_total_rate_spec(standard, metric)
    expect_equal(spec$use_trips, "complete", info = metric)
    expect_equal(spec$estimator, "ratio-of-means", info = metric)
    expect_false(spec$roving_auto, info = metric)
  }

  ht <- standard
  ht$design_type <- "bus_route"
  ht_spec <- resolve_total_rate_spec(ht, "catch")
  expect_equal(ht_spec$use_trips, "complete")
  expect_equal(ht_spec$estimator, "ratio-of-means")
  expect_false(ht_spec$roving_auto)
})

test_that("an access design never auto-routes", {
  access <- drop_sections_sel(roving_selection_design())
  expect_false(resolve_total_rate_spec(access, "catch")$roving_auto)

  # interview_type is NULL on a design built without add_interviews()'s type,
  # and identical(NULL, "roving") must not error or match.
  no_type <- access
  no_type$interview_type <- NULL
  expect_false(resolve_total_rate_spec(no_type, "catch")$roving_auto)
})

test_that("MOR truncation records what it dropped", {
  design <- drop_sections_sel(roving_selection_design())

  # A truncation that reported nothing would be indistinguishable from one that
  # never ran, which is why the count is metadata rather than a message alone.
  truncated <- quiet_sel(truncate_interviews_for_mor, design, "mor", 2.0)
  expect_gt(truncated$mor_n_truncated, 0)
  expect_equal(truncated$mor_truncate_at, 2.0)
  expect_equal(nrow(truncated$interviews), nrow(design$interviews) - truncated$mor_n_truncated)

  # Ratio-of-means must not be reshaped by a threshold it does not use.
  untouched <- truncate_interviews_for_mor(design, "ratio-of-means", 2.0)
  expect_equal(nrow(untouched$interviews), nrow(design$interviews))
})

test_that("a trip with no recorded duration is dropped apart from the short trips", {
  design <- drop_sections_sel(roving_selection_design())
  duration_col <- design$trip_duration_col
  iv <- design$interviews
  iv[[duration_col]][1:3] <- NA_real_
  design <- rebuild_interview_survey(design, iv)

  baseline <- quiet_sel(
    truncate_interviews_for_mor,
    drop_sections_sel(roving_selection_design()),
    "mor",
    2.0
  )
  with_na <- quiet_sel(truncate_interviews_for_mor, design, "mor", 2.0)

  # A missing duration is a missing-data loss, not a truncation decision. Rolled
  # into one count they are indistinguishable, and the repo's own rule is that
  # NA and absence are never silently the same thing. mor_n_truncated must
  # therefore report only trips that were measured and found too short -- which
  # is the same number whether or not other rows lack a duration.
  expect_equal(with_na$mor_n_truncated, baseline$mor_n_truncated)
  expect_equal(
    nrow(with_na$interviews),
    nrow(baseline$interviews) - sum(is.na(iv[[duration_col]]))
  )

  # And the loss is announced rather than absorbed. The short-trip message also
  # fires here; muffling only that one keeps this an assertion about the
  # missing-duration warning rather than about whichever warning happens to be
  # raised first.
  expect_warning(
    suppressMessages(withCallingHandlers(
      truncate_interviews_for_mor(design, "mor", 2.0),
      warning = function(w) {
        if (!grepl("missing trip duration", conditionMessage(w))) {
          invokeRestart("muffleWarning")
        }
      }
    )),
    "missing trip duration"
  )
})
