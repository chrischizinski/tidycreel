# Coding Conventions

**Analysis Date:** 2026-01-27

## Naming Patterns

**Files:**
- R source files: lowercase with hyphens separating logical units: `est-cpue.R`, `qa-check-effort.R`, `utils-validate.R`
- Test files: `test-{feature}.R` pattern, e.g., `test-est-cpue-roving.R`, `test-utils-validate.R`
- Helper files: `helper-{purpose}.R`, e.g., `helper-testdata.R`

**Functions:**
- Public functions: snake_case, prefixed with domain context: `est_cpue()`, `qa_checks()`, `tc_require_cols()`
- Internal/utility functions: snake_case with `tc_` prefix for tidycreel utilities: `tc_interview_svy()`, `tc_group_warn()`, `tc_diag_drop()`
- Private helper functions: snake_case with leading dot: `.qa_summarize_check()`, or marked with `@keywords internal` and `@noRd` roxygen tags
- Abbreviations in functions: keep readable, e.g., `est_cpue_roving()`, `qa_check_effort()`

**Variables:**
- Snake_case for local variables and parameters: `response_col`, `min_trip_hours`, `conf_level`, `n_replicates`
- Dataframe column names: snake_case: `interview_id`, `catch_total`, `hours_fished`, `target_species`
- Constants: UPPER_SNAKE_CASE (rare, typically used with explicit declarations)

**Types/Classes:**
- Custom S3 classes: snake_case: `variance_decomp`, `survey_design_info`, `variance_enhanced`
- Class naming: simple descriptive names, used internally for `expect_s3_class()` in tests

## Code Style

**Formatting:**
- Tool: EditorConfig (`.editorconfig` enforced)
- Indentation: 2 spaces (R, Rmd, markdown, YAML)
- Line endings: LF (Unix style)
- Trailing whitespace: removed
- Final newline: required on all files

**Linting:**
- Tool: lintr (configured via `.lintr` file)
- Exclusions: `data-raw/`, `inst/extdata`
- Standard R style conventions applied

**Pre-commit hooks:**
- Trailing whitespace check
- End-of-file fixer
- Excludes: `renv/`, `.lintr` file

## Import Organization

**Order:**
1. Standard R packages (if needed): `library(tibble)`, `library(stats)`
2. Domain packages from Imports: `survey`, `dplyr`, `tidyr`, `cli`
3. Conditional imports via `requireNamespace()` for optional features

**Path Aliases:**
- Not applicable (R package, not TypeScript/JavaScript)
- Use relative paths in `@examples` via `system.file()`: `system.file("extdata", "toy_interviews.csv", package = "tidycreel")`

**Roxygen Documentation:**
- All exported functions use roxygen2 comment blocks (`#'`)
- Located directly above function definition
- Standard tags: `@param`, `@return`, `@examples`, `@export`, `@seealso`, `@details`
- Internal functions: `@keywords internal`, `@noRd` (no Rd file generated)
- Markdown support enabled in DESCRIPTION: `Roxygen: list(markdown = TRUE)`

## Error Handling

**Patterns:**
- Primary: `cli::cli_abort()` for errors with formatted messages
- Secondary: `stop()` for simple cases (rare)
- Structure uses cli message formatting:
  ```r
  cli::cli_abort(c(
    "x" = "Error description",
    "i" = "Additional information"
  ))
  ```
- Validation messages use descriptive context parameter: `tc_abort_missing_cols(df, cols, context = "est_cpue")`

**Warnings:**
- Primary: `cli::cli_warn()` for formatted warnings
- Secondary: `warning(..., call. = FALSE)` for simpler cases
- Example: `cli::cli_warn(c("!" = "Message", "i" = "Detail"))`

**Validation order:**
1. Immediate null/missing input checks
2. Column existence validation: `tc_require_cols()` or `tc_abort_missing_cols()`
3. Value range validation: custom checks or utility functions like `tc_clamp01()`
4. Design/structure validation: for survey objects

## Logging

**Framework:** `cli` package (not base `message()` or `cat()`)

**Patterns:**
- Informational: `cli::cli_alert_info()` - informational messages with bullet
- Headers: `cli::cli_h1()` for major section headers
- Text: `cli::cli_text()` for plain text
- Warnings: `cli::cli_warn()` - warning alerts
- Errors: `cli::cli_abort()` - error messages with context

**When to log:**
- Starting major operations: `cli::cli_h1("Running Quality Assurance Checks")`
- Long-running computations: checkpoint messages
- Data quality issues: warnings before dropping rows or applying corrections
- Processing status: `cli::cli_alert_info()` for intermediate steps

## Comments

**When to Comment:**
- Algorithm explanations for complex statistical methods (e.g., Pollock correction, variance decomposition)
- Non-obvious branching logic: `if (mode == "auto") { ... }`
- Workarounds or temporary fixes: flag with `# TODO` or `# FIXME`
- Section markers: `# ── Section Name ──` for readability in long functions

**JSDoc/TSDoc (Roxygen in R):**
- Required for all exported functions (marked `@export`)
- Detailed `@details` section for complex behavior
- `@examples` section must be runnable (use `\dontrun{}` if requires external data)
- Cross-references with `@seealso [function_name()]` or `\code{\link{function_name}}`
- Parameter descriptions use inline formatting: `\code{}` for code, `.arg` in cli messages

## Function Design

**Size:**
- Target < 50 lines for single-responsibility functions
- Longer functions allowed if clearly structured with section comments (e.g., `# ── Validation ──`)

**Parameters:**
- Accept data objects first: `function(design, by, response, ...)`
- Use named arguments with meaningful defaults
- Required parameters without defaults appear before optional ones
- Defaults: meaningful and documented, e.g., `conf_level = 0.95`, `method = c("survey", "bootstrap")` with `match.arg()` for validation

**Return Values:**
- Tibbles preferred over data.frames for results: `tibble::tibble(...)`
- Lists for complex results with multiple components
- Invisible returns for side-effect functions: `invisible(TRUE)`
- Structure documented in `@return` roxygen section with named list descriptions

**match.arg() pattern:**
Used for character vector parameters to enforce allowed values:
```r
function(design, mode = c("auto", "ratio_of_means", "mean_of_ratios")) {
  mode <- match.arg(mode)
  # mode is now validated
}
```

## Module Design

**Exports:**
- All user-facing functions explicitly marked with `@export`
- Generated via roxygen2 → NAMESPACE file
- Internal functions use `@keywords internal` and `@noRd`

**Barrel Files:**
- Not applicable (R packages use NAMESPACE for exports, not barrel files)
- Related functions organized in single .R files by feature domain

**File Organization:**
- Core estimators: `est-cpue.R`, `est-cpue-roving.R`, `est-effort-*.R`, `est-total-harvest.R`
- Quality assurance: `qa-checks.R`, `qa-check-*.R` (separate files for individual checks)
- Utilities: `utils-validate.R`, `utils-time.R`, `utils-ops.R`
- Data documentation: `data.R` (roxygen `@format` for all datasets)

---

*Convention analysis: 2026-01-27*
