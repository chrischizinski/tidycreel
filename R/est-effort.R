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
  method <- match.arg(method)

  # Prefer counts embedded in the design; else, require counts param
  if (is.null(counts) && !is.null(x$counts)) counts <- x$counts
  if (is.null(counts)) stop("Counts data must be supplied via `counts` or present in the design object as `$counts`.")

  # Choose grouping variables that actually exist
  by <- intersect(by, names(counts))
  if (length(by) == 0) {
    warning("None of the default grouping vars were found; aggregating all counts together.")
  }

  # Standardize expected columns
  required_any <- c("time", "count", "anglers_count")
  if (!any(required_any %in% names(counts))) {
    stop("Counts must have a `count` column (or `anglers_count`).")
  }
  if (!"count" %in% names(counts) && "anglers_count" %in% names(counts)) {
    counts$count <- counts$anglers_count
  }

  # Diagnostics: dropped rows due to NA in required columns
  required_cols <- c(by, "count")
  if (method == "instantaneous") required_cols <- c(required_cols, "count_duration", "interval_minutes")
  if (method == "progressive") required_cols <- c(required_cols, "time", "timestamp")
  required_cols <- unique(required_cols[required_cols %in% names(counts)])
  na_rows <- !stats::complete.cases(counts[required_cols])
  n_dropped <- sum(na_rows)
  if (n_dropped > 0) warning(sprintf("Dropped %d rows with missing required values for effort estimation.", n_dropped))
  counts_clean <- counts[!na_rows, , drop = FALSE]

  # Helper: as tibble without depending on tibble at runtime
  as_tb <- function(df) {
    if (requireNamespace("tibble", quietly = TRUE)) tibble::as_tibble(df) else df
  }

  # Group/summarize
  if (method == "instantaneous") {
    dur_col <- if ("count_duration" %in% names(counts_clean)) "count_duration" else if ("interval_minutes" %in% names(counts_clean)) "interval_minutes" else NULL
    if (is.null(dur_col)) stop("For instantaneous method, counts require `count_duration` or `interval_minutes` (in minutes).")
    agg <- as_tb(stats::aggregate(counts_clean[c("count", dur_col)],
                                  by = counts_clean[by],
                                  FUN = sum, na.rm = TRUE))
    names(agg)[names(agg) == dur_col] <- "interval_minutes"
    agg$estimate <- (agg$count * agg$interval_minutes) / 60

    # Basic diagnostics
    agg$n <- as.integer(stats::aggregate(count ~ ., data = counts_clean[c(by, "count")], FUN = length)$count)

    # Placeholder SE/CI (TODO: add survey-based variance when time-sampling weights are available)
    agg$se <- NA_real_
    agg$ci_low <- NA_real_
    agg$ci_high <- NA_real_
    agg$method <- "instantaneous"
    agg$diagnostics <- sprintf("Dropped rows: %d", n_dropped)

    out <- agg[c(by, "estimate", "se", "ci_low", "ci_high", "n", "method", "diagnostics")]
    return(out)
  }

  if (method == "progressive") {
    df <- counts_clean
    time_col <- if ("time" %in% names(df)) "time" else "timestamp"
    if (is.null(time_col)) stop("For progressive method, counts require a `time` or `timestamp` column.")

    # Coerce time to POSIXct if not already
    if (!inherits(df[[time_col]], c("POSIXct", "POSIXt"))) {
      if (requireNamespace("lubridate", quietly = TRUE)) {
        df[[time_col]] <- lubridate::ymd_hms(df[[time_col]], quiet = TRUE)
      } else {
        df[[time_col]] <- as.POSIXct(df[[time_col]])
      }
    }

    split_keys <- if (length(by)) interaction(df[by], drop = TRUE) else factor(1L)
    idx <- split(seq_len(nrow(df)), split_keys)

    estimates <- lapply(idx, function(ix) {
      d <- df[ix, , drop = FALSE]
      d <- d[order(d[[time_col]]), , drop = FALSE]
      if (nrow(d) < 2) return(list(estimate = NA_real_, n = nrow(d), diagnostics = "Insufficient data for integration"))
      dt_min <- as.numeric(diff(d[[time_col]]), units = "mins")
      est_min <- sum((head(d$count, -1) + tail(d$count, 1)) / 2 * dt_min, na.rm = TRUE)
      list(estimate = est_min / 60, n = nrow(d), diagnostics = sprintf("Dropped rows: %d", n_dropped))
    })

    est_vec <- vapply(estimates, function(z) z$estimate, numeric(1))
    n_vec <- vapply(estimates, function(z) z$n, integer(1))
    diag_vec <- vapply(estimates, function(z) z$diagnostics, character(1))

    out <- as_tb(unique(df[if (length(by)) by else NULL]))
    if (!length(by)) out <- data.frame(dummy = 1)[FALSE, ]
    out$estimate <- est_vec
    out$se <- NA_real_  # TODO: add variance via replicate designs or model-based SE
    out$ci_low <- NA_real_
    out$ci_high <- NA_real_
    out$n <- n_vec
    out$method <- "progressive"
    out$diagnostics <- diag_vec

    # Reattach by-columns explicitly
    if (length(by)) {
      levs <- levels(split_keys)
      if (length(levs) == nrow(out)) {
        by_df <- utils::read.table(text = gsub("^", "", levs), sep = ".", col.names = by, stringsAsFactors = FALSE)
        suppressWarnings({
          for (j in seq_along(by)) if (!by[j] %in% names(out)) out[[by[j]]] <- by_df[[j]]
        })
      }
    }

    cols <- c(by, "estimate", "se", "ci_low", "ci_high", "n", "method", "diagnostics")
    cols <- unique(cols[cols %in% names(out)])
    out <- out[cols]
    return(out)
  }

  stop("Unknown method.")
      se <- NA_real_
      ci_low <- NA_real_
      ci_high <- NA_real_
      if (survey_avail && !is.null(x$weights)) {
        svy <- survey::svydesign(ids = ~1, weights = x$weights[ix], data = d)
        total <- survey::svytotal(~I((count * dt_min) / 60), svy)
        est_hr <- as.numeric(total)
        se <- as.numeric(survey::SE(total))
        ci <- survey::confint(total, level = conf_level)
        ci_low <- ci[1]
        ci_high <- ci[2]
      } else if (has_replicates && survey_avail) {
        rep_cols <- grep("^rw_", names(d), value = TRUE)
        if (length(rep_cols) > 0) {
          repweights <- as.matrix(d[rep_cols])
          svy <- survey::svrepdesign(weights = x$weights[ix], repweights = repweights, type = "bootstrap", data = d)
          total <- survey::svytotal(~I((count * dt_min) / 60), svy)
          est_hr <- as.numeric(total)
          se <- as.numeric(survey::SE(total))
          ci <- survey::confint(total, level = conf_level)
          ci_low <- ci[1]
          ci_high <- ci[2]
        }
      }
      list(estimate = est_hr, n = nrow(d), se = se, ci_low = ci_low, ci_high = ci_high)
    })

    est_vec <- vapply(estimates, function(z) z$estimate, numeric(1))
    n_vec <- vapply(estimates, function(z) z$n, integer(1))
    se_vec <- vapply(estimates, function(z) z$se, numeric(1))
    ci_low_vec <- vapply(estimates, function(z) z$ci_low, numeric(1))
    ci_high_vec <- vapply(estimates, function(z) z$ci_high, numeric(1))

    out <- as_tb(unique(df[if (length(by)) by else NULL]))
    if (!length(by)) out <- data.frame(dummy = 1)[FALSE, ]
    out$estimate <- est_vec
    out$se <- se_vec
    out$ci_low <- ci_low_vec
    out$ci_high <- ci_high_vec
    out$n <- n_vec
    out$method <- "progressive"

    # Reattach by-columns explicitly
    if (length(by)) {
      levs <- levels(split_keys)
      if (length(levs) == nrow(out)) {
        by_df <- utils::read.table(text = gsub("^", "", levs), sep = ".", col.names = by, stringsAsFactors = FALSE)
        suppressWarnings({
          for (j in seq_along(by)) if (!by[j] %in% names(out)) out[[by[j]]] <- by_df[[j]]
        })
      }
    }

    cols <- c(by, "estimate", "se", "ci_low", "ci_high", "n", "method")
    cols <- unique(cols[cols %in% names(out)])
    out <- out[cols]
    return(out)
  }

  stop("Unknown method.")
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
