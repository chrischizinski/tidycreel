# The bins' covariance reaches the ratio consumers (GH #311) ----
#
# `svytotal()` over the bin columns estimates a full covariance matrix, and
# `two_phase_rescale()` propagates it. Every consumer then rebuilt a variance
# from the DIAGONAL alone -- the quadratic form w' Sigma w with every
# off-diagonal set to zero. The bins are a partition of the same fish, rescaled
# onto a single reported total, so they are strongly dependent.
#
# The point estimate propagated correctly the whole time, which is why nothing
# looked wrong: only the uncertainty was affected.
#
# These tests pin the answer against `survey` references built independently in
# base R, sharing no tidycreel helper with the code under test. An agreement
# test against the package's own arithmetic could not have caught this -- that
# is precisely what the previous SE tests were, and they passed throughout.

ld_for_covariance <- function() {
  data(example_calendar, package = "tidycreel")
  data(example_interviews, package = "tidycreel")
  data(example_lengths, package = "tidycreel")

  d <- suppressWarnings(suppressMessages(
    add_lengths(
      add_interviews(
        creel_design(example_calendar, date = date, strata = day_type), # nolint: object_usage_linter
        example_interviews,
        catch = catch_total, # nolint: object_usage_linter
        effort = hours_fished, # nolint: object_usage_linter
        harvest = catch_kept, # nolint: object_usage_linter
        trip_status = trip_status # nolint: object_usage_linter
      ),
      example_lengths,
      length_uid = interview_id, # nolint: object_usage_linter
      interview_uid = interview_id, # nolint: object_usage_linter
      species = species, # nolint: object_usage_linter
      length = length, # nolint: object_usage_linter
      length_type = length_type, # nolint: object_usage_linter
      count = count, # nolint: object_usage_linter
      release_format = "binned"
    )
  ))
  suppressWarnings(suppressMessages(
    est_length_distribution(d, type = "harvest", bin_width = 25)
  ))
}

# Bins rebuilt from the raw length table in base R, then one `svydesign()`.
# Deliberately does not call add_lengths(), est_length_distribution(), or any
# tidycreel helper, so a shared bug cannot make the two sides agree.
reference_interviews <- function(min_length = NULL, bin_width = 25) {
  data(example_calendar, package = "tidycreel")
  data(example_interviews, package = "tidycreel")
  data(example_lengths, package = "tidycreel")

  raw <- example_lengths[example_lengths$length_type == "harvest", , drop = FALSE]
  lenv <- as.numeric(raw$length)
  cnt <- raw$count
  cnt[is.na(cnt)] <- 1L
  ok <- !is.na(lenv)
  raw <- raw[ok, , drop = FALSE]
  lenv <- lenv[ok]
  cnt <- cnt[ok]

  # The same bin the package assigns: cut(breaks = seq(0, ..., bin_width)).
  bin_lower <- floor(lenv / bin_width) * bin_width
  bin_mid <- bin_lower + bin_width / 2

  iv <- example_interviews
  # The stratum, joined from the calendar in base R. add_interviews() does this
  # too, but the point of this reference is to share no code with it.
  iv$day_type <- example_calendar$day_type[match(iv$date, example_calendar$date)]
  put <- function(x) {
    agg <- tapply(x, raw$interview_id, sum)
    out <- as.numeric(agg[as.character(iv$interview_id)])
    out[is.na(out)] <- 0
    out
  }
  iv$alltot <- put(cnt)
  iv$lensum <- put(bin_mid * cnt)
  if (!is.null(min_length)) {
    # A bin is legal when its LOWER edge clears the limit, which is the rule
    # est_compliance() documents.
    iv$legal <- put(as.numeric(bin_lower >= min_length) * cnt)
  }
  iv
}

test_that("BINCOV-01 (#311): est_compliance() matches an independent svyratio() SE", {
  skip_if_not_installed("survey")
  min_length <- 356

  iv <- reference_interviews(min_length = min_length)
  svy <- suppressWarnings(survey::svydesign(ids = ~1, strata = ~day_type, data = iv))
  ref <- survey::svyratio(~legal, ~alltot, svy)

  pkg <- suppressWarnings(suppressMessages(
    est_compliance(ld_for_covariance(), min_length = min_length)
  ))

  # The proportion is invariant to the two-phase rescale -- every bin is
  # multiplied by the same factor, which cancels in a ratio of bins -- so the
  # measured-basis reference is the right comparison for both the estimate and
  # its standard error.
  expect_equal(pkg$compliance_prop, as.numeric(coef(ref)), tolerance = 1e-8)

  # This is the assertion the defect fails. The package reported 0.1422436
  # against the reference's 0.2093703 -- 32% too small, on a proportion that is
  # compared against a legal size limit.
  expect_equal(pkg$compliance_se, as.numeric(survey::SE(ref)), tolerance = 1e-8)
})

test_that("BINCOV-02 (#311): est_mean_length() matches an independent svyratio() SE", {
  skip_if_not_installed("survey")

  iv <- reference_interviews()
  svy <- suppressWarnings(survey::svydesign(ids = ~1, strata = ~day_type, data = iv))
  ref <- survey::svyratio(~lensum, ~alltot, svy)

  pkg <- suppressWarnings(suppressMessages(
    est_mean_length(ld_for_covariance())
  ))

  # Same scale-invariance argument as BINCOV-01: mean length is a ratio of bin
  # totals, so the rescale factor cancels.
  expect_equal(pkg$mean_length, as.numeric(coef(ref)), tolerance = 1e-8)
  expect_equal(pkg$mean_length_se, as.numeric(survey::SE(ref)), tolerance = 1e-8)
})

test_that("BINCOV-03 (#311): the off-diagonal terms actually move the answer", {
  # The mutation. Zeroing the off-diagonals reproduces the independence form
  # exactly, so if the two agreed, BINCOV-01 and BINCOV-02 would pass against
  # the very defect they exist to catch.
  ld <- ld_for_covariance()
  sigma <- attr(ld, "bin_vcov")[[".all"]]
  expect_false(is.null(sigma))

  rows <- ld
  p <- sum(rows$estimate[rows$bin_lower >= 356]) / sum(rows$estimate)
  w <- as.numeric(rows$bin_lower >= 356) - p

  with_cov <- sqrt(as.numeric(t(w) %*% sigma %*% w)) / sum(rows$estimate)
  diag_only <- sqrt(as.numeric(t(w) %*% diag(diag(sigma)) %*% w)) / sum(rows$estimate)

  # The diagonal-only form is what the package used to report.
  expect_equal(diag_only, sqrt(sum(w^2 * rows$se^2)) / sum(rows$estimate), tolerance = 1e-10)
  # And it is materially different -- not a rounding detail.
  expect_false(isTRUE(all.equal(with_cov, diag_only, tolerance = 1e-6)))
  expect_gt(with_cov / diag_only, 1.3)
})

test_that("BINCOV-04 (#311): sqrt(diag(vcov)) is exactly the reported per-bin se", {
  # The carrier and the reported column are one quantity, not two that could
  # drift apart. GH #134 was an object whose se provably contained a component
  # its own se_expansion said had never been propagated.
  ld <- ld_for_covariance()
  sigma <- attr(ld, "bin_vcov")[[".all"]]
  expect_equal(sqrt(diag(sigma)), ld$se, ignore_attr = TRUE, tolerance = 1e-12)
  expect_equal(rownames(sigma), as.character(ld$length_bin))
})

test_that("BINCOV-05b (#311): a row subset still gets the right covariance block", {
  # The matrix is keyed by bin label, so a caller who keeps only some rows gets
  # those rows' block rather than a misaligned one or a warning. Indexing it by
  # position would have paired each remaining bin with another bin's variance.
  ld <- ld_for_covariance()
  keep <- ld[ld$bin_lower >= 300, , drop = FALSE]
  expect_gt(nrow(keep), 1L)
  expect_false(is.null(attr(keep, "bin_vcov")))

  res <- expect_no_warning(est_mean_length(keep))

  sigma <- attr(ld, "bin_vcov")[[".all"]]
  labs <- as.character(keep$length_bin)
  block <- sigma[labs, labs]
  l_mid <- (keep$bin_lower + keep$bin_upper) / 2
  n_total <- sum(keep$estimate)
  mean_l <- sum(l_mid * keep$estimate) / n_total
  w <- l_mid - mean_l
  expect_equal(
    res$mean_length_se,
    sqrt(as.numeric(t(w) %*% block %*% w)) / n_total,
    tolerance = 1e-10
  )
})

test_that("BINCOV-05 (#311): a missing covariance warns rather than assuming independence", {
  # An absent covariance is UNKNOWN, not zero. Silently falling back to the
  # independence form would restore the defect this issue is about by the back
  # door, so the fallback says so out loud.
  #
  # Which operations actually drop the carrier was MEASURED rather than assumed
  # from GH #124: row subsetting (`ld[i, ]`), `dplyr::filter()`, `rbind()` and
  # `as_tibble()` all KEEP it in this R version -- and a surviving matrix still
  # aligns, because bin_vcov_for() indexes it by bin label rather than by
  # position. What drops it is selecting COLUMNS, and `subset()`.
  ld <- ld_for_covariance()
  stripped <- ld[, names(ld)]
  expect_null(attr(stripped, "bin_vcov"))

  expect_warning(
    est_compliance(stripped, min_length = 356),
    class = "creel_warning_bin_vcov_unavailable"
  )

  # It still returns the independence approximation rather than failing, and
  # that value is the one the unsubsetted object would have reported had the
  # covariance been diagonal.
  res <- suppressWarnings(est_compliance(stripped, min_length = 356))
  rows <- ld
  p <- sum(rows$estimate[rows$bin_lower >= 356]) / sum(rows$estimate)
  w <- as.numeric(rows$bin_lower >= 356) - p
  expect_equal(
    res$compliance_se,
    sqrt(sum(w^2 * rows$se^2)) / sum(rows$estimate),
    tolerance = 1e-10
  )
})
