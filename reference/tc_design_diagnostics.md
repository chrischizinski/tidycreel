# Survey Design Diagnostics

Comprehensive assessment of survey design quality and potential issues.
Built-in to tidycreel estimators for automatic quality checking.

## Usage

``` r
tc_design_diagnostics(design, detailed = FALSE)
```

## Arguments

- design:

  Survey design object

- detailed:

  Logical, whether to include detailed diagnostics

## Value

List with class "tc_design_diagnostics" containing:

- design_summary:

  Basic design characteristics

- quality_checks:

  Design quality assessments

- warnings:

  Potential issues detected

- recommendations:

  Suggestions for improvement

## Details

Performs comprehensive design diagnostics including:

- Stratification balance and singleton strata detection

- Clustering structure and small cluster detection

- Weight distribution and extreme weights

- Finite population correction assessment

- Sample size adequacy by stratum

## Examples

``` r
if (FALSE) { # \dontrun{
# Diagnose survey design
diag <- tc_design_diagnostics(creel_design)
print(diag)

# Check for warnings
diag$warnings

# Get recommendations
diag$recommendations
} # }
```
