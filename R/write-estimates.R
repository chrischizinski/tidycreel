#' Export creel survey estimates to a file
#'
#' Writes a `creel_estimates` or `creel_summary` object to a CSV or xlsx file.
#' For CSV, a three-line comment block is prepended containing the estimation
#' method, variance method, confidence level, and generation timestamp. For
#' xlsx, the data are written directly (Excel does not support comment rows).
#'
#' @param x A `creel_estimates` or `creel_summary` object.
#' @param path File path for the output. The extension (`.csv` or `.xlsx`)
#'   determines the format; alternatively, use the `format` argument to
#'   override.
#' @param format One of `"csv"` (default) or `"xlsx"`. When `"csv"`, a
#'   comment header is prepended. When `"xlsx"`,
#'   [writexl::write_xlsx()] is used behind an [rlang::check_installed()]
#'   guard.
#' @param overwrite Logical; if `FALSE` (default) an error is raised when
#'   `path` already exists.
#' @param ... Currently unused; reserved for future arguments.
#'
#' @return `path`, returned invisibly.
#'
#' @details
#' **CSV format** — The output file begins with comment lines starting with
#' `#` that record survey metadata:
#'
#' ```
#' # Survey estimates — tidycreel
#' # Method: Total Effort | Taylor linearization | 95% CI
#' # Generated: 2024-06-15 09:32:11 UTC
#' Estimate,SE,CI Lower,CI Upper,N
#' 372.5,13.18,343.8,401.2,14
#' ```
#'
#' These lines can be skipped when reading back with
#' `utils::read.csv(path, comment.char = "#")`.
#'
#' **xlsx format** — The data are written without a comment header since Excel
#' does not natively support comment rows. Row 1 will be the column headers.
#'
#' @seealso [summary.creel_estimates()], [write_schedule()]
#'
#' @examples
#' data("example_counts")
#' data("example_interviews")
#' cal <- unique(example_counts[, c("date", "day_type")])
#' design <- suppressWarnings(
#'   creel_design(cal, date = date, strata = day_type) # nolint
#' )
#' design <- suppressWarnings(add_counts(design, example_counts))
#' design <- suppressWarnings(
#'   add_interviews(
#'     design, example_interviews,
#'     catch = catch_total, effort = hours_fished, trip_status = trip_status
#'   )
#' )
#' eff <- suppressWarnings(estimate_effort(design))
#'
#' tmp <- tempfile(fileext = ".csv")
#' write_estimates(eff, tmp)
#'
#' # Read back (skipping comment lines)
#' out <- utils::read.csv(tmp, comment.char = "#")
#' out
#'
#' @export
write_estimates <- function(
  x,
  path,
  format = c("auto", "csv", "xlsx"),
  overwrite = FALSE,
  ...
) {
  # ---- Input validation -------------------------------------------------------
  if (!inherits(x, c("creel_estimates", "creel_summary"))) {
    cli::cli_abort(c(
      "{.arg x} must be a {.cls creel_estimates} or {.cls creel_summary}.",
      "x" = "Got {.cls {class(x)[1]}}.",
      "i" = paste0(
        "Create one with {.fn estimate_effort}, {.fn estimate_catch_rate}, ",
        "or {.fn summary.creel_estimates}."
      )
    ))
  }
  if (!is.character(path) || length(path) != 1L || !nzchar(path)) {
    cli::cli_abort("{.arg path} must be a single non-empty character string.")
  }
  if (!overwrite && file.exists(path)) {
    cli::cli_abort(c(
      "File already exists: {.path {path}}",
      "i" = "Set {.code overwrite = TRUE} to replace it."
    ))
  }

  # ---- Format detection -------------------------------------------------------
  format <- match.arg(format)
  if (format == "auto") {
    ext <- tolower(tools::file_ext(path))
    format <- switch(ext,
      csv = "csv",
      xlsx = "xlsx",
      cli::cli_abort(c(
        "Cannot infer format from extension {.val .{ext}}.",
        "i" = paste0(
          "Use a {.val .csv} or {.val .xlsx} extension, ",
          "or set {.arg format} explicitly."
        )
      ))
    )
  }

  # ---- Extract data frame -----------------------------------------------------
  df <- if (inherits(x, "creel_summary")) {
    as.data.frame(x)
  } else {
    as.data.frame(summary(x))
  }

  # ---- Metadata ---------------------------------------------------------------
  method_label <- x$method %||% "Unknown"
  var_label <- x$variance_method %||% "Unknown"
  conf_label <- paste0(round((x$conf_level %||% 0.95) * 100), "%")
  effort_target <- x$effort_target %||% NULL
  ts <- format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")

  # ---- Write ------------------------------------------------------------------
  if (format == "csv") {
    con <- file(path, open = "wt")
    on.exit(close(con), add = TRUE)
    header_lines <- c(
      "# Survey estimates — tidycreel",
      paste0(
        "# Method: ", method_label,
        " | ", var_label,
        " | ", conf_label, " CI"
      )
    )
    if (!is.null(effort_target) && nzchar(effort_target)) {
      header_lines <- c(header_lines, paste0("# Effort target: ", effort_target))
    }
    header_lines <- c(header_lines, paste0("# Generated: ", ts))
    writeLines(header_lines, con = con)
    utils::write.csv(df, file = con, row.names = FALSE)
  } else {
    rlang::check_installed(
      "writexl",
      reason = "to write xlsx estimate files"
    )
    writexl::write_xlsx(df, path)
  }

  invisible(path)
}
