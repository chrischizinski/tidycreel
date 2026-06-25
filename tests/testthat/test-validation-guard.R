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
  pkg_direct <- normalizePath(system.file(package = "tidycreel"), mustWork = FALSE)
  pkg_root <- if (file.exists(file.path(pkg_direct, "DESCRIPTION"))) {
    pkg_direct
  } else {
    normalizePath(dirname(pkg_direct), mustWork = FALSE)
  }
  if (!file.exists(file.path(pkg_root, "DESCRIPTION"))) {
    skip("Cannot locate package root with DESCRIPTION in this context")
  }
  withr::with_dir(pkg_root, {
    caught <- tryCatch(
      source(script_path, local = TRUE),
      error = function(e) e
    )
    # If an error occurred, its message must NOT mention DESCRIPTION
    # (meaning the guard did not fire — the error came from elsewhere).
    if (inherits(caught, "error")) {
      expect_false(
        grepl("DESCRIPTION", conditionMessage(caught)),
        info = paste(
          "DESCRIPTION guard must not fire from package root;",
          "actual error:",
          conditionMessage(caught)
        )
      )
    } else {
      # Script completed without error — guard trivially passed
      succeed("Script ran to completion from package root without DESCRIPTION guard error")
    }
  })
})
