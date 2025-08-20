# Contributing to tidycreel

We welcome contributions to tidycreel! This document outlines our development standards and contribution process.

## Code of Conduct

Please note that this project is released with a [Contributor Code of Conduct](CODE_OF_CONDUCT.md). By participating in this project you agree to abide by its terms.

## Development Principles

### Vectorization-First Policy

**tidycreel follows a vectorization-first approach** to ensure performance and scalability:

- **Prefer vectorized operations** over explicit loops (`for`, `while`) whenever possible
- **Use grouped operations** via `dplyr::group_by()` for stratum-level calculations
- **Leverage vectorized functions** from base R, tidyverse, and survey packages
- **Avoid `apply()` family** when vectorized alternatives exist
- **Profile performance** for functions processing large datasets (>10^5 rows)

**Examples:**

```r
# ✅ Good: Vectorized approach
effort_total <- sum(design_data$effort * design_data$weights, na.rm = TRUE)

# ✅ Good: Grouped vectorized approach  
strata_totals <- design_data %>%
  group_by(stratum_id) %>%
  summarise(effort = sum(effort * weights, na.rm = TRUE))

# ❌ Avoid: Explicit loops
effort_total <- 0
for (i in seq_len(nrow(design_data))) {
  effort_total <- effort_total + design_data$effort[i] * design_data$weights[i]
}
```

### Statistical Foundations

**tidycreel builds on the `survey` package** as the authoritative engine:

- **Use `survey::svydesign()` and `survey::svrepdesign()`** for design objects
- **Provide tidy wrappers** around survey functions with pipe-friendly interfaces
- **Return tibbles** with estimates, standard errors, and metadata
- **Document statistical assumptions** and variance estimation methods
- **Favor design-based estimators** over model-based approaches as defaults

### Tidyverse Style

**Follow the [tidyverse style guide](https://style.tidyverse.org) completely:**

- **Function names:** `snake_case` with descriptive verbs (`estimate_effort`, not `effort_est`)
- **Variable names:** `snake_case` with clear meaning (`party_size`, not `ps`)  
- **File names:** `kebab-case` for multi-word concepts (`design-constructors.R`)
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

```r
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

**Test edge cases explicitly:**
- Zero effort/catch scenarios  
- Empty strata
- Missing data patterns
- Single-observation groups
- Date/time boundary conditions (DST, leap years)

### Performance Expectations

**Functions must scale efficiently:**

- **Benchmark large datasets** (10^6+ rows) in tests
- **Use `profvis` for profiling** computationally intensive functions  
- **Consider `data.table` backends** for heavy processing
- **Document time/memory complexity** for key algorithms

## Contribution Workflow

### Getting Started

1. **Fork and clone** the repository
2. **Create a feature branch:** `git checkout -b feature/descriptive-name`
3. **Set up development environment:**
   ```r
   renv::restore()
   devtools::load_all()
   ```

### Development Process

1. **Write tests first** following TDD principles
2. **Implement the feature** following our style guide
3. **Update documentation** including function docs and vignettes if needed
4. **Run comprehensive checks:**
   ```r
   devtools::document()
   devtools::test()
   devtools::check()
   ```
5. **Commit with clear messages** following [conventional commits](https://www.conventionalcommits.org/)

### Pull Request Guidelines

**Before submitting:**
- [ ] All tests pass (`devtools::test()`)
- [ ] Package passes R CMD check (`devtools::check()`)
- [ ] Documentation is complete and accurate
- [ ] NEWS.md updated for user-facing changes
- [ ] Code follows tidyverse style (verified with `styler::style_pkg()`)

**PR Description should include:**
- Summary of changes and motivation
- Links to relevant issues
- Breaking changes (if any)
- Example usage for new features

## Package Architecture

### File Organization

```
R/
├── data-schemas.R      # Schema definitions and validation
├── design-constructors.R  # Survey design object creation
├── estimators.R        # Core estimation functions
├── legacy-*.R          # Legacy API compatibility
└── utils.R             # Internal helper functions
```

### Naming Conventions

- **Design functions:** `design_*()`
- **Estimation functions:** `estimate_*()`  
- **Validation functions:** `validate_*()`
- **Utility functions:** `calculate_*()`, `create_*()`

### Dependencies

**Core dependencies** (keep minimal):
- `survey` - design objects and estimation
- `dplyr`, `tidyr` - data manipulation
- `rlang`, `vctrs` - programming tools

**Suggested dependencies** (for specific features):
- `cli` - user messaging
- `lifecycle` - deprecation management

## Getting Help

- **GitHub Issues:** Bug reports and feature requests
- **GitHub Discussions:** Questions and community support
- **Code Review:** All maintainers provide feedback on PRs

## Recognition

Contributors are recognized in:
- Package DESCRIPTION file
- NEWS.md release notes  
- Annual contributor acknowledgments

Thank you for contributing to tidycreel!