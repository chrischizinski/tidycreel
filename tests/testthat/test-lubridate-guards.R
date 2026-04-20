# Tests for DEPS-02: lubridate check_installed guards
# Verifies that lubridate is in Suggests (not Imports) in DESCRIPTION
# and that rlang::check_installed("lubridate") guards are present in source files.

# Helper: resolve path to package root relative to test file location
pkg_root <- function() {
  # test files live at <root>/tests/testthat/
  test_dir <- testthat::test_path(".")
  normalizePath(file.path(test_dir, "..", ".."), mustWork = FALSE)
}

test_that("DEPS-02: lubridate is in Suggests, not Imports, in DESCRIPTION", {
  root <- pkg_root()
  desc_lines <- readLines(file.path(root, "DESCRIPTION"))

  # Collect Imports lines (start line + continuation lines with leading whitespace)
  imports_start <- grep("^Imports:", desc_lines)
  imports_block <- character(0)
  if (length(imports_start) > 0) {
    i <- imports_start
    repeat {
      imports_block <- c(imports_block, desc_lines[i])
      i <- i + 1
      if (i > length(desc_lines)) break
      if (!grepl("^\\s", desc_lines[i])) break
    }
  }

  # lubridate must NOT appear in the Imports block
  expect_false(
    any(grepl("lubridate", imports_block)),
    label = "lubridate must not appear in Imports"
  )

  # Collect Suggests lines
  suggests_start <- grep("^Suggests:", desc_lines)
  suggests_block <- character(0)
  if (length(suggests_start) > 0) {
    i <- suggests_start
    repeat {
      suggests_block <- c(suggests_block, desc_lines[i])
      i <- i + 1
      if (i > length(desc_lines)) break
      if (!grepl("^\\s", desc_lines[i])) break
    }
  }

  # lubridate MUST appear in the Suggests block
  expect_true(
    any(grepl("lubridate", suggests_block)),
    label = "lubridate must appear in Suggests"
  )
})

test_that("DEPS-02: check_installed guard for lubridate exists in schedule-generators.R", {
  root <- pkg_root()
  lines <- readLines(file.path(root, "R", "schedule-generators.R"))
  matches <- grep("check_installed.*lubridate", lines, value = TRUE)
  expect_gte(length(matches), 1L)
})

test_that("DEPS-02: check_installed guards for lubridate exist in schedule-print.R (2 guards)", {
  root <- pkg_root()
  lines <- readLines(file.path(root, "R", "schedule-print.R"))
  matches <- grep("check_installed.*lubridate", lines, value = TRUE)
  expect_gte(length(matches), 2L)
})

test_that("DEPS-02: check_installed guard for lubridate exists in autoplot-methods.R", {
  root <- pkg_root()
  lines <- readLines(file.path(root, "R", "autoplot-methods.R"))
  matches <- grep("check_installed.*lubridate", lines, value = TRUE)
  expect_gte(length(matches), 1L)
})
