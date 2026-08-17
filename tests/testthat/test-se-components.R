# Tests for named standard-error components (GH #141) ----
#
# The invariant under test throughout: a component name is absent when the path
# has no such component, NA_real_ when it applies but cannot be measured, and a
# finite number only when it was measured. Never 0, which cannot be told apart
# from a component that never propagated at all.

# Helpers ---------------------------------------------------------------------

make_component_camera_design <- function() {
  cal <- data.frame(
    date = as.Date(c(
      "2024-06-03",
      "2024-06-04",
      "2024-06-05",
      "2024-06-08",
      "2024-06-09"
    )),
    day_type = c("weekday", "weekday", "weekday", "weekend", "weekend"),
    stringsAsFactors = FALSE
  )
  d <- suppressWarnings(
    creel_design(
      cal,
      date = date,
      strata = day_type, # nolint
      survey_type = "camera",
      camera_mode = "counter"
    )
  )
  counts <- data.frame(
    date = cal$date,
    day_type = cal$day_type,
    ingress_count = c(48L, 55L, 43L, 80L, 75L),
    camera_status = rep("operational", 5L),
    stringsAsFactors = FALSE
  )
  suppressWarnings(add_counts(d, counts))
}

# Weekend has one paired interview/count day, so its calibration ratio has no
# measurable spread (GH #136).
make_thin_interviews <- function() {
  data.frame(
    date = as.Date(c("2024-06-03", "2024-06-04", "2024-06-08")),
    day_type = c("weekday", "weekday", "weekend"),
    hours_fished = c(3.5, 4.0, 2.5),
    stringsAsFactors = FALSE
  )
}

# The same weekend calibration ratio -- 2.5/80 = 4.84375/155 = 0.03125 -- spread
# over two paired days, so rho and therefore the count-sampling term are
# unchanged and only the calibration variance becomes measurable.
make_matched_rho_interviews <- function() {
  data.frame(
    date = as.Date(c("2024-06-03", "2024-06-04", "2024-06-08", "2024-06-09")),
    day_type = c("weekday", "weekday", "weekend", "weekend"),
    hours_fished = c(3.5, 4.0, 2.5, 2.34375),
    stringsAsFactors = FALSE
  )
}

make_well_calibrated_interviews <- function() {
  data.frame(
    date = as.Date(c(
      "2024-06-03",
      "2024-06-03",
      "2024-06-04",
      "2024-06-08",
      "2024-06-09"
    )),
    day_type = c("weekday", "weekday", "weekday", "weekend", "weekend"),
    hours_fished = c(3.5, 2.0, 4.0, 2.5, 3.0),
    stringsAsFactors = FALSE
  )
}

# Camera: the knowable half of an NA standard error (GH #141) ------------------

test_that("COMP-01: a thin stratum leaves the count-sampling component knowable", {
  # #136 made the total SE NA when any stratum's calibration variance is
  # unknown, and that must stay: Var = sum_h [rho_h^2 Var(T_h) + T_h^2
  # Var(rho_h)], so an unknown term makes the sum unknown and a partial sum
  # would be a lower bound wearing the SE's name. What #141 adds is that the
  # count-sampling half is still perfectly well known, so the NA can say which
  # half is missing instead of only blocking.
  d <- make_component_camera_design()
  result <- suppressWarnings(
    est_effort_camera(d, interviews = make_thin_interviews(), n_anglers = 1)
  )

  expect_true(is.na(result$estimates$se))
  expect_true(is.finite(result$se_components$count_sampling))
  expect_gt(result$se_components$count_sampling, 0)
})

test_that("COMP-02: the unmeasurable calibration component is NA, not 0 and not dropped", {
  # A 0 here would read as "the calibration is known exactly" -- the very claim
  # #136 exists to refuse -- and an omitted name would read as "this path has no
  # calibration", which is false. Both mistakes are invisible downstream, so
  # they are asserted separately rather than through is.na() alone.
  d <- make_component_camera_design()
  result <- suppressWarnings(
    est_effort_camera(d, interviews = make_thin_interviews(), n_anglers = 1)
  )

  expect_true("calibration" %in% names(result$se_components))
  expect_true(is.na(result$se_components$calibration))
  expect_false(isTRUE(result$se_components$calibration == 0))
})

test_that("COMP-03: the count-sampling component does not depend on whether calibration is measurable", {
  # The two interview tables give the weekend stratum the same calibration
  # ratio (2.5/80 == 4.84375/155), one over a single paired day and one over
  # two. Only the calibration variance differs. If the count-sampling component
  # moved between them it would be contaminated by the calibration term and
  # could not be reported while that term is unknown -- which is the whole
  # premise of the split.
  d <- make_component_camera_design()
  thin <- suppressWarnings(
    est_effort_camera(d, interviews = make_thin_interviews(), n_anglers = 1)
  )
  matched <- suppressWarnings(
    est_effort_camera(
      d,
      interviews = make_matched_rho_interviews(),
      n_anglers = 1
    )
  )

  expect_identical(
    thin$se_components$count_sampling,
    matched$se_components$count_sampling
  )
  expect_true(is.na(thin$se_components$calibration))
  expect_true(is.finite(matched$se_components$calibration))
  expect_true(is.na(thin$estimates$se))
  expect_true(is.finite(matched$estimates$se))
})

test_that("COMP-04: the reported components reconstruct the standard error exactly", {
  # The components are a split of the same delta-method sum the SE comes from,
  # not a parallel recomputation, so they must agree to the last bit. Equality
  # rather than tolerance: a tolerance here would hide exactly the drift
  # between a reported component and the number it claims to be part of that
  # #134 was.
  d <- make_component_camera_design()
  result <- suppressWarnings(
    est_effort_camera(
      d,
      interviews = make_well_calibrated_interviews(),
      n_anglers = 1
    )
  )

  expect_identical(
    result$estimates$se,
    sqrt(
      result$se_components$count_sampling^2 +
        result$se_components$calibration^2
    )
  )
})

test_that("COMP-05: the uncalibrated raw-count path reports calibration as NA, not absent", {
  # This assertion is inverted from what it was, deliberately.
  #
  # It previously required `calibration` to be ABSENT here, on the reasoning
  # that h_open is a supplied constant and no calibration ratio applies to this
  # branch. The author ruling of 2026-08-17 is that a raw camera count is not
  # pre-corrected, so a calibration DOES apply -- the branch simply assumes it
  # equals 1 and never measures it. That makes this the "applies but is
  # unknown" case, which is NA, and no longer the "does not apply" case, which
  # is absent (GH #141, #158).
  #
  # The two claims remain distinct and an analyst still acts on them
  # differently; what changed is which one this branch is making.
  d <- make_component_camera_design()
  result <- suppressWarnings(est_effort_camera(d, h_open = 14, calibration = "none"))

  expect_true("calibration" %in% names(result$se_components))
  expect_true(is.na(result$se_components$calibration))
  # Never 0: a zero would be indistinguishable from having propagated the
  # calibration's uncertainty and found none.
  expect_false(identical(result$se_components$calibration, 0))

  # The count-sampling half stays reportable, so the NA says which half is
  # unknown instead of only blocking.
  expect_true(is.finite(result$se_components$count_sampling))
  # The total goes NA with it: a sum missing an unknown term is a lower bound,
  # not an SE.
  expect_true(is.na(result$estimates$se))
})

# Constructor: the party-size component has one write point --------------------

test_that("COMP-06: se_expansion is mirrored into se_components", {
  # #134 was a reported component disagreeing with the SE that contained it.
  # The defence is that nothing writes the party-size component except the
  # constructor, from se_expansion, so the two representations cannot drift.
  scalar <- new_creel_estimates(
    data.frame(estimate = 1, se = 2),
    se_expansion = 0.5
  )
  expect_identical(scalar$se_components, list(party_size = 0.5))

  # Grouped estimates carry one value per group. A flat named numeric could not
  # tell three components apart from one component over three groups, which is
  # why the slot is a list of numeric vectors.
  grouped <- new_creel_estimates(
    data.frame(estimate = c(1, 2), se = c(2, 3)),
    se_expansion = c(0.5, 0.25)
  )
  expect_identical(grouped$se_components, list(party_size = c(0.5, 0.25)))
})

test_that("COMP-07: no components slot when nothing was propagated", {
  # NULL rather than an empty list, for the same reason a component is absent
  # rather than 0: an empty container invites a `length()` test that reads as
  # "measured nothing".
  bare <- new_creel_estimates(data.frame(estimate = 1, se = 2))
  expect_null(bare$se_components)
})

test_that("COMP-08: supplying party_size directly is refused", {
  # Two write points is how the reported value and the SE drift apart. The
  # constructor owns this name.
  expect_error(
    new_creel_estimates(
      data.frame(estimate = 1, se = 2),
      se_components = list(party_size = 0.5)
    ),
    class = "creel_error_se_component_reserved"
  )
})

test_that("COMP-09: malformed component containers are refused", {
  # An unnamed entry cannot be reported, and a non-numeric one cannot be a
  # standard error. Both would otherwise reach print() and fail there instead.
  expect_error(
    new_creel_estimates(
      data.frame(estimate = 1, se = 2),
      se_components = list(0.5)
    ),
    "fully named"
  )
  expect_error(
    new_creel_estimates(
      data.frame(estimate = 1, se = 2),
      se_components = list(count_sampling = 0.5, calibration = "unknown")
    ),
    "must be numeric"
  )
})

# Print: the relationship to `se` is derived, not stored ------------------------

test_that("COMP-10: a known component prints as known even when the total is NA", {
  # The point of #141: the print must distinguish "this component is unknown,
  # which is why se is NA" from "this component is known, but se is NA because
  # a different one is not". Reporting both as a bare number, or suppressing
  # the knowable one, throws away the only information the NA carries.
  d <- make_component_camera_design()
  result <- suppressWarnings(
    est_effort_camera(d, interviews = make_thin_interviews(), n_anglers = 1)
  )
  printed <- cli::cli_fmt(print(result))

  expect_true(any(grepl("Count-sampling SE", printed, fixed = TRUE)))
  expect_true(any(grepl("known, but", printed, fixed = TRUE)))
  expect_true(any(grepl("Calibration SE", printed, fixed = TRUE)))
  expect_true(any(grepl("unknown, so", printed, fixed = TRUE)))
})

test_that("COMP-11: a component of a finite standard error prints as included in it", {
  finite <- new_creel_estimates(
    data.frame(estimate = 1, se = 2),
    se_expansion = 0.5
  )
  printed <- cli::cli_fmt(print(finite))

  expect_true(
    any(grepl("Party-size expansion SE: 0.5", printed, fixed = TRUE))
  )
  expect_true(any(grepl("included in", printed, fixed = TRUE)))
})

test_that("COMP-12: a partly measurable grouped component does not claim the whole se is NA", {
  # A component carries one value per group, so it can be measurable for some
  # groups and not others. The flat claim "so se is NA" would be false for the
  # groups where it is finite, and groups are the unit the analyst acts on.
  partial <- new_creel_estimates(
    data.frame(estimate = c(1, 2), se = c(2, NA_real_)),
    se_expansion = c(0.5, NA_real_)
  )
  printed <- cli::cli_fmt(print(partial))

  expect_true(any(grepl("unknown for some groups", printed, fixed = TRUE)))
  expect_false(any(grepl("(unknown, so", printed, fixed = TRUE)))
})

test_that("COMP-13: an unlabelled component prints under its own name", {
  # Components will be added by later estimators. One that reaches print()
  # before it reaches the label table must still be reported: an unlabelled
  # component is information, a silently dropped one is not.
  novel <- new_creel_estimates(
    data.frame(estimate = 1, se = 2),
    se_components = list(future_component = 0.25)
  )
  printed <- cli::cli_fmt(print(novel))

  expect_true(any(grepl("future_component: 0.25", printed, fixed = TRUE)))
})
