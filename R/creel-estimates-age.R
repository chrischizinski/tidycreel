# Age distribution estimation ----

#' Estimate a weighted age distribution from creel interview data
#'
#' @description
#' `est_age_distribution()` estimates a pressure-weighted age-frequency
#' distribution from fish age data attached via [add_ages()]. Age records are
#' aggregated through the internal interview survey design so the result
#' reflects the survey design rather than only the observed sample.
#'
#' Ages are discrete integers; each unique observed age is its own class. The
#' estimator returns one row per occupied integer age, with weighted totals,
#' standard errors, confidence intervals, and within-group percentages.
#'
#' @param design A `creel_design` object with interviews and ages attached.
#' @param by Optional tidy selector evaluated against `design$ages`.
#'   Common choices include `by = species`.
#' @param type Character string indicating which fish to include. One of
#'   `"catch"` (default; both harvest and release), `"harvest"`, or
#'   `"release"`.
#' @param variance Character string specifying variance estimation method.
#'   One of `"taylor"` (default), `"bootstrap"`, or `"jackknife"`.
#' @param conf_level Numeric confidence level for confidence intervals.
#'   Default `0.95`.
#'
#' @return A `data.frame` with class
#'   `c("creel_age_distribution", "data.frame")` and columns: grouping columns
#'   (if any), `age` (integer), `estimate`, `se`, `ci_lower`, `ci_upper`,
#'   `percent`, `cumulative_percent`, and `n`.
#'
#' @examples
#' data(example_calendar)
#' data(example_interviews)
#' data(example_ages)
#'
#' design <- creel_design(example_calendar, date = date, strata = day_type)
#' design <- add_interviews(design, example_interviews,
#'   catch = catch_total, effort = hours_fished, harvest = catch_kept,
#'   trip_status = trip_status
#' )
#' design <- add_ages(design, example_ages,
#'   age_uid = interview_id,
#'   interview_uid = interview_id,
#'   species = species,
#'   age = age,
#'   age_type = age_type
#' )
#'
#' est_age_distribution(design, by = species)
#'
#' @family "Estimation"
#' @export
est_age_distribution <- function(
  design,
  by = NULL,
  type = "catch",
  variance = "taylor",
  conf_level = 0.95
) {
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
      "x" = "Attach interviews with {.fn add_interviews} before estimating age distributions."
    ))
  }

  if (is.null(design[["ages"]])) {
    cli::cli_abort(c(
      "No age data found in design.",
      "x" = "The design object has no age data.",
      "i" = "Attach age data with {.fn add_ages}."
    ))
  }

  valid_methods <- c("taylor", "bootstrap", "jackknife")
  if (!variance %in% valid_methods) {
    cli::cli_abort(c(
      "Invalid variance method: {.val {variance}}",
      "x" = "Must be one of: {.val {valid_methods}}"
    ))
  }

  if (!is.numeric(conf_level) || length(conf_level) != 1L || conf_level <= 0 || conf_level >= 1) {
    # nolint: indentation_linter
    cli::cli_abort(c(
      "{.arg conf_level} must be a single number in (0, 1).",
      "x" = "{.arg conf_level} is {.val {conf_level}}."
    ))
  }

  type <- match.arg(type, choices = c("catch", "harvest", "release"))

  ages_data <- design$ages

  if (rlang::quo_is_null(by_quo)) {
    by_vars <- character(0)
  } else {
    by_cols <- tidyselect::eval_select(
      by_quo,
      data = ages_data,
      allow_rename = FALSE,
      allow_empty = FALSE,
      error_call = rlang::caller_env()
    )
    by_vars <- names(by_cols)
  }

  records <- .build_age_distribution_records(
    ages_data = ages_data,
    type = type,
    by_vars = by_vars,
    age_col = design$ages_age_col,
    type_col = design$ages_type_col,
    interview_uid_col = design$ages_uid_col
  )

  if (nrow(records) == 0) {
    cli::cli_abort(c(
      "No age data found for {.arg type} = {.val {type}}.",
      "i" = "Check that {.fn add_ages} included rows of this type."
    ))
  }

  result_rows <- vector("list", 0)
  base_interviews <- design$interviews
  uid_col <- design$ages_interview_uid_col

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
        age = group_records$.age_value
      ),
      FUN = sum
    )
    names(agg)[ncol(agg)] <- "age_count"

    age_classes <- sort(unique(agg$age))
    age_col_names <- paste0(".age_", age_classes)
    age_lookup <- data.frame(
      age = age_classes,
      age_col = age_col_names,
      stringsAsFactors = FALSE
    )

    agg$age_col <- age_lookup$age_col[match(agg$age, age_lookup$age)]

    wide <- stats::reshape(
      agg[, c("uid", "age_col", "age_count")],
      idvar = "uid",
      timevar = "age_col",
      direction = "wide"
    )
    names(wide) <- sub("^age_count\\.", "", names(wide))
    names(wide)[names(wide) == "uid"] <- uid_col

    row_map <- match(base_interviews[[uid_col]], wide[[uid_col]])
    interviews_aug <- base_interviews
    for (col in age_lookup$age_col) {
      val <- wide[[col]][row_map]
      val[is.na(val)] <- 0L
      interviews_aug[[col]] <- val
    }

    temp_design <- rebuild_interview_survey(design, interviews_aug) # nolint: object_usage_linter
    svy_design <- get_variance_design(temp_design$interview_survey, variance) # nolint: object_usage_linter
    age_formula <- stats::reformulate(age_lookup$age_col)
    svy_result <- wrap_survey_call(survey::svytotal(age_formula, svy_design)) # nolint: object_usage_linter

    estimates <- as.numeric(stats::coef(svy_result))
    ses <- as.numeric(survey::SE(svy_result))
    cis <- suppressWarnings(confint(svy_result, level = conf_level))
    if (is.null(dim(cis))) {
      cis <- matrix(cis, nrow = 1L)
    }

    group_df <- data.frame(
      age = as.integer(age_lookup$age),
      estimate = estimates,
      se = ses,
      ci_lower = cis[, 1],
      ci_upper = cis[, 2],
      n = nrow(wide),
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
      group_df <- group_df[,
        c(
          by_vars,
          "age",
          "estimate",
          "se",
          "ci_lower",
          "ci_upper",
          "percent",
          "cumulative_percent",
          "n"
        ),
        drop = FALSE
      ]
    } else {
      group_df <- group_df[,
        c(
          "age",
          "estimate",
          "se",
          "ci_lower",
          "ci_upper",
          "percent",
          "cumulative_percent",
          "n"
        ),
        drop = FALSE
      ]
    }

    result_rows[[length(result_rows) + 1L]] <- group_df
  }

  result <- do.call(rbind, result_rows)
  rownames(result) <- NULL

  class(result) <- c("creel_age_distribution", "data.frame")
  attr(result, "method") <- "age-distribution"
  attr(result, "variance_method") <- variance
  attr(result, "conf_level") <- conf_level
  attr(result, "by_vars") <- if (length(by_vars) > 0) by_vars else NULL
  attr(result, "type") <- type
  result
}

#' Build per-record data for age-distribution estimation
#'
#' @keywords internal
#' @noRd
.build_age_distribution_records <- function(
  ages_data, # nolint: object_length_linter
  type,
  by_vars,
  age_col,
  type_col,
  interview_uid_col
) {
  if (type == "harvest") {
    ages_data <- ages_data[ages_data[[type_col]] == "harvest", , drop = FALSE]
  } else if (type == "release") {
    ages_data <- ages_data[ages_data[[type_col]] == "release", , drop = FALSE]
  }

  if (nrow(ages_data) == 0) {
    out <- data.frame(
      .interview_uid = numeric(0),
      .age_value = integer(0),
      .fish_count = numeric(0),
      stringsAsFactors = FALSE
    )
    for (v in by_vars) {
      out[[v]] <- ages_data[[v]]
    }
    return(out)
  }

  age_values <- suppressWarnings(as.integer(round(as.numeric(ages_data[[age_col]]))))
  if (any(is.na(age_values))) {
    cli::cli_abort(c(
      "Non-numeric age values found.",
      "i" = "Check that the attached age data are numeric integers."
    ))
  }

  out <- data.frame(
    .interview_uid = ages_data[[interview_uid_col]],
    .age_value = age_values,
    .fish_count = rep(1, nrow(ages_data)),
    stringsAsFactors = FALSE
  )
  for (v in by_vars) {
    out[[v]] <- ages_data[[v]]
  }
  out
}

# Mean age estimation ----

#' Estimate design-weighted mean age from a creel age distribution
#'
#' @description
#' `est_mean_age()` computes the pressure-weighted mean fish age from a
#' [est_age_distribution()] object using the ratio estimator
#' \eqn{\bar{A} = \sum_a a \hat{N}_a / \sum_a \hat{N}_a}, with delta-method
#' standard error.
#'
#' @param ad A `creel_age_distribution` object from [est_age_distribution()].
#' @param conf_level Numeric confidence level for confidence intervals.
#'   Defaults to the level stored in `ad` (usually `0.95`).
#'
#' @details
#' Each integer age \eqn{a} contributes its survey-weighted count
#' \eqn{\hat{N}_a}. Mean age is the ratio of total age-weighted count to total
#' count:
#' \deqn{\bar{A} = \frac{\sum_a a \hat{N}_a}{\hat{N}}}
#'
#' Variance is propagated via the delta method for a ratio estimator, treating
#' cross-class covariances as zero:
#' \deqn{\widehat{\text{Var}}(\bar{A}) \approx
#'   \frac{1}{\hat{N}^2} \sum_a (a - \bar{A})^2 \, \widehat{\text{SE}}_a^2}
#'
#' @return A `data.frame` with class `c("creel_mean_age", "data.frame")` and
#'   columns: grouping columns (if any), `mean_age`, `mean_age_se`,
#'   `mean_age_ci_lower`, `mean_age_ci_upper`. Rows where the total estimated
#'   fish is zero or negative return `NA` for all numeric columns with a
#'   warning.
#'
#' @examples
#' data(example_calendar)
#' data(example_interviews)
#' data(example_ages)
#'
#' design <- creel_design(example_calendar, date = date, strata = day_type)
#' design <- add_interviews(design, example_interviews,
#'   catch = catch_total, effort = hours_fished, harvest = catch_kept,
#'   trip_status = trip_status
#' )
#' design <- add_ages(design, example_ages,
#'   age_uid = interview_id,
#'   interview_uid = interview_id,
#'   species = species,
#'   age = age,
#'   age_type = age_type
#' )
#'
#' ad <- est_age_distribution(design, by = species)
#' est_mean_age(ad)
#'
#' @family "Estimation"
#' @export
est_mean_age <- function(ad, conf_level = NULL) {
  if (!inherits(ad, "creel_age_distribution")) {
    cli::cli_abort(c(
      "{.arg ad} must be a {.cls creel_age_distribution} object.",
      "x" = "{.arg ad} is {.cls {class(ad)[1]}}.",
      "i" = "Create one with {.fn est_age_distribution}."
    ))
  }

  ad_conf <- attr(ad, "conf_level")
  if (is.null(conf_level)) {
    conf_level <- if (!is.null(ad_conf)) ad_conf else 0.95
  } else {
    if (!is.numeric(conf_level) || length(conf_level) != 1L || conf_level <= 0 || conf_level >= 1) {
      # nolint: indentation_linter
      cli::cli_abort(c(
        "{.arg conf_level} must be a single number in (0, 1).",
        "x" = "{.arg conf_level} is {.val {conf_level}}."
      ))
    }
  }

  by_vars <- attr(ad, "by_vars")
  if (is.null(by_vars)) {
    by_vars <- character(0)
  }
  z <- stats::qnorm((1 + conf_level) / 2)

  compute_mean_age <- function(rows) {
    a <- as.numeric(rows$age)
    n_total <- sum(rows$estimate)
    if (n_total <= 0) {
      cli::cli_warn("Total estimated fish is zero or negative; mean age cannot be computed.")
      return(data.frame(
        mean_age = NA_real_,
        mean_age_se = NA_real_,
        mean_age_ci_lower = NA_real_,
        mean_age_ci_upper = NA_real_,
        stringsAsFactors = FALSE
      ))
    }
    mean_a <- sum(a * rows$estimate) / n_total
    se_a <- sqrt(sum((a - mean_a)^2 * rows$se^2)) / n_total
    data.frame(
      mean_age = mean_a,
      mean_age_se = se_a,
      mean_age_ci_lower = mean_a - z * se_a,
      mean_age_ci_upper = mean_a + z * se_a,
      stringsAsFactors = FALSE
    )
  }

  if (length(by_vars) == 0L) {
    result <- compute_mean_age(ad)
  } else {
    group_key <- do.call(paste, c(lapply(by_vars, function(v) ad[[v]]), sep = "\x1f"))
    groups <- unique(group_key)
    result_rows <- vector("list", length(groups))
    for (i in seq_along(groups)) {
      rows <- ad[group_key == groups[[i]], , drop = FALSE]
      group_info <- rows[1L, by_vars, drop = FALSE]
      result_rows[[i]] <- cbind(group_info, compute_mean_age(rows), row.names = NULL)
    }
    result <- do.call(rbind, result_rows)
  }

  rownames(result) <- NULL
  class(result) <- c("creel_mean_age", "data.frame")
  attr(result, "method") <- "mean_age"
  attr(result, "conf_level") <- conf_level
  attr(result, "by_vars") <- if (length(by_vars) > 0L) by_vars else NULL
  result
}
