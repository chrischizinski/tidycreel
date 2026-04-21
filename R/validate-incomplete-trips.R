#' Validate incomplete trip estimates using TOST equivalence testing
#'
#' Performs Two One-Sided Tests (TOST) to determine if incomplete trip CPUE
#' estimates are statistically equivalent to complete trip estimates within a
#' specified threshold. Returns validation results with recommendations for
#' whether incomplete trips are appropriate for estimation in the given dataset.
#'
#' @param design A creel_design object with interviews attached via
#'   \code{\link{add_interviews}}. Must include trip_status field to
#'   distinguish complete from incomplete trips.
#' @param catch Bare column name for catch data (supports tidy evaluation)
#' @param effort Bare column name for effort data (supports tidy evaluation)
#' @param by Optional tidy selector for grouping variables. When provided,
#'   performs TOST for each group independently. Overall validation passes
#'   only if overall test AND all group tests pass equivalence.
#' @param variance Character string specifying variance estimation method.
#'   Options: \code{"taylor"} (default), \code{"bootstrap"}, or
#'   \code{"jackknife"}. Passed to \code{\link{estimate_catch_rate}}.
#' @param conf_level Numeric confidence level for confidence intervals
#'   (default: 0.95). Passed to \code{\link{estimate_catch_rate}}.
#' @param truncate_at Numeric minimum trip duration (hours) for incomplete trip
#'   estimation. Default is 0.5 hours (30 minutes). Passed to
#'   \code{\link{estimate_catch_rate}} for MOR estimator.
#'
#' @return A creel_tost_validation S3 object (list) with components:
#'   \itemize{
#'     \item \code{overall_test}: List with TOST results for overall comparison
#'       (p_lower, p_upper, equivalence_passed, diff_estimate, equivalence_bounds)
#'     \item \code{group_tests}: Data frame with per-group TOST results (only
#'       present for grouped estimation)
#'     \item \code{equivalence_threshold}: Numeric threshold used (e.g., 0.20
#'       for ±20\%)
#'     \item \code{passed}: Logical indicating if overall AND all groups (if
#'       applicable) passed equivalence
#'     \item \code{recommendation}: Character string with usage recommendation
#'     \item \code{metadata}: List with complete and incomplete trip estimates,
#'       standard errors, confidence intervals, and sample sizes
#'   }
#'
#' @section Package Options:
#' The package option \code{tidycreel.equivalence_threshold} controls the
#' equivalence threshold (default: 0.20 = ±20\%). This threshold defines the
#' bounds for equivalence as ±threshold * complete_trip_estimate. For example,
#' with the default 20\% threshold and a complete trip CPUE of 2.0 fish/hour,
#' equivalence bounds are 1.6 to 2.4 fish/hour. Users can set a custom threshold:
#'
#' \code{options(tidycreel.equivalence_threshold = 0.15)}
#'
#' @section TOST Equivalence Testing:
#' TOST (Two One-Sided Tests) is the statistically appropriate method for
#' proving similarity between two estimates. Unlike traditional hypothesis
#' testing which tests for difference, TOST tests the null hypothesis that
#' estimates differ by MORE than the threshold. Equivalence is concluded when
#' both one-sided tests reject the null (both p-values < 0.05).
#'
#' The two tests are:
#' \enumerate{
#'   \item H0: complete - incomplete <= -threshold vs H1: complete - incomplete > -threshold
#'   \item H0: complete - incomplete >= threshold vs H1: complete - incomplete < threshold
#' }
#'
#' Both tests must reject (p < 0.05) for equivalence. This ensures estimates
#' are "close enough" to be considered equivalent for practical purposes.
#'
#' @section Grouped Validation:
#' When \code{by} is provided, the function performs TOST for each group
#' independently AND for the overall (ungrouped) data. The validation passes
#' only if ALL tests pass equivalence. This conservative approach prevents
#' overlooking group-specific bias that could be masked by overall equivalence.
#'
#' @details
#' The function estimates CPUE separately for complete trips (using ratio-of-means)
#' and incomplete trips (using mean-of-ratios) via \code{\link{estimate_catch_rate}}.
#' It then performs TOST to test equivalence within the specified threshold.
#'
#' Equivalence bounds are calculated as ±threshold * complete_trip_estimate.
#' The difference variance is estimated using the delta method:
#' Var(complete - incomplete) = Var(complete) + Var(incomplete), assuming
#' independence between the two samples.
#'
#' Sample size requirements: At least 10 complete trips AND 10 incomplete trips
#' are required for stable variance estimation and TOST. The function errors
#' if either sample size is insufficient.
#'
#' @examples
#' # Create design with both complete and incomplete trips
#' calendar <- data.frame(
#'   date = as.Date(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04")),
#'   day_type = rep(c("weekday", "weekend"), each = 2)
#' )
#' design <- creel_design(calendar, date = date, strata = day_type)
#'
#' set.seed(123)
#' interviews <- data.frame(
#'   date = as.Date(rep(c("2024-06-01", "2024-06-02", "2024-06-03", "2024-06-04"), each = 25)),
#'   catch_total = rpois(100, lambda = 6),
#'   hours_fished = runif(100, min = 2, max = 4),
#'   trip_status = rep(c("complete", "incomplete"), each = 50),
#'   trip_duration = runif(100, min = 2, max = 4)
#' )
#'
#' design_with_interviews <- add_interviews(design, interviews,
#'   catch = catch_total,
#'   effort = hours_fished,
#'   trip_status = trip_status,
#'   trip_duration = trip_duration
#' )
#'
#' # Validate incomplete trips
#' result <- validate_incomplete_trips(design_with_interviews,
#'   catch = catch_total,
#'   effort = hours_fished
#' )
#' print(result)
#'
#' # Grouped validation
#' result_grouped <- validate_incomplete_trips(design_with_interviews,
#'   catch = catch_total,
#'   effort = hours_fished,
#'   by = day_type
#' )
#' print(result_grouped)
#'
#' # Custom equivalence threshold
#' options(tidycreel.equivalence_threshold = 0.15) # 15% threshold
#' result_custom <- validate_incomplete_trips(design_with_interviews,
#'   catch = catch_total,
#'   effort = hours_fished
#' )
#' @family "Reporting & Diagnostics"
#' @export
validate_incomplete_trips <- function(design,
                                      catch,
                                      effort,
                                      by = NULL,
                                      variance = "taylor",
                                      conf_level = 0.95,
                                      truncate_at = 0.5) {
  # Capture bare column names
  catch_quo <- rlang::enquo(catch)
  effort_quo <- rlang::enquo(effort)
  by_quo <- rlang::enquo(by)

  # Validate input is creel_design
  if (!inherits(design, "creel_design")) {
    cli::cli_abort(c(
      "{.arg design} must be a {.cls creel_design} object.",
      "x" = "{.arg design} is {.cls {class(design)[1]}}.",
      "i" = "Create a design with {.fn creel_design}."
    ))
  }

  # Validate trip_status field exists
  if (is.null(design$trip_status_col)) {
    cli::cli_abort(c(
      "trip_status required for validation",
      "x" = "Design does not have trip_status field",
      "i" = "Call {.fn add_interviews} with trip_status parameter to distinguish complete from incomplete trips"
    ))
  }

  # Validate catch and effort columns exist
  catch_col <- rlang::as_name(catch_quo)
  effort_col <- rlang::as_name(effort_quo)

  if (!catch_col %in% names(design$interviews)) {
    cli::cli_abort(c(
      "Catch column not found",
      "x" = "Column {.field {catch_col}} does not exist in interview data",
      "i" = "Available columns: {.field {names(design$interviews)}}"
    ))
  }

  if (!effort_col %in% names(design$interviews)) {
    cli::cli_abort(c(
      "Effort column not found",
      "x" = "Column {.field {effort_col}} does not exist in interview data",
      "i" = "Available columns: {.field {names(design$interviews)}}"
    ))
  }

  # Check sample sizes
  trip_status_col <- design$trip_status_col
  n_complete <- sum(design$interviews[[trip_status_col]] == "complete", na.rm = TRUE)
  n_incomplete <- sum(design$interviews[[trip_status_col]] == "incomplete", na.rm = TRUE)

  if (n_complete < 10) {
    cli::cli_abort(c(
      "Insufficient complete trips for validation",
      "x" = "Need at least 10 complete trips, found {n_complete}",
      "i" = "TOST requires sufficient sample sizes for stable variance estimation"
    ))
  }

  if (n_incomplete < 10) {
    cli::cli_abort(c(
      "Insufficient incomplete trips for validation",
      "x" = "Need at least 10 incomplete trips, found {n_incomplete}",
      "i" = "TOST requires sufficient sample sizes for stable variance estimation"
    ))
  }

  # Get equivalence threshold from package option (default 0.20 = ±20%)
  threshold <- getOption("tidycreel.equivalence_threshold", 0.20)

  # Estimate CPUE for complete trips (ratio-of-means)
  complete_result <- suppressMessages(
    estimate_catch_rate( # nolint: object_usage_linter
      design,
      by = !!by_quo,
      variance = variance,
      conf_level = conf_level,
      estimator = "ratio-of-means",
      use_trips = "complete",
      truncate_at = truncate_at
    )
  )

  # Estimate CPUE for incomplete trips (mean-of-ratios)
  incomplete_result <- suppressMessages(suppressWarnings(
    estimate_catch_rate( # nolint: object_usage_linter
      design,
      by = !!by_quo,
      variance = variance,
      conf_level = conf_level,
      estimator = "mor",
      use_trips = "incomplete",
      truncate_at = truncate_at
    )
  ))

  # Determine if grouped or ungrouped
  is_grouped <- !rlang::quo_is_null(by_quo)

  if (is_grouped) {
    # Grouped validation: perform TOST per group AND overall
    by_cols <- tidyselect::eval_select(
      by_quo,
      data = design$interviews,
      allow_rename = FALSE,
      allow_empty = FALSE,
      error_call = rlang::caller_env()
    )
    by_vars <- names(by_cols)

    # Overall test (ungrouped data)
    overall_result <- perform_overall_tost(
      design = design,
      catch_quo = catch_quo,
      effort_quo = effort_quo,
      variance = variance,
      conf_level = conf_level,
      truncate_at = truncate_at,
      threshold = threshold
    )

    # Per-group tests
    group_results <- perform_grouped_tost(
      complete_result = complete_result,
      incomplete_result = incomplete_result,
      by_vars = by_vars,
      threshold = threshold
    )

    # Overall passed = overall test passes AND all group tests pass
    passed <- overall_result$equivalence_passed && all(group_results$equivalence_passed)

    # Build plot_data for grouped estimation
    complete_df <- complete_result$estimates
    incomplete_df <- incomplete_result$estimates

    # Create group labels
    group_labels <- character(nrow(complete_df))
    for (i in seq_len(nrow(complete_df))) {
      group_vals <- complete_df[i, by_vars, drop = FALSE]
      group_labels[i] <- paste(by_vars, "=", group_vals[1, ], collapse = ", ")
    }

    plot_data <- list(
      complete_est = complete_df$estimate,
      incomplete_est = incomplete_df$estimate,
      complete_ci_lower = complete_df$ci_lower,
      complete_ci_upper = complete_df$ci_upper,
      incomplete_ci_lower = incomplete_df$ci_lower,
      incomplete_ci_upper = incomplete_df$ci_upper,
      passed = group_results$equivalence_passed,
      group_labels = group_labels
    )

    # Build metadata
    metadata <- list(
      overall = list(
        complete = list(
          n = sum(complete_result$estimates$n),
          estimate = mean(complete_result$estimates$estimate),
          se = sqrt(sum(complete_result$estimates$se^2)) / nrow(complete_result$estimates)
        ),
        incomplete = list(
          n = sum(incomplete_result$estimates$n),
          estimate = mean(incomplete_result$estimates$estimate),
          se = sqrt(sum(incomplete_result$estimates$se^2)) / nrow(incomplete_result$estimates)
        )
      ),
      groups = group_results
    )

    # Recommendation
    if (passed) {
      recommendation <- paste(
        "Validation passed: Safe to use incomplete trips for CPUE estimation in this dataset",
        "(overall and all groups passed equivalence)"
      )
    } else {
      failing_groups <- group_results[!group_results$equivalence_passed, by_vars, drop = FALSE]
      if (nrow(failing_groups) > 0) {
        recommendation <- paste0(
          "Validation failed: Use complete trips only. ",
          "Groups failed equivalence: ",
          paste(apply(failing_groups, 1, function(x) paste(by_vars, "=", x, collapse = ", ")), collapse = "; ")
        )
      } else {
        recommendation <- "Validation failed: Use complete trips only (overall test failed)"
      }
    }

    result <- list(
      overall_test = overall_result,
      group_tests = group_results,
      equivalence_threshold = threshold,
      passed = passed,
      recommendation = recommendation,
      metadata = metadata,
      plot_data = plot_data
    )
  } else {
    # Ungrouped validation: single TOST
    complete_estimate <- complete_result$estimates$estimate
    complete_se <- complete_result$estimates$se
    complete_ci_lower <- complete_result$estimates$ci_lower
    complete_ci_upper <- complete_result$estimates$ci_upper
    incomplete_estimate <- incomplete_result$estimates$estimate
    incomplete_se <- incomplete_result$estimates$se
    incomplete_ci_lower <- incomplete_result$estimates$ci_lower
    incomplete_ci_upper <- incomplete_result$estimates$ci_upper

    # Perform TOST
    tost_result <- perform_tost(
      complete_estimate = complete_estimate,
      complete_se = complete_se,
      incomplete_estimate = incomplete_estimate,
      incomplete_se = incomplete_se,
      threshold = threshold,
      n_complete = complete_result$estimates$n,
      n_incomplete = incomplete_result$estimates$n
    )

    # Metadata
    metadata <- list(
      complete = list(
        n = complete_result$estimates$n,
        estimate = complete_estimate,
        se = complete_se,
        ci_lower = complete_ci_lower,
        ci_upper = complete_ci_upper
      ),
      incomplete = list(
        n = incomplete_result$estimates$n,
        estimate = incomplete_estimate,
        se = incomplete_se,
        ci_lower = incomplete_ci_lower,
        ci_upper = incomplete_ci_upper
      )
    )

    # Build plot_data for ungrouped estimation
    plot_data <- list(
      complete_est = complete_estimate,
      incomplete_est = incomplete_estimate,
      complete_ci_lower = complete_ci_lower,
      complete_ci_upper = complete_ci_upper,
      incomplete_ci_lower = incomplete_ci_lower,
      incomplete_ci_upper = incomplete_ci_upper,
      passed = tost_result$equivalence_passed,
      group_labels = NULL
    )

    # Recommendation
    if (tost_result$equivalence_passed) {
      recommendation <- "Validation passed: Safe to use incomplete trips for CPUE estimation in this dataset"
    } else {
      recommendation <- "Validation failed: Use complete trips only (estimates not statistically equivalent)"
    }

    result <- list(
      overall_test = tost_result,
      equivalence_threshold = threshold,
      passed = tost_result$equivalence_passed,
      recommendation = recommendation,
      metadata = metadata,
      plot_data = plot_data
    )
  }

  class(result) <- "creel_tost_validation"
  result
}

#' Perform overall TOST for grouped validation
#'
#' Helper to run ungrouped CPUE estimates and TOST for overall comparison
#' when grouped validation is requested.
#'
#' @keywords internal
#' @noRd
perform_overall_tost <- function(design, catch_quo, effort_quo, variance,
                                 conf_level, truncate_at, threshold) {
  # Estimate ungrouped complete CPUE
  complete_overall <- suppressMessages(
    estimate_catch_rate( # nolint: object_usage_linter
      design,
      variance = variance,
      conf_level = conf_level,
      estimator = "ratio-of-means",
      use_trips = "complete",
      truncate_at = truncate_at
    )
  )

  # Estimate ungrouped incomplete CPUE
  incomplete_overall <- suppressMessages(suppressWarnings(
    estimate_catch_rate( # nolint: object_usage_linter
      design,
      variance = variance,
      conf_level = conf_level,
      estimator = "mor",
      use_trips = "incomplete",
      truncate_at = truncate_at
    )
  ))

  # Perform TOST
  perform_tost(
    complete_estimate = complete_overall$estimates$estimate,
    complete_se = complete_overall$estimates$se,
    incomplete_estimate = incomplete_overall$estimates$estimate,
    incomplete_se = incomplete_overall$estimates$se,
    threshold = threshold,
    n_complete = complete_overall$estimates$n,
    n_incomplete = incomplete_overall$estimates$n
  )
}

#' Perform TOST for each group
#'
#' @keywords internal
#' @noRd
perform_grouped_tost <- function(complete_result, incomplete_result, by_vars, threshold) {
  # Extract estimates by group
  complete_df <- complete_result$estimates
  incomplete_df <- incomplete_result$estimates

  # Initialize result data frame
  group_results <- complete_df[, by_vars, drop = FALSE]
  group_results$p_lower <- numeric(nrow(group_results))
  group_results$p_upper <- numeric(nrow(group_results))
  group_results$equivalence_passed <- logical(nrow(group_results))
  group_results$diff_estimate <- numeric(nrow(group_results))
  group_results$equivalence_lower <- numeric(nrow(group_results))
  group_results$equivalence_upper <- numeric(nrow(group_results))

  # Perform TOST for each group
  for (i in seq_len(nrow(complete_df))) {
    tost_result <- perform_tost(
      complete_estimate = complete_df$estimate[i],
      complete_se = complete_df$se[i],
      incomplete_estimate = incomplete_df$estimate[i],
      incomplete_se = incomplete_df$se[i],
      threshold = threshold,
      n_complete = complete_df$n[i],
      n_incomplete = incomplete_df$n[i]
    )

    group_results$p_lower[i] <- tost_result$p_lower
    group_results$p_upper[i] <- tost_result$p_upper
    group_results$equivalence_passed[i] <- tost_result$equivalence_passed
    group_results$diff_estimate[i] <- tost_result$diff_estimate
    group_results$equivalence_lower[i] <- tost_result$equivalence_lower
    group_results$equivalence_upper[i] <- tost_result$equivalence_upper
  }

  group_results
}

#' Perform TOST (Two One-Sided Tests) equivalence testing
#'
#' Implements TOST to test equivalence between complete and incomplete trip
#' CPUE estimates. Returns p-values for both one-sided tests and overall
#' equivalence conclusion.
#'
#' @keywords internal
#' @noRd
perform_tost <- function(complete_estimate, complete_se, incomplete_estimate,
                         incomplete_se, threshold, n_complete, n_incomplete) {
  # Calculate difference and bounds
  diff_estimate <- complete_estimate - incomplete_estimate
  equivalence_lower <- -threshold * abs(complete_estimate)
  equivalence_upper <- threshold * abs(complete_estimate)

  # Delta method for difference variance: Var(C - I) = Var(C) + Var(I)
  # (assuming independence)
  se_diff <- sqrt(complete_se^2 + incomplete_se^2)

  # Degrees of freedom (conservative: min of two samples)
  df <- min(n_complete - 1, n_incomplete - 1)

  # TOST: Two one-sided tests
  # Test 1: H0: diff <= lower_bound vs H1: diff > lower_bound
  t_lower <- (diff_estimate - equivalence_lower) / se_diff
  p_lower <- stats::pt(t_lower, df = df, lower.tail = FALSE)

  # Test 2: H0: diff >= upper_bound vs H1: diff < upper_bound
  t_upper <- (diff_estimate - equivalence_upper) / se_diff
  p_upper <- stats::pt(t_upper, df = df, lower.tail = TRUE)

  # Equivalence passed if both tests reject at alpha = 0.05
  equivalence_passed <- (p_lower < 0.05) && (p_upper < 0.05)

  list(
    p_lower = p_lower,
    p_upper = p_upper,
    equivalence_passed = equivalence_passed,
    diff_estimate = diff_estimate,
    equivalence_lower = equivalence_lower,
    equivalence_upper = equivalence_upper,
    se_diff = se_diff,
    df = df
  )
}

#' Format creel_tost_validation for printing
#'
#' @param x A creel_tost_validation object
#' @param ... Additional arguments (currently ignored)
#'
#' @return Character vector with formatted output
#'
#' @export
format.creel_tost_validation <- function(x, ...) {
  output <- character()

  output <- c(output, cli::cli_format_method({
    cli::cli_h1("TOST Equivalence Validation Results")
    cli::cli_text("Threshold: \u00b1{round(x$equivalence_threshold * 100, 1)}% of complete trip estimate")

    # Overall status
    if (x$passed) {
      cli::cli_alert_success("Validation PASSED")
    } else {
      cli::cli_alert_danger("Validation FAILED")
    }

    cli::cli_text("")
    cli::cli_text("Recommendation: {x$recommendation}")
    cli::cli_text("")

    # Overall test results
    cli::cli_h2("Overall Test")

    # Handle both ungrouped (metadata$complete) and grouped (metadata$overall$complete) structures
    if (!is.null(x$metadata$overall)) {
      # Grouped validation
      complete_meta <- x$metadata$overall$complete # nolint: object_usage_linter
      incomplete_meta <- x$metadata$overall$incomplete # nolint: object_usage_linter
    } else {
      # Ungrouped validation
      complete_meta <- x$metadata$complete # nolint: object_usage_linter
      incomplete_meta <- x$metadata$incomplete # nolint: object_usage_linter
    }

    cli::cli_text("Complete trips: n = {complete_meta$n}, CPUE = {round(complete_meta$estimate, 3)}")
    cli::cli_text("Incomplete trips: n = {incomplete_meta$n}, CPUE = {round(incomplete_meta$estimate, 3)}")
    cli::cli_text("Difference: {round(x$overall_test$diff_estimate, 3)}")
    equiv_lower <- round(x$overall_test$equivalence_lower, 3) # nolint: object_usage_linter
    equiv_upper <- round(x$overall_test$equivalence_upper, 3) # nolint: object_usage_linter
    p_lower <- round(x$overall_test$p_lower, 4) # nolint: object_usage_linter
    p_upper <- round(x$overall_test$p_upper, 4) # nolint: object_usage_linter
    cli::cli_text("Equivalence bounds: [{equiv_lower}, {equiv_upper}]")
    cli::cli_text("TOST p-values: p_lower = {p_lower}, p_upper = {p_upper}")

    if (x$overall_test$equivalence_passed) {
      cli::cli_alert_success("Overall equivalence: PASSED")
    } else {
      cli::cli_alert_danger("Overall equivalence: FAILED")
    }

    # Group results if present
    if (!is.null(x$group_tests)) {
      cli::cli_text("")
      cli::cli_h2("Per-Group Tests")
      n_groups <- nrow(x$group_tests) # nolint: object_usage_linter
      n_passed <- sum(x$group_tests$equivalence_passed) # nolint: object_usage_linter
      cli::cli_text("{n_passed}/{n_groups} group{?s} passed equivalence")
    }
  }))

  output
}

#' Print creel_tost_validation
#'
#' Prints formatted validation results and displays scatter plot comparing
#' complete vs incomplete trip CPUE estimates. Plot includes y=x reference
#' line, confidence interval error bars, and annotations for failed groups.
#'
#' @param x A creel_tost_validation object
#' @param ... Additional arguments passed to format
#'
#' @return The input object, invisibly
#'
#' @export
print.creel_tost_validation <- function(x, ...) {
  # Print formatted text output
  cat(format(x, ...), sep = "\n")
  cat("\n")

  # Generate scatter plot using plot_data
  plot_data <- x$plot_data

  # Set up plot margins and layout
  graphics::par(mar = c(5, 5, 4, 2) + 0.1)

  # Determine axis ranges (include CI bounds)
  x_range <- range(c(
    plot_data$complete_est,
    plot_data$complete_ci_lower,
    plot_data$complete_ci_upper
  ), na.rm = TRUE)

  y_range <- range(c(
    plot_data$incomplete_est,
    plot_data$incomplete_ci_lower,
    plot_data$incomplete_ci_upper
  ), na.rm = TRUE)

  # Ensure ranges are equal (square plot)
  all_range <- range(c(x_range, y_range))
  x_range <- all_range
  y_range <- all_range

  # Create color scheme: blue for passed, red for failed
  point_colors <- ifelse(plot_data$passed, "#0066CC", "#CC0000")

  # Create base plot
  graphics::plot(
    x = plot_data$complete_est,
    y = plot_data$incomplete_est,
    xlim = x_range,
    ylim = y_range,
    xlab = "Complete Trip CPUE",
    ylab = "Incomplete Trip CPUE",
    main = "Validation: Incomplete vs Complete Trip Estimates",
    pch = 19,
    col = point_colors,
    cex = 1.5,
    las = 1
  )

  # Add y=x reference line
  graphics::abline(a = 0, b = 1, col = "gray50", lty = 2, lwd = 2)

  # Add error bars for confidence intervals
  n_points <- length(plot_data$complete_est)
  for (i in seq_len(n_points)) {
    # Horizontal error bars (complete trip CIs)
    graphics::segments(
      x0 = plot_data$complete_ci_lower[i],
      y0 = plot_data$incomplete_est[i],
      x1 = plot_data$complete_ci_upper[i],
      y1 = plot_data$incomplete_est[i],
      col = point_colors[i],
      lwd = 1.5
    )

    # Vertical error bars (incomplete trip CIs)
    graphics::segments(
      x0 = plot_data$complete_est[i],
      y0 = plot_data$incomplete_ci_lower[i],
      x1 = plot_data$complete_est[i],
      y1 = plot_data$incomplete_ci_upper[i],
      col = point_colors[i],
      lwd = 1.5
    )
  }

  # Add text labels for failed points
  if (any(!plot_data$passed)) {
    failed_indices <- which(!plot_data$passed)
    for (i in failed_indices) {
      label_text <- if (!is.null(plot_data$group_labels)) {
        plot_data$group_labels[i]
      } else {
        "FAILED"
      }

      # Position label above point
      graphics::text(
        x = plot_data$complete_est[i],
        y = plot_data$incomplete_est[i],
        labels = label_text,
        pos = 3, # above
        col = "#CC0000",
        cex = 0.8,
        font = 2 # bold
      )
    }
  }

  # Add legend
  graphics::legend(
    "topleft",
    legend = c("Passed equivalence", "Failed equivalence", "y=x reference"),
    col = c("#0066CC", "#CC0000", "gray50"),
    pch = c(19, 19, NA),
    lty = c(NA, NA, 2),
    lwd = c(NA, NA, 2),
    bty = "n",
    cex = 0.9
  )

  invisible(x)
}
