# Tests for GH #307: `targeted` on the harvest and release rates.
#
# WHY these tests exist
#
# #304 gave the catch rate a per-species `targeted` test. The harvest and
# release rates had no `targeted` argument at all, so the same domain
# restriction was unavailable for HPUE and release rate even though both accept
# the mean-of-ratios estimator that reads it.
#
# Two things are pinned here. First, that `targeted` now works on both siblings
# and means the same thing it means for catch. Second, and more importantly,
# that it is REFUSED rather than silently ignored when there is no species to
# be about -- a knob that quietly does nothing is exactly what #304 was.
#
# The totals are deliberately excluded; see the "Why there is no `targeted`
# argument" section in their documentation, and SIBLING-TARGETED-08 below.

make_sibling_targeted_design <- function() {
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-08", "2024-06-09")),
    day_type = c("weekday", "weekday", "weekend", "weekend"),
    stringsAsFactors = FALSE
  )

  n <- 50L
  n_bass <- 12L

  hours <- 1 + (seq_len(n) - 1L) * 0.05

  # Counts are all >= 2 so that every recorded fish splits into at least one
  # harvested and one released: add_catch() refuses harvest + release > catch.
  bass_caught <- c((seq_len(n_bass) %% 3L) + 2L, rep(0L, n - n_bass))
  panfish_caught <- rep(c(2L, 3L, 4L), length.out = n)

  split_kept <- function(x) as.integer(ceiling(x / 2))
  bass_kept <- split_kept(bass_caught)
  panfish_kept <- split_kept(panfish_caught)

  interviews <- data.frame(
    interview_id = seq_len(n),
    date = as.Date(rep(
      c("2024-06-01", "2024-06-02", "2024-06-08", "2024-06-09"),
      length.out = n
    )),
    catch_total = bass_caught + panfish_caught,
    catch_kept = bass_kept + panfish_kept,
    hours_fished = hours,
    trip_status = rep("incomplete", n),
    trip_duration = hours,
    stringsAsFactors = FALSE
  )

  # Every interview records some panfish under all three types, so the
  # "recorded nothing at all" test is inert and only the per-species test bites.
  sp_rows <- function(sp, caught, kept, ids) {
    data.frame(
      interview_id = rep(ids, 3L),
      species = sp,
      count = c(caught[ids], kept[ids], (caught - kept)[ids]),
      catch_type = rep(c("caught", "harvested", "released"), each = length(ids)),
      stringsAsFactors = FALSE
    )
  }
  catch <- rbind(
    sp_rows("panfish", panfish_caught, panfish_kept, seq_len(n)),
    sp_rows("bass", bass_caught, bass_kept, seq_len(n_bass))
  )

  design <- suppressMessages(creel_design(cal, date = date, strata = day_type))
  design <- suppressMessages(suppressWarnings(add_interviews(
    design, interviews,
    catch = catch_total, effort = hours_fished, harvest = catch_kept,
    trip_status = trip_status, trip_duration = trip_duration
  )))
  suppressMessages(suppressWarnings(add_catch(
    design, catch,
    catch_uid = interview_id, interview_uid = interview_id,
    species = species, count = count, catch_type = catch_type
  )))
}

sib_rate <- function(result, sp) {
  est <- result$estimates
  est$estimate[est$species == sp]
}

# ---- the argument exists and bites ------------------------------------------

test_that("SIBLING-TARGETED-01: harvest targeted=FALSE drops this species' zeros", {
  design <- make_sibling_targeted_design()
  res_true <- suppressWarnings(suppressMessages(
    estimate_harvest_rate(design, by = species, estimator = "mor", targeted = TRUE, use_trips = "all")
  ))
  res_false <- suppressWarnings(suppressMessages(
    estimate_harvest_rate(design, by = species, estimator = "mor", targeted = FALSE, use_trips = "all")
  ))
  # Before #307 `targeted` was not a formal of this function at all, so this
  # call was an "unused argument" error rather than a different number.
  expect_gt(sib_rate(res_false, "bass"), sib_rate(res_true, "bass"))
  # panfish is harvested on every trip, so nothing is dropped for it.
  expect_equal(sib_rate(res_false, "panfish"), sib_rate(res_true, "panfish"))
})

test_that("SIBLING-TARGETED-02: the harvest rate equals MOR over the harvesting trips", {
  design <- make_sibling_targeted_design()
  res_false <- suppressWarnings(suppressMessages(
    estimate_harvest_rate(design, by = species, estimator = "mor", targeted = FALSE, use_trips = "all")
  ))
  bass <- tidycreel:::make_species_catch_for_interviews(design, "bass", "harvested")
  kept <- bass[bass$.species_count > 0, , drop = FALSE]
  expected <- mean(kept$.species_count / kept[[design$angler_effort_col]])
  # Pins the estimand, not merely that the number moved.
  expect_equal(sib_rate(res_false, "bass"), expected, tolerance = 1e-8)
  expect_equal(nrow(kept), 12L)
})

test_that("SIBLING-TARGETED-03: release targeted=FALSE drops this species' zeros", {
  design <- make_sibling_targeted_design()
  res_true <- suppressWarnings(suppressMessages(
    estimate_release_rate(design, by = species, estimator = "mor", targeted = TRUE, use_trips = "all")
  ))
  res_false <- suppressWarnings(suppressMessages(
    estimate_release_rate(design, by = species, estimator = "mor", targeted = FALSE, use_trips = "all")
  ))
  expect_gt(sib_rate(res_false, "bass"), sib_rate(res_true, "bass"))
  expect_equal(sib_rate(res_false, "panfish"), sib_rate(res_true, "panfish"))
})

test_that("SIBLING-TARGETED-04: warnings name the species and use the right verb", {
  design <- make_sibling_targeted_design()
  # The message wording is shared with catch through one helper, so the verb is
  # the only thing that distinguishes them; a copy-paste slip would show here.
  expect_warning(
    suppressMessages(
      estimate_harvest_rate(design, by = species, estimator = "mor", targeted = FALSE, use_trips = "all")
    ),
    regexp = "bass.*38 zero-harvest trips excluded \\(76% of trips\\)"
  )
  expect_warning(
    suppressMessages(
      estimate_release_rate(design, by = species, estimator = "mor", targeted = FALSE, use_trips = "all")
    ),
    regexp = "bass.*38 zero-release trips excluded \\(76% of trips\\)"
  )
})

test_that("SIBLING-TARGETED-05: the 70% warning fires per species on the siblings", {
  design <- make_sibling_targeted_design()
  expect_warning(
    suppressMessages(
      estimate_harvest_rate(design, by = species, estimator = "mor", targeted = TRUE, use_trips = "all")
    ),
    regexp = "bass.*76% of trips harvested none of this species"
  )
  # Release too: the verb is the only thing separating the two messages, so
  # testing one does not cover the other.
  expect_warning(
    suppressMessages(
      estimate_release_rate(design, by = species, estimator = "mor", targeted = TRUE, use_trips = "all")
    ),
    regexp = "bass.*76% of trips released none of this species"
  )
})

# ---- refused, not silently ignored ------------------------------------------

test_that("SIBLING-TARGETED-06: targeted=FALSE without by = species is an error", {
  design <- make_sibling_targeted_design()
  # The whole point of #307. Every interview here records SOMETHING, so a
  # "recorded nothing at all" test would have excluded zero rows and returned
  # the untargeted rate silently -- the #304 failure mode, reproduced.
  expect_error(
    suppressMessages(
      estimate_harvest_rate(design, estimator = "mor", targeted = FALSE, use_trips = "all")
    ),
    class = "creel_error_targeted_needs_species"
  )
  expect_error(
    suppressMessages(
      estimate_release_rate(design, estimator = "mor", targeted = FALSE, use_trips = "all")
    ),
    class = "creel_error_targeted_needs_species"
  )
})

test_that("SIBLING-TARGETED-07: the refusal reaches a sectioned design too", {
  design <- make_sibling_targeted_design()
  sections <- data.frame(section = c("north", "south"), stringsAsFactors = FALSE)
  design$interviews$section <- rep(c("north", "south"), length.out = nrow(design$interviews))
  sectioned <- suppressMessages(suppressWarnings(
    add_sections(design, sections, section_col = section)
  ))
  # The section guard returns before the species dispatch, so a check placed
  # after it would never run here. Sectioned paths are where this package's
  # dispatch bugs cluster, so the refusal is pinned on one explicitly.
  expect_error(
    suppressMessages(
      estimate_harvest_rate(sectioned, estimator = "mor", targeted = FALSE, use_trips = "all")
    ),
    class = "creel_error_targeted_needs_species"
  )
})

# ---- scope: what #307 must NOT change ---------------------------------------

test_that("SIBLING-TARGETED-08: the totals still refuse to accept targeted", {
  design <- make_sibling_targeted_design()
  # Deliberate, and documented under "Why there is no `targeted` argument": a
  # targeted rate is conditional on recording the species, total effort is not,
  # and multiplying them applies a conditional rate to an unconditional base.
  expect_error(
    estimate_total_catch(design, by = species, targeted = FALSE),
    regexp = "unused argument"
  )
  expect_error(
    estimate_total_harvest(design, by = species, targeted = FALSE),
    regexp = "unused argument"
  )
  expect_error(
    estimate_total_release(design, by = species, targeted = FALSE),
    regexp = "unused argument"
  )
})

test_that("SIBLING-TARGETED-08b: targeted is appended, not slotted in", {
  # A new argument inserted before an existing one silently rebinds positional
  # calls: `estimate_harvest_rate(d, by, var, conf, verbose, ut, est, trunc,
  # "warn")` would have bound "warn" to `targeted`. Appending keeps every
  # existing position stable, so this pins the order rather than just the name.
  for (fn in list(estimate_harvest_rate, estimate_release_rate)) {
    nms <- names(formals(fn))
    expect_equal(nms[length(nms)], "targeted")
    expect_equal(nms[length(nms) - 1L], "missing_sections")
  }
})

test_that("SIBLING-TARGETED-08c: targeted is validated on all three rate functions", {
  design <- make_sibling_targeted_design()
  # `targeted` reaches `if (!targeted)` unguarded, so NA surfaced as a base
  # "missing value where TRUE/FALSE needed" naming no argument. NA with no
  # species was worse: it fell through to the by = species refusal and reported
  # the wrong reason entirely. Catch is included because the argument and the
  # gap predate this PR, and fixing two of three would just move the asymmetry.
  for (bad in list(NA, "yes", c(TRUE, TRUE), NULL)) {
    expect_error(
      suppressMessages(estimate_harvest_rate(
        design, by = species, estimator = "mor", use_trips = "all", targeted = bad
      )),
      class = "creel_error_invalid_targeted"
    )
    expect_error(
      suppressMessages(estimate_release_rate(
        design, by = species, estimator = "mor", use_trips = "all", targeted = bad
      )),
      class = "creel_error_invalid_targeted"
    )
    expect_error(
      suppressMessages(estimate_catch_rate(
        design, by = species, estimator = "mor", use_trips = "all", targeted = bad
      )),
      class = "creel_error_invalid_targeted"
    )
  }
})

test_that("SIBLING-TARGETED-08d: NA does not masquerade as the species refusal", {
  design <- make_sibling_targeted_design()
  # `!isTRUE(NA)` is TRUE, so before validation an NA with no `by = species`
  # aborted with "targeted = FALSE needs by = species" -- a true statement about
  # a value the caller never passed.
  expect_error(
    suppressMessages(estimate_harvest_rate(
      design, estimator = "mor", use_trips = "all", targeted = NA
    )),
    class = "creel_error_invalid_targeted"
  )
})

test_that("SIBLING-TARGETED-09: default arguments move no sibling estimate", {
  design <- make_sibling_targeted_design()
  # #307 adds a knob and a diagnostic warning; it must not move a number for
  # anyone who never passes `targeted`.
  res <- suppressWarnings(suppressMessages(
    estimate_harvest_rate(design, by = species, estimator = "mor", use_trips = "all")
  ))
  bass <- tidycreel:::make_species_catch_for_interviews(design, "bass", "harvested")
  expected <- mean(bass$.species_count / bass[[design$angler_effort_col]])
  expect_equal(sib_rate(res, "bass"), expected, tolerance = 1e-8)
})

test_that("SIBLING-TARGETED-10: ratio-of-means on the siblings still ignores targeted", {
  design <- make_sibling_targeted_design()
  # Same carve-out as catch: ROM is the default estimator and has never read
  # the argument.
  res_true <- suppressWarnings(suppressMessages(
    estimate_harvest_rate(design, by = species, estimator = "ratio-of-means", targeted = TRUE, use_trips = "all")
  ))
  res_false <- suppressWarnings(suppressMessages(
    estimate_harvest_rate(design, by = species, estimator = "ratio-of-means", targeted = FALSE, use_trips = "all")
  ))
  expect_equal(res_false$estimates$estimate, res_true$estimates$estimate)
})

test_that("SIBLING-TARGETED-11: mortr reaches the sibling filter", {
  design <- make_sibling_targeted_design()
  # The siblings pass `dispatch_estimator` to their species loops, which is
  # still "mortr" -- the opposite convention from estimate_catch_rate(), which
  # normalises first. The filter normalises internally so it cannot depend on
  # which caller reached it. Without that, targeted=FALSE would be a silent
  # no-op under mortr here while working under mor.
  res_mor <- suppressWarnings(suppressMessages(
    estimate_harvest_rate(design, by = species, estimator = "mor", targeted = FALSE, use_trips = "all")
  ))
  res_mortr <- suppressWarnings(suppressMessages(
    estimate_harvest_rate(design, by = species, estimator = "mortr", targeted = FALSE, use_trips = "all")
  ))
  expect_equal(res_mortr$estimates$n, res_mor$estimates$n)
})
