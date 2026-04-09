# autoplot-methods.R — ggplot2 autoplot for creel_estimates
# PLOT-01 through PLOT-05

#' @importFrom ggplot2 autoplot
#' @importFrom rlang .data
NULL

#' Plot creel survey estimates with ggplot2
#'
#' @description
#' `autoplot.creel_estimates()` produces a point-and-errorbar plot from a
#' `creel_estimates` object. For ungrouped estimates a single point with
#' confidence interval is shown. For grouped estimates (when `by` was
#' supplied to the estimation function) each group level gets its own point,
#' colour-coded and positioned along the x-axis.
#'
#' Requires the **ggplot2** package (listed in `Suggests`). Install it with
#' `install.packages("ggplot2")` if needed.
#'
#' @param object A `creel_estimates` object.
#' @param title Optional character string for the plot title. Defaults to
#'   a human-readable description of the estimation method.
#' @param ... Additional arguments (currently unused).
#'
#' @return A `ggplot` object.
#'
#' @seealso [estimate_effort()], [estimate_catch_rate()],
#'   [tidycreel::summary.creel_estimates()]
#'
#' @examples
#' \dontrun{
#' est <- estimate_effort(design)
#' ggplot2::autoplot(est)
#'
#' est_grp <- estimate_effort(design, by = day_type)
#' ggplot2::autoplot(est_grp)
#' }
#'
#' @export
autoplot.creel_estimates <- function(object, title = NULL, ...) {
  # Human-readable method label
  method_label <- switch(object$method,
    total = "Total Effort",
    "ratio-of-means-cpue" = "CPUE (Ratio-of-Means)",
    "mean-of-ratios-cpue" = "CPUE (Mean-of-Ratios)",
    "ratio-of-means-hpue" = "HPUE (Ratio-of-Means)",
    "ratio-of-means-cpue-per-angler" =
      "CPUE per Angler (Ratio-of-Means)",
    "mean-of-ratios-cpue-per-angler" =
      "CPUE per Angler (Mean-of-Ratios)",
    "ratio-of-means-hpue-per-angler" =
      "HPUE per Angler (Ratio-of-Means)",
    "product-total-catch" = "Total Catch",
    "product-total-harvest" = "Total Harvest",
    object$method
  )

  if (is.null(title)) title <- method_label

  conf_pct <- paste0(round(object$conf_level * 100L), "% CI")
  est <- object$estimates

  # Identify group columns
  est_cols <- c(
    "estimate", "se", "ci_lower", "ci_upper", "n",
    "se_between", "se_within"
  )
  group_cols <- setdiff(names(est), est_cols)

  if (length(group_cols) == 0L) {
    # Ungrouped: single point
    plot_df <- data.frame(
      label     = method_label,
      estimate  = est$estimate,
      ci_lower  = est$ci_lower,
      ci_upper  = est$ci_upper
    )
    p <- ggplot2::ggplot(
      plot_df,
      ggplot2::aes(
        x    = .data[["label"]], # nolint: object_usage_linter
        y    = .data[["estimate"]],
        ymin = .data[["ci_lower"]],
        ymax = .data[["ci_upper"]]
      )
    ) +
      ggplot2::geom_point(size = 3L) +
      ggplot2::geom_errorbar(width = 0.2) +
      ggplot2::labs(
        x = NULL,
        y = method_label,
        title = title,
        caption = conf_pct
      ) +
      ggplot2::theme_bw()
  } else {
    # Grouped: one point per group row
    grp_col <- group_cols[[1L]]
    plot_df <- data.frame(
      group    = as.character(est[[grp_col]]),
      estimate = est$estimate,
      ci_lower = est$ci_lower,
      ci_upper = est$ci_upper
    )
    p <- ggplot2::ggplot(
      plot_df,
      ggplot2::aes(
        x     = .data[["group"]], # nolint: object_usage_linter
        y     = .data[["estimate"]],
        ymin  = .data[["ci_lower"]],
        ymax  = .data[["ci_upper"]],
        color = .data[["group"]]
      )
    ) +
      ggplot2::geom_point(size = 3L) +
      ggplot2::geom_errorbar(width = 0.2) +
      ggplot2::labs(
        x = grp_col,
        y = method_label,
        color = grp_col,
        title = title,
        caption = conf_pct
      ) +
      ggplot2::theme_bw() +
      ggplot2::theme(legend.position = "none")
  }

  p
}

#' Plot a creel schedule as a ggplot2 tile calendar
#'
#' @description
#' `autoplot.creel_schedule()` produces a monthly tile calendar showing sampled
#' dates coloured by day type (weekday / weekend) and unsampled dates in grey.
#' Multiple months are shown as faceted panels.
#'
#' Requires the **ggplot2** package (listed in `Suggests`). Install it with
#' `install.packages("ggplot2")` if needed.
#'
#' @param object A `creel_schedule` object from [generate_schedule()] or
#'   [generate_bus_schedule()].
#' @param title Optional character string for the plot title. Defaults to
#'   `"Creel Schedule"`.
#' @param ... Additional arguments (currently unused).
#'
#' @return A `ggplot` object.
#'
#' @seealso [generate_schedule()], [print.creel_schedule()],
#'   [write_schedule()]
#'
#' @examples
#' \dontrun{
#' sched <- generate_schedule(
#'   start_date = "2024-06-01", end_date = "2024-07-31",
#'   n_periods = 1,
#'   sampling_rate = c(weekday = 0.3, weekend = 0.6),
#'   seed = 42
#' )
#' ggplot2::autoplot(sched)
#' }
#'
#' @export
autoplot.creel_schedule <- function(object, title = "Creel Schedule", ...) {
  # Reconstruct full season from min/max date in the schedule
  min_date <- min(object$date)
  max_date <- max(object$date)

  all_days <- data.frame(
    date = seq(
      lubridate::floor_date(min_date, "month"),
      lubridate::ceiling_date(max_date, "month") - 1L,
      by = "1 day"
    )
  )

  # Join with schedule to flag sampled days and day_type
  all_days$sampled <- all_days$date %in% object$date
  all_days$day_type <- ifelse(
    all_days$sampled,
    object$day_type[match(all_days$date, object$date)],
    NA_character_
  )
  # If circuit_id column is present, use it as fill; otherwise use day_type
  has_circuit <- "circuit_id" %in% names(object)
  if (has_circuit) {
    all_days$circuit_id <- ifelse(
      all_days$sampled,
      object$circuit_id[match(all_days$date, object$date)],
      NA_character_
    )
    all_days$fill_group <- ifelse(
      all_days$sampled,
      all_days$circuit_id,
      "unsampled"
    )
  } else {
    all_days$fill_group <- ifelse(
      all_days$sampled,
      all_days$day_type,
      "unsampled"
    )
  }

  # Calendar geometry: week column (0=Sun..6=Sat) + week-of-month row
  all_days$wday <- lubridate::wday(all_days$date, week_start = 7L) - 1L
  month_floor <- lubridate::floor_date(all_days$date, "month")
  first_wday <- lubridate::wday(month_floor, week_start = 7L) - 1L
  all_days$week_row <- as.integer(
    floor((lubridate::mday(all_days$date) - 1L + first_wday) / 7L)
  )
  all_days$week_row <- -all_days$week_row # invert so row 0 is at top

  # Month facet label
  all_days$month_label <- format(month_floor, "%B %Y")

  # Day-of-month label (shown only for sampled days)
  all_days$day_label <- ifelse(
    all_days$sampled,
    as.character(lubridate::mday(all_days$date)),
    ""
  )

  # Weekday header labels
  wday_labels <- c("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat")

  p <- ggplot2::ggplot(
    all_days,
    ggplot2::aes( # nolint: object_usage_linter
      x    = .data[["wday"]], # nolint: object_usage_linter
      y    = .data[["week_row"]],
      fill = .data[["fill_group"]]
    )
  ) +
    ggplot2::geom_tile(
      color = "white", linewidth = 0.5
    ) +
    ggplot2::geom_text(
      ggplot2::aes(label = .data[["day_label"]]), # nolint: object_usage_linter
      size = 2.5, color = "white", fontface = "bold"
    ) +
    ggplot2::scale_x_continuous(
      breaks = 0:6,
      labels = wday_labels,
      expand = c(0, 0)
    ) +
    ggplot2::scale_y_continuous(expand = c(0.05, 0.05))

  fill_scale <- if (has_circuit) {
    ggplot2::scale_fill_brewer(
      palette  = "Set2",
      na.value = "#cccccc",
      name     = "Circuit"
    )
  } else {
    ggplot2::scale_fill_manual(
      values = c(
        weekday   = "#2c7bb6",
        weekend   = "#d7191c",
        unsampled = "#cccccc"
      ),
      na.value = "#cccccc",
      name = NULL
    )
  }

  p <- p +
    fill_scale +
    ggplot2::facet_wrap(
      ggplot2::vars(.data[["month_label"]]), # nolint: object_usage_linter
      ncol = 1L,
      scales = "free_y"
    ) +
    ggplot2::labs(
      title = title,
      x = NULL,
      y = NULL
    ) +
    ggplot2::theme_minimal() +
    ggplot2::theme(
      axis.text.y  = ggplot2::element_blank(),
      axis.ticks.y = ggplot2::element_blank(),
      panel.grid   = ggplot2::element_blank(),
      strip.text   = ggplot2::element_text(face = "bold")
    )

  p
}

# ---- plot_design() -----------------------------------------------------------

#' Plot a creel survey design
#'
#' @description
#' Produces a quick visual summary of a `creel_design` object:
#'
#' - **Without counts attached** (`design$counts` is `NULL`): a bar chart
#'   showing the number of sampled days per stratum.
#' - **With counts attached**: a jitter + crossbar chart showing the
#'   distribution of count values per stratum.
#'
#' Both variants colour bars/points by stratum for easy differentiation.
#'
#' @param design A `creel_design` object created by [creel_design()].
#' @param title Optional character title. Defaults to
#'   `"Creel Design Summary"` (no counts) or `"Count Distribution by Stratum"`
#'   (with counts).
#' @param ... Additional arguments (currently ignored).
#'
#' @return A `ggplot` object.
#'
#' @seealso [creel_design()], [autoplot.creel_schedule()]
#'
#' @examples
#' \dontrun{
#' # Without counts — stratum sample sizes
#' cal <- data.frame(
#'   date = as.Date(c(
#'     "2024-06-01", "2024-06-02", "2024-06-08", "2024-06-09"
#'   )),
#'   day_type = c("weekday", "weekday", "weekend", "weekend")
#' )
#' design <- creel_design(cal, date = date, strata = day_type)
#' plot_design(design)
#'
#' # With counts — count distribution per stratum
#' design_with_counts <- add_counts(design, counts_df)
#' plot_design(design_with_counts)
#' }
#'
#' @export
plot_design <- function(design, title = NULL, ...) { # nolint: object_usage_linter
  if (!inherits(design, "creel_design")) {
    cli::cli_abort(c(
      "{.arg design} must be a {.cls creel_design} object.",
      "x" = "{.arg design} is {.cls {class(design)[1]}}.",
      "i" = "Create a design with {.fn creel_design}."
    ))
  }

  strata_col <- design$strata_cols[1]

  if (is.null(design$counts)) {
    # ---- No counts: stratum sample-size bar chart ---------------------------
    cal <- design$calendar
    n_per_strat <- as.data.frame(table(cal[[strata_col]]),
      stringsAsFactors = FALSE
    )
    names(n_per_strat) <- c("stratum", "n_days")
    n_per_strat$stratum <- as.character(n_per_strat$stratum)

    plot_title <- if (!is.null(title)) title else "Creel Design Summary"

    ggplot2::ggplot(
      n_per_strat,
      ggplot2::aes(
        x = .data[["stratum"]], # nolint: object_usage_linter
        y = .data[["n_days"]], # nolint: object_usage_linter
        fill = .data[["stratum"]] # nolint: object_usage_linter
      )
    ) +
      ggplot2::geom_col(width = 0.6, colour = "white") +
      ggplot2::geom_text(
        ggplot2::aes(label = .data[["n_days"]]), # nolint: object_usage_linter
        vjust = -0.4,
        size = 3.5
      ) +
      ggplot2::scale_fill_brewer(palette = "Set2") +
      ggplot2::labs(
        title = plot_title,
        x     = "Stratum",
        y     = "Sampled days",
        fill  = "Stratum"
      ) +
      ggplot2::theme_bw() +
      ggplot2::theme(
        plot.title = ggplot2::element_text(face = "bold"),
        legend.position = "none"
      )
  } else {
    # ---- With counts: jitter + crossbar distribution per stratum -----------
    counts <- design$counts

    # Identify first numeric count column (excluding design metadata)
    excluded <- c(
      design$date_col, design$strata_cols, design$psu_col, design$section_col
    )
    num_cols <- names(counts)[sapply(counts, is.numeric)]
    count_var <- setdiff(num_cols, excluded)[1]

    plot_df <- data.frame(
      stratum = counts[[strata_col]],
      count = counts[[count_var]],
      stringsAsFactors = FALSE
    )
    plot_df <- plot_df[!is.na(plot_df$count), ]

    plot_title <- if (!is.null(title)) {
      title
    } else {
      paste0("Count Distribution by Stratum (", count_var, ")")
    }

    ggplot2::ggplot(
      plot_df,
      ggplot2::aes(
        x = .data[["stratum"]], # nolint: object_usage_linter
        y = .data[["count"]], # nolint: object_usage_linter
        colour = .data[["stratum"]] # nolint: object_usage_linter
      )
    ) +
      ggplot2::geom_jitter(
        width = 0.15, alpha = 0.6, size = 2
      ) +
      ggplot2::stat_summary(
        fun.data = ggplot2::mean_cl_normal, # nolint: object_usage_linter
        geom = "crossbar",
        width = 0.4,
        colour = "black",
        fill = NA,
        linewidth = 0.5
      ) +
      ggplot2::scale_colour_brewer(palette = "Set2") +
      ggplot2::labs(
        title  = plot_title,
        x      = "Stratum",
        y      = count_var,
        colour = "Stratum"
      ) +
      ggplot2::theme_bw() +
      ggplot2::theme(
        plot.title      = ggplot2::element_text(face = "bold"),
        legend.position = "none"
      )
  }
}
