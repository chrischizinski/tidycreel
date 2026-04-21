# Imports ----

#' @importFrom stats coef confint qt reformulate setNames vcov
NULL

# Internal helpers ----

#' Wrap a survey package call and re-raise single-PSU errors as cli_abort
#'
#' @param expr An expression that calls a survey function (svytotal, svyby, etc.)
#' @return The result of the expression, or a structured cli_abort on single-PSU
#' @keywords internal
#' @noRd
wrap_survey_call <- function(expr) {
  tryCatch(
    suppressWarnings(expr),
    error = function(e) {
      msg <- conditionMessage(e)
      if (grepl("has only one PSU at stage", msg, fixed = TRUE)) {
        # Extract stratum name from: "Stratum (X) has only one PSU at stage 1"
        strat <- regmatches(msg, regexpr("(?<=Stratum \\()([^)]+)", msg, perl = TRUE))
        strat_label <- if (length(strat) > 0L && nzchar(strat)) strat else "unknown" # nolint: object_usage_linter
        cli::cli_abort(
          c(
            "Stratum {.val {strat_label}} has only 1 PSU \u2014 \\
          variance cannot be estimated.",
            "x" = paste0(
              "A stratum must have at least 2 PSUs (e.g., 2 sampled days) \\
            for variance estimation."
            ),
            "i" = paste0(
              "Increase the sampling rate for stratum {.val {strat_label}}, \\
            or combine sparse strata before estimation."
            )
          ),
          class = "creel_error_single_psu"
        )
      }
      stop(e)
    }
  )
}

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
                                by_vars = NULL,
                                effort_target = NULL) {
  # Input validation
  stopifnot(
    "estimates must be a data.frame" = is.data.frame(estimates),
    "method must be character" = is.character(method) && length(method) == 1,
    "variance_method must be character" = is.character(variance_method) && length(variance_method) == 1,
    "conf_level must be numeric" = is.numeric(conf_level) && length(conf_level) == 1,
    "by_vars must be NULL or character" = is.null(by_vars) || is.character(by_vars),
    "effort_target must be NULL or character" = is.null(effort_target) || is.character(effort_target)
  )

  structure(
    list(
      estimates = estimates,
      method = method,
      variance_method = variance_method,
      design = design,
      conf_level = conf_level,
      by_vars = by_vars,
      effort_target = effort_target
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

    if (!is.null(x$effort_target)) {
      cli::cli_text("Effort target: {x$effort_target}")
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
#' @param target Character string specifying the temporal effort target.
#'   Options: \code{"sampled_days"} (default, current behavior: total across
#'   sampled PSU rows only), \code{"stratum_total"} (expand sampled-day means
#'   within calendar strata before combining), or \code{"period_total"}
#'   (full calendar-period total after stratum expansion). For standard
#'   stratified count designs, \code{"stratum_total"} and \code{"period_total"}
#'   use the same weighted expansion engine; the distinction is semantic and is
#'   recorded on the returned object as \code{effort_target}. Expanded targets
#'   are currently limited to the standard count-design path and are not yet
#'   supported for bus-route, ice, aerial, or sectioned designs.
#' @param verbose Logical. If TRUE, prints an informational message identifying
#'   which estimator path was used. Default FALSE for transparent dispatch.
#' @param aggregate_sections Logical. If TRUE (default), a \code{.lake_total}
#'   row is appended aggregating across all sections. Ignored for non-sectioned
#'   designs.
#' @param method Character string specifying how the lake-wide total SE is
#'   computed when \code{aggregate_sections = TRUE}. \code{"correlated"}
#'   (default) uses \code{svyby(covmat=TRUE)} + \code{svycontrast()} for
#'   covariance-aware aggregation (recommended for shared-calendar NGPC
#'   designs). \code{"independent"} uses Cochran 5.2 \code{sqrt(sum(SE_h^2))}
#'   as a documented approximation for genuinely independent section designs.
#'   Ignored for non-sectioned designs.
#' @param missing_sections Character string controlling behavior when a
#'   registered section has no count observations. \code{"warn"} (default)
#'   emits a \code{cli_warn()} and inserts an NA row with
#'   \code{data_available = FALSE}. \code{"error"} aborts with
#'   \code{cli_abort()}. Ignored for non-sectioned designs.
#'
#' @return A creel_estimates S3 object (list) with components: estimates
#'   (tibble with estimate, se, se_between, se_within, ci_lower, ci_upper, n
#'   columns, plus grouping columns if \code{by} is specified),
#'   method (character: "total"),
#'   variance_method (character: reflects the variance parameter value used),
#'   design (reference to source creel_design), conf_level (numeric), and
#'   by_vars (character vector of grouping variable names or NULL).
#'   \code{se_between} is the between-day standard error from
#'   \code{survey::svytotal()} (equals \code{se} when a single count is
#'   recorded per PSU). \code{se_within} is the within-day standard error from
#'   the Rasmussen two-stage formula; it is zero when a single count is
#'   recorded per PSU and nonzero when \code{count_time_col} is supplied to
#'   \code{add_counts()}. For bus-route designs, a "site_contributions"
#'   attribute is also present containing per-site e_i, pi_i, and
#'   e_i_over_pi_i columns.
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
#' @family "Estimation"
#' @export
estimate_effort <- function(design, by = NULL, variance = "taylor", conf_level = 0.95,
                            target = c("sampled_days", "stratum_total", "period_total"),
                            verbose = FALSE, aggregate_sections = TRUE,
                            method = "correlated", missing_sections = "warn") {
  # Capture by parameter BEFORE validation
  by_quo <- rlang::enquo(by)
  target <- match.arg(target)

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

  # Validate design$survey exists (skip for bus-route, ice, and aerial: custom dispatch below)
  if (!design$design_type %in% c("bus_route", "ice", "aerial") && is.null(design$survey)) {
    cli::cli_abort(
      c(
        "No survey design available.",
        "x" = "Call {.fn add_counts} before estimating effort.",
        "i" = "Example: {.code design <- add_counts(design, counts)}"
      ),
      class = "creel_error_missing_survey_design"
    )
  }

  # Bus-route and ice dispatch (after survey NULL check, before standard tier-2 validation)
  if (!is.null(design$design_type) && design$design_type %in% c("bus_route", "ice")) {
    if (!identical(target, "sampled_days")) {
      cli::cli_abort(
        c(
          "Expanded effort targets are not yet supported for {.val {design$design_type}} designs.",
          "x" = "Got {.arg target = {target}}.",
          "i" = "Use {.code target = 'sampled_days'} for now."
        ),
        class = "creel_error_dispatch_unsupported"
      )
    }
    if (verbose) {
      cli::cli_inform(c(
        "i" = "Using bus-route estimator (Jones & Pollock 2012, Eq. 19.4)"
      ))
    }

    # Validate interview data exists
    if (is.null(design$interviews)) {
      cli::cli_abort(
        c(
          "Bus-route effort estimation requires interview data.",
          "x" = "No interview data found in design.",
          "i" = paste0(
            "Call {.fn add_interviews} with {.arg n_counted} and {.arg n_interviewed} parameters."
          )
        ),
        class = "creel_error_missing_data"
      )
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

    result <- estimate_effort_br( # nolint: object_usage_linter.
      design,
      by_vars_br,
      variance,
      conf_level,
      verbose,
      effort_target = target
    ) # nolint: object_usage_linter

    # Ice-specific: rename 'estimate' column to reflect effort_type
    if (identical(design$design_type, "ice")) {
      col_name <- switch(design$ice$effort_type,
        time_on_ice = "total_effort_hr_on_ice",
        active_fishing_time = "total_effort_hr_active",
        "estimate"
      )
      names(result$estimates)[names(result$estimates) == "estimate"] <- col_name
    }

    return(result)
  }

  # Aerial dispatch — svytotal scaled by h_open/v (Pollock et al. 1994 sec.15.6.1)
  if (!is.null(design$design_type) && identical(design$design_type, "aerial")) {
    if (!identical(target, "sampled_days")) {
      cli::cli_abort(
        c(
          "Expanded effort targets are not yet supported for aerial designs.",
          "x" = "Got {.arg target = {target}}.",
          "i" = "Use {.code target = 'sampled_days'} for now."
        ),
        class = "creel_error_dispatch_unsupported"
      )
    }
    if (is.null(design$counts)) {
      cli::cli_abort(
        c(
          "Aerial effort estimation requires count data.",
          "x" = "No count data found in design.",
          "i" = "Call {.fn add_counts} before estimating aerial effort."
        ),
        class = "creel_error_missing_data"
      )
    }
    return(estimate_effort_aerial(design, variance, conf_level, verbose, effort_target = target)) # nolint: object_usage_linter
  }

  # Section dispatch (v0.7.0+ — only fires when add_sections() was called)
  if (!is.null(design[["sections"]])) {
    if (!identical(target, "sampled_days")) {
      cli::cli_abort(c(
        "Expanded effort targets are not yet supported for sectioned designs.",
        "x" = "Got {.arg target = {target}}.",
        "i" = "Use {.code target = 'sampled_days'} for now."
      ))
    }
    return(estimate_effort_sections( # nolint: object_usage_linter
      design,
      variance,
      conf_level,
      aggregate_sections,
      method,
      missing_sections,
      target = target
    ))
  }

  # Tier 2 validation - data quality checks (warnings only)
  warn_tier2_issues(design) # nolint: object_usage_linter

  # Route to grouped or ungrouped estimation
  if (rlang::quo_is_null(by_quo)) {
    # Ungrouped estimation (Phase 4 behavior)
    return(estimate_effort_total(design, variance, conf_level, target = target)) # nolint: object_usage_linter
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

    return(estimate_effort_grouped(design, by_vars, variance, conf_level, target = target)) # nolint: object_usage_linter
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
#'   \code{"ratio-of-means"} (default, for complete trips), \code{"mor"}
#'   (mean-of-ratios, for incomplete trips), or \code{"mortr"} (truncated
#'   mean-of-ratios — same as \code{"mor"} but \code{truncate_at} is
#'   mandatory and defaults to 0.5 h). MOR and MORtr require the trip_status
#'   field and error if no incomplete trips are available. See Details.
#' @param use_trips Character string specifying which trip type to use when
#'   trip_status field is provided. Options: \code{"complete"} (default when
#'   NULL) uses only complete trips with ratio-of-means estimator,
#'   \code{"incomplete"} uses only incomplete trips with mean-of-ratios
#'   estimator, or \code{"diagnostic"} estimates CPUE using both trip types and
#'   returns a comparison table. Following Pollock et al. (1994),
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
#' @param targeted Logical. When \code{TRUE} (default), all trips are used.
#'   When \code{FALSE}, zero-effort trips are excluded before MOR/MORtr
#'   estimation — appropriate for non-targeted species where most trips have
#'   zero catch. A \code{cli_warn()} is emitted when more than 70\% of trips
#'   have zero catch and \code{targeted = TRUE} (possible mis-specification).
#'   Ignored for \code{ratio-of-means} estimator.
#' @param missing_sections Character string controlling behavior when a
#'   registered section has no interview observations. \code{"warn"} (default)
#'   emits a \code{cli_warn()} and inserts an NA row with
#'   \code{data_available = FALSE}. \code{"error"} aborts with
#'   \code{cli_abort()}. Ignored for non-sectioned designs.
#'
#' @note When called on a sectioned design, no \code{.lake_total} row is
#'   produced. Catch rates (fish per angler-hour) are not additive across
#'   sections. Lake-wide catch rate requires a separate unsectioned call on
#'   the full design. See \code{estimate_total_catch()} for lake-wide total
#'   catch estimation.
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
#' (Pollock et al. 1994). Complete trip interviews are taken at trip
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
#' result <- estimate_catch_rate(design_with_interviews)
#' print(result)
#'
#' # Grouped by day_type
#' result_grouped <- estimate_catch_rate(design_with_interviews, by = day_type)
#' print(result_grouped)
#'
#' # Custom confidence level
#' result_90 <- estimate_catch_rate(design_with_interviews, conf_level = 0.90)
#'
#' # Bootstrap variance estimation
#' result_boot <- estimate_catch_rate(design_with_interviews, variance = "bootstrap")
#'
#' # Mean-of-ratios for incomplete trips
#' result_mor <- estimate_catch_rate(design_with_interviews, estimator = "mor")
#'
#' # Mean-of-ratios with custom truncation threshold
#' result_mor_1h <- estimate_catch_rate(design_with_interviews, estimator = "mor", truncate_at = 1.0)
#' @family "Estimation"
#' @export
estimate_catch_rate <- function(design,
                                by = NULL,
                                variance = "taylor",
                                conf_level = 0.95,
                                estimator = "ratio-of-means",
                                use_trips = NULL,
                                truncate_at = 0.5,
                                targeted = TRUE,
                                missing_sections = "warn") {
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
  valid_estimators <- c("ratio-of-means", "mor", "mortr")
  if (!estimator %in% valid_estimators) {
    cli::cli_abort(c(
      "Invalid estimator: {.val {estimator}}",
      "x" = "Must be one of: {.val {valid_estimators}}",
      "i" = paste(
        "{.val ratio-of-means} for complete trips,",
        "{.val mor} for incomplete trips,",
        "{.val mortr} for truncated mean-of-ratios"
      )
    ))
  }

  # Normalise mortr -> mor with mandatory truncation
  if (estimator == "mortr") {
    if (is.null(truncate_at)) {
      truncate_at <- 0.5
    }
    estimator <- "mor"
    mortr_active <- TRUE
  } else {
    mortr_active <- FALSE
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

      # Call estimate_catch_rate recursively for both trip types
      complete_result <- estimate_catch_rate(
        design = design,
        by = !!by_quo,
        variance = variance,
        conf_level = conf_level,
        estimator = "ratio-of-means",
        use_trips = "complete",
        truncate_at = truncate_at
      )

      incomplete_result <- suppressWarnings(
        estimate_catch_rate(
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
  if (estimator %in% c("mor", "mortr")) {
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

    # targeted = FALSE: exclude zero-catch trips (non-targeted species)
    if (!targeted) {
      catch_col_local <- design$catch_col
      n_before_target <- nrow(incomplete_interviews)
      zero_catch_rows <- incomplete_interviews[[catch_col_local]] == 0 |
        is.na(incomplete_interviews[[catch_col_local]])
      n_zero <- sum(zero_catch_rows, na.rm = TRUE)
      incomplete_interviews <- incomplete_interviews[!zero_catch_rows, ]
      if (n_zero > 0) {
        pct_excluded <- round(100 * n_zero / n_before_target) # nolint: object_usage_linter
        cli::cli_warn(c(
          "{n_zero} zero-catch trip{?s} excluded ({pct_excluded}% of trips).",
          "i" = "Set {.code targeted = TRUE} to include zero-catch trips."
        ))
      }
      if (nrow(incomplete_interviews) == 0) {
        cli::cli_abort(c(
          "No trips remain after zero-catch exclusion.",
          "x" = "All trips had zero catch with {.code targeted = FALSE}.",
          "i" = "Set {.code targeted = TRUE} or check catch data."
        ))
      }
    } else {
      # Warn when targeted = TRUE but most trips are zero-catch
      # (possible mis-specification for a non-targeted species)
      catch_col_local <- design$catch_col
      col_present <- !is.null(catch_col_local) && catch_col_local %in% names(incomplete_interviews)
      if (col_present) {
        n_total_trips <- nrow(incomplete_interviews)
        n_zero_catch <- sum(
          incomplete_interviews[[catch_col_local]] == 0 |
            is.na(incomplete_interviews[[catch_col_local]]),
          na.rm = TRUE
        )
        high_zero_rate <- n_total_trips > 0 && (n_zero_catch / n_total_trips) > 0.70
        if (high_zero_rate) {
          cli::cli_warn(c(
            paste0(
              round(100 * n_zero_catch / n_total_trips),
              "% of trips have zero catch."
            ),
            "i" = paste0(
              "For non-targeted species, consider ",
              "{.code targeted = FALSE} to exclude zero-catch trips ",
              "before MOR estimation."
            )
          ))
        }
      }
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

  # Section dispatch guard — fires AFTER trip filtering, BEFORE standard dispatch
  if (!is.null(design[["sections"]])) {
    return(estimate_catch_rate_sections( # nolint: object_usage_linter
      design, by_quo, variance, conf_level, missing_sections, estimator
    ))
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
        "i" = "Call {.fn add_catch} before using species grouping in {.fn estimate_catch_rate}."
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
  # Restore mortr estimator string for downstream method labelling
  dispatch_estimator <- if (mortr_active) "mortr" else estimator
  if (rlang::quo_is_null(by_quo)) {
    validate_ratio_sample_size(design, NULL, type = "cpue") # nolint: object_usage_linter
    return(estimate_cpue_total(design, variance, conf_level, dispatch_estimator)) # nolint: object_usage_linter
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
    return(estimate_cpue_grouped( # nolint: object_usage_linter
      design, by_vars, variance, conf_level, dispatch_estimator
    ))
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
#' @param missing_sections Character string controlling behavior when a
#'   registered section has no interview observations. \code{"warn"} (default)
#'   emits a \code{cli_warn()} and inserts an NA row with
#'   \code{data_available = FALSE}. \code{"error"} aborts with
#'   \code{cli_abort()}. Ignored for non-sectioned designs.
#'
#' @note When called on a sectioned design, no \code{.lake_total} row is
#'   produced. Harvest rates (fish per angler-hour) are not additive across
#'   sections. Lake-wide harvest rate requires a separate unsectioned call.
#'
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
#' @seealso \code{\link{estimate_catch_rate}} for total catch rate estimation
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
#' result <- estimate_harvest_rate(design_with_interviews)
#' print(result)
#'
#' # Grouped by day_type
#' result_grouped <- estimate_harvest_rate(design_with_interviews, by = day_type)
#' print(result_grouped)
#'
#' # Custom confidence level
#' result_90 <- estimate_harvest_rate(design_with_interviews, conf_level = 0.90)
#'
#' # Bootstrap variance estimation
#' result_boot <- estimate_harvest_rate(design_with_interviews, variance = "bootstrap")
#'
#' # Verbose dispatch message (shows which estimator was used for bus-route designs)
#' # result_verbose <- estimate_harvest_rate(design, verbose = TRUE)
#' @family "Estimation"
#' @export
estimate_harvest_rate <- function(
  design,
  by = NULL,
  variance = "taylor",
  conf_level = 0.95,
  verbose = FALSE,
  use_trips = NULL,
  missing_sections = "warn"
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

  # Bus-route / ice dispatch (before standard tier-2 validation)
  # Ice is a degenerate bus-route (p_site = 1.0); both use the HT estimator.
  if (!is.null(design$design_type) && design$design_type %in% c("bus_route", "ice")) {
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

  # Section dispatch guard — fires AFTER validation, BEFORE standard dispatch
  if (!is.null(design[["sections"]])) {
    return(estimate_harvest_rate_sections( # nolint: object_usage_linter
      design, by_quo, variance, conf_level, missing_sections
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
#' @param missing_sections Character string controlling behavior when a
#'   registered section has no interview observations. \code{"warn"} (default)
#'   emits a \code{cli_warn()} and inserts an NA row with
#'   \code{data_available = FALSE}. \code{"error"} aborts with
#'   \code{cli_abort()}. Ignored for non-sectioned designs.
#'
#' @note When called on a sectioned design, no \code{.lake_total} row is
#'   produced. Release rates (fish per angler-hour) are not additive across
#'   sections. Lake-wide release rate requires a separate unsectioned call.
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
#' @seealso \code{\link{estimate_harvest_rate}} for harvest rate, \code{\link{add_catch}}
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
#' @family "Estimation"
#' @export
estimate_release_rate <- function(
  design,
  by = NULL,
  variance = "taylor",
  conf_level = 0.95,
  missing_sections = "warn"
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

  # Section dispatch guard — fires AFTER validation, BEFORE standard dispatch
  if (!is.null(design[["sections"]])) {
    return(estimate_release_rate_sections( # nolint: object_usage_linter
      design, by_quo, variance, conf_level, missing_sections
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
      conf_level = conf_level
    )
    return(new_creel_estimates( # nolint: object_usage_linter
      estimates       = tibble::as_tibble(estimates_df),
      method          = "ratio-of-means-rpue",
      variance_method = variance,
      design          = design,
      conf_level      = conf_level,
      by_vars         = by_info$all_vars
    ))
  }

  # Standard (non-species) path: aggregate all released counts per interview
  release_data <- estimate_release_build_data(design, species = NULL) # nolint: object_usage_linter

  release_data$.release_effort <- release_data[[design$angler_effort_col]]

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
    result$method <- "ratio-of-means-rpue"
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
    result$method <- "ratio-of-means-rpue"
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

#' Rebuild counts survey design for a single section
#'
#' Internal helper: filters design$counts to a single section and rebuilds the
#' svydesign using construct_survey_design(). Ensures per-section SE uses only
#' that section's PSUs as the denominator (not the full-lake PSU pool).
#' Analogous to rebuild_interview_survey() but operates on the counts slot.
#'
#' @param design A creel_design object with design$section_col set
#' @param section_name Character(1) — the section identifier to filter to
#'
#' @return Modified creel_design with counts and survey filtered to section_name
#'
#' @keywords internal
#' @noRd
rebuild_counts_survey <- function(design, section_name) {
  sec_col <- design[["section_col"]]
  filtered_counts <- design$counts[design$counts[[sec_col]] == section_name, ]
  design_new <- design
  design_new$counts <- filtered_counts
  design_new$survey <- construct_survey_design(design_new) # nolint: object_usage_linter
  design_new
}

#' Aggregate per-section estimates to a covariance-aware lake-wide total
#'
#' Internal helper: computes the lake-wide effort total using either
#' svyby(covmat=TRUE) + svycontrast() (method="correlated") or
#' Cochran 5.2 sqrt(sum(SE_h^2)) (method="independent").
#'
#' @param by_formula A formula for the section grouping variable (e.g. ~section)
#' @param full_design_svy A survey.design2 or svyrep.design built from the full design
#' @param count_formula A formula for the count variable (e.g. ~effort_hours)
#' @param method Character(1) — "correlated" or "independent"
#'
#' @return Named list with components:
#'   \item{estimate}{Numeric — lake-wide total estimate}
#'   \item{se}{Numeric — lake-wide total SE}
#'
#' @keywords internal
#' @noRd
aggregate_section_totals <- function(by_formula, full_design_svy, count_formula, method) {
  method <- match.arg(method, c("correlated", "independent"))
  if (method == "correlated") {
    by_result <- survey::svyby(
      formula = count_formula,
      by      = by_formula,
      design  = full_design_svy,
      FUN     = survey::svytotal,
      covmat  = TRUE
    )
    contrast_vec <- setNames(rep(1, nrow(by_result)), rownames(vcov(by_result)))
    lake_contrast <- survey::svycontrast(by_result, list(lake_total = contrast_vec))
    list(
      estimate = as.numeric(coef(lake_contrast)),
      se       = as.numeric(survey::SE(lake_contrast))
    )
  } else {
    # Cochran 5.2 — documented approximation for independent section designs
    by_result_ind <- survey::svyby(
      formula = count_formula,
      by      = by_formula,
      design  = full_design_svy,
      FUN     = survey::svytotal,
      covmat  = FALSE
    )
    section_ests <- as.numeric(coef(by_result_ind))
    section_ses <- as.numeric(survey::SE(by_result_ind))
    list(
      estimate = sum(section_ests),
      se       = sqrt(sum(section_ses^2))
    )
  }
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

#' Compute within-day variance contribution (Rasmussen 1998)
#'
#' Adds the within-day (sub-PSU) variance component to the between-day survey
#' variance. Called from estimate_effort_total() and estimate_effort_grouped()
#' when design$within_day_var is non-NULL.
#'
#' Formula (per stratum s):
#'   S2_within_s  = sum(SS_d) / (n_s * (K_bar_s - 1))
#'   V_within_s   = (N_s / K_bar_s) * S2_within_s
#'
#' where:
#'   n_s    = sampled days in stratum s
#'   N_s    = total available days in stratum s (from design$calendar)
#'   K_bar_s = mean counts per day in stratum s
#'   SS_d   = within-day sum of squared deviations for day d
#'
#' Source: Rasmussen, P.W., Staggs, M.D., Beard, T.D., and Newman, S.P. 1998.
#' Transactions of the American Fisheries Society 127(3):469-480.
#'
#' @param design A creel_design object with design$within_day_var populated
#' @param by_vars Character vector of grouping column names, or NULL for total
#'
#' @return Named numeric vector of within-day variance contributions (in total
#'   scale, matching svytotal() output). Names match group combinations when
#'   by_vars is not NULL. Returns 0 (or named zeros) when K_bar <= 1.
#'
#' @keywords internal
#' @noRd
compute_within_day_var_contribution <- function(design, by_vars = NULL) { # nolint: object_length_linter
  wdv <- design$within_day_var
  if (is.null(wdv)) {
    return(0)
  }

  counts_data <- design$counts
  strata_cols <- design$strata_cols

  # Get n_avail (available days per stratum) from design$calendar
  cal <- design$calendar
  if (length(strata_cols) == 1) {
    cal$.strata_key <- as.character(cal[[strata_cols]])
  } else {
    cal$.strata_key <- do.call(paste, c(cal[strata_cols], sep = "\u001f"))
  }
  available_by_strata <- table(cal$.strata_key)

  # Build a combined data frame: counts_data + within_day_var (joined by PSU key)
  key_cols <- unique(c(design$psu_col, strata_cols))
  combined <- merge(counts_data, wdv, by = key_cols, all.x = TRUE, sort = FALSE)

  # Days with k_d = 1 -> ss_d = 0 (VAR-03: within-day term is 0 for those days)
  combined$ss_d[is.na(combined$ss_d)] <- 0
  combined$k_d[is.na(combined$k_d)] <- 1L

  # VAR-03: emit informational message if mixed k_d
  mixed_days <- sum(combined$k_d == 1L)
  if (mixed_days > 0 && mixed_days < nrow(combined)) {
    cli::cli_inform(
      c(
        "i" = paste0(
          mixed_days,
          " day(s) had nC = 1 (single count); within-day variance set to 0 for those days."
        ),
        "i" = "Total variance includes within-day component only for days with nC >= 2 (VAR-03)."
      )
    )
  }

  # Create stratum key on combined data (matches cal$.strata_key)
  if (length(strata_cols) == 1) {
    combined$.strata_key <- as.character(combined[[strata_cols]])
  } else {
    combined$.strata_key <- do.call(paste, c(combined[strata_cols], sep = "\u001f"))
  }

  # Determine grouping: by_vars or strata alone
  if (is.null(by_vars)) {
    # Ungrouped: sum within-day variance across strata
    strata_keys <- unique(combined$.strata_key)
    v_within_total <- 0
    for (sk in strata_keys) {
      rows <- combined$.strata_key == sk
      n_sampled <- sum(rows)
      n_avail <- as.integer(available_by_strata[sk])
      k_d <- combined$k_d[rows]
      ss_d <- combined$ss_d[rows]
      k_bar <- mean(k_d)
      if (k_bar <= 1) next # no within-day component when k_bar = 1
      s2_within <- sum(ss_d) / (n_sampled * (k_bar - 1))
      v_within <- (n_avail / k_bar) * s2_within
      v_within_total <- v_within_total + v_within
    }
    v_within_total
  } else {
    # Grouped: return named vector matching svyby() row order
    if (length(by_vars) == 1) {
      combined$.group_key <- as.character(combined[[by_vars]])
    } else {
      combined$.group_key <- do.call(paste, c(combined[by_vars], sep = "\u001f"))
    }
    group_keys <- unique(combined$.group_key)
    v_within_by_group <- stats::setNames(
      numeric(length(group_keys)), group_keys
    )
    for (gk in group_keys) {
      g_rows <- combined$.group_key == gk
      g_data <- combined[g_rows, , drop = FALSE]
      strata_keys_g <- unique(g_data$.strata_key)
      v_g <- 0
      for (sk in strata_keys_g) {
        s_rows <- g_data$.strata_key == sk
        n_sampled <- sum(s_rows)
        n_avail <- as.integer(available_by_strata[sk])
        k_d <- g_data$k_d[s_rows]
        ss_d <- g_data$ss_d[s_rows]
        k_bar <- mean(k_d)
        if (k_bar <= 1) next
        s2_within <- sum(ss_d) / (n_sampled * (k_bar - 1))
        v_within <- (n_avail / k_bar) * s2_within
        v_g <- v_g + v_within
      }
      v_within_by_group[gk] <- v_g
    }
    v_within_by_group
  }
}

#' Build a target-aware survey design for effort estimation
#'
#' @param design A creel_design object with counts attached.
#' @param target Effort target: sampled_days, stratum_total, or period_total.
#'
#' @return A survey design object suitable for the requested effort target.
#'
#' @keywords internal
#' @noRd
get_effort_target_design <- function(design, target) {
  if (identical(target, "sampled_days")) {
    return(design$survey)
  }

  counts_data <- design$counts
  strata_cols <- design$strata_cols
  calendar <- design$calendar

  if (is.null(strata_cols) || length(strata_cols) == 0) {
    cli::cli_abort(c(
      "Expanded effort targets require stratified calendar information.",
      "x" = "The design has no registered strata columns.",
      "i" = "Use {.code target = 'sampled_days'} or create the design with {.arg strata}."
    ))
  }

  available_by_strata <- dplyr::count(calendar, dplyr::across(dplyr::all_of(strata_cols)), name = ".N_avail")
  sampled_by_strata <- dplyr::count(counts_data, dplyr::across(dplyr::all_of(strata_cols)), name = ".n_sampled")

  expanded_counts <- counts_data |>
    dplyr::left_join(available_by_strata, by = strata_cols) |>
    dplyr::left_join(sampled_by_strata, by = strata_cols)

  if (any(is.na(expanded_counts$.N_avail)) || any(is.na(expanded_counts$.n_sampled))) {
    cli::cli_abort(c(
      "Could not compute stratum expansion weights.",
      "x" = "Some count rows could not be matched to calendar strata.",
      "i" = "Check that count strata match the design calendar exactly."
    ))
  }

  if (any(expanded_counts$.n_sampled <= 0)) {
    cli::cli_abort(c(
      "Expanded effort targets require at least one sampled day in each observed stratum.",
      "x" = "Found strata with zero sampled days."
    ))
  }

  expanded_counts$.expansion_weight <- expanded_counts$.N_avail / expanded_counts$.n_sampled

  survey::svydesign(
    ids = stats::reformulate(design$psu_col),
    strata = stats::reformulate(strata_cols),
    weights = ~.expansion_weight,
    data = expanded_counts,
    nest = TRUE
  )
}

#' Per-section effort estimation orchestrator (Phase 39 logic)
#'
#' Dispatched from estimate_effort() when design$sections is non-NULL.
#' Loops over registered sections, calls rebuild_counts_survey() + estimate_effort_total()
#' per section, handles missing sections, aggregates to lake total via
#' aggregate_section_totals(), and returns a creel_estimates object.
#'
#' @param design A creel_design object with sections slot set by add_sections()
#' @param variance_method Character(1) — "taylor", "bootstrap", or "jackknife"
#' @param conf_level Numeric confidence level
#' @param aggregate_sections Logical — append .lake_total row?
#' @param method Character(1) — "correlated" or "independent"
#' @param missing_sections Character(1) — "warn" or "error"
#'
#' @return A creel_estimates S3 object with method = "total-sections"
#'
#' @keywords internal
#' @noRd
estimate_effort_sections <- function(design, variance_method, conf_level,
                                     aggregate_sections, method, missing_sections,
                                     target = "sampled_days") {
  # NULL guard (defensive; dispatch should prevent this firing)
  if (is.null(design[["sections"]])) {
    stop("sections dispatch called on non-section design")
  }

  section_col <- design[["section_col"]]
  registered_sections <- design$sections[[section_col]]
  present_sections <- unique(design$counts[[section_col]])
  absent_sections <- setdiff(registered_sections, present_sections)

  # Handle missing sections
  if (length(absent_sections) > 0) {
    n_absent <- length(absent_sections) # nolint: object_usage_linter
    if (missing_sections == "error") {
      cli::cli_abort(c(
        "{n_absent} missing section(s) in count data.",
        "x" = "Section(s) not found: {.val {absent_sections}}",
        "i" = "All registered sections must have count observations, or use {.arg missing_sections = 'warn'}."
      ))
    } else {
      cli::cli_warn(c(
        "{n_absent} missing section(s) in count data.",
        "!" = "Section(s) not found: {.val {absent_sections}}",
        "i" = "Inserting NA row(s) with {.field data_available = FALSE}."
      ))
    }
  }

  # Identify count variable (same logic as estimate_effort_total)
  counts_data <- design$counts
  excluded_cols <- c(design$date_col, design$strata_cols, design$psu_col, section_col)
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
  count_var <- count_vars[1]
  count_formula <- stats::reformulate(count_var)
  section_formula <- stats::reformulate(section_col)

  # Full-design survey for lake total denominator (prop_of_lake_total)
  full_svy_design <- get_variance_design(design$survey, variance_method) # nolint: object_usage_linter
  lake_total_svy <- wrap_survey_call(survey::svytotal(count_formula, full_svy_design))
  lake_total_est <- as.numeric(coef(lake_total_svy))

  # Loop over registered sections
  section_rows <- vector("list", length(registered_sections))
  names(section_rows) <- registered_sections

  for (sec in registered_sections) {
    if (sec %in% absent_sections) {
      # Build NA row for missing section
      section_rows[[sec]] <- tibble::tibble(
        section = sec,
        estimate = NA_real_,
        se = NA_real_,
        se_between = NA_real_,
        se_within = NA_real_,
        ci_lower = NA_real_,
        ci_upper = NA_real_,
        n = 0L,
        prop_of_lake_total = NA_real_,
        data_available = FALSE
      )
    } else {
      # Build filtered section design and estimate
      sec_design <- suppressWarnings(rebuild_counts_survey(design, sec)) # nolint: object_usage_linter
      sec_result <- estimate_effort_total(sec_design, variance_method, conf_level) # nolint: object_usage_linter
      row <- sec_result$estimates
      prop <- row$estimate / lake_total_est
      section_rows[[sec]] <- tibble::tibble(
        section = sec,
        estimate = row$estimate,
        se = row$se,
        se_between = row$se_between,
        se_within = row$se_within,
        ci_lower = row$ci_lower,
        ci_upper = row$ci_upper,
        n = row$n,
        prop_of_lake_total = prop,
        data_available = TRUE
      )
    }
  }

  # Combine section rows
  result_df <- dplyr::bind_rows(section_rows)

  # Append .lake_total row if requested
  if (aggregate_sections) {
    # Use only present sections for aggregation
    present_design_svy <- full_svy_design
    # Filter to present sections only for the section formula (absent sections skipped)
    agg <- suppressWarnings(aggregate_section_totals( # nolint: object_usage_linter
      by_formula      = section_formula,
      full_design_svy = present_design_svy,
      count_formula   = count_formula,
      method          = method
    ))
    lake_est <- agg$estimate
    lake_se <- agg$se

    # CI for lake total using full-design df
    df <- as.numeric(survey::degf(full_svy_design))
    alpha <- 1 - conf_level
    t_crit <- qt(1 - alpha / 2, df = df)
    lake_ci_lower <- lake_est - t_crit * lake_se
    lake_ci_upper <- lake_est + t_crit * lake_se

    lake_row <- tibble::tibble(
      section = ".lake_total",
      estimate = lake_est,
      se = lake_se,
      se_between = NA_real_,
      se_within = NA_real_,
      ci_lower = lake_ci_lower,
      ci_upper = lake_ci_upper,
      n = nrow(design$counts),
      prop_of_lake_total = 1.0,
      data_available = TRUE
    )
    result_df <- dplyr::bind_rows(result_df, lake_row)
  }

  # Return creel_estimates object
  new_creel_estimates( # nolint: object_usage_linter
    estimates = result_df,
    method = "total-sections",
    variance_method = variance_method,
    design = design,
    conf_level = conf_level,
    by_vars = NULL,
    effort_target = target
  )
}

#' Ungrouped total estimation (Phase 4 logic)
#'
#' @keywords internal
#' @noRd
estimate_effort_total <- function(design, variance_method, conf_level, target = "sampled_days") {
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

  # Warn (not abort) if all count values are NA — result will be NA
  if (all(is.na(counts_data[[count_var]]))) {
    cli::cli_warn(c(
      "All values in count column {.field {count_var}} are {.val NA}.",
      "i" = "The effort estimate will be {.val NA}.",
      "i" = paste0(
        "Check that counts were attached correctly via ",
        "{.fn add_counts}."
      )
    ))
  }

  # Create formula
  count_formula <- stats::reformulate(count_var)

  # Get appropriate survey design for variance method and target
  target_design <- get_effort_target_design(design, target) # nolint: object_usage_linter
  svy_design <- get_variance_design(target_design, variance_method) # nolint: object_usage_linter

  # Call survey::svytotal (suppress expected survey package warnings)
  svy_result <- wrap_survey_call(survey::svytotal(count_formula, svy_design))
  estimate <- as.numeric(coef(svy_result))

  # Between-day variance (from survey package)
  var_between <- as.numeric(survey::SE(svy_result))^2
  se_between <- sqrt(var_between)

  # Detect degenerate bootstrap replicate design (single-PSU strata)
  if (is.nan(se_between) && variance_method == "bootstrap") {
    cli::cli_abort(
      c(
        paste0(
          "Bootstrap variance is {.val NaN} \u2014 one or more strata have ",
          "only 1 PSU."
        ),
        "x" = paste0(
          "Bootstrap resampling requires at least 2 PSUs ",
          "(sampled days) per stratum."
        ),
        "i" = paste0(
          "Increase the sampling rate or use ",
          "{.code variance = 'taylor'} for single-PSU strata."
        )
      ),
      class = "creel_error_single_psu"
    )
  }

  # Within-day variance contribution (Rasmussen 1998; 0 when K_bar = 1)
  var_within <- compute_within_day_var_contribution(design, by_vars = NULL) # nolint: object_usage_linter
  se_within <- sqrt(var_within)

  # Combined SE and CI (recomputed from total variance)
  total_var <- var_between + var_within
  se <- sqrt(total_var)

  # Degrees of freedom: use survey package df (Taylor series linearization)
  df <- as.numeric(survey::degf(svy_design))
  alpha <- 1 - conf_level
  t_crit <- qt(1 - alpha / 2, df = df)
  ci_lower <- estimate - t_crit * se
  ci_upper <- estimate + t_crit * se

  n <- nrow(counts_data)

  # Build estimates tibble
  estimates_df <- tibble::tibble(
    estimate = estimate,
    se = se,
    se_between = se_between,
    se_within = se_within,
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
    by_vars = NULL,
    effort_target = target
  )
}

#' Grouped total estimation using svyby (Phase 5 logic)
#'
#' @keywords internal
#' @noRd
estimate_effort_grouped <- function(design, by_vars, variance_method, conf_level, target = "sampled_days") {
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

  # Get appropriate survey design for variance method and target
  target_design <- get_effort_target_design(design, target) # nolint: object_usage_linter
  svy_design <- get_variance_design(target_design, variance_method) # nolint: object_usage_linter

  # Call survey::svyby (suppress expected survey package warnings)
  svy_result <- wrap_survey_call(survey::svyby(
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

  # Between-day variance per group (from svyby "se" column)
  se_between_vec <- svy_result[["se"]]
  var_between_vec <- se_between_vec^2

  # Within-day variance per group (Rasmussen 1998; named vector keyed by group)
  var_within_named <- compute_within_day_var_contribution(design, by_vars = by_vars) # nolint: object_usage_linter

  # Build group keys for the svyby result rows to match var_within_named names
  if (length(by_vars) == 1) {
    result_group_keys <- as.character(svy_result[[by_vars]])
  } else {
    result_group_keys <- do.call(paste, c(svy_result[by_vars], sep = "\u001f"))
  }

  # Match within-day variance to svyby row order
  if (length(var_within_named) >= 1 && !is.null(names(var_within_named))) {
    var_within_vec <- as.numeric(var_within_named[result_group_keys])
  } else {
    var_within_vec <- rep(as.numeric(var_within_named), length(estimate))
  }
  var_within_vec[is.na(var_within_vec)] <- 0

  # Combined SE per group
  total_var_vec <- var_between_vec + var_within_vec
  se <- sqrt(total_var_vec)
  se_between <- se_between_vec
  se_within <- sqrt(var_within_vec)

  # Recompute CI from combined variance (not from svyby ci_l/ci_u)
  df_val <- as.numeric(survey::degf(svy_design))
  alpha <- 1 - conf_level
  t_crit <- qt(1 - alpha / 2, df = df_val)
  ci_lower <- estimate - t_crit * se
  ci_upper <- estimate + t_crit * se

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
  estimates_df$se_between <- se_between
  estimates_df$se_within <- se_within
  estimates_df$ci_lower <- ci_lower
  estimates_df$ci_upper <- ci_upper

  # Join sample sizes
  estimates_df <- merge(estimates_df, n_by_group, by = by_vars, all.x = TRUE, sort = FALSE)

  # Convert to tibble and reorder columns (group cols, then estimate cols, then n)
  estimates_df <- tibble::as_tibble(estimates_df)
  col_order <- c(by_vars, "estimate", "se", "se_between", "se_within", "ci_lower", "ci_upper", "n")
  estimates_df <- estimates_df[col_order]

  # Return creel_estimates object
  new_creel_estimates( # nolint: object_usage_linter
    estimates = estimates_df,
    method = "total",
    variance_method = variance_method,
    design = design,
    conf_level = conf_level,
    by_vars = by_vars,
    effort_target = target
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
  if (estimator %in% c("mor", "mortr")) {
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

    method_name <- if (estimator == "mortr") {
      "mean-of-ratios-truncated-cpue"
    } else {
      "mean-of-ratios-cpue"
    }
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
  if (estimator %in% c("mor", "mortr")) {
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
  if (estimator %in% c("mor", "mortr")) {
    # Mean-of-ratios: add ratio column
    interviews_data$cpue_ratio <- interviews_data[[catch_col]] / interviews_data[[effort_col]]
    method_name <- if (estimator == "mortr") {
      "mean-of-ratios-truncated-cpue"
    } else {
      "mean-of-ratios-cpue"
    }
  } else {
    method_name <- "ratio-of-means-cpue"
  }

  # Build temporary survey design from filtered data (or with ratio column for MOR)
  if (any(zero_effort) || estimator %in% c("mor", "mortr")) {
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

  if (estimator %in% c("mor", "mortr")) {
    # MOR: use svyby with svymean on ratio
    svy_result <- wrap_survey_call(survey::svyby(
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

    svy_result <- wrap_survey_call(survey::svyby(
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
  if (estimator %in% c("mor", "mortr")) {
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

#' Warn when effort strata have no matching species-rate rows
#'
#' Species/product totals are computed from stratum-level effort × rate products.
#' If the rate table lacks one or more effort strata, the merge in
#' `compute_stratum_product_sum()` drops those strata and the resulting total is
#' necessarily conditioned on the covered strata only. That may be the intended
#' estimator behavior, but it should not happen silently.
#'
#' @param effort_df Tibble of per-stratum effort estimates.
#' @param rate_df Tibble of per-stratum rate estimates.
#' @param stratum_by_vars Character vector of join columns.
#' @param context Short human-readable label for the warning.
#'
#' @keywords internal
#' @noRd
warn_missing_rate_strata <- function(effort_df, rate_df, stratum_by_vars, context) {
  if (length(stratum_by_vars) == 0L) {
    return(invisible(NULL))
  }

  effort_keys <- unique(effort_df[, c(stratum_by_vars, "estimate"), drop = FALSE])
  rate_keys <- unique(rate_df[, stratum_by_vars, drop = FALSE])

  missing_rate <- dplyr::anti_join(effort_keys, rate_keys, by = stratum_by_vars)
  if (nrow(missing_rate) == 0L) {
    return(invisible(NULL))
  }

  omitted_effort <- sum(missing_rate$estimate, na.rm = TRUE)
  total_effort <- sum(effort_df$estimate, na.rm = TRUE)
  omitted_pct_text <- if (is.finite(total_effort) && total_effort > 0) {
    paste0(format(round(100 * omitted_effort / total_effort, 1), trim = TRUE), "%")
  } else {
    "NA%"
  }

  cli::cli_warn(c(
    "Missing rate strata detected during {.val {context}} aggregation.",
    "!" = paste(
      nrow(missing_rate),
      "effort stratum row(s) had no matching rate estimate and will be excluded from the product sum."
    ),
    "i" = paste(
      "Excluded effort total:",
      format(round(omitted_effort, 3), trim = TRUE),
      paste0("(", omitted_pct_text, " of grouped effort).")
    ),
    "i" = paste(
      "This usually means count strata were observed without corresponding",
      "interview coverage for the requested grouping."
    )
  ))

  invisible(NULL)
}

#' Stratum-sum product helper for species total estimators
#'
#' Merges per-stratum effort and rate estimates, computes delta-method products
#' per stratum, then sums across strata within `interview_by_vars` groups.
#' When `stratum_by_vars` is empty (no strata, no grouping), applies simple
#' ungrouped delta method.
#'
#' @param effort_df Tibble from estimate_effort_total / estimate_effort_grouped.
#' @param rate_df Tibble from estimate_cpue/hpue/release species (species col removed).
#' @param stratum_by_vars Character vector of strata + interview grouping columns.
#' @param interview_by_vars Character vector of user grouping columns (subset of stratum_by_vars).
#' @param conf_level Numeric confidence level.
#' @param rate_suffix Character suffix for rate columns after merge ("cpue", "hpue", "rpue").
#'
#' @return data.frame with columns: [interview_by_vars...], estimate, se, ci_lower, ci_upper, n
#'
#' @keywords internal
#' @noRd
compute_stratum_product_sum <- function(effort_df, rate_df, stratum_by_vars,
                                        interview_by_vars, conf_level,
                                        rate_suffix = "rate") {
  z <- stats::qnorm(1 - (1 - conf_level) / 2)

  if (length(stratum_by_vars) == 0L) {
    # No strata, no grouping: simple delta method on single estimates
    e_est <- effort_df$estimate
    r_est <- rate_df$estimate
    e_se <- effort_df$se
    r_se <- rate_df$se
    est <- e_est * r_est
    pv <- (e_est^2 * r_se^2) + (r_est^2 * e_se^2)
    return(data.frame(
      estimate = est, se = sqrt(pv),
      ci_lower = est - z * sqrt(pv), ci_upper = est + z * sqrt(pv),
      n = rate_df$n, stringsAsFactors = FALSE
    ))
  }

  # Merge per-stratum effort and rate on stratum_by_vars
  merged <- merge(
    effort_df, rate_df,
    by = stratum_by_vars,
    suffixes = c("_effort", paste0("_", rate_suffix)),
    sort = FALSE
  )

  e_col <- "estimate_effort"
  r_col <- paste0("estimate_", rate_suffix)
  se_e <- "se_effort"
  se_r <- paste0("se_", rate_suffix)
  n_r <- paste0("n_", rate_suffix)

  # Per-stratum delta-method products and variances
  merged$.est_sh <- merged[[e_col]] * merged[[r_col]]
  merged$.var_sh <- (merged[[e_col]]^2 * merged[[se_r]]^2) +
    (merged[[r_col]]^2 * merged[[se_e]]^2)
  merged$.n_sh <- merged[[n_r]]

  if (is.null(interview_by_vars)) {
    # Sum all strata to a single total
    est <- sum(merged$.est_sh)
    pv <- sum(merged$.var_sh)
    n <- sum(merged$.n_sh)
    data.frame(
      estimate = est, se = sqrt(pv),
      ci_lower = est - z * sqrt(pv), ci_upper = est + z * sqrt(pv),
      n = as.integer(n), stringsAsFactors = FALSE
    )
  } else {
    # Sum strata within each interview_by_vars group
    agg <- stats::aggregate(
      cbind(.est_sh, .var_sh, .n_sh) ~ .,
      data = merged[c(interview_by_vars, ".est_sh", ".var_sh", ".n_sh")],
      FUN  = sum
    )
    sp_result <- tibble::as_tibble(agg[interview_by_vars])
    sp_result$estimate <- agg$.est_sh
    sp_result$se <- sqrt(agg$.var_sh)
    sp_result$ci_lower <- sp_result$estimate - z * sp_result$se
    sp_result$ci_upper <- sp_result$estimate + z * sp_result$se
    sp_result$n <- as.integer(agg$.n_sh)
    sp_result
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
                                  estimator = "ratio-of-means",
                                  validate = TRUE) {
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

    if (validate) {
      validate_ratio_sample_size(design_sp, interview_by_vars, type = "cpue") # nolint: object_usage_linter
    }

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
                                          validate = TRUE) {
  all_species <- sort(unique(design[["catch"]][[species_col]]))

  results_list <- vector("list", length(all_species))

  for (i in seq_along(all_species)) {
    sp <- all_species[[i]]

    # Build per-species release interview data (zero-filled)
    sp_data <- estimate_release_build_data(design, species = sp) # nolint: object_usage_linter

    sp_data$.release_effort <- sp_data[[design$angler_effort_col]]

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

    if (validate) {
      validate_ratio_sample_size(design_sp, interview_by_vars, type = "cpue") # nolint: object_usage_linter
    }

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
                                  variance_method, conf_level,
                                  validate = TRUE) {
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

    if (validate) {
      validate_ratio_sample_size(design_sp, interview_by_vars, type = "harvest") # nolint: object_usage_linter
    }

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
  svy_result <- wrap_survey_call(survey::svyby(
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

# Section dispatch helpers for rate estimators ----

#' Per-section catch rate (CPUE) estimation
#'
#' @keywords internal
#' @noRd
estimate_catch_rate_sections <- function(design, by_quo, variance_method, # nolint: object_length_linter
                                         conf_level, missing_sections,
                                         estimator) {
  section_col <- design[["section_col"]]
  registered_sections <- design$sections[[section_col]]
  present_sections <- unique(design$interviews[[section_col]])
  absent_sections <- setdiff(registered_sections, present_sections)

  # Handle missing sections
  if (length(absent_sections) > 0) {
    n_absent <- length(absent_sections) # nolint: object_usage_linter
    if (missing_sections == "error") {
      cli::cli_abort(c(
        "{n_absent} missing section(s) in interview data.",
        "x" = "Section(s) not found: {.val {absent_sections}}",
        "i" = "All registered sections must have interview data, or use {.arg missing_sections = 'warn'}."
      ))
    } else {
      cli::cli_warn(c(
        "{n_absent} missing section(s) in interview data.",
        "!" = "Section(s) not found: {.val {absent_sections}}",
        "i" = "Inserting NA row(s) with {.field data_available = FALSE}."
      ))
    }
  }

  # Resolve by= ONCE before the section loop
  by_info <- resolve_species_by(by_quo, design) # nolint: object_usage_linter

  section_rows <- vector("list", length(registered_sections))
  names(section_rows) <- registered_sections

  for (sec in registered_sections) {
    if (sec %in% absent_sections) {
      # Build NA row — include by= columns set to NA if present
      na_row <- tibble::tibble(
        section        = sec,
        estimate       = NA_real_,
        se             = NA_real_,
        ci_lower       = NA_real_,
        ci_upper       = NA_real_,
        n              = 0L,
        data_available = FALSE
      )
      if (!is.null(by_info$all_vars)) {
        for (v in by_info$all_vars) {
          na_row[[v]] <- NA_character_
        }
      }
      section_rows[[sec]] <- na_row
    } else {
      # Filter interviews to this section and rebuild survey
      filtered <- design$interviews[design$interviews[[section_col]] == sec, ]
      sec_design <- rebuild_interview_survey(design, filtered) # nolint: object_usage_linter

      if (!is.null(by_info$species_var)) {
        # Species by= path
        sp_df <- estimate_cpue_species( # nolint: object_usage_linter
          sec_design,
          species_col       = by_info$species_var,
          interview_by_vars = by_info$interview_vars,
          variance_method   = variance_method,
          conf_level        = conf_level,
          estimator         = estimator
        )
        sp_df <- tibble::add_column(tibble::as_tibble(sp_df), section = sec, .before = 1)
        sp_df$data_available <- TRUE
        section_rows[[sec]] <- sp_df
      } else if (!is.null(by_info$interview_vars)) {
        # Grouped (non-species) by= path
        result <- estimate_cpue_grouped( # nolint: object_usage_linter
          sec_design,
          by_vars         = by_info$interview_vars,
          variance_method = variance_method,
          conf_level      = conf_level,
          estimator       = estimator
        )
        row_df <- tibble::add_column(result$estimates, section = sec, .before = 1)
        row_df$data_available <- TRUE
        section_rows[[sec]] <- row_df
      } else {
        # Ungrouped (total) path
        result <- estimate_cpue_total( # nolint: object_usage_linter
          sec_design, variance_method, conf_level, estimator
        )
        row <- result$estimates
        section_rows[[sec]] <- tibble::tibble(
          section        = sec,
          estimate       = row$estimate,
          se             = row$se,
          ci_lower       = row$ci_lower,
          ci_upper       = row$ci_upper,
          n              = row$n,
          data_available = TRUE
        )
      }
    }
  }

  result_df <- dplyr::bind_rows(section_rows)

  new_creel_estimates( # nolint: object_usage_linter
    estimates       = result_df,
    method          = "ratio-of-means-cpue-sections",
    variance_method = variance_method,
    design          = design,
    conf_level      = conf_level,
    by_vars         = if (!is.null(by_info$all_vars)) c("section", by_info$all_vars) else "section"
  )
}

#' Per-section harvest rate (HPUE) estimation
#'
#' @keywords internal
#' @noRd
estimate_harvest_rate_sections <- function(design, by_quo, variance_method, # nolint: object_length_linter
                                           conf_level, missing_sections) {
  section_col <- design[["section_col"]]
  registered_sections <- design$sections[[section_col]]
  present_sections <- unique(design$interviews[[section_col]])
  absent_sections <- setdiff(registered_sections, present_sections)

  # Handle missing sections
  if (length(absent_sections) > 0) {
    n_absent <- length(absent_sections) # nolint: object_usage_linter
    if (missing_sections == "error") {
      cli::cli_abort(c(
        "{n_absent} missing section(s) in interview data.",
        "x" = "Section(s) not found: {.val {absent_sections}}",
        "i" = "All registered sections must have interview data, or use {.arg missing_sections = 'warn'}."
      ))
    } else {
      cli::cli_warn(c(
        "{n_absent} missing section(s) in interview data.",
        "!" = "Section(s) not found: {.val {absent_sections}}",
        "i" = "Inserting NA row(s) with {.field data_available = FALSE}."
      ))
    }
  }

  # Resolve by= ONCE before the section loop (no species dispatch for harvest in v0.7.0)
  if (rlang::quo_is_null(by_quo)) {
    by_vars <- NULL
  } else {
    by_cols <- tidyselect::eval_select(
      by_quo,
      data = design$interviews,
      allow_rename = FALSE,
      allow_empty = FALSE,
      error_call = rlang::caller_env()
    )
    by_vars <- names(by_cols)
  }

  section_rows <- vector("list", length(registered_sections))
  names(section_rows) <- registered_sections

  for (sec in registered_sections) {
    if (sec %in% absent_sections) {
      na_row <- tibble::tibble(
        section        = sec,
        estimate       = NA_real_,
        se             = NA_real_,
        ci_lower       = NA_real_,
        ci_upper       = NA_real_,
        n              = 0L,
        data_available = FALSE
      )
      if (!is.null(by_vars)) {
        for (v in by_vars) {
          na_row[[v]] <- NA_character_
        }
      }
      section_rows[[sec]] <- na_row
    } else {
      filtered <- design$interviews[design$interviews[[section_col]] == sec, ]
      sec_design <- rebuild_interview_survey(design, filtered) # nolint: object_usage_linter

      if (!is.null(by_vars)) {
        result <- estimate_harvest_grouped( # nolint: object_usage_linter
          sec_design, by_vars, variance_method, conf_level
        )
        row_df <- tibble::add_column(result$estimates, section = sec, .before = 1)
        row_df$data_available <- TRUE
        section_rows[[sec]] <- row_df
      } else {
        result <- estimate_harvest_total( # nolint: object_usage_linter
          sec_design, variance_method, conf_level
        )
        row <- result$estimates
        section_rows[[sec]] <- tibble::tibble(
          section        = sec,
          estimate       = row$estimate,
          se             = row$se,
          ci_lower       = row$ci_lower,
          ci_upper       = row$ci_upper,
          n              = row$n,
          data_available = TRUE
        )
      }
    }
  }

  result_df <- dplyr::bind_rows(section_rows)

  new_creel_estimates( # nolint: object_usage_linter
    estimates       = result_df,
    method          = "ratio-of-means-hpue-sections",
    variance_method = variance_method,
    design          = design,
    conf_level      = conf_level,
    by_vars         = if (!is.null(by_vars)) c("section", by_vars) else "section"
  )
}

#' Per-section release rate (RPUE) estimation
#'
#' @keywords internal
#' @noRd
estimate_release_rate_sections <- function(design, by_quo, variance_method, # nolint: object_length_linter
                                           conf_level, missing_sections) {
  section_col <- design[["section_col"]]
  registered_sections <- design$sections[[section_col]]
  present_sections <- unique(design$interviews[[section_col]])
  absent_sections <- setdiff(registered_sections, present_sections)

  # Handle missing sections
  if (length(absent_sections) > 0) {
    n_absent <- length(absent_sections) # nolint: object_usage_linter
    if (missing_sections == "error") {
      cli::cli_abort(c(
        "{n_absent} missing section(s) in interview data.",
        "x" = "Section(s) not found: {.val {absent_sections}}",
        "i" = "All registered sections must have interview data, or use {.arg missing_sections = 'warn'}."
      ))
    } else {
      cli::cli_warn(c(
        "{n_absent} missing section(s) in interview data.",
        "!" = "Section(s) not found: {.val {absent_sections}}",
        "i" = "Inserting NA row(s) with {.field data_available = FALSE}."
      ))
    }
  }

  # Resolve by= ONCE before the section loop (no species dispatch for release in v0.7.0)
  if (rlang::quo_is_null(by_quo)) {
    by_vars <- NULL
  } else {
    by_cols <- tidyselect::eval_select(
      by_quo,
      data = design$interviews,
      allow_rename = FALSE,
      allow_empty = FALSE,
      error_call = rlang::caller_env()
    )
    by_vars <- names(by_cols)
  }

  section_rows <- vector("list", length(registered_sections))
  names(section_rows) <- registered_sections

  for (sec in registered_sections) {
    if (sec %in% absent_sections) {
      na_row <- tibble::tibble(
        section        = sec,
        estimate       = NA_real_,
        se             = NA_real_,
        ci_lower       = NA_real_,
        ci_upper       = NA_real_,
        n              = 0L,
        data_available = FALSE
      )
      if (!is.null(by_vars)) {
        for (v in by_vars) {
          na_row[[v]] <- NA_character_
        }
      }
      section_rows[[sec]] <- na_row
    } else {
      filtered <- design$interviews[design$interviews[[section_col]] == sec, ]
      sec_design <- rebuild_interview_survey(design, filtered) # nolint: object_usage_linter

      # Build release data for this section's filtered design
      release_data <- estimate_release_build_data(sec_design, species = NULL) # nolint: object_usage_linter
      release_data$.release_effort <- release_data[[sec_design$angler_effort_col]]

      design_rel <- sec_design
      design_rel$interviews <- release_data
      design_rel$catch_col <- ".release_count"
      design_rel$angler_effort_col <- ".release_effort"

      strata_cols <- sec_design$strata_cols
      strata_formula <- if (!is.null(strata_cols) && length(strata_cols) > 0L) {
        stats::reformulate(strata_cols)
      } else {
        NULL
      }
      design_rel$interview_survey <- build_interview_survey( # nolint: object_usage_linter
        release_data,
        strata = strata_formula
      )

      if (!is.null(by_vars)) {
        result <- estimate_cpue_grouped( # nolint: object_usage_linter
          design_rel, by_vars, variance_method, conf_level
        )
        row_df <- tibble::add_column(result$estimates, section = sec, .before = 1)
        row_df$data_available <- TRUE
        section_rows[[sec]] <- row_df
      } else {
        result <- estimate_cpue_total(design_rel, variance_method, conf_level) # nolint: object_usage_linter
        row <- result$estimates
        section_rows[[sec]] <- tibble::tibble(
          section        = sec,
          estimate       = row$estimate,
          se             = row$se,
          ci_lower       = row$ci_lower,
          ci_upper       = row$ci_upper,
          n              = row$n,
          data_available = TRUE
        )
      }
    }
  }

  result_df <- dplyr::bind_rows(section_rows)

  new_creel_estimates( # nolint: object_usage_linter
    estimates       = result_df,
    method          = "ratio-of-means-rpue-sections",
    variance_method = variance_method,
    design          = design,
    conf_level      = conf_level,
    by_vars         = if (!is.null(by_vars)) c("section", by_vars) else "section"
  )
}
