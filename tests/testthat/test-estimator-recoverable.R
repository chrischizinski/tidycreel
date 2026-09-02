# Which estimator produced this number? (GH #275, GH #284)
#
# Every estimate in this package is a claim about a population, and a claim is
# only checkable if the reader can tell how it was made. Two things stood in
# the way, and they are different failures:
#
#   1. A total's `method` is "product-total-catch" whatever produced it, so
#      ratio-of-means, mean-of-ratios and truncated mean-of-ratios were the
#      same string. Nothing on the returned object separated them: the design
#      slot carries the *normalised* estimator, and "mor" with the default
#      threshold is byte-identical to a "mortr" request there (GH #275).
#   2. The sectioned catch rate named an estimator that had not run. It passed
#      the caller's choice down, computed mean-of-ratios with it, and then
#      labelled the result "ratio-of-means-cpue-sections" (GH #284). That is
#      the roving default path, because the auto-route resolves to "mor".
#
# The claim these tests defend is that the returned object answers "which
# estimator" for itself, on every path that takes one, and that the answer is
# the estimator as the caller asked for it -- "mortr" stays "mortr", because
# mandatory truncation is a different statement from a threshold that happens
# to be set. A test that only checked `method` would pass for the totals while
# the question stayed unanswerable, which is why `estimator` is asserted
# separately from `method` throughout.

recoverable_design <- function(n_interviews = 48L, seed = 275L) {
  # Mixed trip status *within* section, for the reason in test-total-use-trips.R:
  # alternating by row confounds status with the grouping variable, and a MOR
  # path that never sees both statuses in a section is not being exercised.
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

flatten_rec <- function(design) {
  design[["sections"]] <- NULL
  design
}

quiet_rec <- function(f, ...) {
  suppressMessages(suppressWarnings(f(...)))
}

rate_fns <- c(
  "estimate_catch_rate",
  "estimate_harvest_rate",
  "estimate_release_rate"
)

total_fns <- c(
  "estimate_total_catch",
  "estimate_total_harvest",
  "estimate_total_release"
)

# ---- the totals ------------------------------------------------------------

test_that("every total reports the estimator it was given", {
  design <- flatten_rec(recoverable_design())

  for (fn in total_fns) {
    expect_identical(
      quiet_rec(get(fn), design, use_trips = "complete", estimator = "ratio-of-means")$estimator,
      "ratio-of-means",
      info = fn
    )
    expect_identical(
      quiet_rec(get(fn), design, use_trips = "all", estimator = "mor")$estimator,
      "mor",
      info = fn
    )
  }
})

# The discriminating case for the whole issue. `estimator = "mortr"` and
# `estimator = "mor", truncate_at = 0.5` resolve to the same pair and therefore
# to the same number -- that equality is asserted here so the test cannot pass
# by accident on two different estimates. What separates them is the request,
# and the request is exactly what was unrecoverable: a reader asking the
# returned object which one it had been given got the same answer either way.
test_that("a total tells mortr apart from mor at the same threshold", {
  design <- flatten_rec(recoverable_design())

  for (fn in total_fns) {
    mortr <- quiet_rec(get(fn), design, use_trips = "all", estimator = "mortr")
    mor <- quiet_rec(
      get(fn),
      design,
      use_trips = "all",
      estimator = "mor",
      truncate_at = 0.5
    )

    expect_equal(mortr$estimates$estimate, mor$estimates$estimate, info = fn)
    expect_identical(mortr$estimator, "mortr", info = fn)
    expect_identical(mor$estimator, "mor", info = fn)
  }
})

test_that("a sectioned total reports the estimator too", {
  design <- recoverable_design()

  for (fn in total_fns) {
    expect_identical(
      quiet_rec(get(fn), design, use_trips = "all", estimator = "mortr")$estimator,
      "mortr",
      info = fn
    )
  }
})

# `method` is deliberately left alone on the totals: it names the product form,
# not the rate estimator. Pinned so a later change that starts encoding the
# estimator there has to come past this test rather than silently splitting the
# answer across two fields.
test_that("a total's method still names only the product form", {
  design <- flatten_rec(recoverable_design())
  expect_identical(
    quiet_rec(estimate_total_catch, design, use_trips = "all", estimator = "mortr")$method,
    "product-total-catch"
  )
})

# ---- the sectioned rates ---------------------------------------------------

# GH #284. The estimator was used and the label was not, so the check has to
# show the numbers moving: a label test alone would pass against a sections
# path that had stopped honouring `estimator` altogether.
test_that("the sectioned catch rate names the estimator that produced it", {
  design <- recoverable_design()

  rom <- quiet_rec(
    estimate_catch_rate,
    design,
    use_trips = "all",
    estimator = "ratio-of-means"
  )
  mor <- quiet_rec(estimate_catch_rate, design, use_trips = "all", estimator = "mor")

  expect_false(isTRUE(all.equal(rom$estimates$estimate, mor$estimates$estimate)))
  expect_identical(rom$method, "ratio-of-means-cpue-sections")
  expect_identical(mor$method, "mean-of-ratios-cpue-sections")
})

test_that("every sectioned rate reports mandatory truncation in its method", {
  design <- recoverable_design()
  expected <- c(
    estimate_catch_rate = "mean-of-ratios-truncated-cpue-sections",
    estimate_harvest_rate = "mean-of-ratios-truncated-hpue-sections",
    estimate_release_rate = "mean-of-ratios-truncated-rpue-sections"
  )

  for (fn in rate_fns) {
    result <- quiet_rec(get(fn), design, use_trips = "all", estimator = "mortr")
    expect_identical(result$method, unname(expected[[fn]]), info = fn)
    expect_identical(result$estimator, "mortr", info = fn)
  }
})

# The sectioned path normalises "mortr" to "mor" for its own dispatch. If that
# normalisation ever leaked into what runs rather than only into what is
# tested, the numbers would move; they must not.
test_that("carrying mortr into the sections path changes no estimate", {
  design <- recoverable_design()

  for (fn in rate_fns) {
    mortr <- quiet_rec(get(fn), design, use_trips = "all", estimator = "mortr")
    mor <- quiet_rec(
      get(fn),
      design,
      use_trips = "all",
      estimator = "mor",
      truncate_at = 0.5
    )
    expect_equal(mortr$estimates$estimate, mor$estimates$estimate, info = fn)
  }
})

# ---- the flat rates: method and estimator must agree -----------------------

# These paths already reported truncation in `method` before this change. The
# assertion is that the new field says the same thing, so the two cannot drift
# into disagreeing about one result.
test_that("a flat rate's estimator field agrees with its method", {
  design <- flatten_rec(recoverable_design())
  truncated <- c(
    estimate_catch_rate = "mean-of-ratios-truncated-cpue",
    estimate_harvest_rate = "mean-of-ratios-truncated-hpue",
    estimate_release_rate = "mean-of-ratios-truncated-rpue"
  )

  for (fn in rate_fns) {
    result <- quiet_rec(get(fn), design, use_trips = "all", estimator = "mortr")
    expect_identical(result$method, unname(truncated[[fn]]), info = fn)
    expect_identical(result$estimator, "mortr", info = fn)
  }
})

test_that("the grouped and species catch paths report the estimator", {
  design <- flatten_rec(recoverable_design())

  grouped <- quiet_rec(
    estimate_catch_rate,
    design,
    by = day_type,
    use_trips = "all",
    estimator = "mortr"
  )
  species <- quiet_rec(
    estimate_catch_rate,
    design,
    by = species,
    use_trips = "all",
    estimator = "mortr"
  )

  expect_identical(grouped$estimator, "mortr")
  expect_identical(species$estimator, "mortr")
  expect_identical(species$method, "mean-of-ratios-truncated-cpue-species")
})

test_that("the regression path reports itself", {
  design <- flatten_rec(recoverable_design())
  expect_identical(
    quiet_rec(estimate_catch_rate, design, estimator = "regression")$estimator,
    "regression"
  )
})

# ---- absence is not "ratio-of-means" ---------------------------------------

# NULL means the path takes no estimator choice at all. Recording a default
# there would assert something false about an effort total, which is not a rate
# and not a ratio of anything the estimator vocabulary describes -- the same
# distinction `se_components` keeps between an absent component and a zero one.
test_that("a path with no estimator choice records no estimator", {
  design <- flatten_rec(recoverable_design())
  expect_null(quiet_rec(estimate_effort, design)$estimator)
})

test_that("the constructor refuses a non-string estimator", {
  expect_error(
    new_creel_estimates(
      estimates = data.frame(estimate = 1, se = 1, ci_lower = 0, ci_upper = 2, n = 1L),
      estimator = c("mor", "mortr")
    ),
    "estimator must be NULL or a single string"
  )
})
