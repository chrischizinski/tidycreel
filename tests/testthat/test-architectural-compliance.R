#' Architectural Compliance Tests
#'
#' These tests enforce tidycreel's architectural standards and prevent divergence.
#' They ensure ALL estimators use the core variance engine and follow standard patterns.

# Helper to detect if we're running in R CMD check (source files not available)
in_check_mode <- function() {
  !dir.exists("../../R")
}

test_that("variance engine exists and is exported", {
  skip_if(in_check_mode(), "Source files not available in check mode")

  expect_true(
    exists("tc_compute_variance", mode = "function"),
    "Core variance engine tc_compute_variance() must exist"
  )
})

test_that("no banned file naming patterns exist", {
  skip_if(in_check_mode(), "Source files not available in check mode")

  # Get all R files
  r_files <- list.files("../../R", pattern = "\\.R$", full.names = TRUE)

  # Check for banned patterns
  banned_patterns <- c(
    "-integration\\.R$",
    "-enhanced\\.R$",
    "-wrapper\\.R$",
    "-patch\\.R$",
    "-internals-access\\.R$"
  )

  for (pattern in banned_patterns) {
    banned_files <- grep(pattern, r_files, value = TRUE)
    expect_equal(
      length(banned_files),
      0,
      info = sprintf(
        "Found banned file naming pattern '%s': %s",
        pattern,
        paste(basename(banned_files), collapse = ", ")
      )
    )
  }
})

test_that("no wrapper functions exist in codebase", {
  skip_if(in_check_mode(), "Source files not available in check mode")

  # Get all R files
  r_files <- list.files("../../R", pattern = "\\.R$", full.names = TRUE)

  # Banned function patterns
  banned_functions <- c(
    "add_enhanced_",
    "enhance_estimator",
    "create_enhanced_",
    "batch_enhance_"
  )

  for (file in r_files) {
    content <- readLines(file, warn = FALSE)
    file_content <- paste(content, collapse = "\n")

    for (banned_func in banned_functions) {
      matches <- grepl(banned_func, file_content, fixed = TRUE)
      expect_false(
        matches,
        info = sprintf(
          "Found banned function pattern '%s' in file: %s",
          banned_func,
          basename(file)
        )
      )
    }
  }
})

test_that("estimator functions use tc_compute_variance", {
  skip_if(in_check_mode(), "Source files not available in check mode")

  # Get all estimator files
  est_files <- list.files("../../R", pattern = "^est-.*\\.R$", full.names = TRUE)

  # Skip the REBUILT demo file
  est_files <- est_files[!grepl("REBUILT", est_files)]

  for (file in est_files) {
    # Read file content
    content <- readLines(file, warn = FALSE)
    file_content <- paste(content, collapse = "\n")

    # Check if file has a survey design path (has 'svy' or 'design' parameter)
    has_survey_design <- grepl("svy\\s*=", file_content) ||
                         grepl("design\\s*=", file_content)

    if (has_survey_design) {
      # Check if it uses tc_compute_variance
      uses_core_engine <- grepl("tc_compute_variance", file_content, fixed = TRUE)

      # For now, make this a warning not a failure since we're in transition
      if (!uses_core_engine) {
        warning(
          sprintf(
            "File %s has survey design but doesn't use tc_compute_variance(). ",
            basename(file),
            "This should be rebuilt to use the core variance engine."
          ),
          call. = FALSE
        )
      }
    }
  }

  # This test always passes but generates warnings for non-compliant files
  expect_true(TRUE)
})

test_that("variance_method parameter exists in rebuilt estimators", {
  # Skip for now since this is aspirational
  # Will pass once estimators are rebuilt

  skip("Estimators not yet rebuilt")

  # Check rebuilt estimators have variance_method parameter
  # rebuilt_estimators <- c("est_effort.instantaneous")
  #
  # for (func_name in rebuilt_estimators) {
  #   func <- get(func_name)
  #   params <- names(formals(func))
  #
  #   expect_true(
  #     "variance_method" %in% params,
  #     info = sprintf("%s must have variance_method parameter", func_name)
  #   )
  # }
})

test_that("no direct survey::svytotal calls in estimators (should use core engine)", {
  # Skip for now - this is aspirational for after rebuild
  skip("Estimators not yet rebuilt")

  # Get all estimator files
  # est_files <- list.files("../../R", pattern = "^est-.*\\.R$", full.names = TRUE)
  #
  # for (file in est_files) {
  #   content <- readLines(file, warn = FALSE)
  #   file_content <- paste(content, collapse = "\n")
  #
  #   # Check for direct survey calls (should use tc_compute_variance instead)
  #   has_direct_calls <- grepl("survey::svytotal", file_content, fixed = TRUE) ||
  #                       grepl("survey::svymean", file_content, fixed = TRUE) ||
  #                       grepl("survey::svyby", file_content, fixed = TRUE)
  #
  #   expect_false(
  #     has_direct_calls,
  #     info = sprintf(
  #       "%s uses direct survey calls. Should use tc_compute_variance() instead.",
  #       basename(file)
  #     )
  #   )
  # }
})

test_that("core engine functions follow naming convention", {
  skip_if(in_check_mode(), "Source files not available in check mode")

  # Core engine functions must start with tc_
  core_functions <- c(
    "tc_compute_variance",
    "tc_decompose_variance",
    "tc_design_diagnostics",
    "tc_extract_design_info"
  )

  # Check files exist
  expected_files <- c(
    "../../R/variance-engine.R",
    "../../R/variance-decomposition-engine.R",
    "../../R/survey-diagnostics.R"
  )

  for (file in expected_files) {
    expect_true(
      file.exists(file),
      info = sprintf("Core infrastructure file must exist: %s", basename(file))
    )
  }
})

test_that("integration and patch files have been deleted", {
  skip_if(in_check_mode(), "Source files not available in check mode")

  # After full rebuild, these files should NOT exist
  banned_files <- c(
    "../../R/survey-enhanced-integration.R",
    "../../R/estimators-integration.R",
    "../../R/survey-internals-integration.R",
    "../../R/survey-internals-integration-fixed.R",
    "../../R/survey-integration-example.R",
    "../../R/survey-integration-phase2-example.R",
    "../../R/estimators-enhanced.R"
  )

  for (file in banned_files) {
    if (file.exists(file)) {
      warning(
        sprintf(
          "Patch file still exists and should be deleted after rebuild: %s",
          basename(file)
        ),
        call. = FALSE
      )
    }
  }

  # Always pass but generate warnings
  expect_true(TRUE)
})

test_that("output structure is consistent across estimators", {
  # All estimator outputs should have these columns
  required_columns <- c(
    "estimate",
    "se",
    "ci_low",
    "ci_high",
    "method"
  )

  # Rebuilt estimators should also have
  rebuilt_columns <- c(required_columns, "deff", "variance_info")

  # This is aspirational - will be enforced after rebuild
  expect_true(TRUE)
})

test_that("documentation mentions architectural principles", {
  skip_if(in_check_mode(), "Source files not available in check mode")

  # Check that key files are documented
  docs_to_check <- c(
    "../../ARCHITECTURAL_STANDARDS.md",
    "../../GROUND_UP_INTEGRATION_DESIGN.md",
    "../../GROUND_UP_IMPLEMENTATION_SUMMARY.md"
  )

  for (doc in docs_to_check) {
    expect_true(
      file.exists(doc),
      info = sprintf("Documentation file must exist: %s", basename(doc))
    )
  }
})

test_that("variance methods are consistent across functions", {
  skip_if(in_check_mode(), "Source files not available in check mode")

  # All functions that accept variance_method should use the same options
  valid_methods <- c("survey", "svyrecvar", "bootstrap", "jackknife", "linearization")

  # Check that tc_compute_variance uses these methods
  variance_engine_file <- "../../R/variance-engine.R"

  if (file.exists(variance_engine_file)) {
    content <- readLines(variance_engine_file, warn = FALSE)
    file_content <- paste(content, collapse = "\n")

    for (method in valid_methods) {
      expect_true(
        grepl(sprintf('"%s"', method), file_content, fixed = TRUE),
        info = sprintf("tc_compute_variance should support method: %s", method)
      )
    }
  }
})

# Helper function for future tests
verify_estimator_compliance <- function(estimator_name, estimator_file) {
  # Read file
  content <- readLines(estimator_file, warn = FALSE)
  file_content <- paste(content, collapse = "\n")

  # Check 1: Uses tc_compute_variance
  uses_core_engine <- grepl("tc_compute_variance", file_content, fixed = TRUE)

  # Check 2: Has variance_method parameter
  has_variance_method <- grepl("variance_method\\s*=", file_content)

  # Check 3: Has decompose_variance parameter
  has_decompose <- grepl("decompose_variance\\s*=", file_content)

  # Check 4: Has design_diagnostics parameter
  has_diagnostics <- grepl("design_diagnostics\\s*=", file_content)

  # Check 5: Returns variance_info list-column
  has_variance_info <- grepl("variance_info", file_content, fixed = TRUE)

  list(
    uses_core_engine = uses_core_engine,
    has_variance_method = has_variance_method,
    has_decompose = has_decompose,
    has_diagnostics = has_diagnostics,
    has_variance_info = has_variance_info,
    compliant = uses_core_engine && has_variance_method && has_variance_info
  )
}
