#' Format creel_estimates_mor for printing
#'
#' @param x A creel_estimates_mor object
#' @param ... Additional arguments (currently ignored)
#'
#' @return Character vector with formatted output
#'
#' @export
format.creel_estimates_mor <- function(x, ...) {
  # Get base formatting from parent class
  base_output <- NextMethod("format")

  # Build diagnostic banner
  banner <- cli::cli_format_method({
    cli::cli_rule(
      left = "DIAGNOSTIC: MOR Estimator (Incomplete Trips)"
    )
    cli::cli_alert_warning("Complete trips preferred for CPUE estimation.")
    cli::cli_text(
      "This estimate uses incomplete trip interviews ({x$n_incomplete} of {x$n_total} total)."
    )

    # Add truncation details if applicable
    if (!is.null(x$mor_truncate_at)) {
      if (x$mor_n_truncated > 0) {
        cli::cli_text("Truncation: {x$mor_n_truncated} trip{?s} excluded (< {x$mor_truncate_at} hours)")
      } else {
        cli::cli_text("Truncation: 0 trips excluded (threshold: {x$mor_truncate_at} hours)")
      }
    }

    cli::cli_text(
      "Validate with {.fn validate_incomplete_trips} before use (Phase 19)."
    )
    cli::cli_text("")
  })

  # Prepend banner to base output
  c(banner, base_output)
}

#' Print creel_estimates_mor
#'
#' @param x A creel_estimates_mor object
#' @param ... Additional arguments passed to format
#'
#' @return The input object, invisibly
#'
#' @export
print.creel_estimates_mor <- function(x, ...) {
  cat(format(x, ...), sep = "\n")
  invisible(x)
}

#' Format creel_estimates_diagnostic for printing
#'
#' @param x A creel_estimates_diagnostic object
#' @param ... Additional arguments (currently ignored)
#'
#' @return Character vector with formatted output
#'
#' @export
format.creel_estimates_diagnostic <- function(x, ...) {
  # Build diagnostic header
  header <- cli::cli_format_method({
    cli::cli_h1("CPUE Diagnostic Comparison")
    cli::cli_text("Complete trips vs Incomplete trips")
    cli::cli_text("")
  })

  # Build comparison table
  comparison_output <- utils::capture.output(print(x$comparison))

  # Build difference metrics section
  metrics <- cli::cli_format_method({
    cli::cli_h2("Difference Metrics")

    if (is.null(x$by_vars)) {
      # Ungrouped metrics
      cli::cli_text("Difference (complete - incomplete): {round(x$diff_estimate, 3)}")
      cli::cli_text("Ratio (complete / incomplete): {round(x$ratio_estimate, 3)}")
    } else {
      # Grouped metrics
      cli::cli_text("Per-group differences:")
      complete_rows <- x$comparison[x$comparison$trip_type == "complete", ]
      for (i in seq_along(x$diff_estimate)) {
        group_vals <- complete_rows[i, x$by_vars, drop = FALSE]
        group_label <- paste(x$by_vars, "=", group_vals[1, ], collapse = ", ") # nolint: object_usage_linter
        diff_val <- round(x$diff_estimate[i], 3) # nolint: object_usage_linter
        ratio_val <- round(x$ratio_estimate[i], 3) # nolint: object_usage_linter
        cli::cli_text("  {group_label}: diff = {diff_val}, ratio = {ratio_val}")
      }
    }
    cli::cli_text("")
  })

  # Build interpretation section
  interpretation <- cli::cli_format_method({
    cli::cli_h2("Interpretation")
    cli::cli_text("{x$interpretation}")
    cli::cli_text("")
    cli::cli_text("For statistical tests, see Phase 19 validation framework:")
    cli::cli_text("  - Test for equality of estimates (confidence interval overlap)")
    cli::cli_text("  - Test for nonstationary catch rates")
    cli::cli_text("  - Validate length-of-stay bias assumptions")
  })

  # Combine all sections
  c(header, comparison_output, "", metrics, interpretation)
}

#' Print creel_estimates_diagnostic
#'
#' @param x A creel_estimates_diagnostic object
#' @param ... Additional arguments passed to format
#'
#' @return The input object, invisibly
#'
#' @export
print.creel_estimates_diagnostic <- function(x, ...) {
  cat(format(x, ...), sep = "\n")
  invisible(x)
}
