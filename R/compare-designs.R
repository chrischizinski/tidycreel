# compare_designs() -----------------------------------------------------------

#' Compare multiple survey design estimates side by side
#'
#' `r lifecycle::badge("experimental")`
#'
#' Takes a named list of `creel_estimates` objects (from different survey
#' designs or methods), extracts key precision metrics from each, and returns
#' a tidy comparison tibble.  An `autoplot()` method renders a forest plot of
#' point estimates with confidence intervals.
#'
#' @param designs Named list of `creel_estimates` objects. Names become the
#'   `design` column in the output. At least two elements are required.
#' @param metric Character scalar. Which estimate column to compare. Default
#'   `"estimate"`.  Must be a column present in every `estimates` data frame.
#'
#' @return A `creel_design_comparison` object -- a data frame with columns:
#'   \describe{
#'     \item{`design`}{Design name (from `names(designs)`).}
#'     \item{`estimate`}{Point estimate.}
#'     \item{`se`}{Standard error.}
#'     \item{`rse`}{Relative standard error (`se / |estimate|`).}
#'     \item{`ci_lower`}{Lower confidence interval bound.}
#'     \item{`ci_upper`}{Upper confidence interval bound.}
#'     \item{`ci_width`}{Width of the confidence interval.}
#'     \item{`n`}{Sample size (if present in the estimates frame).}
#'   }
#'   Group columns are retained when all designs share the same by-variable
#'   structure.
#'
#' @seealso [autoplot.creel_design_comparison()]
#'
#' @examples
#' \dontrun{
#' # Compare instantaneous vs bus-route effort estimates from two designs
#' est1 <- estimate_effort(design_a)
#' est2 <- estimate_effort(design_b)
#' compare_designs(list(instantaneous = est1, bus_route = est2))
#' }
#'
#' @export
compare_designs <- function(designs, metric = "estimate") {
  if (!is.list(designs) || length(designs) < 2L) {
    cli::cli_abort(
      "{.arg designs} must be a named list of at least 2 {.cls creel_estimates}."
    )
  }
  if (is.null(names(designs)) || any(names(designs) == "")) {
    cli::cli_abort(
      "All elements of {.arg designs} must be named."
    )
  }
  for (nm in names(designs)) {
    if (!inherits(designs[[nm]], "creel_estimates")) {
      cli::cli_abort(
        "Element {.val {nm}} must be a {.cls creel_estimates} object."
      )
    }
  }

  rows <- lapply(names(designs), function(nm) {
    est <- designs[[nm]]$estimates
    if (!metric %in% names(est)) {
      cli::cli_abort(
        "Column {.field {metric}} not found in estimates for design {.val {nm}}."
      )
    }
    .build_comparison_row(nm, est, metric)
  })

  # Align columns across all rows (union, fill missing with NA).
  all_cols <- unique(unlist(lapply(rows, names)))
  rows <- lapply(rows, function(df) {
    missing <- setdiff(all_cols, names(df))
    for (col in missing) {
      df[[col]] <- NA
    }
    df[all_cols]
  })

  result <- do.call(rbind, rows)
  rownames(result) <- NULL
  class(result) <- c("creel_design_comparison", class(result))
  result
}

# Build one data frame of rows for a single design.
.build_comparison_row <- function(design_name, est, metric) {
  has_se <- "se" %in% names(est)
  has_ci_lower <- "ci_lower" %in% names(est)
  has_ci_upper <- "ci_upper" %in% names(est)
  has_n <- "n" %in% names(est)

  n_rows <- nrow(est)

  out <- data.frame(
    design = rep(design_name, n_rows),
    estimate = est[[metric]],
    se = if (has_se) est[["se"]] else rep(NA_real_, n_rows),
    rse = if (has_se) {
      abs(est[["se"]]) / pmax(abs(est[[metric]]), .Machine$double.eps)
    } else {
      rep(NA_real_, n_rows)
    },
    ci_lower = if (has_ci_lower) est[["ci_lower"]] else rep(NA_real_, n_rows),
    ci_upper = if (has_ci_upper) est[["ci_upper"]] else rep(NA_real_, n_rows),
    ci_width = if (has_ci_lower && has_ci_upper) {
      est[["ci_upper"]] - est[["ci_lower"]]
    } else {
      rep(NA_real_, n_rows)
    },
    n = if (has_n) est[["n"]] else rep(NA_integer_, n_rows),
    stringsAsFactors = FALSE
  )

  # Retain group columns (anything not in the standard set)
  std_cols <- c(
    "estimate", "se", "se_between", "se_within",
    "ci_lower", "ci_upper", "n"
  )
  grp_cols <- setdiff(names(est), c(std_cols, metric))
  if (length(grp_cols) > 0L) {
    out <- cbind(out, est[grp_cols])
  }

  out
}

# ---- S3 methods -------------------------------------------------------------

#' Print a creel_design_comparison
#'
#' @param x A `creel_design_comparison` object.
#' @param digits Integer. Number of significant digits. Default `3`.
#' @param ... Ignored.
#'
#' @return `x`, invisibly.
#'
#' @export
print.creel_design_comparison <- function(x, digits = 3L, ...) {
  cli::cli_h1("Survey Design Comparison")
  cli::cli_text("{nrow(x)} row(s), {length(unique(x$design))} design(s)")
  cli::cli_text("")
  print(format(as.data.frame(x), digits = digits))
  invisible(x)
}

#' Autoplot a creel_design_comparison as a forest plot
#'
#' Renders a forest plot showing point estimates with confidence intervals
#' for each design, coloured by design name.
#'
#' @param object A `creel_design_comparison` object.
#' @param title Optional plot title.
#' @param ... Ignored.
#'
#' @return A `ggplot` object.
#'
#' @export
autoplot.creel_design_comparison <- function(object, title = NULL, ...) {
  has_ci <- !all(is.na(object$ci_lower)) && !all(is.na(object$ci_upper))

  plot_title <- if (!is.null(title)) title else "Survey Design Comparison"

  p <- ggplot2::ggplot(
    object,
    ggplot2::aes(
      x = .data[["estimate"]], # nolint: object_usage_linter
      y = .data[["design"]], # nolint: object_usage_linter
      colour = .data[["design"]] # nolint: object_usage_linter
    )
  ) +
    ggplot2::geom_point(size = 3) +
    ggplot2::scale_colour_brewer(palette = "Set2") +
    ggplot2::labs(
      title  = plot_title,
      x      = "Estimate",
      y      = "Design",
      colour = "Design"
    ) +
    ggplot2::theme_bw() +
    ggplot2::theme(
      plot.title      = ggplot2::element_text(face = "bold"),
      legend.position = "none"
    )

  if (has_ci) {
    p <- p + ggplot2::geom_errorbarh(
      ggplot2::aes(
        xmin = .data[["ci_lower"]], # nolint: object_usage_linter
        xmax = .data[["ci_upper"]] # nolint: object_usage_linter
      ),
      height = 0.2
    )
  }

  p
}

#' Coerce a creel_design_comparison to a plain data frame
#'
#' @param x A `creel_design_comparison` object.
#' @param ... Ignored.
#'
#' @return A plain `data.frame`.
#'
#' @export
as.data.frame.creel_design_comparison <- function(x, ...) {
  class(x) <- setdiff(class(x), "creel_design_comparison")
  x
}
