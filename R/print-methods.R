#' Format creel_estimates_mor for printing
#'
#' @param x A creel_estimates_mor object
#' @param ... Additional arguments (currently ignored)
#'
#' @return Character vector with formatted output
#'
#' @export
format.creel_estimates_mor <- function(x, ...) {
  # Get base formatting from parent class
  base_output <- NextMethod("format")

  # Name the quantity this estimate actually measures. The banner said "CPUE"
  # unconditionally, which was true while mean-of-ratios reached only the catch
  # rate; GH #271 gave the release rate the same estimator, so an RPUE result
  # started printing a CPUE warning (GH #276).
  rate_label <- if (grepl("rpue", x$method %||% "", fixed = TRUE)) { # nolint: object_usage_linter
    "RPUE"
  } else if (grepl("hpue", x$method %||% "", fixed = TRUE)) {
    "HPUE"
  } else {
    "CPUE"
  }

  # Name the trip set the estimate was actually built from. The banner assumed
  # incomplete trips unconditionally, which was true while mean-of-ratios *was*
  # the incomplete-trip estimator; the roving auto-route made MOR the default
  # over *all* trips (GH #268 for catch, GH #271 for harvest and release), so a
  # roving default rate announced an incomplete-trip caveat while using every
  # trip it had, and `use_trips = "complete"` announced one while using none
  # (GH #276).
  #
  # `mor_estimation_warning()` already stays silent on the "all" and "complete"
  # paths. This is the printed counterpart obeying the same rule, not a new
  # policy: the length-of-stay caveat and the validation pointer belong to the
  # incomplete trip set, and the truncation report belongs to every MOR result
  # because truncation is part of the estimator (Hoenig et al. 1997).
  trip_set <- x$mor_use_trips %||% "incomplete"
  diagnostic <- identical(trip_set, "incomplete")

  # An unknown incomplete count is not a zero one: a design with no trip status
  # column cannot say how many of its interviews were incomplete, and printing
  # "(0 incomplete)" there would report an absence as a measurement.
  n_incomplete <- x$n_incomplete # nolint: object_usage_linter
  incomplete_known <- !is.null(n_incomplete) && !is.na(n_incomplete)

  rule_label <- switch(
    trip_set,
    incomplete = "DIAGNOSTIC: MOR Estimator (Incomplete Trips)",
    complete = "MOR Estimator (Complete Trips)",
    "MOR Estimator (All Trips)"
  )

  # Build diagnostic banner
  banner <- cli::cli_format_method({
    cli::cli_rule(left = rule_label)

    if (diagnostic) {
      cli::cli_alert_warning("Complete trips preferred for {rate_label} estimation.")
      cli::cli_text(
        "Uses incomplete trip interviews only ({x$n_total} trip{?s})."
      )
    } else if (identical(trip_set, "complete")) {
      cli::cli_text(
        "Averages per-trip {rate_label} ratios over {x$n_total} complete trip{?s}."
      )
    } else if (incomplete_known) {
      cli::cli_text(
        "Averages per-trip {rate_label} ratios over {x$n_total} interview{?s} ({n_incomplete} incomplete)."
      )
    } else {
      cli::cli_text(
        "Averages per-trip {rate_label} ratios over {x$n_total} interview{?s}."
      )
    }

    # Add truncation details if applicable
    if (!is.null(x$mor_truncate_at)) {
      if (x$mor_n_truncated > 0) {
        cli::cli_text(
          "Truncation: {x$mor_n_truncated} trip{?s} excluded (< {x$mor_truncate_at} hours)"
        )
      } else {
        cli::cli_text("Truncation: 0 trips excluded (threshold: {x$mor_truncate_at} hours)")
      }
    }

    if (diagnostic) {
      cli::cli_text(
        "Validate with {.fn validate_incomplete_trips} before use (Phase 19)."
      )
    }
    cli::cli_text("")
  })

  # Prepend banner to base output
  c(banner, base_output)
}

#' Print creel_estimates_mor
#'
#' @param x A creel_estimates_mor object
#' @param ... Additional arguments passed to format
#'
#' @return The input object, invisibly
#'
#' @export
print.creel_estimates_mor <- function(x, ...) {
  cat(format(x, ...), sep = "\n")
  invisible(x)
}

#' Format creel_estimates_diagnostic for printing
#'
#' @param x A creel_estimates_diagnostic object
#' @param ... Additional arguments (currently ignored)
#'
#' @return Character vector with formatted output
#'
#' @export
format.creel_estimates_diagnostic <- function(x, ...) {
  # Build diagnostic header
  header <- cli::cli_format_method({
    cli::cli_h1("CPUE Diagnostic Comparison")
    cli::cli_text("Complete trips vs Incomplete trips")
    cli::cli_text("")
  })

  # Build comparison table
  comparison_output <- utils::capture.output(print(x$comparison))

  # Build difference metrics section
  metrics <- cli::cli_format_method({
    cli::cli_h2("Difference Metrics")

    if (is.null(x$by_vars)) {
      # Ungrouped metrics
      cli::cli_text("Difference (complete - incomplete): {round(x$diff_estimate, 3)}")
      cli::cli_text("Ratio (complete / incomplete): {round(x$ratio_estimate, 3)}")
    } else {
      # Grouped metrics
      cli::cli_text("Per-group differences:")
      complete_rows <- x$comparison[x$comparison$trip_type == "complete", ]
      for (i in seq_along(x$diff_estimate)) {
        group_vals <- complete_rows[i, x$by_vars, drop = FALSE]
        group_label <- paste(x$by_vars, "=", group_vals[1, ], collapse = ", ") # nolint: object_usage_linter
        diff_val <- round(x$diff_estimate[i], 3) # nolint: object_usage_linter
        ratio_val <- round(x$ratio_estimate[i], 3) # nolint: object_usage_linter
        cli::cli_text("  {group_label}: diff = {diff_val}, ratio = {ratio_val}")
      }
    }
    cli::cli_text("")
  })

  # Build interpretation section
  interpretation <- cli::cli_format_method({
    cli::cli_h2("Interpretation")
    cli::cli_text("{x$interpretation}")
    cli::cli_text("")
    cli::cli_text("For statistical tests, see Phase 19 validation framework:")
    cli::cli_text("  - Test for equality of estimates (confidence interval overlap)")
    cli::cli_text("  - Test for nonstationary catch rates")
    cli::cli_text("  - Validate length-of-stay bias assumptions")
  })

  # Combine all sections
  c(header, comparison_output, "", metrics, interpretation)
}

#' Print creel_estimates_diagnostic
#'
#' @param x A creel_estimates_diagnostic object
#' @param ... Additional arguments passed to format
#'
#' @return The input object, invisibly
#'
#' @export
print.creel_estimates_diagnostic <- function(x, ...) {
  cat(format(x, ...), sep = "\n")
  invisible(x)
}

# ---- creel_summary print / as.data.frame -------------------------------------

#' Print a creel_summary object
#'
#' @param x A `creel_summary` object from [summary.creel_estimates()].
#' @param ... Additional arguments (currently ignored).
#'
#' @return The input object, invisibly.
#'
#' @export
print.creel_summary <- function(x, ...) {
  method_display <- switch(
    x$method,
    total = "Total",
    "ratio-of-means-cpue" = "Ratio-of-Means CPUE",
    "mean-of-ratios-cpue" = "Mean-of-Ratios CPUE",
    "mean-of-ratios-truncated-cpue" = "Truncated Mean-of-Ratios CPUE",
    "ratio-of-means-hpue" = "Ratio-of-Means HPUE",
    "mean-of-ratios-hpue" = "Mean-of-Ratios HPUE",
    "mean-of-ratios-truncated-hpue" = "Truncated Mean-of-Ratios HPUE",
    "mean-of-ratios-rpue" = "Mean-of-Ratios RPUE",
    "mean-of-ratios-truncated-rpue" = "Truncated Mean-of-Ratios RPUE",
    "ratio-of-means-cpue-per-angler" = "Ratio-of-Means CPUE (per angler)",
    "mean-of-ratios-cpue-per-angler" = "Mean-of-Ratios CPUE (per angler)",
    "ratio-of-means-hpue-per-angler" = "Ratio-of-Means HPUE (per angler)",
    "product-total-catch" = "Total Catch (Effort x CPUE)",
    "product-total-harvest" = "Total Harvest (Effort x HPUE)",
    "ht-total-catch" = "Total Catch (Horvitz-Thompson)",
    "ht-total-harvest" = "Total Harvest (Horvitz-Thompson)",
    "ht-total-release" = "Total Release (Horvitz-Thompson)",
    x$method
  )
  variance_display <- switch(
    x$variance_method,
    taylor = "Taylor linearization",
    bootstrap = "Bootstrap",
    jackknife = "Jackknife",
    x$variance_method
  )
  conf_pct <- paste0(round(x$conf_level * 100L), "%")

  cat(sprintf(
    "-- Creel Survey Summary (%s | %s | %s) --\n",
    method_display,
    variance_display,
    conf_pct
  ))
  print(x$table, row.names = FALSE, ...)
  invisible(x)
}

#' Coerce a creel_summary to a data.frame
#'
#' @param x A `creel_summary` object.
#' @param ... Additional arguments (currently ignored).
#'
#' @return A `data.frame` with human-readable estimate columns.
#'
#' @keywords internal
#' @export
as.data.frame.creel_summary <- function(x, ...) {
  x$table
}
