#' Core Variance Calculation Engine for tidycreel
#'
#' Single source of truth for ALL variance calculations in tidycreel estimators.
#' This engine handles all variance estimation methods through a unified interface.
#'
#' @name variance-engine
NULL

#' Compute Variance Using Survey Package Methods
#'
#' Core variance calculation engine that ALL tidycreel estimators use.
#' Provides unified interface to multiple variance estimation methods.
#'
#' @param design Survey design object (svydesign or svrepdesign)
#' @param response Response variable (formula or character)
#' @param method Variance estimation method:
#'   \describe{
#'     \item{"survey"}{Standard survey package variance (default)}
#'     \item{"svyrecvar"}{survey:::svyrecvar internals (most accurate)}
#'     \item{"bootstrap"}{Bootstrap resampling variance}
#'     \item{"jackknife"}{Jackknife resampling variance}
#'     \item{"linearization"}{Taylor linearization (same as "survey")}
#'   }
#' @param by Optional grouping variables for stratified estimation
#' @param conf_level Confidence level for intervals (default 0.95)
#' @param n_replicates Number of replicates for bootstrap/jackknife (default 1000)
#' @param calculate_deff Whether to calculate design effects (default TRUE)
#'
#' @return List with variance estimation results:
#'   \describe{
#'     \item{estimate}{Point estimate(s)}
#'     \item{variance}{Variance estimate(s)}
#'     \item{se}{Standard error(s)}
#'     \item{ci_lower}{Lower confidence limit(s)}
#'     \item{ci_upper}{Upper confidence limit(s)}
#'     \item{deff}{Design effect(s) (if calculate_deff = TRUE)}
#'     \item{method}{Variance method used}
#'     \item{method_details}{Additional method-specific information}
#'     \item{conf_level}{Confidence level used}
#'   }
#'
#' @details
#' This is the core variance calculation function used by ALL tidycreel estimators.
#' It provides a unified interface to multiple variance estimation approaches:
#'
#' **Standard Methods:**
#' - `"survey"`: Uses survey package public API (svymean, svytotal, svyby)
#' - `"linearization"`: Alias for "survey" (Taylor linearization is the default)
#'
#' **Survey Package Internals:**
#' - `"svyrecvar"`: Direct access to survey:::svyrecvar for maximum accuracy
#'
#' **Resampling Methods:**
#' - `"bootstrap"`: Bootstrap variance estimation with replicate weights
#' - `"jackknife"`: Jackknife variance estimation
#'
#' **Design Effects:**
#' When `calculate_deff = TRUE`, the function computes design effects (DEFF)
#' which measure the impact of the survey design on variance compared to
#' simple random sampling. DEFF values > 1 indicate design effects from
#' clustering, stratification, or weighting.
#'
#' @examples
#' \dontrun{
#' library(survey)
#' library(tidycreel)
#'
#' # Create survey design
#' design <- svydesign(ids = ~1, data = creel_counts, weights = ~1)
#'
#' # Standard variance
#' var_result <- tc_compute_variance(design, "anglers_count")
#'
#' # Bootstrap variance
#' var_boot <- tc_compute_variance(
#'   design,
#'   "anglers_count",
#'   method = "bootstrap",
#'   n_replicates = 2000
#' )
#'
#' # Survey internals (most accurate)
#' var_internals <- tc_compute_variance(
#'   design,
#'   "anglers_count",
#'   method = "svyrecvar"
#' )
#'
#' # Grouped estimation
#' var_by_strata <- tc_compute_variance(
#'   design,
#'   "anglers_count",
#'   by = "stratum"
#' )
#' }
#'
#' @keywords internal
#' @export
tc_compute_variance <- function(design,
                                response,
                                method = "survey",
                                by = NULL,
                                conf_level = 0.95,
                                n_replicates = 1000,
                                calculate_deff = TRUE) {

  # Validate inputs
  if (!inherits(design, c("survey.design", "survey.design2", "svyrep.design"))) {
    cli::cli_abort("{.arg design} must be a survey design object")
  }

  valid_methods <- c("survey", "svyrecvar", "bootstrap", "jackknife", "linearization")
  method <- match.arg(method, valid_methods)

  # Linearization is an alias for survey (it's the default method)
  if (method == "linearization") {
    method <- "survey"
  }

  # Convert response to formula if needed
  if (is.character(response)) {
    response_formula <- as.formula(paste("~", response))
    response_var <- response
  } else if (inherits(response, "formula")) {
    response_formula <- response
    response_var <- all.vars(response)[1]
  } else {
    cli::cli_abort("{.arg response} must be character or formula")
  }

  # Validate response exists in design
  if (!response_var %in% names(design$variables)) {
    cli::cli_abort(
      "Response variable {.val {response_var}} not found in design",
      "i" = "Available variables: {.val {names(design$variables)}}"
    )
  }

  # Validate grouping variables and check for empty groups
  if (!is.null(by) && length(by) > 0) {
    missing_by <- setdiff(by, names(design$variables))
    if (length(missing_by) > 0) {
      cli::cli_abort(c(
        "x" = "Grouping variable(s) not found in design: {.val {missing_by}}",
        "i" = "Available variables: {.val {names(design$variables)}}"
      ))
    }

    # Check for empty groups
    group_counts <- design$variables |>
      dplyr::group_by(dplyr::across(dplyr::all_of(by))) |>
      dplyr::summarise(.n = dplyr::n(), .groups = "drop")

    empty_groups <- group_counts |> dplyr::filter(.data$.n == 0)
    if (nrow(empty_groups) > 0) {
      cli::cli_warn(c(
        "!" = "Empty groups detected in grouping variables",
        "i" = "These groups will be excluded from estimates"
      ))
    }

    # Check for very small groups (n < 3)
    small_groups <- group_counts |> dplyr::filter(.data$.n < 3)
    if (nrow(small_groups) > 0) {
      cli::cli_warn(c(
        "!" = "{nrow(small_groups)} group(s) have fewer than 3 observations",
        "i" = "Variance estimates may be unstable for these groups"
      ))
    }
  }

  # Dispatch to appropriate method
  result <- switch(method,
    "survey" = .tc_variance_survey(
      design, response_formula, by, conf_level, calculate_deff
    ),
    "svyrecvar" = .tc_variance_svyrecvar(
      design, response_formula, response_var, by, conf_level, calculate_deff
    ),
    "bootstrap" = .tc_variance_bootstrap(
      design, response_formula, by, conf_level, n_replicates, calculate_deff
    ),
    "jackknife" = .tc_variance_jackknife(
      design, response_formula, by, conf_level, calculate_deff
    )
  )

  # Add method metadata
  # Use actual method from result if fallback occurred, otherwise use requested
  actual_method <- result$method %||% method
  result$method <- actual_method
  result$requested_method <- method  # Track what user requested
  result$conf_level <- conf_level
  result$response_variable <- response_var

  return(result)
}

# Internal variance calculation methods ----

#' Standard Survey Package Variance
#'
#' Uses survey package public API for variance estimation.
#'
#' @keywords internal
#' @noRd
.tc_variance_survey <- function(design, response_formula, by, conf_level, calculate_deff) {

  # Calculate estimates
  if (is.null(by)) {
    # Overall estimate
    est <- survey::svymean(response_formula, design, na.rm = TRUE)
    estimate <- as.numeric(est)
    se <- as.numeric(survey::SE(est))
    variance <- se^2

    # Design effects
    deff <- if (calculate_deff) {
      tryCatch(
        as.numeric(survey::deff(est)),
        error = function(e) NA_real_
      )
    } else {
      NA_real_
    }

  } else {
    # Grouped estimates
    by_formula <- as.formula(paste("~", paste(by, collapse = " + ")))
    est <- survey::svyby(
      response_formula,
      by_formula,
      design,
      survey::svymean,
      na.rm = TRUE
    )

    estimate <- est[[ncol(est) - 1]]
    se <- est[[ncol(est)]]
    variance <- se^2

    # Design effects for grouped estimates
    deff <- if (calculate_deff) {
      tryCatch(
        as.numeric(survey::deff(est)),
        error = function(e) rep(NA_real_, length(estimate))
      )
    } else {
      rep(NA_real_, length(estimate))
    }

    # Extract grouping variables from result
    # survey::svyby returns grouping vars in first columns
    group_data <- est[, seq_along(by), drop = FALSE]
  }

  # Confidence intervals
  alpha <- 1 - conf_level
  z_score <- qnorm(1 - alpha / 2)
  ci_lower <- estimate - z_score * se
  ci_upper <- estimate + z_score * se

  result <- list(
    estimate = estimate,
    variance = variance,
    se = se,
    ci_lower = ci_lower,
    ci_upper = ci_upper,
    deff = deff,
    method_details = list(
      survey_function = if (is.null(by)) "svymean" else "svyby"
    )
  )

  # Add grouping data if available
  if (!is.null(by) && length(by) > 0) {
    result$group_data <- group_data
  }

  result
}

#' Survey Package Internals Variance (svyrecvar)
#'
#' Direct access to survey:::svyrecvar for maximum accuracy.
#'
#' @keywords internal
#' @noRd
.tc_variance_svyrecvar <- function(design, response_formula, response_var,
                                   by, conf_level, calculate_deff) {

  # Try to access svyrecvar internals
  tryCatch({
    svyrecvar <- getFromNamespace("svyrecvar", "survey")

    # For now, fall back to standard method and enhance later
    # Full svyrecvar integration requires careful handling of design internals
    cli::cli_warn(
      c(
        "!" = "svyrecvar method currently uses survey package standard API",
        "i" = "Full survey internals integration coming in next iteration"
      )
    )

    result <- .tc_variance_survey(design, response_formula, by, conf_level, calculate_deff)
    result$method <- "survey"  # Set actual method used
    result$method_details$attempted_svyrecvar <- TRUE
    result$method_details$fallback_from <- "svyrecvar"
    result$method_details$fallback_reason <- "Full internals integration in progress"

    return(result)

  }, error = function(e) {
    cli::cli_warn(
      c(
        "!" = "Could not access survey:::svyrecvar: {e$message}",
        "i" = "Falling back to standard survey package variance"
      )
    )

    result <- .tc_variance_survey(design, response_formula, by, conf_level, calculate_deff)
    result$method <- "survey"  # Set actual method used
    result$method_details$fallback <- TRUE
    result$method_details$fallback_from <- "svyrecvar"
    result$method_details$error <- e$message

    return(result)
  })
}

#' Bootstrap Variance Estimation
#'
#' Uses bootstrap resampling for variance estimation.
#'
#' @keywords internal
#' @noRd
.tc_variance_bootstrap <- function(design, response_formula, by, conf_level,
                                   n_replicates, calculate_deff) {

  # Convert to replicate design if needed
  if (!inherits(design, "svyrep.design")) {
    cli::cli_alert_info("Creating bootstrap replicate design ({n_replicates} replicates)")

    rep_design <- tryCatch(
      survey::as.svrepdesign(design, type = "bootstrap", replicates = n_replicates),
      error = function(e) {
        cli::cli_warn(
          c(
            "!" = "Could not create bootstrap replicate design: {e$message}",
            "i" = "Falling back to standard variance estimation"
          )
        )
        return(NULL)
      }
    )

    if (is.null(rep_design)) {
      result <- .tc_variance_survey(design, response_formula, by, conf_level, calculate_deff)
      result$method <- "survey"  # Set actual method used
      result$method_details$fallback <- TRUE
      result$method_details$fallback_from <- "bootstrap"
      return(result)
    }
  } else {
    rep_design <- design
    n_replicates <- ncol(rep_design$repweights)
  }

  # Calculate with replicates
  if (is.null(by)) {
    est <- survey::svymean(response_formula, rep_design, na.rm = TRUE)
    estimate <- as.numeric(est)
    se <- as.numeric(survey::SE(est))
    variance <- se^2

    deff <- if (calculate_deff) {
      tryCatch(as.numeric(survey::deff(est)), error = function(e) NA_real_)
    } else {
      NA_real_
    }

  } else {
    by_formula <- as.formula(paste("~", paste(by, collapse = " + ")))
    est <- survey::svyby(
      response_formula,
      by_formula,
      rep_design,
      survey::svymean,
      na.rm = TRUE
    )

    estimate <- est[[ncol(est) - 1]]
    se <- est[[ncol(est)]]
    variance <- se^2

    deff <- if (calculate_deff) {
      tryCatch(
        as.numeric(survey::deff(est)),
        error = function(e) rep(NA_real_, length(estimate))
      )
    } else {
      rep(NA_real_, length(estimate))
    }

    # Extract grouping variables from result
    group_data <- est[, seq_along(by), drop = FALSE]
  }

  # Confidence intervals
  alpha <- 1 - conf_level
  z_score <- qnorm(1 - alpha / 2)
  ci_lower <- estimate - z_score * se
  ci_upper <- estimate + z_score * se

  result <- list(
    estimate = estimate,
    variance = variance,
    se = se,
    ci_lower = ci_lower,
    ci_upper = ci_upper,
    deff = deff,
    method_details = list(
      n_replicates = n_replicates,
      replicate_type = "bootstrap"
    )
  )

  # Add grouping data if available
  if (!is.null(by) && length(by) > 0) {
    result$group_data <- group_data
  }

  result
}

#' Jackknife Variance Estimation
#'
#' Uses jackknife resampling for variance estimation.
#'
#' @keywords internal
#' @noRd
.tc_variance_jackknife <- function(design, response_formula, by, conf_level, calculate_deff) {

  # Convert to jackknife replicate design if needed
  if (!inherits(design, "svyrep.design")) {
    cli::cli_alert_info("Creating jackknife replicate design (JK1)")

    rep_design <- tryCatch(
      survey::as.svrepdesign(design, type = "JK1"),
      error = function(e) {
        cli::cli_warn(
          c(
            "!" = "Could not create jackknife replicate design: {e$message}",
            "i" = "Falling back to standard variance estimation"
          )
        )
        return(NULL)
      }
    )

    if (is.null(rep_design)) {
      result <- .tc_variance_survey(design, response_formula, by, conf_level, calculate_deff)
      result$method <- "survey"  # Set actual method used
      result$method_details$fallback <- TRUE
      result$method_details$fallback_from <- "jackknife"
      return(result)
    }
  } else {
    rep_design <- design
  }

  n_replicates <- ncol(rep_design$repweights)

  # Calculate with replicates
  if (is.null(by)) {
    est <- survey::svymean(response_formula, rep_design, na.rm = TRUE)
    estimate <- as.numeric(est)
    se <- as.numeric(survey::SE(est))
    variance <- se^2

    deff <- if (calculate_deff) {
      tryCatch(as.numeric(survey::deff(est)), error = function(e) NA_real_)
    } else {
      NA_real_
    }

  } else {
    by_formula <- as.formula(paste("~", paste(by, collapse = " + ")))
    est <- survey::svyby(
      response_formula,
      by_formula,
      rep_design,
      survey::svymean,
      na.rm = TRUE
    )

    estimate <- est[[ncol(est) - 1]]
    se <- est[[ncol(est)]]
    variance <- se^2

    deff <- if (calculate_deff) {
      tryCatch(
        as.numeric(survey::deff(est)),
        error = function(e) rep(NA_real_, length(estimate))
      )
    } else {
      rep(NA_real_, length(estimate))
    }

    # Extract grouping variables from result
    group_data <- est[, seq_along(by), drop = FALSE]
  }

  # Confidence intervals
  alpha <- 1 - conf_level
  z_score <- qnorm(1 - alpha / 2)
  ci_lower <- estimate - z_score * se
  ci_upper <- estimate + z_score * se

  result <- list(
    estimate = estimate,
    variance = variance,
    se = se,
    ci_lower = ci_lower,
    ci_upper = ci_upper,
    deff = deff,
    method_details = list(
      n_replicates = n_replicates,
      replicate_type = "jackknife_JK1"
    )
  )

  # Add grouping data if available
  if (!is.null(by) && length(by) > 0) {
    result$group_data <- group_data
  }

  result
}
