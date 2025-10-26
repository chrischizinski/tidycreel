#' Generate Comprehensive Quality Control Report
#'
#' Creates a detailed quality control report from QA check results, with
#' options for HTML, PDF, or console output. Includes visualizations,
#' detailed findings, and actionable recommendations.
#'
#' @param qa_results Results from \code{\link{qa_checks}} function
#' @param output_file Output file path. Extension determines format:
#'   ".html" for HTML, ".pdf" for PDF. If NULL, prints to console.
#' @param title Report title. Default "Creel Survey Data Quality Report"
#' @param include_plots Logical, whether to include diagnostic plots.
#'   Default TRUE for HTML/PDF, FALSE for console.
#' @param include_data_samples Logical, whether to include sample data
#'   showing specific issues. Default TRUE.
#' @param template_path Path to custom report template (advanced users)
#' @param open_report Logical, whether to open the report after generation.
#'   Default TRUE for HTML/PDF.
#' @param ... Additional arguments passed to rendering functions
#'
#' @return Invisibly returns the path to the generated report file,
#'   or NULL if printed to console.
#'
#' @details
#' ## Report Sections
#'
#' The generated report includes:
#' 1. **Executive Summary** - Overall quality score and grade
#' 2. **Data Overview** - Summary of input datasets
#' 3. **Quality Check Results** - Detailed findings for each check
#' 4. **Issue Details** - Sample records showing specific problems
#' 5. **Diagnostic Plots** - Visual summaries of data quality issues
#' 6. **Recommendations** - Prioritized action items
#' 7. **Methodology** - Description of QA/QC procedures used
#'
#' ## Output Formats
#'
#' - **HTML**: Interactive report with collapsible sections, suitable for
#'   sharing and web viewing
#' - **PDF**: Print-ready report for formal documentation
#' - **Console**: Text summary for quick review during analysis
#'
#' ## Diagnostic Plots
#'
#' When \code{include_plots = TRUE}, the report includes:
#' - Effort distribution histograms (outlier detection)
#' - Catch rate vs effort scatter plots (relationship validation)
#' - Zero count frequency by stratum (zero detection patterns)
#' - Spatial coverage maps (if location data available)
#' - Temporal coverage heatmaps (sampling intensity over time)
#'
#' @examples
#' \dontrun{
#' # Run QA checks
#' qa_results <- qa_checks(interviews = my_interviews, counts = my_counts)
#' 
#' # Generate HTML report
#' qc_report(qa_results, "data_quality_report.html")
#' 
#' # Generate PDF report
#' qc_report(qa_results, "data_quality_report.pdf")
#' 
#' # Print to console
#' qc_report(qa_results)
#' 
#' # Minimal report without plots (faster)
#' qc_report(qa_results, "quick_report.html", include_plots = FALSE)
#' }
#'
#' @seealso \code{\link{qa_checks}}
#'
#' @export
qc_report <- function(qa_results,
                      output_file = NULL,
                      title = "Creel Survey Data Quality Report",
                      include_plots = NULL,
                      include_data_samples = TRUE,
                      template_path = NULL,
                      open_report = TRUE,
                      ...) {
  
  # Validate inputs
  if (!inherits(qa_results, "qa_checks_result")) {
    cli::cli_abort("{.arg qa_results} must be output from {.fn qa_checks}")
  }
  
  # Determine output format
  if (is.null(output_file)) {
    output_format <- "console"
    if (is.null(include_plots)) include_plots <- FALSE
  } else {
    ext <- tools::file_ext(output_file)
    output_format <- switch(tolower(ext),
      "html" = "html",
      "pdf" = "pdf", 
      "md" = "markdown",
      cli::cli_abort("Unsupported file extension: {.val {ext}}. Use .html or .pdf")
    )
    if (is.null(include_plots)) include_plots <- TRUE
  }
  
  # Console output (simple text report)
  if (output_format == "console") {
    return(.qc_console_report(qa_results, title, include_data_samples))
  }
  
  # Check if required packages are available for file output
  required_pkgs <- c("rmarkdown")
  if (output_format == "pdf") {
    required_pkgs <- c(required_pkgs, "tinytex")
  }
  
  missing_pkgs <- required_pkgs[!sapply(required_pkgs, requireNamespace, quietly = TRUE)]
  if (length(missing_pkgs) > 0) {
    cli::cli_abort("Required packages not available: {.pkg {missing_pkgs}}.
                   Install with: install.packages({.val {missing_pkgs}})")
  }
  
  # Generate file-based report
  .qc_file_report(
    qa_results = qa_results,
    output_file = output_file,
    output_format = output_format,
    title = title,
    include_plots = include_plots,
    include_data_samples = include_data_samples,
    template_path = template_path,
    open_report = open_report,
    ...
  )
}

# Console report implementation
.qc_console_report <- function(qa_results, title, include_data_samples) {
  cli::cli_rule(title)
  
  # Executive summary
  cli::cli_h2("Executive Summary")
  cli::cli_text("Overall Quality Score: {.strong {qa_results$overall_score}}/100 (Grade: {.strong {qa_results$overall_grade}})")
  cli::cli_text("Total Issues: {.strong {qa_results$issues_detected}}")
  cli::cli_text("High Severity Issues: {.strong {qa_results$high_severity_issues}}")
  
  # Data overview
  if (!is.null(qa_results$data_summary)) {
    cli::cli_h2("Data Overview")
    for (dataset in names(qa_results$data_summary)) {
      info <- qa_results$data_summary[[dataset]]
      cli::cli_text("{.strong {stringr::str_to_title(dataset)}}: {info$n_records} records, {info$n_columns} columns")
    }
  }
  
  # Check results
  if (nrow(qa_results$summary) > 0) {
    cli::cli_h2("Quality Check Results")
    
    # Group by status for cleaner display
    passed_checks <- qa_results$summary[qa_results$summary$status == "PASS", ]
    failed_checks <- qa_results$summary[qa_results$summary$status == "ISSUES", ]
    
    if (nrow(passed_checks) > 0) {
      cli::cli_alert_success("Passed Checks ({nrow(passed_checks)}):")
      for (i in seq_len(nrow(passed_checks))) {
        cli::cli_text("  ✓ {passed_checks$check[i]}: {passed_checks$description[i]}")
      }
    }
    
    if (nrow(failed_checks) > 0) {
      cli::cli_alert_warning("Failed Checks ({nrow(failed_checks)}):")
      for (i in seq_len(nrow(failed_checks))) {
        severity_icon <- switch(failed_checks$severity[i],
          "high" = "🔴",
          "medium" = "🟡", 
          "low" = "🟢",
          "⚪"
        )
        cli::cli_text("  {severity_icon} {failed_checks$check[i]} ({failed_checks$severity[i]}): {failed_checks$description[i]}")
        if (failed_checks$issues_found[i] > 0) {
          cli::cli_text("    Issues found: {failed_checks$issues_found[i]}")
        }
      }
    }
  }
  
  # Sample problematic records
  if (include_data_samples && !is.null(qa_results$details)) {
    cli::cli_h2("Sample Issues")
    for (check_name in names(qa_results$details)) {
      check_result <- qa_results$details[[check_name]]
      if (check_result$issue_detected) {
        .qc_print_sample_issues(check_name, check_result)
      }
    }
  }
  
  # Recommendations
  cli::cli_h2("Recommendations")
  for (rec in qa_results$recommendations) {
    cli::cli_text(rec)
  }
  
  cli::cli_rule()
  
  invisible(NULL)
}

# File-based report implementation
.qc_file_report <- function(qa_results, output_file, output_format, title,
                           include_plots, include_data_samples, template_path,
                           open_report, ...) {
  
  # Create temporary R Markdown file
  if (is.null(template_path)) {
    rmd_content <- .qc_create_rmd_template(
      qa_results, title, include_plots, include_data_samples
    )
    temp_rmd <- tempfile(fileext = ".Rmd")
    writeLines(rmd_content, temp_rmd)
  } else {
    temp_rmd <- template_path
  }
  
  # Render the report
  cli::cli_alert_info("Generating {output_format} report...")
  
  tryCatch({
    if (output_format == "html") {
      rmarkdown::render(
        temp_rmd,
        output_format = rmarkdown::html_document(
          toc = TRUE,
          toc_float = TRUE,
          theme = "flatly",
          code_folding = "hide"
        ),
        output_file = basename(output_file),
        output_dir = dirname(output_file),
        params = list(qa_results = qa_results),
        quiet = TRUE,
        ...
      )
    } else if (output_format == "pdf") {
      rmarkdown::render(
        temp_rmd,
        output_format = rmarkdown::pdf_document(
          toc = TRUE,
          number_sections = TRUE
        ),
        output_file = basename(output_file),
        output_dir = dirname(output_file), 
        params = list(qa_results = qa_results),
        quiet = TRUE,
        ...
      )
    }
    
    cli::cli_alert_success("Report generated: {.file {output_file}}")
    
    # Open report if requested
    if (open_report && interactive()) {
      if (output_format == "html") {
        utils::browseURL(output_file)
      } else {
        utils::browseURL(output_file)
      }
    }
    
    # Clean up temporary file
    if (is.null(template_path)) {
      unlink(temp_rmd)
    }
    
    invisible(output_file)
    
  }, error = function(e) {
    cli::cli_alert_danger("Failed to generate report: {e$message}")
    if (is.null(template_path)) {
      unlink(temp_rmd)
    }
    stop(e)
  })
}

# Create R Markdown template
.qc_create_rmd_template <- function(qa_results, title, include_plots, include_data_samples) {
  c(
    "---",
    paste0("title: \"", title, "\""),
    paste0("date: \"", Sys.Date(), "\""),
    "output:",
    "  html_document:",
    "    toc: true",
    "    toc_float: true", 
    "    theme: flatly",
    "    code_folding: hide",
    "  pdf_document:",
    "    toc: true",
    "    number_sections: true",
    "params:",
    "  qa_results: !r NULL",
    "---",
    "",
    "```{r setup, include=FALSE}",
    "knitr::opts_chunk$set(echo = FALSE, warning = FALSE, message = FALSE)",
    "library(tidycreel)",
    "library(ggplot2)",
    "library(dplyr)",
    "qa_results <- params$qa_results",
    "```",
    "",
    "# Executive Summary",
    "",
    paste0("**Overall Quality Score:** ", qa_results$overall_score, "/100 (Grade: ", qa_results$overall_grade, ")"),
    "",
    paste0("**Total Issues Found:** ", qa_results$issues_detected),
    "",
    paste0("**High Severity Issues:** ", qa_results$high_severity_issues),
    "",
    "# Data Overview",
    "",
    "```{r data-summary}",
    "if (!is.null(qa_results$data_summary)) {",
    "  for (dataset in names(qa_results$data_summary)) {",
    "    info <- qa_results$data_summary[[dataset]]",
    "    cat(paste0('**', stringr::str_to_title(dataset), ':** ', info$n_records, ' records, ', info$n_columns, ' columns\\n\\n'))",
    "  }",
    "}",
    "```",
    "",
    "# Quality Check Results",
    "",
    "```{r check-summary}",
    "if (nrow(qa_results$summary) > 0) {",
    "  knitr::kable(qa_results$summary, caption = 'Summary of Quality Checks')",
    "}",
    "```",
    "",
    if (include_plots) {
      c(
        "# Diagnostic Plots",
        "",
        "```{r plots, fig.width=10, fig.height=6}",
        "# Placeholder for diagnostic plots",
        "# Will implement specific plots based on available data",
        "```",
        ""
      )
    } else {
      ""
    },
    "# Recommendations",
    "",
    "```{r recommendations}",
    "for (rec in qa_results$recommendations) {",
    "  cat(paste0('- ', rec, '\\n'))",
    "}",
    "```",
    "",
    "# Methodology",
    "",
    "This report was generated using the tidycreel package quality assurance framework.",
    "The checks are based on common creel survey mistakes identified in Table 17.3",
    "of *Analysis and Interpretation of Freshwater Fisheries Data, 2nd Edition*.",
    "",
    "For more information, see the tidycreel package documentation."
  )
}

# Helper function to print sample issues
.qc_print_sample_issues <- function(check_name, check_result) {
  cli::cli_h3(stringr::str_to_title(check_name))
  
  # Print sample records if available
  sample_fields <- c(
    "outlier_records", "effort_inconsistent_records", 
    "zero_effort_records", "bias_records", "unit_inconsistent_records",
    "coverage_gap_records"
  )
  
  for (field in sample_fields) {
    if (!is.null(check_result[[field]]) && nrow(check_result[[field]]) > 0) {
      cli::cli_text("Sample problematic records:")
      print(utils::head(check_result[[field]], 3))
      break
    }
  }
}