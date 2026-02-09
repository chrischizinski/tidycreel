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
#' @param by_vars NULL or character vector of grouping variable names
#'
#' @return List of class "creel_estimates" with components:
#'   - estimates: data frame of estimates
#'   - method: estimation method
#'   - variance_method: variance estimation method
#'   - design: source design object or NULL
#'   - conf_level: confidence level
#'   - by_vars: grouping variable names or NULL
#'
#' @keywords internal
#' @noRd
new_creel_estimates <- function(estimates,
                                method = "total",
                                variance_method = "taylor",
                                design = NULL,
                                conf_level = 0.95,
                                by_vars = NULL) {
  # Input validation
  stopifnot(
    "estimates must be a data.frame" = is.data.frame(estimates),
    "method must be character" = is.character(method) && length(method) == 1,
    "variance_method must be character" = is.character(variance_method) && length(variance_method) == 1,
    "conf_level must be numeric" = is.numeric(conf_level) && length(conf_level) == 1,
    "by_vars must be NULL or character" = is.null(by_vars) || is.character(by_vars)
  )

  structure(
    list(
      estimates = estimates,
      method = method,
      variance_method = variance_method,
      design = design,
      conf_level = conf_level,
      by_vars = by_vars
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

    # Show grouping variables if present
    if (!is.null(x$by_vars)) {
      by_display <- paste(x$by_vars, collapse = ", ") # nolint: object_usage_linter
      cli::cli_text("Grouped by: {by_display}")
    }

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
#' (ungrouped) or survey::svyby() (grouped) with Tier 2 validation and
#' domain-specific output formatting.
#'
#' @param design A creel_design object with counts attached via
#'   \code{\link{add_counts}}. The design must have a survey object constructed.
#' @param by Optional tidy selector for grouping variables. Accepts bare column
#'   names (e.g., \code{by = day_type}), multiple columns (e.g.,
#'   \code{by = c(day_type, location)}), or tidyselect helpers (e.g.,
#'   \code{by = starts_with("day")}). When NULL (default), computes a single
#'   total estimate across all observations.
#' @param conf_level Numeric confidence level for confidence intervals (default:
#'   0.95 for 95\% confidence intervals). Must be between 0 and 1.
#'
#' @return A creel_estimates S3 object (list) with components: estimates
#'   (tibble with estimate, se, ci_lower, ci_upper, n columns, plus grouping
#'   columns if \code{by} is specified), method (character: "total"),
#'   variance_method (character: "taylor"), design (reference to source
#'   creel_design), conf_level (numeric), and by_vars (character vector of
#'   grouping variable names or NULL).
#'
#' @details
#' The function performs Tier 2 validation before estimation, issuing warnings
#' (not errors) for: zero values in count variables, negative values in count
#' variables, and sparse strata (< 3 observations). When grouped estimation is
#' used (\code{by} is not NULL), additional warnings are issued for sparse
#' groups (< 3 observations per group level).
#'
#' Grouped estimation uses \code{survey::svyby()} internally, which correctly
#' accounts for domain estimation variance. This is different from naive
#' subsetting, which would underestimate variance.
#'
#' Phase 5 uses Taylor linearization variance estimation (default in survey
#' package). Bootstrap and jackknife methods will be added in Phase 6.
#'
#' @examples
#' \dontrun{
#' # Basic ungrouped usage
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
#' # Grouped by day_type
#' result_grouped <- estimate_effort(design_with_counts, by = day_type)
#' print(result_grouped)
#'
#' # Grouped by multiple variables
#' result_multi <- estimate_effort(design_with_counts, by = c(day_type, location))
#'
#' # Custom confidence level
#' result_90 <- estimate_effort(design_with_counts, conf_level = 0.90)
#' }
#'
#' @export
estimate_effort <- function(design, by = NULL, conf_level = 0.95) {
  # Capture by parameter BEFORE validation
  by_quo <- rlang::enquo(by)

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

  # Route to grouped or ungrouped estimation
  if (rlang::quo_is_null(by_quo)) {
    # Ungrouped estimation (Phase 4 behavior)
    return(estimate_effort_total(design, conf_level)) # nolint: object_usage_linter
  } else {
    # Grouped estimation (Phase 5 behavior)
    # Resolve by parameter to column names
    by_cols <- tidyselect::eval_select(
      by_quo,
      data = design$counts,
      allow_rename = FALSE,
      allow_empty = FALSE,
      error_call = rlang::caller_env()
    )
    by_vars <- names(by_cols)

    return(estimate_effort_grouped(design, by_vars, conf_level)) # nolint: object_usage_linter
  }
}

# Internal estimation functions ----

#' Ungrouped total estimation (Phase 4 logic)
#'
#' @keywords internal
#' @noRd
estimate_effort_total <- function(design, conf_level) {
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
    conf_level = conf_level,
    by_vars = NULL
  )
}

#' Grouped total estimation using svyby (Phase 5 logic)
#'
#' @keywords internal
#' @noRd
estimate_effort_grouped <- function(design, by_vars, conf_level) {
  counts_data <- design$counts

  # Tier 2 validation for groups
  warn_tier2_group_issues(design, by_vars) # nolint: object_usage_linter

  # Identify the count variable
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

  # Build formulas for svyby
  count_formula <- stats::reformulate(count_var)
  by_formula <- stats::reformulate(by_vars)

  # Call survey::svyby (suppress expected survey package warnings)
  svy_result <- suppressWarnings(survey::svyby(
    formula = count_formula,
    by = by_formula,
    design = design$survey,
    FUN = survey::svytotal,
    vartype = c("se", "ci"),
    ci.level = conf_level,
    keep.names = FALSE
  ))

  # Extract estimate columns from svyby result
  # When keep.names = FALSE, svyby returns: count_var, "se", "ci_l", "ci_u"
  estimate <- svy_result[[count_var]]
  se <- svy_result[["se"]]
  ci_lower <- svy_result[["ci_l"]]
  ci_upper <- svy_result[["ci_u"]]

  # Calculate per-group sample sizes
  # Use aggregate to count rows per group combination
  group_data_for_n <- counts_data[by_vars]
  group_data_for_n$.count <- 1
  n_by_group <- stats::aggregate(
    .count ~ .,
    data = group_data_for_n,
    FUN = sum
  )
  names(n_by_group)[names(n_by_group) == ".count"] <- "n"

  # Build result tibble with group columns first, then estimates
  # Start with group columns from svyby result (preserves factor levels)
  estimates_df <- svy_result[by_vars]
  estimates_df$estimate <- estimate
  estimates_df$se <- se
  estimates_df$ci_lower <- ci_lower
  estimates_df$ci_upper <- ci_upper

  # Join sample sizes
  estimates_df <- merge(estimates_df, n_by_group, by = by_vars, all.x = TRUE, sort = FALSE)

  # Convert to tibble and reorder columns (group cols, then estimate cols, then n)
  estimates_df <- tibble::as_tibble(estimates_df)
  col_order <- c(by_vars, "estimate", "se", "ci_lower", "ci_upper", "n")
  estimates_df <- estimates_df[col_order]

  # Return creel_estimates object
  new_creel_estimates( # nolint: object_usage_linter
    estimates = estimates_df,
    method = "total",
    variance_method = "taylor",
    design = design,
    conf_level = conf_level,
    by_vars = by_vars
  )
}
