# survey::svydesign(strata = ~a + b) does not stratify by the a x b
# interaction: a multi-term strata formula gives one strata variable per
# sampling stage, so the days were stratified by `a` alone. About twenty survey
# rebuilds passed reformulate(strata_cols), so with strata = c(day_type, month)
# the point estimates stayed right (the weights are per cell) while the SE and
# the FPC were taken over day_type only: an expanded effort total reported SE
# 147.7 where the cells give 187.9 (GH #422). Every fixture in the suite used
# one strata column, so none of them could see it.

mcs_calendar <- function() {
  dates <- seq(as.Date("2025-08-18"), as.Date("2025-09-14"), by = "day")
  data.frame(
    date = dates,
    day_type = ifelse(as.POSIXlt(dates)$wday %in% c(0, 6), "weekend", "weekday"), # locale-free
    month = format(dates, "%m")
  )
}

# Two sampled days in each day_type x month cell, with effort that differs by
# month, so stratifying by day_type alone pools the months and changes the SE.
mcs_design <- function() {
  cal <- mcs_calendar()
  sampled <- as.Date(c(
    "2025-08-19", "2025-08-21", "2025-09-03", "2025-09-09",
    "2025-08-23", "2025-08-24", "2025-09-06", "2025-09-13"
  ))
  counts <- cal[cal$date %in% sampled, ]
  counts$effort_hours <- c(20, 22, 60, 62, 18, 21, 58, 61)
  d <- suppressMessages(creel_design(cal, date = date, strata = c(day_type, month))) # nolint: object_usage_linter
  suppressWarnings(suppressMessages(add_counts(d, counts)))
}

test_that("#422: a two-column stratum key stratifies by the cells, not the first column", {
  df <- data.frame(id = 1:8, a = rep(c("x", "y"), each = 4), b = rep(c("p", "q"), 4), y = c(1, 3, 2, 8, 5, 9, 4, 7))
  key <- strata_design_key(df, c("a", "b"))
  svy <- survey::svydesign(ids = ~id, strata = key$strata, weights = rep(2, 8), data = key$data, nest = TRUE)
  expect_identical(length(unique(svy$strata[, 1])), 4L)
  # The formula form callers pass is normalised the same way.
  key_f <- strata_design_key(df, ~ a + b)
  expect_identical(levels(key_f$data$.strata), levels(key$data$.strata))
  # One column is left as it is.
  expect_identical(all.vars(strata_design_key(df, "a")$strata), "a")
  expect_null(strata_design_key(df, NULL)$strata)
})

test_that("#422: the key keeps two cells apart even when their labels share a dot", {
  # interaction()'s default "." separator turns a = "x.y", b = "z" and
  # a = "x", b = "y.z" into the same label, "x.y.z".
  df <- data.frame(a = c("x.y", "x"), b = c("z", "y.z"))
  expect_length(levels(strata_design_key(df, c("a", "b"))$data$.strata), 2L)
})

test_that("#422: build_interview_survey() stratifies a multi-term formula by the cells", {
  df <- data.frame(a = rep(c("x", "y"), each = 6), b = rep(c("p", "q", "r"), 4), v = 1:12)
  svy <- build_interview_survey(df, strata = ~ a + b)
  expect_identical(length(unique(svy$strata[, 1])), 6L)
})

test_that("#422: an expanded effort total on two strata columns takes its SE over the cells", {
  d <- mcs_design()
  r <- suppressWarnings(estimate_effort(d, target = "period_total"))$estimates

  # Reference: the same weights and FPC on an explicit cell stratum.
  td <- get_effort_target_design(d, "period_total") # nolint: object_usage_linter
  ref_data <- td$variables
  ref_data$.cell <- paste(ref_data$day_type, ref_data$month)
  ref <- survey::svydesign(
    ids = ~date, strata = ~.cell, weights = ~.expansion_weight,
    fpc = ~.N_avail, data = ref_data, nest = TRUE
  )
  ref_total <- survey::svytotal(~effort_hours, ref)

  expect_equal(r$estimate, as.numeric(coef(ref_total)))
  expect_equal(r$se, as.numeric(survey::SE(ref_total)), tolerance = 1e-8)
  # The day_type-only stratification gave 147.7; the cells give 187.9.
  expect_equal(r$se, 187.851, tolerance = 1e-4)
})

test_that("#422: the sampled-day effort total on two strata columns is unchanged", {
  # design$survey was already built on an interaction; routing it through the
  # shared key must not move it.
  d <- mcs_design()
  r <- suppressWarnings(estimate_effort(d))$estimates
  ref_data <- d$counts
  ref_data$.cell <- paste(ref_data$day_type, ref_data$month)
  # survey notes "No weights or probabilities supplied" for this reference.
  ref <- suppressWarnings(survey::svydesign(ids = ~date, strata = ~.cell, data = ref_data, nest = TRUE))
  ref_total <- suppressWarnings(survey::svytotal(~effort_hours, ref))
  expect_equal(r$estimate, as.numeric(coef(ref_total)))
  expect_equal(r$se, as.numeric(survey::SE(ref_total)), tolerance = 1e-8)
})

test_that("#422: a single-PSU stratum on two columns is named readably", {
  cal <- mcs_calendar()
  sampled <- as.Date(c("2025-08-19", "2025-08-21", "2025-09-03", "2025-08-23", "2025-08-24", "2025-09-06", "2025-09-13"))
  counts <- cal[cal$date %in% sampled, ]
  counts$effort_hours <- seq_len(nrow(counts)) * 10
  d <- suppressMessages(creel_design(cal, date = date, strata = c(day_type, month))) # nolint: object_usage_linter
  d <- suppressWarnings(suppressMessages(add_counts(d, counts)))
  err <- tryCatch(suppressWarnings(estimate_effort(d)), error = function(e) e)
  expect_s3_class(err, "error")
  msg <- conditionMessage(err)
  expect_match(msg, "weekday / 09", fixed = TRUE)
  expect_false(grepl("\u001f", msg, fixed = TRUE))
})
