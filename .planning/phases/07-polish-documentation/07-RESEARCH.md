# Phase 7: Polish & Documentation - Research

**Researched:** 2026-02-09
**Domain:** R package documentation, testing, and quality assurance
**Confidence:** HIGH

## Summary

Phase 7 finalizes tidycreel for v0.1.0 release by completing all documentation requirements (roxygen2, vignettes, example datasets), ensuring quality gates pass (test coverage, lintr, R CMD check), and producing a CRAN-ready package. The R ecosystem has well-established standards for package polish: roxygen2 documentation with @param/@returns/@examples tags, long-form vignettes using rmarkdown and the html_vignette output format, example datasets documented with @format/@source tags and stored in data/, test coverage measured with covr (targeting 85% overall, 95% for core functions), code quality enforced with lintr, and final validation via R CMD check --as-cran.

The package is largely ready but has specific gaps: documentation exists for most exported functions (creel_design, estimate_effort, add_counts) but needs roxygen2 regeneration to fix Rd file formatting errors; no vignettes exist yet despite VignetteBuilder: knitr in DESCRIPTION; no example datasets exist in data/ directory; covr package is not installed so coverage cannot be measured; lintr configuration exists and is clean (.lintr uses tidyverse defaults with 120-char lines); and R CMD check currently fails with 2 WARNINGs and 2 NOTEs due to malformed estimate_effort.Rd file.

The documentation workflow follows a clear pattern: write roxygen2 comments in R/ files, run devtools::document() to generate man/*.Rd files, create vignettes in vignettes/ directory using usethis::use_vignette(), create example datasets with scripts in data-raw/ and export with usethis::use_data(), run covr::package_coverage() to measure test coverage and identify gaps, run lintr::lint_package() to check code quality, and finally run devtools::check(args = "--as-cran") to validate the complete package. All quality gates must pass before release: no errors/warnings from R CMD check (NOTEs acceptable only for new submission, non-ASCII data with declared encoding, or justified cross-references), all vignettes render without errors, and test coverage meets 85% overall with 95% for core estimation functions (estimate_effort and internal helpers).

**Primary recommendation:** Execute Phase 7 in three waves: (1) Documentation - regenerate roxygen2 docs with devtools::document(), create "Getting Started" vignette demonstrating design → counts → estimation workflow, create and document example datasets (calendar and counts) in data/; (2) Quality Assurance - install covr and measure coverage, write additional tests to reach 85%/95% targets, verify lintr passes on all code; (3) Release Validation - run R CMD check --as-cran, fix all errors/warnings, address actionable NOTEs, verify vignettes render correctly. This sequence ensures documentation completeness before quality measurement, and quality gates pass before final validation.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| roxygen2 | 7.3.2+ | Generate .Rd documentation from inline comments | Universal R package documentation standard; already in use (RoxygenNote: 7.3.2 in DESCRIPTION) |
| knitr | 1.45+ | Vignette engine for R Markdown | Standard vignette builder; already declared in DESCRIPTION (VignetteBuilder: knitr) |
| rmarkdown | 2.25+ | R Markdown processor for vignettes | Required dependency for knitr vignettes; already in Suggests |
| covr | 3.6+ | Test coverage measurement | CRAN standard for coverage tracking; already in Suggests but not installed |
| lintr | 3.3+ | Static code analysis | Already configured and in Suggests; enforces tidyverse style guide |
| devtools | 2.4+ | Package development workflow | Meta-package providing document(), check(), test(), build_vignettes() |
| usethis | 3.0+ | Package development helpers | Provides use_vignette(), use_data(), use_data_raw() workflow functions |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| testthat | 3.0+ | Testing framework | Already in use; needed for coverage measurement |
| rcmdcheck | 1.4+ | Programmatic R CMD check | Optional - devtools::check() wraps this; useful for CI/CD |
| pkgdown | 2.0+ | Package website generation | Future enhancement (post-v0.1.0); not required for CRAN |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| roxygen2 | Manual .Rd editing | Manual Rd is error-prone and hard to maintain; roxygen2 is universal standard |
| rmarkdown::html_vignette | Other output formats | html_vignette designed specifically for packages; small file size (~10KB vs ~600KB) for CRAN |
| covr | Manual coverage tracking | covr provides line-level coverage data and integrations (Codecov, Coveralls) |
| Single vignette | Multiple vignettes | Simple packages benefit from single "Getting Started" vignette; complex packages need multiple |

**Installation:**
```r
# covr is only missing dependency
install.packages("covr")

# All other packages already in DESCRIPTION Suggests or are installed
```

## Architecture Patterns

### Pattern 1: Roxygen2 Documentation Structure

**What:** Standard roxygen2 block with required tags for exported functions

**When to use:** Every exported function must have complete roxygen2 documentation

**Example:**
```r
# Source: https://r-pkgs.org/man.html
#' Estimate total effort from a creel survey design
#'
#' Computes total effort estimates with standard errors and confidence intervals
#' from a creel survey design with attached count data. Supports grouped
#' estimation and multiple variance methods.
#'
#' @param design A creel_design object with counts attached via [add_counts()].
#'   The design must have a survey object constructed.
#' @param by Optional tidy selector for grouping variables. Accepts bare column
#'   names (e.g., `by = day_type`), multiple columns, or tidyselect helpers.
#'   Default is `NULL` (ungrouped estimation).
#' @param variance Character string specifying variance estimation method.
#'   Options: `"taylor"` (default), `"bootstrap"`, or `"jackknife"`.
#' @param conf_level Numeric confidence level for intervals (default: 0.95).
#'   Must be between 0 and 1.
#'
#' @returns A [creel_estimates] object containing:
#'   \describe{
#'     \item{estimates}{Tibble with estimate, se, ci_lower, ci_upper, n}
#'     \item{method}{Character: "total"}
#'     \item{variance_method}{Character: variance method used}
#'     \item{design}{Reference to source creel_design}
#'     \item{conf_level}{Numeric: confidence level}
#'     \item{by_vars}{Character vector of grouping variables or NULL}
#'   }
#'
#' @examples
#' # Basic ungrouped estimation
#' calendar <- data.frame(
#'   date = as.Date(c("2024-06-01", "2024-06-02")),
#'   day_type = c("weekday", "weekend")
#' )
#' design <- creel_design(calendar, date = date, strata = day_type)
#'
#' counts <- data.frame(
#'   date = as.Date(c("2024-06-01", "2024-06-02")),
#'   day_type = c("weekday", "weekend"),
#'   effort_hours = c(15, 45)
#' )
#'
#' design <- add_counts(design, counts)
#' result <- estimate_effort(design)
#' print(result)
#'
#' @export
estimate_effort <- function(design, by = NULL, variance = "taylor", conf_level = 0.95) {
  # ... implementation
}
```

**Key elements:**
- **Title**: First sentence, sentence case, no period
- **Description**: Second paragraph explaining what function does
- **@param**: Each parameter with type, allowed values, default
- **@returns**: Structured description using `\describe{}` for complex objects
- **@examples**: Self-contained, executable code under 10 seconds
- **@export**: For user-facing functions only

### Pattern 2: Getting Started Vignette Structure

**What:** Standard vignette demonstrating complete package workflow

**When to use:** Every package should have a primary vignette showing typical usage

**Example:**
```rmd
---
title: "Getting Started with tidycreel"
output: rmarkdown::html_vignette
vignette: >
  %\VignetteIndexEntry{Getting Started with tidycreel}
  %\VignetteEngine{knitr::rmarkdown}
  %\VignetteEncoding{UTF-8}
---

```{r setup, include = FALSE}
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>",
  fig.width = 7,
  fig.height = 5
)
```

```{r load}
library(tidycreel)
```

## Introduction

tidycreel provides a tidy interface for creel survey analysis. This vignette
demonstrates the complete workflow: creating a survey design, adding count data,
and estimating effort with standard errors and confidence intervals.

## Create a Survey Design

Start with calendar data defining survey dates and strata:

```{r design}
calendar <- data.frame(
  date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03")),
  day_type = c("weekday", "weekend", "weekend")
)

design <- creel_design(calendar, date = date, strata = day_type)
print(design)
```

## Add Count Data

Attach instantaneous count observations:

```{r counts}
counts <- data.frame(
  date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03")),
  day_type = c("weekday", "weekend", "weekend"),
  effort_hours = c(15, 45, 52)
)

design <- add_counts(design, counts)
```

## Estimate Total Effort

Compute total effort estimate:

```{r estimate}
result <- estimate_effort(design)
print(result)
```

## Grouped Estimation

Estimate effort by day type:

```{r grouped}
result_grouped <- estimate_effort(design, by = day_type)
print(result_grouped)
```

## Variance Methods

Compare variance estimation methods:

```{r variance}
# Taylor linearization (default, fastest)
result_taylor <- estimate_effort(design)

# Bootstrap (500 replicates, slower but robust)
result_boot <- estimate_effort(design, variance = "bootstrap")

# Jackknife (deterministic alternative)
result_jk <- estimate_effort(design, variance = "jackknife")
```

## Next Steps

- Learn about survey design types: `?creel_design`
- Explore validation tiers: `?validate_calendar_schema`
- Read about variance methods: `?estimate_effort`
```

**Key vignette elements:**
- **YAML metadata**: Must include VignetteIndexEntry, VignetteEngine, VignetteEncoding
- **Output format**: `rmarkdown::html_vignette` for lightweight HTML (~10KB)
- **Setup chunk**: Configure knitr options, include = FALSE to hide
- **Library load**: Explicit `library(tidycreel)` for clarity
- **Workflow sections**: Logical progression from design → data → estimation
- **Executable code**: All chunks must run without errors

### Pattern 3: Example Dataset Documentation

**What:** Documented example datasets in data/ directory created from data-raw/ scripts

**When to use:** Package needs reproducible example data for documentation and vignettes

**Example:**
```r
# data-raw/example_calendar.R
# Script to create example_calendar dataset

library(tibble)

# Example calendar for instantaneous count survey
# 7-day period with weekday/weekend strata
example_calendar <- tibble::tibble(
  date = as.Date(c(
    "2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04",
    "2024-06-05", "2024-06-06", "2024-06-07"
  )),
  day_type = c(
    "weekday", "weekend", "weekday", "weekday",
    "weekday", "weekend", "weekend"
  ),
  # Optional: Temperature covariate for future grouped estimation examples
  temperature = c("warm", "cool", "warm", "hot", "warm", "cool", "warm")
)

# Save to data/
usethis::use_data(example_calendar, overwrite = TRUE)
```

```r
# R/data.R - Documentation for example datasets
#' Example calendar data for creel survey
#'
#' A sample calendar dataset demonstrating the structure required for
#' [creel_design()]. Contains 7 days with weekday/weekend strata and
#' optional temperature covariate.
#'
#' @format A tibble with 7 rows and 3 columns:
#' \describe{
#'   \item{date}{Date column (Date class) spanning June 1-7, 2024}
#'   \item{day_type}{Character stratum: "weekday" or "weekend"}
#'   \item{temperature}{Character covariate: "cool", "warm", or "hot"}
#' }
#'
#' @source Simulated data for package examples
#'
#' @examples
#' data(example_calendar)
#' head(example_calendar)
#'
#' # Use with creel_design
#' design <- creel_design(example_calendar, date = date, strata = day_type)
"example_calendar"

#' Example count data for creel survey
#'
#' Sample instantaneous count observations matching [example_calendar].
#' Demonstrates the structure required for [add_counts()].
#'
#' @format A tibble with 7 rows and 3 columns:
#' \describe{
#'   \item{date}{Date column matching calendar dates}
#'   \item{day_type}{Stratum column matching calendar}
#'   \item{effort_hours}{Numeric count variable (total angler hours observed)}
#' }
#'
#' @source Simulated data for package examples
#'
#' @examples
#' data(example_counts)
#' head(example_counts)
#'
#' # Use with add_counts
#' design <- creel_design(example_calendar, date = date, strata = day_type)
#' design <- add_counts(design, example_counts)
"example_counts"
```

**Workflow:**
1. Create data-raw/ directory: `usethis::use_data_raw("example_calendar")`
2. Write data creation script in data-raw/example_calendar.R
3. Run script to generate data/example_calendar.rda via `usethis::use_data()`
4. Document dataset in R/data.R with @format and @source tags
5. Never @export datasets - they're auto-exported via LazyData: true

### Pattern 4: Test Coverage Measurement and Improvement

**What:** Measure coverage with covr, identify gaps, write targeted tests

**When to use:** After core functionality complete, before release validation

**Example:**
```r
# Measure overall coverage
library(covr)
cov <- package_coverage()
print(cov)
percent_coverage(cov)  # Should be >= 85%

# View line-level coverage in browser
report(cov)

# Identify low-coverage files
coverage_df <- tidy(cov)
coverage_by_file <- coverage_df %>%
  group_by(filename) %>%
  summarise(
    total_lines = n(),
    covered_lines = sum(value > 0),
    pct = covered_lines / total_lines * 100
  ) %>%
  arrange(pct)

print(coverage_by_file)

# Focus on core estimation functions
core_files <- c("R/creel-estimates.R", "R/survey-bridge.R")
core_cov <- file_coverage(core_files, core_files)
percent_coverage(core_cov)  # Should be >= 95%
```

**Coverage improvement workflow:**
1. Run `package_coverage()` to establish baseline
2. Use `report(cov)` to visualize line-level coverage in browser
3. Identify uncovered branches (error handling, edge cases, validation)
4. Write targeted tests for gaps (not aiming for 100%, focus on 85%/95% targets)
5. Re-run coverage to verify improvement
6. Add coverage badge to README (optional): `covr::codecov()`

**Common coverage gaps:**
- Error handling paths (invalid inputs, NA values)
- Edge cases (empty data, single observation, sparse strata)
- Print/format methods (low priority, can accept lower coverage)
- Internal helpers (covered indirectly through exported functions)

### Pattern 5: R CMD Check Workflow

**What:** Validate package meets CRAN standards with devtools::check()

**When to use:** Final step before release, run frequently during polish phase

**Example:**
```r
# Run R CMD check with CRAN settings
library(devtools)

# Full check (recommended)
check(args = c("--as-cran"))

# Quick check (during development)
check(document = FALSE, vignettes = FALSE)

# Check specific components
check(build_args = "--no-build-vignettes")  # Skip vignette rebuild
check(check_dir = tempdir())  # Check in temp directory
```

**Interpreting results:**
- **0 errors, 0 warnings, 0 notes**: Perfect - ready for CRAN
- **0 errors, 0 warnings, 1-2 notes**: Acceptable if notes are justified (new submission, non-ASCII data, cross-references)
- **Warnings**: Must fix before submission
- **Errors**: Critical failures, must fix immediately

**Common fixes:**
| Issue | Fix |
|-------|-----|
| "checking Rd files ... WARNING" | Run `devtools::document()` to regenerate .Rd files |
| "undocumented arguments" | Add @param tags for all function parameters |
| "checking examples ... ERROR" | Fix errors in @examples code or wrap in `\dontrun{}` |
| "checking dependencies ... WARNING" | Add missing packages to DESCRIPTION Imports/Suggests |
| "checking package size ... NOTE" | Compress data files or move to separate package |
| "checking Rd cross-references ... NOTE" | Verify links to other packages exist; add to Suggests if needed |

### Anti-Patterns to Avoid

- **Editing .Rd files directly:** Always edit R/ source files and run `devtools::document()`. Manual .Rd edits will be overwritten.
- **Examples that don't run:** All @examples code must be executable. Use `\donttest{}` for slow examples, `\dontrun{}` only for interactive code.
- **Undocumented datasets:** Every dataset in data/ must have roxygen2 documentation in R/data.R with @format and @source.
- **Vignettes with external dependencies:** Vignettes must render on CRAN with only declared dependencies. Use `eval = requireNamespace("package")` for optional packages.
- **Ignoring NOTEs:** While some NOTEs are acceptable, investigate all of them. Unexplained NOTEs may indicate real issues.
- **Missing VignetteBuilder:** If vignettes exist, DESCRIPTION must include `VignetteBuilder: knitr`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Documentation generation | Manual .Rd files | roxygen2 with devtools::document() | roxygen2 co-locates docs with code, supports markdown, auto-generates cross-links; manual Rd is error-prone |
| Vignette infrastructure | Custom long-form docs | usethis::use_vignette() + rmarkdown | Vignette system is CRAN standard with metadata, indexing, and pkgdown integration |
| Example dataset creation | Manual data() calls | usethis::use_data() + data-raw/ scripts | Reproducible workflow, LazyData integration, compression handling |
| Test coverage measurement | Manual tracking | covr::package_coverage() | Line-level coverage, CI/CD integration, coverage service uploads (Codecov) |
| R CMD check execution | Manual command line | devtools::check(args = "--as-cran") | Captures output, R-friendly error messages, integration with RStudio |

**Key insight:** The R package development ecosystem is mature with well-tested tools. Using devtools + usethis + roxygen2 + covr provides a complete workflow that integrates with CRAN standards, CI/CD, and package websites (pkgdown). Hand-rolling any of these components is reinventing a well-oiled wheel.

## Common Pitfalls

### Pitfall 1: Malformed Roxygen2 Blocks Causing .Rd Errors

**What goes wrong:** Running `devtools::document()` generates .Rd files with syntax errors (unexpected section headers, missing closing braces) that cause R CMD check WARNINGs.

**Why it happens:** Roxygen2 is sensitive to formatting: missing blank lines between sections, unmatched braces in @returns, raw LaTeX commands without escaping, or @param tags appearing after @examples.

**How to avoid:** Follow roxygen2 conventions strictly: blank line after title, @param/@returns/@examples in that order, use `\describe{}` for structured returns, escape special characters (`\%` for %, `\\` for backslash).

**Warning signs:**
- R CMD check warns "unexpected section header \value" or "unexpected END_OF_INPUT"
- Documentation doesn't render in RStudio help pane
- `?function_name` shows garbled output

**Fix:** Re-run `devtools::document()` after fixing roxygen2 comments. Check man/*.Rd files are valid with `tools::checkRd("man/function_name.Rd")`.

### Pitfall 2: Examples That Don't Run

**What goes wrong:** R CMD check fails when running examples, either due to errors, missing objects, or unavailable packages.

**Why it happens:** Examples assume package is loaded but don't attach it, reference datasets without loading them, call functions from suggested packages without checking availability, or use external files that don't exist in check environment.

**How to avoid:** Examples must be self-contained: create all needed objects within @examples block, use `data(dataset_name)` to load package data, wrap optional package code in `if (requireNamespace("package"))`, avoid files outside package structure.

**Warning signs:**
- "checking examples ... ERROR: object 'x' not found"
- "checking examples ... ERROR: there is no package called 'xyz'"
- Examples work interactively but fail in check

**Fix:** Test examples in isolation: `devtools::run_examples("R/function.R")`. Make examples fully reproducible within @examples block.

### Pitfall 3: Vignettes That Don't Render

**What goes wrong:** R CMD check fails during vignette building, or vignettes render but with warnings about missing packages or data.

**Why it happens:** Vignettes use packages not in DESCRIPTION Suggests, reference external files that don't exist in check environment, include code that errors during knitting, or use `eval = TRUE` (default) for chunks that require authentication or network access.

**How to avoid:** Declare all vignette dependencies in DESCRIPTION Suggests field, use package data or inst/extdata/ for files, test vignette rendering with `devtools::build_rmd("vignettes/my-vignette.Rmd")`, set `eval = FALSE` for chunks that can't run in CRAN environment (and provide static output).

**Warning signs:**
- "checking whether package ... can be installed ... WARNING"
- "checking re-building of vignette outputs ... WARNING"
- Vignettes render locally but fail in CI/CD

**Fix:** Run `devtools::check(vignettes = TRUE)` to catch vignette issues early. Test in clean R session: `rmarkdown::render("vignettes/my-vignette.Rmd")`.

### Pitfall 4: Insufficient Test Coverage in Core Functions

**What goes wrong:** Overall coverage reaches 85% but core estimation functions (estimate_effort, internal survey bridge) have lower coverage, missing critical edge cases.

**Why it happens:** Tests focus on happy path (valid inputs, standard use cases), neglecting error handling, validation warnings, and edge cases (empty data, single observation, all-NA columns).

**How to avoid:** Measure coverage by file with `covr::file_coverage()`, prioritize core functions for 95% target, use `covr::report()` to visualize uncovered lines, write targeted tests for uncovered branches.

**Warning signs:**
- Overall coverage above target but specific functions below target
- Many uncovered lines in error handling (if/stop blocks)
- Edge cases discovered in production that weren't tested

**Fix:** Identify core functions from requirements (EST-01 through EST-15), run `file_coverage()` on those files, write tests for each uncovered conditional branch until reaching 95% target.

### Pitfall 5: Ignoring R CMD Check NOTEs

**What goes wrong:** Package passes R CMD check with NOTEs that seem harmless but indicate real issues: unused dependencies, undocumented arguments, cross-references to packages not in Suggests.

**Why it happens:** NOTEs are often dismissed as informational, but many indicate configuration errors or missing documentation that CRAN maintainers will flag.

**How to avoid:** Read every NOTE carefully, understand whether it's acceptable (new submission, declared non-ASCII data, justified cross-reference) or actionable (missing dependency, typo in documentation, unused imports). When in doubt, fix it.

**Warning signs:**
- "checking Rd cross-references ... NOTE: package 'xyz' in Rd xrefs not in suggests"
- "checking dependencies ... NOTE: unused import 'package_name'"
- "checking DESCRIPTION meta-information ... NOTE: malformed description"

**Fix:** For cross-reference NOTEs, add package to Suggests or remove cross-reference. For unused imports, remove from DESCRIPTION or add `@importFrom` tag. For description NOTEs, fix formatting/spelling in DESCRIPTION file.

## Code Examples

Verified patterns from official sources:

### Regenerating Documentation After Roxygen2 Edits
```r
# Source: https://r-pkgs.org/man.html
# After editing roxygen2 comments in R/ files
library(devtools)

# Regenerate all .Rd files and NAMESPACE
document()

# Check that documentation renders correctly
?tidycreel::creel_design

# Preview documentation in browser
pkgdown::build_reference()
```

### Creating a Vignette
```r
# Source: https://r-pkgs.org/vignettes.html
library(usethis)

# Create vignette template
use_vignette("tidycreel")  # Creates vignettes/tidycreel.Rmd

# Edit vignette content...

# Preview during development (uses development version of package)
devtools::build_rmd("vignettes/tidycreel.Rmd")

# Build all vignettes
devtools::build_vignettes()
```

### Creating Example Datasets
```r
# Source: https://r-pkgs.org/data.html
library(usethis)

# Set up data-raw directory and script
use_data_raw("example_calendar")

# In data-raw/example_calendar.R:
example_calendar <- tibble::tibble(
  date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03")),
  day_type = c("weekday", "weekend", "weekend")
)

# Export to data/ directory
use_data(example_calendar, overwrite = TRUE)

# Document in R/data.R:
#' Example calendar data
#'
#' @format A tibble with 3 rows and 2 columns:
#' \describe{
#'   \item{date}{Date column}
#'   \item{day_type}{Character stratum}
#' }
#' @source Simulated data
"example_calendar"
```

### Measuring Test Coverage
```r
# Source: https://covr.r-lib.org/
library(covr)

# Overall package coverage
cov <- package_coverage()
print(cov)
percent_coverage(cov)

# Core function coverage (target: 95%)
core_cov <- file_coverage(
  source_files = c("R/creel-estimates.R", "R/survey-bridge.R"),
  test_files = c("tests/testthat/test-estimate-effort.R",
                 "tests/testthat/test-as-survey-design.R")
)
percent_coverage(core_cov)

# Interactive coverage report
report(cov)

# Zero-coverage lines (need tests)
zero_coverage(cov)
```

### Running R CMD Check
```r
# Source: https://r-pkgs.org/R-CMD-check.html
library(devtools)

# Full CRAN check (run before release)
check(args = c("--as-cran"))

# Quick check during development
check(document = FALSE, vignettes = FALSE)

# Check but keep check artifacts for inspection
check(cleanup = FALSE)

# Run specific check components
check_built(path = "tidycreel_0.0.0.9000.tar.gz")
```

### Verifying Lintr Passes
```r
# Source: https://lintr.r-lib.org/
library(lintr)

# Lint entire package
lint_package()

# Lint specific file
lint("R/creel-estimates.R")

# Lint with specific linters
lint_package(linters = linters_with_defaults(line_length_linter(120)))

# Check for lintr configuration
# Should exist: .lintr file in package root
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual .Rd files | roxygen2 inline documentation | roxygen2 1.0 (2011) | Co-located docs and code; markdown support; auto-cross-linking |
| Sweave vignettes (.Rnw) | R Markdown vignettes (.Rmd) | knitr 1.0 (2012) | Markdown syntax easier than LaTeX; html_vignette format (2015) optimized for packages |
| No coverage tools | covr package + Codecov/Coveralls | covr 1.0 (2015) | Automated coverage tracking, CI/CD integration, line-level reporting |
| R CMD check command line only | devtools::check() wrapper | devtools 1.0 (2014) | R-native check execution, better error reporting, RStudio integration |
| styler + formatR fragmentation | lintr + styler standard | lintr 1.0 (2014) | Unified tidyverse style standard; pre-commit hook integration |
| Hard 85% coverage targets | File-specific targets (85% overall, 95% core) | Community practice (2020s) | Recognizes not all code needs equal coverage (print methods vs estimation) |

**Deprecated/outdated:**
- **Sweave vignettes (.Rnw):** LaTeX-based vignette format replaced by R Markdown. Still supported but no longer recommended.
- **inst/doc/ manual management:** Vignettes now auto-built by package tooling; manually editing inst/doc/ causes conflicts.
- **@docType data tag:** Deprecated in roxygen2 7.0+; datasets documented with simple character string (e.g., `"example_calendar"`) as object.
- **Manual NAMESPACE editing:** roxygen2 auto-generates NAMESPACE from @export/@importFrom tags; manual edits will be overwritten.

## Open Questions

1. **Should Phase 7 create multiple vignettes or a single Getting Started vignette?**
   - What we know: Simple packages benefit from single vignette named after package (triggers pkgdown "Get started" link). Complex packages need multiple topic-focused vignettes.
   - What's unclear: Whether tidycreel v0.1.0 is simple enough for single vignette or needs multiple (design, estimation, validation).
   - Recommendation: Start with single "Getting Started" vignette (tidycreel.Rmd) demonstrating complete workflow. Defer multiple vignettes to future versions when additional design types (roving, aerial) are added.

2. **What should example datasets demonstrate?**
   - What we know: Datasets should enable reproducible examples in documentation and vignettes. Need calendar and counts data per requirements DOC-04/DOC-05.
   - What's unclear: Whether to include multiple examples (weekday/weekend strata, multi-site, with/without covariates) or minimal examples.
   - Recommendation: Create two minimal datasets that work together: `example_calendar` (7 days, weekday/weekend strata) and `example_counts` (matching dates/strata, single effort_hours variable). Keep simple for v0.1.0; add more complex examples in future versions.

3. **How to handle test coverage for print/format methods?**
   - What we know: Print and format methods are low-priority for coverage (not core functionality). Increasing overall coverage by testing print methods may not add value.
   - What's unclear: Whether to exclude print methods from coverage targets or include them.
   - Recommendation: Focus coverage efforts on core functions (estimate_effort, creel_design, survey bridge, validation). Accept lower coverage on print/format methods. If overall coverage falls short of 85%, write targeted tests for uncovered estimation logic before testing print methods.

4. **Should R CMD check pass with zero NOTEs for v0.1.0?**
   - What we know: First CRAN submission always generates "new submission" NOTE. Some NOTEs are acceptable (non-ASCII data with encoding, justified cross-references).
   - What's unclear: Whether to aim for zero non-submission NOTEs or accept justified NOTEs.
   - Recommendation: Aim for zero NOTEs except "new submission". Investigate all other NOTEs and fix or document justification. This establishes clean baseline for future maintenance.

5. **Should vignette include comparison to manual survey package code?**
   - What we know: tidycreel's value proposition is domain translation (creel terminology vs survey package). Showing manual survey package code demonstrates the abstraction benefit.
   - What's unclear: Whether comparison adds clarity or confuses new users.
   - Recommendation: Keep Getting Started vignette focused on tidycreel workflow without survey package comparison. Defer comparison to future "Advanced" vignette or package website article. Users who don't know survey package shouldn't need to learn it; users who do know it can use as_survey_design() escape hatch.

## Sources

### Primary (HIGH confidence)
- [R Packages (2e) - Function documentation](https://r-pkgs.org/man.html) - Roxygen2 best practices, required tags, example guidelines
- [R Packages (2e) - Vignettes](https://r-pkgs.org/vignettes.html) - Vignette structure, workflow, CRAN considerations
- [R Packages (2e) - Data](https://r-pkgs.org/data.html) - data-raw workflow, documentation requirements, LazyData
- [R Packages (2e) - R CMD check](https://r-pkgs.org/R-CMD-check.html) - Check categories, common errors/warnings/notes, CRAN requirements
- [roxygen2 official documentation](https://roxygen2.r-lib.org/) - Tag reference, markdown support, inheritance
- [lintr official documentation](https://lintr.r-lib.org/) - Configuration, linter reference, tidyverse defaults
- [covr official documentation](https://covr.r-lib.org/) - package_coverage(), file_coverage(), reporting

### Secondary (MEDIUM confidence)
- [usethis reference - use_data](https://usethis.r-lib.org/reference/use_data.html) - Dataset creation workflow
- [CRAN submission checklist](https://cran.r-project.org/web/packages/submission_checklist.html) - CRAN requirements
- [R Markdown Vignettes documentation](https://bookdown.org/yihui/rmarkdown-cookbook/package-vignette.html) - html_vignette format, metadata

### Tertiary (LOW confidence)
- None - all findings verified with official R package development sources

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All tools are R package development standards with extensive documentation
- Architecture: HIGH - Patterns verified from R Packages book and official package documentation
- Pitfalls: HIGH - Based on R CMD check behavior, roxygen2 documentation, and community best practices
- Code examples: HIGH - Directly from official package documentation (r-pkgs.org, roxygen2, covr, lintr)

**Research date:** 2026-02-09
**Valid until:** 90 days (R package tooling stable; roxygen2/knitr/covr mature packages with infrequent breaking changes)

**Notes:**
- No CONTEXT.md exists for this phase - full design freedom
- Package infrastructure largely complete from Phase 1 (lintr, CI/CD, testthat)
- Main gaps are documentation completion, example datasets, and coverage measurement
- Current R CMD check failures are documentation-only (malformed .Rd from estimate_effort)
- Test suite comprehensive (238 passing tests) but coverage unknown without covr
- Phase 7 is polish and validation, not new feature development
