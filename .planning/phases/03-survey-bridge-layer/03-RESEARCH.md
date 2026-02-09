# Phase 3: Survey Bridge Layer - Research

**Researched:** 2026-02-08
**Domain:** Survey package integration, svydesign construction, stratified sampling
**Confidence:** HIGH

## Summary

Phase 3 bridges domain vocabulary (creel_design with counts) to statistical machinery (survey package's svydesign objects). The survey package (Thomas Lumley, CRAN) provides robust design-based inference for stratified, clustered sampling designs. This phase implements `add_counts()` to attach instantaneous count data, constructs internal svydesign objects with day-PSU stratified designs, and provides an escape hatch (`as_survey_design()`) for power users.

Key insight: The survey package handles complex designs well but requires careful specification of PSU nesting, stratification variables, and weights. The "lonely PSU" problem (single PSU in a stratum) is a common pitfall requiring detection and handling strategies.

**Primary recommendation:** Use eager construction of svydesign in `add_counts()` to fail fast on design errors. Store the constructed survey object in the creel_design for later use by estimation functions. Follow R S3 best practices: separate low-level constructor (`new_creel_design`), validator, and user-facing helper patterns established in Phase 2.

## User Constraints (from CONTEXT.md)

### Locked Decisions

**add_counts() interface design:**
- **Immutability**: Returns new creel_design object (follows tidyverse patterns) — `design2 <- add_counts(design, counts)`
- **Duplicate handling**: Error if counts already attached — forces explicit workflow, prevents silent data loss
- **Argument style**: Both positional and named allowed — `add_counts(design, counts)` or `add_counts(design, counts = my_data)`
- **Error messages**: Detailed format (what's wrong + why + how to fix) — helps learning users understand validation failures

**Escape hatch design (as_survey_design):**
- **Visibility**: Exported (user-facing) — power users can access, documented, enables advanced workflows with survey package
- **User guidance**: Warning on first use — once-per-session reminder this is advanced feature, not typical workflow
- **Mutation prevention**: Return a copy — modifications to extracted svydesign don't affect creel_design internals
- **Missing counts behavior**: Error with clear message if called before add_counts() — explicit guidance rather than silent NULL

**Validation integration (Tier 1 vs Tier 2):**
- **Validation boundaries**: Structural validation in add_counts() (schema, types, required columns), statistical validation in estimate_effort() (sparse strata, distributions)
- **Tier 1 failure handling**: Error by default, with allow_invalid flag to convert to warnings — safe by default, power users can opt into flexibility
- **Validation storage**: Store validation results in creel_design object for inspection — helpful for debugging even if adds to object size
- **Schema validator integration**: Separate validators called independently — validate_count_schema() parallel to validate_calendar_schema() from Phase 1

### Claude's Discretion

**Construction timing**: Choose eager vs lazy construction based on R patterns and error handling philosophy

**PSU identification**: User specifies PSU column in creel_design or add_counts() — flexible to support different sampling designs rather than hardcoding "day = PSU"

**survey package dependency**: Determine appropriate phase for adding survey package to DESCRIPTION

**Stratification mapping**: Use creel strata directly — pass strata columns from creel_design to svydesign strata argument as straightforward mapping

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| survey | 4.4+ | Design-based inference for complex surveys | Authoritative package by Thomas Lumley, CRAN standard since 2004, handles stratified/clustered designs |
| cli | Current | User-facing messages and errors | Already in DESCRIPTION, used in Phase 1/2 for error messages |
| rlang | Current | Warning control (.frequency for once-per-session) | Already in DESCRIPTION, enables advanced warning patterns |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| checkmate | Current | Fast validation assertions | Already in DESCRIPTION, used for schema validation |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| survey | sampling package | sampling focuses on sample selection, not variance estimation post-survey |
| survey | srvyr (tidyverse wrapper) | srvyr is user-facing wrapper; survey package is needed for underlying svydesign objects |

**Installation:**
```bash
# survey package should be added to DESCRIPTION Imports section
# All other packages already present in Phase 1/2
```

**Note:** `survey` package should be added to DESCRIPTION during this phase since svydesign construction is core functionality.

## Architecture Patterns

### Recommended Project Structure
Current structure already established:
```
R/
├── creel-design.R           # add_counts() and as_survey_design() go here
├── validate-schemas.R       # validate_count_schema() already exists
├── creel-estimates.R        # Future estimation functions
└── creel-validation.R       # Validation results class
```

### Pattern 1: Immutable S3 Method with Copy-on-Modify

**What:** Methods return new objects rather than modifying in place

**When to use:** All user-facing creel_design modification functions (add_counts, future add_catches, etc.)

**Example:**
```r
# Source: Advanced R (Hadley Wickham) S3 chapter
# https://adv-r.hadley.nz/s3.html

add_counts <- function(design, counts, ...) {
  # Validate inputs
  if (!inherits(design, "creel_design")) {
    cli::cli_abort("{.arg design} must be a {.cls creel_design} object.")
  }

  # Error if counts already attached (user decision: prevent silent data loss)
  if (!is.null(design$counts)) {
    cli::cli_abort(c(
      "Counts already attached to design.",
      "x" = "This design already has count data.",
      "i" = "Create a new design or explicitly remove counts first."
    ))
  }

  # Validate count schema
  validate_count_schema(counts)

  # Construct new object with counts attached
  # Uses copy-on-modify: design is unchanged, return new object
  new_design <- design  # R's copy-on-write creates copy when modified
  new_design$counts <- counts
  new_design$survey <- construct_survey_design(new_design)  # Eager construction
  new_design$validation <- validate_counts_tier1(new_design)  # Store results

  new_design
}
```

### Pattern 2: Eager Construction for Fail-Fast Validation

**What:** Construct complex objects immediately in user-facing functions to detect errors early

**When to use:** add_counts() should construct svydesign object immediately, not lazily during estimation

**Why:** Survey design errors (missing strata, invalid PSU nesting) are easier to debug when reported at add_counts() time rather than during estimation. Users have context about what data they're adding.

**Example:**
```r
# Eager construction pattern
construct_survey_design <- function(design) {
  # Construct immediately, fail fast on errors
  # User knows they're in add_counts() context
  tryCatch(
    survey::svydesign(
      ids = ~ get(design$psu_col),      # PSU column from design
      strata = ~ get_strata_formula(design),  # Construct strata formula
      data = design$counts,              # Count data with all columns
      nest = TRUE                        # PSUs nested within strata
    ),
    error = function(e) {
      cli::cli_abort(c(
        "Failed to construct survey design.",
        "x" = conditionMessage(e),
        "i" = "Check that count data has required columns and valid PSU/strata values."
      ))
    }
  )
}

# Lazy construction anti-pattern (DON'T DO THIS)
construct_survey_design_lazy <- function(design) {
  # Returns a function that constructs later
  # User gets cryptic error during estimate_effort(), loses context
  function() {
    survey::svydesign(...)  # Error happens far from add_counts() call
  }
}
```

### Pattern 3: Once-Per-Session Warnings with rlang

**What:** Issue warnings only once per R session using rlang's `.frequency` parameter

**When to use:** as_survey_design() escape hatch warning about advanced usage

**Example:**
```r
# Source: rlang documentation - Signal an error, warning, or message
# https://rlang.r-lib.org/reference/abort.html

as_survey_design <- function(design) {
  # Check counts attached
  if (is.null(design$counts)) {
    cli::cli_abort(c(
      "No count data attached to design.",
      "x" = "Call {.fn add_counts} before extracting survey design.",
      "i" = "Use {.code design <- add_counts(design, counts)}"
    ))
  }

  # Once-per-session warning
  rlang::warn(
    message = paste(
      "Accessing internal survey design object.",
      "This is an advanced feature. Most users should use estimate_effort() instead.",
      "Modifying the survey design may produce incorrect variance estimates."
    ),
    .frequency = "once",
    .frequency_id = "tidycreel_as_survey_design_warning"
  )

  # Return COPY to prevent mutation affecting internal object
  # survey.design objects are lists, R copy-on-modify semantics apply
  design$survey  # R automatically creates copy when user modifies return value
}
```

### Pattern 4: Validation Result Storage

**What:** Store validation results as attributes or list components for later inspection

**When to use:** Tier 1 validation in add_counts() - store results even if validation passes

**Example:**
```r
validate_counts_tier1 <- function(design) {
  results <- list(
    schema_valid = TRUE,
    psu_present = design$psu_col %in% names(design$counts),
    strata_present = all(design$strata_cols %in% names(design$counts)),
    date_present = design$date_col %in% names(design$counts),
    warnings = character(),
    errors = character()
  )

  # Check for issues
  if (!results$psu_present) {
    results$errors <- c(results$errors,
      sprintf("PSU column '%s' not found in count data", design$psu_col))
  }

  # Return structured result
  structure(results, class = "creel_validation")
}
```

### Anti-Patterns to Avoid

- **Lazy construction with user-facing errors:** Don't defer svydesign construction to estimate_effort() - users lose context about what data caused the error
- **Silent count replacement:** Don't allow add_counts() to silently replace existing counts without explicit user action (user decision: error on duplicates)
- **Bare survey package errors:** Don't let survey::svydesign errors bubble up raw - wrap in cli::cli_abort with domain-specific guidance
- **Mutation of extracted objects affecting internals:** Don't return direct references to internal $survey objects - R's copy-on-modify usually handles this, but document the behavior

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Survey variance estimation | Custom variance formulas for stratified designs | survey::svydesign + survey variance functions | Handles complex edge cases: lonely PSUs, unequal weighting, FPC, domain estimation |
| PSU nesting validation | Custom checks for PSU uniqueness across strata | survey::svydesign with check.strata = TRUE | Survey package has battle-tested validation for design specification |
| Stratification formulas | String parsing to build formulas | Standard R formula interface ~ | R's formula objects are first-class, tidyeval helpers work with them |
| Warning frequency control | Global options or package-level state | rlang::warn with .frequency = "once" | Robust, thread-safe, respects user suppression preferences |

**Key insight:** Survey statistics has many subtle edge cases (lonely PSU problem, finite population corrections, domain estimation). The survey package has handled these for 20+ years across thousands of studies. Don't reimplement.

## Common Pitfalls

### Pitfall 1: Lonely PSU Problem

**What goes wrong:** When a stratum contains only one PSU, variance cannot be estimated (mathematically: you need at least 2 observations to compute variance). survey::svydesign will error by default with `survey.lonely.psu="fail"`.

**Why it happens:**
- Small sample sizes in certain strata (e.g., only one weekend day sampled in a month)
- Data filtering creates strata with single PSUs after design construction
- Domain estimation (subpopulation analysis) leaves some strata with one PSU

**How to avoid:**
- **Detection:** Test designs with `survey::svydesign()` immediately in add_counts() (eager construction pattern)
- **Design-time prevention:** Ensure sampling plan has multiple PSUs per stratum
- **Post-hoc handling:** Set `options(survey.lonely.psu = "adjust")` or `"average"` - document this in user guidance
- **Best solution (from survey docs):** Combine single-PSU stratum with another well-chosen stratum

**Warning signs:**
- Error message: "Stratum (...) has only one PSU at stage 1"
- Occurs during svydesign construction or variance estimation
- More common in small creel surveys with fine-grained stratification

**Implementation guidance:** add_counts() should detect this during eager construction and provide educational error message explaining the problem and solutions.

### Pitfall 2: PSU Nesting Confusion (nest = TRUE vs FALSE)

**What goes wrong:** If PSU IDs are reused across strata (e.g., "day 1", "day 2", "day 3" appears in both weekday and weekend strata), svydesign must use `nest = TRUE`. If omitted, survey package assumes PSU IDs are globally unique and may produce incorrect variance estimates.

**Why it happens:**
- Creel surveys naturally reuse day identifiers (day 1, 2, 3...)
- Default is `nest = FALSE` (assumes unique PSU IDs across entire sample)
- Documentation emphasis on nest parameter is subtle

**How to avoid:**
- **Always use `nest = TRUE`** for creel designs unless you're certain PSU IDs are globally unique
- User specifies PSU column; package determines nesting requirement from strata structure
- Consider creating unique PSU ID internally if user provides ambiguous PSU column

**Warning signs:**
- Variance estimates seem too small (incorrect pooling across strata)
- Warning: "Some clusters appear in multiple strata" (if check.strata = TRUE)

**Implementation guidance:** Default to `nest = TRUE` in construct_survey_design(). Document in user guidance that PSU IDs only need to be unique within strata, not globally.

### Pitfall 3: Missing Values in Design Variables

**What goes wrong:** survey::svydesign requires no missing values in strata, PSU, weights, or FPC variables. If present, svydesign errors with "missing values in object".

**Why it happens:**
- Incomplete count data (missed sampling days)
- Strata columns with NA (unclassified days)
- User joins count data incorrectly, introducing NAs

**How to avoid:**
- **Validate in add_counts()** before constructing svydesign - check for NAs in design columns
- Provide specific error: "Column 'day_type' contains 3 missing values. Survey designs require complete stratification."
- Guide users: either remove rows with missing strata or impute values

**Warning signs:**
- Error during svydesign construction mentioning "missing values"
- Occurs with real-world messy data more than clean examples

**Implementation guidance:** Add explicit NA checking in validate_counts_tier1() before calling survey::svydesign.

### Pitfall 4: Mismatched Columns Between calendar and counts

**What goes wrong:** User provides count data with different column names or missing strata columns that exist in calendar. svydesign construction fails because strata variables aren't found.

**Why it happens:**
- Calendar has "day_type", counts have "daytype" (typo)
- User filters count data, drops strata columns
- Different data sources for calendar and counts

**How to avoid:**
- **Validate column presence** in add_counts(): check that date_col, strata_cols, psu_col all exist in counts data frame
- Educational error: "Count data missing required column 'day_type'. Ensure count data includes all strata columns from calendar."
- Consider future enhancement: auto-join counts to calendar by date to ensure consistency

**Warning signs:**
- Error: "variable '...' not found" during svydesign construction
- Occurs when users hand-construct count data frames

**Implementation guidance:** Explicit column existence validation in add_counts() before svydesign construction.

### Pitfall 5: Modifying Extracted Survey Object Affects Internal State

**What goes wrong:** If as_survey_design() returns direct reference to design$survey, user modifications could affect internal state (though R's copy-on-modify usually prevents this).

**Why it happens:**
- R's copy-on-modify semantics are subtle
- Survey objects are lists; modifying list elements triggers copies but direct reference passing doesn't always

**How to avoid:**
- **Documentation:** Clearly state that returned object is independent of internal design
- **Testing:** Verify that modifying return value doesn't affect design$survey
- R's semantics should handle this automatically for list objects

**Warning signs:**
- User reports unexpected behavior after calling as_survey_design()
- Internal survey object changed after user manipulates extracted object

**Implementation guidance:** Trust R's copy-on-modify for list objects. Document behavior. Add tests verifying independence.

## Code Examples

Verified patterns from research:

### Basic Stratified Design Construction
```r
# Source: survey package documentation - Specifying a survey design
# https://r-survey.r-forge.r-project.org/survey/example-design.html

# Pattern: id = ~1 means each row is a PSU (no clustering)
# Pattern: strata = ~varname specifies stratification
# Pattern: nest = TRUE means PSUs reuse IDs within strata

design_svy <- survey::svydesign(
  ids = ~1,                    # Each day is a PSU (no clustering within days)
  strata = ~day_type,          # Stratify by day_type
  data = count_data,           # Data frame with counts and strata
  nest = TRUE                  # Day IDs nested within day_type strata
)
```

### Multi-Strata Design (Multiple Stratification Variables)
```r
# For creel designs with multiple strata (day_type + season)
# Strata formula combines multiple variables

# Option 1: Interaction formula
design_svy <- survey::svydesign(
  ids = ~1,
  strata = ~interaction(day_type, season),  # Combined stratum
  data = count_data,
  nest = TRUE
)

# Option 2: Manual interaction column (clearer error messages)
count_data$stratum <- interaction(
  count_data$day_type,
  count_data$season,
  drop = TRUE
)
design_svy <- survey::svydesign(
  ids = ~1,
  strata = ~stratum,
  data = count_data,
  nest = TRUE
)
```

### PSU Column Specification (User-Provided PSU)
```r
# User specifies PSU column in add_counts() or creel_design()
# PSU can be day, day-site combination, etc.

design_svy <- survey::svydesign(
  ids = ~ get(psu_col_name),   # Dynamic column reference
  strata = ~day_type,
  data = count_data,
  nest = TRUE
)

# Alternative: Use reformulate() for dynamic formulas
psu_formula <- reformulate(psu_col_name)
strata_formula <- reformulate(strata_col_names)

design_svy <- survey::svydesign(
  ids = psu_formula,
  strata = strata_formula,
  data = count_data,
  nest = TRUE
)
```

### Validation and Error Wrapping
```r
# Wrap survey package errors in domain-specific guidance
construct_survey_design <- function(design) {
  tryCatch(
    {
      survey::svydesign(
        ids = reformulate(design$psu_col),
        strata = reformulate(design$strata_cols),
        data = design$counts,
        nest = TRUE
      )
    },
    error = function(e) {
      # Parse survey package error and provide guidance
      msg <- conditionMessage(e)

      if (grepl("only one PSU", msg)) {
        cli::cli_abort(c(
          "Survey design has stratum with only one PSU.",
          "x" = msg,
          "i" = "Variance cannot be estimated with single PSU in a stratum.",
          "i" = "Solutions:",
          "*" = "Combine this stratum with another stratum",
          "*" = "Set options(survey.lonely.psu = 'adjust')",
          "*" = "Collect more samples in this stratum"
        ))
      } else if (grepl("not found", msg)) {
        cli::cli_abort(c(
          "Required column not found in count data.",
          "x" = msg,
          "i" = "Ensure count data includes: {.field {design$date_col}}, {.field {design$strata_cols}}, {.field {design$psu_col}}"
        ))
      } else {
        cli::cli_abort(c(
          "Failed to construct survey design.",
          "x" = msg,
          "i" = "Check that count data has valid values for all design columns."
        ))
      }
    }
  )
}
```

### Once-Per-Session Warning Pattern
```r
# Source: rlang documentation
# https://rlang.r-lib.org/reference/abort.html

as_survey_design <- function(design) {
  # Validate counts attached
  if (is.null(design$counts) || is.null(design$survey)) {
    cli::cli_abort(c(
      "No survey design available.",
      "x" = "Call {.fn add_counts} before extracting survey design.",
      "i" = "Example: {.code design <- add_counts(design, counts)}"
    ))
  }

  # Once-per-session warning about advanced usage
  rlang::warn(
    message = c(
      "Accessing internal survey design object.",
      "i" = "This is an advanced feature.",
      "i" = "Most users should use {.fn estimate_effort} instead.",
      "!" = "Modifying this object may produce incorrect variance estimates."
    ),
    .frequency = "once",
    .frequency_id = "tidycreel_as_survey_design"
  )

  # Return the survey object (R copy-on-modify creates copy on user mutation)
  design$survey
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Separate variance computation packages | Integrated survey package ecosystem | survey package ~2004 | Single package handles design + estimation + variance |
| stopifnot() for validation | cli::cli_abort() with structured messages | cli package 2017+, widespread adoption 2020+ | Better error messages, styled output, bullets |
| Package startup messages | Once-per-session warnings with rlang | rlang .frequency parameter added ~2020 | Less annoying repeated warnings |
| Global options for warnings | .frequency parameter in rlang::warn | rlang 0.4.0+ (2019) | Thread-safe, respects suppressMessages() |

**Deprecated/outdated:**
- **checkmate vs assertthat:** assertthat is superseded (per tidyverse). checkmate is current best practice for input validation (faster, better error messages). tidycreel already uses checkmate in Phase 1/2.
- **survey.lonely.psu = "remove":** Alias for "certainty", prefer "certainty" for clarity
- **Base R formula() vs reformulate():** reformulate() is cleaner for programmatic formula construction from character vectors

## Open Questions

### Question 1: When should survey package be added to DESCRIPTION?

**What we know:**
- Phase 3 needs survey::svydesign for internal construction
- survey package is stable, widely used, minimal dependency footprint
- Adding to Imports is standard practice when using package functions in code

**What's unclear:**
- Should it be added at Phase 3 start or when first svydesign() call is written?
- Any downstream implications for package check/build?

**Recommendation:** Add survey to DESCRIPTION Imports at start of Phase 3. Standard practice is to add dependencies when you start writing code that uses them. Document in NAMESPACE with @importFrom survey svydesign (or @import survey if using multiple functions).

### Question 2: Should PSU column be specified in creel_design() or add_counts()?

**What we know:**
- User decision: "User specifies PSU column in creel_design or add_counts()"
- PSU identification is design-level decision (which sampling unit is primary)
- But PSU values are in count data, not calendar

**What's unclear:**
- If specified in creel_design(), how do we validate it exists? (Calendar doesn't have PSU column)
- If specified in add_counts(), is it awkward to add design metadata after construction?

**Recommendation:**
- **Option A (Preferred):** Add psu_col parameter to creel_design() constructor, validate it exists in count data during add_counts(). This makes PSU identification a design-level decision (where it conceptually belongs).
- **Option B (Alternative):** Add psu parameter to add_counts() if user flexibility is more important than conceptual purity.

Lean toward Option A for consistency with date_col and strata_cols being specified at design construction time.

### Question 3: How should allow_invalid flag work in add_counts()?

**What we know:**
- User decision: "Error by default, with allow_invalid flag to convert to warnings"
- Tier 1 validation errors should be safe by default
- Power users need flexibility for exploratory analysis

**What's unclear:**
- Which specific validations should allow_invalid affect?
- Should it apply to schema validation (missing columns) or only statistical validation?
- What's the right default behavior when invalid design still produces results?

**Recommendation:**
- allow_invalid should apply to **Tier 1 statistical warnings** (e.g., "few samples in stratum") but NOT structural errors (e.g., missing PSU column)
- Structural errors (schema validation failures) should always error - these indicate broken design, not suboptimal design
- Store warnings in validation results even when allow_invalid = TRUE so users can inspect them

### Question 4: Should we create unique PSU IDs internally or require user to provide them?

**What we know:**
- nest = TRUE allows PSU IDs to repeat across strata
- Creel surveys often use day numbers (1, 2, 3...) that repeat across strata
- survey package handles nested PSUs correctly

**What's unclear:**
- Is there any advantage to creating globally unique PSU IDs internally (e.g., "weekday_day1", "weekend_day1")?
- Does it simplify debugging or downstream analysis?

**Recommendation:** Use nest = TRUE and accept user's PSU column as-is. Don't create unique IDs internally - adds complexity, user's PSU column is semantically correct (day IS the PSU), and nest = TRUE handles this properly. Document clearly that PSU IDs only need to be unique within strata.

## Sources

### Primary (HIGH confidence)
- [survey package documentation - svydesign](https://r-survey.r-forge.r-project.org/survey/html/svydesign.html) - Official R-Forge documentation for svydesign function
- [survey package documentation - Specifying a survey design](https://r-survey.r-forge.r-project.org/survey/example-design.html) - Official examples and patterns
- [survey package documentation - Lonely PSUs](https://r-survey.r-forge.r-project.org/survey/exmample-lonely.html) - Official guidance on lonely PSU problem
- [Advanced R - S3 chapter](https://adv-r.hadley.nz/s3.html) - Hadley Wickham, authoritative R programming patterns
- [rlang documentation - Signal conditions](https://rlang.r-lib.org/reference/abort.html) - Official rlang documentation for warning patterns
- [CRAN survey package PDF](https://cran.r-project.org/web/packages/survey/survey.pdf) - Official CRAN documentation (August 28, 2025 version)

### Secondary (MEDIUM confidence)
- [Introduction to Regression Methods for Public Health Using R - Survey Design](https://www.bookdown.org/rwnahhas/RMPH/survey-design.html) - Applied survey design patterns in R
- [Complex survey design tutorial](https://jamescheshire.github.io/learningR/complex-survey-design.html) - Practical examples of svydesign usage
- [UCLA survey data analysis with R](https://stats.oarc.ucla.edu/r/seminars/survey-data-analysis-with-r/) - Educational materials on survey package
- [checkmate paper](https://arxiv.org/pdf/1701.04781) - Fast Argument Checks for Defensive R Programming (Michel Lang)
- [R-hub blog - Lazy evaluation](https://blog.r-hub.io/2025/02/13/lazy-meanings/) - Recent (2025) discussion of lazy evaluation patterns
- [McCormick et al. 2017 - Sample Size Estimation for On-Site Creel Surveys](https://afspubs.onlinelibrary.wiley.com/doi/full/10.1080/02755947.2017.1342723) - Creel survey stratification by day type
- [Alaska DFG - Mechanics of Onsite Creel Surveys](https://www.adfg.alaska.gov/fedaidpdfs/sp98-01.pdf) - Creel survey design patterns

### Tertiary (LOW confidence - domain background)
- [Creel Survey Simulation vignette](https://cran.r-project.org/web/packages/AnglerCreelSurveySimulation/vignettes/creel_survey_simulation.html) - Example creel survey structures
- [R-bloggers - Verbosity control in packages](https://ropensci.org/blog/2024/02/06/verbosity-control-packages/) - Package-level message patterns

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - survey package is authoritative and stable (20+ years on CRAN), patterns verified from official documentation
- Architecture: HIGH - R S3 patterns from Hadley Wickham's Advanced R, eager vs lazy guidance from R-hub blog and established practices
- Pitfalls: HIGH - lonely PSU problem documented in survey package official docs, PSU nesting from official svydesign documentation, missing value requirement explicit in docs
- Creel domain: MEDIUM - stratification patterns from peer-reviewed fisheries literature, but not critical for implementation (design is general-purpose survey package usage)

**Research date:** 2026-02-08
**Valid until:** ~60 days (survey package is stable; R patterns are stable; rlang/cli are stable)

**Key gaps filled:**
- Confirmed survey package patterns for stratified designs with PSUs
- Identified lonely PSU problem and handling strategies (critical for small creel surveys)
- Verified nest = TRUE requirement for non-unique PSU IDs (common in creel designs)
- Established rlang .frequency = "once" pattern for as_survey_design() warning
- Documented eager vs lazy construction guidance (favor eager for fail-fast validation)
- Verified R S3 immutability patterns (copy-on-modify for add_counts)

**Implementation readiness:** HIGH - All technical patterns documented, code examples provided, pitfalls identified with solutions
