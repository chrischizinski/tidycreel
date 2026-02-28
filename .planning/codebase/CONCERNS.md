# Codebase Concerns

**Analysis Date:** 2026-01-27

## Tech Debt

**Large Variance-Related Files (Complexity Risk):**
- Issue: Multiple files handling variance calculations are over 500 lines, risking maintenance complexity
- Files: `R/variance-decomposition.R` (1,101 lines), `R/variance-engine.R` (616 lines), `R/variance-decomposition-engine.R` (522 lines)
- Impact: Difficult to navigate, increased risk of bugs in complex variance logic, challenging to onboard new contributors
- Fix approach: Refactor into focused modules with clearer responsibility boundaries; consider splitting variance-decomposition.R into 2-3 smaller files focusing on specific tasks (component extraction, allocation optimization, ICC calculation)

**Zero/Negative Effort Value Handling:**
- Issue: `R/est-cpue.R` silently converts zero/negative effort to 0.001 (line 118) after warning, which masks data quality issues
- Files: `R/est-cpue.R` (lines 107-118)
- Impact: Creates artificial CPUE estimates; users may not realize their data has been modified; can propagate bad estimates downstream
- Fix approach: Instead of silent conversion, provide options to filter data, raise errors on critical thresholds, or require explicit handling; document the conversion with result metadata

**Deprecated Function Stubs Not Fully Removed:**
- Issue: Old API functions (`estimate_effort`, `estimate_cpue`, `estimate_harvest`) exist as abort stubs in `R/estimators.R` (lines 13-37) pointing to new functions
- Files: `R/estimators.R` (lines 13-37)
- Impact: Dead code in exported API; takes up NAMESPACE space; may confuse users encountering help for deprecated functions
- Fix approach: Remove completely from package, document migration path in DEPRECATED.md or vignette only; use lifecycle package for proper deprecation tracking

**Legacy Code Directory Not Cleaned:**
- Issue: `old_code/` directory contains 7+ archived files from previous development phases (CreelAnalysisFunctions.R, CreelDataAccess.R, etc.) still in repository
- Files: `old_code/` directory (100+ KB of historical code)
- Impact: Confusion about what's active; potential for accidental reference to obsolete patterns; increases repository size
- Fix approach: Archive to separate `archived/` branch or external storage; remove from main branch after confirming no active imports

## Known Bugs

**Variance Method Fallback Naming Inconsistency:**
- Symptoms: When variance method fails (e.g., bootstrap on simple design), fallback to "survey" but method_details shows both requested_method and fallback flags
- Files: `R/variance-engine.R`, validated in `tests/testthat/test-critical-bugfixes.R` (lines 36-77)
- Trigger: Call `est_cpue(..., variance_method = "bootstrap")` on simple design without replicates
- Workaround: Check `variance_info$method_details$fallback` in results to detect fallback occurred
- Fix: Already addressed in test suite; ensure documentation clarifies fallback behavior

**Group Data Extraction Fallback Path in est_cpue:**
- Symptoms: Comment on line 143 states "shouldn't happen with fixed variance engine" but fallback code exists
- Files: `R/est-cpue.R` (lines 140-150, 208-219)
- Trigger: Variance engine returns NULL `group_data`
- Workaround: Function attempts to reconstruct from unique values
- Fix: Remove fallback if variance engine is guaranteed to provide group_data; otherwise document when fallback activates

**.interview_id Collision Risk:**
- Symptoms: Creating temporary .cpue_ratio and .cpue variables during estimation could collide if user data contains these exact names
- Files: `R/est-cpue.R` (lines 125, 194)
- Trigger: User has columns named ".cpue_ratio" or ".cpue"
- Workaround: None in current code
- Fix: Use unique internal namespace like `.tc_cpue_ratio_` and `.tc_cpue_value_` with descriptive suffixes; test with mock data containing these names

## Security Considerations

**No Validation of Design Object Contents:**
- Risk: Functions accept `svydesign`/`svrepdesign` but don't validate that required variables exist in design$variables
- Files: `R/est-cpue.R`, `R/est-effort-*.R` functions (all estimators)
- Current mitigation: `tc_interview_svy()` helper and `tc_abort_missing_cols()` catch missing columns at runtime
- Recommendations:
  - Add pre-flight validation in entry point functions to fail fast with clear messages
  - Document assumptions about design object structure in function headers
  - Create validation helper `tc_validate_design_structure()` used consistently

**No Bounds Checking on Confidence Levels:**
- Risk: Functions accept any `conf_level` without validation (0 to 1 range)
- Files: All estimator functions accept `conf_level` parameter
- Current mitigation: Functions pass to internal variance engine which uses for z-score calculation
- Recommendations: Add validation that `conf_level` is numeric, 0 < conf_level < 1; provide helpful error message for common mistakes (e.g., conf_level=95 instead of 0.95)

## Performance Bottlenecks

**Grouped Variance Computation Using Unique Values:**
- Problem: `est_cpue.R` line 146 uses `unique(svy_ratio$variables[[v]])` to extract group values, which is inefficient for large datasets
- Files: `R/est-cpue.R` (lines 144-150), similar patterns in other estimators
- Cause: Sequential unique extraction instead of using variance engine's pre-computed group_data
- Improvement path: Verify variance engine always returns group_data with aligned ordering; if not, cache unique values once and join

**Variance Decomposition Iterative Fitting:**
- Problem: `variance-decomposition.R` (1,101 lines) performs iterative variance component estimation which can be slow on large datasets
- Files: `R/variance-decomposition.R` (entire file)
- Cause: Component estimation uses iterative algorithms; no obvious parallelization or caching
- Improvement path: Profile to identify exact bottlenecks; consider parallel option for bootstrap replicates; cache intermediate results for repeated calls

**Nested dplyr Group Operations:**
- Problem: `est-cpue.R` lines 160-162 and 229-231 perform grouping twice (once in variance engine, once to compute n)
- Files: `R/est-cpue.R` (lines 160-163, 229-232)
- Cause: Variance engine doesn't return sample sizes, requiring separate grouping operation
- Improvement path: Extend `tc_compute_variance()` to return `n` within group_data, eliminating duplicate grouping

## Fragile Areas

**Variance Engine Fallback Behavior:**
- Files: `R/variance-engine.R`, tested in `tests/testthat/test-critical-bugfixes.R`
- Why fragile: Multiple fallback paths for bootstrap/jackknife/svyrecvar; if survey package internals change, fallback logic may break
- Safe modification: Add comprehensive tests for each fallback scenario before any changes to variance method selection; document fallback decision tree explicitly
- Test coverage: `test-critical-bugfixes.R` covers basic cases but missing edge cases (e.g., single stratum with replicate design)

**Design Assumptions in Estimator Functions:**
- Files: `R/est-cpue.R`, `R/est-effort-*.R`, `R/est-total-harvest.R`
- Why fragile: Functions assume survey design objects contain specific variables (e.g., "date", "shift_block") but don't validate upstream
- Safe modification: Add explicit validation at function entry; document required variable structure
- Test coverage: Tests use well-formed toy data; missing tests with minimal variable sets

**qa_check_effort Outlier Detection:**
- Files: `R/qa-check-effort.R` (lines 46-59 describe logic, implementation spans file)
- Why fragile: Outlier thresholds (max_hours=24, min_hours=0.1) are hardcoded; no sensitivity analysis for different fishing contexts
- Safe modification: Make thresholds parameters with documented defaults; add warnings if thresholds seem inappropriate for data range
- Test coverage: Basic checks present; missing tests for edge cases (e.g., multi-day trips, international contexts with different hour conventions)

**Grouped Estimation with Missing Groups:**
- Files: All estimators using `by` parameter
- Why fragile: If some grouping variable combinations have zero observations, `svyby` behavior may differ from expectations
- Safe modification: Test with sparse group combinations; explicitly document how NA/missing group combinations are handled
- Test coverage: Needs tests specifically for sparse grouping scenarios

## Scaling Limits

**Memory Usage with Large Bootstrap Replicates:**
- Current capacity: Bootstrap variance with n_replicates=1000 (default) on 100K interview records
- Limit: Memory scales with replicates × observations; 10K replicates on 1M records may exhaust RAM on standard machines
- Scaling path: Implement streaming/chunked bootstrap; add memory estimate before computation; provide progress reporting for long-running variance calculations

**Variance Decomposition Nested Structure Handling:**
- Current capacity: Decomposition works for 3-4 nesting levels (e.g., stratum > day > shift > count)
- Limit: Exponential complexity as nesting depth increases; sparse groups at deeper levels
- Scaling path: Add option to drop sparsely-populated nesting levels; implement efficient sparse matrix representation

## Dependencies at Risk

**survey Package Internal Access:**
- Risk: `variance-engine.R` uses `survey:::svyrecvar` (private API) for "svyrecvar" variance method
- Impact: Survey package updates could break this method; no warning to users about private API usage
- Migration plan:
  - Document that svyrecvar method relies on private API (add @details note)
  - Monitor survey package releases for API changes
  - Consider alternative: publish accurate formula documentation so users can implement external if survey package API breaks
  - Add fallback to "survey" method if private API unavailable

**Implicit Dependency on dplyr Behavior:**
- Risk: Heavy use of dplyr::across, dplyr::all_of, group_by semantics throughout codebase
- Impact: Changes to dplyr semantics or deprecation could break grouping logic
- Migration plan: Test with each new dplyr release; avoid undocumented dplyr internal functions; pin dplyr version in DESCRIPTION if using cutting-edge features

## Missing Critical Features

**No Built-in Support for Replicate Weight Designs:**
- Problem: While code references `svrepdesign`, estimator functions don't explicitly handle replicate weight designs from creel surveys with bootstrap/jackknife
- Blocks: Advanced variance estimation with proper design-based replication; comparison of variance methods on same data
- Documentation: DESCRIPTION lists `survey` but no guidance on creating replicate designs from creel data

**No Confidence Interval Type Options:**
- Problem: All CIs use Wald method (normal approximation); no support for profile, percentile, or BCa bootstrap intervals
- Blocks: Analysts with non-normal distributions or extreme proportions can't get appropriate coverage
- Fix approach: Extend `tc_compute_variance()` to accept `ci_type` parameter; implement bootstrap profile intervals

**No Explicit Finite Population Correction Toggle:**
- Problem: Variance functions don't expose finite population correction (fpc) options despite supporting survey designs with fpc
- Blocks: Analysts working with exhaustive surveys or known population sizes can't reduce variance using FPC
- Fix approach: Add `fpc` parameter to estimators; document how to specify in survey design

## Test Coverage Gaps

**Zero/Missing Effort Scenarios:**
- What's not tested: Comprehensive behavior when effort_col contains zeros, NAs, negative values
- Files: `R/est-cpue.R` (effort handling), `R/qa-check-effort.R` (validation)
- Risk: Silent conversion of zero effort to 0.001 may mask data quality issues; tests don't verify warning message content or behavior across different value patterns
- Priority: **High** - CPUE calculations depend critically on effort column validity

**Sparse Grouping Variable Scenarios:**
- What's not tested: Group combinations with single observations, entirely missing groups, or groups appearing in one stratum but not another
- Files: All estimators using `by` parameter
- Risk: Variance estimation may fail or produce unexpected results with sparse groups
- Priority: **High** - Real data often has sparse group structures

**Fallback Behavior Edge Cases:**
- What's not tested: Bootstrap fallback when design has no replicate information; jackknife on very small samples; svyrecvar on complex designs
- Files: `R/variance-engine.R` fallback paths
- Risk: Users may get results with wrong variance method without realizing
- Priority: **Medium** - Affects result reliability but tests do cover basic fallback

**Architectural Compliance:**
- What's not tested: Verification that no new functions bypass `tc_compute_variance()` for variance calculations
- Files: All R/ files
- Risk: Divergence from single-source-of-truth principle if new estimators added without core engine
- Priority: **High** - Architecture maintenance; test-architectural-compliance.R mentioned in ARCHITECTURAL_STANDARDS.md but not found in standard location
- Note: `PREVENTING_DIVERGENCE_SUMMARY.md` references `tests/testthat/test-architectural-compliance.R` but verify it exists and is comprehensive

---

*Concerns audit: 2026-01-27*
