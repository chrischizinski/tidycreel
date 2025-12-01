# Implementation Plan: Quality Assurance / Quality Control Framework
## Detecting Common Creel Survey Mistakes (Table 17.3)

**Created:** 2025-10-24
**Priority:** P0 (Highest - Critical Gap)
**Estimated Effort:** 2-3 weeks
**Target Sprint:** Sprint 1-2

---

## Executive Summary

This plan implements a **comprehensive QA/QC framework** to detect and report the 10 common mistakes identified in Table 17.3 of the creel survey chapter. Quality assurance and quality control are critical for accurate creel surveys, yet no existing R package provides systematic validation tools for this purpose.

**Key Components:**
1. Automated detection of 10 common mistakes (Table 17.3)
2. Comprehensive QA/QC report generation
3. Data validation workflows
4. Diagnostic visualizations
5. User-friendly error messages with remediation guidance

---

## Table 17.3: Ten Common Mistakes

| # | Mistake | Influence on Estimates | Detection Method |
|---|---------|----------------------|------------------|
| 1 | **Skipping zeros for counts or catches** | Overestimates total effort, total catch, and total harvest | Check for missing zero counts/catches |
| 2 | **Targeting successful parties** (e.g., interviews at fish-cleaning stations) | Overestimates catch/harvest rates, total catch/harvest | Examine interview location patterns |
| 3 | **Tendency to measure biggest fish** in subsamples of harvested fish | Overestimates size structure of harvested fish | Compare size distributions |
| 4 | **Counts not covering entire waterbody** | Unrepresentative sample creates unknown bias | Check spatial coverage |
| 5 | **Interviews not covering entire waterbody** or not including all groups | Unrepresentative sample creates unknown bias | Check coverage and exclusions |
| 6 | **Mixing units of measures** (inches vs mm) or mixing precision levels | Variability in precision creates unknown bias | Detect mixed measurement units |
| 7 | **Species misidentification by anglers** | Creates unknown bias if misidentification rate unknown | Flag suspicious species combinations |
| 8 | **Over/under estimation of party-level effort** | Under/overestimates catch/harvest rates | Validate effort calculations |
| 9 | **Lack of standardized training** of creel clerks | Potential loss of data | Check inter-interviewer consistency |
| 10 | **Failure to follow QA-QC protocols** | Inaccurate data creates unknown bias | This entire framework! |

---

## Current State Analysis

### What We Have ✅

**File:** `R/tc-abort-missing-cols.R` and other validation helpers

```r
tc_abort_missing_cols()  # Check for missing columns
tc_group_warn()          # Validate grouping variables
```

**Existing Capabilities:**
- Basic schema validation (required columns present)
- Grouping variable existence checks
- Some data type validation

**Limitations:**
- No systematic QA/QC framework
- No detection of Table 17.3 mistakes
- No comprehensive reporting
- No inter-interviewer consistency checks
- No spatial coverage validation
- No catch rate outlier detection

---

## Implementation Specification

### Phase 1: Core QA/QC Functions 🔍

#### Function 1.1: `qa_check_zeros()`

**Purpose:** Detect Mistake #1 - Skipping zeros for counts or catches

**New File:** `R/qa-check-zeros.R` (~150 lines)

```r
#' Check for Missing Zero Counts or Catches
#'
#' Detects potential skipping of zeros in count or interview data, which
#' leads to overestimation of effort, catch, and harvest. This is one of
#' the most common and serious creel survey errors (Table 17.3, #1).
#'
#' @param data Count data (for counts) or interview data (for catches)
#' @param type Type of data: `"counts"` or `"interviews"`
#' @param date_col Column containing dates
#' @param location_col Column containing locations
#' @param value_col Column containing counts or catches
#' @param expected_coverage Proportion of sampling frame expected to have data
#'   (default 0.95 for counts, 0.7 for interviews). If actual coverage is
#'   below this, a warning is issued.
#'
#' @return List with:
#'   - `issue_detected`: Logical, TRUE if potential zero-skipping detected
#'   - `severity`: "high", "medium", "low", or "none"
#'   - `missing_dates`: Dates that should have data but don't
#'   - `missing_locations`: Locations that should have data but don't
#'   - `missing_combinations`: Date-location combinations missing
#'   - `coverage_rate`: Proportion of expected observations present
#'   - `recommendation`: Text guidance for remediation
#'
#' @details
#' ## Detection Logic
#'
#' **For Counts:**
#' 1. Identify sampling frame (all dates-locations that should be sampled)
#' 2. Check which combinations are missing
#' 3. Flag if coverage < expected_coverage threshold
#' 4. Report missing dates and locations
#'
#' **For Interviews:**
#' 1. Check for suspiciously low proportion of zero catches
#' 2. Compare to expected zero-inflation rate (varies by fishery)
#' 3. Examine interviewer-specific zero rates
#' 4. Flag interviewers with unusually low zero rates
#'
#' ## Severity Levels
#' - **High:** Coverage < 70% or zero rate < 10% (for interviews)
#' - **Medium:** Coverage 70-90% or zero rate 10-30%
#' - **Low:** Coverage > 90% or zero rate 30-50%
#' - **None:** No issues detected
#'
#' @examples
#' \dontrun{
#' library(tidycreel)
#'
#' # Check count data for missing zeros
#' qa_counts <- qa_check_zeros(
#'   counts,
#'   type = "counts",
#'   date_col = "date",
#'   location_col = "location",
#'   value_col = "count"
#' )
#'
#' if (qa_counts$issue_detected) {
#'   print(qa_counts$recommendation)
#' }
#'
#' # Check interview data for skipped zero catches
#' qa_interviews <- qa_check_zeros(
#'   interviews,
#'   type = "interviews",
#'   date_col = "interview_date",
#'   value_col = "catch_total"
#' )
#' }
#'
#' @references
#' *Analysis and Interpretation of Freshwater Fisheries Data, 2nd Edition.*
#' Chapter 17: Creel Surveys, Table 17.3.
#'
#' @export
qa_check_zeros <- function(
  data,
  type = c("counts", "interviews"),
  date_col = "date",
  location_col = "location",
  value_col = NULL,
  expected_coverage = NULL
) {
  # Implementation in Phase 1
}
```

**Implementation Steps:**

1. Validate inputs (~30 lines)
2. Identify sampling frame - expected observations (~40 lines)
3. Check for missing combinations (~40 lines)
4. Calculate coverage rate and zero rate (~20 lines)
5. Determine severity level (~10 lines)
6. Generate recommendation text (~10 lines)

---

#### Function 1.2: `qa_check_targeting()`

**Purpose:** Detect Mistake #2 - Targeting successful parties

**New File:** `R/qa-check-targeting.R` (~180 lines)

```r
#' Check for Targeting Bias (Successful Parties)
#'
#' Detects potential targeting of successful fishing parties, which occurs
#' when interviewers preferentially interview anglers with visible fish
#' (e.g., at fish-cleaning stations). This leads to overestimation of catch
#' and harvest rates (Table 17.3, #2).
#'
#' @param interviews Interview data
#' @param catch_col Column containing catch counts
#' @param location_col Column containing interview locations (optional)
#' @param interviewer_col Column containing interviewer IDs (optional)
#' @param success_threshold Proportion of non-zero catches above which
#'   targeting is suspected (default 0.90)
#'
#' @return List with QA results including severity, statistics, and recommendations
#'
#' @details
#' ## Detection Logic
#'
#' 1. **Overall Success Rate:**
#'    - Calculate proportion of interviews with catch > 0
#'    - Flag if success rate > success_threshold (default 90%)
#'    - Natural fisheries typically have 30-70% success rates
#'
#' 2. **Location-Specific Targeting:**
#'    - Identify "fish-cleaning stations" or high-success locations
#'    - Flag locations with >95% success rate
#'    - Check if these locations are overrepresented in sample
#'
#' 3. **Interviewer Bias:**
#'    - Compare success rates among interviewers
#'    - Flag interviewers with significantly higher success rates
#'    - Use chi-square test for independence
#'
#' 4. **Temporal Patterns:**
#'    - Check if interviews cluster at end of day (when fish visible)
#'    - Examine interview time distributions
#'
#' @export
qa_check_targeting <- function(
  interviews,
  catch_col = "catch_total",
  location_col = NULL,
  interviewer_col = NULL,
  success_threshold = 0.90
) {
  # Implementation
}
```

---

#### Function 1.3: `qa_check_size_bias()`

**Purpose:** Detect Mistake #3 - Tendency to measure biggest fish

**New File:** `R/qa-check-size-bias.R` (~200 lines)

```r
#' Check for Size Measurement Bias
#'
#' Detects potential bias toward measuring largest fish in harvest, which
#' overestimates size structure (Table 17.3, #3).
#'
#' @param interviews Interview data with length measurements
#' @param length_col Column containing fish lengths
#' @param catch_kept_col Column containing harvest counts
#' @param num_measured_col Column containing number of fish measured (optional)
#' @param species_col Column for species-specific analysis (optional)
#'
#' @return List with QA results
#'
#' @details
#' ## Detection Logic
#'
#' 1. **Subsample Representativeness:**
#'    - Compare # fish measured vs # fish harvested
#'    - Flag if always measuring exactly 1 fish when harvest > 1
#'    - Check for pattern "1 measured out of 5 kept" repeatedly
#'
#' 2. **Size Distribution Skew:**
#'    - Examine length frequency distribution
#'    - Flag if distribution is heavily right-skewed (only large fish)
#'    - Compare to expected distributions for species
#'
#' 3. **Interviewer Consistency:**
#'    - Compare size distributions among interviewers
#'    - Flag interviewers with significantly larger mean lengths
#'
#' 4. **Measurement Protocol:**
#'    - Check if subsampling protocol is documented
#'    - Recommend random selection when subsampling
#'
#' @export
qa_check_size_bias <- function(
  interviews,
  length_col = "length_mm",
  catch_kept_col = "catch_kept",
  num_measured_col = NULL,
  species_col = NULL
) {
  # Implementation
}
```

---

#### Function 1.4: `qa_check_spatial_coverage()`

**Purpose:** Detect Mistakes #4 & #5 - Incomplete spatial coverage

**New File:** `R/qa-check-spatial-coverage.R` (~220 lines)

```r
#' Check Spatial Coverage Completeness
#'
#' Detects incomplete spatial coverage for both counts and interviews,
#' which creates unrepresentative samples and unknown bias (Table 17.3, #4-5).
#'
#' @param data Count or interview data
#' @param locations_expected Character vector of all locations that should be sampled
#' @param location_col Column containing location names
#' @param date_col Column containing dates
#' @param type Data type: "counts" or "interviews"
#' @param min_coverage Minimum acceptable coverage proportion (default 0.90)
#'
#' @return List with spatial coverage analysis
#'
#' @details
#' ## Detection Logic
#'
#' 1. **Location Coverage:**
#'    - Check which expected locations are missing
#'    - Calculate proportion of locations covered
#'    - Flag if coverage < min_coverage
#'
#' 2. **Temporal Coverage by Location:**
#'    - Check if each location is sampled throughout season
#'    - Identify locations with gaps in temporal coverage
#'
#' 3. **Effort Allocation:**
#'    - Compare sample sizes among locations
#'    - Flag locations with very low sample sizes
#'    - Recommend proportional or optimal allocation
#'
#' 4. **Interviewer Coverage:**
#'    - Check if interviewers cover all locations
#'    - Flag if certain interviewers only work certain sites
#'
#' @export
qa_check_spatial_coverage <- function(
  data,
  locations_expected,
  location_col = "location",
  date_col = "date",
  type = c("counts", "interviews"),
  min_coverage = 0.90
) {
  # Implementation
}
```

---

#### Function 1.5: `qa_check_exclusions()`

**Purpose:** Detect Mistake #5 (cont.) - Excluding groups of anglers

**New File:** `R/qa-check-exclusions.R` (~180 lines)

```r
#' Check for Systematic Exclusion of Angler Groups
#'
#' Detects potential systematic exclusion of angler groups (e.g.,
#' non-English speaking anglers, certain demographics), which creates
#' unknown bias (Table 17.3, #5).
#'
#' @param interviews Interview data
#' @param refusal_col Column indicating interview refusals (optional)
#' @param language_col Column indicating angler language (optional)
#' @param demographics_cols Columns with demographic data (optional)
#' @param interviewer_col Column with interviewer ID
#' @param max_refusal_rate Maximum acceptable refusal rate (default 0.10)
#'
#' @return List with exclusion analysis
#'
#' @details
#' ## Detection Logic
#'
#' 1. **Refusal Rate:**
#'    - Calculate proportion of attempted interviews refused
#'    - Flag if refusal rate > max_refusal_rate
#'    - Compare refusal rates among interviewers
#'
#' 2. **Language Barriers:**
#'    - Check for documented language barriers
#'    - Flag if non-English speakers are systematically excluded
#'
#' 3. **Demographic Patterns:**
#'    - Examine demographic composition of sample
#'    - Compare to known angler population demographics
#'    - Flag suspicious patterns (e.g., 0% female anglers)
#'
#' 4. **Interviewer Selectivity:**
#'    - Compare interview patterns among interviewers
#'    - Flag interviewers with unusual refusal patterns
#'
#' @export
qa_check_exclusions <- function(
  interviews,
  refusal_col = NULL,
  language_col = NULL,
  demographics_cols = NULL,
  interviewer_col = NULL,
  max_refusal_rate = 0.10
) {
  # Implementation
}
```

---

#### Function 1.6: `qa_check_units()`

**Purpose:** Detect Mistake #6 - Mixing units of measure

**New File:** `R/qa-check-units.R` (~160 lines)

```r
#' Check for Mixed or Inconsistent Measurement Units
#'
#' Detects mixing of measurement units (inches vs mm) or precision levels,
#' which creates variability and unknown bias (Table 17.3, #6).
#'
#' @param interviews Interview data with measurements
#' @param length_col Column containing fish lengths
#' @param weight_col Column containing fish weights (optional)
#' @param species_col Column for species-specific checks (optional)
#'
#' @return List with unit consistency analysis
#'
#' @details
#' ## Detection Logic
#'
#' 1. **Unit Detection:**
#'    - Examine length value distributions
#'    - Detect likely inch measurements (values 5-30)
#'    - Detect likely mm measurements (values 150-800)
#'    - Flag if both present in same dataset
#'
#' 2. **Precision Detection:**
#'    - Check for inconsistent precision (mix of 10mm, 1mm, 0.1mm)
#'    - Recommend standardized precision levels
#'
#' 3. **Species-Specific:**
#'    - Flag suspicious length-species combinations
#'    - E.g., 500mm for a species typically 12" (impossible)
#'
#' 4. **Interviewer Patterns:**
#'    - Check if different interviewers use different units
#'    - Flag interviewer-specific unit preferences
#'
#' @export
qa_check_units <- function(
  interviews,
  length_col = "length_mm",
  weight_col = NULL,
  species_col = NULL
) {
  # Implementation
}
```

---

#### Function 1.7: `qa_check_species_id()`

**Purpose:** Detect Mistake #7 - Species misidentification

**New File:** `R/qa-check-species-id.R` (~180 lines)

```r
#' Check for Potential Species Misidentification
#'
#' Detects suspicious species identification patterns that may indicate
#' angler misidentification, which creates unknown bias (Table 17.3, #7).
#'
#' @param interviews Interview data with species information
#' @param species_col Column containing species names
#' @param length_col Column with lengths for size-species validation (optional)
#' @param location_col Column for location-species validation (optional)
#' @param valid_species Character vector of valid species for this fishery
#'
#' @return List with species ID validation results
#'
#' @details
#' ## Detection Logic
#'
#' 1. **Invalid Species Names:**
#'    - Check against valid_species list
#'    - Flag unrecognized species names
#'    - Suggest corrections for misspellings
#'
#' 2. **Size-Species Validation:**
#'    - Flag suspicious length-species combinations
#'    - E.g., 30" bluegill (likely misidentified bass)
#'    - Use species-specific length ranges
#'
#' 3. **Location-Species Validation:**
#'    - Flag species caught outside known range
#'    - E.g., saltwater species in freshwater
#'
#' 4. **Commonly Confused Species:**
#'    - Identify known confusion pairs (e.g., white bass vs white crappie)
#'    - Flag unusually high rates of rare species
#'
#' @export
qa_check_species_id <- function(
  interviews,
  species_col = "species",
  length_col = NULL,
  location_col = NULL,
  valid_species = NULL
) {
  # Implementation
}
```

---

#### Function 1.8: `qa_check_effort()`

**Purpose:** Detect Mistake #8 - Over/under estimation of party-level effort

**New File:** `R/qa-check-effort.R` (~200 lines)

```r
#' Check for Party-Level Effort Calculation Errors
#'
#' Detects potential errors in party-level effort calculations, which
#' under/overestimates catch and harvest rates (Table 17.3, #8).
#'
#' @param interviews Interview data
#' @param effort_col Column containing effort (angler-hours)
#' @param num_anglers_col Column containing number of anglers in party
#' @param hours_fished_col Column containing hours fished
#' @param party_id_col Column with party identifiers (optional)
#'
#' @return List with effort validation results
#'
#' @details
#' ## Detection Logic
#'
#' 1. **Effort Calculation Validation:**
#'    - Check if effort = num_anglers × hours_fished
#'    - Flag inconsistencies
#'    - Recommend correction formula
#'
#' 2. **Individual Effort Variation:**
#'    - Check for documented individual-level effort within parties
#'    - Flag if always assuming all anglers fished equal time
#'    - Recommend individual-level effort collection
#'
#' 3. **Outlier Detection:**
#'    - Identify unusually high/low effort values
#'    - Flag trips > 24 hours or < 0.1 hours
#'    - Check for decimal point errors (e.g., 0.5 entered as 5)
#'
#' 4. **Zero Effort with Catch:**
#'    - Flag records with catch > 0 but effort = 0 or missing
#'    - These create division-by-zero in CPUE calculations
#'
#' @export
qa_check_effort <- function(
  interviews,
  effort_col = "hours_fished",
  num_anglers_col = "num_anglers",
  hours_fished_col = NULL,
  party_id_col = NULL
) {
  # Implementation
}
```

---

#### Function 1.9: `qa_check_interviewer_consistency()`

**Purpose:** Detect Mistake #9 - Lack of standardized training

**New File:** `R/qa-check-interviewer-consistency.R` (~220 lines)

```r
#' Check Inter-Interviewer Consistency
#'
#' Detects inconsistencies among interviewers that indicate lack of
#' standardized training, leading to potential data loss (Table 17.3, #9).
#'
#' @param interviews Interview data
#' @param interviewer_col Column containing interviewer IDs
#' @param catch_col Column with catch data
#' @param effort_col Column with effort data
#' @param length_col Column with length measurements (optional)
#' @param location_col Column with locations (optional)
#'
#' @return List with inter-interviewer consistency analysis
#'
#' @details
#' ## Detection Logic
#'
#' 1. **Missing Data Rates:**
#'    - Calculate missing data proportions by interviewer
#'    - Flag interviewers with unusually high missing rates
#'    - Chi-square test for independence
#'
#' 2. **CPUE Consistency:**
#'    - Compare mean CPUE among interviewers
#'    - ANOVA to test for significant differences
#'    - Flag interviewers with extreme values
#'
#' 3. **Measurement Consistency:**
#'    - Compare length measurement rates by interviewer
#'    - Check if some interviewers never measure lengths
#'    - Compare mean lengths among interviewers (size bias)
#'
#' 4. **Interview Completeness:**
#'    - Calculate proportion of complete interviews by interviewer
#'    - Flag interviewers with low completion rates
#'
#' 5. **Data Quality Scores:**
#'    - Develop composite quality score per interviewer
#'    - Recommend retraining for low-scoring interviewers
#'
#' @export
qa_check_interviewer_consistency <- function(
  interviews,
  interviewer_col = "interviewer_id",
  catch_col = "catch_total",
  effort_col = "hours_fished",
  length_col = NULL,
  location_col = NULL
) {
  # Implementation
}
```

---

### Phase 2: Master QA/QC Report Function 📊

#### Function 2.1: `qa_report()`

**Purpose:** Generate comprehensive QA/QC report covering all 10 mistakes

**New File:** `R/qa-report.R` (~300 lines)

```r
#' Generate Comprehensive QA/QC Report
#'
#' Runs all quality assurance and quality control checks and generates a
#' comprehensive report identifying potential data quality issues based on
#' Table 17.3 common mistakes.
#'
#' @param counts Count data (for effort estimation)
#' @param interviews Interview data (for catch/harvest estimation)
#' @param calendar Sampling calendar/frame (optional but recommended)
#' @param locations_expected Character vector of expected locations
#' @param valid_species Character vector of valid species for this fishery
#' @param output_format Report format: "text", "html", "pdf", or "list"
#' @param save_path File path to save report (optional)
#' @param verbose Print progress messages (default TRUE)
#'
#' @return If output_format = "list", returns list with all QA check results.
#'   Otherwise returns file path to generated report.
#'
#' @details
#' ## QA/QC Checks Performed
#'
#' 1. **Zero Skipping** - Missing zero counts/catches
#' 2. **Targeting Bias** - Preferential sampling of successful parties
#' 3. **Size Bias** - Measuring only largest fish
#' 4. **Spatial Coverage (Counts)** - Incomplete count locations
#' 5. **Spatial Coverage (Interviews)** - Incomplete interview locations
#' 6. **Angler Exclusions** - Systematic exclusion of groups
#' 7. **Unit Consistency** - Mixed measurement units
#' 8. **Species ID** - Potential misidentifications
#' 9. **Effort Calculations** - Party-level effort errors
#' 10. **Interviewer Consistency** - Lack of standardization
#'
#' ## Report Structure
#'
#' - **Executive Summary:** Overall data quality assessment
#' - **Critical Issues:** High-severity problems requiring attention
#' - **Warnings:** Medium-severity issues to review
#' - **Detailed Checks:** Results from each of 10 checks
#' - **Recommendations:** Specific remediation steps
#' - **Data Quality Score:** Composite score (0-100)
#'
#' ## Severity Classification
#'
#' - **Critical:** Serious bias likely, estimates unreliable
#' - **High:** Moderate bias possible, review recommended
#' - **Medium:** Minor issues, low impact expected
#' - **Low:** No issues detected or minimal impact
#'
#' @examples
#' \dontrun{
#' library(tidycreel)
#'
#' # Generate comprehensive QA/QC report
#' report <- qa_report(
#'   counts = my_counts,
#'   interviews = my_interviews,
#'   calendar = my_calendar,
#'   locations_expected = c("Site A", "Site B", "Site C"),
#'   valid_species = c("bass", "trout", "panfish"),
#'   output_format = "html",
#'   save_path = "creel_qaqc_report.html"
#' )
#'
#' # View in browser
#' browseURL(report)
#'
#' # Or get results as list for programmatic access
#' qa_results <- qa_report(
#'   counts = my_counts,
#'   interviews = my_interviews,
#'   output_format = "list"
#' )
#'
#' # Check overall quality
#' qa_results$summary$data_quality_score  # 0-100
#' qa_results$summary$critical_issues  # Count of critical problems
#' }
#'
#' @references
#' *Analysis and Interpretation of Freshwater Fisheries Data, 2nd Edition.*
#' Chapter 17: Creel Surveys, Table 17.3.
#'
#' @export
qa_report <- function(
  counts = NULL,
  interviews = NULL,
  calendar = NULL,
  locations_expected = NULL,
  valid_species = NULL,
  output_format = c("list", "text", "html", "pdf"),
  save_path = NULL,
  verbose = TRUE
) {
  # Implementation in Phase 2
}
```

**Implementation Steps:**

1. Validate inputs and check data availability (~30 lines)
2. Run all 10 QA checks sequentially (~60 lines)
3. Aggregate results and calculate severity levels (~40 lines)
4. Calculate composite data quality score (~30 lines)
5. Generate report based on output_format (~80 lines)
6. Save to file if save_path specified (~20 lines)
7. Return results (~10 lines)

**Data Quality Score Calculation:**
```r
# Each check contributes to score based on severity
score = 100 - sum(
  critical_issues * 20,
  high_issues * 10,
  medium_issues * 5,
  low_issues * 1
)

score = max(0, min(100, score))  # Bound 0-100
```

---

### Phase 3: Helper Functions & Utilities 🔧

#### Function 3.1: `qa_check_all()`

**Purpose:** Lightweight version of `qa_report()` that returns only list

**New File:** `R/qa-check-all.R` (~80 lines)

```r
#' Run All QA/QC Checks (Returns List Only)
#'
#' Convenience function that runs all QA/QC checks and returns results as
#' a list without generating formatted report. Useful for programmatic access.
#'
#' @inheritParams qa_report
#' @return Named list with results from all 10 QA checks
#'
#' @export
qa_check_all <- function(
  counts = NULL,
  interviews = NULL,
  calendar = NULL,
  locations_expected = NULL,
  valid_species = NULL
) {
  qa_report(
    counts = counts,
    interviews = interviews,
    calendar = calendar,
    locations_expected = locations_expected,
    valid_species = valid_species,
    output_format = "list",
    save_path = NULL,
    verbose = FALSE
  )
}
```

---

#### Function 3.2: `qa_summarize()`

**Purpose:** Create executive summary from QA results

**New File:** `R/qa-summarize.R` (~120 lines)

```r
#' Summarize QA/QC Results
#'
#' Creates executive summary from QA/QC check results.
#'
#' @param qa_results Output from `qa_check_all()` or `qa_report()`
#' @param format Output format: "text" or "tibble"
#'
#' @return Summary of QA/QC results
#'
#' @export
qa_summarize <- function(qa_results, format = c("text", "tibble")) {
  # Implementation
}
```

---

#### Function 3.3: `qa_fix_effort()`

**Purpose:** Auto-fix common effort calculation errors

**New File:** `R/qa-fix-effort.R` (~150 lines)

```r
#' Automatically Fix Party-Level Effort Calculations
#'
#' Attempts to automatically correct common effort calculation errors
#' based on QA check results.
#'
#' @param interviews Interview data
#' @param qa_result Output from `qa_check_effort()`
#' @param num_anglers_col Column with number of anglers
#' @param hours_col Column with hours fished
#' @param effort_col Column to create/fix with total effort
#' @param prompt_before_fix Ask user confirmation before fixing (default TRUE)
#'
#' @return Corrected interview data with updated effort column
#'
#' @details
#' Fixes applied:
#' - Calculate effort = num_anglers × hours_fished
#' - Set effort = hours_fished if num_anglers missing (assume 1)
#' - Flag but don't auto-fix individual-level effort issues
#'
#' @export
qa_fix_effort <- function(
  interviews,
  qa_result = NULL,
  num_anglers_col = "num_anglers",
  hours_col = "hours_fished",
  effort_col = "hours_fished",
  prompt_before_fix = TRUE
) {
  # Implementation
}
```

---

### Phase 4: Testing - `tests/testthat/test-qa-*.R` 📋

**Test Files:** One file per QA function (~100-150 lines each)

#### Test Coverage Plan

**For Each QA Function (10 files × ~120 lines = 1,200 lines total):**

1. **Test Valid Input Handling** (~20 lines)
   - Correct column names
   - Proper data types
   - Expected structure

2. **Test Issue Detection** (~40 lines)
   - Known problematic data → should flag issue
   - Clean data → should not flag issue
   - Edge cases

3. **Test Severity Classification** (~20 lines)
   - Critical issues correctly identified
   - Warning issues correctly identified
   - No issue when data clean

4. **Test Recommendations** (~20 lines)
   - Appropriate recommendation text generated
   - Actionable guidance provided

5. **Test Edge Cases** (~20 lines)
   - Empty data
   - Single observation
   - All NA values
   - Missing optional columns

**Example Test File: `tests/testthat/test-qa-check-zeros.R`**

```r
test_that("qa_check_zeros detects missing zero counts", {
  # Create count data with gaps (skipped zeros)
  counts <- tibble(
    date = as.Date(c("2025-06-01", "2025-06-03", "2025-06-05")),  # Missing 6/2, 6/4
    location = "Site A",
    count = c(5, 3, 8)  # All non-zero
  )

  result <- qa_check_zeros(
    counts,
    type = "counts",
    date_col = "date",
    location_col = "location",
    value_col = "count"
  )

  expect_true(result$issue_detected)
  expect_equal(result$severity, "high")
  expect_equal(length(result$missing_dates), 2)
})

test_that("qa_check_zeros does not flag complete data", {
  # Complete count data with zeros included
  counts <- tibble(
    date = as.Date("2025-06-01") + 0:9,
    location = "Site A",
    count = c(5, 0, 3, 0, 8, 2, 0, 0, 4, 1)
  )

  result <- qa_check_zeros(
    counts,
    type = "counts",
    date_col = "date",
    value_col = "count"
  )

  expect_false(result$issue_detected)
  expect_equal(result$severity, "none")
})

test_that("qa_check_zeros detects low zero rate in interviews", {
  # Interview data where clerk skipped zero-catch parties
  interviews <- tibble(
    interview_id = 1:100,
    catch_total = rpois(100, lambda = 5)  # No zeros (unrealistic)
  )
  interviews$catch_total[interviews$catch_total == 0] <- 1  # Remove all zeros

  result <- qa_check_zeros(
    interviews,
    type = "interviews",
    value_col = "catch_total"
  )

  expect_true(result$issue_detected)
  expect_true(result$zero_rate < 0.01)  # Essentially no zeros
  expect_match(result$recommendation, "zeros.*recorded")
})

# ... more tests
```

**Test File for Master Function: `tests/testthat/test-qa-report.R`** (~200 lines)

```r
test_that("qa_report runs all checks and generates report", {
  # Create realistic test data with known issues
  counts <- create_test_counts(issue = "missing_zeros")
  interviews <- create_test_interviews(issue = "targeting_bias")

  result <- qa_report(
    counts = counts,
    interviews = interviews,
    output_format = "list"
  )

  # Should run all 10 checks
  expect_true("check_zeros_counts" %in% names(result))
  expect_true("check_targeting" %in% names(result))
  # ... etc for all 10

  # Should detect known issues
  expect_true(result$check_zeros_counts$issue_detected)
  expect_true(result$check_targeting$issue_detected)

  # Should calculate quality score
  expect_true("summary" %in% names(result))
  expect_true(result$summary$data_quality_score < 100)
})

test_that("qa_report generates HTML output", {
  counts <- create_test_counts()
  interviews <- create_test_interviews()

  temp_file <- tempfile(fileext = ".html")

  report_path <- qa_report(
    counts = counts,
    interviews = interviews,
    output_format = "html",
    save_path = temp_file
  )

  expect_true(file.exists(report_path))

  # Check HTML structure
  html_content <- readLines(report_path)
  expect_true(any(grepl("QA/QC Report", html_content)))
  expect_true(any(grepl("Data Quality Score", html_content)))

  unlink(temp_file)
})

# ... more tests
```

---

### Phase 5: Documentation & Vignette ✍️

**File:** `vignettes/quality-assurance.Rmd` (~1,000 lines)

#### Vignette Structure

```r
---
title: "Quality Assurance and Quality Control for Creel Surveys"
output: rmarkdown::html_vignette
vignette: >
  %\VignetteIndexEntry{Quality Assurance and Quality Control for Creel Surveys}
  %\VignetteEngine{knitr::rmarkdown}
  %\VignetteEncoding{UTF-8}
---
```

**Section 1: Introduction** (~150 lines)
- Importance of QA/QC in creel surveys
- Table 17.3 overview
- Impact of each mistake on estimates
- Philosophy: "Garbage in, garbage out"

**Section 2: The 10 Common Mistakes** (~200 lines)
- Detailed explanation of each mistake
- Real-world examples
- Statistical impact on estimates
- How tidycreel detects each

**Section 3: Running QA/QC Checks** (~200 lines)
```r
library(tidycreel)
library(dplyr)

# Load example data with known issues
data("example_counts_with_issues")
data("example_interviews_with_issues")

# Run comprehensive QA/QC report
qa_results <- qa_report(
  counts = example_counts_with_issues,
  interviews = example_interviews_with_issues,
  locations_expected = c("Site A", "Site B", "Site C"),
  valid_species = c("bass", "trout", "panfish"),
  output_format = "list"
)

# View summary
qa_summarize(qa_results)

# Detailed examination of specific checks
qa_results$check_zeros_counts
qa_results$check_targeting
```

**Section 4: Interpreting Results** (~150 lines)
- Understanding severity levels
- Data quality score interpretation
- When to reject data vs. when to proceed with caution
- Documenting QA/QC findings

**Section 5: Remediation Strategies** (~200 lines)
- How to fix each type of problem
- Example: Correcting effort calculations
- Example: Retraining interviewers
- Example: Filling spatial gaps
- When data cannot be salvaged

**Section 6: Prevention Best Practices** (~100 lines)
- Training protocols
- Data entry validation
- Real-time QA during surveys
- Periodic checks throughout season

---

## Implementation Timeline

### Sprint 1 (Week 1-2)

**Week 1:**
- [ ] Create QA function skeletons (all 10 functions)
- [ ] Implement `qa_check_zeros()` fully
- [ ] Implement `qa_check_targeting()` fully
- [ ] Write tests for zeros and targeting checks
- [ ] Begin `qa_check_size_bias()`

**Week 2:**
- [ ] Complete `qa_check_size_bias()`
- [ ] Implement `qa_check_spatial_coverage()`
- [ ] Implement `qa_check_exclusions()`
- [ ] Write tests for these 3 functions
- [ ] Begin `qa_check_units()`

### Sprint 2 (Week 3)

**Week 3:**
- [ ] Complete `qa_check_units()`
- [ ] Implement `qa_check_species_id()`
- [ ] Implement `qa_check_effort()`
- [ ] Implement `qa_check_interviewer_consistency()`
- [ ] Write tests for these 4 functions
- [ ] Begin `qa_report()` master function

**Week 4:**
- [ ] Complete `qa_report()` function
- [ ] Implement report generation (text, HTML, PDF)
- [ ] Implement helper functions (`qa_check_all`, `qa_summarize`, `qa_fix_effort`)
- [ ] Write integration tests for `qa_report()`
- [ ] Run R CMD check

### Sprint 3 (Week 5 - Optional Polish)

**Week 5:**
- [ ] Write comprehensive vignette
- [ ] Create example datasets with known issues for testing
- [ ] Polish report formatting (HTML/PDF templates)
- [ ] Add diagnostic visualizations
- [ ] Update DEVELOPMENT_ROADMAP.md
- [ ] Create PR with comprehensive documentation

---

## Success Criteria

### Functionality ✅
- [ ] All 10 QA check functions implemented and tested
- [ ] `qa_report()` generates comprehensive reports in multiple formats
- [ ] Each check correctly identifies known problematic patterns
- [ ] Severity levels accurately reflect impact on estimates
- [ ] Actionable recommendations provided for each issue
- [ ] Helper functions enable programmatic QA workflows

### Documentation ✅
- [ ] Comprehensive roxygen2 documentation for all functions
- [ ] Detailed vignette explaining each check with examples
- [ ] Clear guidance on interpreting results
- [ ] Remediation strategies documented
- [ ] Cross-references to Table 17.3

### Code Quality ✅
- [ ] Follows tidycreel style conventions
- [ ] Consistent return structures across QA functions
- [ ] Informative error messages with `cli::cli_*()`
- [ ] Handles edge cases gracefully
- [ ] Minimal dependencies

### Testing ✅
- [ ] >90% code coverage for QA functions
- [ ] Tests validate detection logic with known issues
- [ ] Tests verify clean data doesn't trigger false positives
- [ ] Integration tests for full report generation
- [ ] Example datasets for testing and documentation

---

## Data Quality Score Rubric

### Score Interpretation

| Score | Quality Level | Interpretation | Recommendation |
|-------|--------------|----------------|----------------|
| 90-100 | Excellent | Minor or no issues detected | Proceed with analysis confidently |
| 75-89 | Good | Some minor issues, unlikely to affect estimates substantially | Review warnings, proceed with caution |
| 60-74 | Fair | Multiple issues detected, potential bias present | Address critical issues before analysis |
| 40-59 | Poor | Serious issues detected, estimates likely biased | Major remediation required |
| 0-39 | Unacceptable | Critical problems throughout dataset | Data likely unusable, restart survey |

### Penalty Weights

| Issue Severity | Penalty | Example |
|----------------|---------|---------|
| Critical | -20 points | >30% missing zeros, >95% success rate (targeting) |
| High | -10 points | 10-30% missing zeros, mixed measurement units |
| Medium | -5 points | Minor spatial gaps, low refusal rates |
| Low | -1 point | Isolated species ID questions, minor inconsistencies |

---

## Example Output

### Console Summary Output

```
═══════════════════════════════════════════════════════════
  CREEL SURVEY QA/QC REPORT
═══════════════════════════════════════════════════════════

Data Quality Score: 68/100 (FAIR)

CRITICAL ISSUES (2):
  ✗ Check #1 (Zero Skipping): Missing 23% of expected zero counts
  ✗ Check #2 (Targeting Bias): Success rate 94% (expected 30-70%)

WARNINGS (3):
  ⚠ Check #4 (Spatial Coverage): Site C has only 12% of expected samples
  ⚠ Check #6 (Mixed Units): Detected mix of inches and millimeters
  ⚠ Check #9 (Interviewer Consistency): Interviewer "JD" has 3x higher CPUE

PASSED (5):
  ✓ Check #3 (Size Bias): No subsample bias detected
  ✓ Check #5 (Exclusions): Refusal rate 8% (acceptable)
  ✓ Check #7 (Species ID): No suspicious patterns
  ✓ Check #8 (Effort Calculations): All calculations verified
  ✓ Check #10 (This Check!): QA/QC completed successfully

══════════════════════════════════════════════════════════

RECOMMENDATIONS:

1. CRITICAL - Zero Skipping (Counts):
   → 47 expected count dates are missing data
   → Review clerk instructions to record ALL counts, including zeros
   → Missing dates: 2025-06-02, 2025-06-05, 2025-06-08, ...

2. CRITICAL - Targeting Bias (Interviews):
   → 94% of interviews had catch > 0 (expected 30-70%)
   → Likely interviewing at fish-cleaning stations
   → Train clerks to interview ALL anglers, not just successful ones
   → Consider access-point sampling instead of roving

[... additional recommendations ...]

══════════════════════════════════════════════════════════

Full HTML report saved to: creel_qaqc_report_2025-10-24.html
```

---

## Open Questions & Design Decisions

### Q1: Statistical Tests for Interviewer Consistency
**Question:** Should we use parametric (ANOVA) or non-parametric (Kruskal-Wallis) tests?

**Options:**
- **Option A:** Use ANOVA (assumes normality, more powerful if assumptions met)
- **Option B:** Use Kruskal-Wallis (non-parametric, more robust)
- **Option C:** Test normality first, choose test adaptively

**Recommendation:** **Option C** - Test normality, use appropriate test, report which was used.

---

### Q2: Auto-Fix vs. Manual Review
**Question:** Should QA functions auto-fix simple errors or only flag them?

**Options:**
- **Option A:** Auto-fix simple errors (effort calculations, unit conversions)
- **Option B:** Only flag errors, never modify data
- **Option C:** Provide `qa_fix_*()` helper functions, but keep detection separate

**Recommendation:** **Option C** - Keep QA checks pure (detection only), provide optional fix helpers.

---

### Q3: Report Format Complexity
**Question:** How sophisticated should HTML/PDF reports be?

**Options:**
- **Option A:** Simple text output with basic formatting
- **Option B:** Polished HTML with interactive plots (requires shiny/plotly)
- **Option C:** Parameterized R Markdown templates (good middle ground)

**Recommendation:** **Option C** - Use R Markdown templates for professional reports without heavy dependencies.

---

## References

1. **Pollock, K.H., C.M. Jones, and T.L. Brown. 1994.** *Angler Survey Methods and Their Applications in Fisheries Management.* American Fisheries Society Special Publication 25.

2. **Jones, C.M. and K.H. Pollock. 2012.** Recreational survey methods: estimation of effort, harvest, and released catch. Pages 883-919 in A.V. Zale, D.L. Parrish, and T.M. Sutton, editors. *Fisheries Techniques, 3rd edition.* American Fisheries Society, Bethesda, Maryland.

3. **Chapter 17: Creel Surveys.** *Analysis and Interpretation of Freshwater Fisheries Data, 2nd Edition.* American Fisheries Society. (Table 17.3)

4. **Rasmussen, P.W., M.D. Staggs, T.D. Beard Jr., and S.P. Newman. 1998.** Bias and confidence interval coverage of creel survey estimators evaluated by simulation. Transactions of the American Fisheries Society 127:469-480.

---

**End of Implementation Plan**

**Next Steps:**
1. Review and approve this plan
2. Create feature branch: `feature/qaqc-framework`
3. Begin Sprint 1 implementation
4. Track progress in `DEVELOPMENT_ROADMAP.md`
5. Coordinate with roving estimators implementation (can be parallel)
