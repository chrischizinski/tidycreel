#' Comprehensive Quality Assurance Checks for Creel Survey Data
#'
#' Runs a comprehensive suite of quality assurance checks on creel survey data
#' to detect common mistakes identified in Table 17.3 and ensure data quality
#' before analysis.
#'
#' @param counts Count data (optional, for zero count and coverage checks)
#' @param interviews Interview data (optional, for effort and targeting checks)
#' @param schedule Survey schedule data (optional, for temporal coverage)
#' @param checks Character vector of checks to run. Options:
#'   \describe{
#'     \item{"effort"}{Party-level effort calculation validation}
#'     \item{"zeros"}{Zero count detection and validation}
#'     \item{"targeting"}{Successful party bias detection}
#'     \item{"units"}{Measurement unit consistency}
#'     \item{"spatial_coverage"}{Spatial sampling validation}
#'     \item{"species"}{Species identification validation}
#'     \item{"temporal"}{Temporal coverage validation}
#'     \item{"outliers"}{Statistical outlier detection}
#'     \item{"missing"}{Missing data pattern analysis}
#'   }
#'   Default is "all" which runs all available checks.
#' @param severity_threshold Minimum severity level to report. One of:
#'   "high", "medium", "low". Default "medium".
#' @param return_details Logical, whether to return detailed results for each
#'   check. If FALSE, returns summary only. Default TRUE.
#' @param ... Additional arguments passed to individual check functions
#'
#' @return List with:
#'   \describe{
#'     \item{overall_score}{Numeric quality score 0-100}
#'     \item{overall_grade}{Letter grade A-F based on score}
#'     \item{issues_detected}{Total number of issues found}
#'     \item{high_severity_issues}{Number of high severity issues}
#'     \item{summary}{Data frame summarizing all checks}
#'     \item{recommendations}{Character vector of prioritized recommendations}
#'     \item{details}{List of detailed results from each check (if requested)}
#'     \item{data_summary}{Summary of input data characteristics}
#'   }
#'
#' @details
#' ## Quality Scoring System
#'
#' The overall quality score (0-100) is calculated as:
#' - Start with 100 points
#' - Subtract points for each issue based on severity:
#'   - High severity: -15 points per issue
#'   - Medium severity: -8 points per issue
#'   - Low severity: -3 points per issue
#' - Minimum score is 0
#'
#' ## Grade Scale
#' - A (90-100): Excellent data quality, ready for analysis
#' - B (80-89): Good quality, minor issues to address
#' - C (70-79): Acceptable quality, some issues need attention
#' - D (60-69): Poor quality, significant issues must be fixed
#' - F (0-59): Failing quality, major problems prevent reliable analysis
#'
#' ## Common Issues Detected
#'
#' Based on Table 17.3 common creel survey mistakes:
#' 1. **Skipping zeros** - No zero counts recorded
#' 2. **Targeting successful parties** - Interview bias
#' 3. **Measurement unit errors** - Inconsistent units
#' 4. **Party effort calculation errors** - Incorrect angler-hour calculations
#' 5. **Spatial coverage gaps** - Areas not sampled
#' 6. **Species identification issues** - Unlikely species combinations
#' 7. **Temporal coverage gaps** - Missing time periods
#' 8. **Statistical outliers** - Extreme values needing validation
#' 9. **Missing data patterns** - Systematic data gaps
#'
#' @examples
#' \dontrun{
#' # Run all checks on interview data
#' qa_results <- qa_checks(interviews = my_interviews)
#'
#' # Run specific checks only
#' qa_results <- qa_checks(
#'     interviews = my_interviews,
#'     counts = my_counts,
#'     checks = c("effort", "zeros", "targeting")
#' )
#'
#' # Get summary only (faster for large datasets)
#' qa_summary <- qa_checks(
#'     interviews = my_interviews,
#'     return_details = FALSE
#' )
#'
#' # Print results
#' print(qa_results)
#' }
#'
#' @seealso
#' \code{\link{qa_check_effort}}, \code{\link{qa_check_zeros}},
#' \code{\link{qa_check_targeting}}, \code{\link{qa_check_units}},
#' \code{\link{qa_check_spatial_coverage}}, \code{\link{qc_report}}
#'
#' @export
qa_checks <- function(counts = NULL,
                      interviews = NULL,
                      schedule = NULL,
                      checks = "all",
                      severity_threshold = "medium",
                      return_details = TRUE,
                      ...) {
    # Validate inputs
    if (is.null(counts) && is.null(interviews) && is.null(schedule)) {
        cli::cli_abort("At least one of {.arg counts}, {.arg interviews}, or {.arg schedule} must be provided.")
    }

    # Define available checks
    available_checks <- c(
        "effort", "zeros", "targeting", "units", "spatial_coverage",
        "species", "temporal", "outliers", "missing"
    )

    # Handle "all" option
    if (length(checks) == 1 && checks == "all") {
        checks <- available_checks
    }

    # Validate check names
    invalid_checks <- setdiff(checks, available_checks)
    if (length(invalid_checks) > 0) {
        cli::cli_abort("Invalid check names: {.val {invalid_checks}}.
                   Available checks: {.val {available_checks}}")
    }

    # Validate severity threshold
    valid_severities <- c("high", "medium", "low")
    if (!severity_threshold %in% valid_severities) {
        cli::cli_abort("{.arg severity_threshold} must be one of {.val {valid_severities}}")
    }

    # Initialize results storage
    check_results <- list()
    summary_rows <- list()

    cli::cli_h1("Running Quality Assurance Checks")
    cli::cli_text("Checking for common creel survey data issues...")

    # Run effort checks
    if ("effort" %in% checks && !is.null(interviews)) {
        cli::cli_alert_info("Checking party-level effort calculations...")
        check_results$effort <- qa_check_effort(interviews, ...)
        summary_rows$effort <- .qa_summarize_check("effort", check_results$effort)
    }

    # Run zero count checks
    if ("zeros" %in% checks && !is.null(counts)) {
        cli::cli_alert_info("Checking for zero count patterns...")
        check_results$zeros <- qa_check_zeros(counts, ...)
        summary_rows$zeros <- .qa_summarize_check("zeros", check_results$zeros)
    }

    # Run targeting bias checks
    if ("targeting" %in% checks && !is.null(interviews)) {
        cli::cli_alert_info("Checking for successful party targeting bias...")
        check_results$targeting <- qa_check_targeting(interviews, ...)
        summary_rows$targeting <- .qa_summarize_check("targeting", check_results$targeting)
    }

    # Run unit consistency checks
    if ("units" %in% checks && !is.null(interviews)) {
        cli::cli_alert_info("Checking measurement unit consistency...")
        check_results$units <- qa_check_units(interviews, ...)
        summary_rows$units <- .qa_summarize_check("units", check_results$units)
    }

    # Run spatial coverage checks
    if ("spatial_coverage" %in% checks && !is.null(counts)) {
        cli::cli_alert_info("Checking spatial coverage...")
        check_results$spatial_coverage <- qa_check_spatial_coverage(counts, ...)
        summary_rows$spatial_coverage <- .qa_summarize_check("spatial_coverage", check_results$spatial_coverage)
    }

    # Run species validation checks
    if ("species" %in% checks && !is.null(interviews)) {
        cli::cli_alert_info("Checking species identification...")
        check_results$species <- qa_check_species(interviews, ...)
        summary_rows$species <- .qa_summarize_check("species", check_results$species)
    }

    # Run temporal coverage checks
    if ("temporal" %in% checks && (!is.null(counts) || !is.null(interviews))) {
        cli::cli_alert_info("Checking temporal coverage...")
        temporal_data <- if (!is.null(counts)) counts else interviews
        check_results$temporal <- qa_check_temporal(temporal_data, schedule = schedule, ...)
        summary_rows$temporal <- .qa_summarize_check("temporal", check_results$temporal)
    }

    # Run statistical outlier checks
    if ("outliers" %in% checks && !is.null(interviews)) {
        cli::cli_alert_info("Checking for statistical outliers...")
        check_results$outliers <- qa_check_outliers(interviews, ...)
        summary_rows$outliers <- .qa_summarize_check("outliers", check_results$outliers)
    }

    # Run missing data pattern checks
    if ("missing" %in% checks) {
        cli::cli_alert_info("Analyzing missing data patterns...")
        missing_data <- if (!is.null(interviews)) interviews else if (!is.null(counts)) counts else schedule
        if (!is.null(missing_data)) {
            check_results$missing <- qa_check_missing(missing_data, ...)
            summary_rows$missing <- .qa_summarize_check("missing", check_results$missing)
        }
    }

    # Combine summary results
    if (length(summary_rows) > 0) {
        summary_df <- do.call(rbind, summary_rows)
        rownames(summary_df) <- NULL
    } else {
        summary_df <- data.frame(
            check = character(0),
            status = character(0),
            severity = character(0),
            issues_found = integer(0),
            description = character(0)
        )
    }

    # Calculate overall quality score
    score_info <- .qa_calculate_score(summary_df, severity_threshold)

    # Generate recommendations
    recommendations <- .qa_generate_recommendations(summary_df, severity_threshold)

    # Create data summary
    data_summary <- .qa_summarize_data(counts, interviews, schedule)

    # Build final result
    result <- list(
        overall_score = score_info$score,
        overall_grade = score_info$grade,
        issues_detected = score_info$total_issues,
        high_severity_issues = score_info$high_issues,
        summary = summary_df,
        recommendations = recommendations,
        data_summary = data_summary
    )

    # Add detailed results if requested
    if (return_details) {
        result$details <- check_results
    }

    # Add class for custom print method
    class(result) <- c("qa_checks_result", "list")

    cli::cli_h2("Quality Assessment Complete")
    cli::cli_text("Overall Score: {.strong {result$overall_score}}/100 (Grade: {.strong {result$overall_grade}})")

    if (result$high_severity_issues > 0) {
        cli::cli_alert_danger("Found {result$high_severity_issues} high severity issue{?s}")
    } else if (result$issues_detected > 0) {
        cli::cli_alert_warning("Found {result$issues_detected} issue{?s} to review")
    } else {
        cli::cli_alert_success("No significant data quality issues detected")
    }

    return(result)
}

# Helper function to summarize individual check results
.qa_summarize_check <- function(check_name, check_result) {
    data.frame(
        check = check_name,
        status = if (check_result$issue_detected) "ISSUES" else "PASS",
        severity = check_result$severity,
        issues_found = sum(c(
            check_result$n_effort_inconsistent %||% 0,
            check_result$n_zero_effort_with_catch %||% 0,
            check_result$n_outliers %||% 0,
            check_result$n_no_zeros %||% 0,
            check_result$n_bias_locations %||% 0,
            check_result$n_unit_inconsistencies %||% 0,
            check_result$n_coverage_gaps %||% 0,
            check_result$n_singleton_species %||% 0,
            check_result$n_seasonal_outliers %||% 0,
            check_result$n_location_outliers %||% 0,
            check_result$n_undersampled_strata %||% 0,
            check_result$n_missing_weekends %||% 0,
            check_result$n_gaps_daily_hours %||% 0,
            check_result$n_outliers_total %||% 0,
            check_result$n_outlier_records %||% 0,
            nrow(check_result$critical_missing %||% data.frame())
        ), na.rm = TRUE),
        description = .qa_get_check_description(check_name, check_result),
        stringsAsFactors = FALSE
    )
}

# Helper function to get check descriptions
.qa_get_check_description <- function(check_name, result) {
    switch(check_name,
        "effort" = if (result$issue_detected) {
            paste("Party effort calculation errors detected")
        } else {
            "Party effort calculations appear correct"
        },
        "zeros" = if (result$issue_detected) {
            paste("Zero count issues detected")
        } else {
            "Zero count patterns appear normal"
        },
        "targeting" = if (result$issue_detected) {
            paste("Potential targeting bias detected")
        } else {
            "No obvious targeting bias"
        },
        "units" = if (result$issue_detected) {
            paste("Unit consistency issues detected")
        } else {
            "Measurement units appear consistent"
        },
        "spatial_coverage" = if (result$issue_detected) {
            paste("Spatial coverage gaps detected")
        } else {
            "Spatial coverage appears adequate"
        },
        "species" = if (result$issue_detected) {
            paste("Species identification issues detected")
        } else {
            "Species identification appears consistent"
        },
        "temporal" = if (result$issue_detected) {
            paste("Temporal coverage issues detected")
        } else {
            "Temporal coverage appears adequate"
        },
        "outliers" = if (result$issue_detected) {
            paste("Statistical outliers detected")
        } else {
            "No significant outliers detected"
        },
        "missing" = if (result$issue_detected) {
            paste("Missing data patterns detected")
        } else {
            "Missing data patterns appear acceptable"
        },
        "Check completed"
    )
}

# Helper function to calculate overall quality score
.qa_calculate_score <- function(summary_df, severity_threshold) {
    if (nrow(summary_df) == 0) {
        return(list(score = 100, grade = "A", total_issues = 0, high_issues = 0))
    }

    # Count issues by severity
    high_issues <- sum(summary_df$severity == "high", na.rm = TRUE)
    medium_issues <- sum(summary_df$severity == "medium", na.rm = TRUE)
    low_issues <- sum(summary_df$severity == "low", na.rm = TRUE)

    # Calculate score (start with 100, subtract points)
    score <- 100
    score <- score - (high_issues * 15) # -15 points per high severity
    score <- score - (medium_issues * 8) # -8 points per medium severity
    score <- score - (low_issues * 3) # -3 points per low severity
    score <- max(0, score) # Minimum score is 0

    # Assign letter grade
    grade <- if (score >= 90) "A" else if (score >= 80) "B" else if (score >= 70) "C" else if (score >= 60) "D" else "F"

    total_issues <- high_issues + medium_issues + low_issues

    list(
        score = score,
        grade = grade,
        total_issues = total_issues,
        high_issues = high_issues
    )
}

# Helper function to generate prioritized recommendations
.qa_generate_recommendations <- function(summary_df, severity_threshold) {
    if (nrow(summary_df) == 0) {
        return("No issues detected. Data appears ready for analysis.")
    }

    recommendations <- character(0)

    # High priority recommendations
    high_issues <- summary_df[summary_df$severity == "high" & summary_df$status == "ISSUES", ]
    if (nrow(high_issues) > 0) {
        recommendations <- c(
            recommendations,
            "HIGH PRIORITY: Address the following critical issues before analysis:",
            paste("-", high_issues$description)
        )
    }

    # Medium priority recommendations
    if (severity_threshold %in% c("medium", "low")) {
        medium_issues <- summary_df[summary_df$severity == "medium" & summary_df$status == "ISSUES", ]
        if (nrow(medium_issues) > 0) {
            recommendations <- c(
                recommendations,
                "MEDIUM PRIORITY: Consider addressing these issues:",
                paste("-", medium_issues$description)
            )
        }
    }

    # Low priority recommendations
    if (severity_threshold == "low") {
        low_issues <- summary_df[summary_df$severity == "low" & summary_df$status == "ISSUES", ]
        if (nrow(low_issues) > 0) {
            recommendations <- c(
                recommendations,
                "LOW PRIORITY: Minor issues to review:",
                paste("-", low_issues$description)
            )
        }
    }

    if (length(recommendations) == 0) {
        recommendations <- "No significant issues detected. Data appears ready for analysis."
    }

    recommendations
}

# Helper function to summarize input data
.qa_summarize_data <- function(counts, interviews, schedule) {
    summary <- list()

    if (!is.null(interviews)) {
        summary$interviews <- list(
            n_records = nrow(interviews),
            n_columns = ncol(interviews),
            date_range = if ("date" %in% names(interviews)) {
                range(interviews$date, na.rm = TRUE)
            } else {
                "Date column not found"
            }
        )
    }

    if (!is.null(counts)) {
        summary$counts <- list(
            n_records = nrow(counts),
            n_columns = ncol(counts),
            date_range = if ("date" %in% names(counts)) {
                range(counts$date, na.rm = TRUE)
            } else {
                "Date column not found"
            }
        )
    }

    if (!is.null(schedule)) {
        summary$schedule <- list(
            n_records = nrow(schedule),
            n_columns = ncol(schedule)
        )
    }

    summary
}

#' Print method for QA check results
#' @param x A qa_checks_result object
#' @param ... Additional arguments (currently unused)
#' @export
print.qa_checks_result <- function(x, ...) {
    cli::cli_h1("Creel Survey Data Quality Assessment")

    cli::cli_h2("Overall Results")
    cli::cli_text("Quality Score: {.strong {x$overall_score}}/100")
    cli::cli_text("Letter Grade: {.strong {x$overall_grade}}")
    cli::cli_text("Issues Found: {.strong {x$issues_detected}}")

    if (nrow(x$summary) > 0) {
        cli::cli_h2("Check Summary")
        print(x$summary)
    }

    cli::cli_h2("Recommendations")
    for (rec in x$recommendations) {
        cli::cli_text(rec)
    }

    invisible(x)
}
