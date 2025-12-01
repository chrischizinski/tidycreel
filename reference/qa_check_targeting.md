# Check for Targeting Bias (Successful Parties)

Detects potential targeting of successful fishing parties, which occurs
when interviewers preferentially interview anglers with visible fish
(e.g., at fish-cleaning stations). This leads to overestimation of catch
and harvest rates (Table 17.3, \#2).

## Usage

``` r
qa_check_targeting(
  interviews,
  catch_col = "catch_total",
  location_col = NULL,
  interviewer_col = NULL,
  success_threshold = 0.85
)
```

## Arguments

- interviews:

  Interview data

- catch_col:

  Column containing catch counts (default "catch_total")

- location_col:

  Column containing interview locations (optional). Used to identify
  high-success locations like cleaning stations.

- interviewer_col:

  Column containing interviewer IDs (optional). Used to detect
  interviewer-specific bias.

- success_threshold:

  Proportion of non-zero catches above which targeting is suspected
  (default 0.85). Natural fisheries typically have 30-70% success rates.

## Value

List with:

- issue_detected:

  Logical, TRUE if potential targeting detected

- severity:

  "high", "medium", "low", or "none"

- overall_success_rate:

  Proportion of interviews with catch \> 0

- expected_success_rate:

  Expected range based on fishery type

- location_stats:

  Success rates by location (if location_col provided)

- high_success_locations:

  Locations with \>90% success (potential cleaning stations)

- interviewer_stats:

  Success rates by interviewer (if interviewer_col provided)

- biased_interviewers:

  Interviewers with significantly high success rates

- recommendation:

  Text guidance for remediation

## Details

### Detection Logic

1.  **Overall Success Rate:**

    - Calculate proportion of interviews with catch \> 0

    - Flag if success rate \> success_threshold (default 85%)

    - Natural fisheries typically have 30-70% success rates

    - Rates \>85% suggest potential targeting bias

2.  **Location-Specific Targeting:**

    - Identify locations with very high success rates (\>90%)

    - These may be fish-cleaning stations or boat ramps where successful
      anglers congregate

    - Check if these locations are overrepresented in sample

3.  **Interviewer Bias:**

    - Compare success rates among interviewers

    - Flag interviewers with substantially higher success rates than
      average

    - Use statistical tests (chi-square) if sufficient sample size

### Severity Levels

- **High:** Success rate \>90% or \>3 high-success locations

- **Medium:** Success rate 85-90% or 1-2 high-success locations

- **Low:** Success rate 75-85%

- **None:** Success rate \<75%

## References

*Analysis and Interpretation of Freshwater Fisheries Data, 2nd Edition.*
Chapter 17: Creel Surveys, Table 17.3.

## Examples

``` r
if (FALSE) { # \dontrun{
library(tidycreel)

# Basic check
qa_result <- qa_check_targeting(
  interviews,
  catch_col = "catch_total"
)

# With location analysis
qa_result <- qa_check_targeting(
  interviews,
  catch_col = "catch_total",
  location_col = "interview_location",
  interviewer_col = "clerk_id"
)

if (qa_result$issue_detected) {
  print(qa_result$high_success_locations)
  print(qa_result$recommendation)
}
} # }
```
