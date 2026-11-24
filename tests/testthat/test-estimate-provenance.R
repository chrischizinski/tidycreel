# Provenance stamps on estimates (GH #585 part 2)
#
# Summing or differencing two estimates adds their variances, which is right
# only if the parts share nothing that was estimated. Two shared components
# are invisible from the numbers: one mean_party_size() result expanding the
# counts of both parts, and one aerial calibration (visibility correction,
# angler ratio) dividing both. Their labels repeat across designs
# (expansion_group "1"), so a later combine_estimates() needs a fingerprint of
# WHICH estimate entered. These tests pin that fingerprint: equal for a shared
# estimate, different for independent ones, NULL where nothing estimated
# entered, NA where something did and its identity is lost -- never NULL for
# that, which would read as "nothing shared" and let the misuse through.

pv_counts <- function() {
  data.frame(
    date = as.Date("2024-06-01") + 0:5,
    day_type = rep(c("weekday", "weekend"), 3),
    bank_anglers = c(3, 5, 2, 4, 8, 10),
    angler_boats = c(6, 2, 4, 8, 5, 5),
    stringsAsFactors = FALSE
  )
}

pv_design <- function(counts, count_time_col = NULL) {
  calendar <- data.frame(
    date = as.Date("2024-06-01") + 0:5,
    day_type = rep(c("weekday", "weekend"), 3),
    stringsAsFactors = FALSE
  )
  design <- creel_design(calendar, date = date, strata = day_type) # nolint: object_usage_linter
  if (is.null(count_time_col)) {
    return(suppressWarnings(add_counts(design, counts, count_col = "angler_count"))) # nolint: object_usage_linter
  }
  suppressWarnings(add_counts( # nolint: object_usage_linter
    design, counts,
    count_col = "angler_count", count_time_col = count_time_col
  ))
}

pv_derive <- function(counts = pv_counts(), party_size = 2.5, party_size_se = 0.1) {
  derive_angler_count( # nolint: object_usage_linter
    counts,
    bank = bank_anglers, boat_count = angler_boats,
    party_size = party_size, party_size_se = party_size_se
  )
}

pv_effort <- function(design, ...) suppressWarnings(estimate_effort(design, ...)) # nolint: object_usage_linter

pv_interviews <- function(design) {
  # Two a day: a rate needs at least 10 interviews.
  interviews <- data.frame(
    date = rep(as.Date("2024-06-01") + 0:5, each = 2),
    day_type = rep(rep(c("weekday", "weekend"), 3), each = 2),
    hours = c(2, 3, 2.5, 4, 3, 2, 1.5, 2, 3.5, 2, 4, 1),
    harvest = c(1, 0, 2, 3, 1, 1, 0, 1, 2, 0, 1, 1),
    status = "complete",
    stringsAsFactors = FALSE
  )
  suppressMessages(suppressWarnings(add_interviews( # nolint: object_usage_linter
    design, interviews,
    catch = harvest, effort = hours, harvest = harvest, trip_status = status
  )))
}

# ---- party size ------------------------------------------------------------

test_that("one mean_party_size() result gives two designs the same fingerprint", {
  # The misuse #585 exists to catch: a single party-size estimate expanding
  # both parts of a later sum. Built through mean_party_size(), as a user would.
  iv <- data.frame(n_anglers = c(2, 3, 2, 4, 3, 1))
  mps <- mean_party_size(iv, n_anglers) # nolint: object_usage_linter
  build <- function(counts) {
    derive_angler_count( # nolint: object_usage_linter
      counts,
      bank = bank_anglers, boat_count = angler_boats, party_size = mps
    )
  }
  day <- pv_effort(pv_design(build(pv_counts())))
  other_counts <- pv_counts()
  other_counts$angler_boats <- other_counts$angler_boats + 3
  night <- pv_effort(pv_design(build(other_counts)))

  expect_false(is.null(day$provenance$party_size))
  expect_identical(day$provenance$party_size, night$provenance$party_size)
})

test_that("independent party-size estimates give disjoint fingerprints", {
  a <- pv_effort(pv_design(pv_derive(party_size = 2.5, party_size_se = 0.1)))
  b <- pv_effort(pv_design(pv_derive(party_size = 2.4, party_size_se = 0.1)))
  c <- pv_effort(pv_design(pv_derive(party_size = 2.5, party_size_se = 0.2)))

  expect_length(intersect(a$provenance$party_size, b$provenance$party_size), 0L)
  # The SE is part of the identity: same mean from a different sample.
  expect_length(intersect(a$provenance$party_size, c$provenance$party_size), 0L)
})

test_that("a fingerprint does not depend on row order or on the other rows", {
  # The fingerprint is built from text. format() pads a vector to a common
  # width, so 2 next to 10.5 printed " 2.0" and hashed differently from 2
  # alone -- one estimate, two identities, and the shared case passes.
  alone <- party_size_fingerprint(2, 0.1) # nolint: object_usage_linter
  beside <- party_size_fingerprint(c(2, 10.5), c(0.1, 0.25)) # nolint: object_usage_linter
  expect_identical(beside[[1]], alone)

  ordered <- pv_effort(pv_design(pv_derive()))
  reversed <- pv_effort(pv_design(pv_derive()[6:1, ]))
  expect_identical(reversed$provenance, ordered$provenance)
})

test_that("a multiplier with no standard error records no party-size provenance", {
  # A constant party size is not an estimate with error, so nothing can be
  # shared: NULL, exactly where se_expansion is NULL.
  counts <- derive_angler_count( # nolint: object_usage_linter
    pv_counts(),
    bank = bank_anglers, boat_count = angler_boats, party_size = 2.5
  )
  result <- pv_effort(pv_design(counts))

  expect_null(result$se_expansion)
  expect_null(result$provenance$party_size)
})

test_that("counts without expansion_id still attach, with provenance unknown", {
  # Counts derived before the column existed (or with it dropped) carry the
  # component but not its identity. Refusing them would break saved 8.0
  # pipelines; recording NULL would claim nothing shared. NA is the truth.
  counts <- pv_derive()
  counts$expansion_id <- NULL
  result <- pv_effort(pv_design(counts))

  expect_false(is.null(result$se_expansion))
  expect_identical(result$provenance$party_size, NA_character_)
})

test_that("derive_angler_count() refuses to overwrite an existing expansion_id", {
  counts <- pv_counts()
  counts$expansion_id <- "stale"
  expect_error(pv_derive(counts), "expansion_id")
})

test_that("the fingerprint survives within-day aggregation and by_type rows", {
  two_counts <- pv_counts()[rep(1:6, each = 2), ]
  two_counts$count_time <- rep(c("am", "pm"), 6)
  aggregated <- pv_effort(pv_design(pv_derive(two_counts), count_time_col = "count_time"))
  expect_identical(
    aggregated$provenance$party_size,
    pv_effort(pv_design(pv_derive()))$provenance$party_size
  )

  long <- derive_angler_count( # nolint: object_usage_linter
    pv_counts(),
    bank = bank_anglers, boat_count = angler_boats,
    party_size = 2.5, party_size_se = 0.1, by_type = TRUE
  )
  expect_identical(unique(long$expansion_id), party_size_fingerprint(2.5, 0.1)) # nolint: object_usage_linter
})

test_that("grouped effort and totals carry the effort's party-size stamp", {
  design <- pv_design(pv_derive())
  effort <- pv_effort(design)
  stamp <- effort$provenance$party_size

  expect_identical(pv_effort(design, by = day_type)$provenance$party_size, stamp)

  with_iv <- pv_interviews(design)
  harvest <- suppressWarnings(estimate_total_harvest(with_iv)) # nolint: object_usage_linter
  catch <- suppressWarnings(estimate_total_catch(with_iv)) # nolint: object_usage_linter
  expect_identical(harvest$provenance$party_size, stamp)
  expect_identical(catch$provenance$party_size, stamp)
})

test_that("rates record no party-size provenance", {
  # A rate uses interviews only. Stamping it would make a later comparison of
  # two rates refuse on a multiplier neither used.
  with_iv <- pv_interviews(pv_design(pv_derive()))
  rate <- suppressWarnings(estimate_harvest_rate(with_iv)) # nolint: object_usage_linter
  expect_null(rate$provenance$party_size)
  expect_null(rate$provenance$aerial_calibration)
})

# ---- aerial calibration ------------------------------------------------------

pv_aerial <- function(v = 0.9, v_se = 0.05, a = 1, a_se = 0) {
  cal <- data.frame(
    date = as.Date("2024-07-01") + 0:7,
    day_type = rep(c("weekday", "weekday", "weekend", "weekend"), 2)
  )
  # "none" declares that no correction was studied; it takes no SE.
  d <- if (identical(v, "none")) {
    creel_design( # nolint: object_usage_linter
      cal,
      date = date, strata = day_type, survey_type = "aerial",
      visibility_correction = "none",
      angler_ratio = a, angler_ratio_se = a_se, h_open = 14
    )
  } else {
    creel_design( # nolint: object_usage_linter
      cal,
      date = date, strata = day_type, survey_type = "aerial",
      visibility_correction = v, visibility_se = v_se,
      angler_ratio = a, angler_ratio_se = a_se, h_open = 14
    )
  }
  sampled <- cal[c(1, 2, 5, 3, 4, 8), ]
  counts <- data.frame(sampled, n_anglers = c(22L, 18L, 30L, 45L, 38L, 51L))
  d <- add_counts(d, counts) # nolint: object_usage_linter
  iv <- data.frame(
    interview_id = 1:30,
    date = rep(sampled$date, each = 5),
    day_type = rep(sampled$day_type, each = 5),
    trip_status = "complete",
    hours_fished = rep(c(2.5, 3, 1.5, 4, 2, 3.5, 1, 2.5, 3, 4.5), 3),
    kept = rep(c(0L, 1L, 1L, 0L, 1L, 0L, 2L, 1L, 0L, 1L), 3)
  )
  suppressMessages(suppressWarnings(add_interviews( # nolint: object_usage_linter
    d, iv,
    catch = kept, harvest = kept, effort = hours_fished,
    trip_status = trip_status, n_anglers = 1
  )))
}

pv_aerial_estimates <- function(d) {
  q <- function(expr) suppressWarnings(suppressMessages(expr))
  list(
    effort = q(estimate_effort(d)), # nolint: object_usage_linter
    effort_by = q(estimate_effort(d, by = day_type)), # nolint: object_usage_linter
    harvest = q(estimate_total_harvest(d)), # nolint: object_usage_linter
    harvest_by = q(estimate_total_harvest(d, by = day_type)), # nolint: object_usage_linter
    catch = q(estimate_total_catch(d)) # nolint: object_usage_linter
  )
}

test_that("every aerial effort and total on one calibration carries one stamp", {
  stamps <- lapply(pv_aerial_estimates(pv_aerial()), function(x) x$provenance$aerial_calibration)
  expect_false(any(vapply(stamps, is.null, logical(1))))
  expect_length(unique(stamps), 1L)

  # A second design on the same calibration values shares it.
  again <- pv_aerial_estimates(pv_aerial())$harvest$provenance$aerial_calibration
  expect_identical(again, stamps$effort)
})

test_that("a different calibration gives a different stamp", {
  base <- pv_aerial_estimates(pv_aerial())$effort$provenance$aerial_calibration
  other_v <- pv_aerial_estimates(pv_aerial(v = 0.8))$effort$provenance$aerial_calibration
  other_se <- pv_aerial_estimates(pv_aerial(a_se = 0.02))$effort$provenance$aerial_calibration
  expect_false(identical(base, other_v))
  expect_false(identical(base, other_se))
})

test_that("an exact calibration records no aerial provenance; an unknown SE does", {
  # SEs of exactly 0 declare the calibration known: nothing to share.
  exact <- pv_aerial_estimates(pv_aerial(v_se = 0, a_se = 0))
  expect_true(all(vapply(exact, function(x) is.null(x$provenance$aerial_calibration), logical(1))))

  # visibility_correction = "none" leaves an NA SE: uncertainty of unknown
  # size, still common to every part built on that design's assumption.
  unknown <- pv_aerial_estimates(pv_aerial(v = "none"))
  expect_false(is.null(unknown$effort$provenance$aerial_calibration))
})

test_that("aerial rates record no calibration provenance", {
  rate <- suppressWarnings(estimate_harvest_rate(pv_aerial())) # nolint: object_usage_linter
  expect_null(rate$provenance$aerial_calibration)
})

# ---- the setter and the validator -------------------------------------------

pv_est <- function() pv_effort(pv_design(pv_derive()))

test_that("a slot changed after construction is validated like one set at it", {
  x <- pv_est()
  expect_error(set_estimate_slots(x, aerial_calibration_rel_var = -1), "non-negative") # nolint: object_usage_linter
  expect_error(set_estimate_slots(x, ci_df = c(1, 2, 3)), "one value per row") # nolint: object_usage_linter
  expect_error(set_estimate_slots(x, method = 1), "method must be character") # nolint: object_usage_linter
  ok <- set_estimate_slots(x, aerial_calibration_rel_var = 0.01) # nolint: object_usage_linter
  expect_identical(ok$aerial_calibration_rel_var, 0.01)
})

test_that("derived slots cannot be set after construction", {
  # se_expansion, its party_size mirror and provenance are derived from one
  # another at construction; setting one alone is how they would disagree.
  x <- pv_est()
  expect_error(set_estimate_slots(x, se_expansion = 0), "can be set") # nolint: object_usage_linter
  expect_error(set_estimate_slots(x, provenance = list()), "can be set") # nolint: object_usage_linter
  comps <- x$se_components
  comps$party_size <- 0
  expect_error(set_estimate_slots(x, se_components = comps), "mirror se_expansion") # nolint: object_usage_linter
})

test_that("setting a slot to NULL keeps the slot", {
  x <- set_estimate_slots(pv_est(), aerial_calibration_rel_var = NULL) # nolint: object_usage_linter
  expect_true("aerial_calibration_rel_var" %in% names(x))
  expect_null(x$aerial_calibration_rel_var)
})

test_that("no code writes a governed slot except through the setter", {
  # The validator only protects what passes through it. A direct
  # `result$aerial_calibration_rel_var <- ...` -- the form this replaced -- is
  # invisible to it. Slot names shared with data frames and designs (estimates,
  # method, design, unit, warnings) cannot be told apart by name and are not
  # checked here.
  governed <- c(
    "se_components", "se_expansion", "expansion_decomposition", "ci_df",
    "provenance", "aerial_calibration_rel_var", "estimator", "variance_method",
    "by_vars", "effort_target"
  )
  r_dir <- test_path("..", "..", "R")
  skip_if_not(dir.exists(r_dir), "package R/ sources not available")
  offenders <- character()
  for (f in list.files(r_dir, pattern = "[.]R$", full.names = TRUE)) {
    exprs <- parse(f, keep.source = TRUE)
    data <- utils::getParseData(exprs)
    assign_ids <- data$parent[data$token %in% c("LEFT_ASSIGN", "EQ_ASSIGN") & data$text != "="]
    for (id in unique(assign_ids)) {
      kids <- data[data$parent == id & !data$token %in% c("COMMENT"), ]
      lhs <- kids[order(kids$line1, kids$col1), ][1, ]
      if (lhs$token != "expr") next
      lhs_text <- utils::getParseText(data, lhs$id)
      m <- regmatches(lhs_text, regexec("(\\$|\\[\\[\")([A-Za-z_.]+)\"?\\]?\\]?$", lhs_text))[[1]]
      if (length(m) == 3L && m[[3]] %in% governed) {
        offenders <- c(offenders, paste0(basename(f), ":", lhs$line1, ": ", lhs_text))
      }
    }
  }
  expect_identical(offenders, character())
})
