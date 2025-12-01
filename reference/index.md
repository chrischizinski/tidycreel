# Package index

## All functions

- [`acres_to_hectares()`](acres_to_hectares.md) : Convert acres to
  hectares
- [`aggregate_cpue()`](aggregate_cpue.md) : Aggregate CPUE Across
  Species (REBUILT with Native Survey Integration)
- [`as_day_svydesign()`](as_day_svydesign.md) : Construct a day-level
  survey design for aerial estimation
- [`as_survey_design()`](as_survey_design.md) : Extract survey design
  object from a creel_design
- [`as_svrep_design()`](as_svrep_design.md) : Extract replicate weights
  survey design from a repweights_design
- [`auxiliary_schema`](auxiliary_schema.md) : Auxiliary Data Schema
- [`calendar_schema`](calendar_schema.md) : Sampling Calendar Schema
- [`capwords()`](capwords.md) : Capitalize words
- [`change_na()`](change_na.md) : Change NA or specific values to a
  target
- [`convertToLogical()`](convertToLogical.md) : Convert to logical
  (compat)
- [`count_schema`](count_schema.md) : Instantaneous Count Schema
- [`decompose_variance()`](decompose_variance.md) : Decompose Variance
  Components in Creel Survey Estimates
- [`design-constructors`](design-constructors.md)
  [`design_repweights`](design-constructors.md) : Survey Design
  Constructors for Access-Point Creel Surveys
- [`design_access()`](design_access.md) : Create Access-Point Survey
  Design (lean container)
- [`design_busroute()`](design_busroute.md) : Create Bus Route Survey
  Design
- [`design_roving()`](design_roving.md) : Create Roving Survey Design
  (lean container)
- [`est_catch()`](est_catch.md) : Catch/Harvest Total Estimator
  (survey-first)
- [`est_cpue()`](est_cpue.md) : CPUE Estimator (REBUILT with Native
  Survey Integration)
- [`est_cpue_roving()`](est_cpue_roving.md) : Estimate CPUE for Roving
  Creel Surveys (Pollock et al. 1997)
- [`est_effort()`](est_effort.md) : Estimate Fishing Effort
  (survey-first wrapper)
- [`est_effort.aerial()`](est_effort.aerial.md) : Aerial Effort
  Estimator (REBUILT with Native Survey Integration)
- [`est_effort.busroute_design()`](est_effort.busroute_design.md) :
  Bus-Route Effort Estimation (REBUILT with Native Survey Integration)
- [`est_effort.instantaneous()`](est_effort.instantaneous.md) :
  Instantaneous Effort Estimator (REBUILT with Native Survey
  Integration)
- [`est_effort.progressive()`](est_effort.progressive.md) : Progressive
  (Roving) Effort Estimator (REBUILT with Native Survey Integration)
- [`est_total_harvest()`](est_total_harvest.md) : Estimate Total
  Harvest/Catch Using Product Estimator (REBUILT)
- [`estimate_cpue()`](estimate_cpue.md) : Estimate Catch Per Unit Effort
  (CPUE)
- [`estimate_effort()`](estimate_effort.md) : Estimate Fishing Effort
- [`estimate_harvest()`](estimate_harvest.md) : Estimate Total Harvest
- [`estimators`](estimators.md) : Core Estimators for Creel Survey
  Analysis
- [`hectares_to_acres()`](hectares_to_acres.md) : Convert hectares to
  acres
- [`interval_minutes()`](interval_minutes.md) : Calculate interval in
  minutes between two time columns
- [`interview_schema`](interview_schema.md) : Interview Data Schema
- [`is.even()`](is.even.md) : Even-number predicate
- [`na.return()`](na.return.md) : Replace NAs with a value (compat)
- [`optimal_allocation()`](optimal_allocation.md) : Calculate Optimal
  Sample Allocation
- [`parse_time_column()`](parse_time_column.md) : Parse time columns
  using lubridate
- [`plot(`*`<variance_decomp>`*`)`](plot.variance_decomp.md) : Plot
  Method for Variance Decomposition Results
- [`plot_design()`](plot_design.md) : Plot survey design structure
- [`plot_effort()`](plot_effort.md) : Plot effort estimates
- [`print(`*`<qa_checks_result>`*`)`](print.qa_checks_result.md) : Print
  method for QA check results
- [`print(`*`<variance_decomp>`*`)`](print.variance_decomp.md) : Print
  Method for Variance Decomposition Results
- [`qa_check_effort()`](qa_check_effort.md) : Check for Party-Level
  Effort Calculation Errors
- [`qa_check_missing()`](qa_check_missing.md) : Check for Missing Data
  Patterns
- [`qa_check_outliers()`](qa_check_outliers.md) : Check for Statistical
  Outliers in Survey Data
- [`qa_check_spatial_coverage()`](qa_check_spatial_coverage.md) : Check
  Spatial Coverage Completeness
- [`qa_check_species()`](qa_check_species.md) : Check for Species
  Identification Issues
- [`qa_check_targeting()`](qa_check_targeting.md) : Check for Targeting
  Bias (Successful Parties)
- [`qa_check_temporal()`](qa_check_temporal.md) : Check for Temporal
  Coverage Issues
- [`qa_check_units()`](qa_check_units.md) : Check for Mixed or
  Inconsistent Measurement Units
- [`qa_check_zeros()`](qa_check_zeros.md) : Check for Missing Zero
  Counts or Catches
- [`qa_checks()`](qa_checks.md) : Comprehensive Quality Assurance Checks
  for Creel Survey Data
- [`qc_report()`](qc_report.md) : Generate Comprehensive Quality Control
  Report
- [`reference_schema`](reference_schema.md) : Reference Table Schema
- [`report_dropped_rows()`](report_dropped_rows.md) : Report dropped
  rows
- [`roving_survey`](roving_survey.md) : Example Roving Survey Interview
  Data
- [`schema_test_runner()`](schema_test_runner.md) : Run All Schema
  Validation Functions
- [`standardize_time_columns()`](standardize_time_columns.md) :
  Standardize time column names using stringr
- [`survey-diagnostics`](survey-diagnostics.md) : Survey Design
  Diagnostics for tidycreel
- [`tc_abort_missing_cols()`](tc_abort_missing_cols.md) : Abort with a
  standardized message for missing columns (cli)
- [`tc_as_time()`](tc_as_time.md) : Utility: Parse to POSIXct
- [`tc_clamp01()`](tc_clamp01.md) : Clamp probabilities to (0,1\] with a
  warning
- [`tc_confint()`](tc_confint.md) : Utility: Confidence Interval Helper
- [`tc_decompose_variance()`](tc_decompose_variance.md) : Decompose
  Variance into Components
- [`tc_design_diagnostics()`](tc_design_diagnostics.md) : Survey Design
  Diagnostics
- [`tc_diag_drop()`](tc_diag_drop.md) : Utility: Diagnostics for Dropped
  Rows
- [`tc_drop_na_rows()`](tc_drop_na_rows.md) : Drop rows with missing
  values in required columns; return diagnostics
- [`tc_extract_design_info()`](tc_extract_design_info.md) : Extract
  Survey Design Information
- [`tc_group_warn()`](tc_group_warn.md) : Utility: Group Warn
- [`tc_guess_cols()`](tc_guess_cols.md) : Utility: Guess Columns
- [`tc_require_cols()`](tc_require_cols.md) : Utility: Require Columns
- [`tidycreel-compat-stubs`](tidycreel-compat-stubs.md) : Legacy stubs
  removed; not part of the package
- [`trim()`](trim.md) : Trim leading and trailing whitespace
- [`validate_allowed_values()`](validate_allowed_values.md) : Validate
  values in a column
- [`validate_auxiliary()`](validate_auxiliary.md) : Validate auxiliary
  data schema
- [`validate_calendar()`](validate_calendar.md) : Validate Calendar Data
- [`validate_counts()`](validate_counts.md) : Validate Count Data
- [`validate_interviews()`](validate_interviews.md) : Validate Interview
  Data
- [`validate_reference()`](validate_reference.md) : Validate reference
  table schema
- [`validate_required_columns()`](validate_required_columns.md) :
  Validate required columns in a data.frame
- [`variance-decomposition-engine`](variance-decomposition-engine.md) :
  Variance Decomposition Engine for tidycreel
- [`variance-engine`](variance-engine.md) : Core Variance Calculation
  Engine for tidycreel
