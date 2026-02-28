# Phase 12: Documentation and Quality Assurance - Research

**Researched:** 2026-02-10
**Domain:** R package documentation, vignette creation, test coverage optimization, and CRAN release preparation
**Confidence:** HIGH

## Summary

Phase 12 finalizes tidycreel v0.2.0 by completing documentation for interview-based estimation, achieving test coverage targets, and ensuring CRAN-readiness. The package has strong foundations from v0.1.0 (Phase 7): roxygen2 documentation infrastructure, testthat v3 framework, lintr configuration (0 issues), and R CMD check passing with 1 NOTE (.mcp.json file). Current state shows 80.27% overall test coverage from 564 passing tests across 15 test files, a "Getting Started" vignette demonstrating effort estimation workflow, and three example datasets (example_calendar, example_counts, example_interviews) already documented in R/data.R.

The key gap is lack of interview-based estimation vignette demonstrating the complete workflow: design → counts → interviews → CPUE → total catch. This vignette is critical for QUAL-04 requirement and must show the new v0.2.0 capabilities: add_interviews() with tidy selectors, estimate_cpue() with ratio-of-means estimator, estimate_harvest() distinguishing caught vs kept fish, and estimate_total_catch()/estimate_total_harvest() combining effort × CPUE with delta method variance. The vignette should parallel the existing "Getting Started" structure but extend it to interview data, demonstrating both ungrouped and grouped estimation, multiple variance methods, and the design-centric API pattern.

Test coverage is close to but below the 85% target (currently 80.27%), requiring targeted tests for uncovered branches in core estimation functions. The package exports 9 functions (add_counts, add_interviews, as_survey_design, creel_design, estimate_cpue, estimate_effort, estimate_harvest, estimate_total_catch, estimate_total_harvest), all with complete roxygen2 documentation. R CMD check passes with 0 errors/0 warnings/1 NOTE, and lintr shows 0 issues. The example_interviews dataset exists and is documented, satisfying QUAL-05.

**Primary recommendation:** Execute Phase 12 in three focused tasks: (1) Create "Interview-Based Estimation" vignette demonstrating complete workflow from counts through total catch, following the proven structure from existing "Getting Started" vignette; (2) Measure file-level coverage with covr::file_coverage() to identify gaps in core estimation functions (estimate_cpue, estimate_harvest, estimate_total_catch, estimate_total_harvest, survey bridge helpers), then write targeted tests for uncovered branches (error handling, edge cases, validation warnings) until reaching 85% overall and 95% for core functions; (3) Run final R CMD check --as-cran, verify all quality gates pass, and document any acceptable NOTEs. This sequence ensures documentation completeness before coverage measurement, and quality validation before declaring phase complete.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| roxygen2 | 7.3.2+ | Documentation generation from inline comments | Universal R package standard; already configured (RoxygenNote: 7.3.2) |
| knitr | 1.45+ | Vignette engine | Already configured in DESCRIPTION (VignetteBuilder: knitr) |
| rmarkdown | 2.25+ | R Markdown processor for vignettes | Required for knitr; already in Suggests |
| covr | 3.6+ | Test coverage measurement | Already installed and working (80.27% measured); CRAN standard |
| lintr | 3.3+ | Static code analysis | Already configured and passing (0 issues); enforces tidyverse style |
| devtools | 2.4+ | Package development workflow | Provides document(), check(), test(), build_vignettes() |
| testthat | 3.0+ | Testing framework | Already configured (Edition 3); 564 tests passing |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| usethis | 3.0+ | Package development helpers | use_vignette() for vignette creation |
| rcmdcheck | 1.4+ | Programmatic R CMD check | Optional - devtools::check() sufficient |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Single vignette | Multiple vignettes | Single vignette sufficient for v0.2.0; future versions can add advanced topics |
| Manual coverage analysis | Automated CI coverage | CI integration deferred to future; manual measurement sufficient for now |
| pkgdown website | Manual documentation | pkgdown deferred to future (post-v0.2.0) |

**Installation:**
All required packages already installed. No additional dependencies needed.

## Architecture Patterns

### Pattern 1: Interview-Based Estimation Vignette Structure

**What:** Complete workflow vignette demonstrating counts → interviews → CPUE → total catch

**When to use:** Primary vignette for v0.2.0 showing new interview-based estimation capabilities

**Example:**
```rmd
---
title: "Interview-Based Catch Estimation"
output: rmarkdown::html_vignette
vignette: >
  %\VignetteIndexEntry{Interview-Based Catch Estimation}
  %\VignetteEngine{knitr::rmarkdown}
  %\VignetteEncoding{UTF-8}
---

```{r setup, include = FALSE}
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>"
)
```

## Introduction

This vignette demonstrates interview-based catch and harvest estimation in tidycreel. Building on the instantaneous count survey design from the "Getting Started" vignette, we add angler interview data to estimate catch per unit effort (CPUE) and total catch.

The complete workflow:
1. **Design**: Create survey calendar and stratification
2. **Counts**: Attach instantaneous count data for effort estimation
3. **Interviews**: Attach angler interview data with catch and effort
4. **CPUE**: Estimate catch per unit effort (ratio-of-means)
5. **Total Catch**: Combine effort × CPUE with delta method variance

## Survey Design and Count Data

```{r design}
library(tidycreel)

# Load example data
data(example_calendar)
data(example_counts)

# Create design and attach counts
design <- creel_design(example_calendar, date = date, strata = day_type)
design <- add_counts(design, example_counts)

# Estimate total effort
effort <- estimate_effort(design)
print(effort)
```

## Adding Interview Data

Attach angler interview data with catch and effort information:

```{r interviews}
# Load example interviews
data(example_interviews)
head(example_interviews)

# Attach to design with tidy selectors
design <- add_interviews(design, example_interviews,
                        catch = catch_total,
                        effort = hours_fished,
                        harvest = catch_kept)
print(design)
```

## Estimating CPUE

Estimate catch per unit effort using ratio-of-means estimator:

```{r cpue}
# Estimate CPUE (catch/effort ratio)
cpue <- estimate_cpue(design)
print(cpue)
```

The ratio-of-means estimator is appropriate for access point surveys with complete trip interviews. It computes total catch divided by total effort across all interviews.

## Estimating Total Catch

Combine effort and CPUE to estimate total catch:

```{r total_catch}
# Estimate total catch (effort × CPUE)
total_catch <- estimate_total_catch(design)
print(total_catch)
```

Variance is propagated correctly using the delta method: Var(E × C) = E² Var(C) + C² Var(E), accounting for independence of count and interview data streams.

## Estimating Harvest

Estimate harvest (kept fish) separately from total catch:

```{r harvest}
# Estimate harvest per unit effort
hpue <- estimate_harvest(design)
print(hpue)

# Estimate total harvest
total_harvest <- estimate_total_harvest(design)
print(total_harvest)

# Verify biological constraint: harvest ≤ catch
stopifnot(total_harvest$estimates$estimate <= total_catch$estimates$estimate)
```

## Grouped Estimation

Estimate by day type (weekday vs weekend):

```{r grouped}
# Grouped CPUE
cpue_by_day <- estimate_cpue(design, by = day_type)
print(cpue_by_day)

# Grouped total catch
total_catch_by_day <- estimate_total_catch(design, by = day_type)
print(total_catch_by_day)
```

Note: Some grouped estimates may be skipped if sample size is too small (n < 10 per group).

## Variance Methods

Compare variance estimation methods:

```{r variance}
# Taylor linearization (default, recommended)
cpue_taylor <- estimate_cpue(design)

# Bootstrap (500 replicates)
set.seed(123)
cpue_boot <- estimate_cpue(design, variance = "bootstrap")

# Jackknife (deterministic alternative)
cpue_jk <- estimate_cpue(design, variance = "jackknife")

# All three methods produce similar results
```

## Complete Workflow Example

Pull it all together:

```{r complete}
# 1. Design
design <- creel_design(example_calendar, date = date, strata = day_type)

# 2. Add count data
design <- add_counts(design, example_counts)

# 3. Add interview data
design <- add_interviews(design, example_interviews,
                        catch = catch_total,
                        effort = hours_fished,
                        harvest = catch_kept)

# 4. Estimate all quantities
effort_est <- estimate_effort(design)
cpue_est <- estimate_cpue(design)
hpue_est <- estimate_harvest(design)
total_catch_est <- estimate_total_catch(design)
total_harvest_est <- estimate_total_harvest(design)

# 5. View results
print(effort_est)
print(cpue_est)
print(total_catch_est)
```

## Next Steps

- `?add_interviews` - Attach interview data to designs
- `?estimate_cpue` - CPUE estimation with ratio-of-means
- `?estimate_harvest` - Harvest rate estimation
- `?estimate_total_catch` - Total catch combining effort and CPUE
- `?example_interviews` - Example interview dataset structure
```

**Key vignette elements:**
- **YAML metadata**: VignetteIndexEntry, VignetteEngine, VignetteEncoding required
- **Output format**: `rmarkdown::html_vignette` for lightweight HTML
- **Logical progression**: Design → counts → interviews → CPUE → total catch
- **Executable code**: All chunks must run without errors
- **Demonstrates new features**: All v0.2.0 functions showcased
- **Parallel structure**: Mirrors "Getting Started" vignette pattern for consistency

### Pattern 2: File-Level Coverage Analysis and Gap Identification

**What:** Systematic coverage measurement and targeted test creation to reach 85%/95% targets

**When to use:** After core functionality complete, before final release validation

**Example:**
```r
library(covr)

# Measure overall coverage
cov <- package_coverage()
percent_coverage(cov)  # Current: 80.27%, target: 85%

# View interactive report to identify gaps
report(cov)

# Focus on core estimation functions (target: 95%)
core_files <- c(
  "R/creel-estimates.R",               # estimate_effort, estimate_cpue, estimate_harvest
  "R/creel-estimates-total-catch.R",   # estimate_total_catch
  "R/creel-estimates-total-harvest.R", # estimate_total_harvest
  "R/survey-bridge.R"                  # validate_design_compatibility, etc.
)

core_cov <- file_coverage(
  source_files = core_files,
  test_files = c(
    "tests/testthat/test-estimate-effort.R",
    "tests/testthat/test-estimate-cpue.R",
    "tests/testthat/test-estimate-harvest.R",
    "tests/testthat/test-estimate-total-catch.R",
    "tests/testthat/test-estimate-total-harvest.R"
  )
)

# Identify uncovered lines
zero_coverage(cov)
```

**Coverage improvement workflow:**
1. Run `package_coverage()` to establish baseline (currently 80.27%)
2. Use `report(cov)` in browser to visualize line-level coverage
3. Identify uncovered branches in core functions (error handlers, edge cases)
4. Write targeted tests for gaps (not aiming for 100%, focus on meaningful coverage)
5. Re-run coverage to verify improvement
6. Iterate until 85% overall and 95% for core functions

**Common coverage gaps to address:**
- Error handling paths (invalid inputs, missing columns, NA values)
- Edge cases (empty data, single observation, zero effort/catch)
- Validation warnings (Tier 2 warnings for data quality issues)
- Format methods (lower priority but may help reach 85% overall)

### Pattern 3: Final Quality Gate Validation

**What:** Comprehensive pre-release checklist ensuring all QUAL-* requirements satisfied

**When to use:** Final step before declaring Phase 12 complete

**Example:**
```r
library(devtools)

# 1. R CMD check (QUAL-06)
check(args = c("--as-cran"))
# Target: 0 errors, 0 warnings, acceptable NOTEs only

# 2. Test coverage (QUAL-07)
library(covr)
cov <- package_coverage()
percent_coverage(cov)
# Target: >= 85% overall

# Core function coverage
core_cov <- file_coverage(
  source_files = c("R/creel-estimates.R",
                   "R/creel-estimates-total-catch.R",
                   "R/creel-estimates-total-harvest.R")
)
percent_coverage(core_cov)
# Target: >= 95% for core estimation functions

# 3. Lintr (QUAL-08)
library(lintr)
lint_package()
# Target: 0 issues (already achieved)

# 4. Vignettes render (QUAL-04)
build_vignettes()
# Target: All vignettes build without errors

# 5. Example datasets documented (QUAL-05)
?example_calendar
?example_counts
?example_interviews
# Target: All datasets have roxygen2 docs (already achieved)
```

**Quality gate checklist:**
- [ ] R CMD check: 0 errors, 0 warnings ✓ (current: 1 NOTE for .mcp.json)
- [ ] Lintr: 0 issues ✓ (already achieved)
- [ ] Test coverage: ≥85% overall (current: 80.27%, needs +4.73%)
- [ ] Core function coverage: ≥95% (needs measurement and targeted tests)
- [ ] Vignettes: Interview-based estimation vignette complete
- [ ] Example datasets: Documented ✓ (already achieved)
- [ ] Tests passing: 564 passing, 0 failing ✓ (already achieved)

### Anti-Patterns to Avoid

- **Adding tests for coverage theater:** Focus on meaningful tests for uncovered branches, not trivial tests to inflate numbers. Testing print methods to reach 85% is less valuable than testing error handling in core functions.
- **Creating overly complex vignettes:** Keep vignette focused on workflow demonstration. Advanced topics (custom variance methods, design internals) can be deferred to future vignettes.
- **Ignoring R CMD check NOTEs:** While some NOTEs are acceptable (.mcp.json is justified), investigate all NOTEs to ensure no hidden issues.
- **Hand-rolling coverage reports:** Use covr's interactive report() function to visualize gaps; manual analysis is error-prone.
- **Skipping vignette testing:** Always run `devtools::build_vignettes()` to verify vignettes render correctly before final validation.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Coverage measurement | Manual line counting | covr::package_coverage() | Automated line-level coverage, CI/CD integration, interactive reports |
| Vignette creation | Custom markdown docs | usethis::use_vignette() + rmarkdown | CRAN-standard vignette infrastructure with metadata and indexing |
| R CMD check | Manual validation | devtools::check(args = "--as-cran") | Comprehensive CRAN checks with R-friendly error messages |
| Coverage gap identification | Reading source code | covr::report() interactive browser | Visual line-level coverage highlighting uncovered branches |
| Test organization | Monolithic test files | testthat file-per-feature pattern | Already established: 15 test files with clear organization |

**Key insight:** The R package ecosystem provides mature, battle-tested tools for documentation and quality assurance. Using roxygen2 + knitr + covr + devtools provides complete workflow that integrates with CRAN standards. Hand-rolling any of these is reinventing wheels that have been refined over years of CRAN submissions.

## Common Pitfalls

### Pitfall 1: Vignette Examples Failing in CRAN Environment

**What goes wrong:** Vignette renders locally but fails during R CMD check or on CRAN due to missing objects, unavailable packages, or data assumptions.

**Why it happens:** Vignettes run in isolated environment during check. Code that works interactively may fail if: examples assume package is loaded but don't call `library(tidycreel)`, reference data without `data()` calls, use external files not in inst/extdata, or call functions from suggested packages without checking availability.

**How to avoid:** Make vignettes fully self-contained: explicit `library(tidycreel)` at top, explicit `data()` calls for example datasets, all needed objects created within vignette, avoid external file dependencies.

**Warning signs:**
- Vignette renders with `devtools::build_rmd()` but fails in `devtools::check()`
- "object not found" errors during vignette building
- CI/CD builds fail on vignette rendering step

**Fix:** Test vignette rendering in clean session: `rmarkdown::render("vignettes/interview-estimation.Rmd")`. Ensure all data loads explicitly and all objects are defined within vignette chunks.

### Pitfall 2: Coverage Measurement Includes Generated/Data Files

**What goes wrong:** Coverage percentage includes auto-generated files (R/data.R documentation) or low-priority code (print methods), diluting meaningful coverage metrics.

**Why it happens:** covr::package_coverage() by default measures all R code. Documentation-only files (R/data.R) and format/print methods have low coverage value but count toward overall percentage.

**How to avoid:** Use existing codecov.yml exclusions (already configured to ignore R/globals.R, R/data.R, data-raw/*). Focus coverage improvement on core estimation functions rather than print methods.

**Warning signs:**
- Overall coverage percentage doesn't reflect core function quality
- Much effort spent testing print/format methods to reach 85%
- Coverage metrics skewed by documentation-only files

**Fix:** Already addressed in codecov.yml configuration. When measuring core function coverage, use file_coverage() with explicit source_files list of estimation functions.

### Pitfall 3: Insufficient Core Function Coverage Despite High Overall Coverage

**What goes wrong:** Overall coverage reaches 85% but core estimation functions (estimate_cpue, estimate_total_catch, etc.) have lower coverage, missing critical edge cases.

**Why it happens:** Tests focus on happy path (valid inputs, standard use cases), neglecting error handling, validation warnings, and edge cases (empty data, zero effort, NA values, extreme sample sizes).

**How to avoid:** Measure coverage by file with file_coverage() for core functions separately. Identify uncovered branches (error handlers, validation logic) and write targeted tests. Prioritize core functions for 95% target before measuring overall coverage.

**Warning signs:**
- Many uncovered lines in validate_* functions
- Error handling blocks (if/stop) not covered
- Edge cases discovered in production that weren't tested
- Sample size validation warnings not tested

**Fix:** From existing test suites (564 tests), identify gaps using covr::report(). Core functions for 95% target:
- R/creel-estimates.R (estimate_effort, estimate_cpue, estimate_harvest)
- R/creel-estimates-total-catch.R (estimate_total_catch)
- R/creel-estimates-total-harvest.R (estimate_total_harvest)
- R/survey-bridge.R (validate_design_compatibility, validate_grouping_compatibility)

### Pitfall 4: R CMD Check NOTE for .mcp.json Not Justified

**What goes wrong:** R CMD check produces NOTE about hidden file .mcp.json but no justification documented, causing uncertainty about CRAN acceptability.

**Why it happens:** MCP configuration file .mcp.json is hidden but needed for development tooling. CRAN check flags hidden files as potential errors.

**How to avoid:** Document justification for .mcp.json NOTE in CRAN submission comments. Alternatively, move to .Rbuildignore to exclude from package tarball if not needed in installed package.

**Warning signs:**
- R CMD check shows NOTE about .mcp.json
- No documentation of why this NOTE is acceptable
- Uncertainty about CRAN submission with this NOTE

**Fix:** Two options:
1. Add to .Rbuildignore: `echo "^\.mcp\.json$" >> .Rbuildignore` (excludes from built package)
2. Document justification: MCP configuration for development tooling, not user-facing

### Pitfall 5: Interview Vignette Doesn't Demonstrate Key v0.2.0 Features

**What goes wrong:** New vignette shows basic workflow but misses key features (grouped estimation, variance methods, delta method variance, harvest vs catch distinction), failing to satisfy QUAL-04 requirement for "complete workflow demonstration."

**Why it happens:** Focus on minimal example without showcasing differentiating features. Users don't understand when to use estimate_harvest vs estimate_cpue, or why delta method variance matters.

**How to avoid:** Structure vignette to demonstrate all v0.2.0 requirements: add_interviews with tidy selectors (INTV-02), ratio-of-means CPUE (CPUE-02), grouped estimation (CPUE-03), harvest distinction (HARV-03), delta method variance (TCATCH-02), design-centric API (QUAL-03).

**Warning signs:**
- Vignette shows only ungrouped estimation
- No explanation of ratio-of-means vs other estimators
- Variance method options not demonstrated
- Delta method variance not mentioned
- Harvest vs catch distinction unclear

**Fix:** Follow Pattern 1 structure: introduction explaining workflow, design/counts section establishing foundation, add_interviews demonstrating tidy selectors, estimate_cpue showing ratio-of-means, estimate_total_catch explaining delta method, grouped estimation by= parameter, variance methods comparison, complete workflow example tying it together.

## Code Examples

Verified patterns from official sources and existing package structure:

### Creating Interview Vignette

```r
# Source: https://r-pkgs.org/vignettes.html
library(usethis)

# Create vignette template
use_vignette("interview-estimation", title = "Interview-Based Catch Estimation")

# Opens vignettes/interview-estimation.Rmd for editing
# Edit content following Pattern 1 structure...

# Preview during development
devtools::build_rmd("vignettes/interview-estimation.Rmd")

# Build all vignettes for final check
devtools::build_vignettes()
```

### Measuring Coverage and Identifying Gaps

```r
# Source: https://covr.r-lib.org/
library(covr)

# Overall package coverage
cov <- package_coverage()
print(cov)
cat("Overall coverage:", percent_coverage(cov), "%\n")

# Interactive report highlighting uncovered lines
report(cov)

# Core function coverage (target: 95%)
core_files <- c(
  "R/creel-estimates.R",
  "R/creel-estimates-total-catch.R",
  "R/creel-estimates-total-harvest.R",
  "R/survey-bridge.R"
)

core_cov <- file_coverage(
  source_files = core_files,
  test_files = list.files("tests/testthat", pattern = "^test-estimate-.*\\.R$",
                          full.names = TRUE)
)
cat("Core function coverage:", percent_coverage(core_cov), "%\n")

# Identify specific uncovered lines
uncovered <- zero_coverage(cov)
print(uncovered)
```

### Final Quality Gate Validation

```r
# Source: Package development best practices
library(devtools)
library(covr)
library(lintr)

# 1. R CMD check (must pass with 0 errors/warnings)
check_results <- check(args = c("--as-cran"))

# 2. Test coverage
cov <- package_coverage()
overall_pct <- percent_coverage(cov)
stopifnot(overall_pct >= 85, "Overall coverage below 85% target")

# Core functions
core_cov <- file_coverage(
  source_files = c("R/creel-estimates.R",
                   "R/creel-estimates-total-catch.R",
                   "R/creel-estimates-total-harvest.R")
)
core_pct <- percent_coverage(core_cov)
stopifnot(core_pct >= 95, "Core function coverage below 95% target")

# 3. Lintr (must be 0 issues)
lints <- lint_package()
stopifnot(length(lints) == 0, "Lintr issues found")

# 4. Vignettes render
build_vignettes()

# 5. All tests pass
test_results <- test()
stopifnot(sum(as.data.frame(test_results)$failed) == 0, "Test failures found")

cat("All quality gates passed ✓\n")
```

### Writing Targeted Coverage Tests

```r
# Pattern from existing test files
# Example: Testing uncovered error handling branches

test_that("estimate_cpue errors when interview data missing", {
  design <- creel_design(example_calendar, date = date, strata = day_type)
  design <- add_counts(design, example_counts)
  # No interviews attached

  expect_error(
    estimate_cpue(design),
    "interviews"  # Regex matching error message
  )
})

test_that("estimate_total_catch handles zero effort edge case", {
  # Create design with zero effort in counts
  zero_counts <- example_counts
  zero_counts$effort_hours[1] <- 0

  design <- creel_design(example_calendar, date = date, strata = day_type)
  design <- add_counts(design, zero_counts)
  design <- add_interviews(design, example_interviews,
                          catch = catch_total,
                          effort = hours_fished)

  # Should complete without error (filter zero-effort before estimation)
  result <- estimate_total_catch(design)
  expect_s3_class(result, "creel_estimates")
})

test_that("estimate_cpue warns for small sample size", {
  # Create design with only 5 interviews
  small_interviews <- example_interviews[1:5, ]

  design <- creel_design(example_calendar, date = date, strata = day_type)
  design <- add_counts(design, example_counts)
  design <- add_interviews(design, small_interviews,
                          catch = catch_total,
                          effort = hours_fished)

  expect_warning(
    estimate_cpue(design),
    "sample size.*small"
  )
})
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual .Rd files | roxygen2 inline documentation | roxygen2 1.0 (2011) | Co-located docs and code; markdown support |
| Sweave vignettes | R Markdown vignettes | knitr 1.0 (2012) | Markdown syntax easier than LaTeX |
| No coverage tools | covr + Codecov | covr 1.0 (2015) | Line-level coverage, CI/CD integration |
| Hard 85% targets everywhere | File-specific targets (85% overall, 95% core) | Community practice (2020s) | Recognizes not all code needs equal coverage |
| testthat Edition 2 | testthat Edition 3 | testthat 3.0 (2020) | Snapshot testing, better output formatting |

**Deprecated/outdated:**
- **Sweave vignettes (.Rnw):** LaTeX-based format replaced by R Markdown
- **@docType data:** Deprecated in roxygen2 7.0+; use character string object documentation
- **Manual NAMESPACE editing:** roxygen2 auto-generates from @export tags
- **inst/doc/ manual management:** Vignettes auto-built by package tooling

## Open Questions

1. **Should Phase 12 aim for zero NOTEs in R CMD check?**
   - What we know: Current 1 NOTE for .mcp.json file. First CRAN submission always generates "new submission" NOTE.
   - What's unclear: Whether to remove .mcp.json NOTE via .Rbuildignore or document justification.
   - Recommendation: Add .mcp.json to .Rbuildignore to achieve zero NOTEs. MCP configuration is development tooling, not needed in installed package.

2. **What level of detail should interview vignette include about delta method variance?**
   - What we know: Delta method is key differentiator vs naive product variance. Technical users may want formula details.
   - What's unclear: Balance between accessibility for domain users and technical rigor for statisticians.
   - Recommendation: Brief explanation in vignette ("variance propagated correctly using delta method accounting for independence"), with reference to ?estimate_total_catch documentation for formula details. Keep vignette focused on workflow.

3. **Should Phase 12 create second vignette for advanced topics?**
   - What we know: Single vignette sufficient for v0.2.0 requirements. Advanced topics (custom variance methods, design internals, survey package comparison) not required.
   - What's unclear: Whether advanced vignette adds value or is premature.
   - Recommendation: Single vignette for v0.2.0. Defer advanced topics to future versions when additional design types (roving, aerial) add complexity warranting separate documentation.

4. **How to handle 9 skipped tests in coverage measurement?**
   - What we know: 9 tests skipped due to example data having groups with n < 10. Tests themselves are correct but data doesn't support grouped estimation.
   - What's unclear: Whether skipped tests count against coverage targets.
   - Recommendation: Skipped tests are acceptable (realistic example data limitation). Focus coverage measurement on passed tests (564 tests). Don't create artificial test data just to run skipped tests.

5. **Should core function coverage exclude format/print methods?**
   - What we know: format.creel_estimates and print methods in R/creel-estimates.R are not "core estimation" logic.
   - What's unclear: Whether format methods should count toward 95% core function target.
   - Recommendation: Include in overall 85% target but exclude from core function 95% target. When measuring core coverage with file_coverage(), focus on estimation logic (estimate_effort, estimate_cpue, etc.) not format methods.

## Sources

### Primary (HIGH confidence)
- [R Packages (2e) - Function documentation](https://r-pkgs.org/man.html) - Roxygen2 best practices
- [R Packages (2e) - Vignettes](https://r-pkgs.org/vignettes.html) - Vignette structure and workflow
- [R Packages (2e) - R CMD check](https://r-pkgs.org/R-CMD-check.html) - CRAN requirements
- [roxygen2 official documentation](https://roxygen2.r-lib.org/) - Tag reference
- [covr official documentation](https://covr.r-lib.org/) - Coverage measurement
- [lintr official documentation](https://lintr.r-lib.org/) - Code quality checks
- tidycreel codebase analysis - Existing test suite (564 tests), vignette structure, documentation patterns

### Secondary (MEDIUM confidence)
- Phase 7 RESEARCH.md - v0.1.0 documentation patterns
- Phase 11 VERIFICATION.md - Current package state (tests passing, R CMD check status)
- .planning/codebase/TESTING.md - Test organization patterns
- .planning/codebase/CONVENTIONS.md - Coding standards

### Tertiary (LOW confidence)
- None - all findings verified from official sources and package inspection

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All tools established from v0.1.0, already configured and working
- Architecture patterns: HIGH - Based on existing package structure and R Packages book
- Pitfalls: HIGH - Based on R CMD check behavior and existing codebase patterns
- Coverage analysis: HIGH - Measured directly (80.27% overall, 564 tests passing)

**Research date:** 2026-02-10
**Valid until:** 90 days (R package tooling stable; roxygen2/knitr/covr mature)

**Current package state:**
- R CMD check: 0 errors, 0 warnings, 1 NOTE (.mcp.json)
- Lintr: 0 issues ✓
- Test coverage: 80.27% overall (target: 85%)
- Tests: 564 passing, 0 failing, 9 skipped
- Vignettes: 1 existing ("Getting Started" for effort estimation)
- Example datasets: 3 documented (calendar, counts, interviews) ✓
- Exported functions: 9 (all with roxygen2 docs)

**Phase 12 gaps:**
1. Interview-based estimation vignette (QUAL-04)
2. Test coverage below 85% target (current: 80.27%, need +4.73%)
3. Core function coverage unmeasured (target: 95%)
4. .mcp.json NOTE in R CMD check (minor, can be resolved via .Rbuildignore)

**Ready for planning:** All research complete, clear path to phase completion.
