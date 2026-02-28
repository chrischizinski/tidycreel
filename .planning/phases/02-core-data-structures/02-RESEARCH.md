# Phase 2: Core Data Structures - Research

**Researched:** 2026-02-01
**Domain:** R S3 class design, tidy evaluation / tidyselect, progressive validation, cli-formatted print methods
**Confidence:** HIGH

## Summary

This phase implements three S3 classes (`creel_design`, `creel_estimates`, `creel_validation`) with print/summary methods, and a user-facing `creel_design()` constructor that accepts calendar data with tidy selectors for column specification. The standard approach uses the tidyverse constructor/validator/helper pattern from Advanced R, `tidyselect::eval_select()` for column selection, `checkmate` for validation with `cli::cli_abort()` for error messages, and `cli_format_method()` for rich print output.

The key architectural insight is that `creel_design()` acts as the entry point to the entire analysis pipeline. It receives a calendar data frame and uses tidy selectors to identify which columns serve as the date, strata, and site variables -- rather than requiring fixed column names. This is the "design-centric API" principle from PROJECT.md. The existing `validate_calendar_schema()` from Phase 1 checks structural validity (has a Date column, has character columns), while Phase 2 adds column-role validation via tidy selectors (the user-specified date column is actually a Date, the strata columns are character/factor, etc.).

The `creel_estimates` class is a container that will be returned by `estimate_effort()` in Phase 4. In Phase 2 we only define the class structure and its print method -- no estimation logic yet. Similarly, `creel_validation` is a lightweight container for validation results, supporting the progressive validation architecture.

**Primary recommendation:** Use the constructor/validator/helper pattern for all S3 classes. Use `tidyselect::eval_select()` to resolve column roles from tidy selectors. Use `cli::cli_format_method()` for all print methods. Add `tidyselect` and `vctrs` to Imports. Follow TDD pattern established in Phase 1.

## Standard Stack

The established libraries/tools for this domain:

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| tidyselect | >= 1.2.0 | Column selection with tidy syntax | Official backend for all tidyverse selection; `eval_select()` is the standard API |
| rlang | >= 1.1.0 | Tidy evaluation primitives | Already in Imports; provides `enquo()`, `expr()`, `caller_env()` for defusing expressions |
| checkmate | >= 2.3.0 | Fast argument validation | Already in Imports; `makeAssertCollection()` pattern established in Phase 1 |
| cli | >= 3.6.0 | Formatted output and error messages | Already in Imports; `cli_format_method()` for print methods, `cli_abort()` for errors |
| vctrs | >= 0.6.0 | Type-stable operations, class infrastructure | Used by tidyselect internally; provides `vec_assert()`, `new_data_frame()`, useful for class construction |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| tibble | >= 3.2.0 | Enhanced data frames | For `creel_estimates` result structure; tibbles print better |
| pillar | >= 1.9.0 | Column formatting | Dependency of tibble; provides formatting primitives |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| tidyselect | Manual column name matching | tidyselect gives users familiar syntax (starts_with, everything, etc.) -- manual matching limits flexibility |
| S3 classes | S7 (new OOP) | S7 is experimental (CRAN Nov 2025); S3 is battle-tested for R packages and matches survey package patterns |
| S3 classes | R6 | R6 is reference-semantics; S3 is value-semantics which matches R's functional style and the survey package |
| cli_format_method | Manual cat/paste | cli provides consistent theming, ANSI support, and semantic formatting; manual output is fragile |

**New dependencies for DESCRIPTION Imports:**
```r
# Add to Imports:
# tidyselect (>= 1.2.0)  -- for eval_select() tidy column specification
# vctrs                    -- peer dependency of tidyselect, useful for class ops
```

## Architecture Patterns

### Recommended File Structure for Phase 2

```
R/
├── creel-design.R          # creel_design S3 class: new_, validate_, creel_design()
├── creel-estimates.R       # creel_estimates S3 class: new_, print, format
├── creel-validation.R      # creel_validation S3 class: new_, print
├── validate-schemas.R      # (existing) structural schema validators
├── tidycreel-package.R     # (existing) package docs
tests/testthat/
├── test-creel-design.R     # Tests for creel_design constructor + methods
├── test-creel-estimates.R  # Tests for creel_estimates class + print
├── test-creel-validation.R # Tests for creel_validation class
├── test-validate-schemas.R # (existing) schema validation tests
├── test-package.R          # (existing) placeholder test
```

### Pattern 1: Constructor / Validator / Helper (S3 Class Pattern)

**What:** Three-function pattern for each S3 class: `new_*()` (low-level), `validate_*()` (correctness), `*()` (user-facing).
**When to use:** Every S3 class in tidycreel v2.
**Source:** Advanced R by Hadley Wickham (https://adv-r.hadley.nz/s3.html)

```r
# Low-level constructor -- creates structure, checks types only
# Internal: not exported, not documented
new_creel_design <- function(calendar,
                             date_col,
                             strata_cols,
                             site_col = NULL,
                             design_type = "instantaneous") {
  stopifnot(is.data.frame(calendar))
  stopifnot(is.character(date_col), length(date_col) == 1)
  stopifnot(is.character(strata_cols), length(strata_cols) >= 1)
  stopifnot(is.null(site_col) || (is.character(site_col) && length(site_col) == 1))
  stopifnot(is.character(design_type), length(design_type) == 1)

  structure(
    list(
      calendar    = calendar,
      date_col    = date_col,
      strata_cols = strata_cols,
      site_col    = site_col,
      design_type = design_type,
      counts      = NULL,        # populated by add_counts() in Phase 3
      survey      = NULL         # populated internally in Phase 3
    ),
    class = "creel_design"
  )
}

# Validator -- checks semantic correctness (Tier 1 validation)
# Internal: not exported
validate_creel_design <- function(x) {
  cal <- x$calendar

  # Tier 1: Date column is actually Date class
  if (!inherits(cal[[x$date_col]], "Date")) {
    cli::cli_abort(c(
      "Column {.var {x$date_col}} must be of class {.cls Date}.",
      "x" = "Column {.var {x$date_col}} is {.cls {class(cal[[x$date_col]])}}.",
      "i" = "Convert with {.code as.Date()}."
    ))
  }

  # Tier 1: Strata columns exist and are character/factor
 for (col in x$strata_cols) {
    if (!is.character(cal[[col]]) && !is.factor(cal[[col]])) {
      cli::cli_abort(c(
        "Strata column {.var {col}} must be character or factor.",
        "x" = "Column {.var {col}} is {.cls {class(cal[[col]])}}."
      ))
    }
  }

  # Tier 1: No NA in date column
  if (anyNA(cal[[x$date_col]])) {
    cli::cli_abort(c(
      "Column {.var {x$date_col}} must not contain {.val NA} values.",
      "i" = "Remove or impute missing dates before creating a design."
    ))
  }

  invisible(x)
}

# User-facing helper -- accepts tidy selectors, calls constructor + validator
#' @export
creel_design <- function(calendar,
                         date,
                         strata,
                         site = NULL,
                         design_type = "instantaneous") {
  # 1. Structural validation (Phase 1 validator)
  validate_calendar_schema(calendar)

  # 2. Resolve tidy selectors to column names
  date_loc <- tidyselect::eval_select(
    rlang::enquo(date),
    data = calendar,
    allow_rename = FALSE,
    allow_empty = FALSE,
    error_call = rlang::caller_env()
  )
  if (length(date_loc) != 1) {
    cli::cli_abort(
      "{.arg date} must select exactly one column, not {length(date_loc)}."
    )
  }
  date_col <- names(date_loc)

  strata_loc <- tidyselect::eval_select(
    rlang::enquo(strata),
    data = calendar,
    allow_rename = FALSE,
    allow_empty = FALSE,
    error_call = rlang::caller_env()
  )
  strata_cols <- names(strata_loc)

  site_col <- NULL
  site_quo <- rlang::enquo(site)
  if (!rlang::quo_is_null(site_quo)) {
    site_loc <- tidyselect::eval_select(
      site_quo,
      data = calendar,
      allow_rename = FALSE,
      allow_empty = FALSE,
      error_call = rlang::caller_env()
    )
    if (length(site_loc) != 1) {
      cli::cli_abort(
        "{.arg site} must select exactly one column, not {length(site_loc)}."
      )
    }
    site_col <- names(site_loc)
  }

  # 3. Construct and validate
  design <- new_creel_design(
    calendar    = calendar,
    date_col    = date_col,
    strata_cols = strata_cols,
    site_col    = site_col,
    design_type = design_type
  )
  validate_creel_design(design)
}
```

### Pattern 2: Print Method with cli_format_method()

**What:** Use `cli_format_method()` in `format.class()`, then `print.class()` calls `format()`.
**When to use:** All S3 print methods.
**Source:** https://cli.r-lib.org/reference/cli_format_method.html

```r
#' @export
format.creel_design <- function(x, ...) {
  cli::cli_format_method({
    cli::cli_h1("Creel Survey Design")
    cli::cli_text("Type: {.val {x$design_type}}")
    cli::cli_text("Date column: {.field {x$date_col}}")
    cli::cli_text("Strata: {.field {x$strata_cols}}")
    if (!is.null(x$site_col)) {
      cli::cli_text("Site column: {.field {x$site_col}}")
    }

    n_days <- nrow(x$calendar)
    date_range <- range(x$calendar[[x$date_col]])
    cli::cli_text("Calendar: {.val {n_days}} days ({date_range[1]} to {date_range[2]})")

    # Strata summary
    for (col in x$strata_cols) {
      levels <- unique(x$calendar[[col]])
      cli::cli_text("  {.field {col}}: {.val {length(levels)}} levels")
    }

    has_counts <- !is.null(x$counts)
    cli::cli_text("Counts: {.val {if (has_counts) 'attached' else 'none'}}")
  })
}

#' @export
print.creel_design <- function(x, ...) {
  cat(format(x, ...), sep = "\n")
  invisible(x)
}
```

### Pattern 3: creel_estimates Print Pattern

**What:** Formatted display of estimation results with point estimates, SEs, and CIs.
**When to use:** For the creel_estimates print method.

```r
#' @export
print.creel_estimates <- function(x, ...) {
  cli::cli_h1("Creel Survey Estimates")
  cli::cli_text("Method: {.val {x$method}}")
  cli::cli_text("Variance: {.val {x$variance_method}}")
  cli::cli_text("")
  # Print the estimates tibble
  print(x$estimates, n = Inf)
  invisible(x)
}
```

### Pattern 4: Tidy Selector Resolution

**What:** Use `tidyselect::eval_select()` with `rlang::enquo()` to resolve user-provided column specifications.
**When to use:** Every function parameter that accepts column names.
**Source:** https://tidyselect.r-lib.org/articles/tidyselect.html

```r
# For single column (date, site):
resolve_single_col <- function(expr, data, arg_name, error_call = rlang::caller_env()) {
  loc <- tidyselect::eval_select(
    expr,
    data = data,
    allow_rename = FALSE,
    allow_empty = FALSE,
    error_call = error_call
  )
  if (length(loc) != 1) {
    cli::cli_abort(
      "{.arg {arg_name}} must select exactly one column, not {length(loc)}.",
      call = error_call
    )
  }
  names(loc)
}

# For multiple columns (strata):
resolve_multi_cols <- function(expr, data, arg_name, error_call = rlang::caller_env()) {
  loc <- tidyselect::eval_select(
    expr,
    data = data,
    allow_rename = FALSE,
    allow_empty = FALSE,
    error_call = error_call
  )
  names(loc)
}
```

### Pattern 5: Progressive Validation (Tier 1 in Phase 2)

**What:** Tier 1 validation at design creation; Tier 2 at estimation (Phase 4); Tier 3 optional deep checks (future).
**When to use:** creel_design() performs Tier 1 checks; estimate_effort() performs Tier 2 checks.

```
Tier 1 (creel_design creation - THIS PHASE):
  - Calendar is a valid data frame with rows
  - Date column exists, is Date class, no NAs
  - Strata columns exist, are character/factor
  - Site column exists and is character/factor (if provided)
  - Fail fast with cli::cli_abort()

Tier 2 (estimation time - Phase 4):
  - Zero or negative count values (warn)
  - Sparse strata with < 3 observations (warn)
  - Singleton PSUs (warn)

Tier 3 (optional diagnostics - future):
  - Coverage gaps
  - Temporal balance
  - Design effect assessment
```

### Anti-Patterns to Avoid

- **Exposing new_creel_design() to users:** The low-level constructor skips validation. Only export `creel_design()`. Mark `new_creel_design()` with `@keywords internal` and `@noRd`.
- **Storing resolved column names as symbols/quosures:** Store as character strings. Quosures are for defusing user input; once resolved, work with strings internally.
- **Checking column names in Phase 1 validators:** Phase 1 `validate_calendar_schema()` checks structure only (has a Date column somewhere). Phase 2 `validate_creel_design()` checks the specific user-selected columns. Keep these concerns separate.
- **Coupling creel_estimates to estimation logic:** In Phase 2, only define the class structure and print method. The estimation logic belongs in Phase 4.
- **Using print() directly inside print method:** Always `cat(format(x), sep = "\n")` with `invisible(x)` return. This follows R conventions and makes the output testable via `format()`.
- **Forgetting S3method() registration:** Every print/format/summary method needs `@export` in roxygen and must produce `S3method(print, creel_design)` in NAMESPACE.

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Column selection from user input | Manual `match()` / `grep()` on names | `tidyselect::eval_select()` | Handles all tidy syntax: bare names, starts_with(), ranges, negation, etc. |
| Defusing user expressions | Manual `substitute()` / `match.call()` | `rlang::enquo()` | Proper quosure creation; handles environments correctly; standard in tidyverse |
| Argument validation | Manual `if (!is.data.frame(...)) stop(...)` chains | `checkmate::assert_data_frame()` | C-optimized, accumulates errors with `makeAssertCollection()`, clear messages |
| Formatted console output | Manual `cat()` / `paste()` / `sprintf()` | `cli::cli_format_method()` + `cli::cli_text()` | Themeable, ANSI-aware, semantic formatting ({.val}, {.field}, {.cls}) |
| Class type checking | Manual `is(x, "class")` / `class(x) == "..."` | `inherits(x, "creel_design")` | Standard R; works with inheritance; no need for `is()` from methods package |
| Print method return value | Forgetting invisible(x) | Always `invisible(x)` | R convention; allows `y <- print(x)` without unwanted output |

**Key insight:** The tidyverse ecosystem has solved the column-selection-from-user-input problem completely with tidyselect. Using `eval_select()` gives users the same syntax they already know from dplyr/tidyr, and the error messages are well-crafted. Do not attempt to build a custom column resolution system.

## Common Pitfalls

### Pitfall 1: tidyselect Requires Data at Call Time

**What goes wrong:** `eval_select()` evaluates the selection expression against actual data column names. If you try to defuse the expression and evaluate it later against different data, you may get unexpected results or errors.
**Why it happens:** Tidy selectors like `starts_with("day")` depend on the available column names at evaluation time. The expression doesn't carry the data with it.
**How to avoid:** Always resolve tidy selectors immediately in the user-facing function (`creel_design()`), and store the resolved character column names. Never store the quosure for later evaluation.
**Warning signs:** Errors like "Column `xyz` doesn't exist" when the column clearly exists in the original data but not in a transformed version.

### Pitfall 2: NAMESPACE S3method Registration

**What goes wrong:** Print method defined but not dispatched -- R falls back to `print.default()`.
**Why it happens:** Missing `@export` tag on the method, or roxygen2 generates `export(print.creel_design)` instead of `S3method(print, creel_design)`.
**How to avoid:** Use `@export` on every S3 method. roxygen2 >= 7.0 correctly generates `S3method()` directives when it detects the `generic.class` naming pattern. Verify by checking the NAMESPACE file after `devtools::document()`.
**Warning signs:** NAMESPACE shows `export(print.creel_design)` instead of `S3method(print, creel_design)`. Or `print(my_design)` shows a raw list instead of formatted output.

### Pitfall 3: enquo() Must Be Called in the User-Facing Function

**What goes wrong:** `enquo()` is called inside an internal helper function, capturing the helper's argument name instead of the user's expression.
**Why it happens:** `enquo()` defuses the expression in the calling frame. If you pass `date` to a helper and the helper calls `enquo(date)`, it captures the literal symbol `date`, not the user's original expression.
**How to avoid:** Always call `enquo()` (or use `{{ }}`) in the directly user-facing function. Pass the resulting quosure to internal helpers, not the bare argument.
**Warning signs:** Error messages refer to internal variable names instead of the user's column specification.

### Pitfall 4: NULL Default for Optional Tidy Selectors

**What goes wrong:** `enquo(site)` when `site = NULL` produces a quosure wrapping NULL, but `eval_select()` cannot evaluate it.
**Why it happens:** The default `NULL` value for optional parameters needs special handling in the tidy evaluation context.
**How to avoid:** Use `rlang::quo_is_null()` to check if the quosure wraps NULL before passing to `eval_select()`. See the `site` handling in Pattern 1 above.
**Warning signs:** Error: "Column NULL doesn't exist" when user omits optional argument.

### Pitfall 5: "No Visible Binding for Global Variable" with Tidy Eval

**What goes wrong:** R CMD check notes about column names used with tidy evaluation.
**Why it happens:** When using `.data$col` or bare column names in NSE contexts, R's static analysis flags them.
**How to avoid:** Since we resolve selectors via `eval_select()` and store results as strings, this is largely avoided. For any downstream dplyr operations, use `.data[[col_name]]` with the stored string, or add variables to `utils::globalVariables()` in a globals.R file.
**Warning signs:** R CMD check NOTE: "no visible binding for global variable 'column_name'"

### Pitfall 6: creel_estimates Structure Must Be Stable Across Phases

**What goes wrong:** The `creel_estimates` class structure defined in Phase 2 is incompatible with what `estimate_effort()` produces in Phase 4.
**Why it happens:** Defining the output structure before the estimation logic exists can lead to mismatches.
**How to avoid:** Define a minimal but extensible structure. Use a list with known slots (`estimates` tibble, `method`, `variance_method`, `design`) and `...` for future additions. The print method should only depend on the minimal slots. Document the expected structure.
**Warning signs:** Phase 4 has to restructure the class, breaking Phase 2 print/format methods.

## Code Examples

Verified patterns from official sources:

### Complete creel_design() User Interaction

```r
# Source: Pattern from tidyselect vignette + Advanced R S3 patterns
# User creates a design from calendar data with tidy selectors:

calendar <- data.frame(
  survey_date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03")),
  day_type = c("weekday", "weekend", "weekend"),
  season = c("summer", "summer", "summer"),
  lake = c("lake_a", "lake_a", "lake_b")
)

# Basic usage with bare column names:
design <- creel_design(
  calendar,
  date = survey_date,
  strata = c(day_type, season),
  site = lake
)

# tidyselect helpers work:
design2 <- creel_design(
  calendar,
  date = survey_date,
  strata = starts_with("day"),
  site = lake
)

# Print shows readable summary:
print(design)
# -- Creel Survey Design ---
# Type: instantaneous
# Date column: survey_date
# Strata: day_type, season
# Site column: lake
# Calendar: 3 days (2024-06-01 to 2024-06-03)
#   day_type: 2 levels
#   season: 1 level
# Counts: none
```

### Tier 1 Validation Fail-Fast Examples

```r
# Source: checkmate + cli patterns from Phase 1

# Missing column fails immediately:
bad_cal <- data.frame(x = 1:3, y = c("a", "b", "c"))
creel_design(bad_cal, date = x, strata = y)
# Error: Column `x` must be of class <Date>.
# x Column `x` is <integer>.
# i Convert with `as.Date()`.

# Invalid date column type:
bad_cal2 <- data.frame(
  date = c("2024-06-01", "2024-06-02"),  # character, not Date
  day_type = c("weekday", "weekend")
)
creel_design(bad_cal2, date = date, strata = day_type)
# Error: Column `date` must be of class <Date>.
# x Column `date` is <character>.
# i Convert with `as.Date()`.

# Non-existent column:
creel_design(calendar, date = nonexistent, strata = day_type)
# Error: Column `nonexistent` doesn't exist.
# (error from tidyselect::eval_select)
```

### creel_estimates Structure (Minimal for Phase 2)

```r
# Source: Designed to be compatible with Phase 4 estimate_effort() output

new_creel_estimates <- function(estimates,
                                method = "total",
                                variance_method = "taylor",
                                design = NULL,
                                conf_level = 0.95) {
  stopifnot(is.data.frame(estimates))
  stopifnot(is.character(method), length(method) == 1)
  stopifnot(is.character(variance_method), length(variance_method) == 1)
  stopifnot(is.numeric(conf_level), length(conf_level) == 1)

  structure(
    list(
      estimates       = estimates,
      method          = method,
      variance_method = variance_method,
      design          = design,
      conf_level      = conf_level
    ),
    class = "creel_estimates"
  )
}
```

### creel_validation Structure

```r
# Source: Custom design for progressive validation architecture

new_creel_validation <- function(results, tier, context) {
  stopifnot(is.data.frame(results))
  stopifnot(is.integer(tier) || is.numeric(tier))
  stopifnot(is.character(context), length(context) == 1)

  structure(
    list(
      results = results,  # tibble with columns: check, status, message
      tier    = as.integer(tier),
      context = context,
      passed  = all(results$status == "pass")
    ),
    class = "creel_validation"
  )
}
```

### testthat Test Pattern for S3 Classes

```r
# Source: testthat 3e patterns from Phase 1

test_that("creel_design() creates valid object with basic inputs", {
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02")),
    day_type = c("weekday", "weekend")
  )
  design <- creel_design(cal, date = date, strata = day_type)

  expect_s3_class(design, "creel_design")
  expect_equal(design$date_col, "date")
  expect_equal(design$strata_cols, "day_type")
  expect_null(design$site_col)
  expect_equal(design$design_type, "instantaneous")
})

test_that("creel_design() fails on non-Date column", {
  cal <- data.frame(
    date = c("2024-06-01", "2024-06-02"),
    day_type = c("weekday", "weekend")
  )
  expect_error(
    creel_design(cal, date = date, strata = day_type),
    class = "rlang_error"
  )
})

test_that("creel_design() accepts tidyselect helpers", {
  cal <- data.frame(
    date = as.Date(c("2024-06-01", "2024-06-02")),
    day_type = c("weekday", "weekend"),
    day_season = c("summer", "summer")
  )
  design <- creel_design(cal, date = date, strata = starts_with("day"))

  expect_equal(design$strata_cols, c("day_type", "day_season"))
})

test_that("print.creel_design() returns invisibly", {
  cal <- data.frame(
    date = as.Date("2024-06-01"),
    day_type = "weekday"
  )
  design <- creel_design(cal, date = date, strata = day_type)
  expect_invisible(print(design))
})

test_that("format.creel_design() returns character vector", {
  cal <- data.frame(
    date = as.Date("2024-06-01"),
    day_type = "weekday"
  )
  design <- creel_design(cal, date = date, strata = day_type)
  out <- format(design)
  expect_type(out, "character")
  expect_true(length(out) > 0)
})
```

### NAMESPACE Registration Pattern

```r
# Generated by roxygen2 from @export on each method:
# In NAMESPACE file (auto-generated, do not edit):
export(creel_design)
S3method(format, creel_design)
S3method(print, creel_design)
S3method(summary, creel_design)
S3method(print, creel_estimates)
S3method(format, creel_estimates)
S3method(print, creel_validation)
```

### DESCRIPTION Updates Required

```
Imports:
    checkmate,
    cli,
    rlang,
    tidyselect (>= 1.2.0)
```

Note: `vctrs` is pulled in by `tidyselect` as a dependency, so it does not need to be listed in Imports unless used directly.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `vars_select()` in tidyselect | `eval_select()` in tidyselect >= 1.0.0 | tidyselect 1.0.0 (2020) | `vars_select()` is soft-deprecated; `eval_select()` is the current API |
| `.data$col` in tidy selections | `all_of(var)` or `"col"` strings | tidyselect 1.1.2 (2022) | `.data` usage in selections is deprecated; use `all_of()` for programmatic access |
| Bare predicates in where() | `where(is.numeric)` wrapped | tidyselect 1.1.2 (2022) | Bare predicates (without `where()`) formally deprecated |
| S3 only | S7 available on CRAN | S7 0.2.0 (Nov 2025) | S7 is the future but experimental; S3 remains the standard for packages today |
| Manual cat() in print methods | `cli::cli_format_method()` | cli 3.0+ (2021) | Semantic formatting, theming, ANSI support; standard in tidyverse packages |

**Deprecated/outdated:**
- `tidyselect::vars_select()`: Replaced by `eval_select()` since tidyselect 1.0.0
- `.data$col` in selection contexts: Use `all_of(var)` instead (deprecated in tidyselect 1.1.2)
- `testthat::context()`: Removed in 3e; use file names
- `testthat::expect_is()`: Use `expect_s3_class()` instead

## Open Questions

Things that couldn't be fully resolved:

1. **Exact creel_estimates tibble columns**
   - What we know: The estimates tibble should contain point estimate, SE, CI low, CI high, sample size. Phase 4 defines `estimate_effort()` which will produce these.
   - What's unclear: Exact column names for the estimates tibble. Candidates: `estimate`, `se`, `ci_lower`, `ci_upper`, `n` -- or `total`, `std_error`, `conf_low`, `conf_high`, `n_obs`.
   - Recommendation: Define minimal structure with flexible column names. Use `estimate`, `se`, `ci_lower`, `ci_upper`, `n` as defaults. The print method should detect available columns rather than hardcode names. This can be refined in Phase 4.

2. **Should creel_design store the full calendar or just metadata?**
   - What we know: The survey bridge (Phase 3) needs access to the full calendar data to construct `svydesign`. The design-centric API means everything flows through `creel_design`.
   - What's unclear: Whether to store the full calendar data frame or just a reference/summary.
   - Recommendation: Store the full calendar data frame. It's needed for Phase 3 (`add_counts()` joins on it), and typical creel survey calendars are small (100-365 rows). Memory is not a concern.

3. **summary.creel_design vs. print.creel_design differentiation**
   - What we know: R convention is that `print()` is brief and `summary()` is detailed.
   - What's unclear: What summary() should show beyond what print() shows.
   - Recommendation: `print()` shows the header info (type, columns, date range, strata level counts). `summary()` adds tabular breakdown of strata combinations (cross-tabulation of strata columns, counts per combination). Keep `summary()` simple in Phase 2 and extend in later phases.

4. **Whether tidyselect requires adding to Suggests or Imports**
   - What we know: `creel_design()` always uses tidyselect for column resolution. It's not optional.
   - What's unclear: None -- this is clearly Imports.
   - Recommendation: Add `tidyselect (>= 1.2.0)` to Imports. The `>= 1.2.0` pin ensures proper `error_call` support and the current `eval_select()` API.

## Sources

### Primary (HIGH confidence)

- **Advanced R - S3 Classes** (https://adv-r.hadley.nz/s3.html) - Constructor/validator/helper pattern, S3 method registration, best practices
- **tidyselect implementing interfaces vignette** (https://tidyselect.r-lib.org/articles/tidyselect.html) - `eval_select()` API, patterns for package developers
- **tidyselect eval_select reference** (https://tidyselect.r-lib.org/reference/eval_select.html) - Full function signature, parameters, return value
- **cli cli_format_method reference** (https://cli.r-lib.org/reference/cli_format_method.html) - S3 format/print method pattern with cli
- **rlang tidy evaluation programming** (https://rlang.r-lib.org/reference/topic-data-mask-programming.html) - enquo(), embrace operator, bridge patterns
- **checkmate CRAN documentation** (https://mllg.github.io/checkmate/) - makeAssertCollection(), assertion functions
- **tidyselect CRAN package** (https://cran.r-project.org/package=tidyselect) - Version 1.2.1, published 2024-03-11

### Secondary (MEDIUM confidence)

- **R survey package svydesign** (https://r-survey.r-forge.r-project.org/survey/html/svydesign.html) - S3 class patterns used by the survey package (our downstream dependency)
- **tidyselect changelog** (https://tidyselect.r-lib.org/news/index.html) - API evolution, deprecation notices
- **S7 package on CRAN** (https://cran.r-project.org/web/packages/S7/S7.pdf) - Next-generation OOP; confirmed S3 is still the recommended approach for R packages today

### Tertiary (LOW confidence)

- **S7 future status** - Web search indicates S7 is experimental as of late 2025; long-term goal to merge into base R. Using S3 is the conservative, safe choice for production R packages.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - tidyselect, rlang, cli all verified via official documentation; patterns well-established
- Architecture: HIGH - Constructor/validator/helper pattern from authoritative source (Advanced R); tidyselect integration pattern from official vignette
- Pitfalls: HIGH - tidyselect gotchas documented in official changelog; S3 method registration issues well-known
- Code examples: HIGH - All patterns verified against official documentation and API references

**Research date:** 2026-02-01
**Valid until:** 2026-03-03 (30 days; tidyselect and rlang are stable, unlikely to change)
