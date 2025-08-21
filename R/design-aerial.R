#' Construct a day-level survey design for aerial estimation
#'
#' Builds a `survey::svydesign` over sampled days (PSUs) using calendar
#' information. Weights per sampled day are computed from target vs actual
#' sample counts within strata (target_sample / actual_sample).
#'
#' @param calendar Tibble/data.frame with day-level sampling plan, including
#'   `day_id`, `target_sample`, `actual_sample`, and strata variables.
#' @param day_id Column name identifying the day PSU (default `date`).
#' @param strata_vars Character vector of calendar columns defining strata
#'   (e.g., `c("day_type","month")`). Missing columns are ignored with a warning.
#' @return A `survey::svydesign` object with one row per sampled day.
#' @examples
#' cal <- tibble::tibble(
#'   date = as.Date(c("2025-08-20","2025-08-21")),
#'   day_type = c("weekday","weekday"),
#'   month = c("August","August"),
#'   target_sample = c(4,4),
#'   actual_sample = c(2,2)
#' )
#' svy_day <- as_day_svydesign(cal, day_id = "date", strata_vars = c("day_type","month"))
#' @export
as_day_svydesign <- function(calendar,
                             day_id = "date",
                             strata_vars = c("day_type", "month", "season", "weekend")) {
  # Validate required columns
  tc_abort_missing_cols(calendar, c(day_id, "target_sample", "actual_sample"), context = "as_day_svydesign")
  # Keep only sampled days (actual_sample > 0)
  cal <- dplyr::filter(calendar, .data$actual_sample > 0)
  if (nrow(cal) == 0) cli::cli_abort("No sampled days found (actual_sample > 0).")
  # Filter to available strata vars
  strata_vars <- tc_group_warn(strata_vars, names(cal))
  # Compute per-stratum weight = target/actual; assign to each sampled day
  if (length(strata_vars) > 0) {
    strat <- dplyr::group_by(cal, dplyr::across(dplyr::all_of(strata_vars)))
    wtab <- dplyr::summarise(strat,
      .target = sum(.data$target_sample, na.rm = TRUE),
      .actual = sum(.data$actual_sample, na.rm = TRUE),
      .groups = "drop"
    )
    cal <- dplyr::left_join(cal, wtab, by = strata_vars)
  } else {
    cal$.target <- sum(cal$target_sample, na.rm = TRUE)
    cal$.actual <- sum(cal$actual_sample, na.rm = TRUE)
  }
  cal$.w <- cal$.target / pmax(cal$.actual, 1)
  # Build svydesign (PSUs = day_id; strata if available)
  ids_formula <- stats::as.formula(paste("~", day_id))
  if (length(strata_vars) > 0) {
    strata_formula <- stats::as.formula(paste("~", paste(strata_vars, collapse = "+")))
    svy <- survey::svydesign(ids = ids_formula, strata = strata_formula, weights = ~.w, data = cal)
  } else {
    svy <- survey::svydesign(ids = ids_formula, weights = ~.w, data = cal)
  }
  svy
}
