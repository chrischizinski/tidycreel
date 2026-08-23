# Tests for the working-directory guard in calamus-2016-validation.R.
# The guard fires if the script is sourced from a directory that does not
# contain a DESCRIPTION file, giving an actionable error rather than a
# cryptic downstream crash.

# Resolve the absolute path to the script before any with_dir() changes cwd.
# system.file() works because tidycreel is loaded during devtools::test().
script_path <- system.file(
  "validation",
  "calamus-2016-validation.R",
  package = "tidycreel",
  mustWork = TRUE
)

# The fixtures the script reads live under inst/extdata, which `.Rbuildignore`
# excludes from the build (`^inst/extdata$`). They are therefore present in a
# source checkout and absent from any installed or R CMD check-ed copy, so the
# script is runnable only from a checkout. The two tests below assert that it
# runs -- strictly, with no tolerated errors -- wherever it CAN run, and skip
# with a stated reason where the data it needs was never shipped (GH #130).
validation_pkg_root <- function() {
  direct <- normalizePath(system.file(package = "tidycreel"), mustWork = FALSE)
  root <- if (file.exists(file.path(direct, "DESCRIPTION"))) {
    direct
  } else {
    normalizePath(dirname(direct), mustWork = FALSE)
  }
  if (!file.exists(file.path(root, "DESCRIPTION"))) {
    skip("Cannot locate package root with DESCRIPTION in this context")
  }
  fixtures <- file.path(root, "inst", "extdata", "calamus-2016", "reference-outputs.csv")
  if (!file.exists(fixtures)) {
    skip("calamus-2016 fixtures are .Rbuildignore'd, so the script cannot run from an installed copy")
  }
  root
}

test_that("validation script fails clearly when run from wrong directory", {
  # Source from a temp directory that contains no DESCRIPTION file.
  # The guard should fire immediately with a stop() message containing "DESCRIPTION".
  withr::with_dir(tempdir(), {
    expect_error(
      source(script_path, local = TRUE),
      regexp = "DESCRIPTION"
    )
  })
})

test_that("validation script passes WD guard when run from package root", {
  # Source from the package root where DESCRIPTION exists.
  # The guard must NOT fire — any other error (e.g. from load_all or estimators)
  # is acceptable, but the DESCRIPTION guard stop() must not be reached.
  #
  # Two contexts to handle:
  #   devtools::load_all() — system.file(package = "tidycreel") returns inst/;
  #     the actual package root (containing DESCRIPTION) is one level up.
  #   Installed (rcmdcheck) — system.file(package = "tidycreel") IS the root
  #     and already contains DESCRIPTION.
  pkg_root <- validation_pkg_root()
  withr::with_dir(pkg_root, {
    caught <- tryCatch(
      source(script_path, local = TRUE),
      error = function(e) e
    )
    # The script must RUN, not merely get past the guard.
    #
    # This assertion used to accept any error that was not the DESCRIPTION
    # guard, on the reasoning that an estimator failure was somebody else's
    # problem. The script had been aborting at add_counts() -- three numeric
    # count columns and no `count_col` -- for as long as that abort has
    # existed, and this test stayed green throughout, which is precisely a test
    # that cannot fail when the thing it covers is broken (GH #130).
    expect_false(
      inherits(caught, "error"),
      info = paste(
        "validation script must run to completion from the package root;",
        "actual error:",
        if (inherits(caught, "error")) conditionMessage(caught) else ""
      )
    )
  })
})

test_that("the validation script agrees with the reference outputs it ships", {
  # The script prints PASS/FAIL per comparison and stops on failure. Running it
  # is therefore the assertion -- but only if a failure is actually reachable
  # from here, which is what the test above now guarantees.
  pkg_root <- validation_pkg_root()

  withr::with_dir(pkg_root, {
    # Not suppressMessages(): the script reports through message(), so
    # suppressing them empties `out` and every grepl() below then passes on a
    # zero-length vector. That is what the FAIL check here used to do.
    out <- capture.output(
      suppressWarnings(source(script_path, local = TRUE)),
      type = "message"
    )
    expect_true(length(out) > 0L)
    expect_false(any(grepl("FAIL", out, fixed = TRUE)))

    # Which comparisons ran, not just that none failed. A script that quietly
    # stopped checking standard errors would still print no FAIL -- and that is
    # exactly how the catch_total SE went stale for three major versions
    # (GH #178). Three estimands x {estimate, se}.
    expect_equal(sum(grepl("^  \\[PASS\\]", out)), 6L)
    expect_equal(sum(grepl("^  \\[PASS\\] \\w+ se:", out)), 3L)
  })
})
