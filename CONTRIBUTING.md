# Contributing to tidycreel

We welcome contributions to tidycreel! This document covers where to ask
questions, how to file bug reports and feature requests, and the
development standards and workflow for pull requests.

## Code of Conduct

Please note that this project is released with a [Contributor Code of
Conduct](https://chrischizinski.github.io/tidycreel/CODE_OF_CONDUCT.md).
By participating in this project you agree to abide by its terms.

## Getting Help

For questions about how to use tidycreel — choosing survey types,
interpreting estimates, structuring your data — open a thread in [GitHub
Discussions](https://github.com/chrischizinski/tidycreel/discussions).
Please search existing threads before posting.

GitHub Issues is for bugs and feature requests only. How-to questions
filed as issues will be redirected to Discussions.

## Filing Issues

### Bug Reports

Click **Bug report** on the [New
Issue](https://github.com/chrischizinski/tidycreel/issues/new/choose)
page to open the structured form. The form asks for:

- **Survey type:** which design you are using (`instantaneous`,
  `bus_route`, `ice`, `camera`, or `aerial`)
- **tidycreel version:** from `packageVersion("tidycreel")`
- **Expected vs actual behavior:** what you expected to happen and what
  actually happened
- **A reprex:** a minimal reproducible example (see below)

**Writing a reprex**

A minimal reproducible example is a self-contained R snippet that
demonstrates the problem using only tidycreel and base R (or
dplyr/tidyr). Use `reprex::reprex()` to render and share it.

A good reprex looks like this:

``` r

library(tidycreel)

# Minimal data that triggers the problem
trips <- data.frame(
  trip_id   = 1:3,
  effort_hr = c(2.5, NA, 1.0),
  catch     = c(4L, 2L, 0L)
)

# The failing call
estimate_catch(trips, survey_type = "instantaneous")
#> Error in ...
```

The snippet should be copy-paste runnable and produce the error without
any additional setup. Avoid including your full dataset; reduce to the
smallest example that still fails.

### Feature Requests

Click **Feature request** on the [New
Issue](https://github.com/chrischizinski/tidycreel/issues/new/choose)
page. The form asks for:

- **Problem statement:** what limitation or gap you are hitting
- **Proposed solution:** how you would like it to work
- **Use case:** a concrete scenario where this would be useful
- **Survey types affected:** which designs (`instantaneous`,
  `bus_route`, `ice`, `camera`, `aerial`) are relevant

## Development Principles

### Vectorization-First Policy

**tidycreel follows a vectorization-first approach** to ensure
performance and scalability:

- **Prefer vectorized operations** over explicit loops (`for`, `while`)
  whenever possible
- **Use grouped operations** via
  [`dplyr::group_by()`](https://dplyr.tidyverse.org/reference/group_by.html)
  for stratum-level calculations
- **Leverage vectorized functions** from base R, tidyverse, and survey
  packages
- **Avoid [`apply()`](https://rdrr.io/r/base/apply.html) family** when
  vectorized alternatives exist
- **Profile performance** for functions processing large datasets
  (\>10^5 rows)

**Examples:**

``` r

# Good: Vectorized approach
effort_total <- sum(design_data$effort * design_data$weights, na.rm = TRUE)

# Good: Grouped vectorized approach
strata_totals <- design_data %>%
  group_by(stratum_id) %>%
  summarise(effort = sum(effort * weights, na.rm = TRUE))

# Avoid: Explicit loops
effort_total <- 0
for (i in seq_len(nrow(design_data))) {
  effort_total <- effort_total + design_data$effort[i] * design_data$weights[i]
}
```

### Statistical Foundations

**tidycreel builds on the `survey` package** as the authoritative
engine:

- **Use
  [`survey::svydesign()`](https://rdrr.io/pkg/survey/man/svydesign.html)
  and
  [`survey::svrepdesign()`](https://rdrr.io/pkg/survey/man/svrepdesign.html)**
  for design objects
- **Provide tidy wrappers** around survey functions with pipe-friendly
  interfaces
- **Return tibbles** with estimates, standard errors, and metadata
- **Document statistical assumptions** and variance estimation methods
- **Favor design-based estimators** over model-based approaches as
  defaults

### Tidyverse Style

**Follow the [tidyverse style guide](https://style.tidyverse.org)
completely:**

- **Function names:** `snake_case` with descriptive verbs
  (`estimate_effort`, not `effort_est`)
- **Variable names:** `snake_case` with clear meaning (`party_size`, not
  `ps`)
- **File names:** `kebab-case` for multi-word concepts
  (`design-constructors.R`)
- **Documentation:** Complete roxygen2 docs with examples
- **Pipes:** Use `%>%` for multi-step data transformations

## Technical Standards

### Code Quality

- **100% of public functions** must have roxygen2 documentation
- **All exported functions** must include working examples
- **Target ≥90% test coverage** with meaningful assertions
- **Use `usethis`, `devtools`, `testthat` workflows** for development
- **Run `devtools::check()` before submitting** pull requests

### Testing Requirements

**Every contribution must include tests:**

``` r

test_that("estimate_effort returns proper structure", {
  # Arrange
  design <- create_test_design()

  # Act
  result <- estimate_effort(design)

  # Assert
  expect_s3_class(result, "tbl_df")
  expect_true(all(c("effort_estimate", "se", "cv") %in% names(result)))
  expect_true(all(result$effort_estimate >= 0))
})
```

**Test edge cases explicitly:** - Zero effort/catch scenarios - Empty
strata - Missing data patterns - Single-observation groups - Date/time
boundary conditions (DST, leap years)

### Performance Expectations

**Functions must scale efficiently:**

- **Benchmark large datasets** (10^6+ rows) in tests
- **Use `profvis` for profiling** computationally intensive functions
- **Consider `data.table` backends** for heavy processing
- **Document time/memory complexity** for key algorithms

## Contribution Workflow

### Getting Started

1.  **Fork and clone** the repository

2.  **Create a feature branch:**
    `git checkout -b feature/descriptive-name`

3.  **Set up development environment:**

    ``` r

    renv::restore()
    devtools::load_all()
    ```

### Development Process

1.  **Write tests first** following TDD principles

2.  **Implement the feature** following our style guide

3.  **Update documentation** including function docs and vignettes if
    needed

4.  **Run comprehensive checks:**

    ``` r

    devtools::document()
    devtools::test()
    devtools::check()
    ```

5.  **Commit with clear messages** following [conventional
    commits](https://www.conventionalcommits.org/)

### Pull Request Guidelines

Before opening a PR for a non-trivial change, file an issue first so the
approach can be discussed. This avoids duplication of effort and ensures
the change aligns with the project direction.

**Before submitting:** - \[ \] All tests pass (`devtools::test()`) - \[
\] Package passes R CMD check (`devtools::check()`) - \[ \]
Documentation is complete and accurate - \[ \] NEWS.md updated for
user-facing changes - \[ \] Code follows tidyverse style (verified with
[`styler::style_pkg()`](https://styler.r-lib.org/reference/style_pkg.html))

**PR Description should include:** - Summary of changes and motivation -
Links to relevant issues - Breaking changes (if any) - Example usage for
new features

## Package Architecture

### File Organization

    R/
    ├── data-schemas.R      # Schema definitions and validation
    ├── design-constructors.R  # Survey design object creation
    ├── estimators.R        # Core estimation functions
    ├── legacy-*.R          # Legacy API compatibility
    └── utils.R             # Internal helper functions

### Naming Conventions

- **Design functions:** `design_*()`
- **Estimation functions:** `estimate_*()`
- **Validation functions:** `validate_*()`
- **Utility functions:** `calculate_*()`, `create_*()`

### Dependencies

**Core dependencies** (keep minimal): - `survey` - design objects and
estimation - `dplyr`, `tidyr` - data manipulation - `rlang`, `vctrs` -
programming tools

**Suggested dependencies** (for specific features): - `cli` - user
messaging - `lifecycle` - deprecation management

## Recognition

Contributors are recognized in: - Package DESCRIPTION file - NEWS.md
release notes - Annual contributor acknowledgments

Thank you for contributing to tidycreel!
