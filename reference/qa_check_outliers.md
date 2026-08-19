# Check for Statistical Outliers in Survey Data

Detects statistical outliers in key survey variables that may indicate
data entry errors, measurement problems, or unusual fishing events
requiring validation (Table 17.3, general data quality).

## Usage

``` r
qa_check_outliers(
  data,
  numeric_cols = NULL,
  outlier_method = "iqr",
  iqr_multiplier = 1.5,
  zscore_threshold = 3,
  min_observations = 10,
  by_group = NULL,
  exclude_zeros = TRUE,
  max_outliers_to_show = 10
)
```

## Arguments

- data:

  Survey data (interviews or counts)

- numeric_cols:

  Character vector of numeric columns to check for outliers. If NULL,
  automatically detects numeric columns.

- outlier_method:

  Method for outlier detection. Options:

  "iqr"

  :   Interquartile range method (default)

  "zscore"

  :   Z-score method

  "modified_zscore"

  :   Modified Z-score using median absolute deviation

  "isolation_forest"

  :   Isolation forest (if available)

- iqr_multiplier:

  Multiplier for IQR method (default 1.5 for mild outliers, 3.0 for
  extreme outliers)

- zscore_threshold:

  Z-score threshold for outlier detection (default 3.0)

- min_observations:

  Minimum number of observations required to detect outliers in a column
  (default 10)

- by_group:

  Character vector of grouping variables for outlier detection within
  groups (e.g., by species, location, stratum)

- exclude_zeros:

  Logical, whether to exclude zero values from outlier detection
  (default TRUE for catch/effort variables)

- max_outliers_to_show:

  Maximum number of outlier records to include in results (default 10)

## Value

List with:

- issue_detected:

  Logical, TRUE if outliers detected

- severity:

  "high", "medium", "low", or "none"

- n_total:

  Total number of records

- n_numeric_columns:

  Number of numeric columns checked

- n_outliers_total:

  Total number of outlier values detected

- n_outlier_records:

  Number of records with any outliers

- outlier_rate:

  Proportion of records with outliers

- outliers_by_column:

  Summary of outliers by column

- outlier_records:

  Sample records containing outliers

- outlier_statistics:

  Statistical summaries for each column

- extreme_outliers:

  Records with extreme outliers (if any)

- multivariate_outliers:

  Records that are outliers across multiple variables

- recommendation:

  Text guidance for remediation

## Details

### Detection Methods

1.  **IQR Method (Default):**

    - Outliers: Q1 - 1.5*IQR or Q3 + 1.5*IQR

    - Extreme outliers: Q1 - 3.0*IQR or Q3 + 3.0*IQR

    - Robust to non-normal distributions

2.  **Z-Score Method:**

    - Outliers: \|z\| \> threshold (default 3.0)

    - Assumes normal distribution

    - Sensitive to extreme values

3.  **Modified Z-Score:**

    - Uses median and MAD instead of mean and SD

    - More robust than standard z-score

    - Outliers: \|modified_z\| \> 3.5

### Common Outliers in Creel Surveys

- **Effort outliers**: Trips \> 24 hours, \< 0.1 hours

- **Catch outliers**: Unusually high catch numbers

- **CPUE outliers**: Extremely high catch rates

- **Party size outliers**: Very large or small parties

- **Length outliers**: Fish lengths outside species range

- **Weight outliers**: Weights inconsistent with lengths

### Validation Priorities

1.  **High Priority**: Extreme outliers (\>3 IQR)

2.  **Medium Priority**: Mild outliers (1.5-3 IQR)

3.  **Low Priority**: Borderline outliers

## See also

[`qa_checks`](qa_checks.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Basic outlier detection
outlier_check <- qa_check_outliers(interviews)

# Specific columns with custom thresholds
outlier_check <- qa_check_outliers(
  interviews,
  numeric_cols = c("catch_total", "hours_fished", "party_size"),
  outlier_method = "iqr",
  iqr_multiplier = 2.0
)

# Group-wise outlier detection
outlier_check <- qa_check_outliers(
  interviews,
  by_group = c("species", "location"),
  outlier_method = "modified_zscore"
)

# Conservative detection for high-stakes data
outlier_check <- qa_check_outliers(
  interviews,
  outlier_method = "iqr",
  iqr_multiplier = 3.0,  # Only extreme outliers
  exclude_zeros = TRUE
)
} # }
```
