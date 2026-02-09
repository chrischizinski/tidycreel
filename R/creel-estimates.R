# Imports ----

#' @importFrom stats coef confint reformulate
NULL

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

# Estimation functions ----

#' Estimate total effort from a creel survey design
#'
#' Computes total effort estimates with standard errors and confidence intervals
#' from a creel survey design with attached count data. Wraps survey::svytotal()
#' with Tier 2 validation and domain-specific output formatting.
#'
#' @param design A creel_design object with counts attached via
#'   \code{\link{add_counts}}. The design must have a survey object constructed.
#' @param conf_level Numeric confidence level for confidence intervals (default:
#'   0.95 for 95\% confidence intervals). Must be between 0 and 1.
#'
#' @return A creel_estimates S3 object (list) with components: estimates
#'   (tibble with estimate, se, ci_lower, ci_upper, n columns), method
#'   (character: "total"), variance_method (character: "taylor"), design
#'   (reference to source creel_design), and conf_level (numeric).
#'
#' @details
#' The function performs Tier 2 validation before estimation, issuing warnings
#' (not errors) for: zero values in count variables, negative values in count
#' variables, and sparse strata (< 3 observations). Warnings do not prevent
#' estimation but indicate data quality issues.
#'
#' Phase 4 uses Taylor linearization variance estimation (default in survey
#' package). Bootstrap and jackknife methods will be added in Phase 6.
#'
#' @examples
#' \dontrun{
#' # Basic usage
#' calendar <- data.frame(
#'   date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
#'   day_type = c("weekday", "weekday", "weekend", "weekend")
#' )
#' design <- creel_design(calendar, date = date, strata = day_type)
#'
#' counts <- data.frame(
#'   date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
#'   day_type = c("weekday", "weekday", "weekend", "weekend"),
#'   effort_hours = c(15, 23, 45, 52)
#' )
#'
#' design_with_counts <- add_counts(design, counts)
#' result <- estimate_effort(design_with_counts)
#' print(result)
#'
#' # Custom confidence level
#' result_90 <- estimate_effort(design_with_counts, conf_level = 0.90)
#' }
#'
#' @export
estimate_effort <- function(design, conf_level = 0.95) {
  # Validate input is creel_design
  if (!inherits(design, "creel_design")) {
    cli::cli_abort(c(
      "{.arg design} must be a {.cls creel_design} object.",
      "x" = "{.arg design} is {.cls {class(design)[1]}}.",
      "i" = "Create a design with {.fn creel_design}."
    ))
  }

  # Validate design$survey exists
  if (is.null(design$survey)) {
    cli::cli_abort(c(
      "No survey design available.",
      "x" = "Call {.fn add_counts} before estimating effort.",
      "i" = "Example: {.code design <- add_counts(design, counts)}"
    ))
  }

  # Tier 2 validation - data quality checks (warnings only)
  warn_tier2_issues(design) # nolint: object_usage_linter

  # Identify the count variable
  # Find first numeric column that is NOT design metadata
  counts_data <- design$counts
  excluded_cols <- c(design$date_col, design$strata_cols, design$psu_col)
  numeric_cols <- names(counts_data)[sapply(counts_data, is.numeric)]
  count_vars <- setdiff(numeric_cols, excluded_cols)

  if (length(count_vars) == 0) {
    cli::cli_abort(c(
      "No count variable found in count data.",
      "x" = "Count data must have at least one numeric column.",
      "i" = "Numeric columns found: {.field {numeric_cols}}",
      "i" = "Design metadata columns: {.field {excluded_cols}}"
    ))
  }

  # Use first count variable
  count_var <- count_vars[1]

  # Create formula
  count_formula <- stats::reformulate(count_var)

  # Call survey::svytotal (suppress expected survey package warnings)
  svy_result <- suppressWarnings(survey::svytotal(count_formula, design$survey))

  # Extract estimates
  estimate <- as.numeric(coef(svy_result))
  se <- as.numeric(survey::SE(svy_result))
  ci <- confint(svy_result, level = conf_level)
  ci_lower <- ci[1, 1]
  ci_upper <- ci[1, 2]
  n <- nrow(counts_data)

  # Build estimates tibble
  estimates_df <- tibble::tibble(
    estimate = estimate,
    se = se,
    ci_lower = ci_lower,
    ci_upper = ci_upper,
    n = n
  )

  # Return creel_estimates object
  new_creel_estimates( # nolint: object_usage_linter
    estimates = estimates_df,
    method = "total",
    variance_method = "taylor",
    design = design,
    conf_level = conf_level
  )
}
