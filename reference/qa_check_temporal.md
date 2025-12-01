# Check for Temporal Coverage Issues

Detects gaps in temporal sampling coverage that may lead to biased
estimates due to incomplete representation of fishing activity patterns
(Table 17.3, \#9).

## Usage

``` r
qa_check_temporal(
  data,
  schedule = NULL,
  date_col = "date",
  time_col = NULL,
  stratum_col = NULL,
  location_col = NULL,
  min_coverage_proportion = 0.8,
  check_weekends = TRUE,
  check_seasons = TRUE,
  check_daily_hours = TRUE,
  min_days_per_stratum = 5
)
```

## Arguments

- data:

  Survey data (counts or interviews) containing temporal information

- schedule:

  Survey schedule data (optional, for planned vs actual comparison)

- date_col:

  Column containing date information

- time_col:

  Column containing time information (optional)

- stratum_col:

  Column containing stratum identifiers (optional)

- location_col:

  Column containing location identifiers (optional)

- min_coverage_proportion:

  Minimum proportion of time periods that should be sampled within each
  stratum (default 0.8 = 80%)

- check_weekends:

  Logical, whether to specifically check weekend coverage (default TRUE)

- check_seasons:

  Logical, whether to check seasonal coverage (default TRUE)

- check_daily_hours:

  Logical, whether to check coverage across hours of day (default TRUE)

- min_days_per_stratum:

  Minimum number of days that should be sampled per stratum (default 5)

## Value

List with:

- issue_detected:

  Logical, TRUE if temporal coverage issues detected

- severity:

  "high", "medium", "low", or "none"

- n_total:

  Total number of records

- n_strata:

  Number of temporal strata

- n_undersampled_strata:

  Number of strata with insufficient coverage

- n_missing_weekends:

  Number of strata missing weekend coverage

- n_missing_seasons:

  Number of seasons with no coverage

- n_gaps_daily_hours:

  Number of hour periods with no coverage

- coverage_by_stratum:

  Coverage statistics by stratum

- weekend_coverage:

  Weekend vs weekday coverage summary

- seasonal_coverage:

  Coverage by season/month

- hourly_coverage:

  Coverage by hour of day

- temporal_gaps:

  Identified gaps in coverage

- undersampled_strata:

  Details of strata with poor coverage

- recommendation:

  Text guidance for remediation

## Details

### Detection Logic

1.  **Stratum Coverage:**

    - Calculate sampling coverage within each temporal stratum

    - Flag strata below minimum coverage threshold

    - Check for completely unsampled strata

2.  **Weekend Coverage:**

    - Compare weekend vs weekday sampling intensity

    - Flag if weekends are systematically under-sampled

    - Important because fishing patterns differ on weekends

3.  **Seasonal Coverage:**

    - Check coverage across months/seasons

    - Flag missing seasonal periods

    - Detect seasonal sampling bias

4.  **Daily Hour Coverage:**

    - Analyze coverage across hours of the day

    - Flag systematic gaps (e.g., early morning, evening)

    - Important for effort estimation accuracy

5.  **Temporal Clustering:**

    - Detect if sampling is clustered in time

    - Flag long gaps between sampling periods

    - Check for systematic temporal bias

### Common Issues Detected

- **Weekend Gaps**: No weekend sampling in fishing season

- **Seasonal Bias**: Only summer sampling for year-round fishery

- **Hour Gaps**: Missing early morning or evening periods

- **Stratum Gaps**: Some strata completely unsampled

- **Clustering**: All sampling in short time periods

- **Holiday Gaps**: Missing major fishing holidays

## See also

[`qa_checks`](qa_checks.md), [`validate_calendar`](validate_calendar.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Basic temporal coverage check
temporal_check <- qa_check_temporal(
  counts,
  date_col = "date",
  stratum_col = "stratum"
)

# Comprehensive temporal validation
temporal_check <- qa_check_temporal(
  interviews,
  schedule = survey_schedule,
  date_col = "date",
  time_col = "time_start",
  stratum_col = "stratum",
  location_col = "location",
  check_weekends = TRUE,
  check_seasons = TRUE,
  check_daily_hours = TRUE
)

# Check against planned schedule
temporal_check <- qa_check_temporal(
  counts,
  schedule = planned_schedule,
  date_col = "date"
)
} # }
```
