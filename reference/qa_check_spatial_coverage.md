# Check Spatial Coverage Completeness

Detects incomplete spatial coverage for both counts and interviews,
which creates unrepresentative samples and unknown bias (Table 17.3,
\#4-5).

## Usage

``` r
qa_check_spatial_coverage(
  data,
  locations_expected = NULL,
  location_col = "location",
  date_col = "date",
  type = c("counts", "interviews"),
  interviewer_col = NULL,
  min_coverage = 0.9,
  min_sample_size = 10
)
```

## Arguments

- data:

  Count or interview data

- locations_expected:

  Character vector of all locations that should be sampled. If NULL,
  uses all unique locations found in data.

- location_col:

  Column containing location names (default "location")

- date_col:

  Column containing dates (default "date")

- type:

  Data type: `"counts"` or `"interviews"`

- interviewer_col:

  Column containing interviewer IDs (optional). Used to check if
  interviewers cover all locations.

- min_coverage:

  Minimum acceptable coverage proportion (default 0.90)

- min_sample_size:

  Minimum sample size per location to avoid low-n warnings (default 10)

## Value

List with:

- issue_detected:

  Logical, TRUE if coverage issues detected

- severity:

  "high", "medium", "low", or "none"

- location_coverage:

  Proportion of expected locations sampled

- locations_observed:

  Locations found in data

- locations_missing:

  Expected locations not in data

- location_stats:

  Sample sizes and temporal coverage by location

- undersampled_locations:

  Locations with sample size \< min_sample_size

- temporal_gaps:

  Locations with poor temporal coverage

- interviewer_coverage:

  Coverage matrix by interviewer (if interviewer_col provided)

- recommendation:

  Text guidance for remediation

## Details

### Detection Logic

1.  **Location Coverage:**

    - Check which expected locations are missing entirely

    - Calculate proportion of locations covered

    - Flag if coverage \< min_coverage

2.  **Sample Size Adequacy:**

    - Compare sample sizes among locations

    - Flag locations with very low sample sizes (\< min_sample_size)

    - Check for extreme imbalance (CV \> 1.0)

3.  **Temporal Coverage:**

    - For each location, check temporal span vs overall season

    - Flag locations with temporal coverage \< 70% of season

4.  **Interviewer Coverage (optional):**

    - Check if interviewers cover all locations

    - Flag if certain interviewers only work certain sites

### Severity Levels

- **High:** Missing \>20% of locations OR \>50% have low sample sizes

- **Medium:** Missing 10-20% of locations OR 25-50% have low sample
  sizes

- **Low:** Missing \<10% of locations OR \<25% have low sample sizes

- **None:** All locations covered with adequate samples

## References

*Analysis and Interpretation of Freshwater Fisheries Data, 2nd Edition.*
Chapter 17: Creel Surveys, Table 17.3.

## Examples

``` r
if (FALSE) { # \dontrun{
library(tidycreel)

# Define expected locations
expected_locs <- c("North Shore", "South Shore", "East Bay", "West Bay")

# Check spatial coverage
qa_result <- qa_check_spatial_coverage(
  counts,
  locations_expected = expected_locs,
  location_col = "location",
  date_col = "date",
  type = "counts"
)

# With interviewer analysis
qa_result <- qa_check_spatial_coverage(
  interviews,
  locations_expected = expected_locs,
  location_col = "location",
  interviewer_col = "clerk_id",
  type = "interviews"
)
} # }
```
