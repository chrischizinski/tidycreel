# creel_estimates S3 class ----

#' Create a creel_estimates object
#'
#' Internal constructor for creel survey estimate results. Creates an S3 object
#' containing estimates with standard errors, confidence intervals, and metadata
#' about the estimation method and variance approach.
#'
#' @param estimates Data frame with estimate columns (at minimum: estimate, se,
#'   ci_lower, ci_upper, n)
#' @param method Character string indicating estimation method (default: "total")
#' @param variance_method Character string indicating variance estimation method
#'   (default: "taylor")
#' @param design NULL or creel_design object - reference to source design
#' @param conf_level Numeric confidence level (default: 0.95)
#'
#' @return List of class "creel_estimates" with components:
#'   - estimates: data frame of estimates
#'   - method: estimation method
#'   - variance_method: variance estimation method
#'   - design: source design object or NULL
#'   - conf_level: confidence level
#'
#' @keywords internal
#' @noRd
new_creel_estimates <- function(estimates,
                                method = "total",
                                variance_method = "taylor",
                                design = NULL,
                                conf_level = 0.95) {
  # Input validation
  stopifnot(
    "estimates must be a data.frame" = is.data.frame(estimates),
    "method must be character" = is.character(method) && length(method) == 1,
    "variance_method must be character" = is.character(variance_method) && length(variance_method) == 1,
    "conf_level must be numeric" = is.numeric(conf_level) && length(conf_level) == 1
  )

  structure(
    list(
      estimates = estimates,
      method = method,
      variance_method = variance_method,
      design = design,
      conf_level = conf_level
    ),
    class = "creel_estimates"
  )
}

#' Format creel_estimates for printing
#'
#' @param x A creel_estimates object
#' @param ... Additional arguments (currently ignored)
#'
#' @return Character vector with formatted output
#'
#' @export
format.creel_estimates <- function(x, ...) {
  # Convert variance method to human-readable form
  variance_display <- switch(x$variance_method, # nolint: object_usage_linter
    taylor = "Taylor linearization",
    bootstrap = "Bootstrap",
    jackknife = "Jackknife",
    x$variance_method
  )

  # Format confidence level as percentage
  conf_pct <- paste0(round(x$conf_level * 100), "%") # nolint: object_usage_linter

  # Build formatted output using cli
  output <- character()

  output <- c(output, cli::cli_format_method({
    cli::cli_h1("Creel Survey Estimates")
    cli::cli_text("Method: {x$method}")
    cli::cli_text("Variance: {variance_display}")
    cli::cli_text("Confidence level: {conf_pct}")
    cli::cli_text("")
  }))

  # Add estimates table
  output <- c(output, utils::capture.output(print(x$estimates)))

  output
}

#' Print creel_estimates
#'
#' @param x A creel_estimates object
#' @param ... Additional arguments passed to format
#'
#' @return The input object, invisibly
#'
#' @export
print.creel_estimates <- function(x, ...) {
  cat(format(x, ...), sep = "\n")
  invisible(x)
}
