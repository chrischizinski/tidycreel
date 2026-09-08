# Tests for GH #304: `targeted` on a `by = species` request.
#
# WHY these tests exist
#
# `targeted = FALSE` means "drop the trips that caught none of the species I am
# asking about". Before #304 the mean-of-ratios branch applied that test to the
# design's TOTAL catch column, upstream of the species split, so a trip that
# caught one fish of any species counted as non-zero however many of THIS
# species it held. On a design where every interview caught something the
# argument therefore excluded nothing, silently, and returned the untargeted
# rate under a targeted label. The 70% mis-specification warning read the same
# wrong column and so never fired on the very designs it exists to flag.
#
# The fixture below is built so that the OLD behaviour is provably inert:
# `panfish` is caught by every interview, so total catch is never zero. Any
# assertion here that passes on the pre-#304 code is not testing #304.

# ---- Fixtures ----------------------------------------------------------------

#' 50 incomplete-trip interviews; `panfish` caught by all 50, `bass` by 12.
#'
#' bass is 76% zero-for-species: above the 70% mis-specification threshold, and
#' the 12 survivors clear the n >= 10 ratio floor, so `targeted = FALSE` yields
#' an estimable rate rather than an abort. That is what lets these tests pin a
#' moved NUMBER instead of only an error.
make_species_targeted_design <- function() {
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-08", "2024-06-09")),
    day_type = c("weekday", "weekday", "weekend", "weekend"),
    stringsAsFactors = FALSE
  )

  n <- 50L
  n_bass <- 12L

  # Deterministic effort: 1.0 .. 3.45 hours, all clear of the 0.5h truncation.
  hours <- 1 + (seq_len(n) - 1L) * 0.05
  # Deterministic per-species counts.
  bass_count <- c(seq_len(n_bass) %% 4L + 1L, rep(0L, n - n_bass))
  panfish_count <- rep(c(1L, 2L, 3L), length.out = n)

  interviews <- data.frame(
    interview_id = seq_len(n),
    date = as.Date(rep(
      c("2024-06-01", "2024-06-02", "2024-06-08", "2024-06-09"),
      length.out = n
    )),
    catch_total = bass_count + panfish_count,
    hours_fished = hours,
    trip_status = rep("incomplete", n),
    trip_duration = hours,
    stringsAsFactors = FALSE
  )

  catch <- rbind(
    data.frame(
      interview_id = seq_len(n),
      species = "panfish",
      count = panfish_count,
      catch_type = "caught",
      stringsAsFactors = FALSE
    ),
    data.frame(
      interview_id = seq_len(n_bass),
      species = "bass",
      count = bass_count[seq_len(n_bass)],
      catch_type = "caught",
      stringsAsFactors = FALSE
    )
  )

  design <- suppressMessages(creel_design(cal, date = date, strata = day_type))
  design <- suppressMessages(suppressWarnings(add_interviews(
    design,
    interviews,
    catch = catch_total,
    effort = hours_fished,
    trip_status = trip_status,
    trip_duration = trip_duration
  )))
  suppressMessages(suppressWarnings(add_catch(
    design,
    catch,
    catch_uid = interview_id,
    interview_uid = interview_id,
    species = species,
    count = count,
    catch_type = catch_type
  )))
}

#' Same shape, but `bass` is caught by only 3 of 50 interviews.
#'
#' Under `targeted = FALSE` the survivors fall below the n >= 10 ratio floor.
#' The point of this fixture is that the abort is the CORRECT outcome: a
#' targeted rate from three trips is not estimable, and an error naming the
#' sample size beats an untargeted number wearing a targeted label.
make_species_targeted_sparse_design <- function() {
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-08", "2024-06-09")),
    day_type = c("weekday", "weekday", "weekend", "weekend"),
    stringsAsFactors = FALSE
  )

  n <- 50L
  n_bass <- 3L

  hours <- 1 + (seq_len(n) - 1L) * 0.05
  bass_count <- c(rep(2L, n_bass), rep(0L, n - n_bass))
  panfish_count <- rep(c(1L, 2L, 3L), length.out = n)

  interviews <- data.frame(
    interview_id = seq_len(n),
    date = as.Date(rep(
      c("2024-06-01", "2024-06-02", "2024-06-08", "2024-06-09"),
      length.out = n
    )),
    catch_total = bass_count + panfish_count,
    hours_fished = hours,
    trip_status = rep("incomplete", n),
    trip_duration = hours,
    stringsAsFactors = FALSE
  )

  catch <- rbind(
    data.frame(
      interview_id = seq_len(n),
      species = "panfish",
      count = panfish_count,
      catch_type = "caught",
      stringsAsFactors = FALSE
    ),
    data.frame(
      interview_id = seq_len(n_bass),
      species = "bass",
      count = bass_count[seq_len(n_bass)],
      catch_type = "caught",
      stringsAsFactors = FALSE
    )
  )

  design <- suppressMessages(creel_design(cal, date = date, strata = day_type))
  design <- suppressMessages(suppressWarnings(add_interviews(
    design,
    interviews,
    catch = catch_total,
    effort = hours_fished,
    trip_status = trip_status,
    trip_duration = trip_duration
  )))
  suppressMessages(suppressWarnings(add_catch(
    design,
    catch,
    catch_uid = interview_id,
    interview_uid = interview_id,
    species = species,
    count = count,
    catch_type = catch_type
  )))
}

sp_rate <- function(result, sp) {
  est <- result$estimates
  est$estimate[est$species == sp]
}

# ---- The fixture really is inert for the OLD test ----------------------------

test_that("SPECIES-TARGETED-00: every interview has non-zero TOTAL catch", {
  design <- make_species_targeted_design()
  # If this ever becomes FALSE the fixture stops discriminating: the old
  # total-catch test would start excluding rows on its own, and the tests below
  # could pass without the per-species test existing at all.
  expect_equal(sum(design$interviews[[design$catch_col]] == 0), 0L)

  bass <- tidycreel:::make_species_catch_for_interviews(design, "bass", "caught")
  expect_equal(sum(bass$.species_count == 0), 38L)
})

# ---- targeted = FALSE moves the number ---------------------------------------

test_that("SPECIES-TARGETED-01: MOR targeted=FALSE excludes this species' zeros", {
  design <- make_species_targeted_design()

  res_true <- suppressWarnings(
    estimate_catch_rate(design, by = species, estimator = "mor", targeted = TRUE)
  )
  res_false <- suppressWarnings(
    estimate_catch_rate(design, by = species, estimator = "mor", targeted = FALSE)
  )

  # The whole defect: these were identical to the digit before #304.
  expect_false(isTRUE(all.equal(sp_rate(res_true, "bass"), sp_rate(res_false, "bass"))))
  # Excluding zeros can only raise a mean of non-negative ratios.
  expect_gt(sp_rate(res_false, "bass"), sp_rate(res_true, "bass"))

  # panfish has no zeros, so its rate must NOT move -- the exclusion is per
  # species, not a blanket filter on the interview set.
  expect_equal(sp_rate(res_false, "panfish"), sp_rate(res_true, "panfish"))
})

test_that("SPECIES-TARGETED-02: the targeted rate equals MOR over the caught trips", {
  design <- make_species_targeted_design()

  res_false <- suppressWarnings(
    estimate_catch_rate(design, by = species, estimator = "mor", targeted = FALSE)
  )

  bass <- tidycreel:::make_species_catch_for_interviews(design, "bass", "caught")
  caught <- bass[bass$.species_count > 0, , drop = FALSE]
  expected <- mean(caught$.species_count / caught[[design$angler_effort_col]])

  # Pins the estimand, not just "it changed": mean of per-trip ratios over the
  # trips that caught bass. A filter that dropped the wrong rows would still
  # move the number but would not land on this value.
  expect_equal(sp_rate(res_false, "bass"), expected, tolerance = 1e-8)
  expect_equal(nrow(caught), 12L)
})

test_that("SPECIES-TARGETED-03: exclusion warning names the species and percentage", {
  design <- make_species_targeted_design()
  expect_warning(
    estimate_catch_rate(design, by = species, estimator = "mor", targeted = FALSE),
    regexp = "bass.*38 zero-catch trips excluded \\(76% of trips\\)"
  )
})

# ---- the >70% mis-specification warning, per species -------------------------

test_that("SPECIES-TARGETED-04: targeted=TRUE warns on a species that is mostly zeros", {
  design <- make_species_targeted_design()
  # Never fired before #304: total catch was non-zero on all 50 trips, so the
  # rate it measured was 0%, not bass's 76%.
  expect_warning(
    estimate_catch_rate(design, by = species, estimator = "mor", targeted = TRUE),
    regexp = "bass.*76% of trips caught none of this species"
  )
})

test_that("SPECIES-TARGETED-05: no mis-specification warning for a species with no zeros", {
  design <- make_species_targeted_design()
  warns <- character(0)
  withCallingHandlers(
    estimate_catch_rate(design, by = species, estimator = "mor", targeted = TRUE),
    warning = function(w) {
      warns <<- c(warns, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  # panfish is caught on every trip; warning it would be a false alarm.
  expect_false(any(grepl("panfish.*caught none of this species", warns)))
})

test_that("SPECIES-TARGETED-06: targeted=TRUE does not change any estimate", {
  design <- make_species_targeted_design()
  res <- suppressWarnings(
    estimate_catch_rate(design, by = species, estimator = "mor", targeted = TRUE)
  )
  bass <- tidycreel:::make_species_catch_for_interviews(design, "bass", "caught")
  expected <- mean(bass$.species_count / bass[[design$angler_effort_col]])

  # The new warning is diagnostic only. `mor` is the estimator #304 changes, so
  # this pins the case that could move: leaving `targeted` at its default must
  # keep every interview and reproduce the plain per-species MOR rate. The
  # package default estimator, ratio-of-means, is pinned in -08.
  expect_equal(sp_rate(res, "bass"), expected, tolerance = 1e-8)
})

# ---- too few survivors is an error, not a silent number ----------------------

test_that("SPECIES-TARGETED-07: sparse species aborts on the ratio sample floor", {
  design <- make_species_targeted_sparse_design()
  # Pre-#304 this returned the untargeted bass rate with no warning at all.
  # Aborting is the intended trade: three trips cannot support a ratio estimate.
  expect_error(
    suppressWarnings(
      estimate_catch_rate(design, by = species, estimator = "mor", targeted = FALSE)
    ),
    regexp = "requires n >= 10"
  )
})

# ---- scope: what #304 must NOT touch -----------------------------------------

test_that("SPECIES-TARGETED-08: ratio-of-means still ignores targeted", {
  design <- make_species_targeted_design()
  res_true <- suppressWarnings(
    estimate_catch_rate(
      design,
      by = species,
      estimator = "ratio-of-means",
      use_trips = "all",
      targeted = TRUE
    )
  )
  res_false <- suppressWarnings(
    estimate_catch_rate(
      design,
      by = species,
      estimator = "ratio-of-means",
      use_trips = "all",
      targeted = FALSE
    )
  )
  # Documented as ignored for ROM, which is the package default. Honouring it
  # here would move numbers for callers who never opted into a domain change.
  expect_equal(res_false$estimates$estimate, res_true$estimates$estimate)

  # Equality alone would hold even if both sides were wrong, so pin the value:
  # ratio-of-means is the ratio of the two totals over ALL interviews, zeros
  # included. If #304's exclusion ever leaked into ROM, bass would rise to the
  # 12-trip rate and this would fail.
  bass <- tidycreel:::make_species_catch_for_interviews(design, "bass", "caught")
  expected <- sum(bass$.species_count) / sum(bass[[design$angler_effort_col]])
  expect_equal(
    res_true$estimates$estimate[res_true$estimates$species == "bass"],
    expected,
    tolerance = 1e-8
  )
})

test_that("SPECIES-TARGETED-09: a non-species request still tests total catch", {
  design <- make_species_targeted_design()
  res_true <- suppressWarnings(
    estimate_catch_rate(design, estimator = "mor", targeted = TRUE)
  )
  res_false <- suppressWarnings(
    estimate_catch_rate(design, estimator = "mor", targeted = FALSE)
  )
  # No interview has zero total catch, so the ungrouped path excludes nothing --
  # unchanged by #304, which only redirects the column on a species request.
  expect_equal(res_false$estimates$estimate, res_true$estimates$estimate)
  expect_equal(res_false$estimates$n, res_true$estimates$n)
})

test_that("SPECIES-TARGETED-12: regression without by = species ignores targeted", {
  design <- make_species_targeted_design()
  # The `targeted` docs enumerate which estimators read the argument. The
  # non-species regression paths (estimate_cpue_regression_total() and
  # estimate_cpue_reg_grouped()) take no `targeted` parameter, so it cannot
  # reach them. Pinned because the docs make that a promise a reader can rely
  # on, and because an earlier draft of those docs claimed the opposite.
  flat_true <- suppressWarnings(suppressMessages(
    estimate_catch_rate(design, estimator = "regression", use_trips = "all", targeted = TRUE)
  ))
  flat_false <- suppressWarnings(suppressMessages(
    estimate_catch_rate(design, estimator = "regression", use_trips = "all", targeted = FALSE)
  ))
  expect_equal(flat_false$estimates$estimate, flat_true$estimates$estimate)

  grouped_true <- suppressWarnings(suppressMessages(
    estimate_catch_rate(design, by = date, estimator = "regression", use_trips = "all", targeted = TRUE)
  ))
  grouped_false <- suppressWarnings(suppressMessages(
    estimate_catch_rate(design, by = date, estimator = "regression", use_trips = "all", targeted = FALSE)
  ))
  expect_equal(grouped_false$estimates$estimate, grouped_true$estimates$estimate)
})

test_that("SPECIES-TARGETED-11: mortr behaves as mor on the species path", {
  design <- make_species_targeted_design()
  # `mortr` is absent from the estimator test inside estimate_cpue_species()
  # because it is normalised to "mor" above the species dispatch, so it cannot
  # arrive. Two independent reviewers read that absence as a missing case, so
  # the equivalence is pinned here rather than left to a comment.
  res_mor <- suppressWarnings(
    estimate_catch_rate(design, by = species, estimator = "mor", targeted = FALSE)
  )
  res_mortr <- suppressWarnings(
    estimate_catch_rate(design, by = species, estimator = "mortr", targeted = FALSE)
  )
  expect_equal(res_mortr$estimates$estimate, res_mor$estimates$estimate)
  expect_equal(res_mortr$estimates$n, res_mor$estimates$n)

  # ... and the mis-specification warning reaches mortr too.
  expect_warning(
    estimate_catch_rate(design, by = species, estimator = "mortr", targeted = TRUE),
    regexp = "bass.*76% of trips caught none of this species"
  )
})

test_that("SPECIES-TARGETED-10: regression species form is unchanged by #304", {
  design <- make_species_targeted_design()
  res <- suppressWarnings(
    estimate_catch_rate(
      design,
      by = species,
      estimator = "regression",
      use_trips = "all",
      targeted = FALSE
    )
  )
  bass <- tidycreel:::make_species_catch_for_interviews(design, "bass", "caught")
  caught <- bass[bass$.species_count > 0, , drop = FALSE]
  # #290's per-species exclusion feeds the same 12 trips to the origin slope,
  # which is OLS through zero: sum(xy) / sum(x^2), not the ratio of sums.
  x <- caught[[design$angler_effort_col]]
  expected <- sum(x * caught$.species_count) / sum(x^2)
  expect_equal(sp_rate(res, "bass"), expected, tolerance = 1e-8)
})
