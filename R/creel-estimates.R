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

#' Create a creel_estimates_mor object for mean-of-ratios diagnostic estimates
#'
#' Internal constructor for MOR (mean-of-ratios) diagnostic estimates from
#' incomplete trips. Inherits from creel_estimates but adds mor-specific class
#' for custom printing and Phase 19 validation framework detection.
#'
#' @inheritParams new_creel_estimates
#' @param n_incomplete Number of incomplete trips used in estimation
#' @param n_total Total number of interviews in dataset
#' @param mor_truncate_at Truncation threshold used (hours)
#' @param mor_n_truncated Number of trips excluded by truncation
#'
#' @return List of class c("creel_estimates_mor", "creel_estimates")
#'
#' @keywords internal
#' @noRd
new_creel_estimates_mor <- function(estimates,
                                    method = "mean-of-ratios-cpue",
                                    variance_method = "taylor",
                                    design = NULL,
                                    conf_level = 0.95,
                                    by_vars = NULL,
                                    n_incomplete = NULL,
                                    n_total = NULL,
                                    mor_truncate_at = NULL,
                                    mor_n_truncated = NULL) {
  # Call parent constructor
  result <- new_creel_estimates(
    estimates = estimates,
    method = method,
    variance_method = variance_method,
    design = design,
    conf_level = conf_level,
    by_vars = by_vars
  )

  # Add MOR-specific metadata
  result$n_incomplete <- n_incomplete
  result$n_total <- n_total
  result$mor_truncate_at <- mor_truncate_at
  result$mor_n_truncated <- mor_n_truncated

  # Add mor class BEFORE creel_estimates (S3 method dispatch priority)
  class(result) <- c("creel_estimates_mor", "creel_estimates")

  result
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
    "mean-of-ratios-cpue" = "Mean-of-Ratios CPUE",
    "ratio-of-means-hpue" = "Ratio-of-Means HPUE",
    "ratio-of-means-cpue-per-angler" = "Ratio-of-Means CPUE (per angler)",
    "mean-of-ratios-cpue-per-angler" = "Mean-of-Ratios CPUE (per angler)",
    "ratio-of-means-hpue-per-angler" = "Ratio-of-Means HPUE (per angler)",
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

    # Show normalization note if effort was normalized by party size
    if (endsWith(x$method, "-per-angler")) {
      cli::cli_text("Note: Effort normalized by party size (n_anglers)")
    }

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
#' @param verbose Logical. If TRUE, prints an informational message identifying
#'   which estimator path was used. Default FALSE for transparent dispatch.
#'
#' @return A creel_estimates S3 object (list) with components: estimates
#'   (tibble with estimate, se, ci_lower, ci_upper, n columns, plus grouping
#'   columns if \code{by} is specified), method (character: "total"),
#'   variance_method (character: reflects the variance parameter value used),
#'   design (reference to source creel_design), conf_level (numeric), and
#'   by_vars (character vector of grouping variable names or NULL). For
#'   bus-route designs, a "site_contributions" attribute is also present
#'   containing per-site e_i, pi_i, and e_i_over_pi_i columns.
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
#'
#' # Verbose dispatch message (shows which estimator was used for bus-route designs)
#' result_verbose <- estimate_effort(design_with_counts, verbose = TRUE)
#' @export
estimate_effort <- function(design, by = NULL, variance = "taylor", conf_level = 0.95, verbose = FALSE) {
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

  # Validate design$survey exists (skip for bus-route: uses interviews not counts)
  if (!identical(design$design_type, "bus_route") && is.null(design$survey)) {
    cli::cli_abort(c(
      "No survey design available.",
      "x" = "Call {.fn add_counts} before estimating effort.",
      "i" = "Example: {.code design <- add_counts(design, counts)}"
    ))
  }

  # Bus-route dispatch (after survey NULL check, before standard tier-2 validation)
  if (!is.null(design$design_type) && design$design_type == "bus_route") {
    if (verbose) {
      cli::cli_inform(c(
        "i" = "Using bus-route estimator (Jones & Pollock 2012, Eq. 19.4)"
      ))
    }

    # Validate interview data exists
    if (is.null(design$interviews)) {
      cli::cli_abort(c(
        "Bus-route effort estimation requires interview data.",
        "x" = "No interview data found in design.",
        "i" = paste0(
          "Call {.fn add_interviews} with {.arg n_counted} and {.arg n_interviewed} parameters."
        )
      ))
    }

    # Resolve by_vars (same tidyselect pattern as standard path but against interviews)
    if (rlang::quo_is_null(by_quo)) {
      by_vars_br <- NULL
    } else {
      by_cols_br <- tidyselect::eval_select(
        by_quo,
        data = design$interviews,
        allow_rename = FALSE,
        allow_empty = FALSE,
        error_call = rlang::caller_env()
      )
      by_vars_br <- names(by_cols_br)
    }

    return(estimate_effort_br(design, by_vars_br, variance, conf_level, verbose)) # nolint: object_usage_linter
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
#' from a creel survey design with attached interview data. Supports both
#' ratio-of-means (for complete trips) and mean-of-ratios (for incomplete trips)
#' estimation methods.
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
#' @param estimator Character string specifying estimation method. Options:
#'   \code{"ratio-of-means"} (default, for complete trips) or \code{"mor"}
#'   (mean-of-ratios, for incomplete trips). MOR requires trip_status field
#'   and errors if no incomplete trips are available. See Details.
#' @param use_trips Character string specifying which trip type to use when
#'   trip_status field is provided. Options: \code{"complete"} (default when
#'   NULL) uses only complete trips with ratio-of-means estimator,
#'   \code{"incomplete"} uses only incomplete trips with mean-of-ratios
#'   estimator, or \code{"diagnostic"} estimates CPUE using both trip types and
#'   returns a comparison table. Following Colorado C-SAP and Pollock et al.,
#'   complete trips are scientifically preferred (no length-of-stay bias).
#'   Incomplete trip estimation is diagnostic/research mode requiring
#'   validation. Diagnostic mode requires both complete and incomplete trips to
#'   be present. Default is NULL which defaults to \code{"complete"}.
#'   Parameter is ignored when trip_status field is not provided (perfect
#'   backward compatibility). See Details.
#' @param truncate_at Numeric minimum trip duration (hours) for MOR estimation.
#'   Default is 0.5 hours (30 minutes) per Hoenig et al. (1997) to prevent
#'   unstable variance from very short trips. Trips with duration < truncate_at
#'   are excluded before MOR estimation. Set to NULL to disable truncation
#'   (research mode only). Ignored for ratio-of-means estimator.
#'
#' @return A creel_estimates S3 object (list) with components: estimates
#'   (tibble with estimate, se, ci_lower, ci_upper, n columns, plus grouping
#'   columns if \code{by} is specified), method (character: "ratio-of-means-cpue"
#'   or "mean-of-ratios-cpue", with "-per-angler" suffix when normalized),
#'   variance_method (character: reflects the variance parameter value used),
#'   design (reference to source creel_design), conf_level (numeric), and
#'   by_vars (character vector of grouping variable names or NULL).
#'
#' @section Package Options:
#' \strong{Complete Trip Percentage Threshold:}
#' The package option \code{tidycreel.min_complete_pct} controls the threshold
#' for complete trip percentage warnings (default: 0.10 = 10\%). When the
#' percentage of complete trips falls below this threshold, a warning is issued
#' referencing Pollock et al. roving-access design best practices. Users can
#' set a custom threshold for their session:
#'
#' \code{options(tidycreel.min_complete_pct = 0.05)}
#'
#' The default 10\% threshold follows Pollock et al. recommendations for
#' scientifically valid estimation. Lowering the threshold is appropriate only
#' for special cases with documented justification. Warnings help ensure data
#' quality and guide users toward diagnostic validation when complete trip
#' samples are insufficient.
#'
#' @details
#' \strong{Trip Type Selection (use_trips):}
#' When trip_status is provided, the \code{use_trips} parameter controls which
#' trips are used for estimation. The default \code{use_trips = "complete"}
#' filters to complete trips only, following roving-access design best practices
#' (Colorado C-SAP, Pollock et al.). Complete trip interviews are taken at trip
#' completion and avoid length-of-stay bias. Setting \code{use_trips = "incomplete"}
#' filters to incomplete trips and automatically uses the MOR estimator.
#' Incomplete trip estimation is diagnostic/research mode and requires validation
#' (see Phase 19 validate_incomplete_trips). Setting \code{use_trips = "diagnostic"}
#' runs both complete and incomplete trip estimation and returns a comparison
#' object with difference metrics and interpretation guidance. Diagnostic mode
#' requires both trip types to be present in the data. When trip_status is not
#' provided, use_trips is ignored for perfect backward compatibility with v0.2.0.
#'
#' \strong{Ratio-of-Means (default):}
#' CPUE is estimated as the ratio of total catch to total effort. This is the
#' appropriate estimator for complete trip interviews (interview at trip end).
#' The function uses survey::svyratio() internally, which correctly accounts
#' for the correlation between catch and effort in variance estimation.
#'
#' \strong{Mean-of-Ratios (MOR):}
#' When \code{estimator = "mor"}, CPUE is estimated as the mean of individual
#' catch/effort ratios. This is the statistically appropriate estimator for
#' incomplete trip interviews (interview during trip). MOR automatically filters
#' to incomplete trips only and requires the trip_status field. The function
#' uses survey::svymean() on individual ratios.
#'
#' \strong{Trip Truncation:}
#' Very short incomplete trips can produce extreme catch/effort ratios that
#' dominate variance estimation. Following Hoenig et al. (1997), the default
#' \code{truncate_at = 0.5} hours (30 minutes) excludes trips shorter than
#' this threshold before MOR estimation. The survey design is rebuilt with
#' the truncated sample for correct variance computation. Set \code{truncate_at = NULL}
#' to disable truncation (research mode only). Truncation only applies to MOR
#' estimator; ratio-of-means ignores this parameter.
#'
#' The function performs sample size validation before estimation: errors if
#' n < 10 (ungrouped or any group), warns if 10 <= n < 30. For MOR, validation
#' uses the post-truncation sample size. This follows best practices for ratio
#' estimation stability.
#'
#' When grouped estimation is used (\code{by} is not NULL), survey::svyby()
#' correctly accounts for domain estimation variance.
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
#'
#' # Mean-of-ratios for incomplete trips
#' result_mor <- estimate_cpue(design_with_interviews, estimator = "mor")
#'
#' # Mean-of-ratios with custom truncation threshold
#' result_mor_1h <- estimate_cpue(design_with_interviews, estimator = "mor", truncate_at = 1.0)
#' @export
estimate_cpue <- function(design,
                          by = NULL,
                          variance = "taylor",
                          conf_level = 0.95,
                          estimator = "ratio-of-means",
                          use_trips = NULL,
                          truncate_at = 0.5) {
  # Capture by parameter BEFORE validation
  by_quo <- rlang::enquo(by)

  # Track whether use_trips was explicitly provided (for messaging)
  use_trips_is_default <- is.null(use_trips)
  if (is.null(use_trips)) {
    use_trips <- "complete"
  }

  # Validate variance parameter
  valid_methods <- c("taylor", "bootstrap", "jackknife")
  if (!variance %in% valid_methods) {
    cli::cli_abort(c(
      "Invalid variance method: {.val {variance}}",
      "x" = "Must be one of: {.val {valid_methods}}",
      "i" = "Default is {.val taylor} (Taylor linearization)"
    ))
  }

  # Validate estimator parameter
  valid_estimators <- c("ratio-of-means", "mor")
  if (!estimator %in% valid_estimators) {
    cli::cli_abort(c(
      "Invalid estimator: {.val {estimator}}",
      "x" = "Must be one of: {.val {valid_estimators}}",
      "i" = "{.val ratio-of-means} for complete trips, {.val mor} for incomplete trips"
    ))
  }

  # Validate truncate_at parameter
  if (!is.null(truncate_at) && (!is.numeric(truncate_at) || truncate_at <= 0)) {
    cli::cli_abort(c(
      "Invalid truncate_at: {.val {truncate_at}}",
      "x" = "truncate_at must be positive or NULL",
      "i" = "Default is 0.5 hours (30 minutes) per Hoenig et al. (1997)"
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

  # Backward compatibility: if trip_status_col is NULL, skip all use_trips logic
  # This ensures perfect v0.2.0 compatibility when trip_status not provided
  has_trip_status <- !is.null(design$trip_status_col)

  if (has_trip_status) {
    # Validate use_trips parameter
    valid_use_trips <- c("complete", "incomplete", "diagnostic")
    if (!use_trips %in% valid_use_trips) {
      cli::cli_abort(c(
        "Invalid use_trips value: {.val {use_trips}}",
        "x" = "Must be one of: {.val {valid_use_trips}}",
        "i" = paste(
          "{.val complete} for complete trips (default),",
          "{.val incomplete} for incomplete trips,",
          "{.val diagnostic} for comparison"
        )
      ))
    }

    # Handle diagnostic mode
    if (use_trips == "diagnostic") {
      # Diagnostic mode requires both complete and incomplete trips
      trip_status_col <- design$trip_status_col
      n_complete <- sum(design$interviews[[trip_status_col]] == "complete", na.rm = TRUE)
      n_incomplete <- sum(design$interviews[[trip_status_col]] == "incomplete", na.rm = TRUE)

      if (n_complete == 0) {
        cli::cli_abort(c(
          "Diagnostic mode requires complete trips",
          "x" = "Dataset has 0 complete trips",
          "i" = "Diagnostic mode compares complete vs incomplete trip estimates",
          "i" = "Ensure trip_status includes complete trips in interview data"
        ))
      }

      if (n_incomplete == 0) {
        cli::cli_abort(c(
          "Diagnostic mode requires incomplete trips",
          "x" = "Dataset has 0 incomplete trips",
          "i" = "Diagnostic mode compares complete vs incomplete trip estimates",
          "i" = "Ensure trip_status includes incomplete trips in interview data"
        ))
      }

      # Informative message about diagnostic comparison
      cli::cli_inform(c(
        "i" = "Running diagnostic comparison",
        " " = "Complete trips (n={n_complete}) vs Incomplete trips (n={n_incomplete})"
      ))

      # Call estimate_cpue recursively for both trip types
      complete_result <- estimate_cpue(
        design = design,
        by = !!by_quo,
        variance = variance,
        conf_level = conf_level,
        estimator = "ratio-of-means",
        use_trips = "complete",
        truncate_at = truncate_at
      )

      incomplete_result <- suppressWarnings(
        estimate_cpue(
          design = design,
          by = !!by_quo,
          variance = variance,
          conf_level = conf_level,
          estimator = "mor",
          use_trips = "incomplete",
          truncate_at = truncate_at
        )
      )

      # Build comparison data frame
      if (rlang::quo_is_null(by_quo)) {
        # Ungrouped: simple two-row comparison
        comparison <- data.frame(
          trip_type = c("complete", "incomplete"),
          estimate = c(complete_result$estimates$estimate, incomplete_result$estimates$estimate),
          se = c(complete_result$estimates$se, incomplete_result$estimates$se),
          ci_lower = c(complete_result$estimates$ci_lower, incomplete_result$estimates$ci_lower),
          ci_upper = c(complete_result$estimates$ci_upper, incomplete_result$estimates$ci_upper),
          n = c(complete_result$estimates$n, incomplete_result$estimates$n),
          stringsAsFactors = FALSE
        )

        # Calculate overall difference metrics
        diff_estimate <- complete_result$estimates$estimate - incomplete_result$estimates$estimate
        ratio_estimate <- complete_result$estimates$estimate / incomplete_result$estimates$estimate

        # Interpretation guidance
        threshold <- 0.1 * complete_result$estimates$estimate
        if (abs(diff_estimate) < threshold) {
          interpretation <- "Estimates are similar (difference < 10% of complete estimate)"
        } else {
          interpretation <- paste(
            "Estimates differ substantially",
            "(difference >= 10% of complete estimate) - investigate causes"
          )
        }
      } else {
        # Grouped: comparison within each group
        # Add trip_type column to each result
        complete_comparison <- complete_result$estimates
        complete_comparison$trip_type <- "complete"

        incomplete_comparison <- incomplete_result$estimates
        incomplete_comparison$trip_type <- "incomplete"

        # Combine into single comparison table
        comparison <- rbind(complete_comparison, incomplete_comparison)

        # Reorder columns to put trip_type first (after grouping columns)
        by_vars <- complete_result$by_vars
        other_cols <- setdiff(names(comparison), c(by_vars, "trip_type"))
        comparison <- comparison[, c(by_vars, "trip_type", other_cols)]

        # Calculate difference metrics per group
        diff_estimate <- complete_comparison$estimate - incomplete_comparison$estimate
        ratio_estimate <- complete_comparison$estimate / incomplete_comparison$estimate

        # Interpretation guidance for grouped
        interpretation <- paste(
          "See comparison table for within-group differences.",
          "Investigate groups with ratio_estimate far from 1.0"
        )
      }

      # Return diagnostic object
      result <- list(
        comparison = comparison,
        complete_result = complete_result,
        incomplete_result = incomplete_result,
        diff_estimate = diff_estimate,
        ratio_estimate = ratio_estimate,
        interpretation = interpretation,
        conf_level = conf_level,
        by_vars = complete_result$by_vars
      )

      class(result) <- c("creel_estimates_diagnostic", "list")
      return(result)
    }

    # Validate use_trips + estimator combination
    if (use_trips == "incomplete" && estimator == "ratio-of-means") {
      cli::cli_abort(c(
        "Invalid combination: use_trips='incomplete' with estimator='ratio-of-means'",
        "x" = "Incomplete trips require mean-of-ratios (MOR) estimator",
        "i" = "Incomplete trips have length-of-stay bias (Pollock et al.)",
        "i" = "Use {.code estimator = 'mor'} with {.code use_trips = 'incomplete'}",
        "i" = "Or use {.code use_trips = 'complete'} (default) with ratio-of-means"
      ))
    }

    # Auto-adjust use_trips when estimator=mor requested with default use_trips
    if (estimator == "mor" && use_trips_is_default) {
      use_trips <- "incomplete"
      # Clear the is_default flag since we're now explicitly using incomplete
      use_trips_is_default <- FALSE
    }

    # Force MOR estimator for incomplete trips when estimator not explicitly set
    # NOTE: Above validation ensures if we reach here with use_trips='incomplete', estimator must be 'mor'
    if (use_trips == "incomplete") {
      estimator <- "mor"
    }

    # Filter to selected trip type and validate sample size
    trip_status_col <- design$trip_status_col
    n_complete <- sum(design$interviews[[trip_status_col]] == "complete", na.rm = TRUE)
    n_incomplete <- sum(design$interviews[[trip_status_col]] == "incomplete", na.rm = TRUE)
    n_total <- n_complete + n_incomplete

    # Warn if complete trip percentage is below threshold (uses package option)
    # Check if we're doing grouped estimation to provide per-group warnings
    if (rlang::quo_is_null(by_quo)) {
      # Ungrouped: overall warning
      warn_low_complete_pct(n_complete, n_total) # nolint: object_usage_linter
    } else {
      # Grouped: per-group warnings (before filtering)
      # Resolve by parameter to column names for grouping, handling species col
      warn_by_info <- resolve_species_by(by_quo, design) # nolint: object_usage_linter
      warn_by_vars <- warn_by_info$interview_vars # only interview-level vars for grouping

      if (!is.null(warn_by_vars)) {
        # Split data by interview-level groups and check each group
        group_list <- split(design$interviews, design$interviews[warn_by_vars], drop = TRUE)

        for (group_name in names(group_list)) {
          group_data <- group_list[[group_name]]
          n_complete_group <- sum(group_data[[trip_status_col]] == "complete", na.rm = TRUE)
          n_total_group <- sum(!is.na(group_data[[trip_status_col]]))

          # Warn if this group has low complete trip percentage
          warn_low_complete_pct(n_complete_group, n_total_group) # nolint: object_usage_linter
        }
      } else {
        # Only species in by= (no interview grouping) — warn overall
        warn_low_complete_pct(n_complete, n_total) # nolint: object_usage_linter
      }
    }

    if (use_trips == "complete") {
      # Check complete trips available
      if (n_complete == 0) {
        cli::cli_abort(c(
          "No complete trips available for estimation",
          "x" = "use_trips='complete' but dataset has 0 complete trips",
          "i" = "Use {.code use_trips = 'incomplete'} if incomplete trips are available",
          "i" = "Or check trip_status values in interview data"
        ))
      }

      # Check sample size for complete trips
      if (n_complete < 10) {
        cli::cli_abort(c(
          "Insufficient complete trips for estimation",
          "x" = "use_trips='complete' but only {n_complete} complete trip{?s} available",
          "i" = "Need at least 10 complete trips for stable estimates",
          "i" = "Consider using diagnostic mode with {.code use_trips = 'incomplete'} if appropriate",
          "i" = "See roving-access design documentation for guidance"
        ))
      }

      # Informative message about trip selection
      pct_complete <- round(100 * n_complete / n_total, 1) # nolint: object_usage_linter
      if (use_trips_is_default) {
        cli::cli_inform(c(
          "i" = "Using complete trips for CPUE estimation",
          " " = "(n={n_complete}, {pct_complete}% of {n_total} interviews) [default]"
        ))
      } else {
        cli::cli_inform(c(
          "i" = "Using complete trips for CPUE estimation",
          " " = "(n={n_complete}, {pct_complete}% of {n_total} interviews)"
        ))
      }

      # Filter to complete trips and rebuild survey design
      complete_interviews <- design$interviews[design$interviews[[trip_status_col]] == "complete", ]
      design <- rebuild_interview_survey(design, complete_interviews) # nolint: object_usage_linter
    } else if (use_trips == "incomplete") {
      # Check incomplete trips available
      if (n_incomplete == 0) {
        cli::cli_abort(c(
          "No incomplete trips available for estimation",
          "x" = "use_trips='incomplete' but dataset has 0 incomplete trips",
          "i" = "Use {.code use_trips = 'complete'} (default) for complete trips",
          "i" = "Or check trip_status values in interview data"
        ))
      }

      # Informative message about trip selection
      pct_incomplete <- round(100 * n_incomplete / n_total, 1) # nolint: object_usage_linter
      cli::cli_inform(c(
        "i" = "Using incomplete trips for CPUE estimation",
        " " = "(n={n_incomplete}, {pct_incomplete}% of {n_total} interviews)"
      ))

      # Filter to incomplete trips and rebuild survey design
      # This lets MOR's validate_mor_availability see incomplete-only data
      incomplete_interviews <- design$interviews[design$interviews[[trip_status_col]] == "incomplete", ]
      design <- rebuild_interview_survey(design, incomplete_interviews) # nolint: object_usage_linter
    }
  }

  # If MOR estimator requested, validate and filter to incomplete trips
  if (estimator == "mor") {
    # Determine if we already filtered via use_trips
    # If use_trips='incomplete', we already filtered to incomplete in use_trips block
    # If use_trips='complete', we filtered to complete (MOR will see only complete trips - non-standard but valid)
    use_trips_was_incomplete <- has_trip_status && use_trips == "incomplete"
    use_trips_was_complete <- has_trip_status && use_trips == "complete"

    # Non-standard case: use_trips='complete' + estimator='mor'
    # Warn but allow (valid but unusual choice)
    if (use_trips_was_complete) {
      cli::cli_warn(c(
        "Non-standard combination: use_trips='complete' with estimator='mor'",
        "i" = "MOR typically used with incomplete trips",
        "i" = paste(
          "You are using MOR on {nrow(design$interviews)} complete trips -",
          "consider {.code estimator = 'ratio-of-means'} for standard complete trip estimation"
        )
      ))
    } else {
      # Standard MOR usage - validate incomplete trips available
      validate_mor_availability(design) # nolint: object_usage_linter
    }

    # Calculate trip counts for warning and handle filtering
    if (use_trips_was_incomplete) {
      # Already filtered to incomplete trips in use_trips block - all rows are incomplete
      n_incomplete <- nrow(design$interviews)
      n_total <- n_incomplete # For MOR warning context
      incomplete_interviews <- design$interviews
    } else if (use_trips_was_complete) {
      # Non-standard case: use_trips='complete' + estimator='mor'
      # Design already filtered to complete trips - use them with MOR (unusual but valid)
      n_complete_for_mor <- nrow(design$interviews)
      n_total <- n_complete_for_mor
      n_incomplete <- 0 # Not using incomplete trips
      # Use complete trips for MOR estimation (non-standard)
      incomplete_interviews <- design$interviews
    } else {
      # Old behavior: no use_trips filtering, filter to incomplete now
      n_total <- nrow(design$interviews)
      n_incomplete <- sum(design$interviews[[design$trip_status_col]] == "incomplete", na.rm = TRUE)
      incomplete_interviews <- design$interviews[design$interviews[[design$trip_status_col]] == "incomplete", ]
    }

    # Issue warning about MOR assumptions BEFORE estimation
    # For use_trips='complete' + MOR, skip standard MOR warning (already warned above)
    if (!use_trips_was_complete) {
      mor_estimation_warning(n_incomplete, n_total) # nolint: object_usage_linter
    }

    # Apply truncation if specified
    if (!is.null(truncate_at)) {
      # Filter to trips >= threshold
      truncated_interviews <- incomplete_interviews[
        incomplete_interviews[[design$trip_duration_col]] >= truncate_at,
      ]

      # Count truncated trips
      n_truncated <- nrow(incomplete_interviews) - nrow(truncated_interviews)

      # Use truncated data
      incomplete_interviews <- truncated_interviews

      # Issue truncation message
      mor_truncation_message(n_truncated, n_incomplete, truncate_at) # nolint: object_usage_linter
    } else {
      n_truncated <- 0
    }

    # Create new interview survey design with incomplete trips only
    design_incomplete <- design
    design_incomplete$interviews <- incomplete_interviews

    # Store trip counts for MOR constructor (before design replacement)
    design_incomplete$mor_n_incomplete <- n_incomplete
    design_incomplete$mor_n_total <- n_total

    # Store truncation metadata for messaging (Phase 16-02)
    design_incomplete$mor_truncate_at <- truncate_at
    design_incomplete$mor_n_truncated <- n_truncated

    # Rebuild survey design for incomplete trips
    strata_cols <- design$strata_cols
    strata_formula <- if (!is.null(strata_cols) && length(strata_cols) > 0) {
      stats::reformulate(strata_cols)
    } else {
      NULL
    }
    design_incomplete$interview_survey <- build_interview_survey( # nolint: object_usage_linter
      incomplete_interviews,
      strata = strata_formula
    )

    # Use the incomplete-trip design for estimation
    design <- design_incomplete
  }

  # Detect species-level grouping
  by_info <- resolve_species_by(by_quo, design) # nolint: object_usage_linter

  # Route to species-level or standard estimation
  if (!is.null(by_info$species_var)) {
    # Species-level CPUE: requires design$catch
    if (is.null(design[["catch"]])) {
      cli::cli_abort(c(
        "Species-level CPUE requires catch data.",
        "x" = "{.field species} found in {.arg by} but {.fn add_catch} has not been called.",
        "i" = "Call {.fn add_catch} before using species grouping in {.fn estimate_cpue}."
      ))
    }

    estimates_df <- estimate_cpue_species( # nolint: object_usage_linter
      design,
      species_col       = by_info$species_var,
      interview_by_vars = by_info$interview_vars,
      variance_method   = variance,
      conf_level        = conf_level,
      estimator         = estimator
    )

    return(new_creel_estimates( # nolint: object_usage_linter
      estimates       = tibble::as_tibble(estimates_df),
      method          = "ratio-of-means-cpue-species",
      variance_method = variance,
      design          = design,
      conf_level      = conf_level,
      by_vars         = by_info$all_vars
    ))
  }

  # Standard (non-species) routing
  if (rlang::quo_is_null(by_quo)) {
    validate_ratio_sample_size(design, NULL, type = "cpue") # nolint: object_usage_linter
    return(estimate_cpue_total(design, variance, conf_level, estimator)) # nolint: object_usage_linter
  } else {
    by_cols <- tidyselect::eval_select(
      by_quo,
      data = design$interviews,
      allow_rename = FALSE,
      allow_empty = FALSE,
      error_call = rlang::caller_env()
    )
    by_vars <- names(by_cols)
    validate_ratio_sample_size(design, by_vars, type = "cpue") # nolint: object_usage_linter
    return(estimate_cpue_grouped(design, by_vars, variance, conf_level, estimator)) # nolint: object_usage_linter
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
#' @param verbose Logical. If TRUE, prints an informational message identifying
#'   which estimator path was used. Default FALSE.
#' @param use_trips Character string specifying which trip type to use for
#'   bus-route estimation. One of \code{"complete"} (default),
#'   \code{"incomplete"} (pi_i-weighted MOR), or \code{"diagnostic"} (both).
#'   Ignored for non-bus-route designs.
#' @return A creel_estimates S3 object (list) with components: estimates
#'   (tibble with estimate, se, ci_lower, ci_upper, n columns, plus grouping
#'   columns if \code{by} is specified), method (character: "ratio-of-means-hpue",
#'   with "-per-angler" suffix when normalized), variance_method (character:
#'   reflects the variance parameter value used), design (reference to source
#'   creel_design), conf_level (numeric), and by_vars (character vector of
#'   grouping variable names or NULL).
#'   For bus-route designs, a "site_contributions" attribute is also present.
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
#'
#' # Verbose dispatch message (shows which estimator was used for bus-route designs)
#' # result_verbose <- estimate_harvest(design, verbose = TRUE)
#' @export
estimate_harvest <- function(
  design,
  by = NULL,
  variance = "taylor",
  conf_level = 0.95,
  verbose = FALSE,
  use_trips = NULL
) {
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

  # Validate design$interview_survey exists (skip for bus-route: uses interviews not counts)
  if (!identical(design$design_type, "bus_route") && is.null(design$interview_survey)) {
    cli::cli_abort(c(
      "No interview survey design available.",
      "x" = "Call {.fn add_interviews} before estimating harvest.",
      "i" = paste(
        "Example: {.code design <- add_interviews(design, interviews,",
        "catch = catch_total, harvest = catch_kept, effort = hours_fished)}"
      )
    ))
  }

  # Bus-route dispatch (before standard tier-2 validation)
  if (!is.null(design$design_type) && design$design_type == "bus_route") {
    if (verbose) {
      cli::cli_inform(c(
        "i" = "Using bus-route estimator (Jones & Pollock 2012, Eq. 19.5)"
      ))
    }

    # Resolve by parameter to column names for bus-route
    if (rlang::quo_is_null(by_quo)) {
      by_vars_br <- NULL
    } else {
      by_cols_br <- tidyselect::eval_select(
        by_quo,
        data = design$interviews,
        allow_rename = FALSE,
        allow_empty = FALSE,
        error_call = rlang::caller_env()
      )
      by_vars_br <- names(by_cols_br)
    }
    use_trips_br <- if (is.null(use_trips)) "complete" else use_trips
    return(estimate_harvest_br( # nolint: object_usage_linter
      design, by_vars_br, variance, conf_level,
      verbose = FALSE, use_trips = use_trips_br
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

#' Estimate release rate (RPUE: Released fish Per Unit Effort) from a creel survey design
#'
#' Computes release rate estimates with standard errors and confidence intervals
#' from a creel survey design with attached interview and catch data. Uses
#' ratio-of-means estimation via survey::svyratio(). RPUE measures the rate of
#' released fish per unit effort, analogous to HPUE for harvested fish.
#'
#' @param design A creel_design object with interviews (via \code{\link{add_interviews}})
#'   and catch data (via \code{\link{add_catch}}) attached. The catch data must
#'   include records with \code{catch_type = "released"}.
#' @param by Optional tidy selector for grouping variables. Accepts bare column
#'   names (e.g., \code{by = day_type}, \code{by = species}), multiple columns,
#'   or tidyselect helpers. When species grouping is used, per-species release
#'   rates are estimated.
#' @param variance Character string specifying variance estimation method.
#'   Options: \code{"taylor"} (default), \code{"bootstrap"}, or
#'   \code{"jackknife"}.
#' @param conf_level Numeric confidence level (default: 0.95).
#' @param normalize_by_anglers Logical. If \code{TRUE}, multiplies effort by
#'   \code{n_anglers} to convert party-hours to angler-hours, yielding fish
#'   released per angler per hour. Default \code{FALSE}. Requires
#'   \code{n_anglers} to be set via \code{add_interviews()}.
#'
#' @return A creel_estimates S3 object with method = "ratio-of-means-rpue".
#'   Estimates tibble has columns: estimate, se, ci_lower, ci_upper, n (plus
#'   any grouping columns).
#'
#' @details
#' RPUE is estimated as the ratio of total released fish to total effort
#' (ratio-of-means). Release data comes from \code{add_catch()} records with
#' \code{catch_type = "released"}. Interviews with no releases contribute 0
#' to the numerator (zero-fill), ensuring the effort denominator is correct.
#'
#' @seealso \code{\link{estimate_harvest}} for harvest rate, \code{\link{add_catch}}
#'
#' @examples
#' library(tidycreel)
#' data(example_calendar)
#' data(example_counts)
#' data(example_interviews)
#' data(example_catch)
#'
#' design <- creel_design(example_calendar, date = date, strata = day_type)
#' design <- add_counts(design, example_counts)
#' design <- add_interviews(design, example_interviews,
#'   catch = catch_total, effort = hours_fished,
#'   trip_status = trip_status, trip_duration = trip_duration
#' )
#' design <- add_catch(design, example_catch,
#'   catch_uid = interview_id,
#'   interview_uid = interview_id,
#'   species = species,
#'   count = count,
#'   catch_type = catch_type
#' )
#'
#' # Overall release rate (all species combined)
#' rpue <- estimate_release_rate(design)
#' print(rpue)
#'
#' # Per-species release rates
#' rpue_by_species <- estimate_release_rate(design, by = species)
#' print(rpue_by_species)
#' @export
estimate_release_rate <- function(
  design,
  by = NULL,
  variance = "taylor",
  conf_level = 0.95,
  normalize_by_anglers = FALSE
) {
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

  # Validate catch data exists
  if (is.null(design[["catch"]])) {
    cli::cli_abort(c(
      "No catch data available.",
      "x" = "Call {.fn add_catch} before estimating release rate.",
      "i" = "Release data comes from catch records with catch_type = 'released'."
    ))
  }

  # Validate interview survey exists
  if (is.null(design$interview_survey)) {
    cli::cli_abort(c(
      "No interview survey design available.",
      "x" = "Call {.fn add_interviews} before estimating release rate.",
      "i" = "Release rate requires effort data from interviews."
    ))
  }

  # Validate normalize_by_anglers
  if (!is.logical(normalize_by_anglers) || length(normalize_by_anglers) != 1L) {
    cli::cli_abort(c(
      "{.arg normalize_by_anglers} must be a single logical value.",
      "x" = "Got: {.val {normalize_by_anglers}}"
    ))
  }
  if (normalize_by_anglers && is.null(design$n_anglers_col)) {
    cli::cli_abort(c(
      "{.arg normalize_by_anglers = TRUE} requires {.field n_anglers} data.",
      "x" = "Design does not have {.field n_anglers_col} set.",
      "i" = "Call {.fn add_interviews} with the {.arg n_anglers} parameter."
    ))
  }

  # Detect species-level grouping
  by_info <- resolve_species_by(by_quo, design) # nolint: object_usage_linter

  if (!is.null(by_info$species_var)) {
    # Species-level release rate: loop over species
    estimates_df <- estimate_release_rate_species( # nolint: object_usage_linter
      design,
      species_col = by_info$species_var,
      interview_by_vars = by_info$interview_vars,
      variance_method = variance,
      conf_level = conf_level,
      normalize_by_anglers = normalize_by_anglers
    )
    method_name <- if (normalize_by_anglers) "ratio-of-means-rpue-per-angler" else "ratio-of-means-rpue"
    return(new_creel_estimates( # nolint: object_usage_linter
      estimates       = tibble::as_tibble(estimates_df),
      method          = method_name,
      variance_method = variance,
      design          = design,
      conf_level      = conf_level,
      by_vars         = by_info$all_vars
    ))
  }

  # Standard (non-species) path: aggregate all released counts per interview
  release_data <- estimate_release_build_data(design, species = NULL) # nolint: object_usage_linter

  # Apply normalize_by_anglers scaling if requested
  if (normalize_by_anglers) {
    n_ang_col <- design$n_anglers_col
    release_data$.release_effort <- release_data[[design$angler_effort_col]] *
      release_data[[n_ang_col]]
  } else {
    release_data$.release_effort <- release_data[[design$angler_effort_col]]
  }

  method_name <- if (normalize_by_anglers) "ratio-of-means-rpue-per-angler" else "ratio-of-means-rpue"

  # Build temporary design with release count and effort
  design_rel <- design
  design_rel$interviews <- release_data
  design_rel$catch_col <- ".release_count"
  design_rel$angler_effort_col <- ".release_effort"

  strata_cols <- design$strata_cols
  strata_formula <- if (!is.null(strata_cols) && length(strata_cols) > 0L) {
    stats::reformulate(strata_cols)
  } else {
    NULL
  }
  design_rel$interview_survey <- build_interview_survey( # nolint: object_usage_linter
    release_data,
    strata = strata_formula
  )

  if (rlang::quo_is_null(by_quo)) {
    validate_ratio_sample_size(design_rel, NULL, type = "cpue") # nolint: object_usage_linter
    result <- estimate_cpue_total(design_rel, variance, conf_level) # nolint: object_usage_linter
    result$method <- method_name
    result # nolint: return_linter
  } else {
    by_cols <- tidyselect::eval_select(
      by_quo,
      data = release_data,
      allow_rename = FALSE,
      allow_empty = FALSE,
      error_call = rlang::caller_env()
    )
    by_vars <- names(by_cols)
    validate_ratio_sample_size(design_rel, by_vars, type = "cpue") # nolint: object_usage_linter
    result <- estimate_cpue_grouped(design_rel, by_vars, variance, conf_level) # nolint: object_usage_linter
    result$method <- method_name
    result # nolint: return_linter
  }
}

# Helper functions ----

#' Rebuild interview survey design with filtered data
#'
#' Internal helper to rebuild survey design after filtering interviews
#' by trip type. Handles both stratified and unstratified designs.
#'
#' @param design Original creel_design object
#' @param filtered_interviews Data frame with filtered interview data
#'
#' @return Modified creel_design with updated interview_survey
#'
#' @keywords internal
#' @noRd
rebuild_interview_survey <- function(design, filtered_interviews) {
  design_new <- design
  design_new$interviews <- filtered_interviews

  # Rebuild survey design with filtered data
  strata_cols <- design$strata_cols
  strata_formula <- if (!is.null(strata_cols) && length(strata_cols) > 0) {
    stats::reformulate(strata_cols)
  } else {
    NULL
  }
  design_new$interview_survey <- build_interview_survey( # nolint: object_usage_linter
    filtered_interviews,
    strata = strata_formula
  )

  design_new
}

#' Resolve by= selector across both interviews and catch (species) data
#'
#' Internal helper: splits a by= quosure into interview-level variables and the
#' species variable (from design$catch). Returns a named list so callers know
#' whether to route to species-level estimation.
#'
#' @param by_quo A quosure from enquo(by)
#' @param design A creel_design object
#'
#' @return Named list with:
#'   \item{all_vars}{character vector of all resolved variable names}
#'   \item{species_var}{character(1) or NULL -- the catch species column name}
#'   \item{interview_vars}{character vector of non-species variables}
#'
#' @keywords internal
#' @noRd
resolve_species_by <- function(by_quo, design) {
  # If no catch data, cannot have species -- resolve normally against interviews
  if (is.null(design[["catch"]])) {
    if (rlang::quo_is_null(by_quo)) {
      return(list(all_vars = NULL, species_var = NULL, interview_vars = NULL))
    }
    by_cols <- tidyselect::eval_select(
      by_quo,
      data = design$interviews,
      allow_rename = FALSE,
      allow_empty = FALSE,
      error_call = rlang::caller_env()
    )
    return(list(
      all_vars = names(by_cols),
      species_var = NULL,
      interview_vars = names(by_cols)
    ))
  }

  if (rlang::quo_is_null(by_quo)) {
    return(list(all_vars = NULL, species_var = NULL, interview_vars = NULL))
  }

  # Build prototype data frame: interviews columns + species column
  # This allows eval_select to resolve species names without error
  species_col_name <- design$catch_species_col
  prototype <- design$interviews[0L, , drop = FALSE]
  prototype[[species_col_name]] <- character(0L)

  by_cols <- tidyselect::eval_select(
    by_quo,
    data = prototype,
    allow_rename = FALSE,
    allow_empty = FALSE,
    error_call = rlang::caller_env()
  )
  all_vars <- names(by_cols)

  # Split: species_var vs interview_vars
  species_var <- if (species_col_name %in% all_vars) species_col_name else NULL
  interview_vars <- setdiff(all_vars, species_col_name)
  if (length(interview_vars) == 0L) interview_vars <- NULL

  list(
    all_vars = all_vars,
    species_var = species_var,
    interview_vars = interview_vars
  )
}

#' Build per-species interview data for species-level estimation
#'
#' Joins design$catch (filtered to a specific catch_type) to design$interviews
#' for a single species. Every interview appears in the result; interviews that
#' did not catch this species receive count = 0. This zero-fill is statistically
#' required so the effort denominator includes all interviews.
#'
#' @param design A creel_design object with catch data attached
#' @param species_val Character(1). The species value to filter on.
#' @param catch_type_val Character(1). One of "caught", "harvested", "released".
#'
#' @return data.frame with all columns from design$interviews plus a
#'   ".species_count" column (integer, 0-filled). The interview FK column
#'   is used for matching.
#'
#' @keywords internal
#' @noRd
make_species_catch_for_interviews <- function(design, species_val, catch_type_val) { # nolint: object_length_linter
  catch_df <- design[["catch"]]
  interviews <- design$interviews

  uid_col <- design$catch_interview_uid_col
  species_col <- design$catch_species_col
  count_col <- design$catch_count_col
  type_col <- design$catch_type_col

  # Filter catch to this species + catch_type
  species_catch <- catch_df[
    catch_df[[species_col]] == species_val & catch_df[[type_col]] == catch_type_val,
    c(uid_col, count_col),
    drop = FALSE
  ]

  # Aggregate: sum counts per interview (handles multiple rows same species)
  if (nrow(species_catch) > 0L) {
    agg <- stats::aggregate(
      species_catch[[count_col]],
      by = list(uid = species_catch[[uid_col]]),
      FUN = sum
    )
    names(agg) <- c(uid_col, ".species_count")
  } else {
    agg <- data.frame(
      stats::setNames(list(integer(0L), integer(0L)), c(uid_col, ".species_count"))
    )
  }

  # Left-join to interviews (all interviews appear, 0 for missing)
  result <- merge(
    interviews,
    agg,
    by = uid_col,
    all.x = TRUE,
    sort = FALSE
  )
  result$.species_count[is.na(result$.species_count)] <- 0L

  result
}

#' Build per-interview release count data
#'
#' Aggregates design$catch (released rows) to one row per interview.
#' Zero-fills interviews with no releases.
#'
#' @param design A creel_design object with catch data attached
#' @param species Character(1) or NULL. If non-NULL, filter to this species only.
#'
#' @return data.frame: all design$interviews rows + ".release_count" column
#'
#' @keywords internal
#' @noRd
estimate_release_build_data <- function(design, species = NULL) {
  catch_df <- design[["catch"]]
  uid_col <- design$catch_interview_uid_col
  count_col <- design$catch_count_col
  type_col <- design$catch_type_col
  species_col <- design$catch_species_col

  # Filter to released rows (and optionally to a species)
  released <- catch_df[catch_df[[type_col]] == "released", , drop = FALSE]
  if (!is.null(species)) {
    released <- released[released[[species_col]] == species, , drop = FALSE]
  }

  # Aggregate count per interview
  if (nrow(released) > 0L) {
    agg <- stats::aggregate(
      released[[count_col]],
      by = list(uid = released[[uid_col]]),
      FUN = sum
    )
    names(agg) <- c(uid_col, ".release_count")
  } else {
    agg <- data.frame(
      stats::setNames(list(integer(0L), integer(0L)), c(uid_col, ".release_count"))
    )
  }

  # Left-join to all interviews
  result <- merge(design$interviews, agg, by = uid_col, all.x = TRUE, sort = FALSE)
  result$.release_count[is.na(result$.release_count)] <- 0L
  result
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
estimate_cpue_total <- function(design, variance_method, conf_level,
                                estimator = "ratio-of-means") {
  interviews_data <- design$interviews
  catch_col <- design$catch_col
  effort_col <- design$angler_effort_col

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
    strata_formula <- if (!is.null(strata_cols) && length(strata_cols) > 0) {
      stats::reformulate(strata_cols)
    } else {
      NULL
    }
    temp_survey <- build_interview_survey(interviews_data, strata = strata_formula) # nolint: object_usage_linter
    # Get variance design from temporary survey
    svy_design <- get_variance_design(temp_survey, variance_method) # nolint: object_usage_linter
  } else {
    # No filtering needed - use original design
    svy_design <- get_variance_design(design$interview_survey, variance_method) # nolint: object_usage_linter
  }

  # Determine method based on estimator
  if (estimator == "mor") {
    # Mean-of-ratios: compute individual ratios, then take mean
    # Add ratio column to data
    interviews_data$cpue_ratio <- interviews_data[[catch_col]] / interviews_data[[effort_col]]

    # Rebuild survey design with ratio column included
    strata_cols <- design$strata_cols
    strata_formula <- if (!is.null(strata_cols) && length(strata_cols) > 0) {
      stats::reformulate(strata_cols)
    } else {
      NULL
    }
    temp_survey <- build_interview_survey(interviews_data, strata = strata_formula) # nolint: object_usage_linter
    svy_design <- get_variance_design(temp_survey, variance_method) # nolint: object_usage_linter

    # Call survey::svymean on ratio (suppress expected survey package warnings)
    svy_result <- suppressWarnings(
      survey::svymean(~cpue_ratio, svy_design)
    )

    method_name <- "mean-of-ratios-cpue"
  } else {
    # Ratio-of-means: standard svyratio approach
    catch_formula <- stats::reformulate(catch_col)
    effort_formula <- stats::reformulate(effort_col)

    # Call survey::svyratio (suppress expected survey package warnings)
    svy_result <- suppressWarnings(
      survey::svyratio(catch_formula, effort_formula, svy_design)
    )

    method_name <- "ratio-of-means-cpue"
  }

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

  # Return appropriate creel_estimates object (MOR or standard)
  if (estimator == "mor") {
    # Get trip counts and truncation metadata stored during MOR filtering
    new_creel_estimates_mor( # nolint: object_usage_linter
      estimates = estimates_df,
      method = method_name,
      variance_method = variance_method,
      design = design,
      conf_level = conf_level,
      by_vars = NULL,
      n_incomplete = design$mor_n_incomplete,
      n_total = design$mor_n_total,
      mor_truncate_at = design$mor_truncate_at,
      mor_n_truncated = design$mor_n_truncated
    )
  } else {
    new_creel_estimates( # nolint: object_usage_linter
      estimates = estimates_df,
      method = method_name,
      variance_method = variance_method,
      design = design,
      conf_level = conf_level,
      by_vars = NULL
    )
  }
}

#' Grouped CPUE estimation using svyby + svyratio
#'
#' @keywords internal
#' @noRd
estimate_cpue_grouped <- function(design, by_vars, variance_method, conf_level,
                                  estimator = "ratio-of-means") {
  interviews_data <- design$interviews
  catch_col <- design$catch_col
  effort_col <- design$angler_effort_col

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

  # Determine method based on estimator
  if (estimator == "mor") {
    # Mean-of-ratios: add ratio column
    interviews_data$cpue_ratio <- interviews_data[[catch_col]] / interviews_data[[effort_col]]
    method_name <- "mean-of-ratios-cpue"
  } else {
    method_name <- "ratio-of-means-cpue"
  }

  # Build temporary survey design from filtered data (or with ratio column for MOR)
  if (any(zero_effort) || estimator == "mor") {
    # Get strata column(s) from original design
    strata_cols <- design$strata_cols
    strata_formula <- if (!is.null(strata_cols) && length(strata_cols) > 0) {
      stats::reformulate(strata_cols)
    } else {
      NULL
    }
    temp_survey <- build_interview_survey(interviews_data, strata = strata_formula) # nolint: object_usage_linter
    # Get variance design from temporary survey
    svy_design <- get_variance_design(temp_survey, variance_method) # nolint: object_usage_linter
  } else {
    # No filtering needed - use original design
    svy_design <- get_variance_design(design$interview_survey, variance_method) # nolint: object_usage_linter
  }

  # Build formulas for svyby
  by_formula <- stats::reformulate(by_vars)

  if (estimator == "mor") {
    # MOR: use svyby with svymean on ratio
    svy_result <- suppressWarnings(survey::svyby(
      formula = ~cpue_ratio,
      by = by_formula,
      design = svy_design,
      FUN = survey::svymean,
      vartype = c("se", "ci"),
      ci.level = conf_level,
      keep.names = FALSE
    ))

    # Extract estimate columns from svyby result
    # svymean uses simpler column names: cpue_ratio, se, ci_l, ci_u
    estimate <- svy_result[["cpue_ratio"]]
    se <- svy_result[["se"]]
    ci_lower <- svy_result[["ci_l"]]
    ci_upper <- svy_result[["ci_u"]]
  } else {
    # Ratio-of-means: use svyby with svyratio
    catch_formula <- stats::reformulate(catch_col)
    effort_formula <- stats::reformulate(effort_col)

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
  }

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

  # Return appropriate creel_estimates object (MOR or standard)
  if (estimator == "mor") {
    # Get trip counts and truncation metadata stored during MOR filtering
    new_creel_estimates_mor( # nolint: object_usage_linter
      estimates = estimates_df,
      method = method_name,
      variance_method = variance_method,
      design = design,
      conf_level = conf_level,
      by_vars = by_vars,
      n_incomplete = design$mor_n_incomplete,
      n_total = design$mor_n_total,
      mor_truncate_at = design$mor_truncate_at,
      mor_n_truncated = design$mor_n_truncated
    )
  } else {
    new_creel_estimates( # nolint: object_usage_linter
      estimates = estimates_df,
      method = method_name,
      variance_method = variance_method,
      design = design,
      conf_level = conf_level,
      by_vars = by_vars
    )
  }
}

#' Species-level CPUE estimation (loops over species)
#'
#' @param design A creel_design with non-NULL catch slot.
#' @param species_col Character(1). Name of species column in design$catch.
#' @param interview_by_vars Character vector or NULL. Calendar/interview grouping vars.
#' @param variance_method Character. Variance method.
#' @param conf_level Numeric.
#' @param estimator Character. "ratio-of-means" or "mor".
#'
#' @return tibble with species column first, then interview_by_vars, then estimate/se/ci/n.
#'
#' @keywords internal
#' @noRd
estimate_cpue_species <- function(design, species_col, interview_by_vars,
                                  variance_method, conf_level,
                                  estimator = "ratio-of-means") {
  all_species <- sort(unique(design[["catch"]][[species_col]]))

  results_list <- vector("list", length(all_species))

  for (i in seq_along(all_species)) {
    sp <- all_species[[i]]

    # Build per-species interview data (zero-filled)
    sp_data <- make_species_catch_for_interviews(design, sp, "caught") # nolint: object_usage_linter

    # Modify a temporary design with .species_count as catch column
    design_sp <- design
    design_sp$interviews <- sp_data
    design_sp$catch_col <- ".species_count"

    # Rebuild survey design for this species' data
    strata_cols <- design$strata_cols
    strata_formula <- if (!is.null(strata_cols) && length(strata_cols) > 0L) {
      stats::reformulate(strata_cols)
    } else {
      NULL
    }
    design_sp$interview_survey <- build_interview_survey( # nolint: object_usage_linter
      sp_data,
      strata = strata_formula
    )

    validate_ratio_sample_size(design_sp, interview_by_vars, type = "cpue") # nolint: object_usage_linter

    if (is.null(interview_by_vars)) {
      result <- estimate_cpue_total(design_sp, variance_method, conf_level, estimator) # nolint: object_usage_linter
    } else {
      result <- estimate_cpue_grouped(design_sp, interview_by_vars, variance_method, conf_level, estimator) # nolint: object_usage_linter
    }

    sp_df <- result$estimates
    sp_df[[species_col]] <- sp
    sp_df <- sp_df[c(species_col, setdiff(names(sp_df), species_col))]

    results_list[[i]] <- sp_df
  }

  do.call(rbind, results_list)
}

#' Species-level release rate estimation (loops over species)
#'
#' @keywords internal
#' @noRd
estimate_release_rate_species <- function(design, species_col, interview_by_vars,
                                          variance_method, conf_level,
                                          normalize_by_anglers = FALSE) {
  all_species <- sort(unique(design[["catch"]][[species_col]]))

  results_list <- vector("list", length(all_species))

  for (i in seq_along(all_species)) {
    sp <- all_species[[i]]

    # Build per-species release interview data (zero-filled)
    sp_data <- estimate_release_build_data(design, species = sp) # nolint: object_usage_linter

    # Apply normalization
    if (normalize_by_anglers) {
      n_ang_col <- design$n_anglers_col
      sp_data$.release_effort <- sp_data[[design$angler_effort_col]] * sp_data[[n_ang_col]]
    } else {
      sp_data$.release_effort <- sp_data[[design$angler_effort_col]]
    }

    design_sp <- design
    design_sp$interviews <- sp_data
    design_sp$catch_col <- ".release_count"
    design_sp$angler_effort_col <- ".release_effort"

    strata_cols <- design$strata_cols
    strata_formula <- if (!is.null(strata_cols) && length(strata_cols) > 0L) {
      stats::reformulate(strata_cols)
    } else {
      NULL
    }
    design_sp$interview_survey <- build_interview_survey( # nolint: object_usage_linter
      sp_data,
      strata = strata_formula
    )

    validate_ratio_sample_size(design_sp, interview_by_vars, type = "cpue") # nolint: object_usage_linter

    if (is.null(interview_by_vars)) {
      result <- estimate_cpue_total(design_sp, variance_method, conf_level) # nolint: object_usage_linter
    } else {
      result <- estimate_cpue_grouped(design_sp, interview_by_vars, variance_method, conf_level) # nolint: object_usage_linter
    }

    sp_df <- result$estimates
    sp_df[[species_col]] <- sp
    sp_df <- sp_df[c(species_col, setdiff(names(sp_df), species_col))]

    results_list[[i]] <- sp_df
  }

  do.call(rbind, results_list)
}

#' Species-level harvest rate estimation (loops over species, uses "harvested" catch_type)
#'
#' @keywords internal
#' @noRd
estimate_hpue_species <- function(design, species_col, interview_by_vars,
                                  variance_method, conf_level) {
  all_species <- sort(unique(design[["catch"]][[species_col]]))
  results_list <- vector("list", length(all_species))

  for (i in seq_along(all_species)) {
    sp <- all_species[[i]]

    # Build per-species harvest interview data (zero-filled, harvested only)
    sp_data <- make_species_catch_for_interviews(design, sp, "harvested") # nolint: object_usage_linter

    design_sp <- design
    design_sp$interviews <- sp_data
    design_sp$catch_col <- ".species_count"
    design_sp$harvest_col <- ".species_count"

    strata_cols <- design$strata_cols
    strata_formula <- if (!is.null(strata_cols) && length(strata_cols) > 0L) {
      stats::reformulate(strata_cols)
    } else {
      NULL
    }
    design_sp$interview_survey <- build_interview_survey( # nolint: object_usage_linter
      sp_data,
      strata = strata_formula
    )

    validate_ratio_sample_size(design_sp, interview_by_vars, type = "harvest") # nolint: object_usage_linter

    if (is.null(interview_by_vars)) {
      result <- estimate_harvest_total(design_sp, variance_method, conf_level) # nolint: object_usage_linter
    } else {
      result <- estimate_harvest_grouped(design_sp, interview_by_vars, variance_method, conf_level) # nolint: object_usage_linter
    }

    sp_df <- result$estimates
    sp_df[[species_col]] <- sp
    sp_df <- sp_df[c(species_col, setdiff(names(sp_df), species_col))]

    results_list[[i]] <- sp_df
  }

  do.call(rbind, results_list)
}

#' Ungrouped harvest (HPUE) estimation using ratio-of-means
#'
#' @keywords internal
#' @noRd
estimate_harvest_total <- function(design, variance_method, conf_level) {
  interviews_data <- design$interviews
  harvest_col <- design$harvest_col
  effort_col <- design$angler_effort_col

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
    strata_formula <- if (!is.null(strata_cols) && length(strata_cols) > 0) {
      stats::reformulate(strata_cols)
    } else {
      NULL
    }
    temp_survey <- build_interview_survey(interviews_data, strata = strata_formula) # nolint: object_usage_linter
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
  effort_col <- design$angler_effort_col

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
    strata_formula <- if (!is.null(strata_cols) && length(strata_cols) > 0) {
      stats::reformulate(strata_cols)
    } else {
      NULL
    }
    temp_survey <- build_interview_survey(interviews_data, strata = strata_formula) # nolint: object_usage_linter
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
