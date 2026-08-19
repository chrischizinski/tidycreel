# Check for Mixed or Inconsistent Measurement Units

Detects mixing of measurement units (inches vs mm) or precision levels,
which creates variability and unknown bias (Table 17.3, \#6).

## Usage

``` r
qa_check_units(
  interviews,
  length_col = "length_mm",
  weight_col = NULL,
  species_col = NULL,
  interviewer_col = NULL,
  mm_range = c(50, 1000),
  inch_range = c(2, 50)
)
```

## Arguments

- interviews:

  Interview data with measurements

- length_col:

  Column containing fish lengths (default "length_mm")

- weight_col:

  Column containing fish weights (optional)

- species_col:

  Column for species-specific checks (optional)

- interviewer_col:

  Column containing interviewer IDs (optional). Used to detect
  interviewer-specific unit preferences.

- mm_range:

  Numeric vector of length 2 specifying expected range for mm
  measurements (default c(50, 1000)). Values outside this suggest
  inches.

- inch_range:

  Numeric vector of length 2 specifying expected range for inch
  measurements (default c(2, 50)). Values in this range with low
  variance suggest inches.

## Value

List with:

- issue_detected:

  Logical, TRUE if unit issues detected

- severity:

  "high", "medium", "low", or "none"

- likely_units:

  Detected measurement system: "mm", "inches", or "mixed"

- n_measurements:

  Total number of length measurements

- n_likely_mm:

  Number of measurements likely in mm

- n_likely_inches:

  Number of measurements likely in inches

- precision_stats:

  Summary of measurement precision (decimal places)

- mixed_unit_samples:

  Sample of records with suspected wrong units

- interviewer_units:

  Unit patterns by interviewer (if interviewer_col provided)

- suspicious_interviewers:

  Interviewers using different units than majority

- species_unit_patterns:

  Unit patterns by species (if species_col provided)

- recommendation:

  Text guidance for remediation

## Details

### Detection Logic

1.  **Unit Detection:**

    - Examine length value distributions

    - Detect likely inch measurements (values 2-50 with low variance)

    - Detect likely mm measurements (values 50-1000)

    - Flag if both present in same dataset

2.  **Precision Detection:**

    - Check for inconsistent precision (mix of 10mm, 1mm, 0.1mm)

    - Count decimal places to infer measurement precision

    - Recommend standardized precision levels

3.  **Species-Specific:**

    - Flag suspicious length-species combinations (if species_col
      provided)

    - E.g., 500mm for a species typically 12" (likely wrong units)

4.  **Interviewer Patterns:**

    - Check if different interviewers use different units

    - Flag interviewer-specific unit preferences

### Severity Levels

- **High:** Clear evidence of mixed units (\>20% in wrong units)

- **Medium:** Moderate mixing (5-20% in wrong units) or inconsistent
  precision

- **Low:** Suspicious patterns (\<5% in wrong units)

- **None:** Consistent units and precision

## References

*Analysis and Interpretation of Freshwater Fisheries Data, 2nd Edition.*
Chapter 17: Creel Surveys, Table 17.3.

## Examples

``` r
if (FALSE) { # \dontrun{
library(tidycreel)

# Basic check
qa_result <- qa_check_units(
  interviews,
  length_col = "length_mm"
)

# With interviewer analysis
qa_result <- qa_check_units(
  interviews,
  length_col = "length_mm",
  interviewer_col = "clerk_id",
  species_col = "species"
)

if (qa_result$issue_detected) {
  print(qa_result$likely_units)
  print(qa_result$recommendation)
}
} # }
```
