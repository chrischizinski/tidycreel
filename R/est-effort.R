#' Estimate Fishing Effort via Roving (Creel Clerk) Count
#'
#' Design-based estimator for angler-hours using roving counts (creel clerk method).
#' Supports grouping, variance estimation, and diagnostics.
#'
#' @param counts Data frame of roving counts
#' @param by Character vector of grouping variables (default: c("date", "shift_block", "location"))
#' @param minutes_col Name of column with count duration (default: c("count_duration", "interval_minutes"))
#' @param svy Optional survey design object for variance estimation
#' @param conf_level Confidence level for CI (default: 0.95)
#' @param ... Additional arguments
#' @return Tibble with estimate, SE, CI, n, method, diagnostics
est_effort_roving <- function(counts,
  by = c("date", "shift_block", "location"),
  minutes_col = c("count_duration", "interval_minutes"),
  svy = NULL,
  conf_level = 0.95,
  ...
) {
  # Validate columns
  min_col <- minutes_col[which(minutes_col %in% names(counts))]
  if (length(min_col) == 0) {
    stop("Missing columns in roving effort: one of ", paste(minutes_col, collapse = ", "))
  }
  cols_needed <- c("count", min_col[1])
  tc_require_cols(counts, cols_needed, context = "roving effort")
  # Grouping
  by <- tc_group_warn(by, names(counts))
  grouped <- dplyr::group_by(counts, dplyr::across(dplyr::all_of(by)))
  summarised <- dplyr::summarise(grouped,
    mean_count = mean(count, na.rm = TRUE),
    total_minutes = sum(.data[[min_col[1]]], na.rm = TRUE),
    n = dplyr::n()
  )
  summarised$estimate <- summarised$mean_count * summarised$total_minutes / 60
  if (!is.null(svy)) {
    est <- survey::svytotal(~count, svy, na.rm = TRUE)
    se <- as.numeric(attr(est, "var"))^0.5
    ci <- tc_confint(as.numeric(est), se, level = conf_level)
    summarised$se <- se
    summarised$ci_low <- ci[1]
    summarised$ci_high <- ci[2]
  } else {
    if (nrow(summarised) == 1) {
      summarised$se <- NA_real_
      summarised$ci_low <- NA_real_
      summarised$ci_high <- NA_real_
    } else {
      se <- sd(summarised$estimate, na.rm = TRUE) / sqrt(summarised$n)
      ci <- tc_confint(summarised$estimate, se, level = conf_level)
      summarised$se <- se
      summarised$ci_low <- ci[1]
      summarised$ci_high <- ci[2]
    }
  }
  summarised$method <- "roving"
  summarised$diagnostics <- list(NULL)
  summarised
}
#' Estimate Fishing Effort via Aerial (Remote Sensing) Count
#'
#' Design-based estimator for angler-hours using aerial counts (remote sensing).
#' Supports grouping, variance estimation, and diagnostics.
#'
#' @param counts Data frame of aerial counts
#' @param by Character vector of grouping variables (default: c("date", "shift_block", "location"))
#' @param minutes_col Name of column with count duration (default: c("count_duration", "interval_minutes"))
#' @param svy Optional survey design object for variance estimation
#' @param conf_level Confidence level for CI (default: 0.95)
#' @param ... Additional arguments
#' @return Tibble with estimate, SE, CI, n, method, diagnostics
est_effort_aerial <- function(counts,
  by = c("date", "shift_block", "location"),
  minutes_col = c("count_duration", "interval_minutes"),
  svy = NULL,
  conf_level = 0.95,
  ...
) {
  # Validate columns
  min_col <- minutes_col[which(minutes_col %in% names(counts))]
  if (length(min_col) == 0) {
    stop("Missing columns in aerial effort: one of ", paste(minutes_col, collapse = ", "))
  }
  cols_needed <- c("count", min_col[1])
  tc_require_cols(counts, cols_needed, context = "aerial effort")
  # Grouping
  by <- tc_group_warn(by, names(counts))
  grouped <- dplyr::group_by(counts, dplyr::across(dplyr::all_of(by)))
  summarised <- dplyr::summarise(grouped,
    mean_count = mean(count, na.rm = TRUE),
    total_minutes = sum(.data[[min_col[1]]], na.rm = TRUE),
    n = dplyr::n()
  )
  summarised$estimate <- summarised$mean_count * summarised$total_minutes / 60
  if (!is.null(svy)) {
    est <- survey::svytotal(~count, svy, na.rm = TRUE)
    se <- as.numeric(attr(est, "var"))^0.5
    ci <- tc_confint(as.numeric(est), se, level = conf_level)
    summarised$se <- se
    summarised$ci_low <- ci[1]
    summarised$ci_high <- ci[2]
  } else {
    if (nrow(summarised) == 1) {
      summarised$se <- NA_real_
      summarised$ci_low <- NA_real_
      summarised$ci_high <- NA_real_
    } else {
      se <- sd(summarised$estimate, na.rm = TRUE) / sqrt(summarised$n)
      ci <- tc_confint(summarised$estimate, se, level = conf_level)
      summarised$se <- se
      summarised$ci_low <- ci[1]
      summarised$ci_high <- ci[2]
    }
  }
  summarised$method <- "aerial"
  summarised$diagnostics <- list(NULL)
  summarised
}
#' Estimate Fishing Effort via Progressive (Bus-Route) Count
#'
#' Design-based estimator for angler-hours using progressive counts (bus-route method).
#' Supports grouping, variance estimation, and diagnostics.
#'
#' @param counts Data frame of progressive counts
#' @param by Character vector of grouping variables (default: c("date", "shift_block", "location"))
#' @param minutes_col Name of column with count duration (default: c("count_duration", "interval_minutes"))
#' @param svy Optional survey design object for variance estimation
#' @param conf_level Confidence level for CI (default: 0.95)
#' @param ... Additional arguments
#' @return Tibble with estimate, SE, CI, n, method, diagnostics
est_effort_progressive <- function(counts,
  by = c("date", "shift_block", "location"),
  minutes_col = c("count_duration", "interval_minutes"),
  svy = NULL,
  conf_level = 0.95,
  ...
) {
  # Validate columns
  min_col <- minutes_col[which(minutes_col %in% names(counts))]
  if (length(min_col) == 0) {
    stop("Missing columns in progressive effort: one of ", paste(minutes_col, collapse = ", "))
  }
  cols_needed <- c("count", min_col[1])
  tc_require_cols(counts, cols_needed, context = "progressive effort")
  # Grouping
  by <- tc_group_warn(by, names(counts))
  grouped <- dplyr::group_by(counts, dplyr::across(dplyr::all_of(by)))
  summarised <- dplyr::summarise(grouped,
    total_count = sum(count, na.rm = TRUE),
    total_minutes = sum(.data[[min_col[1]]], na.rm = TRUE),
    n = dplyr::n()
  )
  summarised$estimate <- summarised$total_count * summarised$total_minutes / (summarised$n * 60)
  if (!is.null(svy)) {
    est <- survey::svytotal(~count, svy, na.rm = TRUE)
    se <- as.numeric(attr(est, "var"))^0.5
    ci <- tc_confint(as.numeric(est), se, level = conf_level)
    summarised$se <- se
    summarised$ci_low <- ci[1]
    summarised$ci_high <- ci[2]
  } else {
    if (nrow(summarised) == 1) {
      summarised$se <- NA_real_
      summarised$ci_low <- NA_real_
      summarised$ci_high <- NA_real_
    } else {
      se <- sd(summarised$estimate, na.rm = TRUE) / sqrt(summarised$n)
      ci <- tc_confint(summarised$estimate, se, level = conf_level)
      summarised$se <- se
      summarised$ci_low <- ci[1]
      summarised$ci_high <- ci[2]
    }
  }
  summarised$method <- "progressive"
  summarised$diagnostics <- list(NULL)
  summarised
}
#' Estimate Fishing Effort via Instantaneous Count
#'
#' Implements the mean count method for instantaneous (snapshot) creel surveys.
#' Supports visibility adjustment, flexible grouping, and design-based variance estimation.
#'
#' @param counts Data frame of instantaneous counts (one row per count event)
#' @param by Character vector of grouping variables (default: c("date", "shift_block", "location"))
#' @param minutes_col Name of column with count duration (default: c("count_duration", "interval_minutes"))
#' @param visibility_col Optional column for visibility proportion (0-1)
#' @param svy Optional survey design object for variance estimation
#' @param conf_level Confidence level for CI (default: 0.95)
#' @param ... Additional arguments
#' @return Tibble with estimate, SE, CI, n, method, diagnostics
est_effort_instantaneous <- function(counts,
  by = c("date", "shift_block", "location"),
  minutes_col = c("count_duration", "interval_minutes"),
  visibility_col = NULL,
  svy = NULL,
  conf_level = 0.95,
  ...
) {
  # Validate columns
  # Accept either count_duration or interval_minutes
  min_col <- minutes_col[which(minutes_col %in% names(counts))]
  if (length(min_col) == 0) {
    stop("Missing columns in instantaneous effort: one of ", paste(minutes_col, collapse = ", "))
  }
  cols_needed <- c("count", min_col[1])
  tc_require_cols(counts, cols_needed, context = "instantaneous effort")
  # Visibility adjustment
  if (!is.null(visibility_col) && visibility_col %in% names(counts)) {
    counts$count <- counts$count / pmax(counts[[visibility_col]], 0.1)
    counts$count <- pmin(counts$count, counts$count * 2) # cap at 2x
  }
  # Grouping
  by <- tc_group_warn(by, names(counts))
  grouped <- dplyr::group_by(counts, dplyr::across(dplyr::all_of(by)))
  summarised <- dplyr::summarise(grouped,
    mean_count = mean(count, na.rm = TRUE),
    total_minutes = sum(.data[[min_col[1]]], na.rm = TRUE),
    n = dplyr::n()
  )
  summarised$estimate <- summarised$mean_count * summarised$total_minutes / 60
  if (!is.null(svy)) {
    est <- survey::svytotal(~count, svy, na.rm = TRUE)
    se <- as.numeric(attr(est, "var"))^0.5
    ci <- tc_confint(as.numeric(est), se, level = conf_level)
    summarised$se <- se
    summarised$ci_low <- ci[1]
    summarised$ci_high <- ci[2]
  } else {
    if (nrow(summarised) == 1) {
      summarised$se <- NA_real_
      summarised$ci_low <- NA_real_
      summarised$ci_high <- NA_real_
    } else {
      se <- sd(summarised$estimate, na.rm = TRUE) / sqrt(summarised$n)
      ci <- tc_confint(summarised$estimate, se, level = conf_level)
      summarised$se <- se
      summarised$ci_low <- ci[1]
      summarised$ci_high <- ci[2]
    }
  }
  summarised$method <- "instantaneous"
  summarised$diagnostics <- list(NULL)
  summarised
}
