# Length distribution estimation ----

#' Estimate a weighted length distribution from creel interview data
#'
#' @description
#' `est_length_distribution()` estimates a pressure-weighted length-frequency
#' distribution from fish length data attached via [add_lengths()]. Unlike
#' [summarize_length_freq()], which reports raw sample frequencies,
#' `est_length_distribution()` aggregates interview-level bin counts through the
#' internal interview survey design so the result reflects the survey design
#' rather than only the observed sample.
#'
#' The estimator returns one row per occupied length bin, with weighted totals,
#' standard errors, confidence intervals, and within-group percentages.
#'
#' @param design A `creel_design` object with interviews and lengths attached.
#' @param type Character string indicating which fish to include. One of
#'   `"catch"` (default), `"harvest"`, or `"release"`.
#' @param by Optional tidy selector evaluated against `design$lengths`.
#'   Common choices include `by = species`.
#' @param bin_width Positive numeric bin width in the same units as the attached
#'   length data. Default `1`.
#' @param length_col Optional character column name in `design$lengths` to use
#'   for the length values. Defaults to the column registered by
#'   [add_lengths()].
#' @param variance Character string specifying variance estimation method.
#'   One of `"taylor"` (default), `"bootstrap"`, or `"jackknife"`.
#' @param conf_level Numeric confidence level for confidence intervals.
#'   Default `0.95`.
#'
#' @return A `data.frame` with class
#'   `c("creel_length_distribution", "data.frame")` and columns:
#'   grouping columns (if any), `length_bin` (ordered factor), `bin_lower`,
#'   `bin_upper`, `estimate`, `se`, `ci_lower`, `ci_upper`, `percent`,
#'   `cumulative_percent`, and `n`.
#'
#' @examples
#' data(example_calendar)
#' data(example_interviews)
#' data(example_lengths)
#'
#' design <- creel_design(example_calendar, date = date, strata = day_type)
#' design <- add_interviews(design, example_interviews,
#'   catch = catch_total, effort = hours_fished, harvest = catch_kept,
#'   trip_status = trip_status
#' )
#' design <- add_lengths(design, example_lengths,
#'   length_uid = interview_id,
#'   interview_uid = interview_id,
#'   species = species,
#'   length = length,
#'   length_type = length_type,
#'   count = count,
#'   release_format = "binned"
#' )
#'
#' est_length_distribution(design, by = species, bin_width = 25)
#'
#' @family "Estimation"
#' @export
est_length_distribution <- function(design,
                                    type = "catch",
                                    by = NULL,
                                    bin_width = 1,
                                    length_col = NULL,
                                    variance = "taylor",
                                    conf_level = 0.95) {
  by_quo <- rlang::enquo(by)

  if (!inherits(design, "creel_design")) {
    cli::cli_abort(c(
      "{.arg design} must be a {.cls creel_design} object.",
      "x" = "{.arg design} is {.cls {class(design)[1]}}.",
      "i" = "Create a design with {.fn creel_design}."
    ))
  }

  if (is.null(design$interviews) || is.null(design$interview_survey)) {
    cli::cli_abort(c(
      "No interview survey available.",
      "x" = "Attach interviews with {.fn add_interviews} before estimating length distributions."
    ))
  }

  if (is.null(design[["lengths"]])) {
    cli::cli_abort(c(
      "No length data found in design.",
      "x" = "The design object has no length data.",
      "i" = "Attach length data with {.fn add_lengths}."
    ))
  }

  if (!is.numeric(bin_width) || length(bin_width) != 1L || bin_width <= 0) {
    cli::cli_abort(c(
      "{.arg bin_width} must be a single positive number.",
      "x" = "{.arg bin_width} is {.val {bin_width}}."
    ))
  }

  valid_methods <- c("taylor", "bootstrap", "jackknife")
  if (!variance %in% valid_methods) {
    cli::cli_abort(c(
      "Invalid variance method: {.val {variance}}",
      "x" = "Must be one of: {.val {valid_methods}}"
    ))
  }

  if (!is.numeric(conf_level) || length(conf_level) != 1L ||
    conf_level <= 0 || conf_level >= 1) { # nolint: indentation_linter
    cli::cli_abort(c(
      "{.arg conf_level} must be a single number in (0, 1).",
      "x" = "{.arg conf_level} is {.val {conf_level}}."
    ))
  }

  type <- match.arg(type, choices = c("catch", "harvest", "release"))

  lengths_data <- design$lengths
  length_col_name <- if (is.null(length_col)) {
    design$lengths_length_col
  } else {
    if (!is.character(length_col) || length(length_col) != 1L) {
      cli::cli_abort("{.arg length_col} must be a single column name when provided.")
    }
    if (!length_col %in% names(lengths_data)) {
      cli::cli_abort(c(
        "Column {.field {length_col}} not found in attached length data.",
        "i" = "Available columns: {.field {names(lengths_data)}}"
      ))
    }
    length_col
  }

  if (rlang::quo_is_null(by_quo)) {
    by_vars <- character(0)
  } else {
    by_cols <- tidyselect::eval_select(
      by_quo,
      data = lengths_data,
      allow_rename = FALSE,
      allow_empty = FALSE,
      error_call = rlang::caller_env()
    )
    by_vars <- names(by_cols)
  }

  records <- build_length_distribution_records(
    lengths_data = lengths_data,
    type = type,
    by_vars = by_vars,
    length_col = length_col_name,
    type_col = design$lengths_type_col,
    count_col = design$lengths_count_col,
    interview_uid_col = design$lengths_uid_col,
    release_format = design$lengths_release_format
  )

  if (nrow(records) == 0) {
    cli::cli_abort(c(
      "No length data found for {.arg type} = {.val {type}}.",
      "i" = "Check that {.fn add_lengths} included rows of this type."
    ))
  }

  max_len <- ceiling(max(records$.length_value) / bin_width) * bin_width
  breaks <- seq(0, max_len + bin_width, by = bin_width)
  bin_labels <- paste0("[", breaks[-length(breaks)], ",", breaks[-1], ")")
  records$length_bin <- cut(
    records$.length_value,
    breaks = breaks,
    labels = bin_labels,
    right = FALSE,
    include.lowest = TRUE
  )
  records$bin_lower <- breaks[as.integer(records$length_bin)]
  records$bin_upper <- records$bin_lower + bin_width

  ordered_labs <- bin_labels[bin_labels %in% as.character(unique(records$length_bin))]
  result_rows <- vector("list", 0)

  if (length(by_vars) == 0L) {
    group_indices <- list(seq_len(nrow(records)))
    group_values <- list(NULL)
  } else {
    group_key <- do.call(paste, c(lapply(by_vars, function(v) records[[v]]), sep = "\x1f"))
    split_idx <- split(seq_len(nrow(records)), group_key)
    group_indices <- unname(split_idx)
    group_values <- lapply(group_indices, function(idx) records[idx[1], by_vars, drop = FALSE])
  }

  for (i in seq_along(group_indices)) {
    idx <- group_indices[[i]]
    group_records <- records[idx, , drop = FALSE]

    agg <- stats::aggregate(
      group_records$.fish_count,
      by = list(
        uid = group_records$.interview_uid,
        length_bin = group_records$length_bin,
        bin_lower = group_records$bin_lower,
        bin_upper = group_records$bin_upper
      ),
      FUN = sum
    )
    names(agg)[ncol(agg)] <- "bin_count"

    bin_order <- unique(agg[, c("length_bin", "bin_lower", "bin_upper"), drop = FALSE])
    bin_order <- bin_order[order(bin_order$bin_lower), , drop = FALSE]
    bin_col_names <- paste0(".bin_", seq_len(nrow(bin_order)))
    bin_lookup <- data.frame(
      length_bin = as.character(bin_order$length_bin),
      bin_lower = bin_order$bin_lower,
      bin_upper = bin_order$bin_upper,
      bin_col = bin_col_names,
      stringsAsFactors = FALSE
    )

    agg$bin_col <- bin_lookup$bin_col[match(as.character(agg$length_bin), bin_lookup$length_bin)]

    wide <- stats::reshape(
      agg[, c("uid", "bin_col", "bin_count")],
      idvar = "uid",
      timevar = "bin_col",
      direction = "wide"
    )
    names(wide) <- sub("^bin_count\\.", "", names(wide))
    names(wide)[names(wide) == "uid"] <- design$lengths_interview_uid_col

    interviews_aug <- dplyr::left_join(
      design$interviews,
      wide,
      by = design$lengths_interview_uid_col
    )

    for (col in bin_lookup$bin_col) {
      if (!col %in% names(interviews_aug)) {
        interviews_aug[[col]] <- 0
      }
      interviews_aug[[col]][is.na(interviews_aug[[col]])] <- 0
    }

    temp_design <- rebuild_interview_survey(design, interviews_aug) # nolint: object_usage_linter
    svy_design <- get_variance_design(temp_design$interview_survey, variance) # nolint: object_usage_linter
    bin_formula <- stats::reformulate(bin_lookup$bin_col)
    svy_result <- wrap_survey_call(survey::svytotal(bin_formula, svy_design)) # nolint: object_usage_linter

    estimates <- as.numeric(stats::coef(svy_result))
    ses <- as.numeric(survey::SE(svy_result))
    cis <- suppressWarnings(confint(svy_result, level = conf_level))
    if (is.null(dim(cis))) {
      cis <- matrix(cis, nrow = 1L)
    }

    group_df <- data.frame(
      length_bin = factor(
        bin_lookup$length_bin,
        levels = ordered_labs,
        ordered = TRUE
      ),
      bin_lower = bin_lookup$bin_lower,
      bin_upper = bin_lookup$bin_upper,
      estimate = estimates,
      se = ses,
      ci_lower = cis[, 1],
      ci_upper = cis[, 2],
      n = nrow(design$interviews),
      stringsAsFactors = FALSE
    )

    total_est <- sum(group_df$estimate)
    if (isTRUE(all.equal(total_est, 0))) {
      group_df$percent <- 0
      group_df$cumulative_percent <- 0
    } else {
      group_df$percent <- round(group_df$estimate / total_est * 100, 1)
      group_df$cumulative_percent <- cumsum(group_df$percent)
    }

    if (length(by_vars) > 0) {
      group_info <- group_values[[i]]
      for (v in by_vars) {
        group_df[[v]] <- group_info[[v]][1]
      }
      group_df <- group_df[, c(
        by_vars, "length_bin", "bin_lower", "bin_upper",
        "estimate", "se", "ci_lower", "ci_upper", "percent",
        "cumulative_percent", "n"
      ), drop = FALSE]
    }

    result_rows[[length(result_rows) + 1L]] <- group_df
  }

  result <- do.call(rbind, result_rows)
  rownames(result) <- NULL

  class(result) <- c("creel_length_distribution", "data.frame")
  attr(result, "method") <- "length-distribution"
  attr(result, "variance_method") <- variance
  attr(result, "conf_level") <- conf_level
  attr(result, "by_vars") <- if (length(by_vars) > 0) by_vars else NULL
  attr(result, "type") <- type
  attr(result, "bin_width") <- bin_width
  result
}

#' Build per-record data for length-distribution estimation
#'
#' @keywords internal
#' @noRd
build_length_distribution_records <- function(lengths_data, # nolint: object_length_linter
                                              type,
                                              by_vars,
                                              length_col,
                                              type_col,
                                              count_col,
                                              interview_uid_col,
                                              release_format) {
  if (type == "harvest") {
    lengths_data <- lengths_data[lengths_data[[type_col]] == "harvest", , drop = FALSE]
  } else if (type == "release") {
    lengths_data <- lengths_data[lengths_data[[type_col]] == "release", , drop = FALSE]
  }

  harvest_rows <- lengths_data[lengths_data[[type_col]] == "harvest", , drop = FALSE]
  release_rows <- lengths_data[lengths_data[[type_col]] == "release", , drop = FALSE]

  build_rows <- function(rows, is_binned_release) {
    if (nrow(rows) == 0) {
      out <- data.frame(
        .interview_uid = numeric(0),
        .length_value = numeric(0),
        .fish_count = numeric(0),
        stringsAsFactors = FALSE
      )
      for (v in by_vars) out[[v]] <- rows[[v]]
      return(out)
    }

    if (is_binned_release) {
      parts <- strsplit(as.character(rows[[length_col]]), "-")
      lower_bounds <- suppressWarnings(
        as.numeric(vapply(parts, function(p) p[[1]], character(1)))
      )
      upper_bounds <- suppressWarnings(
        as.numeric(vapply(parts, function(p) p[[2]], character(1)))
      )
      if (any(is.na(lower_bounds)) || any(is.na(upper_bounds))) {
        cli::cli_abort(c(
          "Could not parse bin labels in release length data.",
          "i" = "Expected format: {.val '350-400'} (lower-upper separated by {.code -}).",
          "x" = "Check the {.arg length_col} values in your attached length data."
        ))
      }
      length_values <- (lower_bounds + upper_bounds) / 2
      fish_count <- as.numeric(rows[[count_col]])
    } else {
      length_values <- suppressWarnings(as.numeric(rows[[length_col]]))
      fish_count <- rep(1, nrow(rows))
    }

    if (any(is.na(length_values))) {
      cli::cli_abort(c(
        "Non-numeric length values found after parsing.",
        "i" = "Check that harvest/release individual lengths are numeric and release bins are parseable."
      ))
    }

    out <- data.frame(
      .interview_uid = rows[[interview_uid_col]],
      .length_value = length_values,
      .fish_count = fish_count,
      stringsAsFactors = FALSE
    )
    for (v in by_vars) out[[v]] <- rows[[v]]
    out
  }

  harvest_records <- build_rows(harvest_rows, is_binned_release = FALSE)
  release_records <- build_rows(
    release_rows,
    is_binned_release = (release_format == "binned" && nrow(release_rows) > 0)
  )

  rbind(harvest_records, release_records)
}
