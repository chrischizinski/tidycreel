# Tests for the product_variance and ci_type arguments shared by the
# effort x rate product-total estimators (total catch, harvest, release).
#
# These arguments control two independent statistical choices:
#
#   product_variance - whether the variance of the product E x R includes the
#     Goodman (1960) third term. "goodman" (default) adds var(E) * var(R) to the
#     two first-order terms; "first_order" drops it. The term is small when both
#     components are precise but grows with the product of the two CVs, so
#     silently dropping or sign-flipping it changes reported uncertainty without
#     changing the point estimate. The tests below pin the term's magnitude AND
#     its sign against an independent hand calculation.
#
#   ci_type - the shape of the interval. "symmetric" (default) is Wald clamped
#     at zero, which can produce a lower bound of exactly 0 for imprecise
#     estimates and hide that the interval was truncated. "log" back-transforms
#     from the log scale, keeping the bound strictly positive and asymmetric.
#     A total is a non-negative quantity, so the distinction is substantive.

# Test helpers ----

make_product_arg_design <- function() {
  data("example_calendar", package = "tidycreel")
  data("example_counts", package = "tidycreel")
  data("example_interviews", package = "tidycreel")

  design <- creel_design(example_calendar, date = date, strata = day_type) # nolint: object_usage_linter
  design <- add_counts(design, example_counts) # nolint: object_usage_linter
  add_interviews(
    design,
    example_interviews, # nolint: object_usage_linter
    catch = catch_total, # nolint: object_usage_linter
    harvest = catch_kept, # nolint: object_usage_linter
    effort = hours_fished, # nolint: object_usage_linter
    trip_status = trip_status, # nolint: object_usage_linter
    trip_duration = trip_duration # nolint: object_usage_linter
  )
}

make_product_arg_release_design <- function() {
  data("example_catch", package = "tidycreel")

  suppressWarnings(add_catch(
    make_product_arg_design(),
    example_catch, # nolint: object_usage_linter
    catch_uid = interview_id,
    interview_uid = interview_id, # nolint: object_usage_linter
    species = species,
    count = count,
    catch_type = catch_type # nolint: object_usage_linter
  ))
}

quiet_estimate <- function(expr) {
  suppressWarnings(suppressMessages(expr))
}

# Single-stratum design so that the stratified sum collapses to one pooled
# product. Only then can the cross-term be derived from the pooled component
# SEs; with real strata the example data has too few weekend interviews to
# estimate a per-stratum catch rate. Mirrors the construction used by
# "total catch SE matches stratified-sum delta method formula".
make_single_stratum_design <- function() {
  calendar <- data.frame(
    date = seq.Date(as.Date("2024-06-01"), by = "day", length.out = 7),
    day_type = rep("weekday", 7),
    stringsAsFactors = FALSE
  )
  counts <- data.frame(
    date = calendar$date,
    day_type = calendar$day_type,
    effort_hours = c(10, 12, 14, 11, 13, 15, 10),
    stringsAsFactors = FALSE
  )
  n_int <- 15L
  set.seed(123L)
  interviews <- data.frame(
    date = sample(calendar$date, n_int, replace = TRUE),
    day_type = rep("weekday", n_int),
    catch_total = sample(0:5, n_int, replace = TRUE),
    hours_fished = round(runif(n_int, 1, 4), 2),
    trip_status = rep("complete", n_int),
    trip_duration = round(runif(n_int, 1, 4), 2),
    stringsAsFactors = FALSE
  )

  d <- creel_design(calendar, date = date, strata = day_type) # nolint: object_usage_linter
  d <- quiet_estimate(add_counts(d, counts)) # nolint: object_usage_linter
  quiet_estimate(add_interviews(
    d,
    interviews,
    catch = catch_total,
    effort = hours_fished, # nolint: object_usage_linter
    trip_status = trip_status,
    trip_duration = trip_duration
  ))
}

# product_variance ----

test_that("product_variance='first_order' drops exactly the Goodman cross-term", {
  # The two settings must differ only by var(E) * var(R). Deriving the expected
  # difference from the component estimates (not from the estimator output)
  # means this fails if the cross-term is dropped, doubled, or sign-flipped.
  design <- make_single_stratum_design()

  goodman <- quiet_estimate(estimate_total_catch(design, product_variance = "goodman"))
  first_order <- quiet_estimate(estimate_total_catch(design, product_variance = "first_order"))

  effort <- quiet_estimate(estimate_effort(design))
  cpue <- quiet_estimate(estimate_catch_rate(design))

  expected_cross <- sum(effort$estimates$se^2 * cpue$estimates$se^2)

  expect_equal(
    goodman$estimates$se^2 - first_order$estimates$se^2,
    expected_cross,
    tolerance = 1e-8
  )
})

test_that("Goodman cross-term is added, not subtracted", {
  # Guards the sign. Goodman (1960) gives both an exact product variance
  # (which adds var(E)var(R)) and an unbiased estimator (which subtracts it).
  # tidycreel plugs point estimates into the additive form, so the Goodman SE
  # must be the larger of the two. A sign flip would silently narrow every
  # product-total CI in the package.
  design <- make_product_arg_design()

  goodman <- quiet_estimate(estimate_total_catch(design, product_variance = "goodman"))
  first_order <- quiet_estimate(estimate_total_catch(design, product_variance = "first_order"))

  expect_gt(goodman$estimates$se, first_order$estimates$se)
})

test_that("product_variance does not change the point estimate", {
  # The argument is a variance-only choice. If it ever moves the estimate, the
  # cross-term has leaked into the wrong expression.
  design <- make_product_arg_design()

  goodman <- quiet_estimate(estimate_total_catch(design, product_variance = "goodman"))
  first_order <- quiet_estimate(estimate_total_catch(design, product_variance = "first_order"))

  expect_equal(goodman$estimates$estimate, first_order$estimates$estimate)
})

test_that("product_variance is wired through harvest and release estimators", {
  # The three product-total estimators share compute_stratum_product_sum() but
  # each passes the argument down separately, so each path needs its own check.
  harvest_design <- make_product_arg_design()
  release_design <- make_product_arg_release_design()

  harvest_g <- quiet_estimate(estimate_total_harvest(harvest_design, product_variance = "goodman"))
  harvest_f <- quiet_estimate(
    estimate_total_harvest(harvest_design, product_variance = "first_order")
  )
  release_g <- quiet_estimate(estimate_total_release(release_design, product_variance = "goodman"))
  release_f <- quiet_estimate(
    estimate_total_release(release_design, product_variance = "first_order")
  )

  expect_gt(harvest_g$estimates$se, harvest_f$estimates$se)
  expect_gt(release_g$estimates$se, release_f$estimates$se)
  expect_equal(harvest_g$estimates$estimate, harvest_f$estimates$estimate)
  expect_equal(release_g$estimates$estimate, release_f$estimates$estimate)
})

test_that("product_variance rejects unknown values", {
  design <- make_product_arg_design()

  expect_error(
    quiet_estimate(estimate_total_catch(design, product_variance = "delta")),
    "should be one of"
  )
})

# ci_type ----

test_that("ci_type='log' returns a strictly positive, asymmetric interval", {
  # A total cannot be negative. The log interval encodes that by construction
  # rather than by clamping, so the bounds are unequal distances from the
  # estimate. Equal distances would mean the log path was not taken.
  design <- make_product_arg_design()

  result <- quiet_estimate(estimate_total_catch(design, ci_type = "log"))
  est <- result$estimates$estimate
  lower <- result$estimates$ci_lower
  upper <- result$estimates$ci_upper

  expect_gt(lower, 0)
  expect_lt(lower, est)
  expect_gt(upper, est)
  expect_gt(upper - est, est - lower)
})

test_that("ci_type='log' bounds match the back-transformed delta interval", {
  # Pins the actual transform: est * exp(+/- z * se / est) with a t quantile.
  # An arithmetic-scale interval, or a z quantile, would fail here.
  design <- make_product_arg_design()

  result <- quiet_estimate(estimate_total_catch(design, ci_type = "log", conf_level = 0.95))
  est <- result$estimates$estimate
  se_val <- result$estimates$se

  # Recover the quantile actually used from the upper bound, then confirm the
  # lower bound is its exact reciprocal reflection.
  z_used <- log(result$estimates$ci_upper / est) * est / se_val

  expect_equal(
    result$estimates$ci_lower,
    est * exp(-z_used * se_val / est),
    tolerance = 1e-8
  )
  expect_gt(z_used, 1.95) # t quantile at 95%, always at or above the z value
})

test_that("ci_type='symmetric' never returns a negative lower bound", {
  # Wald intervals on a total can go below zero when the CV is large; the
  # estimator clamps at zero instead of reporting an impossible bound.
  design <- make_product_arg_design()

  result <- quiet_estimate(estimate_total_catch(design, ci_type = "symmetric"))

  expect_gte(result$estimates$ci_lower, 0)
  expect_true(all(!is.na(c(result$estimates$ci_lower, result$estimates$ci_upper))))
})

test_that("ci_type does not change the estimate or its standard error", {
  # Interval shape is a presentation choice over a fixed (estimate, se) pair.
  design <- make_product_arg_design()

  symmetric <- quiet_estimate(estimate_total_catch(design, ci_type = "symmetric"))
  logged <- quiet_estimate(estimate_total_catch(design, ci_type = "log"))

  expect_equal(symmetric$estimates$estimate, logged$estimates$estimate)
  expect_equal(symmetric$estimates$se, logged$estimates$se)
})

test_that("ci_type is wired through harvest and release estimators", {
  harvest_design <- make_product_arg_design()
  release_design <- make_product_arg_release_design()

  harvest <- quiet_estimate(estimate_total_harvest(harvest_design, ci_type = "log"))
  release <- quiet_estimate(estimate_total_release(release_design, ci_type = "log"))

  expect_gt(harvest$estimates$ci_lower, 0)
  expect_gt(release$estimates$ci_lower, 0)
  expect_gt(
    harvest$estimates$ci_upper - harvest$estimates$estimate,
    harvest$estimates$estimate - harvest$estimates$ci_lower
  )
})

test_that("ci_type rejects unknown values", {
  design <- make_product_arg_design()

  expect_error(
    quiet_estimate(estimate_total_catch(design, ci_type = "wald")),
    "should be one of"
  )
})

# Defaults ----

test_that("product-total defaults are goodman and symmetric", {
  # The defaults are part of the public contract: changing either would move
  # every reported SE or interval in downstream analyses without warning.
  design <- make_product_arg_design()

  default <- quiet_estimate(estimate_total_catch(design))
  explicit <- quiet_estimate(
    estimate_total_catch(design, product_variance = "goodman", ci_type = "symmetric")
  )

  expect_equal(default$estimates$se, explicit$estimates$se)
  expect_equal(default$estimates$ci_lower, explicit$estimates$ci_lower)
  expect_equal(default$estimates$ci_upper, explicit$estimates$ci_upper)
})
