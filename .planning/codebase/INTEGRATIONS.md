# External Integrations

**Analysis Date:** 2026-01-27

## APIs & External Services

**No external APIs detected**
- This is a pure statistical analysis package with no external service dependencies
- All functionality is self-contained within R environment
- No third-party HTTP API calls found in codebase

## Data Storage

**Databases:**
- DBI (Database Interface) - Included in Suggests
  - Not currently used in production code
  - Available for future database integration
  - Connection: User-specified via DBI drivers (not pre-configured)
  - Potential use: Reading/writing creel survey data

**File Storage:**
- Local filesystem only
  - Package includes example data files in `inst/extdata/`:
    - `toy_interviews.csv` - Test interview data
    - `toy_counts.csv` - Test count data
    - `toy_catch.csv` - Test catch data
    - `toy_calendar.csv` - Test calendar/sampling plan
    - `example_interviews.csv` - Additional example data
    - `example_counts_*.csv` - Effort count examples (progressive, instantaneous, busroute, aerial)
    - `example_calendar.csv` - Detailed calendar example
    - `example_busroute_schedule.csv` - Bus route scheduling example
  - Data loaded via `system.file("extdata", "*.csv", package = "tidycreel")`
  - No cloud storage integration

**Caching:**
- None - Package operates on in-memory data objects
- Optional: `qs` (suggested) for fast serialization of R objects
  - Could be used by users for caching intermediate results
  - Not integrated into package functions

## Authentication & Identity

**Auth Provider:**
- None required - Package is a standalone statistical library
- GitHub token used only for CI/CD workflows (`GITHUB_TOKEN` in GitHub Actions)
  - Not exposed to users or package code

## Data Ingestion

**Input Formats:**
- CSV files (via user responsibility or `readr` in Suggests)
- R data frames / tibbles
- `survey::svydesign` objects (from `survey` package)
- Raw interview/catch/count/calendar tibbles

**Example Data Access:**
```R
# From inst/extdata
toy_interviews <- read.csv(system.file("extdata", "toy_interviews.csv", package = "tidycreel"))
toy_counts <- read.csv(system.file("extdata", "toy_counts.csv", package = "tidycreel"))
```

**Expected Data Structures:**
- Interview data: `interview_id`, `date`, `time_start`, `time_end`, `catch_*`, `hours_fished`, `party_size`, etc.
- Count data: `count_id`, `date`, `time`, `anglers_count`, `parties_count`, `location`, `mode`, etc.
- Calendar data: `date`, `target_sample`, `actual_sample`, strata columns (day_type, month, season, etc.)
- Catch data: Species details with catch counts

## Monitoring & Observability

**Error Tracking:**
- None - Package produces informative R errors and warnings
- Uses `cli` package for user-friendly error messages
  - Structured via `cli::cli_abort()`, `cli::cli_warn()`
  - Stack traces preserved in standard R error handling

**Logs:**
- Console output only
  - `cli::cli_inform()` for informational messages
  - Standard R warnings/errors
  - No persistent logging system
  - No debug logging framework

**Package Health:**
- codecov.io integration (`.github/workflows/test-coverage.yml`)
  - Automatic coverage reporting on main branch
  - 1% threshold (informational only)
  - No blocking coverage gates

## CI/CD & Deployment

**Hosting:**
- No deployment/hosting required - Package is distributed via CRAN
- GitHub repository: `https://github.com/chrischizinski/tidycreel`
- Installation: `install.packages("tidycreel")` from CRAN or `devtools::install_github("chrischizinski/tidycreel")`

**CI Pipeline:**
- GitHub Actions (`.github/workflows/`)
  - Build triggers: push and pull_request events
  - Test matrix: ubuntu-latest, macos-latest, windows-latest
  - R version: release channel
  - Artifact uploads on failure (check results)

**Documentation Deployment:**
- pkgdown site auto-deployed via GitHub Actions
- Host: GitHub Pages (URL in `_pkgdown.yml`)
- Trigger: Commits to main branch

**Release Workflow:**
- `release.yaml` workflow defined (specific release process)
- Likely coordinates with GitHub Releases

## Environment Configuration

**Required environment variables:**
- `GITHUB_TOKEN` - GitHub Actions (standard, auto-injected)
- `GITHUB_PAT` - GitHub Actions for package dependencies
- No user-facing environment variables
- No secrets management required for package use

**Package Options (Runtime Configuration):**
- Options system via `options()` not explicitly documented
- Configuration via function parameters and R objects
- Global variables suppressed via `globalVariables()` in `R/tidycreel-package.R`

## Webhooks & Callbacks

**Incoming Webhooks:**
- None - Package is stateless and library-only
- No server/API listening capability

**Outgoing Webhooks:**
- None - No external notification system
- GitHub integration limited to CI/CD context only

## Package-Specific Integrations

**Statistical Software Interfaces:**
- `survey::svydesign()` - Creates design objects for analysis
- `survey::svrepdesign()` - Replicate design support
- `survey` package internals:
  - `survey:::svyrecvar()` - Variance estimation (uses private API)
  - Access documented in function comments (e.g., `R/est-effort-progressive.R`)

**Testing Framework Integration:**
- `testthat::test_that()` - Unit test definition (edition 3)
- Helper functions in `tests/testthat/helper-testdata.R`
  - `create_test_interviews()` - Generates test interview tibbles
  - `create_test_counts()` - Generates test count tibbles
  - `create_test_calendar()` - Generates test calendar tibbles

**Build System Dependencies:**
- roxygen2 7.3.2 - Documentation and NAMESPACE generation
  - Markdown support enabled
  - Auto-generates export statements
  - Triggers on `devtools::document()` or `roxygen2::roxygenise()`

**Development Tools (Suggested):**
- `rmarkdown` - Vignette compilation
- `knitr` - Dynamic document generation
- `targets` - Workflow/pipeline orchestration (optional for users)
- `future` / `furrr` - Parallel execution (optional enhancement)

## Data Validation & Schemas

**Schema Validation:**
- `schema_test_runner()` - Test runner for data schema validation (exported)
- `data-schemas.R` - Schema definitions and validation utilities
- Validates required columns, data types, allowed values
- Location: `R/data-schemas.R`, `R/utils-validate.R`

**Validation Functions:**
- `validate_required_columns()` - Checks presence of columns
- `validate_allowed_values()` - Checks enum constraints
- `validate_interviews()`, `validate_counts()`, `validate_catch()` - Data-specific validators
- `tc_abort_missing_cols()` - Error on missing columns

---

*Integration audit: 2026-01-27*
