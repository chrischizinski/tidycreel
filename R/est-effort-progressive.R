#' Progressive (Roving) Effort Estimator (survey-first)
#'
#' Estimate angler-hours from progressive (roving) counts by summing pass-level
#' counts × route_minutes per day × group, then compute design-based totals and
#' variance via the `survey` package when a day-level design is supplied.
#'
#' Effort per day×group = sum_over_passes(count_pass × route_minutes) ÷ 60.
#'
#' @param counts Tibble/data.frame of progressive counts with columns: `count`,
#'   `route_minutes` (or candidate), grouping variables (e.g., `date`, `location`),
#'   and optional `pass_id`/`circuit_id`.
#' @param by Character vector of grouping variables (e.g., `date`, `location`).
#'   Missing columns are ignored with a warning.
#' @param route_minutes_col Name(s) of the per-pass route minutes column; the
#'   first present is used.
#' @param pass_id Optional column name identifying passes. If absent, rows are
#'   treated as pass records and summed within day × group.
#' @param day_id Day identifier (PSU), typically `date`, used to join with the
#'   survey design.
#' @param covariates Optional character vector of additional grouping variables.
#' @param svy Optional `svydesign`/`svrepdesign` for day-level sampling design.
#' @param conf_level Confidence level for Wald CIs (default 0.95).
#'
#' @return Tibble with grouping columns, `estimate`, `se`, `ci_low`, `ci_high`,
#'   `n`, `method`, and a `diagnostics` list-column.
#'
#' @details
#' Sums pass-level contributions to day × group totals and uses the day-PSU
#' survey design to compute totals and variance via the `survey` package.
#'
#' @seealso [as_day_svydesign()], [survey::svytotal()], [survey::svyby()].
#' @export
est_effort.progressive <- function(
  counts,
  by = c("date", "location"),
  route_minutes_col = c("route_minutes", "circuit_minutes"),
  pass_id = c("pass_id", "circuit_id"),
  day_id = "date",
  covariates = NULL,
  svy = NULL,
  conf_level = 0.95
) {
  tc_require_cols(counts, c("count"), context = "progressive effort")
  rm_col <- intersect(route_minutes_col, names(counts))
  if (length(rm_col) == 0) cli::cli_abort(c(
    "x" = "Missing route minutes column for progressive effort.",
    "i" = paste0("Provide one of: ", paste(route_minutes_col, collapse = ", "))
  ))
  rm_col <- rm_col[1]

  # Grouping
  by <- tc_group_warn(by, names(counts))
  if (is.null(covariates)) covariates <- character()
  covariates <- tc_group_warn(covariates, names(counts))
  by_all <- unique(c(by, covariates))

  # Define pass groupers
  pass_col <- intersect(pass_id, names(counts))
  if (length(pass_col) > 0) pass_col <- pass_col[1] else pass_col <- NULL

  # Compute pass totals then day totals
  if (!is.null(pass_col)) {
    pass_totals <- counts |>
      dplyr::group_by(
        dplyr::across(dplyr::all_of(c(day_id, by_all, pass_col)))
      ) |>
      dplyr::summarise(
        pass_effort = sum(.data$count * .data[[rm_col]], na.rm = TRUE) / 60,
        .groups = "drop"
      )
  } else {
    pass_totals <- counts |>
      dplyr::group_by(dplyr::across(dplyr::all_of(c(day_id, by_all)))) |>
      dplyr::summarise(
        pass_effort = sum(.data$count * .data[[rm_col]], na.rm = TRUE) / 60,
        .groups = "drop"
      )
  }

  day_group <- pass_totals |>
    dplyr::group_by(dplyr::across(dplyr::all_of(c(day_id, by_all)))) |>
    dplyr::summarise(effort_day = sum(pass_effort, na.rm = TRUE), n_passes = dplyr::n(), .groups = "drop")

  # Design-based path
  if (!is.null(svy)) {
    svy_vars <- svy$variables
    if (!(day_id %in% names(svy_vars))) cli::cli_abort(paste0("`svy` must include day_id variable: ", day_id))
    day_group$.w <- as.numeric(stats::weights(svy))[match(day_group[[day_id]], svy_vars[[day_id]])]
    if (any(is.na(day_group$.w))) cli::cli_abort(paste0("Failed to align survey weights on ", day_id))
    ids_formula <- stats::as.formula(paste("~", day_id))
    if (inherits(svy, "svyrep.design")) {
      repmat <- survey::repweights(svy)
      rep_df <- tibble::as_tibble(repmat)
      rep_df[[day_id]] <- svy_vars[[day_id]]
      day_group <- dplyr::left_join(day_group, rep_df, by = day_id)
      repcols <- colnames(repmat)
      design_eff <- survey::svrepdesign(
        data = day_group,
        repweights = as.matrix(day_group[, repcols]),
        weights = ~.w,
        type = attr(repmat, "type") %||% "bootstrap",
        scale = attr(repmat, "scale") %||% 1,
        rscales = attr(repmat, "rscales") %||% 1,
        combined.weights = attr(repmat, "combined.weights") %||% TRUE
      )
    } else {
      design_eff <- survey::svydesign(ids = ids_formula, weights = ~.w, data = day_group)
    }

    if (length(by_all) > 0) {
      by_formula <- stats::as.formula(paste("~", paste(by_all, collapse = "+")))
      est <- survey::svyby(~effort_day, by = by_formula, design_eff, survey::svytotal, na.rm = TRUE)
      out <- tibble::as_tibble(est)
      names(out)[names(out) == "effort_day"] <- "estimate"
      V <- attr(est, "var")
      out$se <- if (!is.null(V) && length(V) > 0) sqrt(diag(V)) else rep(NA_real_, nrow(out))
      z <- stats::qnorm(1 - (1 - conf_level)/2)
      out$ci_low <- out$estimate - z * out$se
      out$ci_high <- out$estimate + z * out$se
      out$n <- NA_integer_
      out$method <- "progressive"
      out$diagnostics <- replicate(nrow(out), list(NULL))
      return(dplyr::select(
        out,
        dplyr::all_of(by_all),
        estimate,
        se,
        ci_low,
        ci_high,
        n,
        method,
        diagnostics
      ))
    } else {
      total_est <- survey::svytotal(~effort_day, design_eff, na.rm = TRUE)
      estimate <- as.numeric(total_est[1])
      se <- sqrt(as.numeric(survey::vcov(total_est)))
      ci <- tc_confint(estimate, se, level = conf_level)
      return(tibble::tibble(
        estimate = estimate,
        se = se,
        ci_low = ci[1],
        ci_high = ci[2],
        n = NA_integer_,
        method = "progressive",
        diagnostics = list(NULL)
      ))
    }
  }

  # Fallback: within-group variability only (n_passes proxy)
  out <- day_group |>
    dplyr::group_by(dplyr::across(dplyr::all_of(by_all))) |>
    dplyr::summarise(
      estimate = sum(effort_day, na.rm = TRUE),
      n = sum(n_passes),
      .groups = "drop"
    )
  out$se <- NA_real_
  out$ci_low <- NA_real_
  out$ci_high <- NA_real_
  out$method <- "progressive"
  out$diagnostics <- replicate(nrow(out), list(NULL))
  dplyr::select(out, dplyr::all_of(by_all), estimate, se, ci_low, ci_high, n, method, diagnostics)
}
