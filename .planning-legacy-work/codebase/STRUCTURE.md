# Codebase Structure

**Analysis Date:** 2026-01-27

## Directory Layout

```
tidycreel/
├── R/                          # R package source code (41 .R files)
│   ├── design-*.R              # Survey design constructors
│   ├── est-*.R                 # Estimator functions
│   ├── qa-check-*.R            # QA check functions
│   ├── variance-*.R            # Variance computation engines
│   ├── utils-*.R               # Utility functions
│   ├── data-schemas.R          # Data validation schemas
│   ├── data.R                  # Example datasets
│   ├── plots.R                 # Visualization functions
│   ├── globals.R               # Global variable declarations
│   └── tidycreel-package.R     # Package initialization
│
├── tests/testthat/             # Test suite (20+ test files)
│   ├── test-*.R                # Unit/integration tests
│   └── helper-testdata.R       # Test data generators
│
├── vignettes/                  # User documentation and tutorials
│   ├── getting-started.Rmd     # Entry point tutorial
│   ├── effort-*.Rmd            # Effort estimation guides
│   ├── cpue_catch.Rmd          # CPUE and catch guides
│   ├── roving-surveys.Rmd      # Roving survey tutorial
│   ├── aerial.Rmd              # Aerial survey tutorial
│   └── ratio-estimators-guide.Rmd  # Advanced ratio estimators
│
├── inst/extdata/               # External data files
│   ├── toy_*.csv               # Minimal example datasets
│   ├── example_*.csv           # Full example datasets
│   └── generate_*.R            # Data generation scripts
│
├── data/                       # Compiled R datasets (.rda)
│   └── [compiled data objects]
│
├── data-raw/                   # Raw data and generation scripts
│   └── [scripts to generate data/]
│
├── man/                        # Generated documentation (.Rd files)
│   └── figures/                # Package logo and graphics
│
├── docs/                       # Built package website
│   └── [pkgdown generated site]
│
├── .github/                    # GitHub configuration
│   ├── workflows/              # CI/CD pipelines
│   └── ISSUE_TEMPLATE/         # Issue templates
│
├── scripts/                    # Development and maintenance scripts
│   ├── check-architecture.sh   # Architecture validation script
│   ├── cleanup-patches.sh      # Cleanup maintenance script
│   └── pre-commit-hook         # Git pre-commit hook
│
├── DESCRIPTION                 # Package metadata
├── NAMESPACE                   # Exported symbols
├── _pkgdown.yml                # Website configuration
├── .Rbuildignore               # Build exclusions
├── .Rprofile                   # R startup configuration
├── .lintr                      # Linting configuration
└── ARCHITECTURAL_STANDARDS.md  # Architecture rules and standards

```

## Directory Purposes

**R/** (Primary source code):
- Purpose: Contains all executable R code for the tidycreel package
- Contains: Function definitions, S3 methods, internal utilities
- Key files:
  - Design constructors: `design-constructors.R`, `design-aerial.R`, `design_busroute.R`
  - Estimators: `est-effort-*.R`, `est-cpue*.R`, `est-catch.R`, `est-total-harvest.R`
  - QA checks: `qa-checks.R`, `qa-check-*.R` (individual check modules)
  - Variance: `variance-engine.R`, `variance-decomposition*.R`

**tests/testthat/** (Test suite):
- Purpose: Unit and integration tests verifying function behavior
- Contains: Test files matching source files (test-*.R pattern)
- Key files:
  - `helper-testdata.R`: Functions to generate test data
  - `test-*.R`: Individual test files covering specific features
  - Test file naming matches source: `test-est-effort-instantaneous.R` tests `est-effort-instantaneous.R`

**vignettes/** (User documentation):
- Purpose: Long-form guides and tutorials for end users
- Contains: RMarkdown files (.Rmd) that render to HTML
- Key files:
  - `getting-started.Rmd`: Entry point, basic workflow example
  - Design-specific vignettes: `effort_design_based.Rmd`, `effort_aerial.Rmd`, `roving-surveys.Rmd`
  - Topic vignettes: `cpue_catch.Rmd`, `ratio-estimators-guide.Rmd`

**inst/extdata/** (Example data):
- Purpose: Provide example datasets for vignettes and user reference
- Contains: CSV files and generation scripts
- Key files:
  - Toy datasets (minimal): `toy_calendar.csv`, `toy_counts.csv`, `toy_interviews.csv`, `toy_catch.csv`
  - Example datasets (realistic): `example_calendar.csv`, `example_counts_instantaneous.csv`, `example_counts_progressive.csv`, `example_interviews.csv`
  - Generation scripts: `generate_realistic_data.R`, `generate_additional_data.R`

**data/** (Compiled datasets):
- Purpose: Provide example datasets as lazy-loaded R objects (.rda)
- Contains: Compiled RData objects referenced via `data()` calls
- Generated from: `data-raw/` scripts via roxygen2 processing

**data-raw/** (Data source):
- Purpose: Scripts and raw files for generating datasets
- Contains: R scripts that produce data/ objects
- Not included in: Built package (excluded in .Rbuildignore)

**man/** (Documentation):
- Purpose: Generated R help files from roxygen2 comments
- Contains: .Rd files (one per exported function/object)
- Generated from: roxygen2 comments in R/ source files
- Never manually edited: Always regenerated from source

**docs/** (Website):
- Purpose: Built pkgdown website for package documentation
- Contains: HTML, CSS, generated from vignettes and man pages
- Generated by: `pkgdown::build_site()`
- Not committed: Typically excluded from git

**scripts/** (Development utilities):
- Purpose: Maintenance and validation scripts
- Key scripts:
  - `check-architecture.sh`: Validates architecture compliance
  - `cleanup-patches.sh`: Removes temporary/patch files
  - `pre-commit-hook`: Git hook for pre-commit validation

## Key File Locations

**Entry Points:**
- Main package initialization: `R/tidycreel-package.R` (package metadata, global variable declarations)
- Getting started guide: `vignettes/getting-started.Rmd` (directs users to appropriate workflows)

**Configuration:**
- Package metadata: `DESCRIPTION` (version, dependencies, authors)
- Namespace/exports: `NAMESPACE` (generated from `@export` roxygen comments)
- Build rules: `.Rbuildignore` (excludes non-package files)
- Website config: `_pkgdown.yml` (defines navigation, styling)
- Architecture standards: `ARCHITECTURAL_STANDARDS.md` (design rules for contributors)

**Core Logic:**

*Survey Design Construction:*
- `R/design-constructors.R`: Main constructors (`design_access()`, `as_day_svydesign()`)
- `R/design-aerial.R`: Aerial survey design (`design_aerial()`)
- `R/design_busroute.R`: Bus route survey design (`design_busroute()`)

*Effort Estimation (by survey method):*
- `R/est-effort-instantaneous.R`: Snapshot count method
- `R/est-effort-progressive.R`: Roving/pass-based method
- `R/est-effort-aerial.R`: Aerial survey method
- `R/est-effort-busroute.R`: Bus route survey method

*CPUE/Catch Estimation:*
- `R/est-cpue.R`: Main CPUE estimator
- `R/est-cpue-roving.R`: CPUE for roving surveys with length-bias correction
- `R/est-catch.R`: Catch/harvest estimation
- `R/aggregate-cpue.R`: Aggregation and standardization
- `R/est-total-harvest.R`: Total population harvest

*Variance Computation:*
- `R/variance-engine.R`: Core variance dispatcher (`tc_compute_variance()`)
- `R/variance-decomposition.R`: Main decomposition orchestrator
- `R/variance-decomposition-engine.R`: Decomposition algorithms
- `R/variance-decomposition-methods.R`: Method-specific implementations

*Quality Assurance:*
- `R/qa-checks.R`: Main QA orchestrator (`qa_checks()`)
- `R/qa-check-effort.R`: Party effort validation
- `R/qa-check-missing.R`: Missing data patterns
- `R/qa-check-outliers.R`: Statistical outlier detection
- `R/qa-check-spatial-coverage.R`: Geographic sampling validation
- `R/qa-check-species.R`: Species identification validation
- `R/qa-check-targeting.R`: Interview bias detection
- `R/qa-check-temporal.R`: Time coverage validation
- `R/qa-check-units.R`: Measurement unit consistency
- `R/qa-check-zeros.R`: Zero count validation

*Utilities:*
- `R/utils-survey.R`: Survey design extraction and manipulation
- `R/utils-validate.R`: Data schema validation
- `R/utils-time.R`: Date/time parsing and conversion
- `R/utils-ops.R`: Pipe operators and helpers
- `R/globals.R`: Global variable declarations for R CMD check

*Reporting:*
- `R/qc-report.R`: Report generation (`qc_report()`)
- `R/plots.R`: Visualization functions
- `R/survey-diagnostics.R`: Design diagnostics and summaries

*Data Schemas & Examples:*
- `R/data-schemas.R`: Data validation schemas, validation functions
- `R/data.R`: Documentation for example datasets

**Testing:**
- Test organization: One test file per source module (e.g., `tests/testthat/test-est-effort-instantaneous.R`)
- Test data generation: `tests/testthat/helper-testdata.R`
- Test configuration: `tests/testthat/_snaps/` (for snapshot testing, if used)

## Naming Conventions

**Files:**
- Source modules: lowercase with hyphens, functional grouping: `est-effort-instantaneous.R`, `qa-check-effort.R`, `variance-decomposition.R`
- Test files: `test-` prefix matching source: `test-est-effort-instantaneous.R`
- Utilities: `utils-` prefix for functional area: `utils-survey.R`, `utils-validate.R`, `utils-time.R`
- Vignettes: lowercase with hyphens: `getting-started.Rmd`, `effort_design_based.Rmd`, `roving-surveys.Rmd`
- Data files: `toy_` prefix for minimal examples, `example_` for realistic examples: `toy_counts.csv`, `example_interviews.csv`

**Functions:**
- Exported user functions: `verb_noun()` pattern in present tense: `est_effort()`, `est_cpue()`, `design_access()`, `as_day_svydesign()`, `qa_checks()`
- Deprecated functions: Still exported with immediate `cli::cli_abort()` directing to replacement: `estimate_effort()`, `estimate_harvest()` → `est_effort()`, `est_catch()`
- Internal utilities: `tc_` prefix for internal tidycreel functions: `tc_compute_variance()`, `tc_decompose_variance()`, `tc_interview_svy()`, `tc_extract_se()`
- Specific estimator methods: Dot notation for method dispatch: `est_effort.instantaneous()`, `est_effort.progressive()`, `est_effort.aerial()`
- S3 methods: Typical R convention: `print.creel_design()`, `summary.creel_design()`, `plot.creel_design()`

**Variables & Parameters:**
- Column names: lowercase with underscores: `catch_total`, `hours_fished`, `party_size`, `shift_block`, `stratum_id`
- Parameters: camelCase in function signatures: `confLevel`, `varianceMethod`, `decomposeVariance`, `designDiagnostics` (internal R convention, though camelCase less common in tidyverse)
- Grouping variables: descriptive, plural when aggregating: `by = c("location", "date", "shift_block")`

## Where to Add New Code

**New Effort Estimator (new survey method):**
- Primary code: Create `R/est-effort-{method}.R` with function `est_effort.{method}()`
- Pattern: Follow structure of `R/est-effort-instantaneous.R` or `R/est-effort-progressive.R`
- Must implement: Aggregation logic → survey design → `survey::svytotal()`/`survey::svyby()` → `tc_compute_variance()` for variance
- Tests: Create `tests/testthat/test-est-effort-{method}.R`
- Vignette: Add `vignettes/effort_{method}.Rmd` demonstrating the workflow
- Example data: Add sample data to `inst/extdata/example_{method}_counts.csv`

**New CPUE/Catch Estimator:**
- Primary code: Create `R/est-{type}.R` with function `est_{type}()`
- Pattern: Follow structure of `R/est-cpue.R` or `R/est-catch.R`
- Location: Alongside other est-* files in R/
- Tests: Create corresponding `tests/testthat/test-est-{type}.R`

**New QA Check:**
- Check function: Create `R/qa-check-{issue}.R` with function `check_{issue}()` (internal) + documented in main orchestrator
- Update orchestrator: Add check case to `qa_checks()` in `R/qa-checks.R`
- Tests: Add tests to `tests/testthat/test-qa-check-{issue}.R` or extend existing test file
- Documentation: Document expected columns and return format in roxygen comments

**New Utility Function:**
- Location: Add to appropriate `R/utils-{area}.R` file (survey, validate, time, ops)
- Pattern: Prefix with `tc_` if internal tidycreel function, no prefix if general helper
- Documentation: Roxygen comments with `@keywords internal` if not exported
- Tests: Add to `tests/testthat/` (can combine with existing test file for the utils module)

**New Example Dataset:**
- CSV file: Add to `inst/extdata/` with naming `toy_` (minimal) or `example_` (realistic)
- R dataset: Document in `R/data.R` with roxygen comments, roxygen2 generates compiled version
- Data-raw script: Add generation script to `data-raw/` if complex
- Reference: Use in vignettes with `read.csv(system.file("extdata", "toy_xxx.csv", package = "tidycreel"))`

**New Vignette:**
- Location: `vignettes/{topic}.Rmd`
- Pattern: Title, introduction, workflow steps with code examples, summary
- Link: Update `_pkgdown.yml` navbar section to include in website navigation
- Data: Use `inst/extdata/` example datasets; avoid large data in vignette files
- Build: `devtools::build_vignettes()` to regenerate HTML

## Special Directories

**R/** (Source code):
- Purpose: All executable R code for the package
- Generated: No, manually edited
- Committed: Yes, all .R files tracked in git
- Built-in functions: Use roxygen2 `@export` comments to control namespace

**tests/testthat/** (Test code):
- Purpose: Unit and integration tests for all functions
- Generated: No, manually written
- Committed: Yes, all test files tracked in git
- Configuration: Uses `testthat` edition 3 as specified in DESCRIPTION

**vignettes/** (Long-form documentation):
- Purpose: RMarkdown tutorials for end users
- Generated: HTML output generated during package build, not committed
- Committed: .Rmd source files committed; HTML output excluded
- Build: `devtools::build_vignettes()` or automatic during `R CMD build`

**man/** (Help files):
- Purpose: .Rd files for R help system
- Generated: Yes, from roxygen2 comments in R/ files
- Committed: No, regenerated from source
- Process: Never edit manually; use roxygen comments in R/ → `devtools::document()`

**inst/extdata/** (Package data):
- Purpose: CSV files and scripts for example data
- Generated: CSV files are manually created or generated by scripts
- Committed: Yes, data files committed; generation scripts committed
- Accessed: Via `system.file()` in vignettes and examples

**data/** (Compiled datasets):
- Purpose: Lazy-loaded .rda objects available via `data()`
- Generated: Yes, from data-raw/ scripts, processed by roxygen2
- Committed: No, regenerated from data-raw/
- Process: Define in data-raw/xxx.R with roxygen `@docType data` comment → roxygen processes → data/ populated

**data-raw/** (Data source scripts):
- Purpose: Scripts to generate data/ objects
- Generated: No, manually written
- Committed: No (excluded in .Rbuildignore)
- Usage: Run scripts with `devtools::load_all()` to populate data/

**docs/** (Website):
- Purpose: Built pkgdown website
- Generated: Yes, from vignettes and man/ files
- Committed: No, typically excluded from git
- Build: `pkgdown::build_site()` generates complete site

**.github/workflows/** (CI/CD):
- Purpose: GitHub Actions pipelines
- Generated: No, manually configured
- Committed: Yes, tracked in git
- Files: `*.yaml` workflows (check, build, release, etc.)

**.Rbuildignore** (Build exclusions):
- Purpose: Files to exclude from built package
- Includes: data-raw/, docs/, old_code/, scripts/, vignettes/.Rproj.user, etc.
- Never commit: Binary build artifacts (.tar.gz, .zip)

---

*Structure analysis: 2026-01-27*
