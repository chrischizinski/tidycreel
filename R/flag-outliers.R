# flag-outliers.R — IQR-based outlier flagging for creel interview data
# OUTL-01 through OUTL-07

#' Flag outliers in a creel interview data column
#'
#' @description
#' `flag_outliers()` identifies extreme values in a numeric column of a
#' data frame using Tukey's IQR fence method. Flagged rows are annotated
#' with `is_outlier`, `outlier_reason`, `fence_low`, and `fence_high`
#' columns. A `cli` summary of flagged rows is emitted.
#'
#' @details
#' **Method:** Tukey's IQR fence.
#' \deqn{\text{fence\_low} = Q_1 - k \times IQR}
#' \deqn{\text{fence\_high} = Q_3 + k \times IQR}
#'
#' Values below `fence_low` or above `fence_high` are flagged. When
#' `n < 4`, there is insufficient data to estimate the IQR reliably;
#' fences are set to `NA` and no rows are flagged.
#'
#' @param data A `data.frame` containing the column to check.
#' @param col Bare column name (unquoted) to check for outliers.
#' @param k Numeric IQR multiplier (default: 1.5). Larger values produce
#'   wider fences and fewer flags. Tukey's standard values are 1.5
#'   (mild outliers) and 3.0 (extreme outliers).
#' @param na.rm Logical. Remove `NA` values before computing quantiles
#'   (default: `TRUE`).
#'
#' @return The input `data` with four additional columns appended:
#'   \item{is_outlier}{Logical — `TRUE` if the row is outside the fence.}
#'   \item{outlier_reason}{Character — brief description of why it is
#'     flagged (e.g. `"above fence_high (23.5)"`), or `""` if not flagged.}
#'   \item{fence_low}{Numeric — lower fence value (same for all rows).
#'     `NA` when `n < 4`.}
#'   \item{fence_high}{Numeric — upper fence value (same for all rows).
#'     `NA` when `n < 4`.}
#'
#' @seealso [add_interviews()], [estimate_catch_rate()]
#'
#' @examples
#' df <- data.frame(
#'   interview_id = 1:8,
#'   effort = c(1.0, 1.5, 2.0, 1.8, 1.2, 1.9, 2.1, 15.0)
#' )
#' flag_outliers(df, col = effort)
#'
#' @family "Reporting & Diagnostics"
#' @export
flag_outliers <- function(data, col, k = 1.5, na.rm = TRUE) { # nolint: object_name_linter
  if (!is.data.frame(data)) {
    cli::cli_abort(c(
      "{.arg data} must be a {.cls data.frame}.",
      "i" = "Provide a data frame of interview records."
    ))
  }
  if (!is.numeric(k) || length(k) != 1L || k <= 0) {
    cli::cli_abort(
      "{.arg k} must be a single positive number, not {.val {k}}."
    )
  }

  # Resolve tidy-eval column name to a string
  col_name <- deparse(substitute(col))
  if (!col_name %in% names(data)) {
    cli::cli_abort(
      "Column {.field {col_name}} not found in {.arg data}."
    )
  }

  vals <- data[[col_name]]

  if (!is.numeric(vals)) {
    cli::cli_abort(c(
      "Column {.field {col_name}} must be numeric.",
      "i" = "Got {.cls {class(vals)}}."
    ))
  }

  if (nrow(data) == 0L) {
    data$is_outlier <- logical(0L)
    data$outlier_reason <- character(0L)
    data$fence_low <- numeric(0L)
    data$fence_high <- numeric(0L)
    return(data)
  }

  n_valid <- sum(!is.na(vals))

  if (n_valid < 4L) {
    # Not enough data for reliable IQR — return no flags
    data$is_outlier <- FALSE
    data$outlier_reason <- ""
    data$fence_low <- NA_real_
    data$fence_high <- NA_real_
    if (n_valid > 0L) {
      cli::cli_inform(c(
        "i" = paste0(
          "Not enough non-NA values (n = {n_valid}) in ",
          "{.field {col_name}} to compute IQR fences ",
          "(minimum 4). No rows flagged."
        )
      ))
    }
    return(data)
  }

  q1 <- stats::quantile(vals, 0.25, na.rm = na.rm, names = FALSE)
  q3 <- stats::quantile(vals, 0.75, na.rm = na.rm, names = FALSE)
  iqr <- q3 - q1

  fence_lo <- q1 - k * iqr
  fence_hi <- q3 + k * iqr

  above <- !is.na(vals) & vals > fence_hi
  below <- !is.na(vals) & vals < fence_lo

  is_out <- above | below
  reason <- character(nrow(data))
  reason[above] <- sprintf(
    "above fence_high (%.4g)", fence_hi
  )
  reason[below] <- sprintf(
    "below fence_low (%.4g)", fence_lo
  )

  data$is_outlier <- is_out
  data$outlier_reason <- reason
  data$fence_low <- fence_lo
  data$fence_high <- fence_hi

  n_flagged <- sum(is_out, na.rm = TRUE) # nolint: object_usage_linter
  cli::cli_inform(c(
    "i" = paste0(
      "{n_flagged} of {n_valid} value{?s} flagged as outlier{?s} ",
      "in {.field {col_name}} ",
      "(k = {k}, fence: [{round(fence_lo, 4)}, {round(fence_hi, 4)}])."
    )
  ))

  data
}
