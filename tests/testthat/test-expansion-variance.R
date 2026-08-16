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
  attr(lookup, "se") <- c(weekday = 0.1, weekend = 0.2)

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
  attr(lookup, "se") <- c(weekday = 0.1, weekend = 0.2)

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
    expansion_of = "angler_count",
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
                       "expansion_se", "expansion_group", "expansion_of")]
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

# GH #131: the basis must stay in the units of the column it differentiates ----

expansion_calendar <- function() {
  data.frame(
    date = as.Date("2024-06-01") + 0:5,
    day_type = rep(c("weekday", "weekend"), 3),
    stringsAsFactors = FALSE
  )
}

test_that("premultiplying the count without the basis aborts (GH #131)", {
  # expansion_basis is d(count)/d(party_size), so it is only meaningful in the
  # units of the count it was derived for. A transformation applied before
  # add_counts() scales the count and leaves the basis behind: the component is
  # then understated by exactly the scale factor while remaining present and
  # non-NULL, so it reads as propagated. That is strictly harder to notice than
  # the fully-dropped carriers of GH #124, which at least surface as NULL.
  counts <- derive_angler_count(
    expansion_counts(),
    bank = bank_anglers,
    boat_count = angler_boats,
    party_size = 2.5,
    party_size_se = 0.1
  )
  counts$angler_hours <- counts$angler_count * 12

  design <- creel_design(expansion_calendar(), date = date, strata = day_type)
  expect_error(
    suppressWarnings(add_counts(design, counts, count_col = "angler_hours")),
    class = "creel_error_expansion_basis_desync"
  )
})

test_that("period_length_col carries the basis into effort units (GH #131)", {
  # The supported way to express the same physics. add_counts() scales the count
  # and the basis together, so the component is the whole boat total times the
  # multiplier's SE, in effort units -- twelve times the count-unit value that
  # the premultiplied path reported.
  counts <- derive_angler_count(
    expansion_counts(),
    bank = bank_anglers,
    boat_count = angler_boats,
    party_size = 2.5,
    party_size_se = 0.1
  )
  counts$shift_hours <- 12

  design <- creel_design(expansion_calendar(), date = date, strata = day_type)
  result <- suppressWarnings(estimate_effort(suppressWarnings(add_counts(
    design,
    counts,
    count_col = "angler_count",
    period_length_col = "shift_hours"
  ))))

  expect_equal(result$se_expansion, sum(counts$expansion_basis) * 12 * 0.1)
  expect_equal(result$se_expansion, 36)
})

test_that("a count column that matches the derived-for column is not a desync (GH #131)", {
  # The guard must fire on a mismatch, not on the presence of carriers. The
  # ordinary pipeline names the derived column and counts on it, and has to stay
  # silent.
  counts <- derive_angler_count(
    expansion_counts(),
    bank = bank_anglers,
    boat_count = angler_boats,
    party_size = 2.5,
    party_size_se = 0.1
  )

  design <- creel_design(expansion_calendar(), date = date, strata = day_type)
  expect_no_error(
    suppressWarnings(add_counts(design, counts, count_col = "angler_count"))
  )
})

test_that("a differently named count with no carriers does not abort (GH #131)", {
  # Nothing to desynchronize: without carriers there is no basis to be in the
  # wrong units. This case is GH #124's silent NULL, which the design print
  # guard covers -- it must not be turned into an error here.
  counts <- expansion_counts()
  counts$angler_hours <- (counts$bank_anglers + counts$angler_boats) * 12

  design <- creel_design(expansion_calendar(), date = date, strata = day_type)
  expect_no_error(
    suppressWarnings(add_counts(design, counts, count_col = "angler_hours"))
  )
})

test_that("expansion_of travels with the other carriers (GH #131, GH #132)", {
  # It is a carrier: written with the other three, and a proper subset of the
  # four is the malformed state GH #132 refuses.
  counts <- derive_angler_count(
    expansion_counts(),
    bank = bank_anglers,
    boat_count = angler_boats,
    party_size = 2.5,
    party_size_se = 0.1
  )

  expect_true("expansion_of" %in% names(counts))
  expect_identical(unique(counts$expansion_of), "angler_count")

  partial <- counts[, setdiff(names(counts), "expansion_of")]
  design <- creel_design(expansion_calendar(), date = date, strata = day_type)
  expect_error(
    suppressWarnings(add_counts(design, partial, count_col = "angler_count")),
    class = "creel_error_partial_expansion_carriers"
  )
})

# GH #131: every path that reaches the guard needs its own fixture -------------
#
# Phase 1 shipped two guards that passed their own tests and still missed the
# data they targeted, because the fixtures took the simple path into the
# estimator. The desync check sits ahead of aggregation and of the count-type
# branches, so each of those has to be shown reaching it rather than assumed to.

desync_counts <- function() {
  counts <- derive_angler_count(
    expansion_counts(),
    bank = bank_anglers,
    boat_count = angler_boats,
    party_size = 2.5,
    party_size_se = 0.1
  )
  counts$angler_hours <- counts$angler_count * 12
  counts
}

test_that("the desync guard fires ahead of within-day aggregation (GH #131)", {
  # Two counts per day: aggregate_within_day() averages the basis, so a run that
  # got past the guard would rebuild the table and hide which column the basis
  # belonged to.
  raw <- expansion_counts()[rep(1:6, each = 2), ]
  raw$count_time <- rep(c("am", "pm"), 6)
  counts <- derive_angler_count(
    raw,
    bank = bank_anglers,
    boat_count = angler_boats,
    party_size = 2.5,
    party_size_se = 0.1
  )
  counts$angler_hours <- counts$angler_count * 12

  design <- creel_design(expansion_calendar(), date = date, strata = day_type)
  expect_error(
    suppressWarnings(add_counts(
      design,
      counts,
      count_col = "angler_hours",
      count_time_col = "count_time"
    )),
    class = "creel_error_expansion_basis_desync"
  )
})

test_that("the desync guard fires with duplicate PSU rows (GH #131)", {
  # Duplicate rows for one day are only warned about (CNT-06), so they reach the
  # estimator. They must not carry a desynchronized basis in with them.
  counts <- desync_counts()
  counts <- rbind(counts, counts[1, ])

  design <- creel_design(expansion_calendar(), date = date, strata = day_type)
  expect_error(
    suppressWarnings(add_counts(design, counts, count_col = "angler_hours")),
    class = "creel_error_expansion_basis_desync"
  )
})

test_that("the desync guard fires on the progressive count path (GH #131)", {
  # Progressive counts multiply through by tau and T_d in a different branch
  # than instantaneous ones; the guard sits ahead of both.
  counts <- desync_counts()
  counts$shift_hours <- 12

  design <- creel_design(expansion_calendar(), date = date, strata = day_type)
  expect_error(
    suppressWarnings(add_counts(
      design,
      counts,
      count_col = "angler_hours",
      count_type = "progressive",
      circuit_time = 2,
      period_length_col = "shift_hours"
    )),
    class = "creel_error_expansion_basis_desync"
  )
})

test_that("the desync guard fires on a bus-route design (GH #131)", {
  # Bus-route designs dispatch differently downstream, and ice designs are
  # degenerate bus routes -- dispatch seams here have failed before.
  sf <- data.frame(
    site = c("A", "B"),
    circuit = "C1",
    p_site = c(0.5, 0.5),
    p_period = 0.8,
    stringsAsFactors = FALSE
  )
  design <- creel_design(
    expansion_calendar(),
    date = date,
    strata = day_type,
    survey_type = "bus_route",
    sampling_frame = sf,
    site = site,
    circuit = circuit,
    p_site = p_site,
    p_period = p_period
  )

  counts <- desync_counts()
  counts$site <- rep(c("A", "B"), 3)
  counts$circuit <- "C1"

  expect_error(
    suppressWarnings(add_counts(design, counts, count_col = "angler_hours")),
    class = "creel_error_expansion_basis_desync"
  )
})

# GH #133: the SE must be addressed by key, never by position -----------------

party_lookup_interviews <- function() {
  data.frame(
    day_type = c(rep("weekday", 3), rep("weekend", 3)),
    type = "boat",
    n_anglers = c(2, 3, 4, 2, 5, 8),
    stringsAsFactors = FALSE
  )
}

test_that("reordering the lookup does not swap the per-stratum SEs (GH #133)", {
  # The means are joined by key, so they follow a reordering. The SEs rode along
  # in a bare positional attribute that dplyr row operations leave untouched, so
  # an arrange() -- the most habitual length-preserving operation there is --
  # silently attributed each stratum's SE to the other stratum. Only the
  # uncertainty moved, which is why nothing caught it.
  mps <- mean_party_size(
    party_lookup_interviews(),
    n_anglers,
    angler_type = type,
    by = day_type
  )
  reordered <- mps[order(mps$day_type, decreasing = TRUE), ]

  ordered_counts <- derive_angler_count(
    expansion_counts(),
    boat_count = angler_boats,
    party_size = mps
  )
  reordered_counts <- derive_angler_count(
    expansion_counts(),
    boat_count = angler_boats,
    party_size = reordered
  )

  expect_identical(reordered_counts$expansion_se, ordered_counts$expansion_se)
  # The means already survived reordering; the point of the test is that the
  # uncertainty now does too.
  expect_identical(reordered_counts$angler_count, ordered_counts$angler_count)
})

test_that("mean_party_size() names its SE attribute by the group key (GH #133)", {
  # Naming is what makes the attribute survive a reordering of the rows it
  # describes: a name is addressable, a position is not.
  mps <- mean_party_size(
    party_lookup_interviews(),
    n_anglers,
    angler_type = type,
    by = day_type
  )

  expect_identical(names(attr(mps, "se")), c("weekday", "weekend"))
  expect_equal(unname(attr(mps, "se")[["weekday"]]), stats::sd(c(2, 3, 4)) / sqrt(3))
})

test_that("an unnamed SE attribute on a multi-row lookup aborts (GH #133)", {
  # Without names there is no way to tell a correctly ordered attribute from one
  # that has gone stale against a reordered lookup, and the failure is silent
  # and swaps only the uncertainty. Refuse rather than guess at row order.
  lookup <- data.frame(
    day_type = c("weekday", "weekend"),
    mean_party_size = c(2.0, 3.0),
    stringsAsFactors = FALSE
  )
  attr(lookup, "se") <- c(0.1, 0.2)

  expect_error(
    derive_angler_count(
      expansion_counts(),
      boat_count = angler_boats,
      party_size = lookup
    ),
    class = "creel_error_unnamed_expansion_se"
  )
})

test_that("a single-row lookup needs no names (GH #133)", {
  # One row cannot be reordered against itself, so there is nothing to go stale.
  counts <- expansion_counts()
  counts$day_type <- "weekday"
  lookup <- data.frame(
    day_type = "weekday",
    mean_party_size = 2.0,
    stringsAsFactors = FALSE
  )
  attr(lookup, "se") <- 0.1

  out <- derive_angler_count(counts, boat_count = angler_boats, party_size = lookup)
  expect_equal(unique(out$expansion_se), 0.1)
})

test_that("the expansion group is keyed to counts rows, not lookup positions (GH #133)", {
  # The issue asked for the "group" attribute to be checked for the same
  # positional hazard. It is built from the counts rows rather than indexed into
  # the lookup, so it is immune -- pinned here so a later refactor cannot
  # quietly give it the defect the SE just lost.
  mps <- mean_party_size(
    party_lookup_interviews(),
    n_anglers,
    angler_type = type,
    by = day_type
  )
  reordered <- mps[order(mps$day_type, decreasing = TRUE), ]

  ordered_counts <- derive_angler_count(
    expansion_counts(),
    boat_count = angler_boats,
    party_size = mps
  )
  reordered_counts <- derive_angler_count(
    expansion_counts(),
    boat_count = angler_boats,
    party_size = reordered
  )

  expect_identical(
    reordered_counts$expansion_group,
    ordered_counts$expansion_group
  )
})

test_that("a multi-column lookup key round-trips through the SE names (GH #133)", {
  # The names are built from the aggregate's key columns and read back from the
  # counts' key columns. Those are two different tables, so a single-key fixture
  # would not show that the encodings agree.
  interviews <- data.frame(
    day_type = rep(c("weekday", "weekend"), each = 4),
    section = rep(c("upper", "lower"), 4),
    type = "boat",
    n_anglers = c(2, 3, 4, 5, 2, 5, 8, 9),
    stringsAsFactors = FALSE
  )
  mps <- mean_party_size(
    interviews,
    n_anglers,
    angler_type = type,
    by = c(day_type, section)
  )

  counts <- expansion_counts()
  counts$section <- rep(c("upper", "lower"), 3)

  ordered_counts <- derive_angler_count(
    counts,
    boat_count = angler_boats,
    party_size = mps
  )
  reordered <- mps[order(mps$section, mps$day_type, decreasing = TRUE), ]
  reordered_counts <- derive_angler_count(
    counts,
    boat_count = angler_boats,
    party_size = reordered
  )

  expect_identical(reordered_counts$expansion_se, ordered_counts$expansion_se)
  # Each count row must carry the SE of its own day_type/section cell.
  expected <- vapply(
    seq_len(nrow(counts)),
    function(i) {
      cell <- interviews$n_anglers[
        interviews$day_type == counts$day_type[i] &
          interviews$section == counts$section[i]
      ]
      stats::sd(cell) / sqrt(length(cell))
    },
    numeric(1)
  )
  expect_equal(ordered_counts$expansion_se, expected)
})

# GH #148: the refusal must not misdescribe a correct hand-rescale -------------

test_that("the desync message names the correct-rescale case too (GH #148)", {
  # The guard cannot distinguish a basis rescaled correctly alongside its count
  # from one left behind: expansion_of records a column name, not a scale
  # factor, so both arrive identically and both are refused. Refusing both is
  # the conservative choice, but the message described only the mistake, and
  # every instructional example in the companion book -- ten chapters -- met it
  # with arithmetic that was right. Stating both cases removes the
  # misdescription without weakening the check.
  counts <- desync_counts()
  design <- creel_design(expansion_calendar(), date = date, strata = day_type)

  err <- tryCatch(
    suppressWarnings(add_counts(design, counts, count_col = "angler_hours")),
    creel_error_expansion_basis_desync = function(e) e
  )
  msg <- cli::ansi_strip(paste(conditionMessage(err), collapse = "\n"))

  # The supported route, and an acknowledgement that correct code lands here.
  expect_match(msg, "period_length_col", fixed = TRUE)
  expect_match(msg, "rescaled")
  # Still says what the actual defect is; broadening must not drop that.
  expect_match(msg, "understates")
})

test_that("the desync guard still refuses every case it did before (GH #131, #148)", {
  # #148 changed wording only. A message change that also changed behaviour
  # would reopen the defect, so the refusal itself is re-asserted here.
  counts <- desync_counts()
  design <- creel_design(expansion_calendar(), date = date, strata = day_type)

  expect_error(
    suppressWarnings(add_counts(design, counts, count_col = "angler_hours")),
    class = "creel_error_expansion_basis_desync"
  )
})
