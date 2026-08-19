# Check for Party-Level Effort Calculation Errors

Detects potential errors in party-level effort calculations, which
under/overestimates catch and harvest rates (Table 17.3, \#8).

## Usage

``` r
qa_check_effort(
  interviews,
  effort_col = NULL,
  num_anglers_col = NULL,
  hours_fished_col = NULL,
  catch_col = NULL,
  party_id_col = NULL,
  tolerance = 0.01,
  max_hours = 24,
  min_hours = 0.1
)
```

## Arguments

- interviews:

  Interview data

- effort_col:

  Column containing effort (angler-hours). If NULL and hours_fished_col
  is provided, effort will be calculated from hours and anglers.

- num_anglers_col:

  Column containing number of anglers in party

- hours_fished_col:

  Column containing hours fished per angler or party

- catch_col:

  Column containing catch counts (for zero-effort validation)

- party_id_col:

  Column with party identifiers (optional)

- tolerance:

  Numeric tolerance for effort calculation validation (default 0.01)

- max_hours:

  Maximum reasonable hours fished (default 24)

- min_hours:

  Minimum reasonable hours fished (default 0.1)

## Value

List with:

- issue_detected:

  Logical, TRUE if effort issues detected

- severity:

  "high", "medium", "low", or "none"

- n_total:

  Total number of interviews

- n_effort_inconsistent:

  Number with incorrect effort calculations

- n_zero_effort:

  Number with zero effort

- n_zero_effort_with_catch:

  Zero effort but non-zero catch

- n_outliers:

  Number with outlier effort values

- outlier_records:

  Sample of outlier records

- effort_inconsistent_records:

  Sample of records with calculation errors

- effort_summary:

  Summary statistics of effort distribution

- decimal_error_candidates:

  Records that may have decimal point errors

- recommendation:

  Text guidance for remediation

## Details

### Detection Logic

1.  **Effort Calculation Validation:**

    - Check if effort = num_anglers x hours_fished

    - Flag inconsistencies (allowing for small rounding errors)

    - Recommend correction formula

2.  **Individual Effort Variation:**

    - Check for documented individual-level effort within parties

    - Flag if always assuming all anglers fished equal time

    - Recommend individual-level effort collection

3.  **Outlier Detection:**

    - Identify unusually high/low effort values

    - Flag trips \> 24 hours or \< 0.1 hours

    - Check for decimal point errors (e.g., 0.5 entered as 5)

4.  **Zero Effort with Catch:**

    - Flag records with catch \> 0 but effort = 0 or missing

    - These create division-by-zero in CPUE calculations

### Severity Levels

- **High:** \>20% incorrect calculations OR zero effort with catch

- **Medium:** 5-20% incorrect calculations OR many outliers

- **Low:** \<5% incorrect OR minor inconsistencies

- **None:** All effort calculations correct

## References

*Analysis and Interpretation of Freshwater Fisheries Data, 2nd Edition.*
Chapter 17: Creel Surveys, Table 17.3.

## Examples

``` r
if (FALSE) { # \dontrun{
library(tidycreel)

# Basic check
qa_result <- qa_check_effort(
  interviews,
  effort_col = "hours_fished",
  num_anglers_col = "num_anglers",
  hours_fished_col = "hours_per_angler"
)

# With catch validation
qa_result <- qa_check_effort(
  interviews,
  effort_col = "angler_hours",
  num_anglers_col = "num_anglers",
  hours_fished_col = "hours",
  catch_col = "catch_total"
)

if (qa_result$issue_detected) {
  print(qa_result$recommendation)
}
} # }
```
