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

  # Convert method to human-readable form
  method_display <- switch(x$method, # nolint: object_usage_linter
    total = "Total",
    "ratio-of-means-cpue" = "Ratio-of-Means CPUE",
    "ratio-of-means-hpue" = "Ratio-of-Means HPUE",
    "product-total-catch" = "Total Catch (Effort \u00d7 CPUE)",
    "product-total-harvest" = "Total Harvest (Effort \u00d7 HPUE)",
    x$method
  )

  # Build formatted output using cli
  output <- character()

  output <- c(output, cli::cli_format_method({
    cli::cli_h1("Creel Survey Estimates")
    cli::cli_text("Method: {method_display}")
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
#' @param variance Character string specifying variance estimation method.
#'   Options: \code{"taylor"} (default, Taylor linearization),
#'   \code{"bootstrap"} (bootstrap resampling with 500 replicates), or
#'   \code{"jackknife"} (jackknife resampling, automatic JKn/JK1 selection).
#' @param conf_level Numeric confidence level for confidence intervals (default:
#'   0.95 for 95% confidence intervals). Must be between 0 and 1.
#'
#' @return A creel_estimates S3 object (list) with components: estimates
#'   (tibble with estimate, se, ci_lower, ci_upper, n columns, plus grouping
#'   columns if \code{by} is specified), method (character: "total"),
#'   variance_method (character: reflects the variance parameter value used),
#'   design (reference to source creel_design), conf_level (numeric), and
#'   by_vars (character vector of grouping variable names or NULL).
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
#' \strong{Variance estimation methods:}
#' \itemize{
#'   \item \code{"taylor"} (default): Taylor linearization, computationally
#'     efficient and appropriate for most smooth statistics. This is the
#'     recommended default.
#'   \item \code{"bootstrap"}: Bootstrap resampling with 500 replicates.
#'     Appropriate for non-smooth statistics or verifying Taylor assumptions.
#'     More computationally intensive than Taylor.
#'   \item \code{"jackknife"}: Jackknife resampling (automatic JKn or JK1
#'     selection based on design). Alternative resampling method, deterministic
#'     unlike bootstrap.
#' }
#'
#' @examples
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
#' # Note: Multiple grouping variables are supported if present in the data
#' # For example: by = c(day_type, location)
#'
#' # Custom confidence level
#' result_90 <- estimate_effort(design_with_counts, conf_level = 0.90)
#'
#' # Bootstrap variance estimation
#' result_boot <- estimate_effort(design_with_counts, variance = "bootstrap")
#' print(result_boot)
#'
#' # Jackknife variance estimation
#' result_jk <- estimate_effort(design_with_counts, variance = "jackknife")
#' print(result_jk)
#'
#' # Grouped estimation with bootstrap variance
#' result_grouped_boot <- estimate_effort(design_with_counts, by = day_type, variance = "bootstrap")
#' @export
estimate_effort <- function(design, by = NULL, variance = "taylor", conf_level = 0.95) {
  # Capture by parameter BEFORE validation
  by_quo <- rlang::enquo(by)

  # Validate variance parameter
  valid_methods <- c("taylor", "bootstrap", "jackknife")
  if (!variance %in% valid_methods) {
    cli::cli_abort(c(
      "Invalid variance method: {.val {variance}}",
      "x" = "Must be one of: {.val {valid_methods}}",
      "i" = "Default is {.val taylor} (Taylor linearization)"
    ))
  }

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
    return(estimate_effort_total(design, variance, conf_level)) # nolint: object_usage_linter
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

    return(estimate_effort_grouped(design, by_vars, variance, conf_level)) # nolint: object_usage_linter
  }
}

#' Estimate CPUE (Catch Per Unit Effort) from a creel survey design
#'
#' Computes CPUE estimates with standard errors and confidence intervals
#' from a creel survey design with attached interview data. Uses ratio-of-means
#' estimation via survey::svyratio() to properly account for ratio variance.
#'
#' @param design A creel_design object with interviews attached via
#'   \code{\link{add_interviews}}. The design must have an interview survey object
#'   constructed with catch and effort columns.
#' @param by Optional tidy selector for grouping variables. Accepts bare column
#'   names (e.g., \code{by = day_type}), multiple columns (e.g.,
#'   \code{by = c(day_type, location)}), or tidyselect helpers (e.g.,
#'   \code{by = starts_with("day")}). When NULL (default), computes a single
#'   CPUE estimate across all interviews.
#' @param variance Character string specifying variance estimation method.
#'   Options: \code{"taylor"} (default, Taylor linearization),
#'   \code{"bootstrap"} (bootstrap resampling with 500 replicates), or
#'   \code{"jackknife"} (jackknife resampling, automatic JKn/JK1 selection).
#' @param conf_level Numeric confidence level for confidence intervals (default:
#'   0.95 for 95% confidence intervals). Must be between 0 and 1.
#'
#' @return A creel_estimates S3 object (list) with components: estimates
#'   (tibble with estimate, se, ci_lower, ci_upper, n columns, plus grouping
#'   columns if \code{by} is specified), method (character: "ratio-of-means-cpue"),
#'   variance_method (character: reflects the variance parameter value used),
#'   design (reference to source creel_design), conf_level (numeric), and
#'   by_vars (character vector of grouping variable names or NULL).
#'
#' @details
#' CPUE is estimated as the ratio of total catch to total effort (ratio-of-means
#' estimator). This is the appropriate estimator for average catch rates when
#' trip lengths (effort) vary. The function uses survey::svyratio() internally,
#' which correctly accounts for the correlation between catch and effort in
#' variance estimation.
#'
#' The function performs sample size validation before estimation: errors if
#' n < 10 (ungrouped or any group), warns if 10 <= n < 30. This follows best
#' practices for ratio estimation stability.
#'
#' When grouped estimation is used (\code{by} is not NULL), survey::svyby()
#' with svyratio correctly accounts for domain estimation variance.
#'
#' \strong{Variance estimation methods:}
#' \itemize{
#'   \item \code{"taylor"} (default): Taylor linearization, computationally
#'     efficient and appropriate for smooth statistics like ratios.
#'   \item \code{"bootstrap"}: Bootstrap resampling with 500 replicates.
#'     Appropriate for verifying Taylor assumptions.
#'   \item \code{"jackknife"}: Jackknife resampling (automatic JKn or JK1
#'     selection based on design). Alternative resampling method.
#' }
#'
#' @examples
#' # Basic ungrouped CPUE
#' calendar <- data.frame(
#'   date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
#'   day_type = c("weekday", "weekday", "weekend", "weekend")
#' )
#' design <- creel_design(calendar, date = date, strata = day_type)
#'
#' interviews <- data.frame(
#'   date = as.Date(rep(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04"), each = 10)),
#'   catch_total = rpois(40, lambda = 3),
#'   hours_fished = runif(40, min = 1, max = 6),
#'   trip_status = rep(c("complete", "incomplete"), each = 20),
#'   trip_duration = runif(40, min = 1, max = 6)
#' )
#'
#' design_with_interviews <- add_interviews(design, interviews,
#'   catch = catch_total,
#'   effort = hours_fished,
#'   trip_status = trip_status,
#'   trip_duration = trip_duration
#' )
#' result <- estimate_cpue(design_with_interviews)
#' print(result)
#'
#' # Grouped by day_type
#' result_grouped <- estimate_cpue(design_with_interviews, by = day_type)
#' print(result_grouped)
#'
#' # Custom confidence level
#' result_90 <- estimate_cpue(design_with_interviews, conf_level = 0.90)
#'
#' # Bootstrap variance estimation
#' result_boot <- estimate_cpue(design_with_interviews, variance = "bootstrap")
#' @export
estimate_cpue <- function(design, by = NULL, variance = "taylor", conf_level = 0.95) {
  # Capture by parameter BEFORE validation
  by_quo <- rlang::enquo(by)

  # Validate variance parameter
  valid_methods <- c("taylor", "bootstrap", "jackknife")
  if (!variance %in% valid_methods) {
    cli::cli_abort(c(
      "Invalid variance method: {.val {variance}}",
      "x" = "Must be one of: {.val {valid_methods}}",
      "i" = "Default is {.val taylor} (Taylor linearization)"
    ))
  }

  # Validate input is creel_design
  if (!inherits(design, "creel_design")) {
    cli::cli_abort(c(
      "{.arg design} must be a {.cls creel_design} object.",
      "x" = "{.arg design} is {.cls {class(design)[1]}}.",
      "i" = "Create a design with {.fn creel_design}."
    ))
  }

  # Validate design$interview_survey exists
  if (is.null(design$interview_survey)) {
    cli::cli_abort(c(
      "No interview survey design available.",
      "x" = "Call {.fn add_interviews} before estimating CPUE.",
      "i" = "Example: {.code design <- add_interviews(design, interviews, catch = catch_total, effort = hours_fished)}"
    ))
  }

  # Validate design$catch_col and design$effort_col exist
  if (is.null(design$catch_col) || is.null(design$effort_col)) {
    cli::cli_abort(c(
      "No catch or effort column available.",
      "x" = "Design must have catch_col and effort_col set.",
      "i" = "Call {.fn add_interviews} with catch and effort parameters."
    ))
  }

  # Route to grouped or ungrouped estimation
  if (rlang::quo_is_null(by_quo)) {
    # Ungrouped estimation
    # Validate sample size
    validate_ratio_sample_size(design, NULL, type = "cpue") # nolint: object_usage_linter
    return(estimate_cpue_total(design, variance, conf_level)) # nolint: object_usage_linter
  } else {
    # Grouped estimation
    # Resolve by parameter to column names
    by_cols <- tidyselect::eval_select(
      by_quo,
      data = design$interviews,
      allow_rename = FALSE,
      allow_empty = FALSE,
      error_call = rlang::caller_env()
    )
    by_vars <- names(by_cols)

    # Validate sample size per group
    validate_ratio_sample_size(design, by_vars, type = "cpue") # nolint: object_usage_linter
    return(estimate_cpue_grouped(design, by_vars, variance, conf_level)) # nolint: object_usage_linter
  }
}

#' Estimate harvest (HPUE: Harvest Per Unit Effort) from a creel survey design
#'
#' Computes HPUE estimates with standard errors and confidence intervals
#' from a creel survey design with attached interview data. Uses ratio-of-means
#' estimation via survey::svyratio() to properly account for ratio variance.
#' HPUE measures the rate of kept fish (harvest) per unit effort, distinguished
#' from total catch rate (CPUE which includes both kept and released fish).
#'
#' @param design A creel_design object with interviews attached via
#'   \code{\link{add_interviews}}. The design must have an interview survey object
#'   constructed with harvest, catch, and effort columns.
#' @param by Optional tidy selector for grouping variables. Accepts bare column
#'   names (e.g., \code{by = day_type}), multiple columns (e.g.,
#'   \code{by = c(day_type, location)}), or tidyselect helpers (e.g.,
#'   \code{by = starts_with("day")}). When NULL (default), computes a single
#'   HPUE estimate across all interviews.
#' @param variance Character string specifying variance estimation method.
#'   Options: \code{"taylor"} (default, Taylor linearization),
#'   \code{"bootstrap"} (bootstrap resampling with 500 replicates), or
#'   \code{"jackknife"} (jackknife resampling, automatic JKn/JK1 selection).
#' @param conf_level Numeric confidence level for confidence intervals (default:
#'   0.95 for 95% confidence intervals). Must be between 0 and 1.
#'
#' @return A creel_estimates S3 object (list) with components: estimates
#'   (tibble with estimate, se, ci_lower, ci_upper, n columns, plus grouping
#'   columns if \code{by} is specified), method (character: "ratio-of-means-hpue"),
#'   variance_method (character: reflects the variance parameter value used),
#'   design (reference to source creel_design), conf_level (numeric), and
#'   by_vars (character vector of grouping variable names or NULL).
#'
#' @details
#' HPUE is estimated as the ratio of total harvest (kept fish) to total effort
#' (ratio-of-means estimator). This is the appropriate estimator for average
#' harvest rates when trip lengths (effort) vary. The function uses
#' survey::svyratio() internally, which correctly accounts for the correlation
#' between harvest and effort in variance estimation.
#'
#' HPUE will always be less than or equal to CPUE for the same data, since
#' harvest (kept fish) is a subset of total catch.
#'
#' The function performs sample size validation before estimation: errors if
#' n < 10 (ungrouped or any group), warns if 10 <= n < 30. This follows best
#' practices for ratio estimation stability.
#'
#' When grouped estimation is used (\code{by} is not NULL), survey::svyby()
#' with svyratio correctly accounts for domain estimation variance.
#'
#' \strong{Variance estimation methods:}
#' \itemize{
#'   \item \code{"taylor"} (default): Taylor linearization, computationally
#'     efficient and appropriate for smooth statistics like ratios.
#'   \item \code{"bootstrap"}: Bootstrap resampling with 500 replicates.
#'     Appropriate for verifying Taylor assumptions.
#'   \item \code{"jackknife"}: Jackknife resampling (automatic JKn or JK1
#'     selection based on design). Alternative resampling method.
#' }
#'
#' @seealso \code{\link{estimate_cpue}} for total catch rate estimation
#'
#' @examples
#' # Basic ungrouped HPUE
#' calendar <- data.frame(
#'   date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
#'   day_type = c("weekday", "weekday", "weekend", "weekend")
#' )
#' design <- creel_design(calendar, date = date, strata = day_type)
#'
#' set.seed(123)
#' interviews <- data.frame(
#'   date = as.Date(rep(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04"), each = 10)),
#'   catch_total = rpois(40, lambda = 3),
#'   hours_fished = runif(40, min = 1, max = 6),
#'   trip_status = rep(c("complete", "incomplete"), each = 20),
#'   trip_duration = runif(40, min = 1, max = 6)
#' )
#' # Harvest is subset of catch (kept fish)
#' interviews$catch_kept <- pmax(0, interviews$catch_total - rbinom(40, size = 2, prob = 0.3))
#'
#' design_with_interviews <- add_interviews(design, interviews,
#'   catch = catch_total,
#'   harvest = catch_kept,
#'   effort = hours_fished,
#'   trip_status = trip_status,
#'   trip_duration = trip_duration
#' )
#' result <- estimate_harvest(design_with_interviews)
#' print(result)
#'
#' # Grouped by day_type
#' result_grouped <- estimate_harvest(design_with_interviews, by = day_type)
#' print(result_grouped)
#'
#' # Custom confidence level
#' result_90 <- estimate_harvest(design_with_interviews, conf_level = 0.90)
#'
#' # Bootstrap variance estimation
#' result_boot <- estimate_harvest(design_with_interviews, variance = "bootstrap")
#' @export
estimate_harvest <- function(design, by = NULL, variance = "taylor", conf_level = 0.95) {
  # Capture by parameter BEFORE validation
  by_quo <- rlang::enquo(by)

  # Validate variance parameter
  valid_methods <- c("taylor", "bootstrap", "jackknife")
  if (!variance %in% valid_methods) {
    cli::cli_abort(c(
      "Invalid variance method: {.val {variance}}",
      "x" = "Must be one of: {.val {valid_methods}}",
      "i" = "Default is {.val taylor} (Taylor linearization)"
    ))
  }

  # Validate input is creel_design
  if (!inherits(design, "creel_design")) {
    cli::cli_abort(c(
      "{.arg design} must be a {.cls creel_design} object.",
      "x" = "{.arg design} is {.cls {class(design)[1]}}.",
      "i" = "Create a design with {.fn creel_design}."
    ))
  }

  # Validate design$interview_survey exists
  if (is.null(design$interview_survey)) {
    cli::cli_abort(c(
      "No interview survey design available.",
      "x" = "Call {.fn add_interviews} before estimating harvest.",
      "i" = paste(
        "Example: {.code design <- add_interviews(design, interviews,",
        "catch = catch_total, harvest = catch_kept, effort = hours_fished)}"
      )
    ))
  }

  # Validate design$harvest_col exists
  if (is.null(design$harvest_col)) {
    cli::cli_abort(c(
      "No harvest column available.",
      "x" = "Design must have harvest_col set.",
      "i" = "Call {.fn add_interviews} with the harvest parameter.",
      "i" = paste(
        "Example: {.code design <- add_interviews(design, interviews,",
        "catch = catch_total, harvest = catch_kept, effort = hours_fished)}"
      )
    ))
  }

  # Validate design$effort_col exists
  if (is.null(design$effort_col)) {
    cli::cli_abort(c(
      "No effort column available.",
      "x" = "Design must have effort_col set.",
      "i" = "Call {.fn add_interviews} with effort parameter."
    ))
  }

  # Route to grouped or ungrouped estimation
  if (rlang::quo_is_null(by_quo)) {
    # Ungrouped estimation
    # Validate sample size
    validate_ratio_sample_size(design, NULL, type = "harvest") # nolint: object_usage_linter
    return(estimate_harvest_total(design, variance, conf_level)) # nolint: object_usage_linter
  } else {
    # Grouped estimation
    # Resolve by parameter to column names
    by_cols <- tidyselect::eval_select(
      by_quo,
      data = design$interviews,
      allow_rename = FALSE,
      allow_empty = FALSE,
      error_call = rlang::caller_env()
    )
    by_vars <- names(by_cols)

    # Validate sample size per group
    validate_ratio_sample_size(design, by_vars, type = "harvest") # nolint: object_usage_linter
    return(estimate_harvest_grouped(design, by_vars, variance, conf_level)) # nolint: object_usage_linter
  }
}

# Internal estimation functions ----

#' Ungrouped total estimation (Phase 4 logic)
#'
#' @keywords internal
#' @noRd
estimate_effort_total <- function(design, variance_method, conf_level) {
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

  # Get appropriate survey design for variance method
  svy_design <- get_variance_design(design$survey, variance_method) # nolint: object_usage_linter

  # Call survey::svytotal (suppress expected survey package warnings)
  svy_result <- suppressWarnings(survey::svytotal(count_formula, svy_design))

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
    variance_method = variance_method,
    design = design,
    conf_level = conf_level,
    by_vars = NULL
  )
}

#' Grouped total estimation using svyby (Phase 5 logic)
#'
#' @keywords internal
#' @noRd
estimate_effort_grouped <- function(design, by_vars, variance_method, conf_level) {
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

  # Get appropriate survey design for variance method
  svy_design <- get_variance_design(design$survey, variance_method) # nolint: object_usage_linter

  # Call survey::svyby (suppress expected survey package warnings)
  svy_result <- suppressWarnings(survey::svyby(
    formula = count_formula,
    by = by_formula,
    design = svy_design,
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
    variance_method = variance_method,
    design = design,
    conf_level = conf_level,
    by_vars = by_vars
  )
}

#' Ungrouped CPUE estimation (ratio-of-means)
#'
#' @keywords internal
#' @noRd
estimate_cpue_total <- function(design, variance_method, conf_level) {
  interviews_data <- design$interviews
  catch_col <- design$catch_col
  effort_col <- design$effort_col

  # Filter out zero-effort interviews with warning
  zero_effort <- !is.na(interviews_data[[effort_col]]) & interviews_data[[effort_col]] == 0
  if (any(zero_effort)) {
    n_zero <- sum(zero_effort) # nolint: object_usage_linter
    cli::cli_warn(c(
      "{n_zero} interview{?s} with zero effort excluded from CPUE estimation.",
      "i" = "CPUE requires effort > 0 (catch/effort is undefined for effort = 0)."
    ))
    interviews_data <- interviews_data[!zero_effort, , drop = FALSE]
  }

  # Build temporary survey design from filtered data if filtering occurred
  if (any(zero_effort)) {
    # Get strata column(s) from original design
    strata_cols <- design$strata_cols
    if (!is.null(strata_cols) && length(strata_cols) > 0) {
      strata_formula <- stats::reformulate(strata_cols)
      temp_survey <- survey::svydesign(
        ids = ~1,
        strata = strata_formula,
        data = interviews_data
      )
    } else {
      temp_survey <- survey::svydesign(
        ids = ~1,
        data = interviews_data
      )
    }
    # Get variance design from temporary survey
    svy_design <- get_variance_design(temp_survey, variance_method) # nolint: object_usage_linter
  } else {
    # No filtering needed - use original design
    svy_design <- get_variance_design(design$interview_survey, variance_method) # nolint: object_usage_linter
  }

  # Create formulas for ratio estimation
  catch_formula <- stats::reformulate(catch_col)
  effort_formula <- stats::reformulate(effort_col)

  # Call survey::svyratio (suppress expected survey package warnings)
  svy_result <- suppressWarnings(
    survey::svyratio(catch_formula, effort_formula, svy_design)
  )

  # Extract estimates
  estimate <- as.numeric(coef(svy_result))
  se <- as.numeric(survey::SE(svy_result))
  ci <- confint(svy_result, level = conf_level)
  ci_lower <- ci[1, 1]
  ci_upper <- ci[1, 2]
  n <- nrow(interviews_data)

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
    method = "ratio-of-means-cpue",
    variance_method = variance_method,
    design = design,
    conf_level = conf_level,
    by_vars = NULL
  )
}

#' Grouped CPUE estimation using svyby + svyratio
#'
#' @keywords internal
#' @noRd
estimate_cpue_grouped <- function(design, by_vars, variance_method, conf_level) {
  interviews_data <- design$interviews
  catch_col <- design$catch_col
  effort_col <- design$effort_col

  # Filter out zero-effort interviews with warning
  zero_effort <- !is.na(interviews_data[[effort_col]]) & interviews_data[[effort_col]] == 0
  if (any(zero_effort)) {
    n_zero <- sum(zero_effort) # nolint: object_usage_linter
    cli::cli_warn(c(
      "{n_zero} interview{?s} with zero effort excluded from CPUE estimation.",
      "i" = "CPUE requires effort > 0 (catch/effort is undefined for effort = 0)."
    ))
    interviews_data <- interviews_data[!zero_effort, , drop = FALSE]
  }

  # Build temporary survey design from filtered data if filtering occurred
  if (any(zero_effort)) {
    # Get strata column(s) from original design
    strata_cols <- design$strata_cols
    if (!is.null(strata_cols) && length(strata_cols) > 0) {
      strata_formula <- stats::reformulate(strata_cols)
      temp_survey <- survey::svydesign(
        ids = ~1,
        strata = strata_formula,
        data = interviews_data
      )
    } else {
      temp_survey <- survey::svydesign(
        ids = ~1,
        data = interviews_data
      )
    }
    # Get variance design from temporary survey
    svy_design <- get_variance_design(temp_survey, variance_method) # nolint: object_usage_linter
  } else {
    # No filtering needed - use original design
    svy_design <- get_variance_design(design$interview_survey, variance_method) # nolint: object_usage_linter
  }

  # Build formulas for svyby
  catch_formula <- stats::reformulate(catch_col)
  effort_formula <- stats::reformulate(effort_col)
  by_formula <- stats::reformulate(by_vars)

  # Call survey::svyby with svyratio (suppress expected survey package warnings)
  svy_result <- suppressWarnings(survey::svyby(
    formula = catch_formula,
    by = by_formula,
    design = svy_design,
    FUN = survey::svyratio,
    denominator = effort_formula,
    vartype = c("se", "ci"),
    ci.level = conf_level,
    keep.names = FALSE
  ))

  # Extract estimate columns from svyby result
  # svyratio creates column named "catch_col/effort_col"
  ratio_col <- paste0(catch_col, "/", effort_col)
  se_col <- paste0("se.", ratio_col)
  estimate <- svy_result[[ratio_col]]
  se <- svy_result[[se_col]]
  ci_lower <- svy_result[["ci_l"]]
  ci_upper <- svy_result[["ci_u"]]

  # Calculate per-group sample sizes
  # Use aggregate to count rows per group combination
  group_data_for_n <- interviews_data[by_vars]
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
    method = "ratio-of-means-cpue",
    variance_method = variance_method,
    design = design,
    conf_level = conf_level,
    by_vars = by_vars
  )
}

#' Ungrouped harvest (HPUE) estimation using ratio-of-means
#'
#' @keywords internal
#' @noRd
estimate_harvest_total <- function(design, variance_method, conf_level) {
  interviews_data <- design$interviews
  harvest_col <- design$harvest_col
  effort_col <- design$effort_col

  # Filter out zero-effort interviews with warning
  zero_effort <- !is.na(interviews_data[[effort_col]]) & interviews_data[[effort_col]] == 0
  if (any(zero_effort)) {
    n_zero <- sum(zero_effort) # nolint: object_usage_linter
    cli::cli_warn(c(
      "{n_zero} interview{?s} with zero effort excluded from harvest estimation.",
      "i" = "HPUE requires effort > 0 (harvest/effort is undefined for effort = 0)."
    ))
    interviews_data <- interviews_data[!zero_effort, , drop = FALSE]
  }

  # Filter out NA harvest interviews with warning
  na_harvest <- is.na(interviews_data[[harvest_col]])
  if (any(na_harvest)) {
    n_na <- sum(na_harvest) # nolint: object_usage_linter
    cli::cli_warn(c(
      "{n_na} interview{?s} with missing harvest excluded from harvest estimation.",
      "i" = "Interviews must have non-NA harvest values for HPUE estimation."
    ))
    interviews_data <- interviews_data[!na_harvest, , drop = FALSE]
  }

  # Check if any data remains after filtering
  if (nrow(interviews_data) == 0) {
    cli::cli_abort(c(
      "No valid interviews remaining after filtering.",
      "x" = "All interviews were excluded (zero effort or missing harvest).",
      "i" = "Harvest estimation requires at least 10 interviews with non-zero effort and non-NA harvest."
    ))
  }

  # Build temporary survey design from filtered data if filtering occurred
  needs_rebuild <- any(zero_effort) || any(na_harvest)
  if (needs_rebuild) {
    strata_cols <- design$strata_cols
    if (!is.null(strata_cols) && length(strata_cols) > 0) {
      strata_formula <- stats::reformulate(strata_cols)
      temp_survey <- survey::svydesign(
        ids = ~1,
        strata = strata_formula,
        data = interviews_data
      )
    } else {
      temp_survey <- survey::svydesign(
        ids = ~1,
        data = interviews_data
      )
    }
    svy_design <- get_variance_design(temp_survey, variance_method) # nolint: object_usage_linter
  } else {
    svy_design <- get_variance_design(design$interview_survey, variance_method) # nolint: object_usage_linter
  }

  # Create formulas for ratio estimation
  harvest_formula <- stats::reformulate(harvest_col)
  effort_formula <- stats::reformulate(effort_col)

  # Call survey::svyratio (suppress expected survey package warnings)
  svy_result <- suppressWarnings(
    survey::svyratio(harvest_formula, effort_formula, svy_design)
  )

  # Extract estimates
  estimate <- as.numeric(coef(svy_result))
  se <- as.numeric(survey::SE(svy_result))
  ci <- confint(svy_result, level = conf_level)
  ci_lower <- ci[1, 1]
  ci_upper <- ci[1, 2]
  n <- nrow(interviews_data)

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
    method = "ratio-of-means-hpue",
    variance_method = variance_method,
    design = design,
    conf_level = conf_level,
    by_vars = NULL
  )
}

#' Grouped harvest (HPUE) estimation using svyby + svyratio
#'
#' @keywords internal
#' @noRd
estimate_harvest_grouped <- function(design, by_vars, variance_method, conf_level) {
  interviews_data <- design$interviews
  harvest_col <- design$harvest_col
  effort_col <- design$effort_col

  # Filter out zero-effort interviews with warning
  zero_effort <- !is.na(interviews_data[[effort_col]]) & interviews_data[[effort_col]] == 0
  if (any(zero_effort)) {
    n_zero <- sum(zero_effort) # nolint: object_usage_linter
    cli::cli_warn(c(
      "{n_zero} interview{?s} with zero effort excluded from harvest estimation.",
      "i" = "HPUE requires effort > 0 (harvest/effort is undefined for effort = 0)."
    ))
    interviews_data <- interviews_data[!zero_effort, , drop = FALSE]
  }

  # Filter out NA harvest interviews with warning
  na_harvest <- is.na(interviews_data[[harvest_col]])
  if (any(na_harvest)) {
    n_na <- sum(na_harvest) # nolint: object_usage_linter
    cli::cli_warn(c(
      "{n_na} interview{?s} with missing harvest excluded from harvest estimation.",
      "i" = "Interviews must have non-NA harvest values for HPUE estimation."
    ))
    interviews_data <- interviews_data[!na_harvest, , drop = FALSE]
  }

  # Check if any data remains after filtering
  if (nrow(interviews_data) == 0) {
    cli::cli_abort(c(
      "No valid interviews remaining after filtering.",
      "x" = "All interviews were excluded (zero effort or missing harvest).",
      "i" = "Harvest estimation requires at least 10 interviews with non-zero effort and non-NA harvest."
    ))
  }

  # Build temporary survey design from filtered data if filtering occurred
  needs_rebuild <- any(zero_effort) || any(na_harvest)
  if (needs_rebuild) {
    strata_cols <- design$strata_cols
    if (!is.null(strata_cols) && length(strata_cols) > 0) {
      strata_formula <- stats::reformulate(strata_cols)
      temp_survey <- survey::svydesign(
        ids = ~1,
        strata = strata_formula,
        data = interviews_data
      )
    } else {
      temp_survey <- survey::svydesign(
        ids = ~1,
        data = interviews_data
      )
    }
    svy_design <- get_variance_design(temp_survey, variance_method) # nolint: object_usage_linter
  } else {
    svy_design <- get_variance_design(design$interview_survey, variance_method) # nolint: object_usage_linter
  }

  # Build formulas for svyby
  harvest_formula <- stats::reformulate(harvest_col)
  effort_formula <- stats::reformulate(effort_col)
  by_formula <- stats::reformulate(by_vars)

  # Call survey::svyby with svyratio (suppress expected survey package warnings)
  svy_result <- suppressWarnings(survey::svyby(
    formula = harvest_formula,
    by = by_formula,
    design = svy_design,
    FUN = survey::svyratio,
    denominator = effort_formula,
    vartype = c("se", "ci"),
    ci.level = conf_level,
    keep.names = FALSE
  ))

  # Extract estimate columns from svyby result
  # svyratio creates column named "harvest_col/effort_col"
  ratio_col <- paste0(harvest_col, "/", effort_col)
  se_col <- paste0("se.", ratio_col)
  estimate <- svy_result[[ratio_col]]
  se <- svy_result[[se_col]]
  ci_lower <- svy_result[["ci_l"]]
  ci_upper <- svy_result[["ci_u"]]

  # Calculate per-group sample sizes
  # Use aggregate to count rows per group combination
  group_data_for_n <- interviews_data[by_vars]
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
    method = "ratio-of-means-hpue",
    variance_method = variance_method,
    design = design,
    conf_level = conf_level,
    by_vars = by_vars
  )
}
