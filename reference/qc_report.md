# Generate Comprehensive Quality Control Report

Creates a detailed quality control report from QA check results, with
options for HTML, PDF, or console output. Includes visualizations,
detailed findings, and actionable recommendations.

## Usage

``` r
qc_report(
  qa_results,
  output_file = NULL,
  title = "Creel Survey Data Quality Report",
  include_plots = NULL,
  include_data_samples = TRUE,
  template_path = NULL,
  open_report = TRUE,
  ...
)
```

## Arguments

- qa_results:

  Results from [`qa_checks`](qa_checks.md) function

- output_file:

  Output file path. Extension determines format: ".html" for HTML,
  ".pdf" for PDF. If NULL, prints to console.

- title:

  Report title. Default "Creel Survey Data Quality Report"

- include_plots:

  Logical, whether to include diagnostic plots. Default TRUE for
  HTML/PDF, FALSE for console.

- include_data_samples:

  Logical, whether to include sample data showing specific issues.
  Default TRUE.

- template_path:

  Path to custom report template (advanced users)

- open_report:

  Logical, whether to open the report after generation. Default TRUE for
  HTML/PDF.

- ...:

  Additional arguments passed to rendering functions

## Value

Invisibly returns the path to the generated report file, or NULL if
printed to console.

## Details

### Report Sections

The generated report includes:

1.  **Executive Summary** - Overall quality score and grade

2.  **Data Overview** - Summary of input datasets

3.  **Quality Check Results** - Detailed findings for each check

4.  **Issue Details** - Sample records showing specific problems

5.  **Diagnostic Plots** - Visual summaries of data quality issues

6.  **Recommendations** - Prioritized action items

7.  **Methodology** - Description of QA/QC procedures used

### Output Formats

- **HTML**: Interactive report with collapsible sections, suitable for
  sharing and web viewing

- **PDF**: Print-ready report for formal documentation

- **Console**: Text summary for quick review during analysis

### Diagnostic Plots

When `include_plots = TRUE`, the report includes:

- Effort distribution histograms (outlier detection)

- Catch rate vs effort scatter plots (relationship validation)

- Zero count frequency by stratum (zero detection patterns)

- Spatial coverage maps (if location data available)

- Temporal coverage heatmaps (sampling intensity over time)

## See also

[`qa_checks`](qa_checks.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Run QA checks
qa_results <- qa_checks(interviews = my_interviews, counts = my_counts)

# Generate HTML report
qc_report(qa_results, "data_quality_report.html")

# Generate PDF report
qc_report(qa_results, "data_quality_report.pdf")

# Print to console
qc_report(qa_results)

# Minimal report without plots (faster)
qc_report(qa_results, "quick_report.html", include_plots = FALSE)
} # }
```
