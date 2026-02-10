# Technology Stack

**Analysis Date:** 2026-01-27

## Languages

**Primary:**
- R 4.1.0+ - Complete package implementation
- R 4.5.1 - Development environment (locked in `renv.lock`)

**Build/Documentation:**
- Markdown - Documentation and vignettes (roxygen2 markdown support enabled)
- YAML - Configuration (GitHub Actions workflows, pre-commit, pkgdown)
- Shell - Utility scripts for checks and cleanup

## Runtime

**Environment:**
- R (R Core Team) - Statistical computing
- Posit Package Manager - CRAN repository (`https://packagemanager.posit.co/cran/latest`)

**Package Manager:**
- renv - Dependency lock and management
- Lockfile: `renv.lock` (present, locked to R 4.5.1)

## Frameworks

**Core Statistical:**
- `survey` - Survey design and analysis framework
  - Implements stratified sampling, design effects, variance estimation
  - Primary for `svydesign`, `svrepdesign` objects
  - Used in `R/design-aerial.R`, `R/est-effort-*.R`, `R/variance-*.R`

**Data Manipulation:**
- `dplyr` - Data frame manipulation (pipe-friendly)
  - Uses `%>%` operator, group_by, summarise, mutate, select
- `tidyr` - Tidy data reshaping
- `tibble` - Enhanced data frames
- `stringr` - String manipulation

**Time Handling:**
- `lubridate` - Date and time parsing, arithmetic

**Visualization:**
- `ggplot2` - Grammar of graphics visualization
- `plotly` - Interactive plots

**Mixed Effects Modeling:**
- `lme4` - Linear mixed-effects models (variance decomposition support)

**CLI/Messaging:**
- `cli` - Formatted terminal output
  - Used for `cli_abort()`, `cli_warn()`, `cli_inform()`
  - Integrated throughout validation and error handling

## Key Dependencies

**Critical - Core Functionality:**
- `survey` [inherited from CRAN] - Essential for design-based inference
- `dplyr` [inherited from CRAN] - Data manipulation foundation
- `tibble` [inherited from CRAN] - Data structures
- `cli` [inherited from CRAN] - Error/warning messaging

**Statistical Methods:**
- `lme4` [inherited from CRAN] - Variance decomposition (mixed models)
- `lubridate` [inherited from CRAN] - Temporal data handling

**Visualization:**
- `ggplot2` [inherited from CRAN] - Primary plotting framework
- `plotly` [inherited from CRAN] - Interactive plots (optional enhancement)

**Development/Testing (Suggests):**
- `testthat` >= 3.0.0 - Testing framework (edition 3)
- `covr` - Code coverage reporting
- `knitr` - Dynamic document generation (vignettes)
- `rmarkdown` - R markdown documents
- `pkgdown` - Package website generation
- `bench` - Performance benchmarking
- `gt`, `flextable` - Table formatting for reports
- `qs` - Fast serialization
- `future`, `furrr` - Parallel processing capabilities
- `data.table` - Alternative data structure (optional)
- `DBI` - Database interface abstraction
- `targets` - Pipeline/workflow management
- `lifecycle` - Lifecycle management for functions
- `readr` - CSV/file reading
- `purrr` - Functional programming utilities
- `janitor` - Data cleaning utilities
- `rlang` - Low-level R programming
- `vctrs` - Vector classes

## Configuration

**Environment:**
- No `.env` files or environment variable dependencies detected
- Configuration via R package options and function parameters
- Github workflows use `GITHUB_TOKEN` for authenticated access (standard)

**Build Configuration:**
- `DESCRIPTION` - Package metadata and dependencies
- `NAMESPACE` - Roxygen-generated exports
- `tidycreel.Rproj` - RStudio project file
- `_pkgdown.yml` - Documentation site structure
- `.Rbuildignore` - Build exclusion rules
- `renv.lock` - Locked dependency versions

**Code Quality:**
- `.pre-commit-config.yaml` - Pre-commit hooks (lintr, styler)
- `.codacy/codacy.yaml` - Code quality checks
- `codecov.yml` - Coverage configuration (1% threshold, informational)

**Documentation:**
- Roxygen2 7.3.2 - Documentation generation
  - `@importFrom` statements auto-generate NAMESPACE
  - Markdown support enabled in DESCRIPTION

## Platform Requirements

**Development:**
- OS: Ubuntu (Linux), macOS (Intel & Apple Silicon), Windows
- R >= 4.1.0 (package dependency)
- System libraries (macOS):
  - `gettext` - Internationalization
  - `harfbuzz`, `fribidi` - Text rendering
  - Configured via GitHub Actions workflow for CI
- RStudio compatible (optional but recommended)

**Testing:**
- CI/CD: GitHub Actions
  - Matrix testing: ubuntu-latest, macos-latest, windows-latest
  - R version: release channel
  - Parallel system dependency installation

**Production:**
- R >= 4.1.0 runtime
- Package installation via `install.packages()` or devtools
- No system service dependencies

## CI/CD & Build Tools

**Continuous Integration:**
- GitHub Actions (`.github/workflows/`)
  - `r-check.yml` - R CMD check on all platforms (on push/PR)
  - `test-coverage.yml` - codecov integration (on main/master push)
  - `lintr.yaml` - Static linting checks
  - `pkgdown.yaml` - Documentation site deployment
  - `roo-todo-sync.yml` - TODO tracking integration
  - `release.yaml` - Release workflow

**Build Checks:**
- R CMD check (strict: `error_on='warning'`)
- No manual PDF vignettes
- CRAN incoming checks enabled
- Timeout: R_DEFAULT_INTERNET_TIMEOUT = 20 seconds

**Linting/Formatting:**
- `lintr` - Static code analysis
- `styler` - Code formatting enforcement
- Pre-commit hooks configured (`.pre-commit-config.yaml`)

**Testing:**
- `testthat` edition 3 - Unit testing framework
- `covr::codecov()` - Coverage reporting to codecov.io
- Coverage thresholds: 1% minimum (informational)

**Documentation:**
- `pkgdown` - Generates HTML documentation site
- `knitr` - Vignette rendering
- Roxygen2 - Automatic man page generation

---

*Stack analysis: 2026-01-27*
