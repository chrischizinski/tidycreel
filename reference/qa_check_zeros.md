# Check for Missing Zero Counts or Catches

Detects potential skipping of zeros in count or interview data, which
leads to overestimation of effort, catch, and harvest. This is one of
the most common and serious creel survey errors (Table 17.3, \#1).

## Usage

``` r
qa_check_zeros(
  data,
  type = c("counts", "interviews"),
  date_col = "date",
  location_col = NULL,
  value_col = NULL,
  interviewer_col = NULL,
  expected_coverage = NULL,
  expected_zero_rate = 0.2
)
```

## Arguments

- data:

  Count data (for counts) or interview data (for catches)

- type:

  Type of data: `"counts"` or `"interviews"`

- date_col:

  Column containing dates (default "date")

- location_col:

  Column containing locations (default "location"). For interviews
  without location, set to NULL.

- value_col:

  Column containing counts or catches. Required for counts, defaults to
  "catch_total" for interviews.

- interviewer_col:

  For interviews, column containing interviewer IDs to check for
  interviewer-specific bias (default NULL)

- expected_coverage:

  Proportion of sampling frame expected to have data (default 0.95 for
  counts, 0.7 for interviews). If actual coverage is below this, a
  warning is issued.

- expected_zero_rate:

  For interviews, expected proportion of zero catches (default 0.2).
  Used to detect suspiciously low zero rates.

## Value

List with:

- issue_detected:

  Logical, TRUE if potential zero-skipping detected

- severity:

  "high", "medium", "low", or "none"

- check_type:

  "counts" or "interviews"

- coverage_rate:

  For counts: proportion of expected observations present

- zero_rate:

  For interviews: proportion of zero catches

- missing_dates:

  Dates that should have data but don't

- missing_locations:

  Locations that should have data but don't

- missing_combinations:

  Date-location combinations missing

- interviewer_zero_rates:

  For interviews: zero rates by interviewer

- suspicious_interviewers:

  Interviewers with unusually low zero rates

- recommendation:

  Text guidance for remediation

## Details

### Detection Logic

**For Counts:**

1.  Identify sampling frame (all date-location combinations that should
    be sampled)

2.  Check which combinations are missing

3.  Flag if coverage \< expected_coverage threshold

4.  Report missing dates and locations

**For Interviews:**

1.  Check for suspiciously low proportion of zero catches

2.  Compare to expected zero-inflation rate (varies by fishery)

3.  If interviewer_col provided, examine interviewer-specific zero rates

4.  Flag interviewers with unusually low zero rates

### Severity Levels

- **High:** Coverage \< 70% or zero rate \< 10% (for interviews)

- **Medium:** Coverage 70-90% or zero rate 10-30%

- **Low:** Coverage \> 90% but \< expected, or zero rate 30-50%

- **None:** No issues detected

## References

*Analysis and Interpretation of Freshwater Fisheries Data, 2nd Edition.*
Chapter 17: Creel Surveys, Table 17.3.

## Examples

``` r
if (FALSE) { # \dontrun{
library(tidycreel)

# Check count data for missing zeros
qa_counts <- qa_check_zeros(
  counts,
  type = "counts",
  date_col = "date",
  location_col = "location",
  value_col = "count"
)

if (qa_counts$issue_detected) {
  print(qa_counts$recommendation)
}

# Check interview data for skipped zero catches
qa_interviews <- qa_check_zeros(
  interviews,
  type = "interviews",
  date_col = "interview_date",
  value_col = "catch_total",
  interviewer_col = "clerk_id"
)
} # }
```
