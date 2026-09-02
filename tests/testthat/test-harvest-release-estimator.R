# Estimator selection on the harvest and release rates (GH #271)
#
# #268 gave the totals a rule: each resolves its rate spec by the same rule its
# own rate function uses. That closed the catch half and left the harvest and
# release half open, because `estimate_harvest_rate()` and
# `estimate_release_rate()` had no estimator to follow -- mean-of-ratios HPUE
# and RPUE existed nowhere outside the bus-route path.
#
# Hoenig et al. (1997) recommend the truncated mean of ratios for a roving
# survey because the clerk intercepts trips mid-stream. That argument is about
# the interview, not about which fish are counted: harvest and release are
# recorded in the same interception and are length-biased the same way. So the
# rate functions gained `estimator`, and the totals follow through the single
# resolver rather than through a per-metric special case.

estimator_design <- function(n_interviews = 48L, seed = 271L) {
  # Mixed trip status *within* section, for the reason in test-total-use-trips.R:
  # alternating by row confounds status with the grouping variable.
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

as_roving_est <- function(design) {
  design$interview_type <- "roving"
  design
}

flatten_est <- function(design) {
  design[["sections"]] <- NULL
  design
}

quiet_est <- function(f, ...) suppressMessages(suppressWarnings(f(...)))

first_est <- function(x) x$estimates$estimate[1]

# ---- the estimator reaches every path, for every metric --------------------

test_that("harvest and release rates honour the estimator on every path", {
  sectioned <- estimator_design()
  flat <- flatten_est(sectioned)
  species_col <- sectioned$species_col %||% "species"

  paths <- list(
    ungrouped = list(design = flat, args = list()),
    grouped = list(design = flat, args = list(by = rlang::sym("day_type"))),
    species = list(design = flat, args = list(by = rlang::sym(species_col))),
    sectioned = list(design = sectioned, args = list())
  )

  for (fn in c("estimate_harvest_rate", "estimate_release_rate")) {
    f <- get(fn)
    for (nm in names(paths)) {
      design <- paths[[nm]]$design
      args <- paths[[nm]]$args

      mor <- do.call(
        quiet_est,
        c(list(f, design), args, list(use_trips = "all", estimator = "mor"))
      )
      rom <- do.call(
        quiet_est,
        c(
          list(f, design),
          args,
          list(use_trips = "all", estimator = "ratio-of-means")
        )
      )

      # Trip set held fixed, so only the estimator differs. Comparing against the
      # plain default instead would vary the trip set too, and a path that
      # ignored the estimator would still move and still pass -- the trap that
      # let two mutants survive on #268.
      expect_false(
        isTRUE(all.equal(first_est(mor), first_est(rom))),
        info = paste(fn, "ignored the estimator on the", nm, "path")
      )
    }
  }
})

test_that("a roving design routes harvest and release to all-trip MOR", {
  sectioned <- estimator_design()
  flat <- flatten_est(sectioned)
  species_col <- sectioned$species_col %||% "species"

  paths <- list(
    ungrouped = list(design = flat, args = list()),
    grouped = list(design = flat, args = list(by = rlang::sym("day_type"))),
    species = list(design = flat, args = list(by = rlang::sym(species_col))),
    sectioned = list(design = sectioned, args = list())
  )

  for (fn in c("estimate_harvest_rate", "estimate_release_rate")) {
    f <- get(fn)
    for (nm in names(paths)) {
      design <- paths[[nm]]$design
      args <- paths[[nm]]$args

      auto <- do.call(quiet_est, c(list(f, as_roving_est(design)), args))
      explicit <- do.call(
        quiet_est,
        c(list(f, design), args, list(use_trips = "all", estimator = "mor"))
      )

      # "Auto-route" means exactly that pair, so the equality is the definition
      # rather than an approximation.
      expect_equal(
        first_est(auto),
        first_est(explicit),
        info = paste(fn, "auto-route wrong on the", nm, "path")
      )
    }
  }
})

test_that("naming use_trips or estimator suppresses the roving auto-route", {
  flat <- flatten_est(estimator_design())
  roving <- as_roving_est(flat)

  for (fn in c("estimate_harvest_rate", "estimate_release_rate")) {
    f <- get(fn)
    access_default <- first_est(quiet_est(f, flat))

    expect_equal(
      first_est(quiet_est(f, roving, use_trips = "complete")),
      access_default,
      info = fn
    )
    expect_equal(
      first_est(quiet_est(f, roving, estimator = "ratio-of-means")),
      access_default,
      info = fn
    )
  }
})

# ---- the returned object says which estimator produced it ------------------

test_that("the method names the estimator that ran", {
  flat <- flatten_est(estimator_design())

  # A number whose estimator cannot be recovered from the object it came back in
  # is the reporting half of the same defect: two different estimators returning
  # results that look identical.
  expect_equal(
    quiet_est(estimate_harvest_rate, flat)$method,
    "ratio-of-means-hpue"
  )
  expect_equal(
    quiet_est(
      estimate_harvest_rate,
      flat,
      use_trips = "all",
      estimator = "mor"
    )$method,
    "mean-of-ratios-hpue"
  )
  expect_equal(
    quiet_est(estimate_release_rate, flat)$method,
    "ratio-of-means-rpue"
  )
  expect_equal(
    quiet_est(
      estimate_release_rate,
      flat,
      use_trips = "all",
      estimator = "mor"
    )$method,
    "mean-of-ratios-rpue"
  )

  # mortr normalises to "mor" so every downstream branch can test one string,
  # which is why the truncated label has to be restored deliberately. Without
  # this, `estimator = "mortr"` and `estimator = "mor"` return objects that are
  # indistinguishable, and the truncated entries in the print, format and
  # autoplot label tables are unreachable.
  expect_equal(
    quiet_est(
      estimate_harvest_rate,
      flat,
      use_trips = "all",
      estimator = "mortr"
    )$method,
    "mean-of-ratios-truncated-hpue"
  )
  expect_equal(
    quiet_est(
      estimate_release_rate,
      flat,
      use_trips = "all",
      estimator = "mortr"
    )$method,
    "mean-of-ratios-truncated-rpue"
  )

  # The roving auto-route resolves to plain "mor", not "mortr" -- truncation
  # runs, but the caller did not ask for it to be mandatory. Same as
  # estimate_catch_rate(), whose auto-route also labels untruncated.
  expect_equal(
    quiet_est(estimate_harvest_rate, as_roving_est(flat))$method,
    "mean-of-ratios-hpue"
  )
})

test_that("the MOR diagnostic banner names the quantity it measured", {
  flat <- flatten_est(estimator_design())

  # `estimate_release_rate()` returns the object `estimate_cpue_*()` built, so
  # after GH #271 an RPUE result inherits the MOR diagnostic banner. The banner
  # named CPUE unconditionally, which was true only while mean-of-ratios reached
  # the catch rate alone.
  rpue <- quiet_est(
    estimate_release_rate,
    flat,
    use_trips = "all",
    estimator = "mor"
  )
  # Asserted on the sentence that names the quantity. That sentence used to be
  # the "Complete trips preferred for {rate} estimation." caveat, which now
  # appears only on the incomplete-trip path -- and release never takes that
  # path. The claim is unchanged: the label is derived, not hardcoded (GH #276).
  banner <- paste(format(rpue), collapse = " ")
  expect_match(banner, "RPUE ratios")
  expect_false(grepl("CPUE", banner, fixed = TRUE))

  # The catch rate's own banner must not have moved.
  cpue <- quiet_est(
    estimate_catch_rate,
    flat,
    use_trips = "all",
    estimator = "mor"
  )
  expect_match(paste(format(cpue), collapse = " "), "CPUE ratios")
})

# ---- truncation ------------------------------------------------------------

test_that("truncate_at reaches the harvest and release MOR estimators", {
  flat <- flatten_est(estimator_design())

  for (fn in c("estimate_harvest_rate", "estimate_release_rate")) {
    f <- get(fn)
    loose <- quiet_est(
      f, flat, use_trips = "all", estimator = "mor", truncate_at = NULL
    )
    tight <- quiet_est(
      f, flat, use_trips = "all", estimator = "mor", truncate_at = 2.0
    )
    expect_false(
      isTRUE(all.equal(first_est(loose), first_est(tight))),
      info = paste(fn, "ignored truncate_at")
    )
  }
})

test_that("mortr is mor with truncation made mandatory", {
  flat <- flatten_est(estimator_design())

  for (fn in c("estimate_harvest_rate", "estimate_release_rate")) {
    f <- get(fn)
    expect_equal(
      first_est(quiet_est(
        f, flat, use_trips = "all", estimator = "mortr", truncate_at = NULL
      )),
      first_est(quiet_est(
        f, flat, use_trips = "all", estimator = "mor", truncate_at = 0.5
      )),
      info = fn
    )
  }
})

test_that("an unrecognised estimator is refused on both rates", {
  flat <- flatten_est(estimator_design())

  for (fn in c("estimate_harvest_rate", "estimate_release_rate")) {
    expect_error(
      quiet_est(get(fn), flat, estimator = "regression"),
      "Must be one of",
      info = fn
    )
  }
})

# ---- bus-route and ice are untouched ---------------------------------------

test_that("a roving bus-route or ice design still gives its complete-trip rate", {
  for (design_type in c("bus_route", "ice")) {
    design <- suppressWarnings(suppressMessages(
      build_ht_multispecies_design(design_type, seed = 271L)
    ))

    # These return before the resolution block, so the auto-route never runs --
    # which is why this function does not reproduce GH #270, where the same
    # route fires first and is then undone with a flag it has already cleared.
    for (fn in c("estimate_harvest_rate", "estimate_release_rate")) {
      f <- get(fn)
      expect_equal(
        first_est(quiet_est(f, as_roving_est(design))),
        first_est(quiet_est(f, design)),
        info = paste(fn, design_type)
      )
    }
  }
})

# ---- the totals inherit it, which is the point of #268's resolver ----------

test_that("the harvest and release totals follow their own rate functions", {
  sectioned <- estimator_design()
  flat <- flatten_est(sectioned)
  species_col <- sectioned$species_col %||% "species"

  paths <- list(
    ungrouped = list(design = flat, args = list()),
    grouped = list(design = flat, args = list(by = rlang::sym("day_type"))),
    species = list(design = flat, args = list(by = rlang::sym(species_col))),
    sectioned = list(design = sectioned, args = list())
  )

  for (fn in c("estimate_total_harvest", "estimate_total_release")) {
    f <- get(fn)
    for (nm in names(paths)) {
      design <- paths[[nm]]$design
      args <- paths[[nm]]$args

      auto <- do.call(quiet_est, c(list(f, as_roving_est(design)), args))
      mor <- do.call(
        quiet_est,
        c(list(f, design), args, list(use_trips = "all", estimator = "mor"))
      )
      rom <- do.call(
        quiet_est,
        c(
          list(f, design),
          args,
          list(use_trips = "all", estimator = "ratio-of-means")
        )
      )

      expect_equal(
        first_est(auto),
        first_est(mor),
        info = paste(fn, "auto-route wrong on the", nm, "path")
      )
      expect_false(
        isTRUE(all.equal(first_est(mor), first_est(rom))),
        info = paste(fn, "ignored the estimator on the", nm, "path")
      )
    }
  }
})

test_that("an unstratified design's totals honour the estimator", {
  # The stratified-sum helpers branch on `length(by_vars) == 0L`, and every other
  # fixture in this file carries `strata_cols = "day_type"`, so the length-0
  # branch is never entered. A mutant that dropped the estimator from exactly
  # that branch survived the whole file: the paths were covered, the *branch*
  # was not. An unstratified design is the only thing that reaches it.
  flat <- flatten_est(estimator_design())
  unstratified <- flat
  unstratified$strata_cols <- character(0)
  unstratified$interview_survey <- build_interview_survey(
    unstratified$interviews,
    strata = NULL
  )

  for (fn in c(
    "estimate_total_harvest",
    "estimate_total_release",
    "estimate_total_catch"
  )) {
    f <- get(fn)
    mor <- quiet_est(
      f, unstratified, use_trips = "all", estimator = "mor"
    )
    rom <- quiet_est(
      f, unstratified, use_trips = "all", estimator = "ratio-of-means"
    )
    expect_false(
      isTRUE(all.equal(first_est(mor), first_est(rom))),
      info = paste(fn, "ignored the estimator on an unstratified design")
    )
  }
})

test_that("resolve_total_rate_spec now routes all three metrics alike", {
  roving <- as_roving_est(flatten_est(estimator_design()))

  # Before #271 only "catch" auto-routed, because only estimate_catch_rate() had
  # an estimator to follow. The rule was always "match your own rate function";
  # what changed is that the other two now have one.
  for (metric in c("catch", "harvest", "release")) {
    spec <- resolve_total_rate_spec(roving, metric)
    expect_equal(spec$use_trips, "all", info = metric)
    expect_equal(spec$estimator, "mor", info = metric)
    expect_true(spec$roving_auto, info = metric)
  }

  # Bus-route and ice still never route, for any metric.
  ht <- roving
  ht$design_type <- "ice"
  for (metric in c("catch", "harvest", "release")) {
    expect_false(resolve_total_rate_spec(ht, metric)$roving_auto, info = metric)
  }
})

test_that("bus-route and ice totals refuse a mean-of-ratios estimator", {
  for (design_type in c("bus_route", "ice")) {
    design <- suppressWarnings(suppressMessages(
      build_ht_multispecies_design(design_type, seed = 271L)
    ))
    for (fn in c("estimate_total_harvest", "estimate_total_release")) {
      expect_error(
        quiet_est(get(fn), design, estimator = "mor"),
        "not available for",
        info = paste(fn, design_type)
      )

      # The resolver normalises "mortr" to "mor" before this refusal runs, so
      # the message has to carry the string the caller typed. Naming a value
      # they never passed sends them looking for a call they did not make.
      expect_error(
        quiet_est(get(fn), design, estimator = "mortr"),
        "mortr",
        info = paste(fn, design_type)
      )
    }
  }
})
