# Does a sectioned design actually run the estimator it was asked for? (GH #285, #290)
#
# `estimate_catch_rate()` dispatches on sections BEFORE it dispatches on the
# regression estimator, and it dispatches on species before that. Two requests
# therefore never reached the regression internals at all:
#
#   - a sectioned design asking for `estimator = "regression"` (GH #285)
#   - any design asking for it with `species` in `by=` (GH #290), flat included
#
# Both fell through to `estimate_cpue_total()`, whose estimator test is
# `estimator %in% c("mor", "mortr")`, so `"regression"` landed in the
# ratio-of-means branch. No error, no warning, and a believable number.
#
# The visible symptom was in `compare_cpue_estimators()`, whose whole purpose is
# making estimator divergence visible: on every sectioned design it reported the
# regression row as numerically identical to the ratio-of-means row, and with a
# jackknife SE attached, because it passes `variance = "jackknife"` for that row.
# A ratio-of-means point estimate carrying a jackknife SE under the label
# "regression" corresponds to no estimator in the literature.
#
# The claim these tests defend is that a sectioned regression request runs the
# regression estimator, per section, and that the species request -- which has no
# regression form to route to -- is refused rather than answered with a different
# estimator.
#
# The discriminating check is NOT "regression differs from ratio-of-means". A
# section-level bug could produce a different-but-wrong number and pass that.
# Each section's estimate is compared against the same regression run standalone
# on that section's interviews, which is what "per-section regression" means.

sec_reg_design <- function(n = 48L, seed = 285L) {
  set.seed(seed)
  make_sectioned_species_design(n)
}

quiet_reg <- function(f, ...) suppressMessages(suppressWarnings(f(...)))

flatten_to_section <- function(design, section) {
  section_col <- design$section_col
  keep <- design$interviews[[section_col]] == section
  flat <- design
  flat[["sections"]] <- NULL
  rebuild_interview_survey(flat, design$interviews[keep, , drop = FALSE])
}

# ---- the estimator asked for is the one that runs -------------------------

test_that("a sectioned regression request runs regression, not ratio-of-means", {
  design <- sec_reg_design()

  reg <- quiet_reg(estimate_catch_rate, design, estimator = "regression")
  rom <- quiet_reg(estimate_catch_rate, design, estimator = "ratio-of-means")

  # The defect was numerical identity: `all.equal` returned TRUE on every section
  # because the ratio-of-means branch had run under the regression label.
  expect_false(isTRUE(all.equal(reg$estimates$estimate, rom$estimates$estimate)))
  expect_identical(reg$method, "regression-cpue-sections")
  expect_identical(reg$estimator, "regression")
})

test_that("each section's estimate is that section's own regression", {
  design <- sec_reg_design()
  reg <- quiet_reg(estimate_catch_rate, design, estimator = "regression")

  # The discriminating assertion. "Differs from ratio-of-means" would also pass
  # if the sections path computed a regression over the WRONG rows -- pooled
  # across sections, say, or on an unfiltered frame. Comparing against the same
  # estimator run standalone on one section's interviews pins the partition as
  # well as the estimator, and the jackknife SE with it.
  for (sec in unique(design$interviews[[design$section_col]])) {
    standalone <- quiet_reg(
      estimate_catch_rate,
      flatten_to_section(design, sec),
      estimator = "regression"
    )
    row <- reg$estimates[reg$estimates$section == sec, ]

    expect_equal(row$estimate, standalone$estimates$estimate, info = sec)
    expect_equal(row$se, standalone$estimates$se, info = sec)
    expect_equal(row$n, standalone$estimates$n, info = sec)
  }
})

test_that("force_origin reaches the sections path", {
  design <- sec_reg_design()

  # An argument that is accepted and then dropped is the same class of defect as
  # the estimator itself being dropped, and the sections path had no
  # `force_origin` parameter at all before this change. Freeing the intercept
  # moves the slope a long way on this fixture, so a dropped argument cannot
  # hide behind a small difference.
  forced <- quiet_reg(estimate_catch_rate, design, estimator = "regression", force_origin = TRUE)
  free <- quiet_reg(estimate_catch_rate, design, estimator = "regression", force_origin = FALSE)

  expect_false(isTRUE(all.equal(forced$estimates$estimate, free$estimates$estimate)))
})

test_that("grouping within sections runs regression per group per section", {
  design <- sec_reg_design()

  grouped <- quiet_reg(estimate_catch_rate, design, by = day_type, estimator = "regression")
  grouped_rom <- quiet_reg(estimate_catch_rate, design, by = day_type, estimator = "ratio-of-means")

  expect_true(all(c("section", "day_type") %in% names(grouped$estimates)))
  expect_false(isTRUE(all.equal(grouped$estimates$estimate, grouped_rom$estimates$estimate)))
  expect_identical(grouped$method, "regression-cpue-sections")
})

test_that("a sectioned regression result reports the variance method that ran", {
  design <- sec_reg_design()
  reg <- quiet_reg(estimate_catch_rate, design, estimator = "regression")

  # The slope's SE is a leave-one-out jackknife computed inside the regression
  # internals; `variance` is never consulted on that path. Recording the caller's
  # Taylor default would name a method that did not run -- the same class of
  # mislabel as #284, one field over.
  expect_identical(reg$variance_method, "jackknife")

  # And the default is genuinely Taylor for the estimators that do use it, so
  # this is not asserting a constant.
  rom <- quiet_reg(estimate_catch_rate, design, estimator = "ratio-of-means")
  expect_identical(rom$variance_method, "taylor")
})

# ---- the species request is refused, not silently substituted -------------

test_that("species plus regression is refused on a flat design", {
  design <- sec_reg_design()
  flat <- design
  flat[["sections"]] <- NULL

  # GH #290, and NOT a sections defect: the species dispatch sits above the
  # regression route on every design. Before this, the call returned
  # ratio-of-means numbers labelled "ratio-of-means-cpue-species" while the
  # caller had asked for regression.
  expect_error(
    quiet_reg(estimate_catch_rate, flat, by = species, estimator = "regression"),
    class = "creel_error_species_regression"
  )
})

test_that("species plus regression is refused on a sectioned design", {
  design <- sec_reg_design()

  # The sections path resolves its own `by=`, so the refusal has to be made
  # there too. Fixing only the flat path would leave the sectioned species
  # request silently wrong inside the code path #285 adds.
  expect_error(
    quiet_reg(estimate_catch_rate, design, by = species, estimator = "regression"),
    class = "creel_error_species_regression"
  )
})

test_that("species still works with the estimators that have a species form", {
  design <- sec_reg_design()

  # The refusal must be narrow. A guard that fired on every species request, or
  # on every regression request, would pass the two tests above while breaking
  # the estimators that do have a species form.
  # `use_trips` is named per estimator because this fixture has no incomplete
  # trips, and mean-of-ratios auto-routes to `use_trips = "incomplete"` when it
  # is left at the default. That abort is about the fixture, not the refusal, and
  # letting it fire here would test nothing.
  result_rom <- quiet_reg(
    estimate_catch_rate, design,
    by = species, estimator = "ratio-of-means", use_trips = "complete"
  )
  expect_s3_class(result_rom, "creel_estimates")
  expect_true(nrow(result_rom$estimates) > 0L)

  result_mor <- quiet_reg(
    estimate_catch_rate, design,
    by = species, estimator = "mor", use_trips = "all"
  )
  expect_s3_class(result_mor, "creel_estimates")
  expect_true(nrow(result_mor$estimates) > 0L)

  # And regression without species is unaffected on the same design.
  expect_identical(
    quiet_reg(estimate_catch_rate, design, estimator = "regression")$method,
    "regression-cpue-sections"
  )
})

# ---- the function that exists to show divergence now shows it -------------

test_that("compare_cpue_estimators reports three distinct estimators on a sectioned design", {
  design <- sec_reg_design()
  cmp <- quiet_reg(compare_cpue_estimators, design)

  rom <- cmp$estimate[cmp$cpue_method == "rom"]
  reg <- cmp$estimate[cmp$cpue_method == "regression"]

  # This is the user-visible symptom of #285. The comparison table reported rom
  # and regression as identical to seven decimal places on every sectioned
  # design, from the one function whose documented purpose is making estimator
  # divergence visible.
  expect_length(reg, length(rom))
  expect_false(isTRUE(all.equal(rom, reg)))
})
