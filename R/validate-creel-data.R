# validate_creel_data() -------------------------------------------------------

#' Validate creel survey data frames
#'
#' Runs field-level schema and quality checks on counts and/or interview data
#' frames, returning a tidy results tibble with a pass/warn/fail verdict per
#' column check.  A `print` method renders a colour-coded `cli` summary.
#'
#' Checks performed for **every** column:
#' \itemize{
#'   \item Type check - column class is reported.
#'   \item NA rate - warns if \eqn{>} `na_threshold` (default 0.10) of values
#'     are `NA`.
#' }
#'
#' Additional checks based on detected column role:
#' \itemize{
#'   \item **Date columns** - values must fall within `date_range` (defaults to
#'     1970-01-01 - 2100-12-31); warns on future dates.
#'   \item **Numeric columns** - warns if any value is negative (effort/count
#'     should be \eqn{\ge 0}).
#'   \item **Character/factor columns** - warns if any value is an empty string.
#' }
#'
#' @param counts A data frame of count (effort) observations, or `NULL` to
#'   skip.
#' @param interviews A data frame of interview observations, or `NULL` to skip.
#' @param na_threshold Numeric scalar in \eqn{[0, 1]}. Columns with an NA rate
#'   above this threshold receive a `"warn"` status. Default `0.10`.
#' @param date_range A length-2 `Date` vector giving the earliest and latest
#'   plausible dates. Default `c(as.Date("1970-01-01"), as.Date("2100-12-31"))`.
#'
#' @return An object of class `creel_data_validation` - a tibble with columns:
#'   \describe{
#'     \item{`table`}{Which input was checked: `"counts"` or `"interviews"`.}
#'     \item{`column`}{Column name.}
#'     \item{`check`}{Short check label (e.g. `"na_rate"`, `"negative_values"`,
#'       `"type"`).}
#'     \item{`status`}{`"pass"`, `"warn"`, or `"fail"`.}
#'     \item{`detail`}{Human-readable detail string.}
#'   }
#'
#' @seealso [validate_creel_schedule()] for schedule-specific validation.
#'
#' @examples
#' counts <- data.frame(
#'   date     = as.Date(c("2024-06-01", "2024-06-02")),
#'   day_type = c("weekday", "weekend"),
#'   count    = c(10L, NA_integer_)
#' )
#' interviews <- data.frame(
#'   date      = as.Date(c("2024-06-01", "2024-06-02")),
#'   fish_kept = c(2L, -1L),
#'   species   = c("walleye", "")
#' )
#' res <- validate_creel_data(counts, interviews)
#' print(res)
#'
#' @family "Reporting & Diagnostics"
#' @export
validate_creel_data <- function(
    counts      = NULL,
    interviews  = NULL,
    na_threshold = 0.10,
    date_range  = c(as.Date("1970-01-01"), as.Date("2100-12-31"))) {
  if (is.null(counts) && is.null(interviews)) {
    cli::cli_abort(
      "At least one of {.arg counts} or {.arg interviews} must be provided."
    )
  }

  bad_threshold <- !is.numeric(na_threshold) ||
    length(na_threshold) != 1L ||
    na_threshold < 0 || na_threshold > 1
  if (bad_threshold) {
    cli::cli_abort(
      "{.arg na_threshold} must be a single number in [0, 1]."
    )
  }

  if (
    !inherits(date_range, "Date") ||
      length(date_range) != 2L ||
      anyNA(date_range)
  ) {
    cli::cli_abort(
      "{.arg date_range} must be a length-2 {.cls Date} vector with no NAs."
    )
  }

  rows <- list()

  if (!is.null(counts)) {
    if (!is.data.frame(counts)) {
      cli::cli_abort("{.arg counts} must be a data frame.")
    }
    rows <- c(rows, .check_table(counts, "counts", na_threshold, date_range))
  }

  if (!is.null(interviews)) {
    if (!is.data.frame(interviews)) {
      cli::cli_abort("{.arg interviews} must be a data frame.")
    }
    rows <- c(
      rows,
      .check_table(interviews, "interviews", na_threshold, date_range)
    )
  }

  result <- do.call(rbind, rows)
  rownames(result) <- NULL
  class(result) <- c("creel_data_validation", class(result))
  result
}

# ---- Internal helpers -------------------------------------------------------

# Run all checks on one table; returns list of single-row data frames.
.check_table <- function(df, table_name, na_threshold, date_range) {
  out <- list()
  for (col in names(df)) {
    out <- c(
      out,
      .check_column(df[[col]], col, table_name, na_threshold, date_range)
    )
  }
  out
}

# Run checks on a single column vector.
.check_column <- function(x, col, table_name, na_threshold, date_range) {
  rows <- list()

  # -- type ------------------------------------------------------------------
  col_class <- paste(class(x), collapse = "/")
  rows <- c(rows, list(.make_row(
    table_name, col, "type", "pass",
    paste0("class: ", col_class)
  )))

  # -- NA rate ---------------------------------------------------------------
  n_total <- length(x)
  n_na <- sum(is.na(x))
  na_rate <- if (n_total > 0L) n_na / n_total else 0
  na_status <- if (na_rate > na_threshold) "warn" else "pass"
  rows <- c(rows, list(.make_row(
    table_name, col, "na_rate", na_status,
    sprintf(
      "%d / %d NA (%.0f%%)",
      n_na, n_total, na_rate * 100
    )
  )))

  # -- Date-specific checks --------------------------------------------------
  if (inherits(x, "Date")) {
    non_na <- x[!is.na(x)]
    if (length(non_na) > 0L) {
      out_of_range <- non_na < date_range[1] | non_na > date_range[2]
      range_status <- if (any(out_of_range)) "warn" else "pass"
      rows <- c(rows, list(.make_row(
        table_name, col, "date_range", range_status,
        if (any(out_of_range)) {
          sprintf(
            "%d value(s) outside %s - %s",
            sum(out_of_range),
            format(date_range[1]),
            format(date_range[2])
          )
        } else {
          sprintf(
            "all within %s - %s",
            format(date_range[1]),
            format(date_range[2])
          )
        }
      )))
    }
  }

  # -- Numeric-specific checks -----------------------------------------------
  if (is.numeric(x) && !inherits(x, "Date")) {
    non_na <- x[!is.na(x)]
    neg_status <- if (any(non_na < 0)) "warn" else "pass"
    rows <- c(rows, list(.make_row(
      table_name, col, "negative_values", neg_status,
      if (any(non_na < 0)) {
        sprintf("%d negative value(s)", sum(non_na < 0))
      } else {
        "none"
      }
    )))
  }

  # -- Character/factor-specific checks --------------------------------------
  if (is.character(x) || is.factor(x)) {
    chr_x <- as.character(x)
    non_na <- chr_x[!is.na(chr_x)]
    empty_status <- if (any(non_na == "")) "warn" else "pass"
    rows <- c(rows, list(.make_row(
      table_name, col, "empty_strings", empty_status,
      if (any(non_na == "")) {
        sprintf("%d empty string(s)", sum(non_na == ""))
      } else {
        "none"
      }
    )))
  }

  rows
}

# Build a single-row data frame.
.make_row <- function(table, column, check, status, detail) {
  data.frame(
    table  = table,
    column = column,
    check  = check,
    status = status,
    detail = detail,
    stringsAsFactors = FALSE
  )
}

# ---- S3 methods -------------------------------------------------------------

#' Print a creel_data_validation result
#'
#' Renders a colour-coded cli summary grouped by table and column. Counts
#' pass/warn/fail verdicts in a header line.
#'
#' @param x A `creel_data_validation` object returned by
#'   `validate_creel_data()`.
#' @param ... Ignored.
#'
#' @return `x`, invisibly.
#'
#' @export
print.creel_data_validation <- function(x, ...) {
  n_pass <- sum(x$status == "pass") # nolint: object_usage_linter
  n_warn <- sum(x$status == "warn") # nolint: object_usage_linter
  n_fail <- sum(x$status == "fail") # nolint: object_usage_linter

  cli::cli_h1("Creel Data Validation")
  cli::cli_text(
    "{.strong {n_pass}} pass  |  {.strong {n_warn}} warn  |  ",
    "{.strong {n_fail}} fail"
  )
  cli::cli_text("")

  for (tbl in unique(x$table)) {
    cli::cli_h2("Table: {tbl}")
    tbl_rows <- x[x$table == tbl, , drop = FALSE]

    for (col in unique(tbl_rows$column)) {
      col_rows <- tbl_rows[tbl_rows$column == col, , drop = FALSE]
      col_status <- if (any(col_rows$status == "fail")) {
        "fail"
      } else if (any(col_rows$status == "warn")) {
        "warn"
      } else {
        "pass"
      }

      if (col_status == "pass") {
        cli::cli_alert_success("{.field {col}}")
      } else if (col_status == "warn") {
        cli::cli_alert_warning("{.field {col}}")
      } else {
        cli::cli_alert_danger("{.field {col}}")
      }

      for (i in seq_len(nrow(col_rows))) {
        status_sym <- switch(col_rows$status[i], # nolint: object_usage_linter
          pass = cli::symbol$tick,
          warn = cli::symbol$warning,
          fail = cli::symbol$cross,
          "?"
        )
        cli::cli_text(
          "  {status_sym} {col_rows$check[i]}: {col_rows$detail[i]}"
        )
      }
    }
    cli::cli_text("")
  }

  invisible(x)
}

#' Coerce a creel_data_validation to a plain data frame
#'
#' Strips the `creel_data_validation` class, returning the underlying data
#' frame of check results.
#'
#' @param x A `creel_data_validation` object.
#' @param ... Ignored.
#'
#' @return A plain `data.frame`.
#'
#' @export
as.data.frame.creel_data_validation <- function(x, ...) {
  class(x) <- setdiff(class(x), "creel_data_validation")
  x
}
