# Check for Missing Data Patterns

Analyzes missing data patterns to detect systematic gaps, non-response
bias, and data collection issues that may affect survey estimates (Table
17.3, general data completeness).

## Usage

``` r
qa_check_missing(
  data,
  required_cols = NULL,
  important_cols = NULL,
  by_group = NULL,
  missing_threshold = 0.05,
  pattern_threshold = 5,
  check_monotonic = TRUE,
  date_col = NULL,
  max_patterns_to_show = 10
)
```

## Arguments

- data:

  Survey data (interviews, counts, or other datasets)

- required_cols:

  Character vector of columns that should never be missing

- important_cols:

  Character vector of columns where missing data is concerning but not
  critical

- by_group:

  Character vector of grouping variables to analyze missing patterns
  within groups (e.g., by stratum, location, interviewer)

- missing_threshold:

  Proportion threshold above which missing data is flagged as
  problematic (default 0.05 = 5%)

- pattern_threshold:

  Minimum number of records required to identify a systematic missing
  pattern (default 5)

- check_monotonic:

  Logical, whether to check for monotonic missing patterns (increasing
  missingness over time) (default TRUE)

- date_col:

  Column containing date information for temporal analysis

- max_patterns_to_show:

  Maximum number of missing patterns to include in results (default 10)

## Value

List with:

- issue_detected:

  Logical, TRUE if missing data issues detected

- severity:

  "high", "medium", "low", or "none"

- n_total:

  Total number of records

- n_complete_records:

  Number of records with no missing values

- completeness_rate:

  Proportion of complete records

- missing_by_column:

  Missing data summary by column

- missing_patterns:

  Common missing data patterns

- systematic_patterns:

  Identified systematic missing patterns

- temporal_patterns:

  Missing data patterns over time (if date provided)

- group_patterns:

  Missing patterns by group (if grouping provided)

- critical_missing:

  Records missing required columns

- recommendation:

  Text guidance for remediation

## Details

### Missing Data Analysis

1.  **Overall Completeness:**

    - Calculate missing data rates by column

    - Identify columns with excessive missing data

    - Flag records missing critical information

2.  **Missing Patterns:**

    - Identify common combinations of missing variables

    - Detect systematic patterns (e.g., always missing together)

    - Flag unusual missing patterns

3.  **Temporal Patterns:**

    - Analyze missing data trends over time

    - Detect periods with high missing rates

    - Identify monotonic missing patterns

4.  **Group Patterns:**

    - Compare missing rates across groups

    - Identify groups with systematic missing data

    - Detect interviewer or location effects

5.  **Non-Response Analysis:**

    - Identify potential non-response bias

    - Flag systematic refusal patterns

    - Analyze partial vs complete non-response

### Common Missing Data Issues

- **Required fields missing**: Date, location, basic catch info

- **Systematic refusal**: Anglers refusing certain questions

- **Interviewer effects**: Some interviewers missing more data

- **Temporal trends**: Increasing missingness over survey period

- **Equipment issues**: Missing data during certain periods

- **Training issues**: New staff missing more data

## See also

[`qa_checks`](qa_checks.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Basic missing data analysis
missing_check <- qa_check_missing(interviews)

# With required and important columns specified
missing_check <- qa_check_missing(
  interviews,
  required_cols = c("date", "location", "catch_total"),
  important_cols = c("species", "length", "weight"),
  missing_threshold = 0.10
)

# Group-wise analysis
missing_check <- qa_check_missing(
  interviews,
  by_group = c("interviewer", "location"),
  date_col = "date",
  check_monotonic = TRUE
)

# Temporal pattern analysis
missing_check <- qa_check_missing(
  interviews,
  date_col = "survey_date",
  check_monotonic = TRUE,
  missing_threshold = 0.05
)
} # }
```
