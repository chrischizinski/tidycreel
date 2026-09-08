# GH #282: a sectioned result reports its sections under the column the design
# registered, not a hardcoded "section".
#
# Why these tests need their own fixture: every other sectioned fixture in the
# repo names the column "section", so `design$section_col == "section"` and the
# hardcoded name and the correct name are the same string. A test built on those
# fixtures cannot fail when this regresses. `make_renamed_section_design()`
# exists so the two are distinguishable.

sectioned_result_cols <- function(x) {
  est <- if (is.list(x) && !is.null(x$estimates)) x$estimates else x
  names(est)
}

quiet <- function(expr) suppressMessages(suppressWarnings(expr))

test_that("every sectioned estimator names its column after design$section_col", {
  design <- make_renamed_section_design("reach")
  expect_identical(design$section_col, "reach")

  results <- list(
    effort = quiet(estimate_effort(design)),
    catch_rate = quiet(estimate_catch_rate(design)),
    harvest_rate = quiet(estimate_harvest_rate(design)),
    release_rate = quiet(estimate_release_rate(design)),
    total_catch = quiet(estimate_total_catch(design)),
    total_harvest = quiet(estimate_total_harvest(design)),
    total_release = quiet(estimate_total_release(design))
  )

  for (nm in names(results)) {
    cols <- sectioned_result_cols(results[[nm]])
    expect_true("reach" %in% cols, info = nm)
    expect_false("section" %in% cols, info = nm)
    # The section column leads the result, as it did when hardcoded.
    expect_identical(cols[[1L]], "reach", info = nm)
  }
})

test_that("the renamed column carries the section values, not just the name", {
  # A rename that dropped or reordered the values would still pass a names-only
  # check. Pin the contents too.
  design <- make_renamed_section_design("reach")
  est <- quiet(estimate_catch_rate(design))
  est <- if (is.list(est) && !is.null(est$estimates)) est$estimates else est
  expect_setequal(as.character(est$reach), c("North", "South"))
})

test_that("the lake-wide row uses the renamed column too", {
  # `.lake_total` is a VALUE in the section column, not a column name, so it must
  # survive under the caller's name rather than reappearing under "section".
  design <- make_renamed_section_design("reach")
  est <- quiet(estimate_total_catch(design, aggregate_sections = TRUE))
  est <- if (is.list(est) && !is.null(est$estimates)) est$estimates else est
  expect_true("reach" %in% names(est))
  expect_false("section" %in% names(est))
  expect_true(".lake_total" %in% as.character(est$reach))
})

test_that("the by= refusal names the same column the result reports", {
  # Before #282 the refusal said "reach is already how the result is split"
  # while no output column was named `reach`. The message was already correct;
  # the result was not, and the two disagreed.
  design <- make_renamed_section_design("reach")
  err <- tryCatch(
    quiet(estimate_catch_rate(design, by = reach)),
    creel_error_section_in_by = function(e) e
  )
  expect_s3_class(err, "creel_error_section_in_by")
  expect_match(conditionMessage(err), "reach")

  est <- quiet(estimate_catch_rate(design))
  est <- if (is.list(est) && !is.null(est$estimates)) est$estimates else est
  expect_true("reach" %in% names(est))
})

test_that("a design whose sections are named `section` is unchanged", {
  # The overwhelmingly common case, and every other fixture in the suite. This
  # is what makes the change safe for existing callers: when section_col is
  # "section", the output is byte-identical to before.
  design <- make_renamed_section_design("section")
  expect_identical(design$section_col, "section")
  cols <- sectioned_result_cols(quiet(estimate_catch_rate(design)))
  expect_identical(cols[[1L]], "section")
})
