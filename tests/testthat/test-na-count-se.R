# GH #566: an unknown count makes its total unknown, standard error included.
#
# survey::svytotal() with no finite-population correction returns an NA total
# beside a numeric SE, and the replicate methods abort ("All replicates
# contained NAs"). On target = "sampled_days" an NA count gave estimate NA with
# SE 13.68; per group the SE was NaN. Camera designs have reported one unknown
# SE since #215; instantaneous effort now does the same, and a group or section
# without an unknown count is unaffected.

q566 <- function(x) suppressWarnings(suppressMessages(x))

na_design <- function(value = NA_real_) {
  cnt <- example_counts
  cnt$effort_hours[1] <- value # 2024-06-01, a weekend day
  q566(add_counts(creel_design(example_calendar, date = date, strata = day_type), cnt))
}

se_cols <- c("estimate", "se", "se_between", "se_within", "ci_lower", "ci_upper")

test_that("an unknown count gives an unknown total and SE on every target (#566)", {
  for (target in c("period_total", "stratum_total", "sampled_days")) {
    e <- q566(estimate_effort(na_design(), target = target))$estimates
    for (col in se_cols) expect_true(is.na(e[[col]]), label = paste(target, col))
  }
})

test_that("the replicate methods report NA rather than abort (#566)", {
  for (vm in c("bootstrap", "jackknife")) {
    e <- q566(estimate_effort(na_design(), variance = vm, target = "sampled_days"))$estimates
    for (col in se_cols) expect_true(is.na(e[[col]]), label = paste(vm, col))
  }
})

test_that("only the group holding the unknown count is unknown (#566)", {
  for (target in c("period_total", "sampled_days")) {
    na_by <- q566(estimate_effort(na_design(), target = target, by = day_type))$estimates
    # The weekday total takes nothing from weekend rows, so it must equal the
    # weekday total with the weekend count known.
    known <- q566(estimate_effort(na_design(45.2), target = target, by = day_type))$estimates
    wk_na <- na_by[na_by$day_type == "weekday", ]
    wk_known <- known[known$day_type == "weekday", ]
    for (col in se_cols) expect_equal(wk_na[[col]], wk_known[[col]], label = paste(target, col))
    we <- na_by[na_by$day_type == "weekend", ]
    for (col in se_cols) expect_true(is.na(we[[col]]), label = paste(target, "weekend", col))
  }
})

test_that("a replicate grouped estimate keeps the known group (#566)", {
  set.seed(566)
  e <- q566(estimate_effort(na_design(), variance = "jackknife", by = day_type))$estimates
  expect_true(is.finite(e$estimate[e$day_type == "weekday"]))
  expect_true(is.finite(e$se[e$day_type == "weekday"]))
  expect_true(is.na(e$se[e$day_type == "weekend"]))
})

test_that("a section with an unknown count is unknown, the others are not (#566)", {
  sc <- example_sections_counts
  sc$effort_hours[sc$section == "North"][1] <- NA
  d <- q566(add_counts(
    add_sections(
      creel_design(example_sections_calendar, date = date, strata = day_type),
      data.frame(section = c("North", "Central", "South")),
      section_col = section
    ),
    sc,
    count_col = effort_hours
  ))
  e <- q566(estimate_effort(d, target = "sampled_days"))$estimates
  north <- e[e$section == "North", ]
  for (col in c("estimate", "se", "se_between", "se_within")) {
    expect_true(is.na(north[[col]]), label = col)
  }
  expect_true(is.na(e$se[e$section == ".lake_total"]))
  expect_true(all(is.finite(e$se[e$section %in% c("Central", "South")])))
})

test_that("the totals built on an unknown effort are unknown (#566)", {
  d <- q566(add_interviews(na_design(), example_interviews,
    catch = catch_total, effort = hours_fished, harvest = catch_kept,
    trip_status = trip_status, n_anglers = n_anglers
  ))
  for (target in c("period_total", "sampled_days")) {
    for (fn in list(estimate_total_catch, estimate_total_harvest)) {
      e <- q566(fn(d, target = target))$estimates
      expect_true(is.na(e$estimate))
      expect_true(is.na(e$se))
    }
  }
})
