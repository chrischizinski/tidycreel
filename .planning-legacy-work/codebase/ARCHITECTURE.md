# Architecture

**Analysis Date:** 2026-01-27

## Pattern Overview

**Overall:** Layered, design-based survey analysis framework with strict separation between survey design construction, estimation, variance computation, and quality assurance.

**Key Characteristics:**
- **Survey-first workflow**: Data flows through explicit survey design objects (`svydesign`, `svrepdesign`) from the `survey` package
- **Single source of truth for variance**: All variance calculations route through `tc_compute_variance()` to prevent divergence
- **Functional decomposition**: Specialized functions handle specific estimation tasks (effort, CPUE, harvest) independently but consistently
- **Built-in features over wrappers**: Advanced features (variance methods, decomposition, diagnostics) are built directly into estimators, not added via wrapper functions
- **Schema-driven data validation**: Input data must conform to defined schemas (calendar, interview, count, auxiliary)

## Layers

**Data Input & Validation Layer:**
- Purpose: Accept, validate, and normalize raw survey data according to schemas
- Location: `R/data-schemas.R`, `R/utils-validate.R`
- Contains: Schema definitions, validation functions (`validate_calendar()`, `validate_interview()`, etc.)
- Depends on: dplyr, tibble, cli for data manipulation and messaging
- Used by: All downstream estimation and QA functions

**Survey Design Construction Layer:**
- Purpose: Create `svydesign`/`svrepdesign` objects from raw data and strata specifications
- Location: `R/design-constructors.R`, `R/design-aerial.R`, `R/design_busroute.R`
- Contains: Constructor functions (`design_access()`, `as_day_svydesign()`, `design_aerial()`, `design_busroute()`)
- Depends on: survey package, dplyr for aggregation
- Used by: Estimator functions that require explicit survey designs

**Estimation Layer:**
- Purpose: Calculate population parameters (effort totals, CPUE, harvest) with design-based variance
- Location: `R/est-effort-*.R`, `R/est-cpue.R`, `R/est-catch.R`, `R/est-total-harvest.R`, `R/est-cpue-roving.R`
- Contains: Estimator functions for specific designs and response variables
  - Instantaneous effort: `est_effort.instantaneous()` in `R/est-effort-instantaneous.R`
  - Progressive effort: `est_effort.progressive()` in `R/est-effort-progressive.R`
  - Aerial effort: `est_effort.aerial()` in `R/est-effort-aerial.R`
  - Bus route effort: `est_effort.busroute()` in `R/est-effort-busroute.R`
  - CPUE: `est_cpue()` in `R/est-cpue.R`
  - Roving CPUE: `est_cpue_roving()` in `R/est-cpue-roving.R`
  - Catch (harvest): `est_catch()` in `R/est-catch.R`
  - Total harvest: `est_total_harvest()` in `R/est-total-harvest.R`
- Depends on: survey package for `svytotal()`, `svyby()`, `svydesign()`; variance engine
- Used by: End users, vignettes, analysis pipelines

**Variance Computation Engine Layer:**
- Purpose: Compute variance estimates using multiple methods (survey, bootstrap, jackknife, linearization)
- Location: `R/variance-engine.R`
- Contains: Core variance function `tc_compute_variance()` handling method dispatch
- Depends on: survey package internals, bootstrap/resampling packages
- Used by: All estimators that report uncertainty

**Variance Decomposition Engine Layer:**
- Purpose: Break down total variance into components (within-day, among-day, stratum effects, etc.)
- Location: `R/variance-decomposition.R`, `R/variance-decomposition-engine.R`, `R/variance-decomposition-methods.R`
- Contains: Decomposition logic and method implementations
- Depends on: variance engine, variance methods
- Used by: Estimators when `decompose_variance = TRUE`, design optimization workflows

**Quality Assurance Layer:**
- Purpose: Detect common data quality issues before analysis
- Location: `R/qa-checks.R`, `R/qa-check-*.R` (effort, missing, outliers, spatial-coverage, species, targeting, temporal, units, zeros)
- Contains: Individual check functions and orchestrator (`qa_checks()`)
- Depends on: dplyr, stats for outlier detection, cli for messaging
- Used by: Data validation workflows, quality reporting

**Utility & Helper Layer:**
- Purpose: Provide reusable functions for time handling, data operations, survey extraction
- Location: `R/utils-*.R` (time, survey, validate, ops), `R/globals.R`
- Contains: Helper functions (`tc_interview_svy()`, `tc_extract_se()`, time parsing, etc.)
- Depends on: lubridate for date/time, rlang for operators
- Used by: All layers above

**Data Export & Reporting Layer:**
- Purpose: Generate outputs suitable for publication and reporting
- Location: `R/qc-report.R`, `R/plots.R`, `R/survey-diagnostics.R`
- Contains: Report generation, plotting, diagnostic summaries
- Depends on: ggplot2, plotly for visualization; tibble for tabular output
- Used by: End users for communication, markdown reports

## Data Flow

**Design-Based Estimation Pipeline:**

1. **Input Phase**: User provides raw survey data (interviews, counts, calendar)
   - `interviews` tibble with columns: interview_id, date, time_start/end, location, mode, party_size, hours_fished, catch totals
   - `counts` tibble with columns: date, location, mode, count value (anglers_count, parties_count), or catches by time interval
   - `calendar` tibble with columns: date, stratum_id, day_type, season, weekend, holiday, shift_block, target/actual sample

2. **Validation Phase**: Data conforms to schemas
   - `validate_calendar(calendar)` checks calendar structure
   - `validate_interview(interviews)` checks interview structure
   - QA checks detect quality issues before proceeding

3. **Design Construction Phase**: Survey design objects are created
   - `as_day_svydesign(calendar, day_id="date", strata_vars=c("weekend", "season"))` builds day-level PSU design
   - `design_access(interviews, calendar, locations, strata_vars)` builds interview-level design for access point surveys
   - Design object stores: strata definitions, weights, replicate weights (if applicable)

4. **Estimation Phase**: Population parameters are estimated
   - Estimator function (e.g., `est_effort.instantaneous()`) receives:
     - `svy`: survey design object
     - `counts` or data: expanded/aggregated counts data
     - `by`: grouping variables
     - `conf_level`, `variance_method`, `decompose_variance`, `design_diagnostics`: options
   - Function aggregates per-observation data to day/group level
   - Calls `survey::svytotal()` or `survey::svyby()` to compute estimates and design-based variance

5. **Variance Computation Phase**: Variance is calculated using specified method
   - `tc_compute_variance()` dispatcher selects method (survey, bootstrap, jackknife, linearization)
   - Survey method uses survey package variance calculation
   - Bootstrap/Jackknife resample design structure and recalculate estimates
   - Returns variance, standard error, design effect

6. **Variance Decomposition Phase** (optional): Variance components are estimated
   - `tc_decompose_variance()` breaks total variance into sources
   - Models hierarchical structure (stratum → day → shift → observation)
   - Estimates intraclass correlations and design effects
   - Returns component table, proportions, ICC, optimal allocation recommendations

7. **Design Diagnostics Phase** (optional): Design quality is assessed
   - Singleton stratum detection
   - Weight distribution analysis
   - Sample size adequacy checks
   - Recommendations for design improvements

8. **Output Phase**: Results are returned as tibble
   - Columns: grouping variables, estimate, se, ci_low, ci_high, deff, n, method
   - Optional `variance_info` list-column containing variance details, decomposition, diagnostics
   - Results ready for publication, plotting, or further analysis

**State Management:**
- Immutable data frames flow through the pipeline (no in-place modification)
- Survey design objects (created by survey package) are passed explicitly to estimators
- Estimates are computed fresh each time (no caching of variance calculations)
- Results are returned as clean tibbles, user can store for downstream use

## Key Abstractions

**Survey Design Object** (`svydesign`, `svrepdesign`):
- Purpose: Encapsulates probability sampling structure (strata, clusters, weights)
- Location: Created in constructors (`design-constructors.R`, etc.), used in estimators
- Pattern: S3 object from survey package; contains data + design metadata
- Example: `design <- as_day_svydesign(calendar, day_id="date", strata_vars=c("weekend", "season"))`

**Creel Design Object** (`creel_design`):
- Purpose: Container for all design components (interviews, calendar, design objects, metadata)
- Location: Created in `design-constructors.R`, methods in `design-constructors.R`
- Pattern: S3 list with named components: `interviews`, `calendar`, `design_weights`, `strata_vars`, `metadata`
- Usage: Legacy pattern (now discouraged in favor of explicit svydesign + separate data)

**Estimator Functions** (e.g., `est_effort.instantaneous()`):
- Purpose: Single-purpose functions that compute specific population parameters
- Pattern: Accept survey design + data, return tibble with estimate + uncertainty
- Built-in features: variance methods, decomposition, diagnostics (not added via wrappers)
- Example: `est_effort.instantaneous(svy, counts, by, variance_method="survey", decompose_variance=TRUE)`

**Variance Info List-Column**:
- Purpose: Package variance details into result rows for downstream reference
- Pattern: Tibble column of type `list` containing variance metadata
- Contents: variance estimate, method used, method details, decomposition (if computed), diagnostics (if computed)
- Used by: QC reporting, variance sensitivity analysis, design optimization

## Entry Points

**High-Level Workflow Entry Point:**
- Location: Vignettes in `vignettes/` (e.g., `getting-started.Rmd`, `effort_design_based.Rmd`)
- Triggers: User loads tidycreel, reads documentation
- Responsibilities: Demonstrate typical workflows, show best practices, illustrate design choices

**Design Construction Entry Point:**
- Location: `R/design-constructors.R` → `as_day_svydesign()`, `design_access()`
- Triggers: User has raw calendar/interview data and needs to create survey design
- Responsibilities: Validate inputs, create strata, calculate weights, return `svydesign` object

**Estimation Entry Point:**
- Location: `R/estimators.R` → `est_effort()` (main dispatcher), or specific estimator functions
- Triggers: User has survey design + count/interview data, wants population estimate
- Responsibilities: Route to appropriate estimator (instantaneous, progressive, etc.), aggregate data, compute estimate and variance, return results

**QA Entry Point:**
- Location: `R/qa-checks.R` → `qa_checks()`
- Triggers: User has raw survey data and wants quality assessment
- Responsibilities: Run specified quality checks, score overall quality, return issues and recommendations

**Reporting Entry Point:**
- Location: `R/qc-report.R` → `qc_report()`, `R/plots.R` → plotting functions
- Triggers: User has estimation results and wants visualization/summary
- Responsibilities: Generate summary tables, plots, diagnostic visualizations

## Error Handling

**Strategy:** Fail fast with informative messages using `cli` package for consistent error communication.

**Patterns:**
- Schema validation: `cli::cli_abort()` when required columns missing (e.g., in `validate_calendar()`)
- Design validation: `cli::cli_abort()` when design object missing required components (e.g., in `tc_interview_svy()`)
- Input validation: `cli::cli_warn()` when optional columns missing, `cli::cli_abort()` when required columns missing
- Deprecation: `cli::cli_abort()` with migration guidance for deprecated functions (e.g., `estimate_effort()` directs to `est_effort()`)

**Example** from `R/design-constructors.R`:
```r
if (!inherits(design, "creel_design")) {
  cli::cli_abort(c(
    "x" = "Object must be a creel_design",
    "i" = "Use design_access() or similar constructor to create valid design"
  ))
}
```

## Cross-Cutting Concerns

**Logging:**
- Approach: `cli` package for user-facing messages; structured messages for errors/warnings
- Usage: Input validation, design construction status, estimation progress
- Located in: All estimator and utility functions

**Validation:**
- Approach: Schema-based (check required columns, data types, ranges)
- Pattern: Validator functions in `R/utils-validate.R` and `R/data-schemas.R`
- Applied at: Data input, survey design creation, estimator execution

**Authentication:** Not applicable (R package, no external services)

**State Consistency:**
- Approach: Immutable data flows through pure functions; survey design objects hold state
- Rule: Estimators never modify input data or design objects
- Enforcement: Data returned as new tibbles; no in-place modifications

**Design Integrity:**
- Approach: Single source of truth for variance via `tc_compute_variance()`
- Rule: No parallel implementations of variance calculation
- Enforcement: Architectural standard documented in `ARCHITECTURAL_STANDARDS.md`, enforced in code review

---

*Architecture analysis: 2026-01-27*
