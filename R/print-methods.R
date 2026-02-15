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
