# Party-size expansion variance component (GH #121)
#
# A mean party size taken from interviews multiplies the boat component of every
# count. Treating it as known understates the effort standard error, and the
# understatement does not shrink as counts accumulate. These tests pin the size
# of the term, the way it accumulates, and -- most importantly -- that it stays
# absent rather than zero when no standard error is available.

expansion_counts <- function() {
  data.frame(
    date = as.Date("2024-06-01") + 0:5,
    day_type = rep(c("weekday", "weekend"), 3),
    bank_anglers = c(3, 5, 2, 4, 8, 10),
    angler_boats = c(6, 2, 4, 8, 5, 5),
    stringsAsFactors = FALSE
  )
}

expansion_design <- function(counts) {
  calendar <- data.frame(
    date = as.Date("2024-06-01") + 0:5,
    day_type = rep(c("weekday", "weekend"), 3),
    stringsAsFactors = FALSE
  )
  design <- creel_design(calendar, date = date, strata = day_type)
  suppressWarnings(add_counts(design, counts, count_col = "angler_count"))
}

test_that("the expansion component equals the expanded boat total times the SE", {
  # The whole term is one multiplier's error applied to every boat, so it is
  # exactly T_boats * se_p -- not something that shrinks with more counts.
  counts <- derive_angler_count(
    expansion_counts(),
    bank = bank_anglers,
    boat_count = angler_boats,
    party_size = 2.5,
    party_size_se = 0.1
  )
  result <- suppressWarnings(estimate_effort(expansion_design(counts)))

  expect_equal(result$se_expansion, sum(counts$expansion_basis) * 0.1)
})

test_that("total se absorbs the expansion component", {
  counts <- derive_angler_count(
    expansion_counts(),
    bank = bank_anglers,
    boat_count = angler_boats,
    party_size = 2.5,
    party_size_se = 0.1
  )
  result <- suppressWarnings(estimate_effort(expansion_design(counts)))
  est <- result$estimates

  expect_equal(
    est$se,
    sqrt(est$se_between^2 + est$se_within^2 + result$se_expansion^2),
    tolerance = 1e-10
  )
})

test_that("propagating the party-size SE strictly increases the effort SE", {
  # The direction is the point of the issue: the published figure was too small.
  base <- expansion_counts()
  without <- derive_angler_count(
    base,
    bank = bank_anglers,
    boat_count = angler_boats,
    party_size = 2.5
  )
  with_se <- derive_angler_count(
    base,
    bank = bank_anglers,
    boat_count = angler_boats,
    party_size = 2.5,
    party_size_se = 0.1
  )

  e_without <- suppressWarnings(estimate_effort(expansion_design(without)))
  e_with <- suppressWarnings(estimate_effort(expansion_design(with_se)))

  # The estimate itself must not move -- only its uncertainty.
  expect_equal(e_with$estimates$estimate, e_without$estimates$estimate)
  expect_gt(e_with$estimates$se, e_without$estimates$se)
})

test_that("an absent party-size SE leaves the component NULL, never zero", {
  # A zero would produce an SE identical to the unpropagated one while looking
  # propagated. That is the specific failure mode this design exists to avoid,
  # so the absence must be representable.
  counts <- derive_angler_count(
    expansion_counts(),
    bank = bank_anglers,
    boat_count = angler_boats,
    party_size = 2.5
  )
  result <- suppressWarnings(estimate_effort(expansion_design(counts)))

  expect_null(result$se_expansion)
  expect_false(any(
    c("expansion_basis", "expansion_se", "expansion_group") %in% names(counts)
  ))
})

test_that("an unknown party-size SE yields an unknown effort SE", {
  # A single interviewed party gives a mean but no spread. That is missing
  # information, not certainty, so it must not quietly reduce to a zero term.
  counts <- derive_angler_count(
    expansion_counts(),
    bank = bank_anglers,
    boat_count = angler_boats,
    party_size = 2.5,
    party_size_se = NA_real_
  )
  result <- suppressWarnings(estimate_effort(expansion_design(counts)))

  expect_true(is.na(result$estimates$se))
})

test_that("separate strata estimates add as independent variances", {
  # Two strata means come from disjoint interview subsets, so their errors are
  # independent: the total combines them in quadrature rather than summing them.
  lookup <- data.frame(
    day_type = c("weekday", "weekend"),
    mean_party_size = c(2.0, 3.0),
    stringsAsFactors = FALSE
  )
  attr(lookup, "se") <- c(0.1, 0.2)

  counts <- derive_angler_count(
    expansion_counts(),
    bank = bank_anglers,
    boat_count = angler_boats,
    party_size = lookup
  )
  result <- suppressWarnings(estimate_effort(expansion_design(counts)))

  basis <- counts$expansion_basis
  weekday <- sum(basis[counts$day_type == "weekday"]) * 0.1
  weekend <- sum(basis[counts$day_type == "weekend"]) * 0.2

  expect_equal(result$se_expansion, sqrt(weekday^2 + weekend^2))
  # Summing instead of combining in quadrature would give this larger number.
  expect_lt(result$se_expansion, weekday + weekend)
})

test_that("counts sharing one estimate accumulate as perfectly correlated error", {
  # Within a group the multiplier's error is one number applied many times, so
  # the bases add before squaring. Treating the counts as independent would
  # divide the term by roughly sqrt(n) and understate it.
  counts <- derive_angler_count(
    expansion_counts(),
    bank = bank_anglers,
    boat_count = angler_boats,
    party_size = 2.5,
    party_size_se = 0.1
  )
  result <- suppressWarnings(estimate_effort(expansion_design(counts)))

  basis <- counts$expansion_basis
  correlated <- sum(basis) * 0.1
  independent <- sqrt(sum((basis * 0.1)^2))

  expect_equal(result$se_expansion, correlated)
  expect_gt(correlated, independent)
})

test_that("a grouped estimate carries one expansion component per group", {
  lookup <- data.frame(
    day_type = c("weekday", "weekend"),
    mean_party_size = c(2.0, 3.0),
    stringsAsFactors = FALSE
  )
  attr(lookup, "se") <- c(0.1, 0.2)

  counts <- derive_angler_count(
    expansion_counts(),
    bank = bank_anglers,
    boat_count = angler_boats,
    party_size = lookup
  )
  result <- suppressWarnings(
    estimate_effort(expansion_design(counts), by = day_type)
  )
  est <- result$estimates

  basis <- counts$expansion_basis
  expected <- c(
    sum(basis[counts$day_type == "weekday"]) * 0.1,
    sum(basis[counts$day_type == "weekend"]) * 0.2
  )

  expect_equal(result$se_expansion, expected)
  expect_equal(
    est$se,
    sqrt(est$se_between^2 + est$se_within^2 + result$se_expansion^2),
    tolerance = 1e-10
  )
})

test_that("the basis follows the count through within-day aggregation", {
  # The basis is d(count)/d(party_size). Aggregation replaces the count with a
  # per-day mean, so a basis left at its first value would be the derivative of
  # a count that no longer exists.
  raw <- data.frame(
    date = rep(as.Date("2024-06-01") + 0:1, each = 2),
    day_type = rep(c("weekday", "weekend"), each = 2),
    count_time = rep(c("am", "pm"), 2),
    bank_anglers = c(3, 5, 2, 4),
    angler_boats = c(6, 2, 4, 8),
    stringsAsFactors = FALSE
  )
  counts <- derive_angler_count(
    raw,
    bank = bank_anglers,
    boat_count = angler_boats,
    party_size = 2.5,
    party_size_se = 0.1
  )
  calendar <- data.frame(
    date = as.Date("2024-06-01") + 0:1,
    day_type = c("weekday", "weekend"),
    stringsAsFactors = FALSE
  )
  design <- creel_design(calendar, date = date, strata = day_type)
  design <- suppressWarnings(add_counts(
    design,
    counts,
    count_col = "angler_count",
    count_time_col = "count_time"
  ))

  expect_equal(design$counts$expansion_basis, c(mean(c(6, 2)), mean(c(4, 8))))
})

test_that("the basis follows the count into effort units via the period length", {
  # Once counts are multiplied by T_d the estimate is in angler-hours. A basis
  # left in count units would put the component in the wrong units entirely.
  raw <- expansion_counts()
  raw$period_length <- 12
  counts <- derive_angler_count(
    raw,
    bank = bank_anglers,
    boat_count = angler_boats,
    party_size = 2.5,
    party_size_se = 0.1
  )
  calendar <- data.frame(
    date = as.Date("2024-06-01") + 0:5,
    day_type = rep(c("weekday", "weekend"), 3),
    stringsAsFactors = FALSE
  )
  design <- creel_design(calendar, date = date, strata = day_type)
  design <- suppressWarnings(add_counts(
    design,
    counts,
    count_col = "angler_count",
    period_length_col = "period_length"
  ))

  expect_equal(design$counts$expansion_basis, raw$angler_boats * 12)
})

test_that("the expansion term reaches harvest totals through the effort SE", {
  # The component is deliberately not a column on the estimates tibble, so the
  # only route into downstream products is `se`. If that route were broken the
  # term would silently stop at effort.
  skip_if_not_installed("survey")

  base <- expansion_counts()
  without <- expansion_design(derive_angler_count(
    base,
    bank = bank_anglers,
    boat_count = angler_boats,
    party_size = 2.5
  ))
  with_se <- expansion_design(derive_angler_count(
    base,
    bank = bank_anglers,
    boat_count = angler_boats,
    party_size = 2.5,
    party_size_se = 0.1
  ))

  interviews <- data.frame(
    date = as.Date("2024-06-01") + 0:5,
    day_type = rep(c("weekday", "weekend"), 3),
    hours = c(2, 3, 2.5, 4, 3, 2),
    harvest = c(1, 0, 2, 3, 1, 1),
    status = "complete",
    stringsAsFactors = FALSE
  )
  add_iv <- function(d) {
    suppressMessages(suppressWarnings(
      add_interviews(
        d,
        interviews,
        catch = harvest,
        effort = hours,
        harvest = harvest,
        trip_status = status
      )
    ))
  }

  h_without <- suppressWarnings(estimate_total_harvest(add_iv(without)))
  h_with <- suppressWarnings(estimate_total_harvest(add_iv(with_se)))

  expect_gt(h_with$estimates$se, h_without$estimates$se)
})

test_that("counts built from two derive_angler_count() calls are rejected", {
  # Aggregation takes the first value for a column it does not average, so a
  # standard error varying inside one PSU would be resolved by row order.
  raw <- data.frame(
    date = rep(as.Date("2024-06-01"), 2),
    day_type = "weekday",
    count_time = c("am", "pm"),
    angler_count = c(10, 12),
    expansion_basis = c(4, 4),
    expansion_se = c(0.1, 0.9),
    expansion_group = c("1", "1"),
    stringsAsFactors = FALSE
  )
  calendar <- data.frame(
    date = as.Date("2024-06-01"),
    day_type = "weekday",
    stringsAsFactors = FALSE
  )
  design <- creel_design(calendar, date = date, strata = day_type)

  expect_error(
    add_counts(design, raw, count_col = "angler_count", count_time_col = "count_time"),
    "varies within a single PSU"
  )
})

test_that("the carrier columns do not make the count column ambiguous", {
  # They are numeric and sit beside the count, so without an exclusion they
  # would turn a perfectly clear table into an ambiguity error.
  counts <- derive_angler_count(
    expansion_counts(),
    bank = bank_anglers,
    boat_count = angler_boats,
    party_size = 2.5,
    party_size_se = 0.1
  )
  counts <- counts[, c("date", "day_type", "angler_count", "expansion_basis",
                       "expansion_se", "expansion_group")]
  calendar <- data.frame(
    date = as.Date("2024-06-01") + 0:5,
    day_type = rep(c("weekday", "weekend"), 3),
    stringsAsFactors = FALSE
  )
  design <- creel_design(calendar, date = date, strata = day_type)

  expect_no_error(suppressWarnings(add_counts(design, counts)))
})

test_that("derive_angler_count() refuses to overwrite existing carrier columns", {
  counts <- expansion_counts()
  counts$expansion_basis <- 1

  expect_error(
    derive_angler_count(
      counts,
      bank = bank_anglers,
      boat_count = angler_boats,
      party_size = 2.5,
      party_size_se = 0.1
    ),
    "already exist"
  )
})

test_that("party_size_se without boat_count is an error", {
  expect_error(
    derive_angler_count(
      expansion_counts(),
      bank = bank_anglers,
      boat_anglers = angler_boats,
      party_size_se = 0.1
    ),
    "without .*boat_count"
  )
})

test_that("a negative party-size SE is rejected", {
  expect_error(
    derive_angler_count(
      expansion_counts(),
      bank = bank_anglers,
      boat_count = angler_boats,
      party_size = 2.5,
      party_size_se = -0.1
    ),
    "not negative"
  )
})

test_that("mean_party_size() output propagates its SE without being asked", {
  # The usual pipeline must carry the term on its own; requiring an extra
  # argument is what left it missing from the published figures in the first place.
  interviews <- data.frame(
    type = rep("boat", 6),
    n_anglers = c(2, 4, 3, 3, 7, 5),
    stringsAsFactors = FALSE
  )
  party <- mean_party_size(interviews, n_anglers, angler_type = type)

  counts <- derive_angler_count(
    expansion_counts(),
    bank = bank_anglers,
    boat_count = angler_boats,
    party_size = party
  )

  expect_equal(unique(counts$expansion_se), attr(party, "se"))
})

test_that("an explicit party_size_se overrides the attribute", {
  interviews <- data.frame(
    type = rep("boat", 6),
    n_anglers = c(2, 4, 3, 3, 7, 5),
    stringsAsFactors = FALSE
  )
  party <- mean_party_size(interviews, n_anglers, angler_type = type)

  counts <- derive_angler_count(
    expansion_counts(),
    bank = bank_anglers,
    boat_count = angler_boats,
    party_size = party,
    party_size_se = 0.5
  )

  expect_equal(unique(counts$expansion_se), 0.5)
})

# GH #132: a partial carrier set is provably malformed -------------------------

test_that("a partial carrier set aborts instead of silently dropping the component (GH #132)", {
  # Dropping one or two of the three carrier columns leaves the survivors
  # visibly in the table while add_counts() silently treats the set as absent:
  # se_expansion comes back NULL with no message. A table carrying a proper
  # subset of the carriers can only arise from partial deletion -- unlike full
  # deletion (GH #124) it is detectable today, so it must refuse loudly rather
  # than quietly downgrade to the no-carriers path.
  full <- derive_angler_count(
    expansion_counts(),
    bank = bank_anglers,
    boat_count = angler_boats,
    party_size = 2.5,
    party_size_se = 0.1
  )
  carriers <- c("expansion_basis", "expansion_se", "expansion_group")

  # one column dropped
  for (dropped in carriers) {
    partial <- full[, setdiff(names(full), dropped)]
    expect_error(
      expansion_design(partial),
      class = "creel_error_partial_expansion_carriers"
    )
  }

  # two columns dropped
  for (kept in carriers) {
    partial <- full[, setdiff(names(full), setdiff(carriers, kept))]
    expect_error(
      expansion_design(partial),
      class = "creel_error_partial_expansion_carriers"
    )
  }
})
