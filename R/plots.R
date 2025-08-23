#' Plot survey design structure
#'
#' Visualize survey design by date, shift, location, stratum, or other grouping
#' variables. Supports bar plots, faceted plots, and interactive plots (via
#' plotly if available).
#'
#' @param design A creel_design object or data frame with survey structure.
#' @param by Character vector of grouping variables (e.g., date, shift_block,
#'   location, stratum).
#' @param type Plot type: "bar", "facet", "interactive".
#' @param ... Additional arguments passed to ggplot2 or plotly.
#'
#' @return A ggplot or plotly object.
#' @details
#' Visualizes survey design structure and effort estimates. Supports bar, facet,
#' and interactive plots. See vignettes for usage examples.
#'
#' @examples
#' # Plot survey design structure
#' plot_design(design_obj, by = c("date", "shift_block", "location"), type = "bar")
#'
#' # Plot effort estimates
#' plot_effort(effort_df, by = c("date", "location"), type = "line")
#'
#' @references
#' Wickham, H. (2016). ggplot2: Elegant Graphics for Data Analysis. Springer-Verlag New York.
#' @export
plot_design <- function(design,
                        by = c("date", "shift_block", "location", "stratum"),
                        type = c("bar", "facet", "interactive"),
                        ...) {
  type <- match.arg(type)
  if (inherits(design, "creel_design") && !is.null(design$calendar)) {
    df <- design$calendar
  } else if (is.data.frame(design)) {
    df <- design
  } else {
    cli::cli_abort("Input must be a creel_design object or data frame with survey structure.")
  }
  by <- intersect(by, names(df))
  if (length(by) == 0) cli::cli_abort("No valid grouping variables found in design.")

  # Basic bar plot: count of samples per group
  p <- ggplot2::ggplot(df, ggplot2::aes_string(x = by[1])) +
    ggplot2::geom_bar() +
    ggplot2::labs(title = "Survey Design Structure", x = by[1], y = "Count")

  # Facet by additional grouping variables
  if (type == "facet" && length(by) > 1) {
    facet_formula <- as.formula(paste("~", paste(by[-1], collapse = "+")))
    p <- p + ggplot2::facet_wrap(facet_formula)
  }

  # Interactive plot (if plotly available)
  if (type == "interactive" && requireNamespace("plotly", quietly = TRUE)) {
    p <- plotly::ggplotly(p)
  }

  return(p)
}

#' Plot effort estimates
#'
#' Visualize effort estimates by stratum, date, location, or other grouping
#' variables. Supports line, bar, and interactive plots.
#'
#' @param effort_df Data frame/tibble of effort estimates (output from
#'   est_effort or similar).
#' @param by Character vector of grouping variables.
#' @param type Plot type: "line", "bar", "interactive".
#' @param ... Additional arguments passed to ggplot2 or plotly.
#'
#' @return A ggplot or plotly object.
#' @details
#' Visualizes effort estimates by stratum, date, location, or other grouping
#' variables. Supports line, bar, and interactive plots. See vignettes for
#' usage examples.
#'
#' @examples
#' # Plot effort estimates
#' plot_effort(effort_df, by = c("date", "location"), type = "line")
#'
#' @references
#' Wickham, H. (2016). ggplot2: Elegant Graphics for Data Analysis. Springer-Verlag New York.
#' @export
plot_effort <- function(effort_df,
                        by = c("date", "location", "stratum"),
                        type = c("line", "bar", "interactive"),
                        ...) {
  type <- match.arg(type)
  by <- intersect(by, names(effort_df))
  if (length(by) == 0) cli::cli_abort("No valid grouping variables found in effort_df.")

  # Basic plot
  if (type == "line") {
    p <- ggplot2::ggplot(effort_df, ggplot2::aes_string(x = by[1], y = "estimate", group = 1)) +
      ggplot2::geom_line() +
      ggplot2::geom_point() +
      ggplot2::labs(title = "Effort Estimates", x = by[1], y = "Effort")
  } else if (type == "bar") {
    p <- ggplot2::ggplot(effort_df, ggplot2::aes_string(x = by[1], y = "estimate")) +
      ggplot2::geom_bar(stat = "identity") +
      ggplot2::labs(title = "Effort Estimates", x = by[1], y = "Effort")
  } else if (type == "interactive" && requireNamespace("plotly", quietly = TRUE)) {
    p <- ggplot2::ggplot(effort_df, ggplot2::aes_string(x = by[1], y = "estimate")) +
      ggplot2::geom_bar(stat = "identity") +
      ggplot2::labs(title = "Effort Estimates", x = by[1], y = "Effort")
    p <- plotly::ggplotly(p)
  } else {
    cli::cli_abort("Unknown plot type or required package not available.")
  }
  return(p)
}
