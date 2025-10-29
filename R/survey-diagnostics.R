#' Survey Design Diagnostics for tidycreel
#'
#' Native design quality assessment and diagnostics built from the ground up.
#' Integrates with tidycreel estimators through the `design_diagnostics` parameter.
#'
#' @name survey-diagnostics
NULL

#' Survey Design Diagnostics
#'
#' Comprehensive assessment of survey design quality and potential issues.
#' Built-in to tidycreel estimators for automatic quality checking.
#'
#' @param design Survey design object
#' @param detailed Logical, whether to include detailed diagnostics
#'
#' @return List with class "tc_design_diagnostics" containing:
#'   \describe{
#'     \item{design_summary}{Basic design characteristics}
#'     \item{quality_checks}{Design quality assessments}
#'     \item{warnings}{Potential issues detected}
#'     \item{recommendations}{Suggestions for improvement}
#'   }
#'
#' @details
#' Performs comprehensive design diagnostics including:
#' - Stratification balance and singleton strata detection
#' - Clustering structure and small cluster detection
#' - Weight distribution and extreme weights
#' - Finite population correction assessment
#' - Sample size adequacy by stratum
#'
#' @examples
#' \dontrun{
#' # Diagnose survey design
#' diag <- tc_design_diagnostics(creel_design)
#' print(diag)
#'
#' # Check for warnings
#' diag$warnings
#'
#' # Get recommendations
#' diag$recommendations
#' }
#'
#' @export
tc_design_diagnostics <- function(design, detailed = FALSE) {

  if (!inherits(design, c("survey.design", "survey.design2", "svyrep.design"))) {
    cli::cli_abort("{.arg design} must be a survey design object")
  }

  # Extract basic design information
  design_summary <- tc_extract_design_info(design)

  # Perform quality checks
  quality_checks <- .tc_design_quality_checks(design, design_summary)

  # Identify warnings
  warnings_list <- .tc_design_warnings(quality_checks)

  # Generate recommendations
  recommendations <- .tc_design_recommendations(quality_checks, design_summary)

  # Detailed diagnostics if requested
  detailed_info <- if (detailed) {
    .tc_detailed_diagnostics(design, design_summary)
  } else {
    NULL
  }

  result <- list(
    design_summary = design_summary,
    quality_checks = quality_checks,
    warnings = warnings_list,
    recommendations = recommendations,
    detailed = detailed_info
  )

  class(result) <- c("tc_design_diagnostics", "list")

  return(result)
}

#' Extract Survey Design Information
#'
#' Extracts comprehensive information about a survey design object.
#'
#' @param design Survey design object
#'
#' @return List with design information
#' @export
tc_extract_design_info <- function(design) {

  # Basic information
  info <- list(
    design_type = class(design)[1],
    n_observations = nrow(design$variables),
    has_strata = !is.null(design$strata),
    has_clusters = !is.null(design$cluster),
    has_weights = !is.null(design$prob),
    has_fpc = !is.null(design$fpc),
    is_replicate = inherits(design, "svyrep.design")
  )

  # Stratification info
  if (info$has_strata) {
    strata_table <- table(design$strata)
    info$strata_info <- list(
      n_strata = length(strata_table),
      strata_sizes = as.list(strata_table),
      min_stratum_size = min(strata_table),
      max_stratum_size = max(strata_table),
      mean_stratum_size = mean(strata_table),
      balanced = (max(strata_table) / min(strata_table)) < 2,
      singleton_strata = sum(strata_table == 1),
      small_strata = sum(strata_table < 5)
    )
  }

  # Clustering info
  if (info$has_clusters) {
    if (is.list(design$cluster)) {
      # Multistage
      info$cluster_info <- list(
        n_stages = length(design$cluster),
        is_multistage = TRUE
      )

      # First stage info
      cluster_table <- table(design$cluster[[1]])
      info$cluster_info$first_stage <- list(
        n_clusters = length(cluster_table),
        avg_cluster_size = mean(cluster_table),
        min_cluster_size = min(cluster_table),
        max_cluster_size = max(cluster_table)
      )
    } else {
      # Single stage
      cluster_table <- table(design$cluster)
      info$cluster_info <- list(
        n_clusters = length(cluster_table),
        avg_cluster_size = mean(cluster_table),
        min_cluster_size = min(cluster_table),
        max_cluster_size = max(cluster_table),
        is_multistage = FALSE,
        singleton_clusters = sum(cluster_table == 1),
        small_clusters = sum(cluster_table < 3)
      )
    }
  }

  # Weight info
  if (info$has_weights) {
    weights <- 1 / design$prob
    info$weight_info <- list(
      min_weight = min(weights),
      max_weight = max(weights),
      mean_weight = mean(weights),
      median_weight = median(weights),
      cv_weights = sd(weights) / mean(weights),
      weight_range_ratio = max(weights) / min(weights),
      extreme_weights = sum(
        weights > 5 * mean(weights) | weights < 0.2 * mean(weights)
      )
    )
  }

  # FPC info
  if (info$has_fpc) {
    if (inherits(design, "survey.design2")) {
      info$fpc_info <- list(
        has_fpc = TRUE,
        type = "new_style"
      )
    } else {
      info$fpc_info <- list(
        has_fpc = TRUE,
        type = "old_style"
      )
    }
  }

  # Replicate weight info
  if (info$is_replicate) {
    info$replicate_info <- list(
      n_replicates = ncol(design$repweights),
      replicate_type = design$type,
      scale = design$scale,
      rscales = if (!is.null(design$rscales)) length(unique(design$rscales)) else NULL
    )
  }

  return(info)
}

# Internal diagnostic functions ----

#' Design Quality Checks
#'
#' @keywords internal
#' @noRd
.tc_design_quality_checks <- function(design, design_summary) {

  checks <- list()

  # Sample size check
  checks$sample_size <- list(
    n_obs = design_summary$n_observations,
    adequate = design_summary$n_observations >= 30,
    issue = if (design_summary$n_observations < 30) "Very small sample size" else NULL
  )

  # Stratification checks
  if (design_summary$has_strata) {
    si <- design_summary$strata_info

    checks$stratification <- list(
      n_strata = si$n_strata,
      balanced = si$balanced,
      singleton_strata = si$singleton_strata,
      small_strata = si$small_strata,
      min_size = si$min_stratum_size,
      issue = if (si$singleton_strata > 0) {
        sprintf("%d singleton strata detected", si$singleton_strata)
      } else if (si$small_strata > 0) {
        sprintf("%d small strata (n < 5) detected", si$small_strata)
      } else {
        NULL
      }
    )
  }

  # Clustering checks
  if (design_summary$has_clusters && !design_summary$cluster_info$is_multistage) {
    ci <- design_summary$cluster_info

    checks$clustering <- list(
      n_clusters = ci$n_clusters,
      avg_size = ci$avg_cluster_size,
      singleton_clusters = ci$singleton_clusters,
      small_clusters = ci$small_clusters,
      issue = if (ci$singleton_clusters > 0) {
        sprintf("%d singleton clusters detected", ci$singleton_clusters)
      } else if (ci$small_clusters > 0) {
        sprintf("%d small clusters (n < 3) detected", ci$small_clusters)
      } else {
        NULL
      }
    )
  }

  # Weight checks
  if (design_summary$has_weights) {
    wi <- design_summary$weight_info

    checks$weights <- list(
      cv_weights = wi$cv_weights,
      range_ratio = wi$weight_range_ratio,
      extreme_weights = wi$extreme_weights,
      issue = if (wi$cv_weights > 1) {
        "High weight variability (CV > 1)"
      } else if (wi$extreme_weights > 0) {
        sprintf("%d extreme weights detected", wi$extreme_weights)
      } else if (wi$weight_range_ratio > 10) {
        "Large weight range (max/min > 10)"
      } else {
        NULL
      }
    )
  }

  # FPC check
  if (!design_summary$has_fpc) {
    checks$fpc <- list(
      has_fpc = FALSE,
      issue = "No finite population correction specified"
    )
  }

  return(checks)
}

#' Extract Design Warnings
#'
#' @keywords internal
#' @noRd
.tc_design_warnings <- function(quality_checks) {

  warnings_list <- list()

  for (check_name in names(quality_checks)) {
    check <- quality_checks[[check_name]]
    if (!is.null(check$issue)) {
      warnings_list[[check_name]] <- check$issue
    }
  }

  return(warnings_list)
}

#' Generate Design Recommendations
#'
#' @keywords internal
#' @noRd
.tc_design_recommendations <- function(quality_checks, design_summary) {

  recommendations <- list()

  # Sample size recommendations
  if (!quality_checks$sample_size$adequate) {
    recommendations$sample_size <- "Increase sample size to at least 30 observations"
  }

  # Stratification recommendations
  if (!is.null(quality_checks$stratification)) {
    if (quality_checks$stratification$singleton_strata > 0) {
      recommendations$singleton_strata <- paste(
        "Consider combining singleton strata with similar strata",
        "or use options(survey.lonely.psu='adjust')"
      )
    }

    if (!quality_checks$stratification$balanced) {
      recommendations$strata_balance <- paste(
        "Strata are imbalanced. Consider proportional allocation",
        "or post-stratification adjustment"
      )
    }
  }

  # Clustering recommendations
  if (!is.null(quality_checks$clustering)) {
    if (quality_checks$clustering$singleton_clusters > 0) {
      recommendations$singleton_clusters <- paste(
        "Singleton clusters reduce variance estimation accuracy.",
        "Consider increasing cluster sizes or using adjusted methods"
      )
    }
  }

  # Weight recommendations
  if (!is.null(quality_checks$weights)) {
    if (quality_checks$weights$cv_weights > 1) {
      recommendations$weights <- paste(
        "High weight variability can reduce precision.",
        "Consider trimming extreme weights or using calibration"
      )
    }
  }

  # FPC recommendation
  if (!is.null(quality_checks$fpc$issue)) {
    recommendations$fpc <- paste(
      "Specify finite population correction if sampling from",
      "a finite population to improve variance estimates"
    )
  }

  return(recommendations)
}

#' Detailed Diagnostics
#'
#' @keywords internal
#' @noRd
.tc_detailed_diagnostics <- function(design, design_summary) {

  detailed <- list()

  # Distribution of weights
  if (design_summary$has_weights) {
    weights <- 1 / design$prob
    detailed$weight_distribution <- list(
      quantiles = quantile(weights, probs = c(0.01, 0.05, 0.25, 0.5, 0.75, 0.95, 0.99)),
      histogram_breaks = hist(weights, plot = FALSE)$breaks
    )
  }

  # Stratum-specific diagnostics
  if (design_summary$has_strata) {
    stratum_stats <- aggregate(
      rep(1, design_summary$n_observations),
      by = list(stratum = design$strata),
      FUN = length
    )
    names(stratum_stats) <- c("stratum", "n")

    detailed$stratum_diagnostics <- stratum_stats
  }

  return(detailed)
}

# Print method ----

#' @export
print.tc_design_diagnostics <- function(x, ...) {

  cli::cli_h1("Survey Design Diagnostics")

  cli::cli_h2("Design Summary")
  cli::cli_text("Design type: {.strong {x$design_summary$design_type}}")
  cli::cli_text("Observations: {.strong {x$design_summary$n_observations}}")
  cli::cli_text("Strata: {.strong {x$design_summary$has_strata}}")
  cli::cli_text("Clusters: {.strong {x$design_summary$has_clusters}}")
  cli::cli_text("Weights: {.strong {x$design_summary$has_weights}}")

  # Display warnings if any
  if (length(x$warnings) > 0) {
    cli::cli_h2("Warnings")
    for (warning_name in names(x$warnings)) {
      cli::cli_alert_warning("{warning_name}: {x$warnings[[warning_name]]}")
    }
  } else {
    cli::cli_h2("Quality Status")
    cli::cli_alert_success("No design issues detected")
  }

  # Display recommendations if any
  if (length(x$recommendations) > 0) {
    cli::cli_h2("Recommendations")
    for (rec_name in names(x$recommendations)) {
      cli::cli_alert_info("{rec_name}: {x$recommendations[[rec_name]]}")
    }
  }

  # Detailed info if available
  if (!is.null(x$detailed)) {
    cli::cli_h2("Detailed Diagnostics")
    cli::cli_text("Additional diagnostic information available in $detailed")
  }

  invisible(x)
}
