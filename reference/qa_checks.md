# Comprehensive Quality Assurance Checks for Creel Survey Data

Runs a comprehensive suite of quality assurance checks on creel survey
data to detect common mistakes identified in Table 17.3 and ensure data
quality before analysis.

## Usage

``` r
qa_checks(
  counts = NULL,
  interviews = NULL,
  schedule = NULL,
  checks = "all",
  severity_threshold = "medium",
  return_details = TRUE,
  ...
)
```

## Arguments

- counts:

  Count data (optional, for zero count and coverage checks)

- interviews:

  Interview data (optional, for effort and targeting checks)

- schedule:

  Survey schedule data (optional, for temporal coverage)

- checks:

  Character vector of checks to run. Options:

  "effort"

  :   Party-level effort calculation validation

  "zeros"

  :   Zero count detection and validation

  "targeting"

  :   Successful party bias detection

  "units"

  :   Measurement unit consistency

  "spatial_coverage"

  :   Spatial sampling validation

  "species"

  :   Species identification validation

  "temporal"

  :   Temporal coverage validation

  "outliers"

  :   Statistical outlier detection

  "missing"

  :   Missing data pattern analysis

  Default is "all" which runs all available checks.

- severity_threshold:

  Minimum severity level to report. One of: "high", "medium", "low".
  Default "medium".

- return_details:

  Logical, whether to return detailed results for each check. If FALSE,
  returns summary only. Default TRUE.

- ...:

  Additional arguments passed to individual check functions

## Value

List with:

- overall_score:

  Numeric quality score 0-100

- overall_grade:

  Letter grade A-F based on score

- issues_detected:

  Total number of issues found

- high_severity_issues:

  Number of high severity issues

- summary:

  Data frame summarizing all checks

- recommendations:

  Character vector of prioritized recommendations

- details:

  List of detailed results from each check (if requested)

- data_summary:

  Summary of input data characteristics

## Details

### Quality Scoring System

The overall quality score (0-100) is calculated as:

- Start with 100 points

- Subtract points for each issue based on severity:

  - High severity: -15 points per issue

  - Medium severity: -8 points per issue

  - Low severity: -3 points per issue

- Minimum score is 0

### Grade Scale

- A (90-100): Excellent data quality, ready for analysis

- B (80-89): Good quality, minor issues to address

- C (70-79): Acceptable quality, some issues need attention

- D (60-69): Poor quality, significant issues must be fixed

- F (0-59): Failing quality, major problems prevent reliable analysis

### Common Issues Detected

Based on Table 17.3 common creel survey mistakes:

1.  **Skipping zeros** - No zero counts recorded

2.  **Targeting successful parties** - Interview bias

3.  **Measurement unit errors** - Inconsistent units

4.  **Party effort calculation errors** - Incorrect angler-hour
    calculations

5.  **Spatial coverage gaps** - Areas not sampled

6.  **Species identification issues** - Unlikely species combinations

7.  **Temporal coverage gaps** - Missing time periods

8.  **Statistical outliers** - Extreme values needing validation

9.  **Missing data patterns** - Systematic data gaps

## See also

[`qa_check_effort`](qa_check_effort.md),
[`qa_check_zeros`](qa_check_zeros.md),
[`qa_check_targeting`](qa_check_targeting.md),
[`qa_check_units`](qa_check_units.md),
[`qa_check_spatial_coverage`](qa_check_spatial_coverage.md),
[`qc_report`](qc_report.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Run all checks on interview data
qa_results <- qa_checks(interviews = my_interviews)

# Run specific checks only
qa_results <- qa_checks(
    interviews = my_interviews,
    counts = my_counts,
    checks = c("effort", "zeros", "targeting")
)

# Get summary only (faster for large datasets)
qa_summary <- qa_checks(
    interviews = my_interviews,
    return_details = FALSE
)

# Print results
print(qa_results)
} # }
```
