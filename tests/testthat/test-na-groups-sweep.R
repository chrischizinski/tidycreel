# Unknown grouping values, across every grouped estimator (GH #321) ----
#
# GH #317 fixed the effort path: `survey::svyby()` drops rows whose `by=` value
# is `NA`, without a warning and without a row, so the grouped parts stop
# summing to the ungrouped whole. #321 is the sweep over the remaining grouped
# estimators. The tests below deliberately do NOT share one fixture: the
# interview-rate, product-total and bus-route paths build their own designs and
# their own keys, and a single fixture would report the sweep as done while two
# of the three still dropped rows.

# --- interview-side rates: the by= column lives in the interviews -------------

# 48 complete trips, gear recorded on 32 of them. The gear is UNKNOWN for the
# other 16, not a third gear and not an absence: those are real interviews with
# real catch. 16 per group clears the n >= 10 ratio-estimation floor, which is
# what lets the unknown group be estimated rather than refused.
make_na_gear_design <- function(n_per_group = 16L) {
  data(example_calendar, package = "tidycreel")
  data(example_counts, package = "tidycreel")
  n <- 3L * n_per_group
  iv <- data.frame(
    date = rep(example_calendar$date, length.out = n),
    hours_fished = rep(c(2, 3, 4), length.out = n),
    catch_total = rep(c(4, 6, 9), length.out = n),
    catch_kept = rep(c(2, 3, 5), length.out = n),
    trip_status = "complete",
    interview_id = seq_len(n),
    gear = rep(c("bank", "boat", NA_character_), each = n_per_group),
    stringsAsFactors = FALSE
  )
  d <- suppressMessages(creel_design(example_calendar, date = date, strata = day_type)) # nolint: object_usage_linter
  d <- suppressWarnings(suppressMessages(add_counts(d, example_counts)))
  suppressWarnings(suppressMessages(add_interviews(
    d, iv,
    catch = catch_total, # nolint: object_usage_linter
    effort = hours_fished, # nolint: object_usage_linter
    harvest = catch_kept, # nolint: object_usage_linter
    trip_status = trip_status # nolint: object_usage_linter
  )))
}

test_that("NAGRP-05 (#321): a grouped catch rate reports the unknown group", {
  d <- make_na_gear_design()

  ungrouped <- suppressWarnings(suppressMessages(estimate_catch_rate(d)))
  grouped <- suppressWarnings(suppressMessages(estimate_catch_rate(d, by = gear)))

  # A rate does not sum across groups, so the falsifiable claim is that every
  # interview is accounted for by some reported group. Before the fix the two
  # rates covered 32 of 48 interviews and said nothing at all about the other
  # 16 -- a third of the sample, silently.
  expect_equal(sum(grouped$estimates$n), ungrouped$estimates$n)
  expect_equal(nrow(grouped$estimates), 3L)

  na_row <- grouped$estimates[is.na(as.character(grouped$estimates$gear)), ]
  expect_equal(nrow(na_row), 1L)
  expect_equal(na_row$n, 16L)
  # A real estimate, not a placeholder: the unknown group's interviews carry
  # catch and effort like any other group's.
  expect_false(is.na(na_row$estimate))
  expect_false(is.na(na_row$se))
  expect_false(anyNA(grouped$estimates$n))
})

test_that("NAGRP-06 (#321): a grouped harvest rate reports the unknown group", {
  d <- make_na_gear_design()

  ungrouped <- suppressWarnings(suppressMessages(estimate_harvest_rate(d)))
  grouped <- suppressWarnings(suppressMessages(estimate_harvest_rate(d, by = gear)))

  expect_equal(sum(grouped$estimates$n), ungrouped$estimates$n)
  expect_equal(nrow(grouped$estimates), 3L)
  na_row <- grouped$estimates[is.na(as.character(grouped$estimates$gear)), ]
  expect_equal(na_row$n, 16L)
  expect_false(is.na(na_row$estimate))
})

test_that("NAGRP-07 (#321): the ratio n>=10 floor is applied to the unknown group too", {
  # Six per group: every group is below the floor, including the unknown one.
  # The floor counted groups with `aggregate(.count ~ ., ...)`, whose formula
  # method drops NA rows -- so the unknown group was never put to the floor at
  # all, and a request was admitted or refused on a denominator that had
  # silently lost rows. The message naming three groups rather than two is the
  # assertion: it is what proves the floor now sees the unknown one.
  d <- make_na_gear_design(n_per_group = 6L)
  err <- tryCatch(
    suppressWarnings(suppressMessages(estimate_catch_rate(d, by = gear))),
    error = function(e) e
  )
  expect_s3_class(err, "error")
  expect_match(conditionMessage(err), "Insufficient sample size in 3 groups")
})

# --- count-side product totals: effort x rate, per stratum -------------------

# `zone` is present in BOTH the counts and the interviews, which is what a
# product total needs: effort can only be split by what the counter classified.
# Some days were counted without the zone being recorded.
make_na_zone_design <- function() {
  data(example_calendar, package = "tidycreel")
  data(example_counts, package = "tidycreel")
  cnt <- example_counts
  cnt$zone <- rep(c("north", "south", NA_character_), length.out = nrow(cnt))
  n <- 48L
  iv <- data.frame(
    date = rep(example_calendar$date, length.out = n),
    hours_fished = rep(c(2, 3, 4), length.out = n),
    catch_total = rep(c(4, 6, 9), length.out = n),
    catch_kept = rep(c(2, 3, 5), length.out = n),
    trip_status = "complete",
    interview_id = seq_len(n),
    stringsAsFactors = FALSE
  )
  iv$zone <- cnt$zone[match(iv$date, cnt$date)]
  d <- suppressMessages(creel_design(example_calendar, date = date, strata = day_type)) # nolint: object_usage_linter
  d <- suppressWarnings(suppressMessages(add_counts(d, cnt)))
  suppressWarnings(suppressMessages(add_interviews(
    d, iv,
    catch = catch_total, # nolint: object_usage_linter
    effort = hours_fished, # nolint: object_usage_linter
    harvest = catch_kept, # nolint: object_usage_linter
    trip_status = trip_status # nolint: object_usage_linter
  )))
}

test_that("NAGRP-08 (#321): a grouped total catch reports the unknown group", {
  d <- make_na_zone_design()

  ungrouped <- suppressWarnings(suppressMessages(estimate_total_catch(d)))
  grouped <- suppressWarnings(suppressMessages(estimate_total_catch(d, by = zone)))

  expect_equal(nrow(grouped$estimates), 3L)
  na_row <- grouped$estimates[is.na(as.character(grouped$estimates$zone)), ]
  expect_equal(nrow(na_row), 1L)
  expect_false(is.na(na_row$estimate))
  expect_gt(na_row$estimate, 0)

  # The grouped total is a stratified sum of per-group products and the
  # ungrouped total is a pooled product, so the two are close rather than
  # identical. What the fix has to restore is that the grouped rows cover the
  # whole fishery: before it they summed to 565.2 against an ungrouped 784.6,
  # 28% of the catch missing with no warning and no row.
  expect_equal(
    sum(grouped$estimates$estimate),
    ungrouped$estimates$estimate,
    tolerance = 0.01
  )
  expect_equal(sum(grouped$estimates$n), ungrouped$estimates$n)
})

test_that("NAGRP-09 (#321): a grouped total harvest reports the unknown group", {
  d <- make_na_zone_design()

  grouped <- suppressWarnings(suppressMessages(estimate_total_harvest(d, by = zone)))
  expect_equal(nrow(grouped$estimates), 3L)
  na_row <- grouped$estimates[is.na(as.character(grouped$estimates$zone)), ]
  expect_equal(nrow(na_row), 1L)
  expect_false(is.na(na_row$estimate))
  expect_false(anyNA(grouped$estimates$n))
})

# --- bus-route: its own design, its own keys ---------------------------------

make_na_gear_br_design <- function() {
  d <- build_ht_multispecies_design(
    "bus_route",
    n_days = 8L,
    n_interviews = 36L,
    seed = 321
  )
  gear <- rep(c("bank", "boat", NA_character_), length.out = nrow(d$interviews))
  d$interviews$gear <- gear
  d$interview_survey$variables$gear <- gear
  d
}

test_that("NAGRP-10 (#321): a grouped bus-route effort total reports the unknown group", {
  d <- make_na_gear_br_design()

  ungrouped <- suppressWarnings(suppressMessages(estimate_effort(d)))
  grouped <- suppressWarnings(suppressMessages(estimate_effort(d, by = gear)))

  expect_equal(nrow(grouped$estimates), 3L)
  expect_equal(sum(grouped$estimates$n), ungrouped$estimates$n)
  expect_equal(
    sum(grouped$estimates$estimate),
    ungrouped$estimates$estimate,
    tolerance = 1e-6
  )
  # `proportion` is each group's share of the overall total, and its
  # denominator always included the unknown group's contribution. So before the
  # fix the column quietly summed to 0.64 -- the one visible trace of the
  # missing third, in a column nobody reads as a completeness check.
  expect_equal(sum(grouped$estimates$proportion), 1, tolerance = 1e-6)
  expect_false(anyNA(grouped$estimates$n))
})

test_that("NAGRP-11 (#321): a grouped bus-route catch total reports the unknown group", {
  d <- make_na_gear_br_design()

  ungrouped <- suppressWarnings(suppressMessages(estimate_total_catch(d)))
  grouped <- suppressWarnings(suppressMessages(estimate_total_catch(d, by = gear)))

  expect_equal(nrow(grouped$estimates), 3L)
  expect_equal(sum(grouped$estimates$n), ungrouped$estimates$n)
  expect_equal(
    sum(grouped$estimates$estimate),
    ungrouped$estimates$estimate,
    tolerance = 1e-6
  )
  expect_equal(sum(grouped$estimates$proportion), 1, tolerance = 1e-6)
})

test_that("NAGRP-12 (#321): a grouped bus-route catch rate reports the unknown group", {
  d <- make_na_gear_br_design()

  ungrouped <- suppressWarnings(suppressMessages(estimate_catch_rate(d)))
  grouped <- suppressWarnings(suppressMessages(estimate_catch_rate(d, by = gear)))

  expect_equal(nrow(grouped$estimates), 3L)
  expect_equal(sum(grouped$estimates$n), ungrouped$estimates$n)
  na_row <- grouped$estimates[is.na(as.character(grouped$estimates$gear)), ]
  expect_equal(na_row$n, 12L)
  expect_false(is.na(na_row$estimate))
})

# --- the "NA" collision ------------------------------------------------------

test_that("NAGRP-13 (#321): a group labelled \"NA\" is not the unknown group", {
  # `paste()` renders a missing value as the string "NA", so any path still
  # building keys that way merges the two and the totals still look right.
  # This is the collision GH #248 already cost this package once.
  data(example_calendar, package = "tidycreel")
  data(example_counts, package = "tidycreel")
  n <- 48L
  iv <- data.frame(
    date = rep(example_calendar$date, length.out = n),
    hours_fished = rep(c(2, 3, 4), length.out = n),
    catch_total = rep(c(4, 6, 9), length.out = n),
    catch_kept = rep(c(2, 3, 5), length.out = n),
    trip_status = "complete",
    interview_id = seq_len(n),
    # One group is genuinely LABELLED "NA" -- a real gear code, spelled that
    # way -- alongside a group whose gear is unknown.
    gear = rep(c("bank", "NA", NA_character_), each = 16L),
    stringsAsFactors = FALSE
  )
  d <- suppressMessages(creel_design(example_calendar, date = date, strata = day_type)) # nolint: object_usage_linter
  d <- suppressWarnings(suppressMessages(add_counts(d, example_counts)))
  d <- suppressWarnings(suppressMessages(add_interviews(
    d, iv,
    catch = catch_total, # nolint: object_usage_linter
    effort = hours_fished, # nolint: object_usage_linter
    harvest = catch_kept, # nolint: object_usage_linter
    trip_status = trip_status # nolint: object_usage_linter
  )))

  grouped <- suppressWarnings(suppressMessages(estimate_catch_rate(d, by = gear)))

  # Three rows, not two: the label and the absence stay apart.
  expect_equal(nrow(grouped$estimates), 3L)
  labels <- as.character(grouped$estimates$gear)
  expect_equal(sum(is.na(labels)), 1L)
  expect_equal(sum(!is.na(labels) & labels == "NA"), 1L)
  # Each keeps its own 16 interviews rather than sharing a pooled 32.
  expect_true(all(grouped$estimates$n == 16L))
})

test_that("NAGRP-14 (#321): expansion_stratum_key() separates absent from a label spelling it", {
  # The private second copy of the key rule. It pasted with a "\r" separator,
  # which renders a missing value as "NA" -- so an unknown stratum and a
  # stratum labelled "NA" received the same key and had their expansion
  # components pooled. It now delegates to group_key(), the package's one
  # answer to this question (GH #320).
  df <- data.frame(
    a = c("NA", NA, "x"),
    b = c("y", "y", "y"),
    stringsAsFactors = FALSE
  )
  keys <- tidycreel:::expansion_stratum_key(df, c("a", "b"))
  expect_equal(length(unique(keys)), 3L)
  expect_false(keys[[1]] == keys[[2]])
})

# --- the reported group column keeps its own type ---------------------------

test_that("NAGRP-15 (#321): a numeric grouping column is still numeric when a value is unknown", {
  # `promote_na_groups()` factor-ises a `by=` column so svyby reports the
  # unknown group -- but only when that column contains an NA. So the same
  # estimator on the same column returned a factor when something was missing
  # and a numeric when nothing was, and `depth > 15` or `depth + 1` on the
  # result worked only in the second case. The factor is an implementation
  # detail of the svyby call and is undone on the way out.
  data(example_calendar, package = "tidycreel")
  data(example_counts, package = "tidycreel")

  mk <- function(with_na) {
    cnt <- example_counts
    cnt$depth_m <- rep(c(10, 20, 30), length.out = nrow(cnt))
    if (with_na) {
      cnt$depth_m[c(3, 7, 11)] <- NA
    }
    d <- suppressMessages(creel_design(example_calendar, date = date, strata = day_type)) # nolint: object_usage_linter
    suppressWarnings(suppressMessages(add_counts(
      d, cnt,
      count_col = "effort_hours",
      unit_cols = c("date", "day_type", "depth_m")
    )))
  }

  clean <- suppressWarnings(suppressMessages(estimate_effort(mk(FALSE), by = depth_m)))
  unknown <- suppressWarnings(suppressMessages(estimate_effort(mk(TRUE), by = depth_m)))

  # The schema does not depend on whether a value happened to be missing.
  expect_type(clean$estimates$depth_m, "double")
  expect_type(unknown$estimates$depth_m, "double")
  expect_false(is.factor(unknown$estimates$depth_m))

  # The unknown group comes back as a numeric NA -- precisely what a depth
  # column can say about a count whose depth was never recorded.
  expect_equal(nrow(unknown$estimates), 4L)
  expect_equal(sum(is.na(unknown$estimates$depth_m)), 1L)

  # And the column is usable as a number, which is the whole point.
  expect_equal(
    unknown$estimates$depth_m > 15,
    c(FALSE, TRUE, TRUE, NA)
  )

  # A column the caller supplied as a factor comes back as that factor -- with
  # a TRUE NA rather than the promoted addNA() level, so `is.na()` finds the
  # unknown group for a factor exactly as it does for every other type.
  d_fac <- local({
    cnt <- example_counts
    cnt$depth_f <- factor(rep(c("shallow", "mid", "deep"), length.out = nrow(cnt)))
    cnt$depth_f[c(3, 7, 11)] <- NA
    dd <- suppressMessages(creel_design(example_calendar, date = date, strata = day_type)) # nolint: object_usage_linter
    suppressWarnings(suppressMessages(add_counts(
      dd, cnt,
      count_col = "effort_hours",
      unit_cols = c("date", "day_type", "depth_f")
    )))
  })
  res_fac <- suppressWarnings(suppressMessages(estimate_effort(d_fac, by = depth_f)))
  expect_true(is.factor(res_fac$estimates$depth_f))
  expect_equal(sum(is.na(res_fac$estimates$depth_f)), 1L)
  # The promoted level is gone: the unknown group is a missing value, not a
  # level spelled NA.
  expect_false(anyNA(levels(res_fac$estimates$depth_f)))
})

test_that("NAGRP-16 (#321): restore_group_types() round-trips every column type", {
  # The helper maps each reported label back onto a value of the source
  # column's own type. Pinned per type rather than only through an estimator,
  # because the estimators in this file exercise character and numeric columns
  # and nothing in the suite would catch a Date or an integer regressing.
  rt <- function(orig) {
    res <- data.frame(v = addNA(factor(orig), ifany = TRUE))
    tidycreel:::restore_group_types(res, data.frame(v = orig), "v")$v
  }

  expect_identical(rt(c(10, 20, NA)), c(10, 20, NA_real_))
  expect_identical(rt(c(10L, 20L, NA)), c(10L, 20L, NA_integer_))
  expect_identical(
    rt(as.Date(c("2024-06-01", "2024-06-02", NA))),
    as.Date(c("2024-06-01", "2024-06-02", NA))
  )
  expect_identical(rt(c(TRUE, FALSE, NA)), c(TRUE, FALSE, NA))
  expect_identical(rt(c("a", "b", NA)), c("a", "b", NA_character_))

  # A factor source comes back as that factor, with a true NA rather than the
  # promoted level, and keeps its levels and its `ordered` class.
  src_f <- factor(c("a", "b", NA))
  res_f <- data.frame(v = addNA(src_f, ifany = TRUE))
  got_f <- tidycreel:::restore_group_types(res_f, data.frame(v = src_f), "v")$v
  expect_identical(got_f, src_f)
  expect_true(is.na(got_f[[3]]))
  expect_false(anyNA(levels(got_f)))

  src_o <- factor(c("lo", "hi", NA), levels = c("lo", "hi"), ordered = TRUE)
  got_o <- tidycreel:::restore_group_types(
    data.frame(v = addNA(src_o, ifany = TRUE)),
    data.frame(v = src_o),
    "v"
  )$v
  expect_true(is.ordered(got_o))
  expect_identical(levels(got_o), c("lo", "hi"))

  # A label with no counterpart in the source has no value of that type to
  # come back as, so it comes back as NA rather than as a coerced guess.
  # Unreachable through the estimators -- svyby only reports groups the design
  # variables contain -- and pinned so it stays a deliberate answer.
  orphan <- tidycreel:::restore_group_types(
    data.frame(v = factor(c("10", "20", "99"))),
    data.frame(v = c(10, 20)),
    "v"
  )$v
  expect_identical(orphan, c(10, 20, NA_real_))
})

test_that("NAGRP-17 (#321): the sample-size floor names the unknown group distinctly", {
  # The floor now counts the unknown group, but its bullet label was built with
  # `paste0(by_vars, "=", vals)`, which renders a missing value as the literal
  # string "NA" -- the very label a group may genuinely carry. A design with
  # both produced two bullets that both read `Group gear=NA: n=6`, leaving no
  # way to tell which group had failed the floor.
  data(example_calendar, package = "tidycreel")
  data(example_counts, package = "tidycreel")
  n <- 18L
  iv <- data.frame(
    date = rep(example_calendar$date, length.out = n),
    hours_fished = rep(c(2, 3, 4), length.out = n),
    catch_total = rep(c(4, 6, 9), length.out = n),
    catch_kept = rep(c(2, 3, 5), length.out = n),
    trip_status = "complete",
    interview_id = seq_len(n),
    gear = rep(c("bank", "NA", NA_character_), each = 6L),
    stringsAsFactors = FALSE
  )
  d <- suppressMessages(creel_design(example_calendar, date = date, strata = day_type)) # nolint: object_usage_linter
  d <- suppressWarnings(suppressMessages(add_counts(d, example_counts)))
  d <- suppressWarnings(suppressMessages(add_interviews(
    d, iv,
    catch = catch_total, # nolint: object_usage_linter
    effort = hours_fished, # nolint: object_usage_linter
    harvest = catch_kept, # nolint: object_usage_linter
    trip_status = trip_status # nolint: object_usage_linter
  )))

  err <- tryCatch(
    suppressWarnings(suppressMessages(estimate_catch_rate(d, by = gear))),
    error = function(e) e
  )
  expect_s3_class(err, "error")
  msg <- conditionMessage(err)

  # All three groups are counted, and each is named once and unambiguously.
  expect_match(msg, "Insufficient sample size in 3 groups")
  expect_equal(length(gregexpr("gear=NA", msg)[[1]]), 1L)
  expect_match(msg, "gear=<unknown>", fixed = TRUE)
})
