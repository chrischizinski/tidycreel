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
#' @param catch Bare column name: the design's catch column, as given to
#'   [add_interviews()]. The test always compares catch rates; any other
#'   column is an error (it was previously checked and then ignored).
#' @param effort Bare column name: the design's effort column, as given to
#'   [add_interviews()]. Rates use it as angler-hours (effort times
#'   \code{n_anglers}) when [add_interviews()] was given a party size, and as
#'   recorded -- party-hours, if that is what it holds -- when it was not; any
#'   other column is an error.
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
#' The difference variance is
#' Var(complete) + Var(incomplete) - 2 Cov(complete, incomplete). The two
#' rates come from different trips, but interview variance is clustered on the
#' survey day, so trips interviewed on the same days covary: when complete and
#' incomplete rates rise and fall together from day to day, their difference
#' is far more precise than either rate. Both rates are estimated jointly, as
#' domains of one survey of every interviewed day, under the requested
#' \code{variance} method, and the covariance comes from that fit (GH #664).
#' The t tests use the design's degrees of freedom, interviewed days minus
#' strata over the strata a comparison draws on, because that variance is
#' between days (GH #669). On bus-route and ice designs the two rates'
#' variances are still added: their rates are clustered on the day as well,
#' so this overstates the SE of the difference, which makes the test
#' conservative (GH #671).
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
#'   trip_status = rep(c("complete", "incomplete"), times = 50),
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
#' # Custom equivalence threshold, restoring the previous option afterwards
#' old_opts <- options(tidycreel.equivalence_threshold = 0.15) # 15% threshold
#' result_custom <- validate_incomplete_trips(design_with_interviews,
#'   catch = catch_total,
#'   effort = hours_fished
#' )
#' options(old_opts)
#' @family "Reporting & Diagnostics"
#' @export
validate_incomplete_trips <- function(
  design,
  catch,
  effort,
  by = NULL,
  variance = "taylor",
  conf_level = 0.95,
  truncate_at = 0.5
) {
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

  # A sectioned design reports one rate per section (and a lake row), which the
  # single overall test cannot pair; it failed with an R condition-length error
  # before. Refused until a per-section test is designed (GH #669).
  if (!is.null(design[["sections"]])) {
    cli::cli_abort(c(
      "{.fn validate_incomplete_trips} does not support sectioned designs yet.",
      "i" = "It compares one complete-trip rate with one incomplete-trip rate; a \\
             sectioned design has one of each per section."
    ), class = "creel_error_tost_sections")
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

  # The test is of the design's catch rate: both rates are estimated by
  # estimate_catch_rate(), which reads the design's catch column and its
  # angler-hours (effort x party size). A different column named here was
  # checked for existence and then ignored, so `catch = <harvest column>`
  # silently tested the catch rate (GH #669).
  if (!identical(catch_col, design$catch_col) || !identical(effort_col, design$effort_col)) {
    cli::cli_abort(c(
      "{.arg catch} and {.arg effort} must name the design's catch and effort columns.",
      "i" = "The design's are {.field {design$catch_col}} and {.field {design$effort_col}}; \\
             got {.field {catch_col}} and {.field {effort_col}}.",
      "i" = "The test compares catch rates. To test another count, give it as \\
             {.arg catch} in {.fn add_interviews}."
    ), class = "creel_error_tost_columns")
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
    estimate_catch_rate(
      # nolint: object_usage_linter
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
  incomplete_result <- suppressMessages(keep_undefined_draws_warning(
    estimate_catch_rate(
      # nolint: object_usage_linter
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
    by_vars <- screen_by_vars(
      names(by_cols), by_quo, design$interviews, design,
      error_call = rlang::caller_env()
    )

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
    overall_rates <- attr(overall_result, "rates")
    attr(overall_result, "rates") <- NULL

    # Per-group tests
    group_results <- perform_grouped_tost(
      design = design,
      complete_result = complete_result,
      incomplete_result = incomplete_result,
      by_vars = by_vars,
      threshold = threshold,
      joint = tost_joint_se_diff(design, complete_result, incomplete_result, variance, by_vars)
    )

    # Overall passed = overall test passes AND all group tests pass. A test
    # that could not be run (NA) is neither: any failure fails the whole, and
    # otherwise any untested test leaves it untested.
    all_tests <- c(overall_result$equivalence_passed, group_results$equivalence_passed)
    passed <- if (any(all_tests %in% FALSE)) FALSE else if (all(all_tests %in% TRUE)) TRUE else NA

    # Build plot_data for grouped estimation, paired by group key as the
    # tests are.
    al <- align_tost_groups(complete_result$estimates, incomplete_result$estimates, by_vars)
    complete_df <- al$complete
    incomplete_df <- al$incomplete

    # Create group labels
    group_labels <- vapply(seq_len(nrow(al$groups)), function(i) tost_group_label(al$groups, i, by_vars), "")

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
      # The overall test's own rates. An unweighted mean of the group rates,
      # with their SEs combined as if independent, was reported here beside a
      # difference taken from the pooled rates (GH #669).
      overall = list(
        complete = list(
          n = overall_rates$complete$n,
          estimate = overall_rates$complete$estimate,
          se = overall_rates$complete$se
        ),
        incomplete = list(
          n = overall_rates$incomplete$n,
          estimate = overall_rates$incomplete$estimate,
          se = overall_rates$incomplete$se
        )
      ),
      groups = group_results
    )

    # Recommendation
    if (isTRUE(passed)) {
      recommendation <- paste(
        "Validation passed: Safe to use incomplete trips for CPUE estimation in this dataset",
        "(overall and all groups passed equivalence)"
      )
    } else {
      # A group that failed and a group that could not be tested (NA, one trip
      # type only) are named separately: no test was run on the second.
      label_rows <- function(rows) {
        paste(vapply(which(rows), function(i) tost_group_label(group_results, i, by_vars), ""), collapse = "; ")
      }
      failed <- group_results$equivalence_passed %in% FALSE
      untested <- is.na(group_results$equivalence_passed)
      if (any(failed) || any(untested)) {
        lead <- if (any(failed) || overall_result$equivalence_passed %in% FALSE) {
          "Validation failed: Use complete trips only."
        } else {
          "Not tested: Use complete trips only."
        }
        recommendation <- paste0(
          lead,
          if (any(failed)) paste0(" Groups failed equivalence: ", label_rows(failed), "."),
          if (any(untested)) paste0(" Groups not tested (one trip type only, or no SE): ", label_rows(untested), ".")
        )
      } else if (is.na(overall_result$equivalence_passed)) {
        recommendation <- "Not tested: Use complete trips only (the overall test could not be run)"
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
    joint <- tost_joint_se_diff(design, complete_result, incomplete_result, variance)
    tost_result <- perform_tost(
      complete_estimate = complete_estimate,
      complete_se = complete_se,
      incomplete_estimate = incomplete_estimate,
      incomplete_se = incomplete_se,
      threshold = threshold,
      n_complete = complete_result$estimates$n,
      n_incomplete = incomplete_result$estimates$n,
      se_diff = if (is.null(joint)) NULL else as.numeric(joint),
      df = unname(tost_design_df(design, "all"))
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
    # NA: no test was run (too few df, or no SE -- GH #673), so neither
    # verdict is reported.
    if (is.na(tost_result$equivalence_passed)) {
      recommendation <- "Not tested: Use complete trips only (equivalence could not be tested)"
    } else if (tost_result$equivalence_passed) {
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
perform_overall_tost <- function(
  design,
  catch_quo,
  effort_quo,
  variance,
  conf_level,
  truncate_at,
  threshold
) {
  # Estimate ungrouped complete CPUE
  complete_overall <- suppressMessages(
    estimate_catch_rate(
      # nolint: object_usage_linter
      design,
      variance = variance,
      conf_level = conf_level,
      estimator = "ratio-of-means",
      use_trips = "complete",
      truncate_at = truncate_at
    )
  )

  # Estimate ungrouped incomplete CPUE
  incomplete_overall <- suppressMessages(keep_undefined_draws_warning(
    estimate_catch_rate(
      # nolint: object_usage_linter
      design,
      variance = variance,
      conf_level = conf_level,
      estimator = "mor",
      use_trips = "incomplete",
      truncate_at = truncate_at
    )
  ))

  # Perform TOST
  joint <- tost_joint_se_diff(design, complete_overall, incomplete_overall, variance)
  tost <- perform_tost(
    complete_estimate = complete_overall$estimates$estimate,
    complete_se = complete_overall$estimates$se,
    incomplete_estimate = incomplete_overall$estimates$estimate,
    incomplete_se = incomplete_overall$estimates$se,
    threshold = threshold,
    n_complete = complete_overall$estimates$n,
    n_incomplete = incomplete_overall$estimates$n,
    se_diff = if (is.null(joint)) NULL else as.numeric(joint),
    df = unname(tost_design_df(design, "all"))
  )
  # The overall rates themselves, for the grouped result's metadata: the test
  # above is of these, not of an average of the group rates (GH #669).
  attr(tost, "rates") <- list(complete = complete_overall$estimates, incomplete = incomplete_overall$estimates)
  tost
}

#' Label one group's `by` values, e.g. `"day_type = weekend, gear = boat"`
#'
#' Column by column, so a factor prints its level and a Date its date (pasting
#' a data-frame row, or `unlist()`-ing one, prints factor codes and day
#' numbers), and an unknown value prints as `<unknown>`, apart from a group
#' genuinely labelled `"NA"`.
#' @keywords internal
#' @noRd
tost_group_label <- function(groups, i, by_vars) {
  vals <- vapply(by_vars, function(v) as.character(groups[[v]][i]), "")
  vals[is.na(vals)] <- "<unknown>"
  paste(by_vars, "=", vals, collapse = ", ")
}

#' Pair the complete-trip and incomplete-trip rows of each group by key
#'
#' Internal. The two grouped estimates are separate `estimate_catch_rate()`
#' calls, each reporting only the groups its own trips fall in, so row i of one
#' is not row i of the other. They were paired by position, which compared one
#' group's complete trips with another group's incomplete trips whenever a
#' group held only one trip type -- and reported the result as that group's
#' test.
#'
#' @return A list: `keys` (one per group, in first-seen order), `groups` (the
#'   `by_vars` columns), `complete` and `incomplete` (each side's estimate rows
#'   aligned to `keys`, all-`NA` where that side has no such group), and
#'   `has_complete`, `has_incomplete`.
#' @keywords internal
#' @noRd
align_tost_groups <- function(complete_df, incomplete_df, by_vars) {
  keys_c <- group_key(complete_df, by_vars) # nolint: object_usage_linter
  keys_i <- group_key(incomplete_df, by_vars) # nolint: object_usage_linter
  keys <- union(keys_c, keys_i)
  both <- rbind(
    as.data.frame(complete_df)[by_vars],
    as.data.frame(incomplete_df)[by_vars]
  )
  groups <- both[match(keys, c(keys_c, keys_i)), , drop = FALSE]
  rownames(groups) <- NULL
  ic <- match(keys, keys_c)
  ii <- match(keys, keys_i)
  list(
    keys = keys,
    groups = groups,
    complete = as.data.frame(complete_df)[ic, , drop = FALSE],
    incomplete = as.data.frame(incomplete_df)[ii, , drop = FALSE],
    has_complete = !is.na(ic),
    has_incomplete = !is.na(ii)
  )
}

#' Perform TOST for each group
#'
#' A group holding only one trip type cannot be tested: its row is `NA`, with
#' a warning, and counts as not passing.
#'
#' @param design The design, for the degrees of freedom.
#' @param joint From `tost_joint_se_diff()`: SEs of the difference keyed as
#'   `align_tost_groups()` keys the groups; `NULL` where the variances are
#'   added.
#' @keywords internal
#' @noRd
perform_grouped_tost <- function(design, complete_result, incomplete_result, by_vars, threshold,
                                 joint = NULL) {
  al <- align_tost_groups(complete_result$estimates, incomplete_result$estimates, by_vars)
  design_df <- tost_design_df(design, al$keys, by_vars)
  cdf <- al$complete
  idf <- al$incomplete

  # Initialize result data frame. NA, not 0: a group that cannot be tested has
  # no p-value and no difference, and a zero would read as a result.
  group_results <- al$groups
  n <- nrow(group_results)
  group_results$p_lower <- rep(NA_real_, n)
  group_results$p_upper <- rep(NA_real_, n)
  group_results$equivalence_passed <- rep(NA, n)
  group_results$diff_estimate <- rep(NA_real_, n)
  group_results$equivalence_lower <- rep(NA_real_, n)
  group_results$equivalence_upper <- rep(NA_real_, n)

  for (i in seq_len(n)) {
    if (!al$has_complete[i] || !al$has_incomplete[i]) {
      label <- tost_group_label(group_results, i, by_vars) # nolint: object_usage_linter
      missing_type <- if (!al$has_complete[i]) "complete" else "incomplete" # nolint: object_usage_linter
      creel_warn( # nolint: object_usage_linter
        c(
          "TOST: group {label} has no {missing_type} trips; equivalence cannot be tested for it.",
          "i" = "Its row is NA and the validation does not pass."
        ),
        class = c("creel_warning_tost_degenerate", "creel_warn_tost_degenerate", "creel_warning")
      )
      next
    }
    tost_result <- perform_tost(
      complete_estimate = cdf$estimate[i],
      complete_se = cdf$se[i],
      incomplete_estimate = idf$estimate[i],
      incomplete_se = idf$se[i],
      threshold = threshold,
      n_complete = cdf$n[i],
      n_incomplete = idf$n[i],
      se_diff = if (is.null(joint)) NULL else unname(joint[al$keys[i]]),
      df = unname(design_df[al$keys[i]])
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

#' Standard error of the complete-minus-incomplete difference, jointly
#'
#' Internal (GH #664). The complete-trip and incomplete-trip rates come from
#' disjoint interviews, but the interview variance is clustered on the survey
#' day (GH #661): trips interviewed on the same days move with those days'
#' conditions, so the two rates covary. Adding their variances, as if they were
#' independent, overstates the SE of the difference -- to the point of failing
#' equivalence for two rates that track each other day by day.
#'
#' Both rates are re-expressed as domain ratios on one survey of every
#' interviewed day: the complete rate as sum(y) / sum(x) over complete trips,
#' the incomplete rate as sum(n r) / sum(n) over incomplete trips (the
#' mean of ratios, party-size weighted exactly when the estimator weights it).
#' One `svyratio(covmat = TRUE)` returns both with their covariance, under the
#' requested variance method. The joint point estimates must equal the ones
#' `estimate_catch_rate()` reported; a disagreement means the two saw different
#' interviews and is an internal error.
#'
#' @param design The design `validate_incomplete_trips()` was given.
#' @param complete_result,incomplete_result The two `estimate_catch_rate()`
#'   results being compared.
#' @param variance Variance method.
#' @param by_vars Grouping columns, or `NULL` for the overall test.
#' @return Named numeric vector of SEs of the difference, one per group as
#'   `align_tost_groups()` keys them (`"all"` when ungrouped); `NA` for a group
#'   holding one trip type.
#' @keywords internal
#' @noRd
tost_joint_se_diff <- function(design, complete_result, incomplete_result, variance, by_vars = NULL) {
  # Bus-route and ice rates are Horvitz-Thompson ratios over their own
  # day-clustered survey (br_add_psu_key()), which this fit does not model, so
  # NULL tells perform_tost() to add the two variances. Their rates share days
  # too, so the sum overstates the SE of the difference -- conservative for an
  # equivalence test, but not the joint SE (GH #671).
  if ((design$design_type %||% "instantaneous") %in% c("bus_route", "ice")) {
    return(NULL)
  }
  catch_col <- design$catch_col
  effort_col <- design$angler_effort_col
  usable <- function(df) {
    e <- df[[effort_col]]
    df[!is.na(e) & e != 0, , drop = FALSE]
  }
  comp <- usable(complete_result$design$interviews)
  inc <- usable(incomplete_result$design$interviews)
  inc$cpue_ratio <- inc[[catch_col]] / inc[[effort_col]]
  w <- mor_party_weights(incomplete_result$design, inc, "cpue_ratio") # nolint: object_usage_linter
  inc_num <- if (w$weighted) w$data$.mor_num else inc$cpue_ratio
  inc_den <- if (w$weighted) w$data$.mor_n else rep(1, nrow(inc))

  cols <- intersect(names(comp), names(inc))
  joint <- rbind(comp[cols], inc[cols])
  n_c <- nrow(comp)
  n_i <- nrow(inc)
  # Domain variables. A trip outside a rate's domain contributes nothing to
  # that rate's numerator or denominator: the zero is the domain indicator, not
  # an unknown value (an incomplete trip's catch is known, and is not this
  # complete-trip rate's to count).
  c_num <- c(comp[[catch_col]], rep(0, n_i))
  c_den <- c(comp[[effort_col]], rep(0, n_i))
  i_num <- c(rep(0, n_c), inc_num)
  i_den <- c(rep(0, n_c), inc_den)

  # Names no user column can already hold, so a stratum or by= column is
  # never overwritten by a domain variable.
  nm <- utils::tail(make.unique(c(names(joint), ".tost_cn", ".tost_cd", ".tost_in", ".tost_id")), 4L)
  joint[[nm[1]]] <- c_num
  joint[[nm[2]]] <- c_den
  joint[[nm[3]]] <- i_num
  joint[[nm[4]]] <- i_den
  num_f <- stats::reformulate(c(nm[1], nm[3]))
  den_f <- stats::reformulate(c(nm[2], nm[4]))
  ratio_nm <- c(paste0(nm[1], "/", nm[2]), paste0(nm[3], "/", nm[4]))

  strata_cols <- design$strata_cols
  strata_formula <- if (length(strata_cols) > 0L) stats::reformulate(strata_cols) else NULL
  svy <- build_interview_survey( # nolint: object_usage_linter
    joint,
    strata = strata_formula,
    psu = interview_psu_col(design, joint), frame = interview_day_frame(design) # nolint: object_usage_linter
  )
  svy <- get_variance_design(svy, variance) # nolint: object_usage_linter

  al <- if (is.null(by_vars)) {
    list(
      keys = "all", complete = as.data.frame(complete_result$estimates),
      incomplete = as.data.frame(incomplete_result$estimates),
      has_complete = TRUE, has_incomplete = TRUE
    )
  } else {
    align_tost_groups(complete_result$estimates, incomplete_result$estimates, by_vars)
  }
  in_group <- if (is.null(by_vars)) {
    function(k) rep(TRUE, nrow(svy$variables))
  } else {
    function(k) group_key(svy$variables, by_vars) == k # nolint: object_usage_linter
  }
  out <- vapply(seq_along(al$keys), function(i) {
    # A group with one trip type has no difference to test.
    if (!al$has_complete[i] || !al$has_incomplete[i]) {
      return(NA_real_)
    }
    k <- al$keys[[i]]
    g <- in_group(k)
    vars <- svy$variables
    vars[[nm[1]]] <- vars[[nm[1]]] * g
    vars[[nm[2]]] <- vars[[nm[2]]] * g
    vars[[nm[3]]] <- vars[[nm[3]]] * g
    vars[[nm[4]]] <- vars[[nm[4]]] * g
    svy_k <- svy
    svy_k$variables <- vars
    # The group is kept by zeroing the other rows, not by subsetting, so it is
    # named here rather than from the design's first row.
    label <- if (is.null(by_vars)) NULL else tost_group_label(al$groups, i, by_vars) # nolint: object_usage_linter
    fit <- with_defined_draws(suppressWarnings( # nolint: object_usage_linter
      draws_defined(survey::svyratio, label = label)( # nolint: object_usage_linter
        num_f, svy_k,
        denominator = den_f, covmat = TRUE
      )
    ))
    est <- stats::coef(fit)[ratio_nm]
    v <- stats::vcov(fit)[ratio_nm, ratio_nm]
    reported <- c(al$complete$estimate[i], al$incomplete$estimate[i])
    if (!isTRUE(all.equal(unname(est), reported, tolerance = 1e-8))) {
      cli::cli_abort(
        "Internal error: the joint complete/incomplete rates disagree with the reported ones.",
        .internal = TRUE
      )
    }
    sqrt(max(0, v[1, 1] + v[2, 2] - 2 * v[1, 2]))
  }, numeric(1))
  stats::setNames(out, al$keys)
}

#' Design degrees of freedom of each TOST comparison
#'
#' Internal (GH #669). The variance of the difference is between days, so its
#' degrees of freedom are days minus strata -- counted over the strata the
#' comparison draws on. A stratum holding none of a group's trips contributes
#' nothing to that group's variance and no degrees of freedom; within a
#' stratum it does draw on, every interviewed day counts, including days
#' without the group's trips (a domain is estimated over all of them). Not
#' `survey::degf()` of the domain subset, which counts only the days holding
#' domain rows. The same on every design: bus-route and ice rates are
#' clustered on the day too.
#'
#' @param design The design `validate_incomplete_trips()` was given.
#' @param keys Group keys as `align_tost_groups()` makes them, or `"all"`.
#' @param by_vars Grouping columns, or `NULL`.
#' @return Named integer vector of degrees of freedom, one per key.
#' @keywords internal
#' @noRd
tost_design_df <- function(design, keys, by_vars = NULL) {
  iv <- design$interviews
  ts <- design$trip_status_col
  iv <- iv[!is.na(iv[[ts]]) & iv[[ts]] %in% c("complete", "incomplete"), , drop = FALSE]
  strata_cols <- design$strata_cols %||% character(0)
  stratum_of <- function(df) {
    if (length(strata_cols) == 0L) rep("all", nrow(df)) else group_key(df, strata_cols) # nolint: object_usage_linter
  }
  days <- unique(design$interviews[c(strata_cols, design$date_col)])
  day_stratum <- stratum_of(days)
  row_key <- if (is.null(by_vars)) rep("all", nrow(iv)) else group_key(iv, by_vars) # nolint: object_usage_linter
  row_stratum <- stratum_of(iv)
  out <- vapply(keys, function(k) {
    used <- unique(row_stratum[row_key == k])
    as.integer(sum(day_stratum %in% used) - length(used))
  }, integer(1))
  stats::setNames(out, keys)
}

#' Perform TOST (Two One-Sided Tests) equivalence testing
#'
#' Implements TOST to test equivalence between complete and incomplete trip
#' CPUE estimates. Returns p-values for both one-sided tests and overall
#' equivalence conclusion.
#'
#' @keywords internal
#' @noRd
perform_tost <- function(
  complete_estimate,
  complete_se,
  incomplete_estimate,
  incomplete_se,
  threshold,
  n_complete,
  n_incomplete,
  se_diff = NULL,
  df = NULL
) {
  # Calculate difference and bounds
  diff_estimate <- complete_estimate - incomplete_estimate
  equivalence_lower <- -threshold * abs(complete_estimate)
  equivalence_upper <- threshold * abs(complete_estimate)

  # The SE of the difference comes from the joint fit (tost_joint_se_diff()),
  # which carries the two rates' covariance through their shared days
  # (GH #664). Adding the variances is the fallback for callers without one,
  # and is right only for rates from independent samples.
  if (is.null(se_diff)) {
    se_diff <- sqrt(complete_se^2 + incomplete_se^2)
  }

  # Degrees of freedom: the design's -- interviewed days minus strata, since
  # the variance is between days (tost_design_df(), GH #669). The interview
  # count is only the fallback for a caller without them.
  if (is.null(df)) {
    df <- min(n_complete - 1, n_incomplete - 1)
  }

  # An unknown SE -- a bootstrap draw that missed one trip type (GH #673) --
  # leaves equivalence untested, not passed or failed.
  if (is.na(se_diff)) {
    return(list(
      p_lower = NA_real_,
      p_upper = NA_real_,
      equivalence_passed = NA,
      diff_estimate = diff_estimate,
      equivalence_lower = equivalence_lower,
      equivalence_upper = equivalence_upper,
      se_diff = se_diff,
      df = df
    ))
  }

  # Guard: se_diff == 0 (both groups have identical estimates with zero SE)
  # → t-statistics are ±Inf; treat as trivially equivalent if diff is within bounds.
  if (se_diff == 0) {
    equivalence_passed <- (diff_estimate >= equivalence_lower) &&
      (diff_estimate <= equivalence_upper)
    return(list(
      p_lower = if (equivalence_passed) 0 else 1,
      p_upper = if (equivalence_passed) 0 else 1,
      equivalence_passed = equivalence_passed,
      diff_estimate = diff_estimate,
      equivalence_lower = equivalence_lower,
      equivalence_upper = equivalence_upper,
      se_diff = se_diff,
      df = df
    ))
  }

  # Guard: df <= 0 (n=1 in one or both groups) → cannot compute t-distribution
  if (df <= 0L) {
    creel_warn(
      "TOST: insufficient degrees of freedom (df={df}); equivalence cannot be tested.",
      class = c("creel_warning_tost_degenerate", "creel_warn_tost_degenerate", "creel_warning")
    )
    return(list(
      p_lower = NA_real_,
      p_upper = NA_real_,
      equivalence_passed = NA,
      diff_estimate = diff_estimate,
      equivalence_lower = equivalence_lower,
      equivalence_upper = equivalence_upper,
      se_diff = se_diff,
      df = df
    ))
  }

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

  output <- c(
    output,
    cli::cli_format_method({
      cli::cli_h1("TOST Equivalence Validation Results")
      cli::cli_text(
        "Threshold: \u00b1{round(x$equivalence_threshold * 100, 1)}% of complete trip estimate"
      )

      # Overall status
      if (isTRUE(x$passed)) {
        cli::cli_alert_success("Validation PASSED")
      } else if (is.na(x$passed)) {
        cli::cli_alert_warning("Validation NOT TESTED")
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

      cli::cli_text(
        "Complete trips: n = {complete_meta$n}, CPUE = {round(complete_meta$estimate, 3)}"
      )
      cli::cli_text(
        "Incomplete trips: n = {incomplete_meta$n}, CPUE = {round(incomplete_meta$estimate, 3)}"
      )
      cli::cli_text("Difference: {round(x$overall_test$diff_estimate, 3)}")
      equiv_lower <- round(x$overall_test$equivalence_lower, 3) # nolint: object_usage_linter
      equiv_upper <- round(x$overall_test$equivalence_upper, 3) # nolint: object_usage_linter
      p_lower <- round(x$overall_test$p_lower, 4) # nolint: object_usage_linter
      p_upper <- round(x$overall_test$p_upper, 4) # nolint: object_usage_linter
      cli::cli_text("Equivalence bounds: [{equiv_lower}, {equiv_upper}]")
      cli::cli_text("TOST p-values: p_lower = {p_lower}, p_upper = {p_upper}")

      if (isTRUE(x$overall_test$equivalence_passed)) {
        cli::cli_alert_success("Overall equivalence: PASSED")
      } else if (is.na(x$overall_test$equivalence_passed)) {
        cli::cli_alert_warning("Overall equivalence: NOT TESTED")
      } else {
        cli::cli_alert_danger("Overall equivalence: FAILED")
      }

      # Group results if present
      if (!is.null(x$group_tests)) {
        cli::cli_text("")
        cli::cli_h2("Per-Group Tests")
        n_groups <- nrow(x$group_tests) # nolint: object_usage_linter
        n_passed <- sum(vapply(x$group_tests$equivalence_passed, isTRUE, logical(1))) # nolint: object_usage_linter
        cli::cli_text("{n_passed}/{n_groups} group{?s} passed equivalence")
        n_untested <- sum(is.na(x$group_tests$equivalence_passed))
        if (n_untested > 0L) {
          cli::cli_alert_warning("{n_untested} group{?s} could not be tested (one trip type only, or no SE)")
        }
      }
    })
  )

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

  # Set up plot margins, restoring the caller's settings on exit
  old_par <- graphics::par(mar = c(5, 5, 4, 2) + 0.1)
  on.exit(graphics::par(old_par), add = TRUE)

  # Determine axis ranges (include CI bounds)
  x_range <- range(
    c(
      plot_data$complete_est,
      plot_data$complete_ci_lower,
      plot_data$complete_ci_upper
    ),
    na.rm = TRUE
  )

  y_range <- range(
    c(
      plot_data$incomplete_est,
      plot_data$incomplete_ci_lower,
      plot_data$incomplete_ci_upper
    ),
    na.rm = TRUE
  )

  # Ensure ranges are equal (square plot)
  all_range <- range(c(x_range, y_range))
  x_range <- all_range
  y_range <- all_range

  # Create color scheme: blue for passed, red for failed, grey for untested.
  # A group with one trip type has one coordinate missing and no point to
  # draw; a test with no SE (GH #673) has both and is drawn as untested.
  passed_ok <- vapply(plot_data$passed, isTRUE, logical(1))
  untested <- is.na(plot_data$passed)
  point_colors <- ifelse(passed_ok, "#0066CC", ifelse(untested, "gray40", "#CC0000"))

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
  if (any(!passed_ok)) {
    failed_indices <- which(!passed_ok)
    for (i in failed_indices) {
      label_text <- if (!is.null(plot_data$group_labels)) {
        plot_data$group_labels[i]
      } else if (untested[i]) {
        "NOT TESTED"
      } else {
        "FAILED"
      }

      # Position label above point
      graphics::text(
        x = plot_data$complete_est[i],
        y = plot_data$incomplete_est[i],
        labels = label_text,
        pos = 3, # above
        col = point_colors[i],
        cex = 0.8,
        font = 2 # bold
      )
    }
  }

  # Add legend
  graphics::legend(
    "topleft",
    legend = c("Passed equivalence", "Failed equivalence", "Not tested", "y=x reference"),
    col = c("#0066CC", "#CC0000", "gray40", "gray50"),
    pch = c(19, 19, 19, NA),
    lty = c(NA, NA, NA, 2),
    lwd = c(NA, NA, NA, 2),
    bty = "n",
    cex = 0.9
  )

  invisible(x)
}
