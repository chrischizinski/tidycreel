# Testing Patterns

**Analysis Date:** 2026-01-27

## Test Framework

**Runner:**
- testthat v3.0.0+ (configured in DESCRIPTION)
- Edition 3 mode enabled: `Config/testthat/edition: 3`

**Assertion Library:**
- testthat built-in expectations (no separate assertion library)

**Run Commands:**
```bash
# Run all tests
devtools::test()              # or testthat::test_dir("tests/testthat")

# Watch mode (interactive development)
# Not directly supported; use R session with devtools::load_all() + test()

# Coverage report
covr::report()                # HTML coverage report
covr::package_coverage()      # Console output
```

**Coverage Configuration:**
- Configured in `codecov.yml`
- Ignores: `R/globals.R`, `R/data.R`, `data-raw/*`, `tests/testthat.R`
- Target: 1% threshold (informational, not enforced)

## Test File Organization

**Location:**
- Co-located in `tests/testthat/` directory (not beside source files)
- 24 test files total (as of current state)

**Naming:**
- Pattern: `test-{feature}.R`
- Examples: `test-est-cpue-roving.R`, `test-utils-validate.R`, `test-variance-decomposition.R`
- Helper files: `helper-{purpose}.R`, e.g., `helper-testdata.R`

**Structure:**
```
tests/
├── testthat/
│   ├── helper-testdata.R
│   ├── test-est-cpue-roving.R
│   ├── test-utils-validate.R
│   ├── test-variance-decomposition.R
│   ├── test-critical-bugfixes.R
│   ├── test-qa-check-*.R
│   └── ... (24 test files total)
└── testthat.R (R package test runner)
```

## Test Structure

**Suite Organization:**

Tests are organized with section comments in logical groups:

```r
# Tests for est_cpue_roving()
# Roving/incomplete trip CPUE estimation with Pollock et al. (1997) methods

# ==============================================================================
# TEST SUITE 1: INPUT VALIDATION
# ==============================================================================

test_that("est_cpue_roving requires response column", { ... })
test_that("est_cpue_roving requires effort column", { ... })

# ==============================================================================
# TEST SUITE 2: PARAMETER VALIDATION
# ==============================================================================

test_that("est_cpue_roving validates min_trip_hours", { ... })
test_that("est_cpue_roving validates conf_level", { ... })
```

**Patterns:**

**Setup/Teardown:**
- No formal setup/teardown functions; uses inline test data creation
- Helper functions in `helper-testdata.R` for shared test data:
  ```r
  create_test_interviews <- function() {
    tibble::tibble(
      interview_id = paste0("INT", sprintf("%03d", 1:20)),
      date = rep(as.Date("2024-01-01") + 0:3, each = 5),
      # ...
    )
  }
  ```

**Test Data Pattern:**
```r
test_that("function does something", {
  # Arrange: Create minimal test data
  data <- tibble::tibble(
    id = 1:10,
    value = rnorm(10)
  )

  # Act: Call function
  result <- my_function(data)

  # Assert: Check results
  expect_equal(nrow(result), 10)
})
```

**Assertion pattern:**
- Direct assertion calls: `expect_error()`, `expect_equal()`, `expect_true()`
- Object class checks: `expect_s3_class(result, "data.frame")`
- Invisible returns: `expect_invisible(tc_require_cols(df, cols))`

## Mocking

**Framework:**
- No explicit mocking library used (testthat has builtin mocking)
- Uses `tryCatch()` for testing error recovery

**Patterns:**

**Error/Warning Testing:**
```r
test_that("function throws error for invalid input", {
  expect_error(
    my_function(bad_input),
    "error message regex"
  )
})

test_that("function warns on issue", {
  expect_warning(
    my_function(issue_input),
    "warning text"
  )
})
```

**Conditional Execution:**
```r
test_that("feature works if available", {
  skip_on_cran()      # Skip on CRAN, run locally
  skip_if_not(condition, "reason")

  result <- my_function()
  expect_true(condition)
})
```

**Complex scenarios:**
```r
test_that("fallback logic works", {
  # Test with tryCatch to handle expected failures
  result <- tryCatch(
    est_cpue(design, variance_method = "bootstrap"),
    error = function(e) NULL
  )

  if (!is.null(result)) {
    expect_equal(result$variance_info[[1]]$method, "survey")
  }
})
```

**What to Mock:**
- External survey package calls: tested via integration with actual `survey::svydesign` objects
- Non-deterministic random functions: use `set.seed()` in setup
- Data generation: use deterministic test data helpers

**What NOT to Mock:**
- Core survey functionality (test with real survey objects)
- Data validation logic (test with edge cases)
- Statistical calculations (test with known values)

## Fixtures and Factories

**Test Data:**

Centralized in `tests/testthat/helper-testdata.R`:

```r
create_test_interviews <- function() {
  tibble::tibble(
    interview_id = paste0("INT", sprintf("%03d", 1:20)),
    date = rep(as.Date("2024-01-01") + 0:3, each = 5),
    shift_block = rep(c("morning", "afternoon", "evening", "morning"), each = 5, length.out = 20),
    catch_total = sample(0:10, 20, replace = TRUE),
    hours_fished = runif(20, 1, 8),
    target_species = rep(c("walleye", "bass", "perch"), length.out = 20),
    # ...
  )
}

create_test_counts <- function() {
  tibble::tibble(
    count_id = paste0("CNT", sprintf("%03d", 1:16)),
    date = rep(as.Date("2024-01-01") + 0:3, each = 4),
    anglers_count = sample(5:25, 16, replace = TRUE),
    # ...
  )
}

create_test_calendar <- function() {
  # Returns structured calendar data for design specification
}
```

**Location:**
- `tests/testthat/helper-testdata.R` - centralized test data factories

**Usage:**
All test files source helpers automatically; call factory functions directly:
```r
test_interviews <- create_test_interviews()
design <- survey::svydesign(ids = ~1, data = test_interviews)
```

## Coverage

**Requirements:**
- Target: 1% (informational, not enforced as hard limit)
- High-priority functions: aim for 80%+ (core estimators, validation)
- Excludes: data documentation (`R/data.R`), internal globals, data-raw

**View Coverage:**
```r
# Generate HTML report
covr::report()

# Console output
covr::package_coverage()

# File-level coverage
covr::file_coverage(file = "R/est-cpue.R")
```

**Ignored in Coverage:**
- `R/globals.R` - package metadata
- `R/data.R` - dataset documentation only
- `data-raw/*` - data generation scripts
- `tests/testthat.R` - test runner bootstrap
- `renv/` - dependency management

## Test Types

**Unit Tests:**
- Scope: Individual functions or small units
- Examples: `test-utils-validate.R`, `test-utils-time.R`
- Approach: Isolated test data, verify single behavior per test
- File size: 17-65 lines typically

**Integration Tests:**
- Scope: Multiple functions working together (e.g., survey design → estimation)
- Examples: `test-est-cpue-roving.R`, `test-est-total-harvest.R`, `test-critical-bugfixes.R`
- Approach: Create survey designs, call estimators, verify results align across functions
- File size: 100-700+ lines
- Structure includes multiple test suites with section headers

**E2E Tests:**
- Framework: Not used (no end-to-end user workflow tests)
- Could be added for vignette scenarios or complete analysis pipelines

## Common Patterns

**Async Testing (N/A for R):**
- Not applicable (R is single-threaded in main execution)
- Future/parallel testing via future/furrr packages tested separately

**Error Testing:**

Standard pattern with regex matching:
```r
test_that("function validates input", {
  data <- tibble::tibble(catch_total = 1:10)  # Missing 'hours_fished'
  svy <- survey::svydesign(ids = ~1, data = data)

  expect_error(
    est_cpue_roving(svy, effort_col = "hours_fished"),
    "hours_fished"  # Regex match on error message
  )
})
```

**Class/Type Testing:**

```r
test_that("function returns correct class", {
  result <- decompose_variance(design, response = "var")

  expect_s3_class(result, "variance_decomp")
  expect_true("components" %in% names(result))
  expect_s3_class(result$components, "data.frame")
})
```

**Invisible Return Testing:**

```r
test_that("validation function returns invisibly", {
  df <- data.frame(a = 1, b = 2)
  expect_invisible(tc_require_cols(df, c("a", "b")))
})
```

**Conditional Skipping:**

```r
test_that("complex calculation works", {
  skip_on_cran()  # Skip resource-intensive tests on CI

  result <- est_cpue(design, variance_method = "bootstrap", n_replicates = 1000)
  expect_true(is.numeric(result$estimate))
})
```

---

*Testing analysis: 2026-01-27*
