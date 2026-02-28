# Phase 8: Interview Data Integration - Research

**Researched:** 2026-02-09
**Domain:** R package - Interview data integration layer for creel surveys
**Confidence:** HIGH

## Summary

Phase 8 adds the data integration layer for angler interview data. This phase establishes `add_interviews()` as a parallel to `add_counts()`, enabling users to attach interview data (catch, harvest, effort per trip) to existing creel_design objects. The focus is on data attachment, validation, and survey design construction - NOT estimation capabilities (those are Phase 9-11).

**Primary recommendation:** Follow the add_counts() pattern exactly - same parameter structure, same validation tiers, same error handling style. Users who learned add_counts() should find add_interviews() immediately familiar. Interview data is a parallel stream to count data, both feeding into the same design calendar structure but requiring separate survey design objects due to different PSU structures.

**Key architectural insight:** Interview and count data are statistically independent but functionally complementary. Keep streams separate (different survey.design2 objects) until final estimation where they combine via delta method variance propagation.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **Mirror add_counts() closely** - Same parameter patterns and naming conventions
- Users who learned add_counts() should find add_interviews() immediately familiar
- Maintain v0.1.0 design philosophy: tidy selectors, consistent error messages, same return patterns
- **Tidy selectors like add_counts()** - e.g., `catch = catch_total, harvest = catch_kept, effort = hours_fished`
- Follows the `count = n` pattern established in add_counts()
- Consistent with tidyverse philosophy and v0.1.0 API design
- **Same as add_counts() exactly** - Use `date_col=` parameter pointing to interview date
- System matches interview dates to design calendar automatically
- No additional stratification mapping required from user - inferred from design

### Claude's Discretion
- Return value and user feedback style (silent vs verbose vs message)
- Exact parameter validation and error message wording
- Internal survey design object construction details
- Data quality validation timing and strictness
- Interview type detection (access point vs roving) approach
- Specific warning vs error thresholds for data quality issues

### Deferred Ideas (OUT OF SCOPE)
None - discussion stayed within phase scope (data integration layer only)
</user_constraints>

## Standard Stack

### Core (Already Available - No New Dependencies)

| Library | Version | Purpose | Why Sufficient |
|---------|---------|---------|----------------|
| survey | 4.4.2 | Design-based inference | `svydesign()` builds interview survey objects with same machinery as count surveys |
| tidyselect | 1.2.1 | Column selection API | Already used in add_counts(), extends to catch/effort/harvest columns |
| rlang | 1.1.7 | Tidy evaluation | Already used for quosures in add_counts(), same pattern for add_interviews() |
| checkmate | 2.3.2 | Progressive validation | Already used for Tier 1 validation, extends to interview data checks |
| cli | 3.6.5 | User messages | Already used for error/warning formatting, extends to interview-specific guidance |
| dplyr | 1.1.4 | Data manipulation | May need for interview/calendar joins, already available |

### Supporting (Already Available)

| Library | Purpose | Interview Usage |
|---------|---------|-----------------|
| testthat | >= 3.0.0 | Unit testing | Reference tests for interview validation and survey construction |
| covr | Test coverage | Maintain 85%+ coverage with new integration functions |

**NO NEW DEPENDENCIES REQUIRED** - Phase 8 is pure data integration using existing v0.1.0 infrastructure.

### Installation

```r
# Verification after Phase 8 implementation
devtools::check()  # Should pass with 0 errors, 0 warnings
sessionInfo()      # Should show NO new package dependencies
```

## Architecture Patterns

### Recommended Project Structure

```
R/
├── creel-design.R         # EXTEND with add_interviews()
├── survey-bridge.R        # EXTEND with construct_interview_survey()
├── creel-validation.R     # EXTEND with interview validation
└── validate-schemas.R     # EXTEND with validate_interview_schema()
```

**Integration pattern:** Extend existing files rather than creating new interview-specific files. Keeps count and interview logic visible side-by-side for consistency.

### Pattern 1: Parallel Data Stream API (Mirror add_counts())

**What:** add_interviews() follows identical signature and behavior to add_counts(), creating parallel data attachment patterns.

**When to use:** When users need to attach a second data source (interviews) to an existing design that already has a first data source (counts).

**Example:**
```r
# From v0.1.0 (proven pattern)
design <- creel_design(calendar, date = date, strata = day_type)
design_with_counts <- add_counts(design, counts)

# Phase 8 (parallel pattern)
design_with_both <- add_interviews(design_with_counts, interviews,
                                    catch = catch_total,
                                    effort = hours_fished,
                                    harvest = catch_kept)

# Users experience: "I already know how to do this"
```

**Key elements:**
- Tidy selectors for column specification (catch = catch_total)
- date_col parameter for calendar linkage (same as add_counts)
- Immutability: returns new object, doesn't modify input
- Eager validation: errors at attachment time, not estimation time
- Progressive validation: Tier 1 errors, Tier 2 warnings

**Source:** Established in v0.1.0 `add_counts()` - `/Users/cchizinski2/Dev/tidycreel/R/creel-design.R` lines 277-404

### Pattern 2: Dual Survey Object Storage

**What:** Store separate survey.design2 objects for counts and interviews in the same creel_design container.

**When to use:** When two data sources have different PSU structures but share calendar/strata.

**Trade-offs:**
- **Pro:** Clean separation, independent validation, can use either alone
- **Pro:** Matches statistical reality (day-PSU for counts, interview-PSU for interviews)
- **Con:** More complex object structure, must coordinate strata

**Example:**
```r
# creel_design object structure after Phase 8
design_with_both <- list(
  calendar = calendar,           # Shared
  date_col = "date",             # Shared
  strata_cols = c("day_type"),   # Shared
  site_col = NULL,               # Shared
  design_type = "instantaneous", # Shared

  # Count data stream (from v0.1.0)
  counts = counts_df,
  psu_col = "date",              # Day as PSU
  survey = count_survey_object,  # Day-PSU survey.design2

  # Interview data stream (NEW in Phase 8)
  interviews = interviews_df,
  catch_col = "catch_total",
  effort_col = "hours_fished",
  harvest_col = "catch_kept",
  interview_survey = interview_survey_object,  # Interview-PSU survey.design2
  interview_type = "access",     # Detected or specified

  validation = validation_object,
  class = "creel_design"
)
```

**Calendar as bridge:** Both survey objects reference the same calendar for stratification, ensuring compatible strata definitions for later combination.

**Source:** Architecture research - `/.planning/research/ARCHITECTURE.md` lines 289-310

### Pattern 3: Progressive Validation with Tiers

**What:** Two-tier validation system where structural failures (Tier 1) abort, data quality issues (Tier 2) warn.

**When to use:** Separating "cannot proceed" errors from "should investigate" warnings.

**Tier 1 (Structural - MUST PASS):**
- Interview data has at least one numeric column (catch/effort)
- Interview data has date column matching design$date_col
- No NA values in design-critical columns (date, strata)
- Specified columns (catch, effort, harvest) exist in data
- Specified columns have correct types (numeric for catch/effort/harvest)

**Tier 2 (Data Quality - WARNINGS):**
- Very short trips (effort < 0.1 hours) - may indicate data entry errors
- Zero or negative catch values - may be valid or errors
- Extreme catch rates - may indicate outliers
- Missing effort values - limits CPUE estimation
- Sparse interview coverage - some calendar days have no interviews

**Example:**
```r
validate_interviews_tier1 <- function(interviews, design, catch_col, effort_col) {
  collection <- checkmate::makeAssertCollection()

  # Check date column exists
  if (!design$date_col %in% names(interviews)) {
    collection$push(sprintf(
      "Date column '%s' from design not found in interview data",
      design$date_col
    ))
  }

  # Check catch column exists and is numeric
  if (!catch_col %in% names(interviews)) {
    collection$push(sprintf("Catch column '%s' not found", catch_col))
  } else if (!is.numeric(interviews[[catch_col]])) {
    collection$push(sprintf(
      "Catch column '%s' must be numeric, got %s",
      catch_col, class(interviews[[catch_col]])[1]
    ))
  }

  # ... more checks

  if (!collection$isEmpty()) {
    cli::cli_abort(c(
      "Interview data validation failed (Tier 1):",
      stats::setNames(collection$getMessages(), rep("x", collection$length())),
      "i" = "Interview data must have all required columns with correct types."
    ))
  }
}

warn_tier2_interview_issues <- function(design) {
  interviews <- design$interviews
  effort_col <- design$effort_col
  catch_col <- design$catch_col

  # Check for very short trips
  if (!is.null(effort_col)) {
    short_trips <- sum(interviews[[effort_col]] < 0.1, na.rm = TRUE)
    if (short_trips > 0) {
      cli::cli_warn(c(
        "{short_trips} interview{?s} ha{?s/ve} effort <0.1 hours (6 minutes).",
        "i" = "Very short trips may indicate data entry errors.",
        "i" = "Review and correct if needed."
      ))
    }
  }

  # Check for negative catch
  negative_catch <- sum(interviews[[catch_col]] < 0, na.rm = TRUE)
  if (negative_catch > 0) {
    cli::cli_warn(c(
      "{negative_catch} interview{?s} ha{?s/ve} negative catch values.",
      "!" = "Negative catch indicates data entry errors.",
      "i" = "Review and correct before estimation."
    ))
  }

  # ... more warnings
}
```

**Source:** Existing pattern from add_counts() - `/Users/cchizinski2/Dev/tidycreel/R/survey-bridge.R` lines 117-235

### Pattern 4: Tidy Selector Resolution

**What:** Resolve user-provided tidy selectors (bare names, tidyselect helpers) to concrete column names.

**When to use:** Any function accepting column specification from users.

**Example:**
```r
add_interviews <- function(design, interviews,
                           catch, effort, harvest = NULL,
                           date_col = NULL) {
  # Resolve catch column
  catch_col <- resolve_single_col(
    rlang::enquo(catch),
    interviews,
    "catch",
    rlang::caller_env()
  )

  # Resolve effort column
  effort_col <- resolve_single_col(
    rlang::enquo(effort),
    interviews,
    "effort",
    rlang::caller_env()
  )

  # Resolve harvest column (optional)
  harvest_col <- NULL
  harvest_quo <- rlang::enquo(harvest)
  if (!rlang::quo_is_null(harvest_quo)) {
    harvest_col <- resolve_single_col(
      harvest_quo,
      interviews,
      "harvest",
      rlang::caller_env()
    )
  }

  # ... continue with resolved column names
}
```

**Reuses existing helpers:** `resolve_single_col()` already exists in creel-design.R (lines 221-250), no new code needed.

**Source:** Existing pattern from creel_design() - `/Users/cchizinski2/Dev/tidycreel/R/creel-design.R` lines 87-111

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Column selection from user input | Custom parsing of column names | tidyselect::eval_select() | Handles bare names, tidyselect helpers (starts_with, etc), errors |
| Survey design construction for interviews | Custom PSU/strata handling | survey::svydesign() | Correct variance formulas, handles edge cases, peer-reviewed |
| Data validation | Custom if/else chains | checkmate::makeAssertCollection() | Progressive accumulation, clear error messages, tested |
| Interview data schema checks | Custom column type checks | Extend existing validate_count_schema() pattern | Consistency with v0.1.0, reuse validation infrastructure |
| Calendar date matching | Custom date joins | dplyr::left_join() with validation | Handles missing dates, duplicates, type mismatches |

**Key insight:** Phase 8 introduces NO new statistical problems - it's pure data wrangling and validation. Reuse existing patterns and libraries.

## Common Pitfalls

### Pitfall 1: Data Structure Mismatch Between Count and Interview Data

**What goes wrong:** Count data (effort estimation) uses day-level PSUs, but interview data uses individual-level observations. When trying to combine for total catch = effort × cpue, the survey designs are incompatible.

**Why it happens:** Different aggregation levels concealed by shared creel_design container until users try to combine estimates.

**How to avoid:**
1. **Separate survey objects:** Store `design$survey` (day-PSU) and `design$interview_survey` (interview-PSU) separately
2. **Shared calendar as bridge:** Both reference `design$calendar` for strata definitions
3. **Document clearly:** Users must understand interviews and counts are parallel streams
4. **Validation in add_interviews():** Check that interview dates exist in calendar

**Warning signs:**
- Dates in interviews not in calendar
- Strata values in interviews not in calendar
- Users confused about why two survey objects exist

**Phase 8 prevention:**
```r
add_interviews <- function(design, interviews, ...) {
  # Check calendar exists
  if (is.null(design$calendar)) {
    cli::cli_abort("Design must have calendar before adding interviews")
  }

  # Validate interview dates exist in calendar
  interview_dates <- unique(interviews[[design$date_col]])
  calendar_dates <- design$calendar[[design$date_col]]
  missing_dates <- setdiff(interview_dates, calendar_dates)

  if (length(missing_dates) > 0) {
    cli::cli_abort(c(
      "x" = "Interview data contains dates not in calendar",
      "i" = "Missing dates: {paste(head(missing_dates, 5), collapse=', ')}",
      "i" = "Add missing dates to calendar before attaching interviews"
    ))
  }

  # Join interviews with calendar to inherit strata
  interviews_with_strata <- dplyr::left_join(
    interviews,
    design$calendar,
    by = design$date_col,
    suffix = c("", "_cal")
  )

  # Continue...
}
```

**Source:** Pitfalls research - `/.planning/research/PITFALLS.md` lines 148-203

### Pitfall 2: Inconsistent Column Naming with add_counts()

**What goes wrong:** add_counts() uses `count = n` pattern, but add_interviews() uses different parameter names, breaking user mental model.

**Why it happens:** Different developers, different phases, inconsistent API review.

**How to avoid:**
1. **Follow count = n pattern:** `catch = catch_total, effort = hours_fished, harvest = catch_kept`
2. **Same parameter structure:** date_col, allow_invalid parameters work identically
3. **Same error messages:** "Column X not found" format matches add_counts()
4. **Same return pattern:** Returns new creel_design object with interviews added

**Warning signs:**
- Users report "add_interviews is confusing" compared to add_counts
- Different parameter order or naming
- Different error message styles

**Phase 8 prevention:** Code review checklist comparing add_interviews() to add_counts() line-by-line for consistency.

**Source:** User decision from CONTEXT.md - consistency is north star

### Pitfall 3: Missing Interview Type Detection

**What goes wrong:** User attaches interview data but system doesn't record whether interviews are access point (complete trips) or roving (incomplete trips). Later CPUE estimation (Phase 9) can't choose correct estimator.

**Why it happens:** Phase 8 focuses on data attachment, forgetting that metadata is needed for Phase 9 decisions.

**How to avoid:**
1. **Store interview_type in design object:** `design$interview_type = "access"` or `"roving"`
2. **Auto-detect from trip_complete column:** If `trip_complete` column exists and is all TRUE, likely access
3. **Allow user to specify:** Parameter `interview_type = c("access", "roving")` with default "access"
4. **Validate at attachment time:** Check that specified type matches data (e.g., roving data shouldn't have all trip_complete=TRUE)

**Warning signs:**
- CPUE estimation (Phase 9) has no basis for choosing estimator
- Users must re-specify interview type in every estimation call
- Inconsistent interview_type across different function calls

**Phase 8 prevention:**
```r
add_interviews <- function(design, interviews, ...,
                           interview_type = c("access", "roving")) {
  interview_type <- match.arg(interview_type)

  # Auto-detect if trip_complete column exists
  if ("trip_complete" %in% names(interviews)) {
    pct_complete <- mean(interviews$trip_complete, na.rm = TRUE)

    if (interview_type == "access" && pct_complete < 0.9) {
      cli::cli_warn(c(
        "!" = "Interview type 'access' specified but only {scales::percent(pct_complete)} of trips are complete",
        "i" = "Access point interviews should be complete trips",
        "i" = "Consider interview_type = 'roving' if these are incomplete trips"
      ))
    }

    if (interview_type == "roving" && pct_complete > 0.5) {
      cli::cli_warn(c(
        "!" = "Interview type 'roving' specified but {scales::percent(pct_complete)} of trips are complete",
        "i" = "Roving interviews should be incomplete trips",
        "i" = "Consider interview_type = 'access' if these are complete trips"
      ))
    }
  }

  # Store in design
  design$interview_type <- interview_type

  # Continue...
}
```

**Source:** Domain knowledge - ratio-of-means vs mean-of-ratios depends on complete/incomplete trips

### Pitfall 4: Forgetting Harvest Column Validation

**What goes wrong:** Harvest estimation (Phase 10) requires catch_kept <= catch_total consistency, but this isn't validated at attachment time. Later harvest estimation fails with cryptic errors or produces impossible results.

**Why it happens:** Phase 8 treats harvest as optional parameter, forgetting to validate logical consistency when provided.

**How to avoid:**
1. **Tier 1 validation:** If harvest column specified, check harvest <= catch for all rows
2. **Clear error message:** "Harvest cannot exceed catch" with row numbers
3. **Handle NA gracefully:** Only validate non-NA rows
4. **Document in add_interviews():** Explain harvest = kept fish, catch = total caught

**Warning signs:**
- Rows where harvest > catch (biologically impossible)
- Harvest estimation fails with "negative release" errors
- Users confused about catch vs harvest distinction

**Phase 8 prevention:**
```r
validate_interviews_tier1 <- function(interviews, catch_col, harvest_col) {
  # ... other checks

  # Check harvest <= catch consistency
  if (!is.null(harvest_col)) {
    catch_vals <- interviews[[catch_col]]
    harvest_vals <- interviews[[harvest_col]]

    # Check only non-NA rows
    valid_rows <- !is.na(catch_vals) & !is.na(harvest_vals)
    violations <- valid_rows & (harvest_vals > catch_vals)

    if (any(violations)) {
      violation_rows <- which(violations)
      cli::cli_abort(c(
        "x" = "Harvest cannot exceed catch (found {sum(violations)} violation{?s})",
        "i" = "Problem rows: {paste(head(violation_rows, 5), collapse=', ')}",
        "i" = "Harvest = fish kept, Catch = total caught (kept + released)"
      ))
    }
  }
}
```

**Source:** Harvest estimation requirements - HARV-04 validates catch_kept <= catch_total

## Code Examples

Verified patterns from existing v0.1.0 code:

### Example 1: add_interviews() Core Function

```r
# Source: Following add_counts() pattern exactly
# Location: R/creel-design.R (extend)

add_interviews <- function(design, interviews,
                           catch, effort, harvest = NULL,
                           date_col = NULL,
                           interview_type = c("access", "roving"),
                           allow_invalid = FALSE) {
  # Validate design is creel_design
  if (!inherits(design, "creel_design")) {
    cli::cli_abort(c(
      "{.arg design} must be a {.cls creel_design} object.",
      "x" = "{.arg design} is {.cls {class(design)[1]}}.",
      "i" = "Create a design with {.fn creel_design}."
    ))
  }

  # Check interviews not already attached
  if (!is.null(design$interviews)) {
    cli::cli_abort(c(
      "Interviews already attached to design.",
      "x" = "The design object already has interview data in the {.field $interviews} slot.",
      "i" = "Create a new design with {.fn creel_design} to attach different interviews.",
      "i" = "Use immutable workflow: {.code design2 <- add_interviews(design, interviews)}"
    ))
  }

  # Validate interview data schema (Date column, numeric columns)
  validate_interview_schema(interviews)

  # Resolve column selectors
  catch_col <- resolve_single_col(
    rlang::enquo(catch), interviews, "catch", rlang::caller_env()
  )
  effort_col <- resolve_single_col(
    rlang::enquo(effort), interviews, "effort", rlang::caller_env()
  )

  harvest_col <- NULL
  harvest_quo <- rlang::enquo(harvest)
  if (!rlang::quo_is_null(harvest_quo)) {
    harvest_col <- resolve_single_col(
      harvest_quo, interviews, "harvest", rlang::caller_env()
    )
  }

  # Set date column (default to design's date_col)
  if (is.null(date_col)) {
    date_col <- design$date_col
  }

  # Match and validate interview_type
  interview_type <- match.arg(interview_type)

  # Validate interviews structure (Tier 1)
  validation <- validate_interviews_tier1(
    interviews, design, catch_col, effort_col, harvest_col,
    date_col, allow_invalid
  )

  # Join interviews with calendar to inherit strata
  interviews_with_strata <- dplyr::left_join(
    interviews,
    design$calendar,
    by = date_col,
    suffix = c("", "_cal")
  )

  # Copy design and add interviews
  new_design <- design
  new_design$interviews <- interviews_with_strata
  new_design$catch_col <- catch_col
  new_design$effort_col <- effort_col
  new_design$harvest_col <- harvest_col
  new_design$interview_type <- interview_type

  # Construct interview survey design eagerly
  new_design$interview_survey <- construct_interview_survey(new_design)

  # Update validation results
  new_design$validation <- validation

  # Warn for Tier 2 data quality issues
  warn_tier2_interview_issues(new_design)

  # Preserve class
  class(new_design) <- "creel_design"

  new_design
}
```

**Pattern:** Matches add_counts() structure line-by-line for consistency.

### Example 2: Interview Schema Validation

```r
# Source: Following validate_count_schema() pattern
# Location: R/validate-schemas.R (extend)

validate_interview_schema <- function(data) {
  collection <- checkmate::makeAssertCollection()
  checkmate::assert_data_frame(data, min.rows = 1, add = collection)

  if (is.data.frame(data) && nrow(data) > 0) {
    # Must have at least one Date column
    has_date <- any(vapply(data, inherits, logical(1), "Date"))
    if (!has_date) {
      collection$push("Must contain at least one Date column")
    }

    # Must have at least one numeric column (for catch/effort/harvest)
    has_numeric <- any(vapply(data, is.numeric, logical(1)))
    if (!has_numeric) {
      collection$push("Must contain at least one numeric column for catch/effort")
    }
  }

  if (!collection$isEmpty()) {
    msgs <- collection$getMessages()
    cli::cli_abort(c(
      "Interview data validation failed:",
      stats::setNames(msgs, rep("x", length(msgs))),
      "i" = paste(
        "Interview data must be a data frame with at least one Date column",
        "and numeric columns for catch/effort/harvest."
      )
    ))
  }

  invisible(data)
}
```

**Pattern:** Identical structure to validate_count_schema(), just checks for interview-relevant columns.

### Example 3: Construct Interview Survey Design

```r
# Source: Following construct_survey_design() pattern
# Location: R/survey-bridge.R (extend)

construct_interview_survey <- function(design) {
  interviews_data <- design$interviews
  strata_cols <- design$strata_cols

  # Create strata variable (same as construct_survey_design)
  if (length(strata_cols) == 1) {
    interviews_data$.strata <- interviews_data[[strata_cols]]
  } else {
    strata_factors <- interviews_data[strata_cols]
    interviews_data$.strata <- interaction(strata_factors, drop = TRUE)
  }

  # Build strata formula
  strata_formula <- stats::reformulate(".strata")

  # Attempt to construct survey design with error wrapping
  tryCatch(
    {
      survey::svydesign(
        ids = ~1,  # Interviews are terminal sampling units
        strata = strata_formula,
        data = interviews_data
      )
    },
    error = function(e) {
      err_msg <- conditionMessage(e)

      if (grepl("Stratum.*has only one PSU", err_msg, ignore.case = TRUE)) {
        cli::cli_abort(c(
          "Survey design construction failed: lonely PSU detected.",
          "x" = paste(
            "At least one stratum has only one interview.",
            "Variance estimation requires 2+ interviews per stratum."
          ),
          "i" = "Possible solutions:",
          "*" = "Combine small strata with similar characteristics",
          "*" = "Use a different stratification scheme",
          "*" = "Collect more interviews in sparse strata"
        ))
      } else {
        cli::cli_abort(c(
          "Survey design construction failed.",
          "x" = err_msg,
          "i" = paste(
            "Check that interview data has correct structure for",
            "strata columns {.field {strata_cols}}."
          )
        ))
      }
    }
  )
}
```

**Pattern:** Uses `ids = ~1` (terminal units) instead of `ids = ~date` (day-PSU), but otherwise identical to count survey construction.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual data joins | dplyr::left_join() with validation | Standard since dplyr 1.0 (2020) | Clearer code, better error messages, handles edge cases |
| Custom validation | checkmate::makeAssertCollection() | tidycreel pattern since v0.1.0 | Progressive error accumulation, consistent style |
| Separate API for interviews | Parallel API (add_interviews mirrors add_counts) | Design decision for v0.2.0 | Users learn one pattern, applies to both data sources |
| Interview type as estimation parameter | Interview type stored in design metadata | Phase 8 architectural decision | Correct estimator dispatch in Phase 9, no user repetition |

**Deprecated/outdated:**
- Manual column name parsing (replaced by tidyselect::eval_select)
- Separate design objects for interviews (replaced by dual survey object storage)
- Estimation-time validation (replaced by attachment-time validation)

## Open Questions

1. **Should harvest column be required or optional?**
   - What we know: Harvest estimation (Phase 10) needs catch_kept, but not all surveys track harvest separately
   - What's unclear: Whether to error if harvest missing and user tries harvest estimation, or allow NULL harvest column
   - Recommendation: Make harvest column optional in add_interviews(), error in estimate_harvest() if missing

2. **How to handle trip_complete column?**
   - What we know: trip_complete indicates whether interview was at trip end (access) or mid-trip (roving)
   - What's unclear: Whether to require this column, auto-detect from it, or rely on interview_type parameter
   - Recommendation: Don't require trip_complete, use interview_type parameter (user knows their design), optionally validate consistency if trip_complete exists

3. **Should we validate interview times (time_start, time_end)?**
   - What we know: Sample data includes time columns, could validate effort = time_end - time_start
   - What's unclear: Whether time validation is Tier 1 (error) or Tier 2 (warning), or skipped entirely
   - Recommendation: Tier 2 warning if time columns exist and don't match effort, not required columns

## Sources

### Primary (HIGH confidence)

**Existing v0.1.0 Implementation:**
- `/Users/cchizinski2/Dev/tidycreel/R/creel-design.R` - add_counts() pattern (lines 277-404)
- `/Users/cchizinski2/Dev/tidycreel/R/survey-bridge.R` - construct_survey_design() pattern (lines 252-319)
- `/Users/cchizinski2/Dev/tidycreel/R/validate-schemas.R` - validate_count_schema() pattern (lines 46-88)
- `/Users/cchizinski2/Dev/tidycreel/tests/testthat/test-add-counts.R` - test patterns to mirror

**v0.2.0 Research:**
- `/.planning/research/ARCHITECTURE.md` - Interview integration architecture
- `/.planning/research/STACK.md` - No new dependencies required
- `/.planning/research/PITFALLS.md` - Critical pitfalls to avoid

**Sample Data:**
- `/Users/cchizinski2/Dev/tidycreel/sample_data/interviews.csv` - Interview data structure

### Secondary (MEDIUM confidence)

**Domain Knowledge:**
- `/Users/cchizinski2/Dev/tidycreel/inst/RATIO_ESTIMATORS_GUIDE.md` - Ratio estimator explanation
- `/Users/cchizinski2/Dev/tidycreel/creel_foundations.md` - Interview-based estimation overview

**Requirements:**
- `/.planning/REQUIREMENTS.md` - Phase 8 requirements (INTV-01 through INTV-06)

### Tertiary (LOW confidence)

None - all research based on existing code and established patterns.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Reusing existing v0.1.0 dependencies, no new packages
- Architecture: HIGH - Mirroring proven add_counts() pattern
- Pitfalls: HIGH - Based on add_counts() experience and literature review

**Research date:** 2026-02-09
**Valid until:** 60 days (stable domain, mature dependencies)

---

## RESEARCH COMPLETE

**Phase:** 08 - Interview Data Integration
**Confidence:** HIGH

### Key Findings

1. **Zero new dependencies** - Phase 8 reuses all v0.1.0 infrastructure (survey, tidyselect, checkmate, cli)
2. **Mirror add_counts() exactly** - User consistency is north star; same parameters, same validation, same errors
3. **Dual survey object storage** - Keep count_survey and interview_survey separate until Phase 11 combines them
4. **Validate at attachment time** - Eager validation prevents estimation-time surprises (v0.1.0 proven pattern)
5. **Interview type detection** - Store interview_type in design metadata for Phase 9 estimator dispatch

### File Created

`.planning/phases/08-interview-data-integration/08-RESEARCH.md`

### Confidence Assessment

| Area | Level | Reason |
|------|-------|--------|
| Standard Stack | HIGH | All dependencies already in v0.1.0 DESCRIPTION |
| Architecture | HIGH | Reusing proven add_counts() pattern line-by-line |
| Pitfalls | HIGH | Based on v0.1.0 experience and creel survey literature |

### Open Questions

1. Harvest column required vs optional (recommend: optional, error in Phase 10 if missing)
2. trip_complete column handling (recommend: use interview_type parameter, validate if column exists)
3. Time validation strictness (recommend: Tier 2 warning only)

### Ready for Planning

Research complete. Planner can now create PLAN.md files with specific tasks for:
- add_interviews() function following add_counts() pattern
- validate_interview_schema() extending count validation
- construct_interview_survey() for interview survey.design2 objects
- Tier 1 and Tier 2 validation for interview data
- Test suite mirroring test-add-counts.R structure
