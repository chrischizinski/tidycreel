# validation_report() ---------------------------------------------------------

#' Generate a validation summary report
#'
#' Runs `validate_creel_data()` on `counts` and/or `interviews`, aggregates
#' the results into a human-readable summary tibble (one row per table x
#' check type), and optionally detects unrecognised species values via
#' `standardize_species()`.
#'
#' The returned object is a `creel_validation_report` - a data frame with a
#' custom `print` method that renders a colour-coded cli summary. It can be
#' exported with [write_estimates()].
#'
#' @param counts A data frame of count (effort) observations, or `NULL`.
#' @param interviews A data frame of interview observations, or `NULL`.
#' @param species_col Character scalar. If non-`NULL` and `interviews` is
#'   provided, calls `standardize_species()` on this column and appends a
#'   `species_coverage` row showing the fraction of rows successfully matched
#'   to an AFS code. Default `NULL` (no species check).
#' @param na_threshold Passed to `validate_creel_data()`. Default `0.10`.
#' @param date_range Passed to `validate_creel_data()`. Default
#'   `c(as.Date("1970-01-01"), as.Date("2100-12-31"))`.
#'
#' @return An object of class `creel_validation_report` - a data frame with
#'   columns:
#'   \describe{
#'     \item{`table`}{Source table: `"counts"`, `"interviews"`, or
#'       `"species"`.}
#'     \item{`check`}{Check type (e.g. `"na_rate"`, `"date_range"`).}
#'     \item{`n_pass`}{Number of columns with `"pass"` status.}
#'     \item{`n_warn`}{Number of columns with `"warn"` status.}
#'     \item{`n_fail`}{Number of columns with `"fail"` status.}
#'     \item{`detail`}{Comma-separated list of flagged columns, or `"all ok"`.}
#'   }
#'
#' @seealso [write_estimates()]
#'
#' @examples
#' \dontrun{
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
#' rpt <- validation_report(counts, interviews, species_col = "species")
#' print(rpt)
#' }
#'
#' @export
validation_report <- function(
    counts       = NULL,
    interviews   = NULL,
    species_col  = NULL,
    na_threshold = 0.10,
    date_range   = c(as.Date("1970-01-01"), as.Date("2100-12-31"))) {
  if (is.null(counts) && is.null(interviews)) {
    cli::cli_abort(
      "At least one of {.arg counts} or {.arg interviews} must be provided."
    )
  }

  # Run field-level validation.
  raw <- validate_creel_data( # nolint: object_usage_linter
    counts       = counts,
    interviews   = interviews,
    na_threshold = na_threshold,
    date_range   = date_range
  )

  # Aggregate: one row per table x check, with flagged column names.
  agg <- .aggregate_validation(raw)

  # Optional species coverage row.
  if (!is.null(species_col) && !is.null(interviews)) {
    sp_row <- .species_coverage_row(interviews, species_col)
    agg <- rbind(agg, sp_row)
  }

  rownames(agg) <- NULL
  class(agg) <- c("creel_validation_report", class(agg))
  agg
}

# ---- Internal helpers -------------------------------------------------------

.aggregate_validation <- function(raw) {
  tables <- unique(raw$table)
  checks <- unique(raw$check)

  rows <- list()
  for (tbl in tables) {
    for (chk in checks) {
      sub <- raw[raw$table == tbl & raw$check == chk, , drop = FALSE]
      if (nrow(sub) == 0L) next

      n_pass <- sum(sub$status == "pass")
      n_warn <- sum(sub$status == "warn")
      n_fail <- sum(sub$status == "fail")

      flagged <- sub$column[sub$status %in% c("warn", "fail")]
      detail_str <- if (length(flagged) == 0L) {
        "all ok"
      } else {
        paste(flagged, collapse = ", ")
      }

      rows <- c(rows, list(data.frame(
        table  = tbl,
        check  = chk,
        n_pass = n_pass,
        n_warn = n_warn,
        n_fail = n_fail,
        detail = detail_str,
        stringsAsFactors = FALSE
      )))
    }
  }
  do.call(rbind, rows)
}

.species_coverage_row <- function(interviews, species_col) {
  if (!species_col %in% names(interviews)) {
    cli::cli_warn(
      "Column {.field {species_col}} not found in {.arg interviews}; ",
      "skipping species coverage check."
    )
    return(NULL)
  }

  res <- suppressWarnings(
    standardize_species(interviews, species_col = species_col) # nolint: object_usage_linter
  )
  n_total   <- nrow(res)
  n_matched <- sum(!is.na(res$species_code))
  pct       <- if (n_total > 0L) round(100 * n_matched / n_total, 1) else 0

  n_warn <- if (n_matched < n_total) 1L else 0L

  data.frame(
    table  = "species",
    check  = "species_coverage",
    n_pass = if (n_warn == 0L) 1L else 0L,
    n_warn = n_warn,
    n_fail = 0L,
    detail = sprintf(
      "%d / %d matched (%.1f%%)", n_matched, n_total, pct
    ),
    stringsAsFactors = FALSE
  )
}

# ---- S3 methods -------------------------------------------------------------

#' Print a creel_validation_report
#'
#' Renders a colour-coded cli summary of the aggregated validation report.
#'
#' @param x A `creel_validation_report` object returned by
#'   `validation_report()`.
#' @param ... Ignored.
#'
#' @return `x`, invisibly.
#'
#' @export
print.creel_validation_report <- function(x, ...) {
  total_warn <- sum(x$n_warn)
  total_fail <- sum(x$n_fail)

  overall <- if (total_fail > 0L) { # nolint: object_usage_linter
    "FAIL"
  } else if (total_warn > 0L) {
    "WARN"
  } else {
    "PASS"
  }

  cli::cli_h1("Creel Validation Report")
  cli::cli_text("Overall: {.strong {overall}}")
  cli::cli_text("")

  for (tbl in unique(x$table)) {
    cli::cli_h2("Table: {tbl}")
    tbl_rows <- x[x$table == tbl, , drop = FALSE]

    for (i in seq_len(nrow(tbl_rows))) {
      row <- tbl_rows[i, , drop = FALSE]
      status <- if (row$n_fail > 0L) "fail" else if (row$n_warn > 0L) "warn" else "pass"
      sym <- if (status == "pass") { # nolint: object_usage_linter
        cli::symbol$tick
      } else if (status == "warn") {
        cli::symbol$warning
      } else {
        cli::symbol$cross
      }
      cli::cli_text(
        "  {sym} {row$check}: {row$detail} ",
        "({row$n_pass}p / {row$n_warn}w / {row$n_fail}f)"
      )
    }
    cli::cli_text("")
  }

  invisible(x)
}

#' Coerce a creel_validation_report to a plain data frame
#'
#' Strips the `creel_validation_report` class.
#'
#' @param x A `creel_validation_report` object.
#' @param ... Ignored.
#'
#' @return A plain `data.frame`.
#'
#' @export
as.data.frame.creel_validation_report <- function(x, ...) {
  class(x) <- setdiff(class(x), "creel_validation_report")
  x
}
