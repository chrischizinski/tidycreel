---
phase: 17-complete-trip-defaults
plan: 02
subsystem: estimation
tags: [cpue, diagnostic-mode, messaging, transparency, ux]

# Dependency graph
requires:
  - phase: 17-complete-trip-defaults
    plan: 01
    provides: use_trips parameter with complete-trip default
  - phase: 16-trip-truncation
    plan: 02
    provides: MOR truncation with messaging
  - phase: 15-mean-of-ratios-estimator-core
    plan: 02
    provides: MOR diagnostic mode foundation
provides:
  - Diagnostic comparison mode (use_trips='diagnostic')
  - Informative trip type selection messages
  - Transparent reporting of sample sizes and trip types
affects: [19-incomplete-trip-framework, phase-18]

# Tech tracking
tech-stack:
  added:
    - "creel_estimates_diagnostic S3 class"
  patterns:
    - "Recursive estimation for diagnostic comparison"
    - "cli::cli_inform() for informative messages"
    - "NULL default pattern to detect explicit parameter usage"
    - "Auto-adjust parameters based on user intent (estimator=mor → use_trips=incomplete)"

key-files:
  created:
    - "man/format.creel_estimates_diagnostic.Rd"
    - "man/print.creel_estimates_diagnostic.Rd"
  modified:
    - "R/creel-estimates.R"
    - "R/print-methods.R"
    - "tests/testthat/test-estimate-cpue.R"
    - "tests/testthat/test-creel-estimates.R"
    - "tests/testthat/test-estimate-total-catch.R"
    - "tests/testthat/test-estimate-harvest.R"

key-decisions:
  - "Diagnostic mode calls estimate_cpue recursively for both trip types"
  - "Comparison table includes difference and ratio metrics"
  - "Interpretation guidance uses 10% threshold for 'substantial difference'"
  - "use_trips default changed from 'complete' to NULL to track explicit usage"
  - "estimator='mor' auto-switches to use_trips='incomplete' for backward compatibility"
  - "Messages use cli::cli_inform() (informative, not warnings)"
  - "Messages show [default] when use_trips not explicitly specified"

patterns-established:
  - "Diagnostic comparison pattern for estimator validation"
  - "Informative messaging with sample size transparency"
  - "Auto-parameter adjustment based on user intent"

# Metrics
duration: 14min
completed: 2026-02-15
---

# Phase 17 Plan 02: Diagnostic Comparison & Informative Messaging Summary

**Diagnostic mode enables complete vs incomplete trip comparison with difference metrics and interpretation guidance, plus transparent messaging about trip type selection and sample sizes**

## Performance

- **Duration:** 14 min (887 seconds)
- **Started:** 2026-02-15T21:04:24Z
- **Completed:** 2026-02-15T21:19:11Z
- **Tasks:** 2 (diagnostic mode + messaging)
- **Files modified:** 6
- **Tests added:** 29 (22 diagnostic + 7 messaging)

## Accomplishments

### Diagnostic Comparison Mode
- Added `use_trips="diagnostic"` option to estimate_cpue()
- Returns creel_estimates_diagnostic object with comparison table
- Comparison includes both complete and incomplete estimates side-by-side
- Calculates difference metrics (diff = complete - incomplete, ratio = complete / incomplete)
- Provides interpretation guidance based on 10% threshold
- Works with both ungrouped and grouped estimation
- Errors if either complete or incomplete trips missing
- Format/print methods produce clear comparison output

### Informative Messaging
- Added cli::cli_inform() messages for trip type selection
- Messages include: trip type, sample size (n), percentage of total, default vs explicit
- Changed use_trips default from "complete" to NULL to detect explicit usage
- Messages appear for all modes: complete (default), complete (explicit), incomplete, diagnostic
- Auto-adjust: when estimator="mor" with default use_trips, switches to "incomplete"

## Task Commits

Each task was committed atomically:

1. **Task 1: Diagnostic comparison mode** - `694837f` (feat)
2. **Task 2: Informative messaging** - `c92f09c` (feat)
3. **Deviation fix: Auto-adjust and test updates** - `7adf31e` (fix)

## Files Created/Modified

**Created:**
- `man/format.creel_estimates_diagnostic.Rd` - Documentation for diagnostic output formatting
- `man/print.creel_estimates_diagnostic.Rd` - Documentation for diagnostic print method

**Modified:**
- `R/creel-estimates.R` - Diagnostic mode, messaging, auto-adjust logic
- `R/print-methods.R` - format/print methods for diagnostic class
- `tests/testthat/test-estimate-cpue.R` - 29 new tests for diagnostic mode and messaging
- `tests/testthat/test-creel-estimates.R` - Updated MOR expectations for new filtering
- `tests/testthat/test-estimate-total-catch.R` - Updated test data for complete trip requirements
- `tests/testthat/test-estimate-harvest.R` - Updated expectations (harvest doesn't filter yet)

## Decisions Made

**Diagnostic Mode Design:**
- Recursive call pattern: call estimate_cpue() separately for complete and incomplete trips
- Comparison table includes all estimate columns plus trip_type
- Difference metrics: simple subtraction and ratio (complete / incomplete)
- Interpretation threshold: 10% of complete estimate for "substantial difference"
- For grouped estimation: within-group comparisons in single table

**Messaging Approach:**
- Use cli::cli_inform() (informative, not warning level)
- Show messages by default (tidyverse convention for data transformations)
- Users can suppress with suppressMessages() if desired
- Include [default] indicator when use_trips not explicitly set
- No messages when trip_status field absent (backward compatibility)

**Parameter Handling:**
- Changed use_trips default from "complete" to NULL
- NULL → "complete" conversion happens early, but tracked via use_trips_is_default flag
- When estimator="mor" and use_trips is default → auto-switch to "incomplete"
- This preserves backward compatibility for existing code using estimator="mor"

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Test data insufficient for new complete-trip default**
- **Found during:** Full test suite run after Task 2
- **Issue:** Tests designed for old behavior (all trips used) now fail because default filters to complete trips only, leaving insufficient sample sizes
- **Fix:**
  - Updated make_grouped_test_design() to create 20 interviews per group (10 complete + 10 incomplete) instead of random distribution
  - Updated MOR test expectations to reflect that n_total = n_incomplete after filtering
  - Updated estimate_harvest test to note different sample sizes (harvest doesn't have use_trips parameter yet)
  - Added auto-adjust logic: estimator="mor" with default use_trips → switches to "incomplete"
- **Files modified:** R/creel-estimates.R, tests/testthat/test-creel-estimates.R, tests/testthat/test-estimate-total-catch.R, tests/testthat/test-estimate-harvest.R
- **Commit:** 7adf31e

## Implementation Details

### Diagnostic Comparison Structure

```r
# Diagnostic mode returns:
list(
  comparison = data.frame(
    trip_type = c("complete", "incomplete"),
    estimate = c(...), se = c(...), ci_lower = c(...), ci_upper = c(...), n = c(...)
    # Plus grouping columns if grouped estimation
  ),
  complete_result = <creel_estimates object>,
  incomplete_result = <creel_estimates_mor object>,
  diff_estimate = complete_est - incomplete_est,
  ratio_estimate = complete_est / incomplete_est,
  interpretation = "...",
  conf_level = 0.95,
  by_vars = NULL or c("group_col")
)
# Class: c("creel_estimates_diagnostic", "list")
```

### Messaging Output Examples

**Default complete trips:**
```
i Using complete trips for CPUE estimation
  (n=20, 50% of 40 interviews) [default]
```

**Explicit incomplete trips:**
```
i Using incomplete trips for CPUE estimation
  (n=20, 50% of 40 interviews)
```

**Diagnostic mode:**
```
i Running diagnostic comparison
  Complete trips (n=20) vs Incomplete trips (n=20)
```

### Auto-Adjust Logic

When user specifies `estimator="mor"` without specifying `use_trips`:
1. Detects default use_trips (was NULL, now "complete")
2. Auto-switches to `use_trips="incomplete"`
3. Clears the `use_trips_is_default` flag
4. Proceeds with incomplete trip filtering and MOR estimation

This preserves backward compatibility with existing code like:
```r
estimate_cpue(design, estimator = "mor")  # Still works!
```

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

**Ready for Phase 18 (Trip Validation):**
- Diagnostic mode provides comparison foundation
- Messages provide transparency for validation decisions
- Auto-adjust logic makes API user-friendly

**Ready for Phase 19 (Incomplete Trip Framework):**
- Diagnostic comparison output structure ready for statistical tests
- Interpretation guidance references Phase 19 validation framework
- Print method mentions validate_incomplete_trips() function
- Difference and ratio metrics support equality testing

**Integration Points for Phase 19:**
- Diagnostic output can be enhanced with statistical test results
- Comparison table structure supports additional validation metrics
- Interpretation guidance can include p-values and effect sizes

## Testing Coverage

**Diagnostic Mode (22 tests):**
- Returns correct S3 class (creel_estimates_diagnostic)
- Comparison table has both trip types
- Includes all estimate columns (estimate, se, ci_lower, ci_upper, n)
- Calculates difference metrics (diff_estimate, ratio_estimate)
- Provides interpretation guidance
- Errors if complete trips missing
- Errors if incomplete trips missing
- Works with grouped estimation (within-group comparisons)
- Print method produces readable output

**Informative Messaging (7 tests):**
- Shows message for default complete trip usage (with [default])
- Shows message for explicit use_trips='complete' (no [default])
- Shows message for use_trips='incomplete'
- Shows message for diagnostic mode
- Messages include sample size (n) and percentage
- Indicates [default] only when use_trips not specified
- Messages can be suppressed with suppressMessages()

**Total test count:** 800 tests passing (29 new tests added)

---

*Phase: 17-complete-trip-defaults*
*Plan: 02*
*Completed: 2026-02-15*
