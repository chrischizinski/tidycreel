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

# Biomass estimation ----

#' Estimate total biomass from a creel length distribution
#'
#' @description
#' `est_biomass()` converts a pressure-weighted length-frequency distribution
#' produced by [est_length_distribution()] into a total biomass estimate using
#' the allometric length-weight equation \eqn{W = a \cdot L^b}.
#'
#' Variance is propagated via the delta method, treating estimated fish counts
#' per length bin as uncorrelated (see Details).
#'
#' @param ld A `creel_length_distribution` object from [est_length_distribution()].
#' @param a Positive numeric allometric coefficient (the \eqn{a} in
#'   \eqn{W = a \cdot L^b}).
#' @param b Numeric allometric exponent (the \eqn{b} in
#'   \eqn{W = a \cdot L^b}). Typical values for fish are 2.5–3.5.
#' @param conf_level Numeric confidence level for confidence intervals.
#'   Defaults to the level stored in `ld` (usually `0.95`).
#'
#' @details
#' For each length bin h with midpoint \eqn{L_h = (\text{bin\_lower} +
#' \text{bin\_upper}) / 2}, per-bin biomass is
#' \eqn{B_h = a \cdot L_h^b \cdot \hat{N}_h}, where \eqn{\hat{N}_h} is the
#' survey-weighted estimated fish count from [est_length_distribution()].
#' Total biomass is \eqn{B = \sum_h B_h}.
#'
#' Variance is approximated as
#' \eqn{\widehat{\text{Var}}(B) \approx \sum_h (a \cdot L_h^b)^2 \cdot
#' \widehat{\text{SE}}_h^2}, which ignores cross-bin covariances.
#' When positive covariances exist (likely in small surveys), this
#' under-estimates the true variance.
#'
#' Length and weight units are determined by the user: if lengths are in mm
#' and `a` is calibrated for mm input, weights are returned in the
#' corresponding unit (e.g., grams).
#'
#' @return A `data.frame` with class `c("creel_biomass", "data.frame")` and
#'   columns: grouping columns (if any), `biomass_estimate`, `biomass_se`,
#'   `biomass_ci_lower`, `biomass_ci_upper`.
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
#' ld <- est_length_distribution(design, by = species, bin_width = 25)
#' est_biomass(ld, a = 0.0088, b = 3.1)
#'
#' @family "Estimation"
#' @export
est_biomass <- function(ld, a, b, conf_level = NULL) {
  if (!inherits(ld, "creel_length_distribution")) {
    cli::cli_abort(c(
      "{.arg ld} must be a {.cls creel_length_distribution} object.",
      "x" = "{.arg ld} is {.cls {class(ld)[1]}}.",
      "i" = "Create one with {.fn est_length_distribution}."
    ))
  }
  if (!is.numeric(a) || length(a) != 1L || is.na(a) || a <= 0) {
    cli::cli_abort(c(
      "{.arg a} must be a single positive number.",
      "x" = "{.arg a} is {.val {a}}."
    ))
  }
  if (!is.numeric(b) || length(b) != 1L || is.na(b)) {
    cli::cli_abort(c(
      "{.arg b} must be a single numeric value.",
      "x" = "{.arg b} is {.val {b}}."
    ))
  }

  ld_conf <- attr(ld, "conf_level")
  if (is.null(conf_level)) {
    conf_level <- if (!is.null(ld_conf)) ld_conf else 0.95
  } else {
    if (!is.numeric(conf_level) || length(conf_level) != 1L ||
      conf_level <= 0 || conf_level >= 1) { # nolint: indentation_linter
      cli::cli_abort(c(
        "{.arg conf_level} must be a single number in (0, 1).",
        "x" = "{.arg conf_level} is {.val {conf_level}}."
      ))
    }
  }

  by_vars <- attr(ld, "by_vars")
  if (is.null(by_vars)) by_vars <- character(0)

  z <- stats::qnorm((1 + conf_level) / 2)

  compute_biomass <- function(rows) {
    l_mid <- (rows$bin_lower + rows$bin_upper) / 2
    w_h <- a * l_mid^b
    biomass <- sum(w_h * rows$estimate)
    se_b <- sqrt(sum(w_h^2 * rows$se^2))
    data.frame(
      biomass_estimate = biomass,
      biomass_se = se_b,
      biomass_ci_lower = biomass - z * se_b,
      biomass_ci_upper = biomass + z * se_b,
      stringsAsFactors = FALSE
    )
  }

  if (length(by_vars) == 0L) {
    result <- compute_biomass(ld)
  } else {
    group_key <- do.call(paste, c(lapply(by_vars, function(v) ld[[v]]), sep = "\x1f"))
    groups <- unique(group_key)
    result_rows <- vector("list", length(groups))
    for (i in seq_along(groups)) {
      rows <- ld[group_key == groups[[i]], , drop = FALSE]
      group_info <- rows[1L, by_vars, drop = FALSE]
      result_rows[[i]] <- cbind(group_info, compute_biomass(rows), row.names = NULL)
    }
    result <- do.call(rbind, result_rows)
  }

  rownames(result) <- NULL
  class(result) <- c("creel_biomass", "data.frame")
  attr(result, "method") <- "biomass"
  attr(result, "a") <- a
  attr(result, "b") <- b
  attr(result, "conf_level") <- conf_level
  attr(result, "by_vars") <- if (length(by_vars) > 0L) by_vars else NULL
  result
}

# Mean length estimation ----

#' Estimate design-weighted mean length from a creel length distribution
#'
#' @description
#' `est_mean_length()` computes the pressure-weighted mean fish length from a
#' [est_length_distribution()] object using the ratio estimator
#' \eqn{\bar{L} = \sum_h L_h \hat{N}_h / \sum_h \hat{N}_h}, with
#' delta-method standard error.
#'
#' @param ld A `creel_length_distribution` object from [est_length_distribution()].
#' @param conf_level Numeric confidence level for confidence intervals.
#'   Defaults to the level stored in `ld` (usually `0.95`).
#'
#' @details
#' Bin midpoints \eqn{L_h = (\text{bin\_lower} + \text{bin\_upper}) / 2} serve
#' as representative lengths. Mean length is the ratio of total length-weighted
#' count to total count:
#' \deqn{\bar{L} = \frac{\sum_h L_h \hat{N}_h}{\hat{N}}}
#'
#' Variance is propagated via the delta method for a ratio estimator, treating
#' cross-bin covariances as zero:
#' \deqn{\widehat{\text{Var}}(\bar{L}) \approx
#'   \frac{1}{\hat{N}^2} \sum_h (L_h - \bar{L})^2 \, \widehat{\text{SE}}_h^2}
#'
#' @return A `data.frame` with class `c("creel_mean_length", "data.frame")` and
#'   columns: grouping columns (if any), `mean_length`, `mean_length_se`,
#'   `mean_length_ci_lower`, `mean_length_ci_upper`.
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
#' ld <- est_length_distribution(design, by = species, bin_width = 25)
#' est_mean_length(ld)
#'
#' @family "Estimation"
#' @export
est_mean_length <- function(ld, conf_level = NULL) {
  if (!inherits(ld, "creel_length_distribution")) {
    cli::cli_abort(c(
      "{.arg ld} must be a {.cls creel_length_distribution} object.",
      "x" = "{.arg ld} is {.cls {class(ld)[1]}}.",
      "i" = "Create one with {.fn est_length_distribution}."
    ))
  }

  ld_conf <- attr(ld, "conf_level")
  if (is.null(conf_level)) {
    conf_level <- if (!is.null(ld_conf)) ld_conf else 0.95
  } else {
    if (!is.numeric(conf_level) || length(conf_level) != 1L ||
      conf_level <= 0 || conf_level >= 1) { # nolint: indentation_linter
      cli::cli_abort(c(
        "{.arg conf_level} must be a single number in (0, 1).",
        "x" = "{.arg conf_level} is {.val {conf_level}}."
      ))
    }
  }

  by_vars <- attr(ld, "by_vars")
  if (is.null(by_vars)) by_vars <- character(0)
  z <- stats::qnorm((1 + conf_level) / 2)

  compute_mean_length <- function(rows) {
    l_mid <- (rows$bin_lower + rows$bin_upper) / 2
    n_total <- sum(rows$estimate)
    mean_l <- sum(l_mid * rows$estimate) / n_total
    se_l <- sqrt(sum((l_mid - mean_l)^2 * rows$se^2)) / n_total
    data.frame(
      mean_length = mean_l,
      mean_length_se = se_l,
      mean_length_ci_lower = mean_l - z * se_l,
      mean_length_ci_upper = mean_l + z * se_l,
      stringsAsFactors = FALSE
    )
  }

  if (length(by_vars) == 0L) {
    result <- compute_mean_length(ld)
  } else {
    group_key <- do.call(paste, c(lapply(by_vars, function(v) ld[[v]]), sep = "\x1f"))
    groups <- unique(group_key)
    result_rows <- vector("list", length(groups))
    for (i in seq_along(groups)) {
      rows <- ld[group_key == groups[[i]], , drop = FALSE]
      group_info <- rows[1L, by_vars, drop = FALSE]
      result_rows[[i]] <- cbind(group_info, compute_mean_length(rows), row.names = NULL)
    }
    result <- do.call(rbind, result_rows)
  }

  rownames(result) <- NULL
  class(result) <- c("creel_mean_length", "data.frame")
  attr(result, "method") <- "mean_length"
  attr(result, "conf_level") <- conf_level
  attr(result, "by_vars") <- if (length(by_vars) > 0L) by_vars else NULL
  result
}

# Compliance estimation ----

#' Estimate design-weighted size-limit compliance from a creel length distribution
#'
#' @description
#' `est_compliance()` estimates the proportion of fish meeting a minimum size
#' limit from a [est_length_distribution()] object.  Fish in bins whose lower
#' bound is at or above `min_length` are classified as legal (conservative:
#' bins straddling the limit are classified as illegal).
#'
#' @param ld A `creel_length_distribution` object from [est_length_distribution()].
#' @param min_length Positive numeric minimum legal length in the same units as
#'   the lengths used to build `ld`.
#' @param conf_level Numeric confidence level for confidence intervals.
#'   Defaults to the level stored in `ld` (usually `0.95`).
#'
#' @details
#' A bin is legal when `bin_lower >= min_length`.  The compliance proportion
#' and its variance use the ratio estimator:
#' \deqn{P = \frac{\sum_h I_h \hat{N}_h}{\hat{N}}}
#' \deqn{\widehat{\text{Var}}(P) \approx
#'   \frac{1}{\hat{N}^2} \sum_h (I_h - P)^2 \, \widehat{\text{SE}}_h^2}
#' where \eqn{I_h = \mathbf{1}(\text{bin\_lower}_h \geq \text{min\_length})}.
#'
#' Confidence interval bounds are clamped to \eqn{[0, 1]}.
#'
#' Choose `bin_width` in [est_length_distribution()] smaller than the typical
#' variation near the legal limit to minimise classification error for bins
#' that straddle the threshold.
#'
#' @return A `data.frame` with class `c("creel_compliance", "data.frame")` and
#'   columns: grouping columns (if any), `min_length`, `n_legal_est`,
#'   `n_total_est`, `compliance_prop`, `compliance_se`,
#'   `compliance_ci_lower`, `compliance_ci_upper`.
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
#' ld <- est_length_distribution(design, by = species, bin_width = 25)
#' est_compliance(ld, min_length = 356)  # 14-inch limit in mm
#'
#' @family "Estimation"
#' @export
est_compliance <- function(ld, min_length, conf_level = NULL) {
  if (!inherits(ld, "creel_length_distribution")) {
    cli::cli_abort(c(
      "{.arg ld} must be a {.cls creel_length_distribution} object.",
      "x" = "{.arg ld} is {.cls {class(ld)[1]}}.",
      "i" = "Create one with {.fn est_length_distribution}."
    ))
  }
  if (!is.numeric(min_length) || length(min_length) != 1L ||
    is.na(min_length) || min_length <= 0) { # nolint: indentation_linter
    cli::cli_abort(c(
      "{.arg min_length} must be a single positive number.",
      "x" = "{.arg min_length} is {.val {min_length}}."
    ))
  }

  ld_conf <- attr(ld, "conf_level")
  if (is.null(conf_level)) {
    conf_level <- if (!is.null(ld_conf)) ld_conf else 0.95
  } else {
    if (!is.numeric(conf_level) || length(conf_level) != 1L ||
      conf_level <= 0 || conf_level >= 1) { # nolint: indentation_linter
      cli::cli_abort(c(
        "{.arg conf_level} must be a single number in (0, 1).",
        "x" = "{.arg conf_level} is {.val {conf_level}}."
      ))
    }
  }

  by_vars <- attr(ld, "by_vars")
  if (is.null(by_vars)) by_vars <- character(0)
  z <- stats::qnorm((1 + conf_level) / 2)

  compute_compliance <- function(rows) {
    legal <- rows$bin_lower >= min_length
    n_legal <- sum(rows$estimate[legal])
    n_total <- sum(rows$estimate)
    p <- n_legal / n_total
    se_p <- sqrt(sum((as.numeric(legal) - p)^2 * rows$se^2)) / n_total
    data.frame(
      min_length = min_length,
      n_legal_est = n_legal,
      n_total_est = n_total,
      compliance_prop = p,
      compliance_se = se_p,
      compliance_ci_lower = pmax(0, p - z * se_p),
      compliance_ci_upper = pmin(1, p + z * se_p),
      stringsAsFactors = FALSE
    )
  }

  if (length(by_vars) == 0L) {
    result <- compute_compliance(ld)
  } else {
    group_key <- do.call(paste, c(lapply(by_vars, function(v) ld[[v]]), sep = "\x1f"))
    groups <- unique(group_key)
    result_rows <- vector("list", length(groups))
    for (i in seq_along(groups)) {
      rows <- ld[group_key == groups[[i]], , drop = FALSE]
      group_info <- rows[1L, by_vars, drop = FALSE]
      result_rows[[i]] <- cbind(group_info, compute_compliance(rows), row.names = NULL)
    }
    result <- do.call(rbind, result_rows)
  }

  rownames(result) <- NULL
  class(result) <- c("creel_compliance", "data.frame")
  attr(result, "method") <- "compliance"
  attr(result, "min_length") <- min_length
  attr(result, "conf_level") <- conf_level
  attr(result, "by_vars") <- if (length(by_vars) > 0L) by_vars else NULL
  result
}
